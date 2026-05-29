// ============================================================================
// Lambda Handler — Low-Stock Alerts
// ============================================================================
// Endpoint:
//   GET /alerts/low-stock?limit=20
//
// Returns items where current quantity <= reorder level for the tenant.
// Uses GSI5 for efficient O(n) query instead of O(full_inventory) scan.
//
// Reduces RCU from ~200 (full inventory scan) to ~10 (GSI5 query).
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseQuery } from '../middleware/validation';
import * as response from '../utils/response';
import { z } from 'zod';
import { queryItems, Keys } from '../config/dynamodb.config';
import { logger } from '../utils/logger';

const querySchema = z.object({
    limit: z.coerce.number().int().min(1).max(100).default(20),
});

/**
 * GET /alerts/low-stock?limit=20
 *
 * Query GSI5 to find all low-stock products for the tenant.
 * Returns products sorted by quantity (lowest first).
 */
export const getLowStockAlerts = authorizedHandler([], async (event, _context, auth) => {
    const parsed = parseQuery(querySchema, event);
    if (!parsed.success) return parsed.error;

    const { limit } = parsed.data;
    const gsi5PK = `TENANT#${auth.tenantId}#LOWSTOCK`;

    try {
        logger.info('[LowStockAlerts] Querying low-stock items', {
            tenantId: auth.tenantId,
            limit,
        });

        // Query GSI5 for all low-stock items
        const result = await queryItems<Record<string, any>>(
            gsi5PK,
            undefined,
            {
                indexName: 'GSI5',
                limit,
                scanIndexForward: true, // Sort by quantity ascending (lowest first)
            }
        );

        // Map to response format
        const items = result.items.map(item => ({
            productId: item.SK?.replace('PRODUCT#', '') || item.id,
            productName: item.name || item.productName,
            currentQuantity: item.quantity || 0,
            reorderLevel: item.reorderLevel || 0,
            sku: item.sku,
            lastUpdated: item.lowStockUpdatedAt || item.updatedAt,
        }));

        logger.info('[LowStockAlerts] Query completed', {
            tenantId: auth.tenantId,
            itemsFound: items.length,
        });

        return response.success({
            items,
            count: items.length,
            limit,
        });
    } catch (error) {
        logger.error('[LowStockAlerts] Failed to query low-stock alerts', {
            tenantId: auth.tenantId,
            error: (error as Error).message,
        });
        return response.internalError('Failed to fetch low-stock alerts');
    }
});
