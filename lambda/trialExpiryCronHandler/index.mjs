/**
 * trialExpiryCronHandler/index.mjs
 *
 * EventBridge cron job — runs daily at midnight IST (18:30 UTC).
 * - Scans all tenants with subscriptionStatus = "TRIAL" and trialEndDate <= today
 * - Batch updates their status to "TRIAL_EXPIRED"
 * - Publishes SNS notification per expired tenant
 * - Logs all transitions with RID for audit trail
 */

import { randomUUID } from 'crypto';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  QueryCommand,
  UpdateCommand,
} from '@aws-sdk/lib-dynamodb';
import { putItem } from '../shared/utils.mjs';
import { emitUnsEvent } from '../shared/uns-emit.mjs';

const ddbClient = new DynamoDBClient({ maxAttempts: 3, retryMode: 'adaptive' });
const docClient = DynamoDBDocumentClient.from(ddbClient);
const sns = new SNSClient({});

const TENANTS_TABLE = process.env.TENANTS_TABLE;
const AUDIT_LOGS_TABLE = process.env.AUDIT_LOGS_TABLE;
const SNS_TRIAL_TOPIC_ARN = process.env.SNS_TRIAL_TOPIC_ARN;

/**
 * Generate Request ID for audit trail
 */
function generateRID(tenantId) {
  const timestamp = Date.now();
  const shortUuid = randomUUID().split('-')[0];
  return `${tenantId}-${timestamp}-${shortUuid}`;
}

/**
 * Query all TRIAL tenants whose trialEndDate <= today
 */
async function getExpiredTrialTenants() {
  const now = new Date().toISOString();
  const tenants = [];
  let lastKey;

  do {
    const command = new QueryCommand({
      TableName: TENANTS_TABLE,
      IndexName: 'GSI_SubscriptionStatus',
      KeyConditionExpression:
        'subscriptionStatus = :status AND trialEndDate <= :now',
      ExpressionAttributeValues: {
        ':status': 'TRIAL',
        ':now': now,
      },
      ExclusiveStartKey: lastKey,
    });

    const result = await docClient.send(command);
    tenants.push(...(result.Items || []));
    lastKey = result.LastEvaluatedKey;
  } while (lastKey);

  return tenants;
}

/**
 * Transition a single tenant from TRIAL to TRIAL_EXPIRED
 */
async function expireTenant(tenant) {
  const rid = generateRID(tenant.tenantId);
  const now = new Date().toISOString();

  // Conditional update: only if still TRIAL (prevents race conditions)
  const command = new UpdateCommand({
    TableName: TENANTS_TABLE,
    Key: { tenantId: tenant.tenantId },
    UpdateExpression:
      'SET subscriptionStatus = :expired, trialExpiredAt = :now, updatedAt = :now, expiryRID = :rid',
    ConditionExpression: 'subscriptionStatus = :trial',
    ExpressionAttributeValues: {
      ':expired': 'TRIAL_EXPIRED',
      ':trial': 'TRIAL',
      ':now': now,
      ':rid': rid,
    },
    ReturnValues: 'ALL_NEW',
  });

  try {
    const result = await docClient.send(command);

    // Audit log
    await putItem(AUDIT_LOGS_TABLE, {
      tenantId: tenant.tenantId,
      SK: `${now}#${randomUUID()}`,
      eventId: randomUUID(),
      userId: 'system',
      action: 'TRIAL_EXPIRED',
      resource: 'subscription',
      resourceId: tenant.tenantId,
      changes: {
        previousStatus: 'TRIAL',
        newStatus: 'TRIAL_EXPIRED',
        trialEndDate: tenant.trialEndDate,
        rid,
      },
      severity: 'warning',
      expiresAt: Math.floor(Date.now() / 1000) + 90 * 24 * 60 * 60,
    });

    // SNS notification
    await sns.send(
      new PublishCommand({
        TopicArn: SNS_TRIAL_TOPIC_ARN,
        Message: JSON.stringify({
          type: 'TRIAL_EXPIRED',
          tenantId: tenant.tenantId,
          businessType: tenant.businessType || 'other',
          daysRemaining: 0,
          notification: {
            title: 'Your trial has expired',
            body: 'Your 14-day free trial has ended. Upgrade now to keep access to all features.',
            deepLink: 'dukanx://upgrade',
          },
          timestamp: now,
          rid,
        }),
        MessageAttributes: {
          tenantId: {
            DataType: 'String',
            StringValue: tenant.tenantId,
          },
          eventType: {
            DataType: 'String',
            StringValue: 'TRIAL_EXPIRED',
          },
        },
      })
    );

    // UNS canonical emit (T-PLN-3: system.tenant_trial.expired)
    await emitUnsEvent({
      eventName: 'system.tenant_trial.expired',
      category: 'system',
      subCategory: 'tenant_trial',
      priority: 'high',
      actorId: 'system',
      targetId: tenant.tenantId,
      recipients: [
        { user_id: tenant.tenantId, role: 'admin' },
      ],
      payload: {
        tenantId: tenant.tenantId,
        businessType: tenant.businessType || 'other',
        title: 'Your trial has expired',
        body: 'Your 14-day free trial has ended. Upgrade now to keep access to all features.',
        deepLink: 'dukanx://upgrade',
        rid,
      },
      channels: ['in_app', 'push', 'email'],
      sourceModule: 'lambda/trialExpiryCronHandler/index.mjs',
      dedupScopeFields: ['tenantId'],
    });

    console.log(`[${rid}] Expired trial for tenant: ${tenant.tenantId}`);
    return { tenantId: tenant.tenantId, rid, status: 'expired' };
  } catch (err) {
    if (err.name === 'ConditionalCheckFailedException') {
      console.warn(
        `[${rid}] Tenant ${tenant.tenantId} already transitioned from TRIAL`
      );
      return {
        tenantId: tenant.tenantId,
        rid,
        status: 'skipped',
        reason: 'already_transitioned',
      };
    }
    throw err;
  }
}

/**
 * Main handler — EventBridge cron entry point
 */
export const handler = async (event) => {
  const startTime = Date.now();
  console.log('[TRIAL_EXPIRY_CRON] Starting daily trial expiry check');

  try {
    const expiredTenants = await getExpiredTrialTenants();
    console.log(
      `[TRIAL_EXPIRY_CRON] Found ${expiredTenants.length} expired trial tenants`
    );

    if (expiredTenants.length === 0) {
      console.log('[TRIAL_EXPIRY_CRON] No expired trials to process');
      return {
        statusCode: 200,
        body: JSON.stringify({
          processed: 0,
          duration: Date.now() - startTime,
        }),
      };
    }

    // Process in batches of 25 to avoid throttling
    const BATCH_SIZE = 25;
    const results = [];

    for (let i = 0; i < expiredTenants.length; i += BATCH_SIZE) {
      const batch = expiredTenants.slice(i, i + BATCH_SIZE);
      const batchResults = await Promise.allSettled(
        batch.map((tenant) => expireTenant(tenant))
      );

      for (const result of batchResults) {
        if (result.status === 'fulfilled') {
          results.push(result.value);
        } else {
          console.error(
            '[TRIAL_EXPIRY_CRON] Error expiring tenant:',
            result.reason
          );
          results.push({
            status: 'error',
            error: result.reason?.message || 'Unknown error',
          });
        }
      }
    }

    const summary = {
      total: expiredTenants.length,
      expired: results.filter((r) => r.status === 'expired').length,
      skipped: results.filter((r) => r.status === 'skipped').length,
      errors: results.filter((r) => r.status === 'error').length,
      duration: Date.now() - startTime,
    };

    console.log('[TRIAL_EXPIRY_CRON] Completed:', JSON.stringify(summary));

    return {
      statusCode: 200,
      body: JSON.stringify(summary),
    };
  } catch (err) {
    console.error('[TRIAL_EXPIRY_CRON] Fatal error:', err);
    throw err;
  }
};
