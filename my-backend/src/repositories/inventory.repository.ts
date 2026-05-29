// ============================================================================
// Inventory Repository — DynamoDB Data Access Layer
// ============================================================================

import { BaseRepository, PaginationOpts, PaginatedResult } from './base.repository';
import { Keys, queryItems } from '../config/dynamodb.config';

export interface InventoryItem {
    id: string;
    tenantId: string;
    productType: string;
    name: string;
    displayName?: string;
    sku?: string;
    barcode?: string;
    category?: string;
    subcategory?: string;
    brand?: string;
    hsnCode?: string;
    unit: string;
    salePriceCents: number;
    purchasePriceCents?: number;
    mrpCents?: number;
    wholesalePriceCents?: number;
    cgstRateBp: number;
    sgstRateBp: number;
    igstRateBp: number;
    cessRateBp: number;
    currentStock: number;
    lowStockThreshold: number;
    reorderQty?: number;
    attributes: Record<string, unknown>;
    isActive: boolean;
    isService: boolean;
    isDeleted: boolean;
    version: number;
    createdAt: string;
    updatedAt: string;
}

export class InventoryRepository extends BaseRepository<InventoryItem> {
    constructor() {
        super('INVENTORY', 'PRODUCT#');
    }

    /**
     * Search inventory with filters.
     */
    async search(
        tenantId: string,
        opts: PaginationOpts & {
            category?: string;
            search?: string;
            lowStockOnly?: boolean;
            isActive?: boolean;
        },
    ): Promise<PaginatedResult<InventoryItem>> {
        return this.findAll(tenantId, opts, (item) => {
            if (opts.category && item.category !== opts.category) return false;
            if (opts.search) {
                const s = opts.search.toLowerCase();
                const matches = (item.name || '').toLowerCase().includes(s) ||
                    (item.sku || '').toLowerCase().includes(s) ||
                    item.barcode === opts.search;
                if (!matches) return false;
            }
            if (opts.lowStockOnly) {
                if (item.isService) return false;
                if ((item.currentStock || 0) > (item.lowStockThreshold || 0)) return false;
            }
            if (opts.isActive !== undefined && item.isActive !== opts.isActive) return false;
            return true;
        });
    }

    /**
     * Find by barcode within tenant scope using O(1) GSI3 lookup.
     */
    async findByBarcode(tenantId: string, barcode: string): Promise<InventoryItem | null> {
        // O(1) lookup via Barcode GSI3
        const result = await queryItems<InventoryItem>(
            Keys.barcodeGSI3PK(tenantId),
            Keys.barcodeGSI3SK(barcode),
            {
                indexName: 'GSI3',
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
                limit: 1,
            },
        );
        return result.items[0] || null;
    }

    /**
     * Get low stock items count.
     */
    async getLowStockCount(tenantId: string): Promise<number> {
        return this.count(tenantId, (item) =>
            item.isActive &&
            !item.isService &&
            (item.currentStock || 0) <= (item.lowStockThreshold || 0)
        );
    }
}
