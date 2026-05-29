/**
 * tenantSubscriptionHandler/index.mjs
 *
 * REST API endpoints:
 *   GET  /tenant/subscription — Returns current subscription state
 *   POST /tenant/upgrade      — Upgrade from trial (stub for payment)
 */
import { randomUUID } from 'crypto';
import {
  success, error, verifyToken, getItem, updateItem, putItem, logAuditEvent,
} from '../shared/utils.mjs';

const TENANTS_TABLE = process.env.TENANTS_TABLE;
const BILLING_TABLE = process.env.BILLING_TABLE;
const AUDIT_LOGS_TABLE = process.env.AUDIT_LOGS_TABLE;

function generateRID(tenantId) {
  return `${tenantId}-${Date.now()}-${randomUUID().split('-')[0]}`;
}

function computeDaysRemaining(trialEndDate) {
  if (!trialEndDate) return null;
  const end = new Date(trialEndDate);
  const now = new Date();
  const diff = Math.ceil((end.getTime() - now.getTime()) / 86400000);
  return Math.max(0, diff);
}

// GET /tenant/subscription
async function getSubscription(event) {
  const authHeader = event.headers?.authorization || event.headers?.Authorization;
  if (!authHeader?.startsWith('Bearer ')) return error('Authorization required', 401);

  const decoded = await verifyToken(authHeader.substring(7));
  const tenantId = decoded.tenantId;
  const rid = generateRID(tenantId);

  const tenant = await getItem(TENANTS_TABLE, { tenantId });
  if (!tenant) return error('Tenant not found', 404, rid);

  const daysRemaining = computeDaysRemaining(tenant.trialEndDate);
  const isInTrial = tenant.subscriptionStatus === 'TRIAL';
  const isExpired = tenant.subscriptionStatus === 'TRIAL_EXPIRED';

  // Auto-detect expiry if TRIAL but past end date
  if (isInTrial && daysRemaining !== null && daysRemaining <= 0) {
    await updateItem(TENANTS_TABLE, { tenantId }, {
      subscriptionStatus: 'TRIAL_EXPIRED',
      trialExpiredAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
    tenant.subscriptionStatus = 'TRIAL_EXPIRED';
  }

  return success({
    tenantId,
    subscriptionStatus: tenant.subscriptionStatus || 'TRIAL',
    planId: tenant.planId || null,
    businessType: tenant.businessType || 'other',
    trialStartDate: tenant.trialStartDate || null,
    trialEndDate: tenant.trialEndDate || null,
    daysRemaining,
    isInTrial: tenant.subscriptionStatus === 'TRIAL',
    isExpired: tenant.subscriptionStatus === 'TRIAL_EXPIRED',
    isActive: tenant.subscriptionStatus === 'ACTIVE',
    isSuspended: tenant.subscriptionStatus === 'SUSPENDED',
    subscriptionStartDate: tenant.subscriptionStartDate || null,
    subscriptionEndDate: tenant.subscriptionEndDate || null,
    upgradedAt: tenant.upgradedAt || null,
    rid,
  });
}

// POST /tenant/upgrade
async function upgradePlan(event) {
  const authHeader = event.headers?.authorization || event.headers?.Authorization;
  if (!authHeader?.startsWith('Bearer ')) return error('Authorization required', 401);

  const decoded = await verifyToken(authHeader.substring(7));
  const tenantId = decoded.tenantId;
  const rid = generateRID(tenantId);

  const body = JSON.parse(event.body || '{}');
  const { planId, paymentReference } = body;

  if (!planId) return error('planId is required', 400, rid);
  if (!paymentReference) return error('paymentReference is required', 400, rid);

  const tenant = await getItem(TENANTS_TABLE, { tenantId });
  if (!tenant) return error('Tenant not found', 404, rid);

  const now = new Date().toISOString();
  const subscriptionEndDate = new Date(
    Date.now() + 30 * 86400000 // Default 30-day subscription
  ).toISOString();

  // Update tenant to ACTIVE
  const updatedTenant = await updateItem(TENANTS_TABLE, { tenantId }, {
    subscriptionStatus: 'ACTIVE',
    planId,
    subscriptionStartDate: now,
    subscriptionEndDate,
    upgradedAt: now,
    paymentReference,
    updatedAt: now,
    // Keep trial fields for audit (don't delete)
  });

  // Record in billing table
  await putItem(BILLING_TABLE, {
    tenantId,
    SK: `SUB#${randomUUID()}`,
    plan: planId,
    status: 'active',
    startDate: now,
    endDate: subscriptionEndDate,
    paymentReference,
    previousStatus: tenant.subscriptionStatus,
    createdAt: now,
    updatedAt: now,
  });

  // Audit trail
  await logAuditEvent(
    tenantId, decoded.sub || decoded.userId, 'PLAN_UPGRADE',
    'subscription', tenantId,
    { planId, paymentReference, previousStatus: tenant.subscriptionStatus, rid },
    event.requestContext?.http?.sourceIp || 'unknown',
    event.requestContext?.http?.userAgent || 'unknown'
  );

  return success({
    tenantId,
    subscriptionStatus: 'ACTIVE',
    planId,
    subscriptionStartDate: now,
    subscriptionEndDate,
    upgradedAt: now,
    previousStatus: tenant.subscriptionStatus,
    rid,
  });
}

export const handler = async (event) => {
  const method = event.requestContext?.http?.method || '';
  const path = event.requestContext?.http?.path || event.rawPath || '';

  try {
    if (method === 'GET' && path === '/tenant/subscription') return await getSubscription(event);
    if (method === 'POST' && path === '/tenant/upgrade') return await upgradePlan(event);
    return error(`Unsupported route: ${method} ${path}`, 404);
  } catch (err) {
    console.error('Subscription handler error:', err);
    if (err.message?.includes('INVALID_TOKEN')) return error('Authentication failed', 401);
    if (err.message === 'FORBIDDEN') return error('Access denied', 403);
    return error('Internal server error', 500);
  }
};
