// ============================================================================
// Feature Manifest Service — Signed JWT Manifest (DynamoDB)
// ============================================================================
// v2 Architecture: PlanConfig (hybrid) + License manualOverrides
//
// Effective feature derivation formula:
//   baseFeatures = PlanConfig(plan).defaultFeatures
//   allowedPerBusiness = intersect(baseFeatures, PLAN_BUSINESS_FEATURES[plan][businessType])
//   effective = (allowedPerBusiness
//                ∪ license.manualOverrides.added
//                \ license.manualOverrides.removed)
//
// Limits hierarchy (most specific wins):
//   1. license.storageLimitGB / license.apiRateLimit (per-license hard caps)
//   2. PlanConfig(plan).limits (DB override of code defaults)
//   3. PLAN_LIMITS[plan] (code defaults)
// ============================================================================

import * as crypto from 'crypto';
import * as jwt from 'jsonwebtoken';
import { Keys, getItem, putItem } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { BusinessType } from '../types/tenant.types';
import {
    PlanTier,
    FeatureKey,
    getAllowedFeatures,
    mapToPlanTier,
    PLAN_LIMITS,
    PlanLimits,
    PLAN_BUSINESS_FEATURES,
} from '../config/plan-feature-registry';
import { CachedManifest, getCachedManifest, setCachedManifest, invalidateManifest } from '../config/manifest-cache';
import { getEffectivePlanConfig } from './plan-config.service';

import { config } from '../config/environment';

const MANIFEST_JWT_SECRET = config.secrets.manifestJwtSecret;
const MANIFEST_TTL_HOURS = 1;

export interface FeatureManifest {
    tenantId: string;
    planTier: PlanTier;
    businessType: BusinessType;
    allowedFeatures: FeatureKey[];
    limits: PlanLimits;
    manifestHash: string;
    signedToken: string;
    issuedAt: string;
    expiresAt: string;
    /** Source of truth flags for debugging */
    _meta?: {
        planConfigSource: 'code' | 'db_override' | 'db_full';
        licenseOverridesApplied: boolean;
    };
}

export interface DecodedManifest {
    tenant_id: string;
    plan_tier: PlanTier;
    business_type: BusinessType;
    allowed_features: FeatureKey[];
    limits: PlanLimits;
    manifest_hash: string;
    iat: number;
    exp: number;
}

/**
 * Compute effective features using the v2 derivation formula:
 * (PlanConfig.default ∩ business-specific) ∪ added \ removed
 */
function computeEffectiveFeatures(
    planTier: PlanTier,
    businessType: BusinessType,
    planConfigFeatures: FeatureKey[],
    manualOverrides: { added: string[]; removed: string[] },
): FeatureKey[] {
    // 1. Start with PlanConfig default features
    let base = new Set<FeatureKey>(planConfigFeatures);

    // 2. Intersect with business-type-specific features (hard isolation rule)
    // Business types can only access features explicitly allowed for that vertical
    const businessFeatures = PLAN_BUSINESS_FEATURES[planTier]?.[businessType] ?? [];
    if (businessFeatures.length > 0) {
        const businessSet = new Set<FeatureKey>(businessFeatures);
        // Keep only features that are in BOTH the plan core AND the business map
        // UNLESS the feature is explicitly manually added (special agreement)
        for (const f of Array.from(base)) {
            if (!businessSet.has(f) && !manualOverrides.added.includes(f)) {
                base.delete(f);
            }
        }
    }

    // 3. Apply manual overrides from license
    for (const f of manualOverrides.added) {
        base.add(f as FeatureKey);
    }
    for (const f of manualOverrides.removed) {
        base.delete(f as FeatureKey);
    }

    return Array.from(base);
}

/**
 * Compute effective limits using hierarchy:
 * license limits → PlanConfig limits → code defaults
 */
function computeEffectiveLimits(
    planTier: PlanTier,
    planConfigLimits: PlanLimits,
    licenseLimits: { storageLimitGB?: number | null; apiRateLimit?: number | null },
): PlanLimits {
    return {
        maxUsers: planConfigLimits.maxUsers,
        maxProducts: planConfigLimits.maxProducts,
        maxBranches: planConfigLimits.maxBranches,
        maxDevices: planConfigLimits.maxDevices,
        maxBusinessTypes: planConfigLimits.maxBusinessTypes,
        // Per-license hard caps (if set on license record)
        storageLimitGB: licenseLimits.storageLimitGB ?? planConfigLimits.storageLimitGB ?? null,
        apiRateLimit: licenseLimits.apiRateLimit ?? planConfigLimits.apiRateLimit ?? null,
    } as PlanLimits;
}

/**
 * Generate a fresh manifest for a tenant using the v2 derivation pipeline.
 * This reads PlanConfig (hybrid) + License manualOverrides, computes effective
 * features, signs a JWT, and persists to DynamoDB.
 */
export async function generateManifest(
    tenantId: string,
    planTier: PlanTier,
    businessType: BusinessType,
    licenseRecord?: Record<string, any> | null,
): Promise<FeatureManifest> {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + MANIFEST_TTL_HOURS * 60 * 60 * 1000);

    // 1. Fetch PlanConfig (hybrid: code defaults + DB overrides)
    const planConfig = await getEffectivePlanConfig(planTier, businessType);

    // 2. Extract manual overrides from license (if available)
    const manualOverrides = {
        added: licenseRecord?.manualOverrides?.added ?? [],
        removed: licenseRecord?.manualOverrides?.removed ?? [],
    };

    // 3. Compute effective features
    const allowedFeatures = computeEffectiveFeatures(
        planTier,
        businessType,
        planConfig.defaultFeatures,
        manualOverrides,
    );

    // 4. Compute effective limits
    const limits = computeEffectiveLimits(
        planTier,
        planConfig.limits,
        {
            storageLimitGB: licenseRecord?.storageLimitGB,
            apiRateLimit: licenseRecord?.apiRateLimit,
        },
    );

    // 5. Generate manifest hash and JWT
    const manifestHash = crypto
        .createHash('sha256')
        .update(JSON.stringify({ tenantId, planTier, businessType, allowedFeatures }))
        .digest('hex')
        .substring(0, 16);

    const payload = {
        tenant_id: tenantId,
        plan_tier: planTier,
        business_type: businessType,
        allowed_features: allowedFeatures,
        limits,
        manifest_hash: manifestHash,
    };

    const signedToken = jwt.sign(payload, MANIFEST_JWT_SECRET, {
        expiresIn: `${MANIFEST_TTL_HOURS}h`,
        issuer: 'dukanx-plan-engine',
        subject: tenantId,
    });

    const manifest: FeatureManifest = {
        tenantId,
        planTier,
        businessType,
        allowedFeatures,
        limits,
        manifestHash,
        signedToken,
        issuedAt: now.toISOString(),
        expiresAt: expiresAt.toISOString(),
        _meta: {
            planConfigSource: planConfig.source,
            licenseOverridesApplied: manualOverrides.added.length > 0 || manualOverrides.removed.length > 0,
        },
    };

    logger.info('Feature manifest generated (v2)', {
        tenantId,
        planTier,
        businessType,
        featureCount: allowedFeatures.length,
        planConfigSource: planConfig.source,
        overridesApplied: manifest._meta?.licenseOverridesApplied ?? false,
    });

    return manifest;
}

export function verifyManifest(token: string): DecodedManifest {
    return jwt.verify(token, MANIFEST_JWT_SECRET, { issuer: 'dukanx-plan-engine' }) as DecodedManifest;
}

/** Legacy shim for callers expecting the old sync signature. DEPRECATED. */
export function generateManifestSync(tenantId: string, planTier: PlanTier, businessType: BusinessType): FeatureManifest {
    // This is a compatibility shim. Real generation is now async via regenerateManifest.
    const allowedFeatures = getAllowedFeatures(planTier, businessType);
    const limits = PLAN_LIMITS[planTier];
    const manifestHash = crypto.createHash('sha256').update(JSON.stringify({ tenantId, planTier, businessType, allowedFeatures })).digest('hex').substring(0, 16);
    const now = new Date();
    const expiresAt = new Date(now.getTime() + MANIFEST_TTL_HOURS * 60 * 60 * 1000);
    const payload = { tenant_id: tenantId, plan_tier: planTier, business_type: businessType, allowed_features: allowedFeatures, limits, manifest_hash: manifestHash };
    const signedToken = jwt.sign(payload, MANIFEST_JWT_SECRET, { expiresIn: `${MANIFEST_TTL_HOURS}h`, issuer: 'dukanx-plan-engine', subject: tenantId });
    return { tenantId, planTier, businessType, allowedFeatures, limits, manifestHash, signedToken, issuedAt: now.toISOString(), expiresAt: expiresAt.toISOString() };
}

async function persistManifest(manifest: FeatureManifest): Promise<void> {
    await putItem({
        PK: Keys.tenantPK(manifest.tenantId),
        SK: 'MANIFEST#FEATURE',
        entityType: 'FEATURE_MANIFEST',
        tenantId: manifest.tenantId,
        planTier: manifest.planTier,
        businessType: manifest.businessType,
        allowedFeatures: manifest.allowedFeatures,
        limits: manifest.limits,
        manifestHash: manifest.manifestHash,
        signedToken: manifest.signedToken,
        expiresAt: manifest.expiresAt,
        updatedAt: new Date().toISOString(),
        // Persist metadata for debugging
        _meta: manifest._meta,
    });
}

export async function getManifestForTenant(tenantId: string): Promise<FeatureManifest> {
    // 1. Try in-memory/Redis cache
    const cached = await getCachedManifest(tenantId);
    if (cached && new Date(cached.expiresAt) > new Date()) {
        return {
            tenantId: cached.tenantId,
            planTier: cached.planTier as PlanTier,
            businessType: cached.businessType as BusinessType,
            allowedFeatures: cached.allowedFeatures as FeatureKey[],
            limits: (cached as any).limits ?? PLAN_LIMITS[cached.planTier as PlanTier],
            manifestHash: cached.manifestHash,
            signedToken: cached.signedToken,
            issuedAt: '',
            expiresAt: cached.expiresAt,
        };
    }

    // 2. Try DynamoDB
    const dbItem = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), 'MANIFEST#FEATURE');
    if (dbItem && dbItem.expiresAt && new Date(dbItem.expiresAt) > new Date()) {
        const manifest: FeatureManifest = {
            tenantId: dbItem.tenantId,
            planTier: dbItem.planTier as PlanTier,
            businessType: dbItem.businessType as BusinessType,
            allowedFeatures: dbItem.allowedFeatures as FeatureKey[],
            limits: dbItem.limits ?? PLAN_LIMITS[dbItem.planTier as PlanTier],
            manifestHash: dbItem.manifestHash,
            signedToken: dbItem.signedToken,
            issuedAt: dbItem.updatedAt,
            expiresAt: dbItem.expiresAt,
            _meta: dbItem._meta,
        };
        await setCachedManifest(tenantId, {
            tenantId,
            planTier: manifest.planTier,
            businessType: manifest.businessType,
            allowedFeatures: manifest.allowedFeatures,
            manifestHash: manifest.manifestHash,
            signedToken: manifest.signedToken,
            expiresAt: manifest.expiresAt,
        });
        return manifest;
    }

    // 3. Generate new (v2 derivation pipeline)
    return regenerateManifest(tenantId);
}

export async function regenerateManifest(tenantId: string): Promise<FeatureManifest> {
    // Parallel fetch of tenant profile + license record
    const [tenant, licenseRecord] = await Promise.all([
        getItem<Record<string, any>>(Keys.tenantPK(tenantId), Keys.tenantProfileSK()),
        getItem<Record<string, any>>(Keys.tenantPK(tenantId), Keys.tenantLicenseSK()),
    ]);

    if (!tenant) throw new Error(`Tenant not found: ${tenantId}`);

    const planTier = mapToPlanTier(tenant.subscriptionPlan);
    const businessType = (tenant.businessType) as BusinessType;

    // v2: Use async generateManifest with PlanConfig + license overrides
    const manifest = await generateManifest(tenantId, planTier, businessType, licenseRecord);

    await persistManifest(manifest);
    await invalidateManifest(tenantId);
    await setCachedManifest(tenantId, {
        tenantId,
        planTier: manifest.planTier,
        businessType: manifest.businessType,
        allowedFeatures: manifest.allowedFeatures,
        manifestHash: manifest.manifestHash,
        signedToken: manifest.signedToken,
        expiresAt: manifest.expiresAt,
    });

    logger.info('Feature manifest regenerated (v2)', {
        tenantId,
        planTier,
        businessType,
        featureCount: manifest.allowedFeatures.length,
        overridesApplied: manifest._meta?.licenseOverridesApplied,
    });

    return manifest;
}

export async function isFeatureAllowedForTenant(tenantId: string, feature: FeatureKey): Promise<boolean> {
    const cached = await getCachedManifest(tenantId);
    if (cached) return cached.allowedFeatures.includes(feature);
    const manifest = await getManifestForTenant(tenantId);
    return manifest.allowedFeatures.includes(feature);
}

/**
 * Admin utility: force regenerate manifest for a tenant.
 * Used by plan upgrade/downgrade and manual override flows.
 */
export async function forceRegenerateManifest(tenantId: string, triggeredBy: string): Promise<FeatureManifest> {
    logger.info('Force manifest regeneration requested', { tenantId, triggeredBy });
    await invalidateManifest(tenantId);
    return regenerateManifest(tenantId);
}
