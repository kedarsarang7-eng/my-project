// ============================================================================
// Tenant Config Handler — Single bootstrap endpoint for the Flutter Desktop app
// ============================================================================
// GET /tenant/config
//
// Returns the unified payload the desktop client needs on login:
//   {
//     tenantId,
//     businessType,                  // primary business type on this tenant
//     allowedBusinessTypes: string[],// union from the active license
//     plan,                          // 'basic' | 'pro' | 'premium' | 'enterprise'
//     enabledFeatures: string[],     // effective feature keys (manifest + overrides)
//     limits: PlanLimits,
//     licenseStatus,                 // 'active' | 'suspended' | 'expired' | 'revoked'
//     expiryDate,                    // ISO-8601
//     renewalPeriodDays,
//     manualOverrides: {
//       added:   string[],           // features added on top of plan
//       removed: string[],           // features explicitly stripped
//     },
//     manifestHash,                  // short sha256 for cache invalidation
//     signedToken,                   // JWT-signed manifest for offline verification
//     serverTime                     // ISO timestamp for client clock skew check
//   }
//
// SECURITY: tenantId, role, and businessType are taken ONLY from the verified
// JWT. No client-provided tenantId is honoured here.
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { AuthContext } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { getItem, Keys } from '../config/dynamodb.config';
import { getManifestForTenant } from '../services/feature-manifest.service';
import { mapToPlanTier } from '../config/plan-feature-registry';

interface TenantConfigPayload {
    tenantId: string;
    businessType: string;
    allowedBusinessTypes: string[];
    plan: string;
    enabledFeatures: string[];
    limits: {
        maxUsers: number;
        maxProducts: number;
        maxBranches: number;
        maxDevices: number;
        maxBusinessTypes: number;
    };
    licenseStatus: string;
    expiryDate: string | null;
    renewalPeriodDays: number | null;
    storageLimitGB: number | null;
    apiRateLimit: number | null;
    manualOverrides: {
        added: string[];
        removed: string[];
    };
    manifestHash: string;
    signedToken: string;
    serverTime: string;
}

export const get = authorizedHandler(
    [], // any authenticated user — feature gating happens client-side from the payload
    async (
        _event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const tenantId = auth.tenantId;

        // Parallel reads — manifest + license record + tenant profile
        const [manifest, licenseRecord, tenantProfile] = await Promise.all([
            getManifestForTenant(tenantId).catch((err) => {
                logger.warn('Manifest fetch failed in /tenant/config, continuing with fallback', {
                    tenantId,
                    error: (err as Error).message,
                });
                return null;
            }),
            getItem<Record<string, any>>(
                Keys.tenantPK(tenantId),
                Keys.tenantLicenseSK(),
            ),
            getItem<Record<string, any>>(
                Keys.tenantPK(tenantId),
                Keys.tenantProfileSK(),
            ),
        ]);

        if (!tenantProfile) {
            logger.warn('Tenant profile missing during /tenant/config', { tenantId });
            return response.error(404, 'TENANT_NOT_FOUND', 'Tenant profile was not found.');
        }

        // License status — prefer DB license record; fall back to tenant row flag.
        const rawStatus = (licenseRecord?.status
            || licenseRecord?.licenseStatus
            || tenantProfile?.licenseStatus
            || 'active') as string;
        const licenseStatus = String(rawStatus).toLowerCase();

        // Plan — authoritative source is license record, fall back to tenant row.
        const planRaw = (licenseRecord?.plan
            || tenantProfile?.subscriptionPlan
            || 'basic') as string;
        const plan = mapToPlanTier(planRaw);

        // Allowed business types — from license (multi-business support).
        const allowedBusinessTypes: string[] = Array.isArray(licenseRecord?.allowedBusinessTypes)
            && licenseRecord!.allowedBusinessTypes.length > 0
            ? licenseRecord!.allowedBusinessTypes
            : [tenantProfile.businessType || auth.businessType];

        // Manual overrides — stored on the license record per spec.
        // Shape: { added: string[], removed: string[] } — default both to [].
        const manualOverrides = {
            added: Array.isArray(licenseRecord?.manualOverrides?.added)
                ? licenseRecord!.manualOverrides.added
                : [],
            removed: Array.isArray(licenseRecord?.manualOverrides?.removed)
                ? licenseRecord!.manualOverrides.removed
                : [],
        };

        // Effective features = manifest ∪ added \ removed
        // Even if the manifest itself already includes overrides (once Step 7
        // lands), this recomputation is safe: set arithmetic is idempotent.
        const baseFeatures = manifest?.allowedFeatures ?? [];
        const effective = new Set<string>(baseFeatures as string[]);
        for (const f of manualOverrides.added) effective.add(f);
        for (const f of manualOverrides.removed) effective.delete(f);
        const enabledFeatures = [...effective];

        // Hard-block payload fields when license isn't active. Client enforces UX;
        // server-side middleware (plan-guard, cognito-auth) already blocks API calls.
        const effectiveLicenseStatus =
            licenseRecord?.expiresAt && new Date(licenseRecord.expiresAt).getTime() < Date.now()
                ? 'expired'
                : licenseStatus;

        const payload: TenantConfigPayload = {
            tenantId,
            businessType: tenantProfile.businessType || auth.businessType,
            allowedBusinessTypes,
            plan,
            enabledFeatures,
            limits: manifest?.limits ?? {
                maxUsers: 0, maxProducts: 0, maxBranches: 0, maxDevices: 0, maxBusinessTypes: 0,
            },
            licenseStatus: effectiveLicenseStatus,
            expiryDate: licenseRecord?.expiresAt || licenseRecord?.expiryDate || null,
            renewalPeriodDays: typeof licenseRecord?.renewalPeriodDays === 'number'
                ? licenseRecord.renewalPeriodDays
                : null,
            storageLimitGB: typeof licenseRecord?.storageLimitGB === 'number'
                ? licenseRecord.storageLimitGB
                : null,
            apiRateLimit: typeof licenseRecord?.apiRateLimit === 'number'
                ? licenseRecord.apiRateLimit
                : null,
            manualOverrides,
            manifestHash: manifest?.manifestHash ?? '',
            signedToken: manifest?.signedToken ?? '',
            serverTime: new Date().toISOString(),
        };

        return response.success(payload, 200);
    },
);
