// ============================================================================
// Plan Guard Middleware — Feature-Level Access Control (DynamoDB)
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { AuthContext } from '../types/tenant.types';
import { FeatureKey, PlanTier, isFeatureAllowed, mapToPlanTier } from '../config/plan-feature-registry';
import { getCachedManifest } from '../config/manifest-cache';
import { logger } from '../utils/logger';
import { Keys, getItem, putItem } from '../config/dynamodb.config';
import { v4 as uuidv4 } from 'uuid';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';
import { config } from '../config/environment';

const cloudwatchClient = new CloudWatchClient(configureAwsClient({ region: config.aws.region }));

export async function validateFeatureAccess(
    auth: AuthContext,
    requiredFeature: FeatureKey,
    correlationId: string,
    requestPath: string,
): Promise<void> {
    const tenantId = auth.tenantId;

    // Fast path: cached manifest
    const cached = await getCachedManifest(tenantId);
    if (cached) {
        if (cached.allowedFeatures.includes(requiredFeature)) return;
        await logFeatureDenial(auth, requiredFeature, cached.planTier, correlationId, requestPath);
        throwFeatureDenied(requiredFeature);
    }

    // Slow path: registry lookup
    // F002/F004: auth.planTier is now populated from custom:plan JWT claim by cognito-auth.ts.
    // The slow path reads from METADATA#SUBSCRIPTION (planId field), NOT from PROFILE
    // (subscriptionPlan field) — they are different DynamoDB items with different field names.
    let planTier: PlanTier;
    if (auth.planTier) {
        planTier = mapToPlanTier(auth.planTier);
    } else {
        // F002: Read from METADATA#SUBSCRIPTION, field planId
        const subscription = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), 'METADATA#SUBSCRIPTION');
        if (!subscription) {
            // F001: Log a warning — missing row silently falls back to Basic
            logger.warn('No subscription record found for tenant, defaulting to BASIC plan', { tenantId, requestPath });
            planTier = PlanTier.BASIC;
        } else {
            planTier = mapToPlanTier(subscription.planId);
        }
    }

    if (!isFeatureAllowed(planTier, auth.businessType, requiredFeature)) {
        await logFeatureDenial(auth, requiredFeature, planTier, correlationId, requestPath);
        throwFeatureDenied(requiredFeature);
    }
}

function throwFeatureDenied(feature: FeatureKey): never {
    const err: any = new Error(`Feature access denied — your plan does not include "${feature}". Please upgrade.`);
    err.statusCode = 403;
    err.code = 'FEATURE_NOT_IN_PLAN';
    throw err;
}

async function logFeatureDenial(auth: AuthContext, feature: FeatureKey, planTier: string, correlationId: string, requestPath: string): Promise<void> {
    logger.error('PLAN FEATURE ACCESS DENIED', { userId: auth.sub, tenantId: auth.tenantId, planTier, requiredFeature: feature, requestPath, correlationId });

    try {
        await cloudwatchClient.send(new PutMetricDataCommand({
            Namespace: 'DukanX/Security',
            MetricData: [{ MetricName: 'UnauthorizedFeatureAccess', Value: 1, Unit: 'Count', Dimensions: [{ Name: 'TenantId', Value: auth.tenantId }, { Name: 'Feature', Value: feature }, { Name: 'PlanTier', Value: planTier }] }],
        }));
    } catch (metricErr) { logger.warn('Failed to emit feature metric', { error: (metricErr as Error).message }); }

    try {
        const now = new Date().toISOString();
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `PLANAUDIT#${now}#${uuidv4().substring(0, 8)}`,
            entityType: 'PLAN_AUDIT_LOG',
            tenantId: auth.tenantId, userId: auth.sub,
            eventType: 'unauthorized_feature_access', severity: 'HIGH',
            featureKey: feature, requestPath,
            details: { planTier, businessType: auth.businessType, correlationId },
            createdAt: now,
        });
    } catch (dbErr) { logger.warn('Failed to write plan audit', { error: (dbErr as Error).message }); }
}
