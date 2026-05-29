import { v4 as uuidv4 } from 'uuid';
import {
    Keys,
    getItem, putItem, queryItems, queryAllItems, updateItem,
} from '../config/dynamodb.config';
import { InventoryItem, InventoryFilters } from '../types/inventory.types';
import { updateLowStockStatus } from '../utils/low-stock-alerts';
import { logger } from '../utils/logger';
import { AppError } from '../utils/errors';
import { logAudit } from '../middleware/audit';
import { recordRevision } from './revision-history.service';

export class InventoryService {

    /**
     * Get paginated inventory items with optional filters.
     * Uses server-side DynamoDB pagination to prevent loading all products into memory.
     */
    async getItems(filters: InventoryFilters): Promise<{ items: InventoryItem[]; total: number; lastKey?: Record<string, unknown> }> {
        // Build filter expression for DynamoDB-side filtering (reduces data transfer)
        const filterParts: string[] = ['(attribute_not_exists(isDeleted) OR isDeleted = :false)'];
        const exprValues: Record<string, unknown> = { ':false': false };
        const exprNames: Record<string, string> = {};

        if (filters.category) {
            filterParts.push('category = :cat');
            exprValues[':cat'] = filters.category;
        }
        if (filters.isActive !== undefined) {
            filterParts.push('isActive = :active');
            exprValues[':active'] = filters.isActive;
        }
        if (filters.productType) {
            filterParts.push('productType = :ptype');
            exprValues[':ptype'] = filters.productType;
        }
        if (filters.lowStockOnly) {
            filterParts.push('currentStock <= lowStockThreshold');
        }
        if (filters.search) {
            filterParts.push('contains(#n, :search)');
            exprValues[':search'] = filters.search.toLowerCase();
            exprNames['#n'] = 'name';
        }

        // Use server-side pagination: request `limit` items from DynamoDB
        const result = await queryItems<Record<string, any>>(
            Keys.tenantPK(filters.tenantId),
            'PRODUCT#',
            {
                filterExpression: filterParts.join(' AND '),
                expressionAttributeValues: exprValues,
                expressionAttributeNames: Object.keys(exprNames).length > 0 ? exprNames : undefined,
                limit: filters.limit * 2, // Request 2x limit to account for filter drops
                exclusiveStartKey: filters.cursor as Record<string, unknown> | undefined,
                scanIndexForward: true,
            },
        );

        // Client-side search refinement for barcode exact match (DynamoDB contains doesn't work for partial)
        let items = result.items;
        if (filters.search) {
            const s = filters.search.toLowerCase();
            items = items.filter(i =>
                (i.name || '').toLowerCase().includes(s) ||
                (i.sku || '').toLowerCase().includes(s) ||
                (i.barcode || '') === filters.search
            );
        }

        // Sort and paginate client-side (within the fetched page)
        items.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
        const paged = items.slice(0, filters.limit);

        return {
            items: paged.map(this.mapRow),
            total: paged.length,
            lastKey: result.lastKey,
        };
    }

    /**
     * Create a new inventory item.
     * Enforces barcode and SKU uniqueness within the tenant.
     */
    async createItem(tenantId: string, data: Partial<InventoryItem>, actor = 'system'): Promise<InventoryItem> {
        const itemId = uuidv4();
        const now = new Date().toISOString();

        // Enforce barcode uniqueness within tenant
        if (data.barcode) {
            const existing = await queryItems<Record<string, any>>(
                Keys.barcodeGSI3PK(tenantId), Keys.barcodeGSI3SK(data.barcode),
                {
                    indexName: 'GSI3', limit: 1,
                    filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                    expressionAttributeValues: { ':false': false },
                },
            );
            if (existing.items.length > 0) {
                throw new InventoryError(
                    `Barcode '${data.barcode}' is already assigned to product '${existing.items[0].name}'`,
                    409,
                );
            }
        }

        // Enforce SKU uniqueness within tenant
        if (data.sku) {
            const existing = await queryItems<Record<string, any>>(
                Keys.tenantPK(tenantId), Keys.skuGSI1SK(data.sku),
                {
                    indexName: 'GSI1', limit: 1,
                    filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                    expressionAttributeValues: { ':false': false },
                },
            );
            if (existing.items.length > 0) {
                throw new InventoryError(
                    `SKU '${data.sku}' is already assigned to product '${existing.items[0].name}'`,
                    409,
                );
            }
        }

        const item: Record<string, any> = {
            PK: Keys.tenantPK(tenantId),
            SK: Keys.productSK(itemId),
            entityType: 'PRODUCT',
            id: itemId,
            tenantId,
            productType: data.productType || 'general',
            name: data.name,
            displayName: data.displayName || null,
            sku: data.sku || null,
            barcode: data.barcode || null,
            category: data.category || null,
            subcategory: data.subcategory || null,
            brand: data.brand || null,
            hsnCode: data.hsnCode || null,
            unit: data.unit || 'pcs',
            salePriceCents: data.salePriceCents || 0,
            purchasePriceCents: data.purchasePriceCents || null,
            mrpCents: data.mrpCents || null,
            wholesalePriceCents: data.wholesalePriceCents || null,
            cgstRateBp: data.cgstRateBp || 0,
            sgstRateBp: data.sgstRateBp || 0,
            igstRateBp: data.igstRateBp || 0,
            currentStock: data.currentStock || 0,
            lowStockThreshold: data.lowStockThreshold || 5,
            reorderQty: data.reorderQty || null,
            attributes: data.attributes || {},
            isActive: data.isActive !== false,
            isArchived: false,
            isDeleted: false,
            isService: false,
            imageUrl: (data as any).imageUrl || null,
            description: (data as any).description || null,
            createdAt: now,
            updatedAt: now,
        };

        // GSI1 for SKU lookup
        if (data.sku) {
            item.GSI1PK = Keys.tenantPK(tenantId);
            item.GSI1SK = Keys.skuGSI1SK(data.sku);
        }

        // GSI3 for Barcode O(1) lookup
        if (data.barcode) {
            item.GSI3PK = Keys.barcodeGSI3PK(tenantId);
            item.GSI3SK = Keys.barcodeGSI3SK(data.barcode);
        }

        await putItem(item, 'attribute_not_exists(PK)');
        await recordRevision(
            tenantId,
            'inventory',
            itemId,
            'create',
            actor,
            null,
            {
                id: itemId,
                name: item.name,
                category: item.category,
                salePriceCents: item.salePriceCents,
                currentStock: item.currentStock,
            },
            { source: 'inventory.createItem' },
        );
        return this.mapRow(item);
    }

    /**
     * Update an existing inventory item.
     */
    async updateItem(
        tenantId: string,
        itemId: string,
        data: Partial<InventoryItem>,
        actor = 'system',
    ): Promise<InventoryItem | null> {
        const before = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), Keys.productSK(itemId));
        if (!before || before.isDeleted) return null;
        const now = new Date().toISOString();
        const updates: Record<string, any> = {};

        // C-4: Enforce barcode uniqueness on UPDATE
        if ((data as any).barcode !== undefined && (data as any).barcode) {
            const existing = await queryItems<Record<string, any>>(
                Keys.barcodeGSI3PK(tenantId), Keys.barcodeGSI3SK((data as any).barcode),
                {
                    indexName: 'GSI3', limit: 1,
                    filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                    expressionAttributeValues: { ':false': false },
                },
            );
            if (existing.items.length > 0 && existing.items[0].id !== itemId) {
                throw new InventoryError(
                    `Barcode '${(data as any).barcode}' is already assigned to product '${existing.items[0].name}'`,
                    409,
                );
            }
            updates.barcode = (data as any).barcode;
            updates.GSI3PK = Keys.barcodeGSI3PK(tenantId);
            updates.GSI3SK = Keys.barcodeGSI3SK((data as any).barcode);
        }

        // C-4: Enforce SKU uniqueness on UPDATE
        if (data.sku !== undefined && data.sku) {
            const existing = await queryItems<Record<string, any>>(
                Keys.tenantPK(tenantId), Keys.skuGSI1SK(data.sku),
                {
                    indexName: 'GSI1', limit: 1,
                    filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                    expressionAttributeValues: { ':false': false },
                },
            );
            if (existing.items.length > 0 && existing.items[0].id !== itemId) {
                throw new InventoryError(
                    `SKU '${data.sku}' is already assigned to product '${existing.items[0].name}'`,
                    409,
                );
            }
            updates.sku = data.sku;
            updates.GSI1PK = Keys.tenantPK(tenantId);
            updates.GSI1SK = Keys.skuGSI1SK(data.sku);
        }

        if (data.name !== undefined) updates.name = data.name;
        if (data.displayName !== undefined) updates.displayName = data.displayName;
        if (data.category !== undefined) updates.category = data.category;
        if (data.salePriceCents !== undefined) updates.salePriceCents = data.salePriceCents;
        if (data.purchasePriceCents !== undefined) updates.purchasePriceCents = data.purchasePriceCents;
        if (data.mrpCents !== undefined) updates.mrpCents = data.mrpCents;
        if (data.lowStockThreshold !== undefined) updates.lowStockThreshold = data.lowStockThreshold;
        if (data.attributes !== undefined) updates.attributes = data.attributes;
        if (data.isActive !== undefined) updates.isActive = data.isActive;
        if ((data as any).imageUrl !== undefined) updates.imageUrl = (data as any).imageUrl;
        if ((data as any).description !== undefined) updates.description = (data as any).description;

        // H-2: Stock override audit — track before/after if currentStock is being directly set
        let stockOverride = false;
        if (data.currentStock !== undefined) {
            updates.currentStock = data.currentStock;
            stockOverride = true;
        }

        updates.updatedAt = now;

        // Build dynamic update expression
        const setExpressions: string[] = [];
        const expressionValues: Record<string, any> = {};
        const expressionNames: Record<string, string> = {};
        let idx = 0;

        for (const [key, value] of Object.entries(updates)) {
            const attrName = `#a${idx}`;
            const attrVal = `:v${idx}`;
            expressionNames[attrName] = key;
            expressionValues[attrVal] = value;
            setExpressions.push(`${attrName} = ${attrVal}`);
            idx++;
        }

        expressionValues[':false'] = false;

        // HIGH FIX: Add optimistic locking with version check
        // Get expected version from input data, default to current version from 'before' or 0
        const expectedVersion = (data as any).expectedVersion ?? before.version ?? 0;

        // Include version in updates to increment it
        setExpressions.push('#version = if_not_exists(#version, :zero) + :one');
        expressionNames['#version'] = 'version';
        expressionValues[':zero'] = 0;
        expressionValues[':one'] = 1;
        expressionValues[':expectedVersion'] = expectedVersion;

        const result = await updateItem(
            Keys.tenantPK(tenantId),
            Keys.productSK(itemId),
            {
                updateExpression: `SET ${setExpressions.join(', ')}`,
                expressionAttributeValues: expressionValues,
                expressionAttributeNames: expressionNames,
                // HIGH FIX: Optimistic locking - only update if version matches
                conditionExpression: 'attribute_exists(PK) AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND (attribute_not_exists(#version) OR #version = :expectedVersion)',
            },
        );
        if (result) {
            await recordRevision(
                tenantId,
                'inventory',
                itemId,
                'update',
                actor,
                {
                    name: before.name,
                    category: before.category,
                    salePriceCents: before.salePriceCents,
                    currentStock: before.currentStock,
                    isActive: before.isActive,
                },
                {
                    name: (result as any).name,
                    category: (result as any).category,
                    salePriceCents: (result as any).salePriceCents,
                    currentStock: (result as any).currentStock,
                    isActive: (result as any).isActive,
                },
                { source: 'inventory.updateItem' },
            );
        }

        // H-2: Audit log for stock override
        if (stockOverride && result) {
            logAudit({
                action: 'STOCK_OVERRIDE',
                resource: 'inventory',
                resourceId: itemId,
                metadata: { newStock: data.currentStock, productName: (result as any).name },
            }).catch(() => { });
        }

        return result ? this.mapRow(result) : null;
    }

    /**
     * Soft-delete an inventory item.
     */
    async deleteItem(tenantId: string, itemId: string, actor = 'system'): Promise<boolean> {
        try {
            const before = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), Keys.productSK(itemId));
            const result = await updateItem(
                Keys.tenantPK(tenantId),
                Keys.productSK(itemId),
                {
                    updateExpression: 'SET isDeleted = :true, updatedAt = :now',
                    expressionAttributeValues: {
                        ':true': true,
                        ':now': new Date().toISOString(),
                        ':false': false,
                    },
                    conditionExpression: 'attribute_exists(PK) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                },
            );
            await recordRevision(
                tenantId,
                'inventory',
                itemId,
                'delete',
                actor,
                {
                    name: before?.name || (result as any)?.name || null,
                    isDeleted: false,
                },
                {
                    name: (result as any)?.name || before?.name || null,
                    isDeleted: true,
                },
                { source: 'inventory.deleteItem' },
            );
            // H-2: Audit log for deletion
            logAudit({
                action: 'INVENTORY_DELETED',
                resource: 'inventory',
                resourceId: itemId,
                metadata: { productName: (result as any)?.name },
            }).catch(() => { });
            return true;
        } catch (err: any) {
            if (err.name === 'ConditionalCheckFailedException') return false;
            throw err;
        }
    }

    /**
     * L-4: Archive a product (hide from active lists but preserve data).
     */
    async archiveItem(tenantId: string, itemId: string): Promise<boolean> {
        try {
            await updateItem(
                Keys.tenantPK(tenantId),
                Keys.productSK(itemId),
                {
                    updateExpression: 'SET isArchived = :true, isActive = :false, updatedAt = :now',
                    expressionAttributeValues: {
                        ':true': true,
                        ':false': false,
                        ':now': new Date().toISOString(),
                    },
                    conditionExpression: 'attribute_exists(PK) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                },
            );
            logAudit({
                action: 'INVENTORY_ARCHIVED',
                resource: 'inventory',
                resourceId: itemId,
            }).catch(() => { });
            return true;
        } catch (err: any) {
            if (err.name === 'ConditionalCheckFailedException') return false;
            throw err;
        }
    }

    /**
     * L-4: Restore an archived product.
     */
    async restoreItem(tenantId: string, itemId: string): Promise<boolean> {
        try {
            await updateItem(
                Keys.tenantPK(tenantId),
                Keys.productSK(itemId),
                {
                    updateExpression: 'SET isArchived = :false, isActive = :true, updatedAt = :now',
                    expressionAttributeValues: {
                        ':false': false,
                        ':true': true,
                        ':now': new Date().toISOString(),
                    },
                    conditionExpression: 'attribute_exists(PK) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                },
            );
            logAudit({
                action: 'INVENTORY_RESTORED',
                resource: 'inventory',
                resourceId: itemId,
            }).catch(() => { });
            return true;
        } catch (err: any) {
            if (err.name === 'ConditionalCheckFailedException') return false;
            throw err;
        }
    }


    /**
     * BUG-004 FIX: Adjust stock with categorized reason (wastage/damage/theft/correction/expiry).
     * Atomically applies adjustment with condition to prevent stock from going negative.
     * Creates an ADJUSTMENT audit entity for wastage reporting.
     */
    async adjustStock(
        tenantId: string,
        itemId: string,
        adjustmentQty: number,
        reason: 'wastage' | 'damage' | 'theft' | 'correction' | 'expiry',
        userId: string,
        notes?: string,
    ): Promise<{ id: string; productName: string; previousStock: number; newStock: number; adjustmentQty: number; reason: string }> {
        if (!Number.isFinite(adjustmentQty) || adjustmentQty === 0) {
            throw new InventoryError('Adjustment quantity must be a non-zero number', 400);
        }

        const pk = Keys.tenantPK(tenantId);
        const sk = Keys.productSK(itemId);

        // Fetch current product to get stock and name
        const product = await getItem<Record<string, any>>(pk, sk);
        if (!product || product.isDeleted) {
            throw new InventoryError(`Product '${itemId}' not found`, 404);
        }

        const previousStock = Number(product.currentStock || 0);
        const expectedNew = previousStock + adjustmentQty;

        // Prevent stock from going negative
        if (expectedNew < 0) {
            throw new InventoryError(
                `Cannot adjust stock for '${product.name}': current stock is ${previousStock}, ` +
                `adjustment of ${adjustmentQty} would result in negative stock (${expectedNew}).`,
                400,
            );
        }

        const now = new Date().toISOString();
        const adjustmentId = (await import('uuid')).v4();

        // Atomic update: apply adjustment with condition to prevent negative stock
        // For negative adjustments (write-downs): currentStock >= abs(adjustmentQty)
        const conditionExpr = adjustmentQty < 0
            ? 'attribute_exists(PK) AND currentStock >= :absQty'
            : 'attribute_exists(PK)';
        const conditionValues: Record<string, any> = {
            ':qty': adjustmentQty,
            ':now': now,
        };
        if (adjustmentQty < 0) {
            conditionValues[':absQty'] = Math.abs(adjustmentQty);
        }

        try {
            const result = await updateItem(pk, sk, {
                updateExpression: 'SET currentStock = currentStock + :qty, updatedAt = :now',
                conditionExpression: conditionExpr,
                expressionAttributeValues: conditionValues,
            });

            const newStock = Number((result as any)?.currentStock) || expectedNew;

            // Update GSI5 low-stock index for dashboard alerts
            const reorderLevel = Number(product.reorderLevel || 0);
            updateLowStockStatus(
                tenantId,
                itemId,
                newStock,
                reorderLevel,
                product.name
            ).catch(err => {
                logger.warn('Failed to update low-stock status', {
                    tenantId, itemId, error: (err as Error).message,
                });
            });

            // Store adjustment record for reporting
            await putItem({
                PK: pk,
                SK: `ADJUSTMENT#${adjustmentId}`,
                entityType: 'STOCK_ADJUSTMENT',
                id: adjustmentId,
                tenantId,
                productId: itemId,
                productName: product.name,
                adjustmentQty,
                previousStock,
                newStock,
                reason,
                notes: notes || null,
                createdBy: userId,
                createdAt: now,
            });
            await recordRevision(
                tenantId,
                'inventory',
                itemId,
                'update',
                userId,
                {
                    currentStock: previousStock,
                },
                {
                    currentStock: newStock,
                },
                {
                    source: 'inventory.adjustStock',
                    adjustmentId,
                    reason,
                    adjustmentQty,
                },
            );

            // Audit log
            logAudit({
                action: 'STOCK_ADJUSTED',
                resource: 'inventory',
                resourceId: itemId,
                metadata: {
                    adjustmentId,
                    productName: product.name,
                    adjustmentQty,
                    previousStock,
                    newStock,
                    reason,
                    notes,
                    userId,
                },
            }).catch(() => { });

            logger.info('Stock adjusted', {
                tenantId, productId: itemId, adjustmentQty,
                previousStock, newStock, reason,
            });

            return {
                id: adjustmentId,
                productName: product.name,
                previousStock,
                newStock,
                adjustmentQty,
                reason,
            };
        } catch (err: any) {
            if (err.name === 'ConditionalCheckFailedException') {
                throw new InventoryError(
                    `Stock adjustment failed for '${product.name}': ` +
                    `concurrent modification detected or insufficient stock. Please retry.`,
                    409,
                );
            }
            throw err;
        }
    }

    /**
     * Query stock adjustment history for reporting.
     * Supports filtering by date range and reason.
     */
    async getStockAdjustments(
        tenantId: string,
        filters: { from?: string; to?: string; reason?: string; productId?: string; limit?: number },
    ): Promise<{ items: Record<string, any>[]; total: number }> {
        const pk = Keys.tenantPK(tenantId);

        const filterParts: string[] = [];
        const exprValues: Record<string, any> = {};

        if (filters.from) {
            filterParts.push('createdAt >= :from');
            exprValues[':from'] = new Date(filters.from).toISOString();
        }
        if (filters.to) {
            filterParts.push('createdAt < :to');
            exprValues[':to'] = new Date(new Date(filters.to).getTime() + 86400000).toISOString();
        }
        if (filters.reason) {
            filterParts.push('reason = :reason');
            exprValues[':reason'] = filters.reason;
        }
        if (filters.productId) {
            filterParts.push('productId = :pid');
            exprValues[':pid'] = filters.productId;
        }

        const result = await queryAllItems<Record<string, any>>(pk, 'ADJUSTMENT#', {
            filterExpression: filterParts.length > 0 ? filterParts.join(' AND ') : undefined,
            expressionAttributeValues: Object.keys(exprValues).length > 0 ? exprValues : undefined,
            maxPages: 5,
        });

        // Sort by date descending
        result.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));

        const limited = filters.limit ? result.slice(0, filters.limit) : result;

        return {
            items: limited.map(adj => ({
                id: adj.id,
                productId: adj.productId,
                productName: adj.productName,
                adjustmentQty: adj.adjustmentQty,
                previousStock: adj.previousStock,
                newStock: adj.newStock,
                reason: adj.reason,
                notes: adj.notes,
                createdBy: adj.createdBy,
                createdAt: adj.createdAt,
            })),
            total: result.length,
        };
    }

    /**
     * Map a DynamoDB item to the InventoryItem interface.
     */
    private mapRow(row: Record<string, unknown>): InventoryItem {
        return {
            id: row.id as string,
            tenantId: row.tenantId as string || row.tenant_id as string,
            productType: (row.productType || row.product_type || 'general') as InventoryItem['productType'],
            name: row.name as string,
            displayName: (row.displayName || row.display_name) as string | undefined,
            sku: row.sku as string | undefined,
            barcode: row.barcode as string | undefined,
            category: row.category as string | undefined,
            subcategory: row.subcategory as string | undefined,
            brand: row.brand as string | undefined,
            hsnCode: (row.hsnCode || row.hsn_code) as string | undefined,
            unit: (row.unit || 'pcs') as string,
            salePriceCents: Number(row.salePriceCents || row.sale_price_cents || 0),
            purchasePriceCents: row.purchasePriceCents || row.purchase_price_cents ? Number(row.purchasePriceCents || row.purchase_price_cents) : undefined,
            mrpCents: row.mrpCents || row.mrp_cents ? Number(row.mrpCents || row.mrp_cents) : undefined,
            wholesalePriceCents: row.wholesalePriceCents || row.wholesale_price_cents ? Number(row.wholesalePriceCents || row.wholesale_price_cents) : undefined,
            cgstRateBp: Number(row.cgstRateBp || row.cgst_rate_bp || 0),
            sgstRateBp: Number(row.sgstRateBp || row.sgst_rate_bp || 0),
            igstRateBp: Number(row.igstRateBp || row.igst_rate_bp || 0),
            currentStock: Number(row.currentStock || row.current_stock || 0),
            lowStockThreshold: Number(row.lowStockThreshold || row.low_stock_threshold || 5),
            reorderQty: row.reorderQty || row.reorder_qty ? Number(row.reorderQty || row.reorder_qty) : undefined,
            attributes: (row.attributes as Record<string, unknown>) || {},
            isActive: (row.isActive ?? row.is_active ?? true) as boolean,
            imageUrl: (row.imageUrl as string) || undefined,
            description: (row.description as string) || undefined,
            isArchived: (row.isArchived as boolean) || false,
            createdAt: row.createdAt as Date || row.created_at as Date,
            updatedAt: row.updatedAt as Date || row.updated_at as Date,
        } as InventoryItem;
    }
}

// ---- Errors ----

// M-10: InventoryError now extends AppError for standardized error handling
export class InventoryError extends AppError {
    constructor(message: string, statusCode = 400) {
        super(message, statusCode, 'INVENTORY_ERROR');
        this.name = 'InventoryError';
    }
}
