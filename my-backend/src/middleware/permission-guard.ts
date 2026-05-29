// ============================================================================
// Permission Guard Middleware — Combined Role + Plan Enforcement
// ============================================================================
// Uses PermissionMatrix as single source of truth.
// Both role AND plan must pass. Returns 403 with actionable error.
// ============================================================================

import { AuthContext } from '../types/tenant.types';
import { checkPermission } from '../config/permission-matrix';
import { mapToPlanTier } from '../config/plan-feature-registry';
import { getCachedManifest } from '../config/manifest-cache';
import { logger } from '../utils/logger';
import { Keys, getItem, putItem } from '../config/dynamodb.config';
import { v4 as uuidv4 } from 'uuid';

/**
 * Validate that user has BOTH sufficient role AND plan for a feature.
 * Throws 403 with descriptive error if either check fails.
 */
export async function validatePermission(
    auth: AuthContext,
    feature: string,
    correlationId: string,
    requestPath: string,
): Promise<void> {
    // Resolve plan tier
    let planTier: string;
    if (auth.planTier) {
        planTier = mapToPlanTier(auth.planTier);
    } else {
        const cached = await getCachedManifest(auth.tenantId);
        if (cached) {
            planTier = cached.planTier;
        } else {
            const tenant = await getItem<Record<string, any>>(
                Keys.tenantPK(auth.tenantId),
                Keys.tenantProfileSK(),
            );
            planTier = tenant ? mapToPlanTier(tenant.subscriptionPlan) : 'basic';
        }
    }

    const result = checkPermission(feature, auth.role, planTier);

    if (!result.allowed) {
        // Audit log
        const now = new Date().toISOString();
        logger.error('PERMISSION DENIED', {
            userId: auth.sub, tenantId: auth.tenantId,
            role: auth.role, planTier, feature, reason: result.reason,
            requestPath, correlationId,
        });

        try {
            await putItem({
                PK: Keys.tenantPK(auth.tenantId),
                SK: `PERMAUDIT#${now}#${uuidv4().substring(0, 8)}`,
                entityType: 'PERMISSION_AUDIT',
                tenantId: auth.tenantId, userId: auth.sub,
                eventType: 'permission_denied', severity: 'HIGH',
                feature, role: auth.role, planTier,
                reason: result.reason, requestPath, correlationId,
                createdAt: now,
            });
        } catch { /* non-critical */ }

        const err: any = new Error(
            result.upgradeTo
                ? `Feature "${feature}" requires ${result.upgradeTo} plan. Upgrade to access. Contact your administrator.`
                : result.reason || `Permission denied for "${feature}".`
        );
        err.statusCode = 403;
        err.code = result.upgradeTo ? 'PLAN_UPGRADE_REQUIRED' : 'ROLE_INSUFFICIENT';
        err.upgradeTo = result.upgradeTo;
        throw err;
    }
}
