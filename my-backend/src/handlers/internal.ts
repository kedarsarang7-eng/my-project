// ============================================================================
// Internal API Handlers (For Server-to-Server Communication) (DynamoDB)
// ============================================================================
import path from 'path';
import { internalHandler } from '../middleware/internal-auth';
import * as invoiceService from '../services/invoice.service';
import { StorageService } from '../services/storage.service';
import { Keys, queryItems, getItem } from '../config/dynamodb.config';
import * as response from '../utils/response';

const storageService = new StorageService();

/**
 * GET /internal/invoices — Fetch invoices for a customer
 */
export const getCustomerInvoices = internalHandler(async (event, _context, auth) => {
    if (!auth.customerId) return response.badRequest('Missing x-customer-id header');

    const { status, from_date, to_date, page, limit } = event.queryStringParameters || {};
    const pageNum = parseInt(page || '1');
    const limitNum = parseInt(limit || '20');
    const pk = Keys.tenantPK(auth.tenantId);

    const invoices = await queryItems<Record<string, any>>(pk, 'INVOICE#', {
        filterExpression: 'customerId = :cid AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':cid': auth.customerId, ':false': false },
    });

    let items = invoices.items;
    if (status) items = items.filter(i => i.status === status);
    if (from_date) items = items.filter(i => (i.createdAt || '') >= from_date);
    if (to_date) items = items.filter(i => (i.createdAt || '') <= to_date);

    items.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));
    const total = items.length;
    const offset = (pageNum - 1) * limitNum;
    const paged = items.slice(offset, offset + limitNum);

    // Enrich with item counts
    const enriched = await Promise.all(paged.map(async inv => {
        const lineItems = await queryItems(Keys.invoiceLineItemPK(inv.id), 'LINEITEM#');
        return {
            id: inv.id, invoiceNumber: inv.invoiceNumber, status: inv.status,
            subtotalCents: inv.subtotalCents, discountCents: inv.discountCents,
            taxCents: inv.taxCents, totalCents: inv.totalCents,
            paidCents: inv.paidCents, balanceCents: inv.balanceCents,
            paymentMode: inv.paymentMode, notes: inv.notes, createdAt: inv.createdAt,
            itemsCount: lineItems.items.length,
        };
    }));

    return response.success({
        invoices: enriched,
        pagination: { page: pageNum, limit: limitNum, total },
    });
});

/**
 * GET /internal/invoices/{id} — Single invoice detail for customer
 */
export const getCustomerInvoiceById = internalHandler(async (event, _context, auth) => {
    if (!auth.customerId) return response.badRequest('Missing x-customer-id header');

    const invoiceId = event.pathParameters?.id;
    if (!invoiceId) return response.badRequest('Missing invoice id');

    const pk = Keys.tenantPK(auth.tenantId);
    const invoice = await getItem<Record<string, any>>(pk, Keys.invoiceSK(invoiceId));

    if (!invoice || invoice.isDeleted) {
        return response.error(404, 'NOT_FOUND', 'Invoice not found');
    }

    if (invoice.customerId !== auth.customerId) {
        return response.error(403, 'FORBIDDEN', 'Access denied');
    }

    // Get customer info
    const customer = invoice.customerId
        ? await getItem<Record<string, any>>(pk, Keys.customerSK(invoice.customerId))
        : null;

    // Get line items
    const lineItems = await queryItems<Record<string, any>>(Keys.invoiceLineItemPK(invoiceId), 'LINEITEM#');

    return response.success({
        ...invoice,
        customerName: customer?.name, customerPhone: customer?.phone,
        itemsCount: lineItems.items.length,
        items: lineItems.items.map(li => ({
            id: li.id, name: li.name, quantity: li.quantity, unit: li.unit,
            unitPriceCents: li.unitPriceCents, discountCents: li.discountCents,
            taxCents: li.taxCents, totalCents: li.totalCents, hsnCode: li.hsnCode,
        })),
    });
});

/**
 * GET /internal/invoices/stats/summary — Customer invoice stats
 */
export const getCustomerInvoiceStats = internalHandler(async (event, _context, auth) => {
    if (!auth.customerId) return response.badRequest('Missing x-customer-id header');

    const pk = Keys.tenantPK(auth.tenantId);
    const invoices = await queryItems<Record<string, any>>(pk, 'INVOICE#', {
        filterExpression: 'customerId = :cid AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':cid': auth.customerId, ':false': false },
    });

    const items = invoices.items;
    const totalBilledCents = items.reduce((s, i) => s + (Number(i.totalCents) || 0), 0);
    const totalPaidCents = items.reduce((s, i) => s + (Number(i.paidCents) || 0), 0);
    const outstandingCents = items.reduce((s, i) => s + (Number(i.balanceCents) || 0), 0);
    const lastInvoiceDate = items.length > 0
        ? items.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))[0]?.createdAt
        : null;

    return response.success({
        total_invoices: items.length,
        total_billed_cents: totalBilledCents,
        total_paid_cents: totalPaidCents,
        outstanding_cents: outstandingCents,
        last_invoice_date: lastInvoiceDate,
    });
});

/**
 * GET /internal/storage/signed-url
 */
export const getInternalSignedUrl = internalHandler(async (event, _context, auth) => {
    const action = event.queryStringParameters?.action as 'upload' | 'download';
    const filePath = event.queryStringParameters?.path;
    const contentType = event.queryStringParameters?.contentType;

    if (!action || !filePath) return response.badRequest('Missing action or path');
    if (action === 'upload' && !contentType) return response.badRequest('Missing contentType for upload');

    // AUDIT FIX #7: MIME type allowlist (consistent with storage.ts)
    const ALLOWED_UPLOAD_MIME_TYPES = [
        'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml',
        'application/pdf', 'text/csv', 'text/plain',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-excel', 'application/json',
    ];
    if (action === 'upload' && !ALLOWED_UPLOAD_MIME_TYPES.includes(contentType!)) {
        return response.badRequest(`Unsupported file type: ${contentType}`);
    }

    try {
        // AUDIT FIX #8: Use robust path sanitization matching storage.ts
        let decoded: string;
        try {
            decoded = decodeURIComponent(filePath);
        } catch {
            return response.badRequest('Invalid file path encoding');
        }
        const normalized = path.normalize(decoded).replace(/\\/g, '/');
        if (normalized.includes('..') || normalized.startsWith('/')) {
            return response.badRequest('Path traversal detected');
        }
        if (!/^[a-zA-Z0-9\-_./]+$/.test(normalized)) {
            return response.badRequest('Invalid characters in file path');
        }
        if (normalized.includes('//') || normalized.startsWith('.')) {
            return response.badRequest('Invalid file path format');
        }
        const safePath = normalized;
        const tenantScopedPath = `tenants/${auth.tenantId}/${safePath}`;

        let url: string;
        if (action === 'upload') {
            url = await storageService.getUploadUrl(tenantScopedPath, contentType!);
        } else {
            url = await storageService.getDownloadUrl(tenantScopedPath);
        }

        return response.success({ url, path: tenantScopedPath, expiresIn: 900 });
    } catch (err: any) {
        return response.badRequest('Invalid path or storage request');
    }
});
