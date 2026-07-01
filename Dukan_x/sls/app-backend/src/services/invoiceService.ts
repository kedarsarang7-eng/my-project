// ============================================
// Invoice Service — Tenant + Customer Scoped Data Access
// ============================================

import { withTenant } from '../middleware/tenantMiddleware';
import { logger } from '../utils/logger';

// ---- Types ----

export interface InvoiceSummary {
    id: string;
    invoice_number: string;
    status: string;
    subtotal_cents: number;
    discount_cents: number;
    tax_cents: number;
    total_cents: number;
    paid_cents: number;
    balance_cents: number;
    payment_mode: string | null;
    notes: string | null;
    created_at: Date;
    items_count: number;
}

export interface InvoiceLineItem {
    id: string;
    name: string;
    quantity: number;
    unit: string;
    unit_price_cents: number;
    discount_cents: number;
    tax_cents: number;
    total_cents: number;
    hsn_code: string | null;
}

export interface InvoiceDetail extends InvoiceSummary {
    items: InvoiceLineItem[];
    customer_name: string | null;
    customer_phone: string | null;
}

export interface InvoiceLookupResult {
    found: boolean;
    authorized: boolean;
    data: InvoiceDetail | null;
}

// ---- List Invoices ----

export async function getInvoices(
    shopId: string,
    customerId: string,
    options: {
        status?: string;
        from_date?: string;
        to_date?: string;
        page?: number;
        limit?: number;
    } = {}
): Promise<{ invoices: InvoiceSummary[]; total: number }> {
    const { status, from_date, to_date, page = 1, limit = 20 } = options;
    const offset = (page - 1) * limit;

    return withTenant(shopId, async (client) => {
        const conditions: string[] = ['NOT is_deleted'];
        const params: any[] = [];
        let paramIndex = 1;

        conditions.push(`customer_id = $${paramIndex}`);
        params.push(customerId);
        paramIndex++;

        if (status) {
            conditions.push(`status = $${paramIndex}`);
            params.push(status);
            paramIndex++;
        }

        if (from_date) {
            conditions.push(`created_at >= $${paramIndex}::timestamptz`);
            params.push(from_date);
            paramIndex++;
        }

        if (to_date) {
            conditions.push(`created_at <= $${paramIndex}::timestamptz`);
            params.push(to_date);
            paramIndex++;
        }

        const whereClause = conditions.join(' AND ');

        const countResult = await client.query(
            `SELECT COUNT(*)::int AS total FROM transactions WHERE ${whereClause}`,
            params
        );
        const total = countResult.rows[0]?.total || 0;

        const dataResult = await client.query(
            `SELECT t.id, t.invoice_number, t.status, t.subtotal_cents,
                    t.discount_cents, t.tax_cents, t.total_cents, t.paid_cents,
                    t.balance_cents, t.payment_mode, t.notes, t.created_at,
                    COALESCE(ic.items_count, 0)::int AS items_count
             FROM transactions t
             LEFT JOIN (
                 SELECT transaction_id, COUNT(*)::int AS items_count
                 FROM transaction_items
                 GROUP BY transaction_id
             ) ic ON ic.transaction_id = t.id
             WHERE ${whereClause}
             ORDER BY t.created_at DESC
             LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
            [...params, limit, offset]
        );

        return { invoices: dataResult.rows, total };
    });
}

// ---- Get Single Invoice (with IDOR Protection) ----

export async function getInvoiceById(
    shopId: string,
    customerId: string,
    invoiceId: string
): Promise<InvoiceLookupResult> {
    return withTenant(shopId, async (client) => {
        const existsResult = await client.query(
            `SELECT id, customer_id
             FROM transactions
             WHERE id = $1 AND NOT is_deleted`,
            [invoiceId]
        );

        if (existsResult.rows.length === 0) {
            return { found: false, authorized: false, data: null };
        }

        const invoiceRow = existsResult.rows[0];

        if (invoiceRow.customer_id !== customerId) {
            logger.warn('IDOR ATTEMPT: Customer tried to access another customer\'s invoice', {
                attackerCustomerId: customerId,
                targetInvoiceId: invoiceId,
                actualOwnerId: invoiceRow.customer_id,
                shopId,
                timestamp: new Date().toISOString(),
            });

            return { found: true, authorized: false, data: null };
        }

        const detailResult = await client.query(
            `SELECT t.id, t.invoice_number, t.status, t.subtotal_cents,
                    t.discount_cents, t.tax_cents, t.total_cents, t.paid_cents,
                    t.balance_cents, t.payment_mode, t.notes, t.created_at,
                    c.name AS customer_name, c.phone AS customer_phone
             FROM transactions t
             LEFT JOIN customers c ON c.id = t.customer_id
             WHERE t.id = $1 AND t.customer_id = $2 AND NOT t.is_deleted`,
            [invoiceId, customerId]
        );

        if (detailResult.rows.length === 0) {
            return { found: false, authorized: false, data: null };
        }

        const invoice = detailResult.rows[0];

        const itemsResult = await client.query(
            `SELECT id, name, quantity, unit, unit_price_cents,
                    discount_cents, tax_cents, total_cents, hsn_code
             FROM transaction_items
             WHERE transaction_id = $1
             ORDER BY id`,
            [invoiceId]
        );

        const detail: InvoiceDetail = {
            ...invoice,
            items_count: itemsResult.rows.length,
            items: itemsResult.rows,
        };

        return { found: true, authorized: true, data: detail };
    });
}

// ---- Invoice Stats ----

export async function getInvoiceStats(
    shopId: string,
    customerId: string
): Promise<{
    total_invoices: number;
    total_billed_cents: number;
    total_paid_cents: number;
    outstanding_cents: number;
    last_invoice_date: Date | null;
}> {
    return withTenant(shopId, async (client) => {
        const result = await client.query(
            `SELECT
                 COUNT(*)::int AS total_invoices,
                 COALESCE(SUM(total_cents), 0)::bigint AS total_billed_cents,
                 COALESCE(SUM(paid_cents), 0)::bigint AS total_paid_cents,
                 COALESCE(SUM(balance_cents), 0)::bigint AS outstanding_cents,
                 MAX(created_at) AS last_invoice_date
             FROM transactions
             WHERE customer_id = $1 AND NOT is_deleted`,
            [customerId]
        );

        const row = result.rows[0] || {};
        return {
            total_invoices: row.total_invoices || 0,
            total_billed_cents: Number(row.total_billed_cents) || 0,
            total_paid_cents: Number(row.total_paid_cents) || 0,
            outstanding_cents: Number(row.outstanding_cents) || 0,
            last_invoice_date: row.last_invoice_date || null,
        };
    });
}
