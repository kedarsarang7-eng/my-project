// ============================================================================
// Lambda Handler — Inventory CRUD
// ============================================================================
// Polymorphic inventory management for all 14 business types.
// Uses `authorizedHandler` wrapper for automatic tenant context security.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { InventoryService } from '../services/inventory.service';
import { UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

const inventoryService = new InventoryService();

/**
 * GET /inventory?category=&search=&page=1&limit=20
 */
export const getItems = authorizedHandler([], async (event, _context, auth) => {
    const params = event.queryStringParameters || {};
    const page = parseInt(params.page || '1', 10);
    const limit = Math.min(parseInt(params.limit || '20', 10), 100);

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
    async (event, _context, auth) => {
        const body = JSON.parse(event.body || '{}');

        if (!body.name || body.salePriceCents === undefined) {
            return response.badRequest('Missing required fields: name, salePriceCents');
        }

        const item = await inventoryService.createItem(auth.tenantId, body);

        logger.info('Inventory item created', {
            tenantId: auth.tenantId,
            itemId: item.id,
        });

        return response.success(item, 201);
    }
);

/**
 * PUT /inventory/{id}
 */
export const updateItem = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const itemId = event.pathParameters?.id;
        if (!itemId) return response.badRequest('Missing item id');

        const body = JSON.parse(event.body || '{}');

        const item = await inventoryService.updateItem(auth.tenantId, itemId, body);
        if (!item) return response.notFound('Inventory item');

        return response.success(item);
    }
);

/**
 * DELETE /inventory/{id}
 */
export const deleteItem = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _context, auth) => {
        const itemId = event.pathParameters?.id;
        if (!itemId) return response.badRequest('Missing item id');

        const deleted = await inventoryService.deleteItem(auth.tenantId, itemId);
        if (!deleted) return response.notFound('Inventory item');

        return response.success({ message: 'Item deleted successfully' });
    }
);
