/**
 * trialNotificationSchedulerHandler/index.mjs
 * Sends trial reminder notifications at Day 7 and Day 12 checkpoints.
 */
import { randomUUID } from 'crypto';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { emitUnsEvent } from '../shared/uns-emit.mjs';

const ddbClient = new DynamoDBClient({ maxAttempts: 3, retryMode: 'adaptive' });
const docClient = DynamoDBDocumentClient.from(ddbClient);
const sns = new SNSClient({});

const TENANTS_TABLE = process.env.TENANTS_TABLE;
const SNS_TRIAL_TOPIC_ARN = process.env.SNS_TRIAL_TOPIC_ARN;

const TEMPLATES = {
  7: { title: '7 days remaining ⏳', body: 'Your trial is halfway through. Explore premium features!', deepLink: 'dukanx://subscription' },
  2: { title: 'Only 2 days left! 🔔', body: 'Upgrade now to keep access to all features.', deepLink: 'dukanx://upgrade' },
};

function getBusinessMsg(bt) {
  const m = { grocery: 'Keep managing inventory seamlessly.', pharmacy: 'Continue tracking prescriptions.', restaurant: "Don't lose KOT features.", wholesale: 'Keep bulk pricing active.', other: 'Keep operations running.' };
  return m[bt] || m.other;
}

async function getTenantsForCheckpoint(daysRemaining) {
  const target = new Date(Date.now() + daysRemaining * 86400000);
  const start = new Date(target.getTime() - 43200000).toISOString();
  const end = new Date(target.getTime() + 43200000).toISOString();
  const items = [];
  let lastKey;
  do {
    const r = await docClient.send(new QueryCommand({
      TableName: TENANTS_TABLE, IndexName: 'GSI_SubscriptionStatus',
      KeyConditionExpression: 'subscriptionStatus = :s AND trialEndDate BETWEEN :a AND :b',
      ExpressionAttributeValues: { ':s': 'TRIAL', ':a': start, ':b': end },
      ExclusiveStartKey: lastKey,
    }));
    items.push(...(r.Items || []));
    lastKey = r.LastEvaluatedKey;
  } while (lastKey);
  return items;
}

async function sendReminder(tenant, days, tpl) {
  await sns.send(new PublishCommand({
    TopicArn: SNS_TRIAL_TOPIC_ARN,
    Message: JSON.stringify({
      type: 'TRIAL_REMINDER', tenantId: tenant.tenantId,
      businessType: tenant.businessType || 'other', daysRemaining: days,
      fcmPayload: { notification: { title: tpl.title, body: `${tpl.body} ${getBusinessMsg(tenant.businessType)}` }, data: { type: 'TRIAL_REMINDER', tenantId: tenant.tenantId, daysRemaining: String(days), deepLink: tpl.deepLink } },
      timestamp: new Date().toISOString(),
    }),
    MessageAttributes: { tenantId: { DataType: 'String', StringValue: tenant.tenantId }, eventType: { DataType: 'String', StringValue: `TRIAL_REMINDER_DAY_${14 - days}` } },
  }));

  // UNS canonical emit (T-PLN-2: system.tenant_trial.expiry_reminder)
  await emitUnsEvent({
    eventName: 'system.tenant_trial.expiry_reminder',
    category: 'system',
    subCategory: 'tenant_trial',
    priority: days <= 2 ? 'high' : 'normal',
    actorId: 'system',
    targetId: tenant.tenantId,
    recipients: [
      { user_id: tenant.tenantId, role: 'admin' },
    ],
    payload: {
      tenantId: tenant.tenantId,
      businessType: tenant.businessType || 'other',
      daysRemaining: days,
      title: tpl.title,
      body: `${tpl.body} ${getBusinessMsg(tenant.businessType)}`,
      deepLink: tpl.deepLink,
    },
    channels: ['in_app', 'push'],
    sourceModule: 'lambda/trialNotificationSchedulerHandler/index.mjs',
    dedupScopeFields: ['tenantId', 'daysRemaining'],
  });
}

export const handler = async () => {
  console.log('[TRIAL_NOTIFICATIONS] Starting');
  const results = [];
  for (const [d, tpl] of Object.entries(TEMPLATES)) {
    const days = parseInt(d, 10);
    const tenants = await getTenantsForCheckpoint(days);
    console.log(`[TRIAL_NOTIFICATIONS] ${tenants.length} tenants at ${days}d remaining`);
    for (const t of tenants) {
      try { await sendReminder(t, days, tpl); results.push({ t: t.tenantId, d: days, ok: true }); }
      catch (e) { console.error(`Error ${t.tenantId}:`, e.message); results.push({ t: t.tenantId, d: days, ok: false }); }
    }
  }
  console.log(`[TRIAL_NOTIFICATIONS] Done: ${results.filter(r=>r.ok).length}/${results.length}`);
  return { statusCode: 200, body: JSON.stringify({ total: results.length }) };
};
