// ============================================================================
// ACADEMIC COACHING — INVENTORY & ASSETS MODULE
// ============================================================================
// Stock items, vendors, purchase orders, stock movements
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole, BusinessType } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
  Keys,
  putItem,
  getItem,
  updateItem as ddbUpdateItem,
  deleteItem,
  queryAllItems,
} from '../config/dynamodb.config';

const AC_INVENTORY_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_MATERIAL_MANAGEMENT,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

// ============================================================================
// ITEMS
// ============================================================================

/**
 * GET /ac/inventory/items
 * List inventory items
 */
export const listItems = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let items = await queryAllItems(pk, 'AC_INVENTORY_ITEM#');

    if (p.category) items = items.filter((i: any) => i.category === p.category);
    if (p.lowStock === 'true') items = items.filter((i: any) => (i.currentStock || 0) <= (i.minStock || 0));
    if (p.search) {
      const s = p.search.toLowerCase();
      items = items.filter((i: any) => 
        (i.name || '').toLowerCase().includes(s) || 
        (i.sku || '').toLowerCase().includes(s)
      );
    }

    return response.success(items);
  },
  AC_INVENTORY_OPTS,
);

/**
 * POST /ac/inventory/items
 * Create inventory item
 */
export const createItem = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { name, description, sku, category, unit, minStock, currentStock, location } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const id = uid();
    const ts = now();

    const item = {
      PK: pk,
      SK: `AC_INVENTORY_ITEM#${id}`,
      GSI1PK: sku ? `AC_ITEM_SKU#${auth.tenantId}#${sku}` : null,
      GSI1SK: ts,
      id,
      name,
      description,
      sku,
      category,
      unit,
      minStock: minStock || 0,
      currentStock: currentStock || 0,
      location,
      isActive: true,
      createdAt: ts,
      updatedAt: ts,
    };

    if (!item.GSI1PK) delete (item as any).GSI1PK;

    await putItem(item);
    return response.success(item, 201);
  },
  AC_INVENTORY_OPTS,
);

/**
 * PUT /ac/inventory/items/{id}
 * Update item
 */
export const updateItem = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Item ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const pk = Keys.tenantPK(auth.tenantId);

    const ts = now();
    await ddbUpdateItem(pk, `AC_INVENTORY_ITEM#${id}`, {
      updateExpression: 'SET #updates = :updates, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#updates': 'updates', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':updates': body, ':updatedAt': ts },
    });

    return response.success({ id, ...body, updatedAt: ts });
  },
  AC_INVENTORY_OPTS,
);

// ============================================================================
// STOCK MOVEMENTS
// ============================================================================

/**
 * POST /ac/inventory/stock/adjust
 * Adjust stock level
 */
export const adjustStock = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { itemId, quantity, type, reason, reference } = body;

    const pk = Keys.tenantPK(auth.tenantId);

    // Get item
    const item = await getItem<any>(pk, `AC_INVENTORY_ITEM#${itemId}`);
    if (!item) return response.notFound('Item not found');

    const id = uid();
    const ts = now();

    // Record movement
    const movement = {
      PK: pk,
      SK: `AC_STOCK_MOVEMENT#${ts}#${id}`,
      GSI1PK: `AC_MOVEMENT_BY_ITEM#${auth.tenantId}#${itemId}`,
      GSI1SK: ts,
      id,
      itemId,
      quantity,
      type, // 'in', 'out', 'adjustment'
      reason,
      reference,
      previousStock: item.currentStock,
      newStock: (item.currentStock || 0) + quantity,
      createdAt: ts,
      createdBy: auth.sub,
    };

    await putItem(movement);

    // Update item stock
    await ddbUpdateItem(pk, `AC_INVENTORY_ITEM#${itemId}`, {
      updateExpression: 'SET #currentStock = if_not_exists(#currentStock, :zero) + :quantity, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#currentStock': 'currentStock', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':quantity': quantity, ':zero': 0, ':updatedAt': ts },
    });

    return response.success(movement, 201);
  },
  AC_INVENTORY_OPTS,
);

/**
 * GET /ac/inventory/stock/movements
 * List stock movements
 */
export const listMovements = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let movements = await queryAllItems(pk, 'AC_STOCK_MOVEMENT#');

    if (p.itemId) movements = movements.filter((m: any) => m.itemId === p.itemId);
    if (p.type) movements = movements.filter((m: any) => m.type === p.type);
    if (p.fromDate && p.toDate) {
      movements = movements.filter((m: any) => m.createdAt >= (p.fromDate || '') && m.createdAt <= (p.toDate || ''));
    }

    // Sort by date desc
    movements.sort((a: any, b: any) => (b.createdAt || '').localeCompare(a.createdAt || ''));

    return response.success(movements);
  },
  AC_INVENTORY_OPTS,
);

// ============================================================================
// VENDORS
// ============================================================================

/**
 * GET /ac/inventory/vendors
 * List vendors
 */
export const listVendors = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let vendors = await queryAllItems(pk, 'AC_VENDOR#');

    if (p.category) vendors = vendors.filter((v: any) => v.category === p.category);
    if (p.isActive) vendors = vendors.filter((v: any) => v.isActive === (p.isActive === 'true'));

    return response.success(vendors);
  },
  AC_INVENTORY_OPTS,
);

/**
 * POST /ac/inventory/vendors
 * Create vendor
 */
export const createVendor = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { name, contactPerson, phone, email, address, category } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const id = uid();
    const ts = now();

    const vendor = {
      PK: pk,
      SK: `AC_VENDOR#${id}`,
      id,
      name,
      contactPerson,
      phone,
      email,
      address,
      category,
      isActive: true,
      createdAt: ts,
      updatedAt: ts,
    };

    await putItem(vendor);
    return response.success(vendor, 201);
  },
  AC_INVENTORY_OPTS,
);

/**
 * PUT /ac/inventory/vendors/{id}
 * Update vendor
 */
export const updateVendor = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Vendor ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const pk = Keys.tenantPK(auth.tenantId);

    const ts = now();
    await ddbUpdateItem(pk, `AC_VENDOR#${id}`, {
      updateExpression: 'SET #updates = :updates, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#updates': 'updates', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':updates': body, ':updatedAt': ts },
    });

    return response.success({ id, ...body, updatedAt: ts });
  },
  AC_INVENTORY_OPTS,
);

// ============================================================================
// PURCHASE ORDERS
// ============================================================================

/**
 * GET /ac/inventory/purchase-orders
 * List purchase orders
 */
export const listPurchaseOrders = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let orders = await queryAllItems(pk, 'AC_PURCHASE_ORDER#');

    if (p.vendorId) orders = orders.filter((o: any) => o.vendorId === p.vendorId);
    if (p.status) orders = orders.filter((o: any) => o.status === p.status);

    // Sort by date desc
    orders.sort((a: any, b: any) => (b.createdAt || '').localeCompare(a.createdAt || ''));

    return response.success(orders);
  },
  AC_INVENTORY_OPTS,
);

/**
 * POST /ac/inventory/purchase-orders
 * Create purchase order
 */
export const createPurchaseOrder = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { vendorId, items, totalAmountPaisa, expectedDeliveryDate, notes } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const id = uid();
    const ts = now();

    const poNumber = `PO-${auth.tenantId.substring(0, 6)}-${Date.now().toString(36).toUpperCase().substring(0, 8)}`;

    const order = {
      PK: pk,
      SK: `AC_PURCHASE_ORDER#${id}`,
      id,
      poNumber,
      vendorId,
      items: items || [],
      totalAmountPaisa: totalAmountPaisa || 0,
      expectedDeliveryDate,
      notes,
      status: 'draft',
      createdAt: ts,
      updatedAt: ts,
      createdBy: auth.sub,
    };

    await putItem(order);
    return response.success(order, 201);
  },
  AC_INVENTORY_OPTS,
);

/**
 * POST /ac/inventory/purchase-orders/{id}/status
 * Update PO status
 */
export const updatePOStatus = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('PO ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { status } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const order = await getItem<any>(pk, `AC_PURCHASE_ORDER#${id}`);
    if (!order) return response.notFound('Purchase order not found');

    const ts = now();

    await ddbUpdateItem(pk, `AC_PURCHASE_ORDER#${id}`, {
      updateExpression: 'SET #status = :status, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#status': 'status', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':status': status, ':updatedAt': ts },
    });

    // If received, update stock
    if (status === 'received') {
      for (const item of (order.items || [])) {
        // Create stock movement for received items
        const movementId = uid();
        const movement = {
          PK: pk,
          SK: `AC_STOCK_MOVEMENT#${ts}#${movementId}`,
          GSI1PK: `AC_MOVEMENT_BY_ITEM#${auth.tenantId}#${item.itemId}`,
          GSI1SK: ts,
          id: movementId,
          itemId: item.itemId,
          quantity: item.quantity,
          type: 'in',
          reason: `Purchase Order ${order.poNumber}`,
          reference: id,
          createdAt: ts,
          createdBy: auth.sub,
        };
        await putItem(movement);
        
        // Update item stock
        await ddbUpdateItem(pk, `AC_INVENTORY_ITEM#${item.itemId}`, {
          updateExpression: 'SET #currentStock = if_not_exists(#currentStock, :zero) + :quantity, #updatedAt = :updatedAt',
          expressionAttributeNames: { '#currentStock': 'currentStock', '#updatedAt': 'updatedAt' },
          expressionAttributeValues: { ':quantity': item.quantity, ':zero': 0, ':updatedAt': ts },
        });
      }
    }

    return response.success({ id, status, updatedAt: ts });
  },
  AC_INVENTORY_OPTS,
);

/**
 * GET /ac/inventory/dashboard
 * Inventory dashboard
 */
export const getInventoryDashboard = authorizedHandler(
  [],
  async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const [items, movements, vendors, orders] = await Promise.all([
      queryAllItems(pk, 'AC_INVENTORY_ITEM#'),
      queryAllItems(pk, 'AC_STOCK_MOVEMENT#'),
      queryAllItems(pk, 'AC_VENDOR#'),
      queryAllItems(pk, 'AC_PURCHASE_ORDER#'),
    ]);

    const lowStockItems = items.filter((i: any) => (i.currentStock || 0) <= (i.minStock || 0));

    const stats = {
      totalItems: items.length,
      activeItems: items.filter((i: any) => i.isActive).length,
      lowStockItems: lowStockItems.length,
      totalStockValue: items.reduce((sum: number, i: any) => sum + ((i.currentStock || 0) * (i.unitCost || 0)), 0),
      totalMovements: movements.length,
      totalVendors: vendors.length,
      activeVendors: vendors.filter((v: any) => v.isActive).length,
      totalPOs: orders.length,
      pendingPOs: orders.filter((o: any) => o.status === 'pending').length,
    };

    return response.success({ stats, lowStockItems });
  },
  AC_INVENTORY_OPTS,
);
