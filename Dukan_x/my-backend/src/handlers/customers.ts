// ============================================================================
// Lambda Handler — Customers (List & Ledger)
// ============================================================================
// Endpoints:
//   GET /customers              — List customers for tenant
//   GET /customers/{id}/ledger  — Get customer's transaction ledger
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { getPool } from '../config/db.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

/**
 * GET /customers?search=&page=1&limit=20
 * List unique customers derived from transactions.
 */
export const listCustomers = authorizedHandler([], async (event, _context, auth) => {
    const db = getPool();
    const params = event.queryStringParameters || {};
    const page = parseInt(params.page || '1', 10);
    const limit = Math.min(parseInt(params.limit || '20', 10), 100);
    const offset = (page - 1) * limit;
    const search = params.search;

    let searchCondition = '';
    const values: unknown[] = [auth.tenantId];
    let paramIdx = 2;

    if (search) {
        searchCondition = `AND (customer_name ILIKE $${paramIdx} OR customer_phone ILIKE $${paramIdx})`;
        values.push(`%${search}%`);
        paramIdx++;
    }

    const countResult = await db.query(
        `SELECT COUNT(DISTINCT COALESCE(customer_phone, customer_name))::int AS total
         FROM transactions
         WHERE tenant_id = $1 AND NOT is_deleted AND customer_name IS NOT NULL ${searchCondition}`,
        values
    );

    const dataResult = await db.query(
        `SELECT
            customer_name AS name,
            customer_phone AS phone,
            customer_id,
            COUNT(*)::int AS total_orders,
            SUM(total_cents)::bigint AS total_billed_cents,
            SUM(paid_cents)::bigint AS total_paid_cents,
            SUM(balance_cents)::bigint AS outstanding_cents,
            MAX(created_at) AS last_order_at
         FROM transactions
         WHERE tenant_id = $1 AND NOT is_deleted AND customer_name IS NOT NULL ${searchCondition}
         GROUP BY customer_name, customer_phone, customer_id
         ORDER BY last_order_at DESC
         LIMIT $${paramIdx} OFFSET $${paramIdx + 1}`,
        [...values, limit, offset]
    );

    return response.paginated(dataResult.rows, countResult.rows[0].total, page, limit);
});

/**
 * GET /customers/{id}/ledger?page=1&limit=50
 * Get a customer's transaction ledger (all invoices).
 * {id} can be customer_id UUID or customer_phone.
 */
export const getCustomerLedger = authorizedHandler([], async (event, _context, auth) => {
    const db = getPool();
    const customerId = event.pathParameters?.id;
    if (!customerId) return response.badRequest('Missing customer id');

    const params = event.queryStringParameters || {};
    const page = parseInt(params.page || '1', 10);
    const limit = Math.min(parseInt(params.limit || '50', 10), 200);
    const offset = (page - 1) * limit;

    // Match by customer_id UUID or customer_phone
    const matchCondition = `(customer_id::text = $2 OR customer_phone = $2)`;

    const countResult = await db.query(
        `SELECT COUNT(*)::int AS total FROM transactions
         WHERE tenant_id = $1 AND ${matchCondition} AND NOT is_deleted`,
        [auth.tenantId, customerId]
    );

    const dataResult = await db.query(
        `SELECT id, invoice_number, customer_name, status,
                total_cents, paid_cents, balance_cents,
                payment_mode, created_at, notes
         FROM transactions
         WHERE tenant_id = $1 AND ${matchCondition} AND NOT is_deleted
         ORDER BY created_at DESC
         LIMIT $3 OFFSET $4`,
        [auth.tenantId, customerId, limit, offset]
    );

    // Running balance
    const summaryResult = await db.query(
        `SELECT
            COALESCE(SUM(total_cents), 0)::bigint AS total_billed_cents,
            COALESCE(SUM(paid_cents), 0)::bigint AS total_paid_cents,
            COALESCE(SUM(balance_cents), 0)::bigint AS outstanding_cents
         FROM transactions
         WHERE tenant_id = $1 AND ${matchCondition} AND NOT is_deleted`,
        [auth.tenantId, customerId]
    );

    return response.success({
        ledger: dataResult.rows,
        summary: summaryResult.rows[0],
        pagination: {
            page, limit,
            total: countResult.rows[0].total,
            totalPages: Math.ceil(countResult.rows[0].total / limit),
        },
    });
});
