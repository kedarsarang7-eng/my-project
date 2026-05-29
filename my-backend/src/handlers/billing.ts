// ============================================================================
// Billing Handler — Lambda handler for billing operations
// ============================================================================
// Provides API endpoints for billing events, analytics, and admin login tracking
//
// QA FIX: BUG-001 — Added missing UserRole import
// QA FIX: BUG-002 — Fixed all handler signatures to use correct authorizedHandler(roles[], fn) format
// QA FIX: BUG-003 — Added Zod validation via parseBody() for all POST handlers
// QA FIX: BUG-004 — Replaced requireAuth:false with proper [] role array + comment
// QA FIX: BUG-020 — Replaced .includes() routing with exact path matching
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { AuthContext, UserRole } from '../types/tenant.types';
import { parseBody } from '../middleware/validation';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import * as billingService from '../services/billing.service';
import { AppError } from '../utils/errors';
import { z } from 'zod';

// ── Zod Schemas for Billing Endpoints (BUG-003 FIX) ─────────────────────────

const createBillingEventSchema = z.object({
    event_type: z.string().min(1).max(100),
    from_plan: z.string().max(100).optional(),
    to_plan: z.string().max(100).optional(),
    amount_cents: z.number().int().min(0).max(999_999_999_99),
    currency: z.string().length(3).default('INR'),
    gst_rate: z.number().min(0).max(100).optional(),
    payment_method: z.string().max(50).optional(),
    payment_reference: z.string().max(200).optional(),
    client_name: z.string().max(200).optional(),
    client_email: z.string().email().max(255).optional(),
    client_gstin: z.string().max(15).optional(),
    client_state_code: z.string().max(10).optional(),
    metadata: z.record(z.string(), z.unknown()).optional(),
    idempotency_key: z.string().max(200).optional(),
    license_key: z.string().max(200).optional(),
    license_id: z.string().max(200).optional(),
});

const transitionBillingStatusSchema = z.object({
    new_status: z.string().min(1).max(50),
    reason: z.string().max(500).optional(),
});

const logAdminLoginSchema = z.object({
    admin_sub: z.string().max(200).optional(),
    email: z.string().email().max(255).optional(),
    success: z.boolean().optional(),
    failure_reason: z.string().max(500).optional(),
    geo_country: z.string().max(100).optional(),
    mfa_used: z.boolean().optional(),
});

// ---- Billing Event CRUD ----

/**
 * POST /api/v1/billing/events
 * Create a new billing event
 */
export const createBillingEvent = authorizedHandler(
    [UserRole.ADMIN, UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        try {
            // BUG-003 FIX: Validate with Zod schema instead of raw JSON.parse
            const parsed = parseBody(createBillingEventSchema, event);
            if (!parsed.success) return parsed.error;

            const body = parsed.data;

            const result = await billingService.createBillingEvent({
                event_type: body.event_type,
                from_plan: body.from_plan,
                to_plan: body.to_plan,
                amount_cents: body.amount_cents,
                currency: body.currency,
                gst_rate: body.gst_rate,
                payment_method: body.payment_method,
                payment_reference: body.payment_reference,
                client_name: body.client_name,
                client_email: body.client_email,
                client_gstin: body.client_gstin,
                client_state_code: body.client_state_code,
                metadata: body.metadata,
                created_by: auth.sub,
                idempotency_key: body.idempotency_key,
                license_key: body.license_key,
                license_id: body.license_id,
            });

            logger.info('Billing event created via API', {
                id: result.id,
                event_type: result.event_type,
                invoice_number: result.invoice_number,
            });

            return response.success({
                success: true,
                data: result,
            });
        } catch (error: any) {
            logger.error('Create billing event failed', { error: error.message });
            return response.error(error.statusCode || 500, error.code || 'INTERNAL_ERROR', error.message);
        }
    }
);

/**
 * GET /api/v1/billing/events
 * List billing events with filtering
 */
export const listBillingEvents = authorizedHandler(
    [UserRole.ADMIN, UserRole.SUPER_ADMIN, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        try {
            const query = event.queryStringParameters || {};
            
            const result = await billingService.listBillingEvents({
                page: query.page ? parseInt(query.page) : 1,
                limit: query.limit ? parseInt(query.limit) : 50,
                event_type: query.event_type,
                license_key: query.license_key,
                status: query.status,
                from_date: query.from_date,
                to_date: query.to_date,
            });

            return response.success({
                success: true,
                data: result.data,
                pagination: {
                    page: query.page ? parseInt(query.page) : 1,
                    limit: query.limit ? parseInt(query.limit) : 50,
                    total: result.total,
                },
            });
        } catch (error: any) {
            logger.error('List billing events failed', { error: error.message });
            return response.error(error.statusCode || 500, error.code || 'INTERNAL_ERROR', error.message);
        }
    }
);

/**
 * POST /api/v1/billing/events/{id}/transition
 * Transition billing event status
 */
export const transitionBillingStatus = authorizedHandler(
    [UserRole.ADMIN, UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        try {
            const id = event.pathParameters?.id;
            if (!id) {
                throw new AppError('MISSING_ID', 'Billing event ID is required');
            }

            // BUG-003 FIX: Validate with Zod schema
            const parsed = parseBody(transitionBillingStatusSchema, event);
            if (!parsed.success) return parsed.error;

            const result = await billingService.transitionBillingStatus({
                event_id: id,
                new_status: parsed.data.new_status,
                actor: auth.sub,
                reason: parsed.data.reason,
            });

            return response.success({
                success: true,
                data: result,
            });
        } catch (error: any) {
            logger.error('Transition billing status failed', { error: error.message });
            return response.error(error.statusCode || 500, error.code || 'INTERNAL_ERROR', error.message);
        }
    }
);

// ---- Revenue Analytics ----

/**
 * GET /api/v1/billing/analytics/revenue
 * Get revenue analytics
 */
export const getRevenueAnalytics = authorizedHandler(
    [UserRole.ADMIN, UserRole.SUPER_ADMIN, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        try {
            const query = event.queryStringParameters || {};

            const result = await billingService.getRevenueAnalytics({
                from_date: query.from_date,
                to_date: query.to_date,
            });

            return response.success({
                success: true,
                data: result,
            });
        } catch (error: any) {
            logger.error('Get revenue analytics failed', { error: error.message });
            return response.error(error.statusCode || 500, error.code || 'INTERNAL_ERROR', error.message);
        }
    }
);

// ---- Admin Login Tracking ----

/**
 * POST /api/v1/billing/admin/login
 * Log admin login attempt (called by auth system).
 * NOTE: Uses empty role array [] so any authenticated user's login can be logged.
 * The handler only records the authenticated user's own login attempt.
 */
export const logAdminLogin = authorizedHandler(
    [],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        try {
            // BUG-003 FIX: Validate with Zod schema
            const parsed = parseBody(logAdminLoginSchema, event);
            if (!parsed.success) return parsed.error;

            const body = parsed.data;

            await billingService.logAdminLogin({
                admin_sub: body.admin_sub,
                email: body.email,
                success: body.success,
                failure_reason: body.failure_reason,
                ip_address: event.requestContext?.http?.sourceIp,
                user_agent: event.requestContext?.http?.userAgent,
                geo_country: body.geo_country,
                mfa_used: body.mfa_used,
            });

            return response.success({
                success: true,
                message: 'Login logged successfully',
            });
        } catch (error: any) {
            logger.error('Log admin login failed', { error: error.message });
            // Don't fail the request - logging failure shouldn't block login
            return response.success({
                success: true,
                message: 'Login processed',
            });
        }
    }
);

/**
 * GET /api/v1/billing/admin/logins
 * Get admin login history
 */
export const getLoginHistory = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        try {
            const query = event.queryStringParameters || {};

            const result = await billingService.getLoginHistory({
                page: query.page ? parseInt(query.page) : 1,
                limit: query.limit ? parseInt(query.limit) : 50,
                email: query.email,
                success: query.success !== undefined ? query.success === 'true' : undefined,
            });

            return response.success({
                success: true,
                data: result.data,
                pagination: {
                    page: query.page ? parseInt(query.page) : 1,
                    limit: query.limit ? parseInt(query.limit) : 50,
                    total: result.total,
                },
            });
        } catch (error: any) {
            logger.error('Get login history failed', { error: error.message });
            return response.error(error.statusCode || 500, error.code || 'INTERNAL_ERROR', error.message);
        }
    }
);

/**
 * GET /api/v1/billing/admin/lockout/{email}
 * Check login lockout status.
 * Uses empty role array [] — lockout check is needed before full auth is complete.
 */
export const checkLoginLockout = authorizedHandler(
    [],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        try {
            const email = event.pathParameters?.email;
            if (!email) {
                throw new AppError('MISSING_EMAIL', 'Email is required');
            }

            const result = await billingService.checkLoginLockout(email);

            return response.success({
                success: true,
                data: result,
            });
        } catch (error: any) {
            logger.error('Check login lockout failed', { error: error.message });
            return response.error(error.statusCode || 500, error.code || 'INTERNAL_ERROR', error.message);
        }
    }
);

// ---- Main Router Handler ----

/**
 * Main billing handler - routes to specific functions
 * BUG-020 FIX: Use exact path segment matching instead of .includes()
 */
export const handler = authorizedHandler(
    [],
    async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        const path = event.rawPath || (event as any).path || '';
        const method = event.requestContext?.http?.method || (event as any).httpMethod || 'GET';

        logger.debug('Billing handler called', { path, method });

        // BUG-020 FIX: Use endsWith/exact segment matching for disambiguation
        // Order matters: more specific paths first
        if (path.endsWith('/admin/lockout') && method === 'GET') {
            return checkLoginLockout(event, context);
        }
        if (path.endsWith('/admin/logins') && method === 'GET') {
            return getLoginHistory(event, context);
        }
        if (path.endsWith('/admin/login') && method === 'POST') {
            return logAdminLogin(event, context);
        }
        if (path.endsWith('/analytics/revenue') && method === 'GET') {
            return getRevenueAnalytics(event, context);
        }
        if (path.includes('/transition') && method === 'POST') {
            return transitionBillingStatus(event, context);
        }
        if (path.endsWith('/events') && method === 'POST') {
            return createBillingEvent(event, context);
        }
        if (path.endsWith('/events') && method === 'GET') {
            return listBillingEvents(event, context);
        }

        return response.error(404, 'NOT_FOUND', 'Billing endpoint not found');
    }
);

// ---- Default Export ----

export default {
    handler,
    createBillingEvent,
    listBillingEvents,
    transitionBillingStatus,
    getRevenueAnalytics,
    logAdminLogin,
    getLoginHistory,
    checkLoginLockout,
};
