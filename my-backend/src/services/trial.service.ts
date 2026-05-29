// ============================================================================
// Trial Service — 15-Day Free Trial Management
// ============================================================================
// Handles trial lifecycle:
//   - 15-day Premium trial on new signup
//   - Trial status checks
//   - Auto-downgrade to Basic on expiry
//   - Notification scheduling (7, 3, 1 days before expiry)
//
// Triggered by:
//   - EventBridge daily cron (trial-expiry handler)
//   - Manual admin downgrade
// ============================================================================

import { Keys, getItem, putItem, updateItem, queryItems } from '../config/dynamodb.config';
import { CognitoIdentityProviderClient, AdminUpdateUserAttributesCommand } from '@aws-sdk/client-cognito-identity-provider';
import { logger } from '../utils/logger';
import { SubscriptionPlan } from '../types/tenant.types';
import { PlanTier } from '../config/plan-feature-registry';
import { regenerateManifest } from './feature-manifest.service';
import { invalidateManifest } from '../config/manifest-cache';
import { config } from '../config/environment';

const cognitoClient = new CognitoIdentityProviderClient({
    region: config.aws.region,
});
const USER_POOL_ID = config.cognito.userPoolId;

export interface TrialStatus {
    isInTrial: boolean;
    daysRemaining: number;
    trialEndDate: string;
    planStatus: string;
}

export interface DowngradeResult {
    success: boolean;
    tenantId: string;
    previousPlan: PlanTier;
    newPlan: PlanTier;
    reason: string;
}

/**
 * Get trial status for a tenant
 */
export async function getTrialStatus(tenantId: string): Promise<TrialStatus | null> {
    const tenant = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        Keys.tenantProfileSK()
    );

    if (!tenant) {
        logger.warn('Tenant not found for trial status check', { tenantId });
        return null;
    }

    const planStatus = tenant.planStatus || 'active';
    const trialEndDate = tenant.trialEndDate;

    if (planStatus !== 'trial' || !trialEndDate) {
        return {
            isInTrial: false,
            daysRemaining: 0,
            trialEndDate: trialEndDate || '',
            planStatus,
        };
    }

    const now = new Date();
    const endDate = new Date(trialEndDate);
    const diffTime = endDate.getTime() - now.getTime();
    const daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    return {
        isInTrial: true,
        daysRemaining: Math.max(0, daysRemaining),
        trialEndDate,
        planStatus,
    };
}

/**
 * Check and auto-downgrade expired trials
 * Called by daily EventBridge cron
 */
export async function processExpiredTrials(): Promise<{
    processed: number;
    downgraded: number;
    errors: number;
    details: DowngradeResult[];
}> {
    const now = new Date().toISOString();
    const results: DowngradeResult[] = [];
    let processed = 0;
    let downgraded = 0;
    let errors = 0;

    // Query all tenants with trial status
    // Note: Using GSI1 to find all tenants, then filter by planStatus
    const tenantList = await queryItems<Record<string, any>>('ENTITY#TENANT', undefined, {
        indexName: 'GSI1',
    });

    const trialTenants = tenantList.items.filter(
        (t) => t.planStatus === 'trial' && t.trialEndDate
    );

    logger.info('Processing expired trials', {
        totalTenants: tenantList.items.length,
        trialTenants: trialTenants.length,
    });

    for (const tenant of trialTenants) {
        processed++;
        const tenantId = tenant.tenantId || tenant.id;
        const trialEndDate = tenant.trialEndDate;

        // Check if trial has expired
        if (trialEndDate && new Date(trialEndDate) <= new Date(now)) {
            try {
                const result = await downgradeExpiredTrial(tenantId, tenant);
                results.push(result);

                if (result.success) {
                    downgraded++;
                    logger.info('Auto-downgraded expired trial', {
                        tenantId,
                        previousPlan: result.previousPlan,
                        newPlan: result.newPlan,
                    });
                } else {
                    errors++;
                    logger.error('Failed to downgrade expired trial', {
                        tenantId,
                        error: result.reason,
                    });
                }
            } catch (err) {
                errors++;
                logger.error('Exception during trial downgrade', {
                    tenantId,
                    error: (err as Error).message,
                });
            }
        }
    }

    return {
        processed,
        downgraded,
        errors,
        details: results,
    };
}

/**
 * Downgrade a single expired trial to Basic plan
 */
async function downgradeExpiredTrial(
    tenantId: string,
    tenant: Record<string, any>
): Promise<DowngradeResult> {
    const now = new Date().toISOString();
    const previousPlan = tenant.subscriptionPlan || 'premium';

    try {
        // Update tenant record to Basic plan
        await updateItem(
            Keys.tenantPK(tenantId),
            Keys.tenantProfileSK(),
            {
                updateExpression: `SET subscriptionPlan = :basic,
                                    planStatus = :expired,
                                    planEndDate = :now,
                                    updatedAt = :now,
                                    maxUsers = :maxUsers,
                                    maxProducts = :maxProducts`,
                expressionAttributeValues: {
                    ':basic': SubscriptionPlan.BASIC,
                    ':expired': 'expired',
                    ':now': now,
                    ':maxUsers': 3,
                    ':maxProducts': 500,
                },
            }
        );

        // Write audit log
        await putItem({
            PK: Keys.tenantPK(tenantId),
            SK: `PLANHISTORY#${now}`,
            entityType: 'PLAN_HISTORY',
            id: crypto.randomUUID(),
            tenantId,
            previousPlan,
            newPlan: SubscriptionPlan.BASIC,
            changeType: 'auto_downgrade',
            changedBy: 'system',
            changeReason: 'Trial period expired - auto-downgraded to Basic',
            metadata: {
                trialEndDate: tenant.trialEndDate,
                autoTriggered: true,
            },
            createdAt: now,
            TTL: Math.floor(Date.now() / 1000) + 2 * 365 * 24 * 60 * 60, // 2 years
        });

        // Update Cognito attributes
        await updateCognitoAttributes(tenant.cognitoUserId || tenant.ownerSub, {
            plan: 'basic',
            plan_status: 'expired',
        });

        // Invalidate and regenerate manifest
        await invalidateManifest(tenantId);
        const newManifest = await regenerateManifest(tenantId);

        // Broadcast WebSocket notification
        const { broadcastManifestInvalidated } = await import('./websocket.service');
        await broadcastManifestInvalidated(
            tenantId,
            `Trial expired. Downgraded to Basic plan.`,
            'system'
        ).catch((err: Error) => {
            logger.warn('WebSocket broadcast failed (non-critical)', {
                error: err.message,
            });
        });

        return {
            success: true,
            tenantId,
            previousPlan: previousPlan as PlanTier,
            newPlan: PlanTier.BASIC,
            reason: 'Trial expired - auto-downgraded',
        };
    } catch (err) {
        return {
            success: false,
            tenantId,
            previousPlan: previousPlan as PlanTier,
            newPlan: PlanTier.BASIC,
            reason: (err as Error).message,
        };
    }
}

/**
 * Get tenants approaching trial expiry (for notification scheduling)
 * Returns tenants with 7, 3, or 1 days remaining
 */
export async function getTrialsForNotification(
    daysThreshold: number
): Promise<Array<{ tenantId: string; email: string; daysRemaining: number; trialEndDate: string }>> {
    const targetDate = new Date();
    targetDate.setDate(targetDate.getDate() + daysThreshold);
    const targetDateStr = targetDate.toISOString().split('T')[0];

    // Query all trial tenants
    const tenantList = await queryItems<Record<string, any>>('ENTITY#TENANT', undefined, {
        indexName: 'GSI1',
    });

    const trialTenants = tenantList.items.filter(
        (t) => t.planStatus === 'trial' && t.trialEndDate
    );

    const result: Array<{ tenantId: string; email: string; daysRemaining: number; trialEndDate: string }> = [];

    for (const tenant of trialTenants) {
        const trialEnd = new Date(tenant.trialEndDate);
        const trialEndStr = trialEnd.toISOString().split('T')[0];

        if (trialEndStr === targetDateStr) {
            const now = new Date();
            const diffTime = trialEnd.getTime() - now.getTime();
            const daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

            result.push({
                tenantId: tenant.tenantId || tenant.id,
                email: tenant.email || '',
                daysRemaining,
                trialEndDate: tenant.trialEndDate,
            });
        }
    }

    return result;
}

/**
 * Update Cognito custom attributes
 */
async function updateCognitoAttributes(
    cognitoUsername: string | undefined,
    attributes: { plan?: string; plan_status?: string }
): Promise<void> {
    if (!cognitoUsername || !USER_POOL_ID) {
        logger.warn('Cannot update Cognito attributes: missing username or UserPoolId', {
            cognitoUsername: !!cognitoUsername,
            hasPoolId: !!USER_POOL_ID,
        });
        return;
    }

    const userAttributes: Array<{ Name: string; Value: string }> = [];
    if (attributes.plan) {
        userAttributes.push({ Name: 'custom:plan', Value: attributes.plan });
    }
    if (attributes.plan_status) {
        userAttributes.push({ Name: 'custom:plan_status', Value: attributes.plan_status });
    }

    if (userAttributes.length === 0) return;

    try {
        await cognitoClient.send(
            new AdminUpdateUserAttributesCommand({
                UserPoolId: USER_POOL_ID,
                Username: cognitoUsername,
                UserAttributes: userAttributes,
            })
        );
        logger.info('Cognito attributes updated', {
            cognitoUsername,
            attributes: Object.keys(attributes),
        });
    } catch (err) {
        logger.error('Failed to update Cognito attributes', {
            cognitoUsername,
            error: (err as Error).message,
        });
        throw err;
    }
}
