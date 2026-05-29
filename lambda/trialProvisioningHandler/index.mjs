/**
 * trialProvisioningHandler/index.mjs
 * 
 * Triggered on Cognito PostConfirmation hook (tenant signup).
 * - Checks abuse prevention (phone + device fingerprint)
 * - Assigns 14-day free trial to the new tenant
 * - Sends Day 0 notification via SNS
 * - Logs audit trail with RID
 */

import { randomUUID } from 'crypto';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import {
  getItem,
  putItem,
  updateItem,
  logAuditEvent,
  success,
  error,
  verifyToken,
} from '../shared/utils.mjs';
import { emitUnsEvent } from '../shared/uns-emit.mjs';

const sns = new SNSClient({});

const TENANTS_TABLE = process.env.TENANTS_TABLE;
const TRIAL_ABUSE_TABLE = process.env.TRIAL_ABUSE_TABLE;
const SNS_TRIAL_TOPIC_ARN = process.env.SNS_TRIAL_TOPIC_ARN;
const TRIAL_DURATION_DAYS = parseInt(process.env.TRIAL_DURATION_DAYS || '14', 10);

/**
 * Generate Request ID for audit trail
 * Format: {tenantId}-{timestamp_ms}-{uuid_v4_short}
 */
function generateRID(tenantId) {
  const timestamp = Date.now();
  const shortUuid = randomUUID().split('-')[0];
  return `${tenantId}-${timestamp}-${shortUuid}`;
}

/**
 * Check if phone or device fingerprint has already used a trial
 */
async function checkAbuseVectors(phone, deviceFingerprint) {
  const reasons = [];

  if (phone) {
    const phoneRecord = await getItem(TRIAL_ABUSE_TABLE, {
      PK: `PHONE#${phone}`,
      SK: 'TRIAL_USED',
    });
    if (phoneRecord) {
      reasons.push({
        vector: 'phone',
        originalTenantId: phoneRecord.tenantId,
        usedAt: phoneRecord.createdAt,
      });
    }
  }

  if (deviceFingerprint) {
    const deviceRecord = await getItem(TRIAL_ABUSE_TABLE, {
      PK: `DEVICE#${deviceFingerprint}`,
      SK: 'TRIAL_USED',
    });
    if (deviceRecord) {
      reasons.push({
        vector: 'device_fingerprint',
        originalTenantId: deviceRecord.tenantId,
        usedAt: deviceRecord.createdAt,
      });
    }
  }

  return reasons;
}

/**
 * Record abuse prevention markers for phone and device
 */
async function recordAbuseVectors(tenantId, phone, deviceFingerprint) {
  const now = new Date().toISOString();
  // Records expire after 2 years (prevent re-trials)
  const expiresAt = Math.floor(Date.now() / 1000) + 2 * 365 * 24 * 60 * 60;

  const promises = [];

  if (phone) {
    promises.push(
      putItem(TRIAL_ABUSE_TABLE, {
        PK: `PHONE#${phone}`,
        SK: 'TRIAL_USED',
        tenantId,
        createdAt: now,
        expiresAt,
      })
    );
  }

  if (deviceFingerprint) {
    promises.push(
      putItem(TRIAL_ABUSE_TABLE, {
        PK: `DEVICE#${deviceFingerprint}`,
        SK: 'TRIAL_USED',
        tenantId,
        createdAt: now,
        expiresAt,
      })
    );
  }

  await Promise.all(promises);
}

/**
 * Send Day 0 trial notification via SNS
 */
async function sendTrialStartNotification(tenantId, businessType, trialEndDate) {
  const message = {
    type: 'TRIAL_STARTED',
    tenantId,
    businessType,
    daysRemaining: TRIAL_DURATION_DAYS,
    trialEndDate,
    notification: {
      title: 'Welcome to DukanX! 🎉',
      body: `Your ${TRIAL_DURATION_DAYS}-day free trial has started! Explore all features.`,
      deepLink: 'dukanx://dashboard',
    },
    timestamp: new Date().toISOString(),
  };

  await sns.send(
    new PublishCommand({
      TopicArn: SNS_TRIAL_TOPIC_ARN,
      Message: JSON.stringify(message),
      MessageAttributes: {
        tenantId: { DataType: 'String', StringValue: tenantId },
        eventType: { DataType: 'String', StringValue: 'TRIAL_STARTED' },
      },
    })
  );

  // UNS canonical emit (T-PLN-1: system.tenant_trial.started)
  await emitUnsEvent({
    eventName: 'system.tenant_trial.started',
    category: 'system',
    subCategory: 'tenant_trial',
    priority: 'normal',
    actorId: 'system',
    targetId: tenantId,
    recipients: [
      { user_id: tenantId, role: 'admin' },
    ],
    payload: {
      tenantId,
      businessType,
      daysRemaining: TRIAL_DURATION_DAYS,
      trialEndDate,
      title: 'Welcome to DukanX! 🎉',
      body: `Your ${TRIAL_DURATION_DAYS}-day free trial has started! Explore all features.`,
    },
    channels: ['in_app', 'push'],
    sourceModule: 'lambda/trialProvisioningHandler/index.mjs',
    dedupScopeFields: ['tenantId'],
  });
}

/**
 * Provision trial on tenant record
 * Called after tenant creation (PostConfirmation hook or direct API call)
 */
async function provisionTrial(tenantId, businessType, phone, deviceFingerprint) {
  const rid = generateRID(tenantId);
  const now = new Date();
  const trialStartDate = now.toISOString();
  const trialEndDate = new Date(
    now.getTime() + TRIAL_DURATION_DAYS * 24 * 60 * 60 * 1000
  ).toISOString();

  // Check if tenant already has a trial
  const existingTenant = await getItem(TENANTS_TABLE, { tenantId });
  if (existingTenant?.subscriptionStatus) {
    console.warn(`[${rid}] Tenant ${tenantId} already has subscription status: ${existingTenant.subscriptionStatus}`);
    return {
      alreadyProvisioned: true,
      subscriptionStatus: existingTenant.subscriptionStatus,
    };
  }

  // Check abuse vectors
  const abuseReasons = await checkAbuseVectors(phone, deviceFingerprint);
  if (abuseReasons.length > 0) {
    console.error(`[${rid}] Trial abuse detected for tenant ${tenantId}:`, JSON.stringify(abuseReasons));
    return {
      abused: true,
      reasons: abuseReasons,
    };
  }

  // Update tenant with trial fields
  const trialFields = {
    subscriptionStatus: 'TRIAL',
    trialStartDate,
    trialEndDate,
    planId: null,
    businessType: businessType || 'other',
    trialProvisionedAt: trialStartDate,
    trialRID: rid,
    updatedAt: trialStartDate,
  };

  await updateItem(TENANTS_TABLE, { tenantId }, trialFields);

  // Record abuse vectors
  await recordAbuseVectors(tenantId, phone, deviceFingerprint);

  // Send Day 0 notification
  await sendTrialStartNotification(tenantId, businessType, trialEndDate);

  // Audit trail
  await logAuditEvent(
    tenantId,
    tenantId, // ownerUserId = tenantId at signup
    'TRIAL_PROVISIONED',
    'subscription',
    tenantId,
    { trialStartDate, trialEndDate, businessType, rid },
    'system',
    'TrialProvisioningLambda'
  );

  return {
    success: true,
    subscriptionStatus: 'TRIAL',
    trialStartDate,
    trialEndDate,
    daysRemaining: TRIAL_DURATION_DAYS,
    rid,
  };
}

/**
 * Cognito PostConfirmation trigger handler
 * Also supports direct HTTP invocation for manual provisioning
 */
export const handler = async (event) => {
  // Detect if this is a Cognito trigger or HTTP API call
  const isCognitoTrigger = event.triggerSource !== undefined;

  if (isCognitoTrigger) {
    // Cognito PostConfirmation hook
    const tenantId =
      event.request?.userAttributes?.['custom:tenantId'] ||
      event.userName;
    const phone = event.request?.userAttributes?.phone_number || '';
    const businessType =
      event.request?.userAttributes?.['custom:businessType'] || 'other';
    const deviceFingerprint =
      event.request?.clientMetadata?.deviceFingerprint || '';

    console.log(`[TRIAL] PostConfirmation for tenant: ${tenantId}`);

    try {
      const result = await provisionTrial(
        tenantId,
        businessType,
        phone,
        deviceFingerprint
      );

      if (result.abused) {
        console.warn(`[TRIAL] Abuse detected, trial not provisioned for ${tenantId}`);
        // Don't block Cognito flow — just skip trial provisioning
      }
    } catch (err) {
      console.error(`[TRIAL] Error provisioning trial for ${tenantId}:`, err);
      // Don't throw — Cognito PostConfirmation should not fail signup
    }

    // Always return the event for Cognito
    return event;
  }

  // HTTP API call — manual trial provisioning
  const method = event.requestContext?.http?.method || '';
  const path = event.requestContext?.http?.path || '';

  if (method === 'POST' && path === '/tenant/provision-trial') {
    try {
      const authHeader =
        event.headers?.authorization || event.headers?.Authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return error('Authorization header required', 401);
      }

      const decoded = await verifyToken(authHeader.substring(7));
      const tenantId = decoded.tenantId;
      const body = JSON.parse(event.body || '{}');

      const result = await provisionTrial(
        tenantId,
        body.businessType || 'other',
        decoded.phone || body.phone || '',
        body.deviceFingerprint || event.headers?.['x-device-fingerprint'] || ''
      );

      if (result.abused) {
        return error('TRIAL_ALREADY_USED', 403, generateRID(tenantId));
      }

      if (result.alreadyProvisioned) {
        return success({
          message: 'Trial already provisioned',
          subscriptionStatus: result.subscriptionStatus,
        });
      }

      return success(result, 201);
    } catch (err) {
      console.error('[TRIAL] Manual provisioning error:', err);
      return error('Failed to provision trial', 500);
    }
  }

  return error('Unsupported route', 404);
};
