// ============================================================================
// Invoice Service — Create & Finalize Invoices
// ============================================================================
// Handles invoice creation from the Flutter billing screen.
// All monetary values are stored as BIGINT paise (cents).
// ============================================================================

import { getPool, withTransaction } from '../config/db.config';
import { logger } from '../utils/logger';

// ---- Types ----

export interface CreateInvoiceInput {
    items: InvoiceItemInput[];
    customerName?: string;
    customerPhone?: string;
    invoiceDate?: string;
    paymentMode?: string;
    notes?: string;
}

export interface InvoiceItemInput {
    productId: string;
    quantity: number;
    unitPrice: number; // Frontend sends in PAISE (cents)
}

export interface InvoiceResult {
    id: string;
    invoiceNumber: string;
    status: string;
    totalCents: number;
    itemsCount: number;
    createdAt: string;
}

// ---- Service Functions ----

/**
 * Create a new invoice (transaction + line items).
 * Expects all monetary values in PAISE (cents).
 */
export async function createInvoice(
    tenantId: string,
    createdBy: string,
    input: CreateInvoiceInput
): Promise<InvoiceResult> {
    if (!input.items || input.items.length === 0) {
        throw new InvoiceError('Invoice must have at least one item');
    }

    return withTransaction(tenantId, async (client) => {
        // 1. Generate invoice number
        const seqResult = await client.query(
            `SELECT COALESCE(MAX(CAST(SUBSTRING(invoice_number FROM '[0-9]+$') AS INTEGER)), 0) + 1 AS next_num
             FROM transactions WHERE tenant_id = $1 AND NOT is_deleted`,
            [tenantId]
        );
        const nextNum = seqResult.rows[0].next_num || 1;
        const invoiceNumber = `INV-${nextNum.toString().padStart(6, '0')}`;

        // 2. Calculate totals from items
        let subtotalCents = 0;
        const resolvedItems: Array<{
            itemId: string;
            name: string;
            quantity: number;
            unitPriceCents: number;
            totalCents: number;
            unit: string;
        }> = [];

        for (const item of input.items) {
            // Lookup product for name and validation
            const productResult = await client.query(
                `SELECT id, name, unit, sale_price_cents, current_stock, is_service
                 FROM inventory WHERE id = $1 AND tenant_id = $2 AND NOT is_deleted`,
                [item.productId, tenantId]
            );

            if (productResult.rows.length === 0) {
                throw new InvoiceError(`Product not found: ${item.productId}`);
            }

            const product = productResult.rows[0];
            // Use price from request (already in paise), fallback to DB price
            const unitPriceCents = item.unitPrice || product.sale_price_cents;
            const lineTotalCents = Math.round(unitPriceCents * item.quantity);

            resolvedItems.push({
                itemId: product.id,
                name: product.name,
                quantity: item.quantity,
                unitPriceCents,
                totalCents: lineTotalCents,
                unit: product.unit || 'pcs',
            });

            subtotalCents += lineTotalCents;

            // Decrement stock (skip for services)
            if (!product.is_service) {
                await client.query(
                    `UPDATE inventory SET current_stock = current_stock - $1, updated_at = NOW()
                     WHERE id = $2 AND tenant_id = $3`,
                    [item.quantity, item.productId, tenantId]
                );
            }
        }

        const totalCents = subtotalCents; // TODO: Add tax/discount logic

        // 3. Insert transaction
        const txnResult = await client.query(
            `INSERT INTO transactions
             (tenant_id, invoice_number, customer_name, customer_phone,
              subtotal_cents, total_cents, paid_cents, balance_cents,
              payment_mode, status, notes, created_by, created_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'draft', $10, $11, COALESCE($12::timestamptz, NOW()))
             RETURNING id, invoice_number, status, total_cents, created_at`,
            [
                tenantId, invoiceNumber,
                input.customerName || 'Walk-in',
                input.customerPhone || null,
                subtotalCents, totalCents,
                0, totalCents, // paid=0, balance=total
                input.paymentMode || 'cash',
                input.notes || null,
                createdBy,
                input.invoiceDate || null,
            ]
        );

        const txn = txnResult.rows[0];

        // 4. Insert line items
        for (const item of resolvedItems) {
            await client.query(
                `INSERT INTO transaction_items
                 (tenant_id, transaction_id, item_id, name, quantity, unit,
                  unit_price_cents, total_cents)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
                [
                    tenantId, txn.id, item.itemId, item.name,
                    item.quantity, item.unit,
                    item.unitPriceCents, item.totalCents,
                ]
            );
        }

        logger.info('Invoice created', {
            tenantId, invoiceNumber, totalCents, items: resolvedItems.length,
        });

        return {
            id: txn.id,
            invoiceNumber: txn.invoice_number,
            status: txn.status,
            totalCents: Number(txn.total_cents),
            itemsCount: resolvedItems.length,
            createdAt: txn.created_at?.toISOString() || new Date().toISOString(),
        };
    });
}

/**
 * Finalize a draft invoice (mark as finalized, record payment).
 */
export async function finalizeInvoice(
    tenantId: string,
    invoiceId: string
): Promise<{ id: string; status: string }> {
    return withTransaction(tenantId, async (client) => {
        const result = await client.query(
            `UPDATE transactions SET status = 'finalized', paid_cents = total_cents, balance_cents = 0, updated_at = NOW()
             WHERE id = $1 AND tenant_id = $2 AND status = 'draft' AND NOT is_deleted
             RETURNING id, status`,
            [invoiceId, tenantId]
        );

        if (result.rows.length === 0) {
            throw new InvoiceError('Invoice not found or already finalized', 404);
        }

        logger.info('Invoice finalized', { tenantId, invoiceId });

        return { id: result.rows[0].id, status: result.rows[0].status };
    });
}

/**
 * Void an invoice (cancel it, reverse stock changes).
 */
export async function voidInvoice(
    tenantId: string,
    invoiceId: string,
    reason?: string
): Promise<{ id: string; status: string }> {
    return withTransaction(tenantId, async (client) => {
        // Check current status
        const current = await client.query(
            `SELECT id, status FROM transactions WHERE id = $1 AND tenant_id = $2 AND NOT is_deleted`,
            [invoiceId, tenantId]
        );

        if (current.rows.length === 0) {
            throw new InvoiceError('Invoice not found', 404);
        }

        if (current.rows[0].status === 'voided') {
            throw new InvoiceError('Invoice is already voided', 409);
        }

        // Reverse stock for each line item
        const items = await client.query(
            `SELECT item_id, quantity FROM transaction_items WHERE transaction_id = $1 AND tenant_id = $2`,
            [invoiceId, tenantId]
        );

        for (const item of items.rows) {
            if (item.item_id) {
                await client.query(
                    `UPDATE inventory SET current_stock = current_stock + $1, updated_at = NOW()
                     WHERE id = $2 AND tenant_id = $3 AND NOT is_service`,
                    [item.quantity, item.item_id, tenantId]
                );
            }
        }

        // Void the transaction
        await client.query(
            `UPDATE transactions SET status = 'voided', notes = COALESCE(notes || E'\n', '') || $1, updated_at = NOW()
             WHERE id = $2 AND tenant_id = $3`,
            [`[VOIDED] ${reason || 'No reason provided'}`, invoiceId, tenantId]
        );

        logger.info('Invoice voided', { tenantId, invoiceId, reason });

        return { id: invoiceId, status: 'voided' };
    });
}

/**
 * Send an invoice (mark as sent, record delivery method).
 * In production this would trigger email/SMS/WhatsApp via SNS.
 */
export async function sendInvoice(
    tenantId: string,
    invoiceId: string,
    method: 'email' | 'sms' | 'whatsapp' = 'email'
): Promise<{ id: string; sent: boolean; method: string }> {
    const db = getPool();

    const result = await db.query(
        `SELECT id, status, customer_name, customer_phone
         FROM transactions WHERE id = $1 AND tenant_id = $2 AND NOT is_deleted`,
        [invoiceId, tenantId]
    );

    if (result.rows.length === 0) {
        throw new InvoiceError('Invoice not found', 404);
    }

    const txn = result.rows[0];

    // Update metadata to record send
    await db.query(
        `UPDATE transactions SET metadata = jsonb_set(
            COALESCE(metadata, '{}'::jsonb),
            '{last_sent}',
            $1::jsonb
         ), updated_at = NOW()
         WHERE id = $2 AND tenant_id = $3`,
        [
            JSON.stringify({ method, sentAt: new Date().toISOString() }),
            invoiceId, tenantId,
        ]
    );

    // TODO: Trigger actual delivery via SNS/SES based on method
    logger.info('Invoice send recorded', { tenantId, invoiceId, method });

    return { id: invoiceId, sent: true, method };
}

// ---- Errors ----

export class InvoiceError extends Error {
    public statusCode: number;
    constructor(message: string, statusCode = 400) {
        super(message);
        this.name = 'InvoiceError';
        this.statusCode = statusCode;
    }
}
