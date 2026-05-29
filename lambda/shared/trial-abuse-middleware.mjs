/**
 * shared/trial-abuse-middleware.mjs
 *
 * Abuse prevention middleware for trial signup.
 * Checks phone number and device fingerprint against TrialAbuseTable.
 * Returns structured 403 response if trial has already been used.
 *
 * Usage in any Lambda handler:
 *   import { checkTrialAbuse } from '../shared/trial-abuse-middleware.mjs';
 *   const abuseResult = await checkTrialAbuse(event);
 *   if (abuseResult) return abuseResult; // 403 response
 */

import { randomUUID } from 'crypto';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb';

const ddbClient = new DynamoDBClient({ maxAttempts: 2, retryMode: 'adaptive' });
const docClient = DynamoDBDocumentClient.from(ddbClient);

const TRIAL_ABUSE_TABLE = process.env.TRIAL_ABUSE_TABLE;

/**
 * Generate RID for abuse log tracking
 */
function generateRID(identifier) {
  const timestamp = Date.now();
  const shortUuid = randomUUID().split('-')[0];
  return `${identifier}-${timestamp}-${shortUuid}`;
}

/**
 * Check if phone number has already used a trial
 */
async function checkPhoneAbuse(phone) {
  if (!phone || !TRIAL_ABUSE_TABLE) return null;

  try {
    const result = await docClient.send(
      new GetCommand({
        TableName: TRIAL_ABUSE_TABLE,
        Key: { PK: `PHONE#${phone}`, SK: 'TRIAL_USED' },
      })
    );

    if (result.Item) {
      return {
        vector: 'phone',
        originalTenantId: result.Item.tenantId,
        usedAt: result.Item.createdAt,
      };
    }
  } catch (err) {
    console.error('Phone abuse check failed:', err.message);
    // Fail open — don't block on DDB errors
  }
  return null;
}

/**
 * Check if device fingerprint has already used a trial
 */
async function checkDeviceAbuse(deviceFingerprint) {
  if (!deviceFingerprint || !TRIAL_ABUSE_TABLE) return null;

  try {
    const result = await docClient.send(
      new GetCommand({
        TableName: TRIAL_ABUSE_TABLE,
        Key: { PK: `DEVICE#${deviceFingerprint}`, SK: 'TRIAL_USED' },
      })
    );

    if (result.Item) {
      return {
        vector: 'device_fingerprint',
        originalTenantId: result.Item.tenantId,
        usedAt: result.Item.createdAt,
      };
    }
  } catch (err) {
    console.error('Device abuse check failed:', err.message);
  }
  return null;
}

/**
 * Main abuse check middleware.
 * Extracts phone and device fingerprint from event, checks both vectors.
 *
 * @param {object} event - API Gateway event
 * @returns {object|null} - 403 response if abused, null if clean
 */
export async function checkTrialAbuse(event) {
  // Extract phone from JWT or body
  const phone =
    event.user?.phone ||
    event.requestContext?.authorizer?.lambda?.phone ||
    '';

  // Extract device fingerprint from header
  const deviceFingerprint =
    event.headers?.['x-device-fingerprint'] ||
    event.headers?.['X-Device-Fingerprint'] ||
    '';

  if (!phone && !deviceFingerprint) {
    return null; // No vectors to check
  }

  const abuses = [];

  const phoneResult = await checkPhoneAbuse(phone);
  if (phoneResult) abuses.push(phoneResult);

  const deviceResult = await checkDeviceAbuse(deviceFingerprint);
  if (deviceResult) abuses.push(deviceResult);

  if (abuses.length === 0) {
    return null; // Clean — no abuse detected
  }

  const rid = generateRID(phone || deviceFingerprint);

  // Log abuse attempt to CloudWatch
  console.error(
    JSON.stringify({
      level: 'WARN',
      event: 'TRIAL_ABUSE_ATTEMPT',
      rid,
      phone: phone ? `***${phone.slice(-4)}` : 'N/A',
      deviceFingerprint: deviceFingerprint
        ? `${deviceFingerprint.slice(0, 8)}...`
        : 'N/A',
      vectors: abuses.map((a) => a.vector),
      sourceIp: event.requestContext?.http?.sourceIp || 'unknown',
      timestamp: new Date().toISOString(),
    })
  );

  // Return structured 403
  return {
    statusCode: 403,
    headers: {
      'Content-Type': 'application/json',
      'X-Request-Id': rid,
    },
    body: JSON.stringify({
      success: false,
      error: {
        code: 'TRIAL_ALREADY_USED',
        message:
          'A free trial has already been used with this account. Please upgrade to continue.',
        rid,
      },
    }),
  };
}

/**
 * Express-style middleware wrapper for handlers
 * Wraps any handler with abuse prevention check
 */
export function withTrialAbuseCheck(handler) {
  return async (event, context) => {
    const abuseResult = await checkTrialAbuse(event);
    if (abuseResult) return abuseResult;
    return handler(event, context);
  };
}
