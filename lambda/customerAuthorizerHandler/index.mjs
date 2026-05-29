/**
 * customerAuthorizerHandler/index.mjs
 * Lambda Authorizer for all /customer/v1/* routes.
 * 
 * UPDATED: Now includes subscription status check with 5-minute in-memory cache.
 * - Validates JWT from Cognito and enforces role=customer
 * - Fetches tenant subscription record from DynamoDB (cached)
 * - Checks subscriptionStatus + trialEndDate
 * - Attaches subscription context to Lambda event
 * - Allow/Deny based on: TRIAL+active → ALLOW, TRIAL_EXPIRED → DENY, ACTIVE → ALLOW, SUSPENDED → DENY
 */

import { CognitoJwtVerifier } from 'aws-jwt-verify';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb';

const USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;
const CLIENT_ID = process.env.COGNITO_MOBILE_CLIENT_ID;
const TENANTS_TABLE = process.env.TENANTS_TABLE || process.env.DYNAMODB_TABLE_TENANTS;

const verifier = CognitoJwtVerifier.create({
  userPoolId: USER_POOL_ID,
  tokenUse: 'access',
  clientId: CLIENT_ID,
});

// DynamoDB client for subscription lookups
const ddbClient = new DynamoDBClient({ maxAttempts: 2, retryMode: 'adaptive' });
const docClient = DynamoDBDocumentClient.from(ddbClient);

// ── In-Memory Subscription Cache (TTL: 5 minutes) ──────────────────────────
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const subscriptionCache = new Map();

function getCachedSubscription(tenantId) {
  const entry = subscriptionCache.get(tenantId);
  if (!entry) return null;
  if (Date.now() - entry.timestamp > CACHE_TTL_MS) {
    subscriptionCache.delete(tenantId);
    return null;
  }
  return entry.data;
}

function setCachedSubscription(tenantId, data) {
  // Evict old entries if cache grows too large (prevent memory leak)
  if (subscriptionCache.size > 1000) {
    const oldest = subscriptionCache.keys().next().value;
    subscriptionCache.delete(oldest);
  }
  subscriptionCache.set(tenantId, { data, timestamp: Date.now() });
}

// ── Subscription Check ──────────────────────────────────────────────────────

async function getSubscriptionStatus(tenantId) {
  // Check cache first
  const cached = getCachedSubscription(tenantId);
  if (cached) return cached;

  // Fetch from DynamoDB
  if (!TENANTS_TABLE) {
    console.warn('TENANTS_TABLE not configured, skipping subscription check');
    return { subscriptionStatus: 'ACTIVE', daysRemaining: null, planId: null };
  }

  try {
    const result = await docClient.send(new GetCommand({
      TableName: TENANTS_TABLE,
      Key: { tenantId },
      ProjectionExpression: 'subscriptionStatus, trialEndDate, planId, businessType',
    }));

    const tenant = result.Item;
    if (!tenant) {
      return { subscriptionStatus: 'UNKNOWN', daysRemaining: null, planId: null };
    }

    const now = new Date();
    let daysRemaining = null;
    let status = tenant.subscriptionStatus || 'ACTIVE';

    if (tenant.trialEndDate) {
      const end = new Date(tenant.trialEndDate);
      daysRemaining = Math.max(0, Math.ceil((end.getTime() - now.getTime()) / 86400000));

      // Auto-detect expiry
      if (status === 'TRIAL' && daysRemaining <= 0) {
        status = 'TRIAL_EXPIRED';
      }
    }

    const subData = {
      subscriptionStatus: status,
      daysRemaining,
      planId: tenant.planId || null,
      businessType: tenant.businessType || 'other',
    };

    setCachedSubscription(tenantId, subData);
    return subData;
  } catch (err) {
    console.error('Subscription lookup failed:', err.message);
    // Fail open — don't block on DDB errors; log for monitoring
    return { subscriptionStatus: 'ACTIVE', daysRemaining: null, planId: null };
  }
}

function isAccessAllowed(subscriptionStatus) {
  switch (subscriptionStatus) {
    case 'TRIAL':
    case 'ACTIVE':
      return true;
    case 'TRIAL_EXPIRED':
    case 'SUSPENDED':
      return false;
    default:
      // Unknown status — allow (fail open for safety)
      return true;
  }
}

export const handler = async (event) => {
  const token = extractToken(event);

  if (!token) {
    return generatePolicy('anonymous', 'Deny', event.routeArn);
  }

  try {
    const payload = await verifier.verify(token);

    // Enforce customer role via Cognito group or custom attribute
    const groups = payload['cognito:groups'] || [];
    const customRole = payload['custom:role'];
    const isCustomer =
      groups.includes('customer') || customRole === 'customer';

    if (!isCustomer) {
      console.warn(`Non-customer attempted to access customer API: ${payload.sub}`);
      return generatePolicy(payload.sub, 'Deny', event.routeArn);
    }

    const tenantId = payload['custom:tenantId'] || '';

    // Check subscription status
    const subscription = await getSubscriptionStatus(tenantId);
    const allowed = isAccessAllowed(subscription.subscriptionStatus);

    if (!allowed) {
      console.warn(`Access denied for tenant ${tenantId}: status=${subscription.subscriptionStatus}`);
      const policy = generatePolicy(payload.sub, 'Deny', event.routeArn);
      policy.context = {
        userId: payload.sub,
        role: 'customer',
        tenantId,
        subscriptionStatus: subscription.subscriptionStatus,
        daysRemaining: String(subscription.daysRemaining ?? ''),
        accessDeniedReason: `SUBSCRIPTION_${subscription.subscriptionStatus}`,
      };
      return policy;
    }

    const policy = generatePolicy(payload.sub, 'Allow', event.routeArn);
    policy.context = {
      userId: payload.sub,
      role: 'customer',
      phone: payload.phone_number || '',
      email: payload.email || '',
      tenantId,
      subscriptionStatus: subscription.subscriptionStatus,
      daysRemaining: String(subscription.daysRemaining ?? ''),
      planId: subscription.planId || '',
    };
    return policy;
  } catch (err) {
    console.error('Token verification failed:', err.message);
    return generatePolicy('anonymous', 'Deny', event.routeArn);
  }
};

function extractToken(event) {
  const auth =
    event.authorizationToken ||
    event.headers?.Authorization ||
    event.headers?.authorization;
  if (!auth) return null;
  if (auth.startsWith('Bearer ')) return auth.slice(7);
  return auth;
}

function generatePolicy(principalId, effect, resource) {
  return {
    principalId,
    policyDocument: {
      Version: '2012-10-17',
      Statement: [
        {
          Action: 'execute-api:Invoke',
          Effect: effect,
          Resource: resource,
        },
      ],
    },
  };
}
