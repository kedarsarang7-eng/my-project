// ============================================================================
// Lambda Handler — Products (Alias for Inventory with product-centric view)
// ============================================================================
// Endpoints:
//   GET /products?category=&search=&page=1&limit=20  — List products
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { InventoryService } from '../services/inventory.service';
import * as response from '../utils/response';

const inventoryService = new InventoryService();

/**
 * GET /products?category=&search=&page=1&limit=20
 * Product-centric view of inventory (active, non-deleted items).
 */
export const listProducts = authorizedHandler([], async (event, _context, auth) => {
    const params = event.queryStringParameters || {};
    const page = parseInt(params.page || '1', 10);
    const limit = Math.min(parseInt(params.limit || '20', 10), 100);

    const result = await inventoryService.getItems({
        tenantId: auth.tenantId,
        category: params.category,
        search: params.search,
        isActive: true,
        page,
        limit,
    });

    return response.paginated(result.items, result.total, page, limit);
});
