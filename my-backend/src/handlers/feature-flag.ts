// ============================================================================
// Feature Flag Handler — Lambda handler for feature flag operations
// ============================================================================
// Provides API endpoints for managing feature flags and resolving for clients

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { success, error } from '../utils/response';
import { logger } from '../utils/logger';
import * as featureFlagService from '../services/feature-flag.service';
import { AppError } from '../utils/errors';

// ---- Admin Endpoints ----

/**
 * GET /api/v1/feature-flags
 * List all feature flags
 */
export const listFeatureFlags = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const flags = await featureFlagService.listFeatureFlags();

            return success(200, {
                success: true,
                data: flags,
                count: flags.length,
            });
        } catch (error: any) {
            logger.error('List feature flags failed', { error: error.message });
            return error(error);
        }
    },
    { requireRoles: ['admin', 'super-admin'] }
);

/**
 * GET /api/v1/feature-flags/{flagKey}
 * Get a specific feature flag
 */
export const getFeatureFlag = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const flagKey = event.pathParameters?.flagKey;
            if (!flagKey) {
                throw new AppError('MISSING_FLAG_KEY', 400, 'MISSING_FLAG_KEY', 'Flag key is required');
            }

            const flag = await featureFlagService.getFeatureFlag(flagKey);
            if (!flag) {
                return success(404, {
                    success: false,
                    error: 'FLAG_NOT_FOUND',
                    message: 'Feature flag not found',
                });
            }

            return success(200, {
                success: true,
                data: flag,
            });
        } catch (error: any) {
            logger.error('Get feature flag failed', { error: error.message });
            return error(error);
        }
    },
    { requireRoles: ['admin', 'super-admin'] }
);

/**
 * POST /api/v1/feature-flags
 * Create a new feature flag
 */
export const createFeatureFlag = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const body = JSON.parse(event.body || '{}');
            const auth = (event as any).requestContext?.authorizer?.jwt?.claims;

            if (!body.flag_key || !body.display_name) {
                throw new AppError('MISSING_FIELDS', 400, 'MISSING_FIELDS', 'flag_key and display_name are required');
            }

            const flag = await featureFlagService.createFeatureFlag({
                flag_key: body.flag_key,
                display_name: body.display_name,
                description: body.description,
                flag_type: body.flag_type,
                default_value: body.default_value,
                plan_overrides: body.plan_overrides,
                min_app_version: body.min_app_version,
                rollout_percentage: body.rollout_percentage,
                created_by: auth?.sub || 'system',
            });

            logger.info('Feature flag created via API', {
                flag_key: flag.flag_key,
                created_by: auth?.sub,
            });

            return success(201, {
                success: true,
                data: flag,
            });
        } catch (error: any) {
            logger.error('Create feature flag failed', { error: error.message });
            return error(error);
        }
    },
    { requireRoles: ['super-admin'] }
);

/**
 * PUT /api/v1/feature-flags/{flagKey}
 * Update a feature flag
 */
export const updateFeatureFlag = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const flagKey = event.pathParameters?.flagKey;
            if (!flagKey) {
                throw new AppError('MISSING_FLAG_KEY', 400, 'MISSING_FLAG_KEY', 'Flag key is required');
            }

            const body = JSON.parse(event.body || '{}');
            const auth = (event as any).requestContext?.authorizer?.jwt?.claims;

            const flag = await featureFlagService.updateFeatureFlag(
                flagKey,
                {
                    display_name: body.display_name,
                    description: body.description,
                    default_value: body.default_value,
                    plan_overrides: body.plan_overrides,
                    min_app_version: body.min_app_version,
                    rollout_percentage: body.rollout_percentage,
                    is_active: body.is_active,
                },
                auth?.sub || 'system'
            );

            if (!flag) {
                return success(404, {
                    success: false,
                    error: 'FLAG_NOT_FOUND',
                    message: 'Feature flag not found',
                });
            }

            logger.info('Feature flag updated via API', {
                flag_key: flagKey,
                updated_by: auth?.sub,
            });

            return success(200, {
                success: true,
                data: flag,
            });
        } catch (error: any) {
            logger.error('Update feature flag failed', { error: error.message });
            return error(error);
        }
    },
    { requireRoles: ['super-admin'] }
);

/**
 * DELETE /api/v1/feature-flags/{flagKey}
 * Delete a feature flag
 */
export const deleteFeatureFlag = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const flagKey = event.pathParameters?.flagKey;
            if (!flagKey) {
                throw new AppError('MISSING_FLAG_KEY', 400, 'MISSING_FLAG_KEY', 'Flag key is required');
            }

            const isDeleted = await featureFlagService.deleteFeatureFlag(flagKey);

            if (!isDeleted) {
                return success(500, {
                    success: false,
                    error: 'DELETE_FAILED',
                    message: 'Failed to delete feature flag',
                });
            }

            logger.info('Feature flag deleted via API', { flag_key: flagKey });

            return success(200, {
                success: true,
                message: 'Feature flag deleted successfully',
            });
        } catch (error: any) {
            logger.error('Delete feature flag failed', { error: error.message });
            return error(error);
        }
    },
    { requireRoles: ['super-admin'] }
);

// ---- Client Resolution Endpoint ----

/**
 * POST /api/v1/feature-flags/resolve
 * Resolve feature flags for a client
 */
export const resolveFeatureFlags = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const body = JSON.parse(event.body || '{}');

            if (!body.plan) {
                throw new AppError('MISSING_PLAN', 400, 'MISSING_PLAN', 'plan is required');
            }

            const result = await featureFlagService.resolveFeatureFlags({
                plan: body.plan,
                app_version: body.app_version,
                license_key: body.license_key,
                license_feature_flags: body.license_feature_flags,
            });

            return success(200, {
                success: true,
                data: result,
            });
        } catch (error: any) {
            logger.error('Resolve feature flags failed', { error: error.message });
            return error(error);
        }
    },
    { requireAuth: false } // Public endpoint - clients need to resolve flags
);

// ---- Main Router Handler ----

/**
 * Main feature flag handler - routes to specific functions
 */
export const handler = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        const path = event.rawPath || '';
        const method = event.requestContext?.http?.method || 'GET';

        logger.debug('Feature flag handler called', { path, method });

        // Route to specific handlers
        if (path.endsWith('/resolve') && method === 'POST') {
            return resolveFeatureFlags(event, context);
        }
        if (path.includes('/feature-flags/') && method === 'GET' && !path.endsWith('/feature-flags')) {
            return getFeatureFlag(event, context);
        }
        if (path.endsWith('/feature-flags') && method === 'GET') {
            return listFeatureFlags(event, context);
        }
        if (path.endsWith('/feature-flags') && method === 'POST') {
            return createFeatureFlag(event, context);
        }
        if (path.includes('/feature-flags/') && method === 'PUT') {
            return updateFeatureFlag(event, context);
        }
        if (path.includes('/feature-flags/') && method === 'DELETE') {
            return deleteFeatureFlag(event, context);
        }

        return success(404, {
            success: false,
            error: 'NOT_FOUND',
            message: 'Feature flag endpoint not found',
        });
    }
);

// ---- Default Export ----

export default {
    handler,
    listFeatureFlags,
    getFeatureFlag,
    createFeatureFlag,
    updateFeatureFlag,
    deleteFeatureFlag,
    resolveFeatureFlags,
};
