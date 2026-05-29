// ============================================================================
// Lambda Handler — Invoices (Create & Finalize)
// ============================================================================
// Endpoints:
//   POST /invoices              — Create a new invoice
//   POST /invoices/{id}/finalize — Finalize a draft invoice
//   POST /invoices/{id}/void    — Void an invoice
//   POST /invoices/{id}/send    — Send invoice to customer
//
// Uses Zod validation for invoice creation.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { parseBody } from '../middleware/validation';
import { createInvoiceSchema, updateInvoiceSchema, voidInvoiceSchema, sendInvoiceSchema, returnInvoiceSchema } from '../schemas';
import * as invoiceService from '../services/invoice.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import * as wsService from '../services/websocket.service';
import { WSEventName } from '../types/websocket.types';
import { withIdempotency } from '../middleware/idempotency';
import { validateHsnGstRate } from '../services/hsn.validator';
import { Keys, batchGetItems } from '../config/dynamodb.config';
// UNS event_bus — task 14.9 migration of T-BIL-2/3/4/5 producers
import { emitUnsEvent } from '../notifications/event-bus';

/**
 * POST /invoices
 * Create a new invoice (transaction + line items).
 */
export const createInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    withIdempotency(async (event, _context, auth) => {
        try {
            const parsed = parseBody(createInvoiceSchema, event);
            if (!parsed.success) return parsed.error;

            // ── HSN→GST validation for each line item ──────────────────
            // PERF-5 FIX: Parallelize HSN validation — was sequential (N × getItem).
            // Now all validations run concurrently via Promise.all.
            // Batch-fetch all products to get their stored HSN codes and rates
            const productIds = (parsed.data.items as any[]).map((item: any) => item.productId);
            const productKeys = productIds.map((id: string) => ({
                PK: Keys.tenantPK(auth.tenantId),
                SK: `PRODUCT#${id}`,
            }));
            const products = await batchGetItems<Record<string, any>>(productKeys);
            const productMap = new Map(products.map(p => [p.id || p.SK?.replace('PRODUCT#', ''), p]));

            // Run all HSN validations concurrently
            const hsnValidationResults = await Promise.all(
                products
                    .filter(product => product.hsnCode && !product.isDeleted)
                    .map(async product => {
                        const hsnResult = await validateHsnGstRate(
                            product.hsnCode,
                            Number(product.cgstRateBp) || 0,
                            Number(product.sgstRateBp) || 0,
                        );
                        return { product, hsnResult };
                    })
            );

            // Check for any validation failures
            for (const { product, hsnResult } of hsnValidationResults) {
                if (!hsnResult.valid) {
                    logger.warn('HSN/GST mismatch detected on invoice creation', {
                        tenantId: auth.tenantId,
                        productId: product.id,
                        productName: product.name,
                        hsnCode: product.hsnCode,
                        result: hsnResult,
                    });
                    return response.error(422, 'HSN_GST_MISMATCH', hsnResult.message || 'GST rate mismatch', {
                        hsnCode: hsnResult.hsnCode,
                        productId: product.id,
                        productName: product.name,
                        expectedCgstRateBp: hsnResult.expected?.cgstRateBp,
                        expectedSgstRateBp: hsnResult.expected?.sgstRateBp,
                        submittedCgstRateBp: hsnResult.submitted?.cgstRateBp,
                        submittedSgstRateBp: hsnResult.submitted?.sgstRateBp,
                    });
                }
            }

            const result = await invoiceService.createInvoice(
                auth.tenantId,
                auth.sub,
                {
                    items: (parsed.data.items as any[]).map((item) => ({
                        ...item,
                        unitPrice: item.unitPrice ?? item.unitPriceCents,
                    })) as any,
                    customerName: parsed.data.customerName,
                    customerPhone: parsed.data.customerPhone,
                    customerGstin: parsed.data.customerGstin,
                    paymentMode: parsed.data.paymentMode,
                    notes: parsed.data.notes,
                    discountCents: parsed.data.discountCents,
                    isInterState: parsed.data.isInterState,
                    isInterStateOverride: parsed.data.isInterStateOverride,
                    invoiceType: parsed.data.invoiceType as any,
                    invoiceProfileId: parsed.data.invoiceProfileId,
                    splitPayments: parsed.data.splitPayments as any,
                    metadata: parsed.data.metadata as Record<string, unknown>,
                    // Hardware: Transport details
                    lrNumber: parsed.data.lrNumber,
                    transporterName: parsed.data.transporterName,
                    ewayBillNumber: parsed.data.ewayBillNumber,
                    transportMode: parsed.data.transportMode,
                },
                auth.role,
                auth.businessType,
            );

            // Broadcast bill created event
            wsService.emitEvent(auth.tenantId, WSEventName.BILL_CREATED, {
                invoiceId: result.id,
                invoiceNumber: result.invoiceNumber,
                totalCents: result.totalCents,
                staffId: auth.sub,
            }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

            // UNS canonical emit (T-BIL-2: billing.invoice.created)
            // Channels default to in_app (matches the legacy WS-only delivery surface
            // for the migration window). Per-role channels resolved server-side via
            // the registry. Recipients are tenant-scoped: shop owner / cashier on
            // every connected device of the same tenant. We emit a single envelope
            // with the tenant id as the recipient anchor so the dispatch layer can
            // expand to all tenant members.
            emitUnsEvent({
                eventName: 'billing.invoice.created',
                category: 'billing',
                subCategory: 'invoice',
                priority: 'normal',
                actorId: auth.sub,
                targetId: result.id,
                recipients: [
                    { user_id: auth.tenantId, role: 'admin' },
                ],
                payload: {
                    tenantId: auth.tenantId,
                    invoiceId: result.id,
                    invoiceNumber: result.invoiceNumber,
                    totalCents: result.totalCents,
                    staffId: auth.sub,
                },
                sourceModule: 'my-backend/src/handlers/invoices.ts',
                dedupScopeFields: ['invoiceId'],
            }).catch(() => { /* non-fatal during migration window */ });

            return response.success(result, 201);
        } catch (err: unknown) {
            if (err instanceof invoiceService.InvoiceValidationError) {
                return response.error(422, 'INVOICE_VALIDATION_ERROR', err.message, err.details);
            }
            if (err instanceof invoiceService.InvoiceError) {
                return response.error(err.statusCode, 'INVOICE_ERROR', err.message);
            }
            throw err;
        }
    })
);

/**
 * POST /invoices/{id}/finalize
 * Finalize a draft invoice.
 */
export const finalizeInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    withIdempotency(async (event, _context, auth) => {
        try {
            const invoiceId = event.pathParameters?.id;
            if (!invoiceId) {
                return response.badRequest('Missing invoice id');
            }

            const result = await invoiceService.finalizeInvoice(auth.tenantId, invoiceId, {
                finalizedBy: auth.sub,
            });

            // Broadcast finalized bill event
            wsService.emitEvent(auth.tenantId, WSEventName.BILL_CREATED, {
                action: 'finalized',
                invoiceId,
            }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

            // UNS canonical emit (T-BIL-3: billing.invoice.finalized)
            emitUnsEvent({
                eventName: 'billing.invoice.finalized',
                category: 'billing',
                subCategory: 'invoice',
                priority: 'normal',
                actorId: auth.sub,
                targetId: invoiceId,
                recipients: [
                    { user_id: auth.tenantId, role: 'admin' },
                ],
                payload: {
                    tenantId: auth.tenantId,
                    invoiceId,
                    finalizedBy: auth.sub,
                },
                sourceModule: 'my-backend/src/handlers/invoices.ts',
                dedupScopeFields: ['invoiceId'],
            }).catch(() => { /* non-fatal during migration window */ });

            return response.success(result);
        } catch (err: unknown) {
            if (err instanceof invoiceService.InvoiceError) {
                return response.error(err.statusCode, 'INVOICE_ERROR', err.message);
            }
            throw err;
        }
    })
);

/**
 * POST /invoices/{id}/void
 * Void (cancel) an invoice and reverse stock changes.
 */
export const voidInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    withIdempotency(async (event, _context, auth) => {
        try {
            const invoiceId = event.pathParameters?.id;
            if (!invoiceId) return response.badRequest('Missing invoice id');

            const parsed = parseBody(voidInvoiceSchema, event);
            if (!parsed.success) return parsed.error;

            const result = await invoiceService.voidInvoice(auth.tenantId, invoiceId, parsed.data.reason);
            return response.success(result);
        } catch (err: unknown) {
            if (err instanceof invoiceService.InvoiceError) {
                return response.error(err.statusCode, 'INVOICE_ERROR', err.message);
            }
            throw err;
        }
    })
);

/**
 * POST /invoices/{id}/send
 * Send an invoice to customer via email/SMS/WhatsApp.
 */
export const sendInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    withIdempotency(async (event, _context, auth) => {
        try {
            const invoiceId = event.pathParameters?.id;
            if (!invoiceId) return response.badRequest('Missing invoice id');

            const parsed = parseBody(sendInvoiceSchema, event);
            if (!parsed.success) return parsed.error;

            const result = await invoiceService.sendInvoice(auth.tenantId, invoiceId, parsed.data.method);
            return response.success(result);
        } catch (err: unknown) {
            if (err instanceof invoiceService.InvoiceError) {
                return response.error(err.statusCode, 'INVOICE_ERROR', err.message);
            }
            throw err;
        }
    })
);

/**
 * PUT /invoices/{id}
 * H1 FIX: Edit a draft invoice — replace items and recalculate totals.
 * Only works on invoices with status 'draft'. Finalized/voided/paid invoices cannot be edited.
 */
export const updateInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    withIdempotency(async (event, _context, auth) => {
        try {
            const invoiceId = event.pathParameters?.id;
            if (!invoiceId) return response.badRequest('Missing invoice id');

            const parsed = parseBody(updateInvoiceSchema, event);
            if (!parsed.success) return parsed.error;

            const result = await invoiceService.updateInvoice(
                auth.tenantId,
                invoiceId,
                {
                    items: (parsed.data.items as any[]).map((item) => ({
                        ...item,
                        unitPrice: item.unitPrice ?? item.unitPriceCents,
                    })) as any,
                    customerName: parsed.data.customerName,
                    customerPhone: parsed.data.customerPhone,
                    customerGstin: parsed.data.customerGstin,
                    paymentMode: parsed.data.paymentMode,
                    notes: parsed.data.notes,
                    discountCents: parsed.data.discountCents,
                    isInterState: parsed.data.isInterState,
                    invoiceType: parsed.data.invoiceType as any,
                    invoiceProfileId: parsed.data.invoiceProfileId,
                }
            );

            // Broadcast update event
            wsService.emitEvent(auth.tenantId, WSEventName.BILL_CREATED, {
                action: 'updated',
                invoiceId: result.id,
                invoiceNumber: result.invoiceNumber,
                totalCents: result.totalCents,
                staffId: auth.sub,
            }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

            // UNS canonical emit (T-BIL-4: billing.invoice.updated)
            emitUnsEvent({
                eventName: 'billing.invoice.updated',
                category: 'billing',
                subCategory: 'invoice',
                priority: 'low',
                actorId: auth.sub,
                targetId: result.id,
                recipients: [
                    { user_id: auth.tenantId, role: 'admin' },
                ],
                payload: {
                    tenantId: auth.tenantId,
                    invoiceId: result.id,
                    invoiceNumber: result.invoiceNumber,
                    totalCents: result.totalCents,
                    staffId: auth.sub,
                },
                sourceModule: 'my-backend/src/handlers/invoices.ts',
                // Registry §4.3: dedup includes version so successive saves emit fresh events.
                dedupScopeFields: ['invoiceId', 'totalCents'],
            }).catch(() => { /* non-fatal during migration window */ });

            return response.success(result);
        } catch (err: unknown) {
            if (err instanceof invoiceService.InvoiceError) {
                return response.error(err.statusCode, 'INVOICE_ERROR', err.message);
            }
            throw err;
        }
    })
);

/**
 * POST /invoices/{id}/return
 * Process a return/refund and create a credit note.
 */
export const returnInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    withIdempotency(async (event, _context, auth) => {
        try {
            const invoiceId = event.pathParameters?.id;
            if (!invoiceId) return response.badRequest('Missing invoice id');

            const parsed = parseBody(returnInvoiceSchema, event);
            if (!parsed.success) return parsed.error;

            const result = await invoiceService.createReturn(
                auth.tenantId,
                invoiceId,
                parsed.data.items as any,
                auth.sub,
            );

            // Broadcast return event
            wsService.emitEvent(auth.tenantId, WSEventName.BILL_CREATED, {
                action: 'returned',
                invoiceId,
                creditNoteId: result.creditNoteId,
                creditAmountCents: result.creditAmountCents,
                staffId: auth.sub,
            }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

            // UNS canonical emit (T-BIL-5: billing.invoice.returned)
            emitUnsEvent({
                eventName: 'billing.invoice.returned',
                category: 'billing',
                subCategory: 'invoice',
                priority: 'normal',
                actorId: auth.sub,
                targetId: invoiceId,
                recipients: [
                    { user_id: auth.tenantId, role: 'admin' },
                ],
                payload: {
                    tenantId: auth.tenantId,
                    invoiceId,
                    creditNoteId: result.creditNoteId,
                    creditAmountCents: result.creditAmountCents,
                    staffId: auth.sub,
                },
                sourceModule: 'my-backend/src/handlers/invoices.ts',
                dedupScopeFields: ['invoiceId', 'creditNoteId'],
            }).catch(() => { /* non-fatal during migration window */ });

            return response.success(result, 201);
        } catch (err: unknown) {
            if (err instanceof invoiceService.InvoiceError) {
                return response.error(err.statusCode, 'INVOICE_ERROR', err.message);
            }
            throw err;
        }
    })
);
