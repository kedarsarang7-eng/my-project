// ============================================================================
// Lambda Handlers — Physical Stock Count / Reconciliation
// ============================================================================
// Workflow:
//   1. POST /stock-count         — Start a new stock count session
//   2. POST /stock-count/{id}/items — Submit counted quantities (batch)
//   3. POST /stock-count/{id}/finalize — Compare system vs counted, generate variance
//   4. GET  /stock-count/{id}    — Get stock count status and variance report
//   5. GET  /stock-count         — List all stock counts
//
// DynamoDB Entities:
//   PK: TENANT#{tenantId}, SK: STOCKCOUNT#{id}    — Count session header
//   PK: STOCKCOUNT#{id},  SK: COUNTITEM#{productId} — Individual count entries
//
// Access: Owner, Admin, Manager
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import {
    Keys,
    getItem, putItem, queryItems, updateItem, batchWrite, batchGetItems,
} from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { logAudit } from '../middleware/audit';
import { z } from 'zod';
import { parseBody } from '../middleware/validation';
import { recordRevision } from '../services/revision-history.service';

// ---- Schemas ----

const startCountSchema = z.object({
    name: z.string().max(200).optional(),
    notes: z.string().max(1000).optional(),
    category: z.string().optional(), // Filter count to specific category
});

const submitItemsSchema = z.object({
    items: z.array(z.object({
        productId: z.string().min(1),
        countedQuantity: z.number().min(0),
        notes: z.string().max(500).optional(),
        location: z.string().max(200).optional(), // Shelf/aisle location
    })).min(1).max(500),
});

// ---- Handlers ----

/**
 * POST /stock-count — Start a new stock count session
 */
export const startCount = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const parsed = parseBody(startCountSchema, event);
        if (!parsed.success) return parsed.error;

        const countId = uuidv4();
        const now = new Date().toISOString();

        const countRecord = {
            PK: Keys.tenantPK(auth.tenantId),
            SK: `STOCKCOUNT#${countId}`,
            entityType: 'STOCK_COUNT',
            id: countId,
            tenantId: auth.tenantId,
            name: parsed.data.name || `Stock Count ${now.split('T')[0]}`,
            status: 'in_progress',
            category: parsed.data.category || null,
            notes: parsed.data.notes || null,
            itemsSubmitted: 0,
            startedBy: auth.sub,
            createdAt: now,
            updatedAt: now,
        };

        await putItem(countRecord);
        await recordRevision(
            auth.tenantId,
            'stock_counts',
            countId,
            'create',
            auth.sub,
            null,
            {
                status: 'in_progress',
                category: parsed.data.category || null,
                name: countRecord.name,
            },
            { source: 'stock-count.startCount' },
        );

        logAudit({
            action: 'STOCK_COUNT_STARTED',
            resource: 'stock_count',
            resourceId: countId,
        }).catch(() => {});

        logger.info('Stock count started', { tenantId: auth.tenantId, countId });
        return response.success(countRecord, 201);
    },
);

/**
 * POST /stock-count/{id}/items — Submit counted quantities
 */
export const submitItems = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const countId = event.pathParameters?.id;
        if (!countId) return response.badRequest('Missing stock count ID');

        const parsed = parseBody(submitItemsSchema, event);
        if (!parsed.success) return parsed.error;
        const duplicateProductIds = Array.from(
            new Set(
                parsed.data.items
                    .map((item) => item.productId)
                    .filter((productId, index, all) => all.indexOf(productId) !== index),
            ),
        );
        if (duplicateProductIds.length > 0) {
            return response.error(
                400,
                'DUPLICATE_PRODUCT',
                `Duplicate productId in payload: ${duplicateProductIds.join(', ')}`,
            );
        }

        // Verify stock count exists and is in progress
        const count = await getItem<Record<string, any>>(
            Keys.tenantPK(auth.tenantId),
            `STOCKCOUNT#${countId}`,
        );

        if (!count) return response.notFound('Stock count not found');
        if (count.status !== 'in_progress') {
            return response.error(409, 'INVALID_STATUS', `Stock count is '${count.status}', cannot submit items`);
        }

        const now = new Date().toISOString();
        const existingCountItems = await queryItems<Record<string, any>>(
            `STOCKCOUNT#${countId}`,
            'COUNTITEM#',
        );
        const existingProductIds = new Set(
            existingCountItems.items.map((item) => String(item.productId || '')),
        );
        const newlyAddedUniqueCount = parsed.data.items.filter(
            (item) => !existingProductIds.has(item.productId),
        ).length;

        // Write count items via batchWrite
        const putOps = parsed.data.items.map(item => ({
            type: 'put' as const,
            item: {
                PK: `STOCKCOUNT#${countId}`,
                SK: `COUNTITEM#${item.productId}`,
                entityType: 'COUNT_ITEM',
                tenantId: auth.tenantId,
                stockCountId: countId,
                productId: item.productId,
                countedQuantity: item.countedQuantity,
                notes: item.notes || null,
                location: item.location || null,
                countedBy: auth.sub,
                countedAt: now,
            },
        }));

        await batchWrite(putOps);

        // Update items count on the header
        await updateItem(
            Keys.tenantPK(auth.tenantId),
            `STOCKCOUNT#${countId}`,
            {
                updateExpression: 'SET itemsSubmitted = itemsSubmitted + :count, updatedAt = :now',
                expressionAttributeValues: { ':count': newlyAddedUniqueCount, ':now': now },
            },
        );
        await recordRevision(
            auth.tenantId,
            'stock_counts',
            countId,
            'update',
            auth.sub,
            {
                itemsSubmitted: Number(count.itemsSubmitted || 0),
            },
            {
                itemsSubmitted: Number(count.itemsSubmitted || 0) + newlyAddedUniqueCount,
            },
            {
                source: 'stock-count.submitItems',
                submittedItems: parsed.data.items.length,
                newlyAddedUniqueItems: newlyAddedUniqueCount,
            },
        );

        logger.info('Stock count items submitted', {
            tenantId: auth.tenantId, countId,
            itemCount: parsed.data.items.length,
        });

        return response.success({
            countId,
            itemsSubmitted: parsed.data.items.length,
            newlyAddedUniqueItems: newlyAddedUniqueCount,
        });
    },
);

/**
 * POST /stock-count/{id}/finalize — Compare system vs counted, generate variance
 */
export const finalize = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const countId = event.pathParameters?.id;
        if (!countId) return response.badRequest('Missing stock count ID');

        // Verify stock count exists and is in progress
        const count = await getItem<Record<string, any>>(
            Keys.tenantPK(auth.tenantId),
            `STOCKCOUNT#${countId}`,
        );

        if (!count) return response.notFound('Stock count not found');
        if (count.status !== 'in_progress') {
            return response.error(409, 'INVALID_STATUS', `Stock count is '${count.status}'`);
        }

        // Fetch all count items
        const countItems = await queryItems<Record<string, any>>(
            `STOCKCOUNT#${countId}`, 'COUNTITEM#',
        );

        if (countItems.items.length === 0) {
            return response.error(400, 'NO_ITEMS', 'No items have been submitted for this stock count');
        }

        // Batch fetch current system stock for all counted products
        const productIds = countItems.items.map(ci => ci.productId);
        const productKeys = productIds.map(id => ({
            PK: Keys.tenantPK(auth.tenantId),
            SK: Keys.productSK(id),
        }));

        const products = await batchGetItems<Record<string, any>>(productKeys);
        const productMap = new Map(products.map(p => [p.id, p]));

        // Calculate variance for each item
        let totalVarianceItems = 0;
        let totalSurplusItems = 0;
        let totalShortageItems = 0;
        let totalVarianceValueCents = 0;

        const varianceReport = countItems.items.map(ci => {
            const product = productMap.get(ci.productId);
            const systemQty = product ? Number(product.currentStock) || 0 : 0;
            const countedQty = Number(ci.countedQuantity) || 0;
            const varianceQty = countedQty - systemQty;
            const variancePct = systemQty > 0 ? ((varianceQty / systemQty) * 100) : (countedQty > 0 ? 100 : 0);
            const unitCostCents = product ? (Number(product.purchasePriceCents) || 0) : 0;
            const varianceValueCents = Math.round(varianceQty * unitCostCents);

            if (varianceQty > 0) totalSurplusItems++;
            else if (varianceQty < 0) totalShortageItems++;
            if (varianceQty !== 0) totalVarianceItems++;
            totalVarianceValueCents += varianceValueCents;

            // Auto-suggest reason based on variance pattern
            let suggestedReason = 'unknown';
            if (varianceQty < 0 && variancePct < -10) suggestedReason = 'theft_or_damage';
            else if (varianceQty < 0 && variancePct >= -10) suggestedReason = 'counting_error';
            else if (varianceQty > 0) suggestedReason = 'unrecorded_receipt';

            return {
                productId: ci.productId,
                productName: product?.name || 'Unknown',
                unit: product?.unit || 'pcs',
                systemQty,
                countedQty,
                varianceQty,
                variancePercent: Math.round(variancePct * 100) / 100,
                varianceValueCents,
                suggestedReason,
                location: ci.location,
                notes: ci.notes,
            };
        });

        // Sort by absolute variance descending (biggest discrepancies first)
        varianceReport.sort((a, b) => Math.abs(b.varianceQty) - Math.abs(a.varianceQty));

        const now = new Date().toISOString();

        // Update stock count status to finalized
        await updateItem(
            Keys.tenantPK(auth.tenantId),
            `STOCKCOUNT#${countId}`,
            {
                updateExpression: 'SET #s = :finalized, updatedAt = :now, finalizedAt = :now, ' +
                    'finalizedBy = :userId, totalVarianceItems = :varItems, ' +
                    'totalSurplusItems = :surplus, totalShortageItems = :shortage, ' +
                    'totalVarianceValueCents = :varValue',
                expressionAttributeNames: { '#s': 'status' },
                expressionAttributeValues: {
                    ':finalized': 'finalized',
                    ':now': now,
                    ':userId': auth.sub,
                    ':varItems': totalVarianceItems,
                    ':surplus': totalSurplusItems,
                    ':shortage': totalShortageItems,
                    ':varValue': totalVarianceValueCents,
                },
            },
        );
        await recordRevision(
            auth.tenantId,
            'stock_counts',
            countId,
            'status_change',
            auth.sub,
            {
                status: count.status || 'in_progress',
            },
            {
                status: 'finalized',
                totalVarianceItems,
                totalVarianceValueCents,
            },
            { source: 'stock-count.finalize' },
        );

        logAudit({
            action: 'STOCK_COUNT_FINALIZED',
            resource: 'stock_count',
            resourceId: countId,
            metadata: { totalVarianceItems, totalVarianceValueCents },
        }).catch(() => {});

        logger.info('Stock count finalized', {
            tenantId: auth.tenantId, countId,
            totalVarianceItems, totalVarianceValueCents,
        });

        return response.success({
            countId,
            status: 'finalized',
            finalizedAt: now,
            summary: {
                totalItemsCounted: countItems.items.length,
                totalVarianceItems,
                totalSurplusItems,
                totalShortageItems,
                totalVarianceValueCents,
                variancePercent: countItems.items.length > 0
                    ? Math.round((totalVarianceItems / countItems.items.length) * 10000) / 100
                    : 0,
            },
            variance: varianceReport,
        });
    },
);

/**
 * GET /stock-count/{id} — Get stock count details
 */
export const getCount = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const countId = event.pathParameters?.id;
        if (!countId) return response.badRequest('Missing stock count ID');

        const count = await getItem<Record<string, any>>(
            Keys.tenantPK(auth.tenantId),
            `STOCKCOUNT#${countId}`,
        );

        if (!count) return response.notFound('Stock count not found');

        // Fetch count items
        const countItems = await queryItems<Record<string, any>>(
            `STOCKCOUNT#${countId}`, 'COUNTITEM#',
        );

        return response.success({
            ...count,
            items: countItems.items,
        });
    },
);

/**
 * GET /stock-count — List all stock counts
 */
export const listCounts = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const limit = Math.min(
            parseInt(event.queryStringParameters?.limit || '20', 10) || 20,
            100,
        );

        const result = await queryItems<Record<string, any>>(
            Keys.tenantPK(auth.tenantId),
            'STOCKCOUNT#',
            { limit },
        );

        const counts = result.items
            .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));

        return response.success({ counts, total: counts.length });
    },
);
