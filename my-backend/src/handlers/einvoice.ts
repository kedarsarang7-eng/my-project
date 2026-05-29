// ============================================================================
// Lambda Handlers — E-Invoice (IRN Generation/Cancellation)
// ============================================================================
// GST-3.2: E-Invoice integration via NIC API
//
// POST /invoices/{id}/einvoice     — Generate e-invoice (IRN)
// POST /invoices/{id}/einvoice/cancel — Cancel e-invoice (within 24h)
// GET  /invoices/{id}/einvoice     — Get e-invoice status
//
// Access: Owner, Admin, Accountant
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import * as einvoiceService from '../services/einvoice.service';
import * as response from '../utils/response';
import { z } from 'zod';
import { parseBody } from '../middleware/validation';

const cancelSchema = z.object({
    cancelReason: z.enum(['1', '2', '3', '4']),
    cancelRemarks: z.string().min(1).max(200),
});

const ewaySchema = z.object({
    fromPlace: z.string().min(1),
    toPlace: z.string().min(1),
    distanceKm: z.number().int().positive(),
    fromPincode: z.string().optional(),
    toPincode: z.string().optional(),
    vehicleNumber: z.string().optional(),
    transporterId: z.string().optional(),
    transporterName: z.string().optional(),
});

const einvoiceSettingsSchema = z.object({
    isEnabled: z.boolean(),
    environment: z.enum(['sandbox', 'production']),
    clientId: z.string().optional(),
    clientSecret: z.string().optional(),
    username: z.string().optional(),
    password: z.string().optional(),
    ewayBillPath: z.string().optional(),
});

/**
 * POST /invoices/{id}/einvoice
 */
export const generateEInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const invoiceId = event.pathParameters?.id;
        if (!invoiceId) return response.badRequest('Missing invoice ID');

        try {
            const result = await einvoiceService.generateEInvoice(
                auth.tenantId, invoiceId,
            );
            return response.success(result, 201);
        } catch (err) {
            if (err instanceof einvoiceService.EInvoiceError) {
                return response.error(err.statusCode, 'EINVOICE_ERROR', err.message);
            }
            throw err;
        }
    },
);

/**
 * POST /invoices/{id}/einvoice/cancel
 */
export const cancelEInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _context, auth) => {
        const invoiceId = event.pathParameters?.id;
        if (!invoiceId) return response.badRequest('Missing invoice ID');

        const parsed = parseBody(cancelSchema, event);
        if (!parsed.success) return parsed.error;

        try {
            const result = await einvoiceService.cancelEInvoice(
                auth.tenantId, invoiceId,
                parsed.data.cancelReason,
                parsed.data.cancelRemarks,
            );
            return response.success(result);
        } catch (err) {
            if (err instanceof einvoiceService.EInvoiceError) {
                return response.error(err.statusCode, 'EINVOICE_ERROR', err.message);
            }
            throw err;
        }
    },
);

/**
 * GET /invoices/{id}/einvoice
 */
export const getEInvoiceStatus = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const invoiceId = event.pathParameters?.id;
        if (!invoiceId) return response.badRequest('Missing invoice ID');

        const { getItem } = await import('../config/dynamodb.config');
        const { Keys } = await import('../config/dynamodb.config');

        const record = await getItem<Record<string, any>>(
            Keys.tenantPK(auth.tenantId),
            `EINVOICE#${invoiceId}`,
        );

        if (!record) {
            return response.success({
                invoiceId,
                hasEInvoice: false,
                status: 'not_generated',
            });
        }

        return response.success({
            invoiceId,
            hasEInvoice: true,
            irn: record.irn,
            ackNo: record.ackNo,
            ackDt: record.ackDt,
            signedQrCode: record.signedQrCode,
            status: record.status,
            createdAt: record.createdAt,
            cancelledAt: record.cancelledAt || null,
        });
    },
);

/**
 * POST /invoices/{id}/ewaybill
 */
export const generateEWayBill = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const invoiceId = event.pathParameters?.id;
        if (!invoiceId) return response.badRequest('Missing invoice ID');

        const parsed = parseBody(ewaySchema, event);
        if (!parsed.success) return parsed.error;

        try {
            const result = await einvoiceService.generateEWayBill(
                auth.tenantId,
                invoiceId,
                parsed.data,
            );
            return response.success(result, 201);
        } catch (err) {
            if (err instanceof einvoiceService.EInvoiceError) {
                return response.error(err.statusCode, 'EWAY_BILL_ERROR', err.message);
            }
            throw err;
        }
    },
);

/**
 * GET /settings/einvoice
 */
export const getEInvoiceSettings = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    async (_event, _context, auth) => {
        const result = await einvoiceService.getEInvoiceSettings(auth.tenantId);
        return response.success(result);
    },
);

/**
 * PUT /settings/einvoice
 */
export const upsertEInvoiceSettings = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _context, auth) => {
        const parsed = parseBody(einvoiceSettingsSchema, event);
        if (!parsed.success) return parsed.error;
        const result = await einvoiceService.upsertEInvoiceSettings(
            auth.tenantId,
            parsed.data,
        );
        return response.success(result);
    },
);
