// ============================================================================
// Plan Config Admin Handler — Super Admin Endpoints for Plan Defaults
// ============================================================================
// GET  /admin/plans              — list effective configs (code + DB overlay)
// GET  /admin/plans/:plan         — get single plan effective config
// PUT  /admin/plans/:plan         — update DB overrides (add/remove features, patch limits)
// POST /admin/plans/:plan/reset   — delete DB row, revert to code defaults
//
// All endpoints require SUPER_ADMIN.
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { AuthContext, UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
    listPlanConfigs,
    getEffectivePlanConfig,
    updatePlanConfig,
    resetPlanConfigToDefaults,
    PlanTier,
} from '../services/plan-config.service';

// ── GET /admin/plans ───────────────────────────────────────────────────────

export const listPlans = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (_event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        const configs = await listPlanConfigs();
        logger.info('Plan configs listed', { by: auth.sub, count: configs.length });
        return response.success(configs);
    },
);

// ── GET /admin/plans/:plan ───────────────────────────────────────────────────

export const getPlan = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        const planParam = event.pathParameters?.plan;
        if (!planParam) {
            return response.error(400, 'MISSING_PLAN', 'plan path parameter is required');
        }
        const plan = mapStringToPlanTier(planParam);
        if (!plan) {
            return response.error(400, 'INVALID_PLAN', 'plan must be one of: basic, pro, premium, enterprise');
        }
        const config = await getEffectivePlanConfig(plan);
        logger.info('Plan config retrieved', { plan, by: auth.sub });
        return response.success(config);
    },
);

// ── PUT /admin/plans/:plan ─────────────────────────────────────────────────

export const updatePlan = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        const planParam = event.pathParameters?.plan;
        if (!planParam) {
            return response.error(400, 'MISSING_PLAN', 'plan path parameter is required');
        }
        const plan = mapStringToPlanTier(planParam);
        if (!plan) {
            return response.error(400, 'INVALID_PLAN', 'plan must be one of: basic, pro, premium, enterprise');
        }
        if (!event.body) {
            return response.error(400, 'MISSING_BODY', 'Request body is required');
        }

        const body = JSON.parse(event.body);
        const delta: Parameters<typeof updatePlanConfig>[1] = {};

        if (body.addFeatures) {
            if (!Array.isArray(body.addFeatures)) {
                return response.error(400, 'INVALID_FIELD', 'addFeatures must be an array');
            }
            delta.addFeatures = body.addFeatures;
        }
        if (body.removeFeatures) {
            if (!Array.isArray(body.removeFeatures)) {
                return response.error(400, 'INVALID_FIELD', 'removeFeatures must be an array');
            }
            delta.removeFeatures = body.removeFeatures;
        }
        if (body.limits) {
            if (typeof body.limits !== 'object') {
                return response.error(400, 'INVALID_FIELD', 'limits must be an object');
            }
            delta.limits = {
                maxUsers: body.limits.maxUsers,
                maxProducts: body.limits.maxProducts,
                maxBranches: body.limits.maxBranches,
                maxDevices: body.limits.maxDevices,
                maxBusinessTypes: body.limits.maxBusinessTypes,
            };
        }
        if (body.replaceDefaults) {
            if (!Array.isArray(body.replaceDefaults)) {
                return response.error(400, 'INVALID_FIELD', 'replaceDefaults must be an array');
            }
            delta.replaceDefaults = body.replaceDefaults;
        }

        const updated = await updatePlanConfig(plan, delta, auth.sub);
        logger.info('Plan config updated', { plan, by: auth.sub, delta });
        return response.success(updated, 200);
    },
);

// ── POST /admin/plans/:plan/reset ──────────────────────────────────────────

export const resetPlan = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        const planParam = event.pathParameters?.plan;
        if (!planParam) {
            return response.error(400, 'MISSING_PLAN', 'plan path parameter is required');
        }
        const plan = mapStringToPlanTier(planParam);
        if (!plan) {
            return response.error(400, 'INVALID_PLAN', 'plan must be one of: basic, pro, premium, enterprise');
        }
        await resetPlanConfigToDefaults(plan, auth.sub);
        logger.info('Plan config reset to defaults', { plan, by: auth.sub });
        return response.success({ success: true, message: `Plan ${plan} reset to code defaults` }, 200);
    },
);

// ── Helper ───────────────────────────────────────────────────────────────────

function mapStringToPlanTier(value: string): PlanTier | null {
    const normalized = value.toLowerCase().trim();
    if (normalized === 'basic') return PlanTier.BASIC;
    if (normalized === 'pro') return PlanTier.PRO;
    if (normalized === 'premium') return PlanTier.PREMIUM;
    if (normalized === 'enterprise') return PlanTier.ENTERPRISE;
    return null;
}
