// ============================================================================
// Lambda Handler — Cash Closings (Sprint 1: Day-End Denomination Close)
// ============================================================================
// Routes:
//   POST /cash-closings              — record a new day close
//   GET  /cash-closings              — list (most recent first)
//   GET  /cash-closings/preview      — expected cash for the date (pre-count)
//   GET  /cash-closings/by-date/{date} — fetch the close for a specific date
//   POST /cash-closings/{date}/approve — owner approval for variance > tolerance
//
// Cashier-or-above can record; only OWNER/ADMIN can approve a mismatch.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import {
    recordCashClosingSchema,
    approveCashClosingSchema,
} from '../schemas/index';
import {
    recordCashClosing,
    listCashClosings,
    getClosingForDate,
    previewExpectedCash,
    approveCashClosing,
} from '../services/cash-closing.service';

const CASHIER_ROLES = [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF];
const APPROVER_ROLES = [UserRole.OWNER, UserRole.ADMIN];

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function todayString(): string {
    return new Date().toISOString().substring(0, 10);
}

/** POST /cash-closings — record a new day close. */
export const create = authorizedHandler(CASHIER_ROLES, async (event, _ctx, auth) => {
    const body = JSON.parse(event.body || '{}');
    const validated = recordCashClosingSchema.parse(body);
    const businessId =
        event.headers?.['x-business-id'] || event.headers?.['X-Business-Id'];

    const record = await recordCashClosing(
        auth.tenantId, auth.sub, businessId, validated,
    );
    return response.success(record, 201);
});

/** GET /cash-closings — list closings, newest first. */
export const list = authorizedHandler(CASHIER_ROLES, async (event, _ctx, auth) => {
    const params = event.queryStringParameters || {};
    const limit = params.limit ? parseInt(params.limit, 10) : 30;
    const items = await listCashClosings(auth.tenantId, { limit });
    return response.success({ items, count: items.length });
});

/**
 * GET /cash-closings/preview?date=YYYY-MM-DD
 * Returns expected cash for the date so the UI can pre-fill the "expected"
 * panel before the cashier counts the drawer.
 */
export const preview = authorizedHandler(CASHIER_ROLES, async (event, _ctx, auth) => {
    const params = event.queryStringParameters || {};
    const date = params.date && DATE_RE.test(params.date) ? params.date : todayString();
    const businessId =
        event.headers?.['x-business-id'] || event.headers?.['X-Business-Id'];
    const result = await previewExpectedCash(auth.tenantId, date, businessId);
    return response.success(result);
});

/** GET /cash-closings/by-date/{date} — fetch the closing for a specific date. */
export const getByDate = authorizedHandler(CASHIER_ROLES, async (event, _ctx, auth) => {
    const date = event.pathParameters?.date;
    if (!date || !DATE_RE.test(date)) {
        return response.badRequest('Date must be YYYY-MM-DD');
    }
    const businessId =
        event.headers?.['x-business-id'] || event.headers?.['X-Business-Id'];
    const record = await getClosingForDate(auth.tenantId, date, businessId);
    if (!record) return response.notFound('Cash closing');
    return response.success(record);
});

/**
 * POST /cash-closings/{date}/approve — owner-approve a variance.
 * Only OWNER/ADMIN. Mismatch must be `mismatch_pending`; matched closings
 * don't require approval.
 */
export const approve = authorizedHandler(APPROVER_ROLES, async (event, _ctx, auth) => {
    const date = event.pathParameters?.date;
    if (!date || !DATE_RE.test(date)) {
        return response.badRequest('Date must be YYYY-MM-DD');
    }
    const body = JSON.parse(event.body || '{}');
    const validated = approveCashClosingSchema.parse(body);
    const businessId =
        event.headers?.['x-business-id'] || event.headers?.['X-Business-Id'];
    const record = await approveCashClosing(
        auth.tenantId, auth.sub, date, validated.reason, businessId,
    );
    return response.success(record);
});
