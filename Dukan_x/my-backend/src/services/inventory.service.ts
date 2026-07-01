// ============================================================================
// Inventory Service — Polymorphic CRUD (PORTABLE)
// ============================================================================

import { getPool } from '../config/db.config';
import { InventoryItem, InventoryFilters } from '../types/inventory.types';
import { logger } from '../utils/logger';

export class InventoryService {

    /**
     * Get paginated inventory items with optional filters.
     */
    async getItems(filters: InventoryFilters): Promise<{ items: InventoryItem[]; total: number }> {
        const db = getPool();
        const conditions: string[] = ['tenant_id = $1', 'is_deleted = FALSE'];
        const params: unknown[] = [filters.tenantId];
        let paramIndex = 2;

        if (filters.category) {
            conditions.push(`category = $${paramIndex}`);
            params.push(filters.category);
            paramIndex++;
        }

        if (filters.search) {
            conditions.push(`(name ILIKE $${paramIndex} OR sku ILIKE $${paramIndex} OR barcode = $${paramIndex + 1})`);
            params.push(`%${filters.search}%`, filters.search);
            paramIndex += 2;
        }

        if (filters.lowStockOnly) {
            conditions.push('current_stock <= low_stock_threshold');
        }

        if (filters.isActive !== undefined) {
            conditions.push(`is_active = $${paramIndex}`);
            params.push(filters.isActive);
            paramIndex++;
        }

        if (filters.productType) {
            conditions.push(`product_type = $${paramIndex}`);
            params.push(filters.productType);
            paramIndex++;
        }

        const whereClause = conditions.join(' AND ');
        const offset = (filters.page - 1) * filters.limit;

        // Count total
        const countResult = await db.query(
            `SELECT COUNT(*)::int AS total FROM inventory WHERE ${whereClause}`,
            params
        );
        const total = countResult.rows[0].total;

        // Fetch page
        const dataResult = await db.query(
            `SELECT * FROM inventory
       WHERE ${whereClause}
       ORDER BY name ASC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
            [...params, filters.limit, offset]
        );

        return {
            items: dataResult.rows.map(this.mapRow),
            total,
        };
    }

    /**
     * Create a new inventory item.
     */
    async createItem(tenantId: string, data: Partial<InventoryItem>): Promise<InventoryItem> {
        const db = getPool();

        const result = await db.query(
            `INSERT INTO inventory (
        tenant_id, product_type, name, display_name, sku, barcode,
        category, subcategory, brand, hsn_code, unit,
        sale_price_cents, purchase_price_cents, mrp_cents, wholesale_price_cents,
        cgst_rate_bp, sgst_rate_bp, igst_rate_bp,
        current_stock, low_stock_threshold, reorder_qty,
        attributes, is_active
      ) VALUES (
        $1, $2, $3, $4, $5, $6,
        $7, $8, $9, $10, $11,
        $12, $13, $14, $15,
        $16, $17, $18,
        $19, $20, $21,
        $22, $23
      ) RETURNING *`,
            [
                tenantId,
                data.productType || 'general',
                data.name,
                data.displayName || null,
                data.sku || null,
                data.barcode || null,
                data.category || null,
                data.subcategory || null,
                data.brand || null,
                data.hsnCode || null,
                data.unit || 'pcs',
                data.salePriceCents || 0,
                data.purchasePriceCents || null,
                data.mrpCents || null,
                data.wholesalePriceCents || null,
                data.cgstRateBp || 0,
                data.sgstRateBp || 0,
                data.igstRateBp || 0,
                data.currentStock || 0,
                data.lowStockThreshold || 5,
                data.reorderQty || null,
                JSON.stringify(data.attributes || {}),
                data.isActive !== false,
            ]
        );

        return this.mapRow(result.rows[0]);
    }

    /**
     * Update an existing inventory item (soft-update).
     */
    async updateItem(
        tenantId: string,
        itemId: string,
        data: Partial<InventoryItem>,
    ): Promise<InventoryItem | null> {
        const db = getPool();

        const result = await db.query(
            `UPDATE inventory
       SET
         name = COALESCE($3, name),
         display_name = COALESCE($4, display_name),
         category = COALESCE($5, category),
         sale_price_cents = COALESCE($6, sale_price_cents),
         purchase_price_cents = COALESCE($7, purchase_price_cents),
         mrp_cents = COALESCE($8, mrp_cents),
         current_stock = COALESCE($9, current_stock),
         low_stock_threshold = COALESCE($10, low_stock_threshold),
         attributes = COALESCE($11::jsonb, attributes),
         is_active = COALESCE($12, is_active),
         updated_at = NOW()
       WHERE id = $1 AND tenant_id = $2 AND is_deleted = FALSE
       RETURNING *`,
            [
                itemId,
                tenantId,
                data.name || null,
                data.displayName || null,
                data.category || null,
                data.salePriceCents ?? null,
                data.purchasePriceCents ?? null,
                data.mrpCents ?? null,
                data.currentStock ?? null,
                data.lowStockThreshold ?? null,
                data.attributes ? JSON.stringify(data.attributes) : null,
                data.isActive ?? null,
            ]
        );

        return result.rows.length > 0 ? this.mapRow(result.rows[0]) : null;
    }

    /**
     * Soft-delete an inventory item.
     */
    async deleteItem(tenantId: string, itemId: string): Promise<boolean> {
        const db = getPool();

        const result = await db.query(
            `UPDATE inventory
       SET is_deleted = TRUE, updated_at = NOW()
       WHERE id = $1 AND tenant_id = $2 AND is_deleted = FALSE`,
            [itemId, tenantId]
        );

        return (result.rowCount ?? 0) > 0;
    }

    /**
     * Map a database row to the InventoryItem interface.
     */
    private mapRow(row: Record<string, unknown>): InventoryItem {
        return {
            id: row.id as string,
            tenantId: row.tenant_id as string,
            productType: row.product_type as InventoryItem['productType'],
            name: row.name as string,
            displayName: row.display_name as string | undefined,
            sku: row.sku as string | undefined,
            barcode: row.barcode as string | undefined,
            category: row.category as string | undefined,
            subcategory: row.subcategory as string | undefined,
            brand: row.brand as string | undefined,
            hsnCode: row.hsn_code as string | undefined,
            unit: row.unit as string,
            salePriceCents: Number(row.sale_price_cents),
            purchasePriceCents: row.purchase_price_cents ? Number(row.purchase_price_cents) : undefined,
            mrpCents: row.mrp_cents ? Number(row.mrp_cents) : undefined,
            wholesalePriceCents: row.wholesale_price_cents ? Number(row.wholesale_price_cents) : undefined,
            cgstRateBp: Number(row.cgst_rate_bp || 0),
            sgstRateBp: Number(row.sgst_rate_bp || 0),
            igstRateBp: Number(row.igst_rate_bp || 0),
            currentStock: Number(row.current_stock),
            lowStockThreshold: Number(row.low_stock_threshold),
            reorderQty: row.reorder_qty ? Number(row.reorder_qty) : undefined,
            attributes: (row.attributes as Record<string, unknown>) || {},
            isActive: row.is_active as boolean,
            createdAt: row.created_at as Date,
            updatedAt: row.updated_at as Date,
        };
    }
}
