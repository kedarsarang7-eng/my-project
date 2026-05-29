// ============================================================================
// Lambda Handler — Estimates / Quotations (Hardware Shop)
// ============================================================================
// FEATURE GATE: HARDWARE_ESTIMATE_TO_INVOICE
// All routes require authentication and are gated by plan feature.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { createEstimateSchema, convertEstimateSchema, voidEstimateSchema } from '../schemas/index';
import {
    createEstimate,
    getEstimate,
    listEstimates,
    convertToInvoice,
    voidEstimate,
} from '../services/estimate.service';

/**
 * POST /estimates
 * Create a new estimate/quotation.
 */
export const create = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _context, auth) => {
        const body = JSON.parse(event.body || '{}');
        const validated = createEstimateSchema.parse(body);

        const result = await createEstimate(
            auth.tenantId,
            auth.sub,
            validated,
        );

        return response.success(result, 201);
    },
    { requiredFeature: FeatureKey.HARDWARE_ESTIMATE_TO_INVOICE },
);

/**
 * GET /estimates
 * List estimates with optional status filter.
 */
export const list = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _context, auth) => {
        const params = event.queryStringParameters || {};
        const result = await listEstimates(auth.tenantId, {
            status: params.status,
            limit: params.limit ? parseInt(params.limit, 10) : 20,
        });

        return response.success(result);
    },
    { requiredFeature: FeatureKey.HARDWARE_ESTIMATE_TO_INVOICE },
);

/**
 * GET /estimates/{id}
 * Get a single estimate with line items.
 */
export const get = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _context, auth) => {
        const estimateId = event.pathParameters?.id;
        if (!estimateId) return response.error(400, 'MISSING_ID', 'Estimate ID is required');

        const result = await getEstimate(auth.tenantId, estimateId);
        if (!result) return response.error(404, 'NOT_FOUND', 'Estimate not found');

        return response.success(result);
    },
    { requiredFeature: FeatureKey.HARDWARE_ESTIMATE_TO_INVOICE },
);

/**
 * POST /estimates/{id}/convert
 * Convert estimate to invoice.
 */
export const convert = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const estimateId = event.pathParameters?.id;
        if (!estimateId) return response.error(400, 'MISSING_ID', 'Estimate ID is required');

        const body = JSON.parse(event.body || '{}');
        const validated = convertEstimateSchema.parse(body);

        const result = await convertToInvoice(
            auth.tenantId,
            estimateId,
            auth.sub,
            auth.role,
            auth.businessType,
        );

        return response.success(result, 201);
    },
    { requiredFeature: FeatureKey.HARDWARE_ESTIMATE_TO_INVOICE },
);

/**
 * POST /estimates/{id}/void
 * Void an estimate.
 */
export const voidEst = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const estimateId = event.pathParameters?.id;
        if (!estimateId) return response.error(400, 'MISSING_ID', 'Estimate ID is required');

        const body = JSON.parse(event.body || '{}');
        const validated = voidEstimateSchema.parse(body);

        const result = await voidEstimate(auth.tenantId, estimateId, validated.reason);

        return response.success(result);
    },
    { requiredFeature: FeatureKey.HARDWARE_ESTIMATE_TO_INVOICE },
);
