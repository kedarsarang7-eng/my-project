// ============================================================================
// Lambda Handler — Inventory CRUD
// ============================================================================
// Polymorphic inventory management for all 14 business types.
// Uses `authorizedHandler` wrapper for automatic tenant context security.
// Uses Zod validation for all input payloads.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { InventoryService, InventoryError } from '../services/inventory.service';
import { UserRole } from '../types/tenant.types';
import { parseBody, parsePagination } from '../middleware/validation';
import { createInventorySchema, updateInventorySchema, stockAdjustmentSchema } from '../schemas';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { validateHsnGstRate } from '../services/hsn.validator';
import { HsnGstMismatchError } from '../utils/errors';
import * as wsService from '../services/websocket.service';
import { WSEventName } from '../types/websocket.types';
import { withIdempotency } from '../middleware/idempotency';
// UNS event_bus — task 14.9 migration of T-INV-3..7,9 producers
import { emitUnsEvent } from '../notifications/event-bus';

const inventoryService = new InventoryService();

/**
 * GET /inventory?category=&search=&page=1&limit=20
 */
export const getItems = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.CASHIER, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
    const params = event.queryStringParameters || {};
    const { page, limit } = parsePagination(event);

    const result = await inventoryService.getItems({
        tenantId: auth.tenantId,
        category: params.category,
        search: params.search,
        lowStockOnly: params.lowStock === 'true',
        isActive: params.active !== 'false',
        page,
        limit,
    });

    return response.paginated(result.items, result.total, page, limit);
});

/**
 * POST /inventory
 */
export const createItem = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    withIdempotency(async (event, _context, auth) => {
        try {
            const parsed = parseBody(createInventorySchema, event);
            if (!parsed.success) return parsed.error;

            const data = parsed.data as any;

            // HSN→GST validation: reject mismatched rates before save
            if (data.hsnCode && (data.cgstRateBp !== undefined || data.sgstRateBp !== undefined)) {
                const hsnResult = await validateHsnGstRate(
                    data.hsnCode,
                    data.cgstRateBp || 0,
                    data.sgstRateBp || 0,
                );
                if (!hsnResult.valid) {
                    return response.error(422, 'HSN_GST_MISMATCH', hsnResult.message || 'GST rate mismatch', {
                        hsnCode: hsnResult.hsnCode,
                        expectedCgstRateBp: hsnResult.expected?.cgstRateBp,
                        expectedSgstRateBp: hsnResult.expected?.sgstRateBp,
                        submittedCgstRateBp: hsnResult.submitted?.cgstRateBp,
                        submittedSgstRateBp: hsnResult.submitted?.sgstRateBp,
                    });
                }
            }

            const item = await inventoryService.createItem(auth.tenantId, data, auth.sub);

            logger.info('Inventory item created', { itemId: item.id });

            // Broadcast inventory change to all connected apps
            wsService.broadcastToBusiness(auth.tenantId, WSEventName.INVENTORY_UPDATED, {
                action: 'created', itemId: item.id, itemName: data.name,
            }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

            // UNS canonical emit (T-INV-3: inventory.item.created)
            emitUnsEvent({
                eventName: 'inventory.item.created',
                category: 'inventory',
                subCategory: 'item',
                priority: 'low',
                actorId: auth.sub,
                targetId: item.id,
                recipients: [
                    { user_id: auth.tenantId, role: 'admin' },
                ],
                payload: {
                    tenantId: auth.tenantId,
                    itemId: item.id,
                    itemName: data.name,
                    action: 'created',
                },
                sourceModule: 'my-backend/src/handlers/inventory.ts',
                dedupScopeFields: ['itemId'],
            }).catch(() => { /* non-fatal during migration window */ });

            return response.success(item, 201);
        } catch (err: unknown) {
            if (err instanceof HsnGstMismatchError) {
                return response.error(422, 'HSN_GST_MISMATCH', err.message, {
                    hsnCode: err.hsnCode,
                    expectedCgstRateBp: err.expectedCgstRateBp,
                    expectedSgstRateBp: err.expectedSgstRateBp,
                    submittedCgstRateBp: err.submittedCgstRateBp,
                    submittedSgstRateBp: err.submittedSgstRateBp,
                });
            }
            if (err instanceof InventoryError) {
                return response.error(err.statusCode, 'INVENTORY_ERROR', err.message);
            }
            throw err;
        }
    })
);

/**
 * PUT /inventory/{id}
 */
export const updateItem = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    withIdempotency(async (event, _context, auth) => {
        const itemId = event.pathParameters?.id;
        if (!itemId) return response.badRequest('Missing item id');

        const parsed = parseBody(updateInventorySchema, event);
        if (!parsed.success) return parsed.error;

        const data = parsed.data as any;

        // HSN→GST validation on update: validate if hsnCode or rates changed
        if (data.hsnCode || data.cgstRateBp !== undefined || data.sgstRateBp !== undefined) {
            // Need current item to merge hsnCode with any rate changes
            const hsnCode = data.hsnCode;
            const cgst = data.cgstRateBp;
            const sgst = data.sgstRateBp;

            // Only validate if we have an HSN code AND at least one rate
            if (hsnCode && (cgst !== undefined || sgst !== undefined)) {
                const hsnResult = await validateHsnGstRate(
                    hsnCode,
                    cgst || 0,
                    sgst || 0,
                );
                if (!hsnResult.valid) {
                    return response.error(422, 'HSN_GST_MISMATCH', hsnResult.message || 'GST rate mismatch', {
                        hsnCode: hsnResult.hsnCode,
                        expectedCgstRateBp: hsnResult.expected?.cgstRateBp,
                        expectedSgstRateBp: hsnResult.expected?.sgstRateBp,
                        submittedCgstRateBp: hsnResult.submitted?.cgstRateBp,
                        submittedSgstRateBp: hsnResult.submitted?.sgstRateBp,
                    });
                }
            }
        }

        let item;
        try {
            item = await inventoryService.updateItem(auth.tenantId, itemId, data, auth.sub);
        } catch (err: any) {
            // HIGH FIX: Handle optimistic locking conflict
            if (err.name === 'OptimisticLockError' || err.name === 'ConditionalCheckFailedException') {
                return response.error(
                    409,
                    'CONCURRENT_MODIFICATION',
                    'This item was modified by another user. Please refresh and try again.',
                    { itemId, expectedVersion: data.expectedVersion }
                );
            }
            throw err; // Re-throw for default error handling
        }
        if (!item) return response.notFound('Inventory item');

        // Broadcast inventory change
        wsService.broadcastToBusiness(auth.tenantId, WSEventName.INVENTORY_UPDATED, {
            action: 'updated', itemId,
        }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

        // UNS canonical emit (T-INV-4: inventory.item.updated)
        emitUnsEvent({
            eventName: 'inventory.item.updated',
            category: 'inventory',
            subCategory: 'item',
            priority: 'low',
            actorId: auth.sub,
            targetId: itemId,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                itemId,
                action: 'updated',
            },
            sourceModule: 'my-backend/src/handlers/inventory.ts',
            dedupScopeFields: ['itemId'],
        }).catch(() => { /* non-fatal during migration window */ });

        // Check for low stock and alert if threshold is breached
        if (item.currentStock != null && item.lowStockThreshold != null
            && item.currentStock <= item.lowStockThreshold) {
            wsService.emitEvent(auth.tenantId, WSEventName.LOW_STOCK_ALERT, {
                itemId,
                itemName: item.name,
                currentStock: item.currentStock,
                threshold: item.lowStockThreshold,
            }).catch(err => logger.warn('WS low-stock broadcast failed', { error: (err as Error).message }));

            // UNS canonical emit (T-INV-5: inventory.stock.low)
            emitUnsEvent({
                eventName: 'inventory.stock.low',
                category: 'inventory',
                subCategory: 'stock',
                priority: 'high',
                actorId: auth.sub,
                targetId: itemId,
                recipients: [
                    { user_id: auth.tenantId, role: 'admin' },
                ],
                payload: {
                    tenantId: auth.tenantId,
                    itemId,
                    itemName: item.name,
                    currentStock: item.currentStock,
                    threshold: item.lowStockThreshold,
                },
                sourceModule: 'my-backend/src/handlers/inventory.ts',
                dedupScopeFields: ['itemId'],
            }).catch(() => { /* non-fatal during migration window */ });
        }

        return response.success(item);
    })
);

/**
 * DELETE /inventory/{id}
 */
export const deleteItem = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    withIdempotency(async (event, _context, auth) => {
        const itemId = event.pathParameters?.id;
        if (!itemId) return response.badRequest('Missing item id');

        const deleted = await inventoryService.deleteItem(auth.tenantId, itemId, auth.sub);
        if (!deleted) return response.notFound('Inventory item');

        // Broadcast inventory change
        wsService.broadcastToBusiness(auth.tenantId, WSEventName.INVENTORY_UPDATED, {
            action: 'deleted', itemId,
        }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

        // UNS canonical emit (T-INV-6: inventory.item.deleted)
        emitUnsEvent({
            eventName: 'inventory.item.deleted',
            category: 'inventory',
            subCategory: 'item',
            priority: 'low',
            actorId: auth.sub,
            targetId: itemId,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                itemId,
                action: 'deleted',
            },
            sourceModule: 'my-backend/src/handlers/inventory.ts',
            dedupScopeFields: ['itemId'],
        }).catch(() => { /* non-fatal during migration window */ });

        return response.success({ message: 'Item deleted successfully' });
    })
);

/**
 * POST /inventory/{id}/adjust
 * BUG-004 FIX: Categorized stock adjustment for wastage, damage, theft, correction, expiry.
 * Atomically adjusts stock with reason tracking for audit and reporting.
 */
export const adjustStock = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    withIdempotency(async (event, _context, auth) => {
        try {
            const itemId = event.pathParameters?.id;
            if (!itemId) return response.badRequest('Missing item id');

            const parsed = parseBody(stockAdjustmentSchema, event);
            if (!parsed.success) return parsed.error;

            const { adjustmentQty, reason, notes } = parsed.data;

            const result = await inventoryService.adjustStock(
                auth.tenantId,
                itemId,
                adjustmentQty,
                reason,
                auth.sub,
                notes,
            );

            // Broadcast stock change
            wsService.broadcastToBusiness(auth.tenantId, WSEventName.INVENTORY_UPDATED, {
                action: 'stock_adjusted', itemId, reason, adjustmentQty,
            }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

            // UNS canonical emit (T-INV-7: inventory.stock.adjusted)
            emitUnsEvent({
                eventName: 'inventory.stock.adjusted',
                category: 'inventory',
                subCategory: 'stock',
                priority: 'normal',
                actorId: auth.sub,
                targetId: itemId,
                recipients: [
                    { user_id: auth.tenantId, role: 'admin' },
                ],
                payload: {
                    tenantId: auth.tenantId,
                    itemId,
                    itemName: result.productName,
                    reason,
                    adjustmentQty,
                    newStock: result.newStock,
                },
                sourceModule: 'my-backend/src/handlers/inventory.ts',
                dedupScopeFields: ['itemId', 'reason'],
            }).catch(() => { /* non-fatal during migration window */ });

            // Alert on low stock after write-down
            if (adjustmentQty < 0 && result.newStock <= 5) {
                wsService.emitEvent(auth.tenantId, WSEventName.LOW_STOCK_ALERT, {
                    itemId,
                    itemName: result.productName,
                    currentStock: result.newStock,
                    threshold: 5,
                    isOutOfStock: result.newStock <= 0,
                }).catch(err => logger.warn('WS low-stock broadcast failed', { error: (err as Error).message }));

                // UNS canonical emit (T-INV-9: inventory.stock.low after sale/adjustment)
                emitUnsEvent({
                    eventName: 'inventory.stock.low',
                    category: 'inventory',
                    subCategory: 'stock',
                    priority: 'high',
                    actorId: auth.sub,
                    targetId: itemId,
                    recipients: [
                        { user_id: auth.tenantId, role: 'admin' },
                    ],
                    payload: {
                        tenantId: auth.tenantId,
                        itemId,
                        itemName: result.productName,
                        currentStock: result.newStock,
                        threshold: 5,
                        isOutOfStock: result.newStock <= 0,
                    },
                    sourceModule: 'my-backend/src/handlers/inventory.ts',
                    dedupScopeFields: ['itemId'],
                }).catch(() => { /* non-fatal during migration window */ });
            }

            return response.success(result, 201);
        } catch (err: unknown) {
            if (err instanceof InventoryError) {
                return response.error(err.statusCode, 'INVENTORY_ERROR', err.message);
            }
            throw err;
        }
    })
);

/**
 * GET /reports/stock-adjustments?from=&to=&reason=&productId=&limit=
 * BUG-004 FIX: Stock adjustment / wastage report for reconciliation.
 */
export const getStockAdjustments = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const params = event.queryStringParameters || {};

        const result = await inventoryService.getStockAdjustments(auth.tenantId, {
            from: params.from,
            to: params.to,
            reason: params.reason,
            productId: params.productId,
            limit: params.limit ? parseInt(params.limit, 10) : undefined,
        });

        // Compute summary by reason
        const summaryMap = new Map<string, { count: number; totalQty: number }>();
        for (const adj of result.items) {
            const key = adj.reason;
            const existing = summaryMap.get(key) || { count: 0, totalQty: 0 };
            existing.count++;
            existing.totalQty += Number(adj.adjustmentQty) || 0;
            summaryMap.set(key, existing);
        }
        const summary = Array.from(summaryMap.entries()).map(([reason, data]) => ({
            reason, ...data,
        }));

        return response.success({
            adjustments: result.items,
            total: result.total,
            summary,
            period: { from: params.from || null, to: params.to || null },
        });
    },
);

/**
 * GET /inventory/serial-lookup?serial={serialNumber|imei}
 * SERIAL-001: Look up serial number or IMEI to find the original sale.
 * Useful for warranty checks, returns, and compliance auditing.
 */
export const serialLookup = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event, _context, auth) => {
        const serial = event.queryStringParameters?.serial;
        if (!serial || serial.trim() === '') {
            return response.badRequest('Missing "serial" query parameter');
        }

        const { getItem, Keys } = await import('../config/dynamodb.config');
        const record = await getItem<Record<string, any>>(
            Keys.tenantPK(auth.tenantId),
            Keys.serialTrackSK(serial.trim()),
        );

        if (!record || record.entityType !== 'SERIALTRACK') {
            return response.notFound('Serial/IMEI number');
        }

        return response.success({
            serialNumber: record.serialNumber || null,
            imei1: record.imei1 || null,
            imei2: record.imei2 || null,
            productId: record.productId,
            productName: record.productName,
            soldInvoiceId: record.invoiceId,
            invoiceNumber: record.invoiceNumber || null,
            customerName: record.customerName || null,
            customerPhone: record.customerPhone || null,
            soldAt: record.soldAt,
            warrantyExpiryDate: record.warrantyExpiryDate || null,
        });
    },
);
