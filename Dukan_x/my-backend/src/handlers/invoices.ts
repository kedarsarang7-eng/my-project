// ============================================================================
// Lambda Handler — Invoices (Create & Finalize)
// ============================================================================
// Endpoints:
//   POST /invoices              — Create a new invoice
//   POST /invoices/{id}/finalize — Finalize a draft invoice
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import * as invoiceService from '../services/invoice.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

/**
 * POST /invoices
 * Create a new invoice (transaction + line items).
 */
export const createInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event, _context, auth) => {
        try {
            const body = JSON.parse(event.body || '{}');

            if (!body.items || !Array.isArray(body.items) || body.items.length === 0) {
                return response.badRequest('Missing required field: items (array)');
            }

            const result = await invoiceService.createInvoice(
                auth.tenantId,
                auth.sub,
                {
                    items: body.items,
                    customerName: body.customerName,
                    customerPhone: body.customerPhone,
                    invoiceDate: body.invoiceDate,
                    paymentMode: body.paymentMode,
                    notes: body.notes,
                }
            );

            return response.success(result, 201);
        } catch (err: unknown) {
            if (err instanceof invoiceService.InvoiceError) {
                return response.error(err.statusCode, 'INVOICE_ERROR', err.message);
            }
            throw err;
        }
    }
);

/**
 * POST /invoices/{id}/finalize
 * Finalize a draft invoice.
 */
export const finalizeInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event, _context, auth) => {
        try {
            const invoiceId = event.pathParameters?.id;
            if (!invoiceId) {
                return response.badRequest('Missing invoice id');
            }

            const result = await invoiceService.finalizeInvoice(auth.tenantId, invoiceId);
            return response.success(result);
        } catch (err: unknown) {
            if (err instanceof invoiceService.InvoiceError) {
                return response.error(err.statusCode, 'INVOICE_ERROR', err.message);
            }
            throw err;
        }
    }
);

/**
 * POST /invoices/{id}/void
 * Void (cancel) an invoice and reverse stock changes.
 */
export const voidInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _context, auth) => {
        try {
            const invoiceId = event.pathParameters?.id;
            if (!invoiceId) return response.badRequest('Missing invoice id');

            const body = JSON.parse(event.body || '{}');
            const result = await invoiceService.voidInvoice(auth.tenantId, invoiceId, body.reason);
            return response.success(result);
        } catch (err: unknown) {
            if (err instanceof invoiceService.InvoiceError) {
                return response.error(err.statusCode, 'INVOICE_ERROR', err.message);
            }
            throw err;
        }
    }
);

/**
 * POST /invoices/{id}/send
 * Send an invoice to customer via email/SMS/WhatsApp.
 */
export const sendInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event, _context, auth) => {
        try {
            const invoiceId = event.pathParameters?.id;
            if (!invoiceId) return response.badRequest('Missing invoice id');

            const body = JSON.parse(event.body || '{}');
            const result = await invoiceService.sendInvoice(auth.tenantId, invoiceId, body.method);
            return response.success(result);
        } catch (err: unknown) {
            if (err instanceof invoiceService.InvoiceError) {
                return response.error(err.statusCode, 'INVOICE_ERROR', err.message);
            }
            throw err;
        }
    }
);
