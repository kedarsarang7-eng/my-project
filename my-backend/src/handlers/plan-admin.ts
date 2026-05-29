// ============================================================================
// Plan Admin Handler — Admin-Only Plan Management Endpoints
// ============================================================================
// Provides endpoints for super-admins to:
//   - List all tenants with plan info
//   - View tenant plan status
//   - Upgrade/downgrade tenant plans
//   - View plan change history
//   - Get/refresh feature manifests
//
// These endpoints are the ONLY way to change a tenant's plan.
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { AuthContext, UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { PlanTier } from '../config/plan-feature-registry';
import {
    upgradePlan,
    downgradePlan,
    getPlanHistory,
    getTenantPlanStatus,
    listTenantPlans,
} from '../services/plan-management.service';
import {
    getManifestForTenant,
    regenerateManifest,
} from '../services/feature-manifest.service';

// ── GET /admin/plan/tenants — List all tenants with plan info ────────────────

export const listTenants = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (
        event: APIGatewayProxyEventV2,
        _context: Context,
        auth: AuthContext,
    ) => {
        const params = event.queryStringParameters || {};
        const result = await listTenantPlans({
            page: params.page ? parseInt(params.page, 10) : 1,
            limit: params.limit ? parseInt(params.limit, 10) : 25,
            planFilter: params.plan as PlanTier | undefined,
            businessTypeFilter: params.business_type,
        });

        return response.success(result);
    },
);

// ── GET /admin/plan/status/:tenantId — Get a tenant's plan status ────────────

export const getPlanStatus = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (
        event: APIGatewayProxyEventV2,
        _context: Context,
        auth: AuthContext,
    ) => {
        const tenantId = event.pathParameters?.tenantId;
        if (!tenantId) {
            return response.error(400, 'MISSING_TENANT_ID', 'tenantId path parameter is required');
        }

        const status = await getTenantPlanStatus(tenantId);
        return response.success(status);
    },
);

// ── POST /admin/plan/upgrade — Upgrade a tenant's plan ──────────────────────

export const upgrade = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (
        event: APIGatewayProxyEventV2,
        _context: Context,
        auth: AuthContext,
    ) => {
        if (!event.body) {
            return response.error(400, 'MISSING_BODY', 'Request body is required');
        }

        const body = JSON.parse(event.body);
        const { tenantId, newPlan, reason } = body;

        if (!tenantId || !newPlan) {
            return response.error(400, 'MISSING_FIELDS', 'tenantId and newPlan are required');
        }

        // Validate plan tier
        if (!Object.values(PlanTier).includes(newPlan)) {
            return response.error(400, 'INVALID_PLAN', `Plan must be one of: ${Object.values(PlanTier).join(', ')}`);
        }

        const result = await upgradePlan(tenantId, newPlan as PlanTier, auth.sub, reason);

        logger.info('Plan upgrade via admin API', {
            tenantId,
            newPlan,
            adminId: auth.sub,
        });

        return response.success(result);
    },
);

// ── POST /admin/plan/downgrade — Downgrade a tenant's plan ──────────────────

export const downgrade = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (
        event: APIGatewayProxyEventV2,
        _context: Context,
        auth: AuthContext,
    ) => {
        if (!event.body) {
            return response.error(400, 'MISSING_BODY', 'Request body is required');
        }

        const body = JSON.parse(event.body);
        const { tenantId, newPlan, reason } = body;

        if (!tenantId || !newPlan) {
            return response.error(400, 'MISSING_FIELDS', 'tenantId and newPlan are required');
        }

        if (!Object.values(PlanTier).includes(newPlan)) {
            return response.error(400, 'INVALID_PLAN', `Plan must be one of: ${Object.values(PlanTier).join(', ')}`);
        }

        const result = await downgradePlan(tenantId, newPlan as PlanTier, auth.sub, reason);

        logger.info('Plan downgrade via admin API', {
            tenantId,
            newPlan,
            adminId: auth.sub,
        });

        return response.success(result);
    },
);

// ── GET /admin/plan/history/:tenantId — Plan change history ─────────────────

export const planHistory = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (
        event: APIGatewayProxyEventV2,
        _context: Context,
        auth: AuthContext,
    ) => {
        const tenantId = event.pathParameters?.tenantId;
        if (!tenantId) {
            return response.error(400, 'MISSING_TENANT_ID', 'tenantId path parameter is required');
        }

        const history = await getPlanHistory(tenantId);
        return response.success({ tenantId, history });
    },
);

// ── GET /manifest — Get current user's feature manifest ─────────────────────

export const getManifest = authorizedHandler(
    [], // Any authenticated user
    async (
        event: APIGatewayProxyEventV2,
        _context: Context,
        auth: AuthContext,
    ) => {
        const manifest = await getManifestForTenant(auth.tenantId);
        return response.success({
            manifest: {
                planTier: manifest.planTier,
                businessType: manifest.businessType,
                allowedFeatures: manifest.allowedFeatures,
                limits: manifest.limits,
                manifestHash: manifest.manifestHash,
                expiresAt: manifest.expiresAt,
            },
            signedToken: manifest.signedToken,
        });
    },
);

// ── POST /manifest/refresh — Force refresh feature manifest ─────────────────

export const refreshManifest = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (
        event: APIGatewayProxyEventV2,
        _context: Context,
        auth: AuthContext,
    ) => {
        const manifest = await regenerateManifest(auth.tenantId);

        logger.info('Manifest manually refreshed', {
            tenantId: auth.tenantId,
            userId: auth.sub,
        });

        return response.success({
            manifest: {
                planTier: manifest.planTier,
                businessType: manifest.businessType,
                allowedFeatures: manifest.allowedFeatures,
                limits: manifest.limits,
                manifestHash: manifest.manifestHash,
                expiresAt: manifest.expiresAt,
            },
            signedToken: manifest.signedToken,
        });
    },
);
