// ============================================================================
// Lambda Handler — Reports (Sales & GSTR1)
// ============================================================================
// Endpoints:
//   GET /reports/sales   — Sales report with date range & aggregations
//   GET /reports/gstr1   — GSTR-1 report (B2B/B2C summary)
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { getPool } from '../config/db.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

/**
 * GET /reports/sales?from=2026-01-01&to=2026-01-31&groupBy=day
 * Sales report with date range filtering and aggregation.
 */
export const salesReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const db = getPool();
        const params = event.queryStringParameters || {};

        const fromDate = params.from || new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().slice(0, 10);
        const toDate = params.to || new Date().toISOString().slice(0, 10);
        const groupBy = params.groupBy || 'day'; // day, week, month

        let dateGroupExpr: string;
        switch (groupBy) {
            case 'week':
                dateGroupExpr = `DATE_TRUNC('week', t.created_at)::date`;
                break;
            case 'month':
                dateGroupExpr = `DATE_TRUNC('month', t.created_at)::date`;
                break;
            default:
                dateGroupExpr = `DATE(t.created_at)`;
        }

        // Aggregated daily/weekly/monthly sales
        const timeseriesResult = await db.query(
            `SELECT
                ${dateGroupExpr} AS period,
                COUNT(*)::int AS bill_count,
                SUM(total_cents)::bigint AS total_cents,
                SUM(paid_cents)::bigint AS paid_cents,
                SUM(discount_cents)::bigint AS discount_cents,
                SUM(tax_cents)::bigint AS tax_cents
             FROM transactions t
             WHERE t.tenant_id = $1
               AND DATE(t.created_at) BETWEEN $2 AND $3
               AND NOT t.is_deleted AND t.status != 'voided'
             GROUP BY period
             ORDER BY period ASC`,
            [auth.tenantId, fromDate, toDate]
        );

        // Overall summary
        const summaryResult = await db.query(
            `SELECT
                COUNT(*)::int AS total_bills,
                COALESCE(SUM(total_cents), 0)::bigint AS total_revenue_cents,
                COALESCE(SUM(paid_cents), 0)::bigint AS total_collected_cents,
                COALESCE(SUM(balance_cents), 0)::bigint AS total_outstanding_cents,
                COALESCE(SUM(discount_cents), 0)::bigint AS total_discount_cents,
                COALESCE(SUM(tax_cents), 0)::bigint AS total_tax_cents,
                COALESCE(AVG(total_cents), 0)::bigint AS avg_bill_cents
             FROM transactions t
             WHERE t.tenant_id = $1
               AND DATE(t.created_at) BETWEEN $2 AND $3
               AND NOT t.is_deleted AND t.status != 'voided'`,
            [auth.tenantId, fromDate, toDate]
        );

        // Top selling products
        const topProductsResult = await db.query(
            `SELECT
                ti.name,
                SUM(ti.quantity)::numeric AS total_qty,
                SUM(ti.total_cents)::bigint AS total_revenue_cents,
                COUNT(DISTINCT ti.transaction_id)::int AS bill_count
             FROM transaction_items ti
             JOIN transactions t ON t.id = ti.transaction_id
             WHERE t.tenant_id = $1
               AND DATE(t.created_at) BETWEEN $2 AND $3
               AND NOT t.is_deleted AND t.status != 'voided'
             GROUP BY ti.name
             ORDER BY total_revenue_cents DESC
             LIMIT 10`,
            [auth.tenantId, fromDate, toDate]
        );

        // Payment mode breakdown
        const paymentModesResult = await db.query(
            `SELECT
                COALESCE(payment_mode::text, 'cash') AS mode,
                COUNT(*)::int AS count,
                SUM(total_cents)::bigint AS total_cents
             FROM transactions t
             WHERE t.tenant_id = $1
               AND DATE(t.created_at) BETWEEN $2 AND $3
               AND NOT t.is_deleted AND t.status != 'voided'
             GROUP BY payment_mode
             ORDER BY total_cents DESC`,
            [auth.tenantId, fromDate, toDate]
        );

        return response.success({
            period: { from: fromDate, to: toDate, groupBy },
            summary: summaryResult.rows[0],
            timeseries: timeseriesResult.rows,
            topProducts: topProductsResult.rows,
            paymentModes: paymentModesResult.rows,
        });
    }
);

/**
 * GET /reports/gstr1?from=2026-01-01&to=2026-03-31
 * GSTR-1 report — B2B and B2C invoice summary for GST filing.
 */
export const gstr1Report = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const db = getPool();
        const params = event.queryStringParameters || {};

        const fromDate = params.from || new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().slice(0, 10);
        const toDate = params.to || new Date().toISOString().slice(0, 10);

        // B2B: Invoices where customer has GSTIN (> ₹2.5 lakh threshold handled by frontend)
        const b2bResult = await db.query(
            `SELECT
                t.invoice_number,
                t.customer_name,
                t.created_at AS invoice_date,
                t.subtotal_cents,
                t.cgst_cents,
                t.sgst_cents,
                t.igst_cents,
                t.total_cents,
                t.status
             FROM transactions t
             WHERE t.tenant_id = $1
               AND DATE(t.created_at) BETWEEN $2 AND $3
               AND NOT t.is_deleted AND t.status NOT IN ('voided', 'draft')
               AND t.metadata->>'customerGstin' IS NOT NULL
             ORDER BY t.created_at ASC`,
            [auth.tenantId, fromDate, toDate]
        );

        // B2C: All other invoices (no GSTIN)
        const b2cResult = await db.query(
            `SELECT
                COUNT(*)::int AS invoice_count,
                COALESCE(SUM(subtotal_cents), 0)::bigint AS taxable_value_cents,
                COALESCE(SUM(cgst_cents), 0)::bigint AS cgst_cents,
                COALESCE(SUM(sgst_cents), 0)::bigint AS sgst_cents,
                COALESCE(SUM(igst_cents), 0)::bigint AS igst_cents,
                COALESCE(SUM(total_cents), 0)::bigint AS total_cents
             FROM transactions t
             WHERE t.tenant_id = $1
               AND DATE(t.created_at) BETWEEN $2 AND $3
               AND NOT t.is_deleted AND t.status NOT IN ('voided', 'draft')
               AND (t.metadata->>'customerGstin' IS NULL)`,
            [auth.tenantId, fromDate, toDate]
        );

        // HSN-wise summary
        const hsnResult = await db.query(
            `SELECT
                COALESCE(i.hsn_code, 'N/A') AS hsn_code,
                SUM(ti.quantity)::numeric AS total_qty,
                SUM(ti.total_cents)::bigint AS total_value_cents,
                COUNT(DISTINCT ti.transaction_id)::int AS invoice_count
             FROM transaction_items ti
             JOIN transactions t ON t.id = ti.transaction_id
             LEFT JOIN inventory i ON i.id = ti.item_id
             WHERE t.tenant_id = $1
               AND DATE(t.created_at) BETWEEN $2 AND $3
               AND NOT t.is_deleted AND t.status NOT IN ('voided', 'draft')
             GROUP BY i.hsn_code
             ORDER BY total_value_cents DESC`,
            [auth.tenantId, fromDate, toDate]
        );

        return response.success({
            period: { from: fromDate, to: toDate },
            b2b: b2bResult.rows,
            b2c_summary: b2cResult.rows[0],
            hsn_summary: hsnResult.rows,
        });
    }
);
