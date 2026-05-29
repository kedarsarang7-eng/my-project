// ============================================================================
// Lambda Handler — Held / Parked Bills (Sprint 1)
// ============================================================================
// Routes:
//   POST   /invoices/hold                — save cart as held bill
//   GET    /invoices/held                — list held bills for tenant
//   GET    /invoices/held/{id}           — fetch one held bill
//   POST   /invoices/held/{id}/resume    — atomic fetch + delete (returns cart)
//   DELETE /invoices/held/{id}           — discard without resuming
//
// All routes require authenticated cashier-or-above.
// Holds DO NOT impact stock, invoice numbering, credit, or accounting.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { holdBillSchema } from '../schemas/index';
import {
    holdBill,
    listHeldBills,
    getHeldBill,
    resumeHeldBill,
    discardHeldBill,
} from '../services/held-bill.service';

const CASHIER_ROLES = [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF];

/** POST /invoices/hold — save cart as held bill. */
export const create = authorizedHandler(CASHIER_ROLES, async (event, _ctx, auth) => {
    const body = JSON.parse(event.body || '{}');
    const validated = holdBillSchema.parse(body);

    const businessId =
        event.headers?.['x-business-id'] || event.headers?.['X-Business-Id'];

    const record = await holdBill(auth.tenantId, auth.sub, businessId, validated);
    return response.success(record, 201);
});

/** GET /invoices/held — list held bills for tenant. */
export const list = authorizedHandler(CASHIER_ROLES, async (event, _ctx, auth) => {
    const params = event.queryStringParameters || {};
    const limit = params.limit ? parseInt(params.limit, 10) : 20;
    const items = await listHeldBills(auth.tenantId, { limit });
    return response.success({ items, count: items.length });
});

/** GET /invoices/held/{id} — fetch a single held bill. */
export const get = authorizedHandler(CASHIER_ROLES, async (event, _ctx, auth) => {
    const heldBillId = event.pathParameters?.id;
    if (!heldBillId) return response.badRequest('Held bill id is required');

    const record = await getHeldBill(auth.tenantId, heldBillId);
    return response.success(record);
});

/**
 * POST /invoices/held/{id}/resume — atomically returns the held cart payload
 * and deletes the hold so it cannot be checked out twice.
 */
export const resume = authorizedHandler(CASHIER_ROLES, async (event, _ctx, auth) => {
    const heldBillId = event.pathParameters?.id;
    if (!heldBillId) return response.badRequest('Held bill id is required');

    const record = await resumeHeldBill(auth.tenantId, heldBillId);
    return response.success(record);
});

/** DELETE /invoices/held/{id} — discard hold without resuming. */
export const discard = authorizedHandler(CASHIER_ROLES, async (event, _ctx, auth) => {
    const heldBillId = event.pathParameters?.id;
    if (!heldBillId) return response.badRequest('Held bill id is required');

    await discardHeldBill(auth.tenantId, heldBillId);
    return response.success({ id: heldBillId, discarded: true });
});
