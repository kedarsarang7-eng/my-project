// ============================================================================
// Lambda Handler — Delivery Challans (Hardware Shop)
// ============================================================================
// FEATURE GATE: HARDWARE_DELIVERY_CHALLAN
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { createChallanSchema, challanDeliveredSchema } from '../schemas/index';
import {
    createChallan,
    getChallan,
    listChallans,
    markDelivered,
} from '../services/challan.service';

/**
 * POST /challans
 * Create a new delivery challan.
 */
export const create = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _context, auth) => {
        const body = JSON.parse(event.body || '{}');
        const validated = createChallanSchema.parse(body);

        const result = await createChallan(auth.tenantId, auth.sub, validated);

        return response.success(result, 201);
    },
    { requiredFeature: FeatureKey.HARDWARE_DELIVERY_CHALLAN },
);

/**
 * GET /challans
 * List delivery challans.
 */
export const list = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _context, auth) => {
        const params = event.queryStringParameters || {};
        const result = await listChallans(auth.tenantId, {
            limit: params.limit ? parseInt(params.limit, 10) : 20,
        });

        return response.success(result);
    },
    { requiredFeature: FeatureKey.HARDWARE_DELIVERY_CHALLAN },
);

/**
 * GET /challans/{id}
 * Get a single delivery challan.
 */
export const get = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _context, auth) => {
        const challanId = event.pathParameters?.id;
        if (!challanId) return response.error(400, 'MISSING_ID', 'Challan ID is required');

        const result = await getChallan(auth.tenantId, challanId);
        if (!result) return response.error(404, 'NOT_FOUND', 'Challan not found');

        return response.success(result);
    },
    { requiredFeature: FeatureKey.HARDWARE_DELIVERY_CHALLAN },
);

/**
 * POST /challans/{id}/delivered
 * Mark a challan as delivered (goods received at site).
 */
export const delivered = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _context, auth) => {
        const challanId = event.pathParameters?.id;
        if (!challanId) return response.error(400, 'MISSING_ID', 'Challan ID is required');

        // SECURITY FIX S-7: Validate input with Zod schema
        const body = JSON.parse(event.body || '{}');
        const validated = challanDeliveredSchema.parse(body);
        const result = await markDelivered(
            auth.tenantId,
            challanId,
            validated.receivedBy,
        );

        return response.success(result);
    },
    { requiredFeature: FeatureKey.HARDWARE_DELIVERY_CHALLAN },
);
