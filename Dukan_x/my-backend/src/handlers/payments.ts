// ============================================================================
// Lambda Handler — Payments (Record & Retrieve)
// ============================================================================
// Endpoints:
//   GET    /payments           — List payments for tenant
//   GET    /payments/{id}      — Get single payment details
//   POST   /payments           — Record a payment against an invoice
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { getPool } from '../config/db.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

/**
 * GET /payments?page=1&limit=20&status=&invoiceId=
 * List payments for the tenant with optional filters.
 */
export const listPayments = authorizedHandler([], async (event, _context, auth) => {
    const db = getPool();
    const params = event.queryStringParameters || {};
    const page = parseInt(params.page || '1', 10);
    const limit = Math.min(parseInt(params.limit || '20', 10), 100);
    const offset = (page - 1) * limit;

    const conditions: string[] = ['t.tenant_id = $1', 'NOT t.is_deleted'];
    const values: unknown[] = [auth.tenantId];
    let paramIdx = 2;

    if (params.status) {
        conditions.push(`t.status = $${paramIdx}`);
        values.push(params.status);
        paramIdx++;
    }

    const where = conditions.join(' AND ');

    const countResult = await db.query(
        `SELECT COUNT(*)::int AS total FROM transactions t WHERE ${where}`,
        values
    );

    const dataResult = await db.query(
        `SELECT t.id, t.invoice_number, t.customer_name, t.customer_phone,
                t.total_cents, t.paid_cents, t.balance_cents,
                t.payment_mode, t.status, t.created_at
         FROM transactions t
         WHERE ${where}
         ORDER BY t.created_at DESC
         LIMIT $${paramIdx} OFFSET $${paramIdx + 1}`,
        [...values, limit, offset]
    );

    return response.paginated(dataResult.rows, countResult.rows[0].total, page, limit);
});

/**
 * GET /payments/{id}
 * Get a single payment/transaction by ID.
 */
export const getPayment = authorizedHandler([], async (event, _context, auth) => {
    const db = getPool();
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Missing payment id');

    const txnResult = await db.query(
        `SELECT t.*, json_agg(
            json_build_object(
                'id', ti.id, 'name', ti.name, 'quantity', ti.quantity,
                'unit', ti.unit, 'unit_price_cents', ti.unit_price_cents,
                'total_cents', ti.total_cents
            )
         ) AS items
         FROM transactions t
         LEFT JOIN transaction_items ti ON ti.transaction_id = t.id
         WHERE t.id = $1 AND t.tenant_id = $2 AND NOT t.is_deleted
         GROUP BY t.id`,
        [id, auth.tenantId]
    );

    if (txnResult.rows.length === 0) {
        return response.notFound('Payment');
    }

    return response.success(txnResult.rows[0]);
});

/**
 * POST /payments
 * Record a payment against an existing invoice.
 */
export const recordPayment = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event, _context, auth) => {
        const db = getPool();
        const body = JSON.parse(event.body || '{}');
        const { invoiceId, amountCents, paymentMode, notes } = body;

        if (!invoiceId || !amountCents) {
            return response.badRequest('Missing required fields: invoiceId, amountCents');
        }

        // Update the transaction's paid amount
        const result = await db.query(
            `UPDATE transactions
             SET paid_cents = LEAST(paid_cents + $1, total_cents),
                 balance_cents = GREATEST(total_cents - (paid_cents + $1), 0),
                 payment_mode = COALESCE($2, payment_mode),
                 status = CASE
                     WHEN paid_cents + $1 >= total_cents THEN 'paid'
                     WHEN paid_cents + $1 > 0 THEN 'partially_paid'
                     ELSE status
                 END,
                 notes = CASE WHEN $3 IS NOT NULL THEN COALESCE(notes || E'\n', '') || $3 ELSE notes END,
                 updated_at = NOW()
             WHERE id = $4 AND tenant_id = $5 AND NOT is_deleted
             RETURNING id, invoice_number, status, total_cents, paid_cents, balance_cents`,
            [amountCents, paymentMode || null, notes || null, invoiceId, auth.tenantId]
        );

        if (result.rows.length === 0) {
            return response.notFound('Invoice');
        }

        logger.info('Payment recorded', { tenantId: auth.tenantId, invoiceId, amountCents });
        return response.success(result.rows[0]);
    }
);
