// ============================================================================
// Plan Management Service � Upgrade/Downgrade Lifecycle (DynamoDB)
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import {
    Keys,
    getItem, putItem, queryItems, updateItem,
} from '../config/dynamodb.config';
import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger';
import { PlanTier, PLAN_HIERARCHY, isValidUpgrade, isValidDowngrade, mapToPlanTier, PLAN_LIMITS } from '../config/plan-feature-registry';
import { regenerateManifest, FeatureManifest } from './feature-manifest.service';
import { invalidateManifest } from '../config/manifest-cache';
import { CognitoIdentityProviderClient, AdminUpdateUserAttributesCommand } from '@aws-sdk/client-cognito-identity-provider';
import { createHmac } from 'crypto';
import { config } from '../config/environment';

const cognitoClient = new CognitoIdentityProviderClient(configureAwsClient({ region: config.aws.region }));
const USER_POOL_ID = config.cognito.userPoolId;

export interface PlanChangeResult { success: boolean; tenantId: string; previousPlan: PlanTier; newPlan: PlanTier; manifest: FeatureManifest; message: string; }
export interface PlanHistoryEntry { id: string; tenant_id: string; previous_plan: string; new_plan: string; change_type: string; changed_by: string; change_reason: string | null; metadata: Record<string, unknown>; created_at: string; }
export interface TenantPlanStatus { tenantId: string; tenantName: string; businessType: string; currentPlan: PlanTier; subscriptionValidUntil: string | null; isActive: boolean; featureCount: number; maxUsers: number | null; maxProducts: number | null; maxBranches: number; }

export async function upgradePlan(tenantId: string, newPlan: PlanTier, adminId: string, reason?: string, ipAddress?: string): Promise<PlanChangeResult> {
    const tenant = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), Keys.tenantProfileSK());
    if (!tenant) throw new Error(`Tenant not found: ${tenantId}`);

    const currentPlan = mapToPlanTier(tenant.subscriptionPlan);
    if (!isValidUpgrade(currentPlan, newPlan)) throw new Error(`Invalid upgrade: ${currentPlan} ? ${newPlan}`);

    const limits = PLAN_LIMITS[newPlan];
    const now = new Date().toISOString();

    await updateItem(Keys.tenantPK(tenantId), Keys.tenantProfileSK(), {
        updateExpression: 'SET subscriptionPlan = :plan, planStatus = :status, maxUsers = :mu, maxProducts = :mp, updatedAt = :now',
        expressionAttributeValues: { ':plan': newPlan, ':status': 'active', ':mu': limits.maxUsers, ':mp': limits.maxProducts, ':now': now },
    });

    await putItem({
        PK: Keys.tenantPK(tenantId), SK: `PLANHISTORY#${now}`,
        entityType: 'PLAN_HISTORY', id: uuidv4(), tenantId,
        previousPlan: currentPlan, newPlan, changeType: 'upgrade',
        changedBy: adminId, changeReason: reason || `Admin upgrade: ${currentPlan} ? ${newPlan}`,
        metadata: { previous_limits: PLAN_LIMITS[currentPlan], new_limits: limits },
        createdAt: now,
        // LOW-004 FIX: Include IP for audit trail
        ...(ipAddress ? { ipAddress } : {}),
        // LOW-005 FIX: TTL auto-deletes after 2 years to prevent unbounded growth
        TTL: Math.floor(Date.now() / 1000) + (2 * 365 * 24 * 60 * 60),
    });

    await invalidateManifest(tenantId);
    const manifest = await regenerateManifest(tenantId);

    // Update Cognito user attribute so JWT carries correct plan
    await updateCognitoPlan(tenant.cognitoUserId || tenant.ownerSub, newPlan);

    // Sync to SLS backend with retry (awaited, not fire-and-forget)
    await syncToSlsBackendWithRetry(tenantId, newPlan);

    // ENHANCED: Push WebSocket notification to desktop clients
    const { broadcastManifestInvalidated } = await import('./websocket.service');
    await broadcastManifestInvalidated(
        tenantId,
        `Plan upgraded: ${currentPlan} ? ${newPlan}`,
        adminId,
    ).catch((err: Error) => logger.warn('WebSocket broadcast failed (non-critical)', { error: err.message }));

    // ENHANCED: Write audit log
    const { auditPlanChange } = await import('./audit-log.service');
    await auditPlanChange(adminId, tenantId, currentPlan, newPlan, {
        reason: reason || 'Admin initiated upgrade',
        ipAddress,
        manifestHash: manifest.manifestHash,
    }).catch((err: Error) => logger.warn('Audit log failed (non-critical)', { error: err.message }));

    logger.info('Plan upgraded', { tenantId, from: currentPlan, to: newPlan, adminId });

    return { success: true, tenantId, previousPlan: currentPlan, newPlan, manifest, message: `Plan upgraded from ${currentPlan} to ${newPlan}.` };
}

export async function downgradePlan(tenantId: string, newPlan: PlanTier, adminId: string, reason?: string, ipAddress?: string): Promise<PlanChangeResult> {
    const tenant = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), Keys.tenantProfileSK());
    if (!tenant) throw new Error(`Tenant not found: ${tenantId}`);

    const currentPlan = mapToPlanTier(tenant.subscriptionPlan);
    if (!isValidDowngrade(currentPlan, newPlan)) throw new Error(`Invalid downgrade: ${currentPlan} ? ${newPlan}`);

    const newLimits = PLAN_LIMITS[newPlan];
    const now = new Date().toISOString();

    // Warn if current usage exceeds new plan limits (non-blocking)
    if (newLimits.maxUsers !== null && tenant.activeUserCount > newLimits.maxUsers) {
        logger.warn('Downgrade: active users exceed new limit', {
            tenantId, activeUsers: tenant.activeUserCount, newMax: newLimits.maxUsers,
        });
    }

    await updateItem(Keys.tenantPK(tenantId), Keys.tenantProfileSK(), {
        updateExpression: 'SET subscriptionPlan = :plan, planStatus = :status, maxUsers = :mu, maxProducts = :mp, updatedAt = :now',
        expressionAttributeValues: { ':plan': newPlan, ':status': 'active', ':mu': newLimits.maxUsers, ':mp': newLimits.maxProducts, ':now': now },
    });

    await putItem({
        PK: Keys.tenantPK(tenantId), SK: `PLANHISTORY#${now}`,
        entityType: 'PLAN_HISTORY', id: uuidv4(), tenantId,
        previousPlan: currentPlan, newPlan, changeType: 'downgrade',
        changedBy: adminId, changeReason: reason || `Admin downgrade: ${currentPlan} ? ${newPlan}`,
        metadata: { previous_limits: PLAN_LIMITS[currentPlan], new_limits: newLimits, warning: 'Data preserved. Features restricted.' },
        createdAt: now,
        // LOW-004 FIX: Include IP for audit trail
        ...(ipAddress ? { ipAddress } : {}),
        // LOW-005 FIX: TTL auto-deletes after 2 years
        TTL: Math.floor(Date.now() / 1000) + (2 * 365 * 24 * 60 * 60),
    });

    await invalidateManifest(tenantId);
    const manifest = await regenerateManifest(tenantId);

    // Update Cognito user attribute so JWT carries correct plan
    await updateCognitoPlan(tenant.cognitoUserId || tenant.ownerSub, newPlan, 'active');

    // Sync to SLS backend with retry
    await syncToSlsBackendWithRetry(tenantId, newPlan);

    // ENHANCED: Push WebSocket notification to desktop clients
    const { broadcastManifestInvalidated } = await import('./websocket.service');
    await broadcastManifestInvalidated(
        tenantId,
        `Plan downgraded: ${currentPlan} ? ${newPlan}`,
        adminId,
    ).catch((err: Error) => logger.warn('WebSocket broadcast failed (non-critical)', { error: err.message }));

    // ENHANCED: Write audit log
    const { auditPlanChange } = await import('./audit-log.service');
    await auditPlanChange(adminId, tenantId, currentPlan, newPlan, {
        reason: reason || 'Admin initiated downgrade',
        ipAddress,
        manifestHash: manifest.manifestHash,
        downgradeWarning: (newLimits.maxUsers !== null && tenant.activeUserCount > newLimits.maxUsers)
            ? `Active users (${tenant.activeUserCount}) exceed new limit (${newLimits.maxUsers})`
            : undefined,
    }).catch((err: Error) => logger.warn('Audit log failed (non-critical)', { error: err.message }));

    logger.info('Plan downgraded', { tenantId, from: currentPlan, to: newPlan, adminId });

    return { success: true, tenantId, previousPlan: currentPlan, newPlan, manifest, message: `Plan downgraded from ${currentPlan} to ${newPlan}.` };
}

export async function getPlanHistory(tenantId: string): Promise<PlanHistoryEntry[]> {
    const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PLANHISTORY#', { scanIndexForward: false, limit: 50 });
    return result.items.map(r => ({ id: r.id, tenant_id: r.tenantId, previous_plan: r.previousPlan, new_plan: r.newPlan, change_type: r.changeType, changed_by: r.changedBy, change_reason: r.changeReason, metadata: r.metadata || {}, created_at: r.createdAt }));
}

export async function getTenantPlanStatus(tenantId: string): Promise<TenantPlanStatus> {
    const tenant = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), Keys.tenantProfileSK());
    if (!tenant) throw new Error(`Tenant not found: ${tenantId}`);

    const planTier = mapToPlanTier(tenant.subscriptionPlan);
    const limits = PLAN_LIMITS[planTier];
    const { getAllowedFeatures } = require('../config/plan-feature-registry');
    const features = getAllowedFeatures(planTier, tenant.businessType);

    return { tenantId, tenantName: tenant.name, businessType: tenant.businessType, currentPlan: planTier, subscriptionValidUntil: tenant.subscriptionValidUntil || null, isActive: tenant.isActive !== false, featureCount: features.length, maxUsers: limits.maxUsers, maxProducts: limits.maxProducts, maxBranches: limits.maxBranches };
}

export async function listTenantPlans(params: { page?: number; limit?: number; planFilter?: PlanTier; businessTypeFilter?: string }): Promise<{ data: TenantPlanStatus[]; pagination: { page: number; limit: number; total: number; totalPages: number } }> {
    // Scan all tenants via GSI (ENTITY#TENANT)
    const result = await queryItems<Record<string, any>>('ENTITY#TENANT', undefined, { indexName: 'GSI1' });
    let items = result.items.filter(t => t.isActive !== false);
    if (params.planFilter) items = items.filter(t => t.subscriptionPlan === params.planFilter);
    if (params.businessTypeFilter) items = items.filter(t => t.businessType === params.businessTypeFilter);

    const total = items.length;
    const page = params.page || 1;
    const limit = params.limit || 25;
    const offset = (page - 1) * limit;
    const paged = items.slice(offset, offset + limit);

    const data = paged.map((tenant: any) => {
        const planTier = mapToPlanTier(tenant.subscriptionPlan);
        const limits = PLAN_LIMITS[planTier];
        return { tenantId: tenant.tenantId || tenant.id, tenantName: tenant.name, businessType: tenant.businessType, currentPlan: planTier, subscriptionValidUntil: tenant.subscriptionValidUntil || null, isActive: tenant.isActive !== false, featureCount: 0, maxUsers: limits.maxUsers, maxProducts: limits.maxProducts, maxBranches: limits.maxBranches };
    });

    return { data, pagination: { page, limit, total, totalPages: Math.ceil(total / limit) } };
}

/** Update Cognito custom attribute for plan tier and status */
async function updateCognitoPlan(cognitoUsername: string | undefined, newPlan: PlanTier, planStatus: string = 'active'): Promise<void> {
    if (!cognitoUsername || !USER_POOL_ID) {
        logger.warn('Cannot update Cognito plan: missing username or UserPoolId', { cognitoUsername: !!cognitoUsername, hasPoolId: !!USER_POOL_ID });
        return;
    }
    // HIGH-008 FIX: Retry once before failing. If both attempts fail, throw
    // to prevent silent plan desync (JWT carries old plan until re-auth).
    for (let attempt = 0; attempt < 2; attempt++) {
        try {
            await cognitoClient.send(new AdminUpdateUserAttributesCommand({
                UserPoolId: USER_POOL_ID,
                Username: cognitoUsername,
                UserAttributes: [
                    { Name: 'custom:plan', Value: newPlan },
                    { Name: 'custom:plan_status', Value: planStatus },
                ],
            }));
            logger.info('Cognito plan attributes updated', { cognitoUsername, newPlan, planStatus });
            return;
        } catch (err) {
            logger.error(`Cognito plan sync attempt ${attempt + 1} failed`, {
                error: (err as Error).message, cognitoUsername, newPlan,
            });
            if (attempt === 0) await new Promise(r => setTimeout(r, 500));
        }
    }
    // Both attempts failed � throw so caller knows plan is desynced
    throw new Error(`Failed to sync plan to Cognito after 2 attempts for user ${cognitoUsername}`);
}

/** Sync to SLS backend with 1 retry and HMAC request signing (MED-011 FIX) */
async function syncToSlsBackendWithRetry(tenantId: string, newPlan: PlanTier): Promise<void> {
    const slsUrl = config.extendedApp.slsBackendUrl;
    if (!slsUrl) return;

    const secret = config.secrets.internalApiSecret;

    for (let attempt = 0; attempt < 2; attempt++) {
        try {
            // MED-011 FIX: HMAC request signing instead of static secret header
            const timestamp = new Date().toISOString();
            const payload = JSON.stringify({ tenant_id: tenantId, new_tier: newPlan, timestamp });
            const signature = createHmac('sha256', secret)
                .update(payload)
                .digest('hex');

            const response = await fetch(`${slsUrl}/api/admin/license/update-tier`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-request-timestamp': timestamp,
                    'x-request-signature': signature,
                },
                body: payload,
                signal: AbortSignal.timeout(5000), // 5s timeout per attempt
            });
            if (response.ok) {
                logger.info('Plan synced to sls/backend', { tenantId, newPlan, attempt });
                return;
            }
            logger.warn('sls/backend sync non-200', { tenantId, status: response.status, attempt });
        } catch (err) {
            logger.error('sls/backend sync attempt failed', { tenantId, attempt, error: (err as Error).message });
        }
        // Wait 500ms before retry
        if (attempt === 0) await new Promise(r => setTimeout(r, 500));
    }
    logger.error('sls/backend sync exhausted retries', { tenantId, newPlan });
}
