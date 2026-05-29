// ============================================================================
// Stock Service — Barcode Lookup, Image Analysis, Manual Add, Replenishment (DynamoDB)
// ============================================================================
// AUDIT FIXES APPLIED:
//   H-1: addStock now supports replenishing existing products (quantity increment)
//   H-5: OpenFoodFacts fetch has 2s AbortSignal timeout
//   M-10: StockError extends AppError
//   L-10: Barcode debounce/rate-limit per session (in-memory)
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import { Keys, getItem, putItem, queryItems, updateItem } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { AppError } from '../utils/errors';
import { logAudit } from '../middleware/audit';
import { recordRevision } from './revision-history.service';
import { config } from '../config/environment';

export interface BarcodeLookupResult { found: boolean; source: 'local' | 'openfoodfacts' | null; data: Record<string, unknown> | null; }
export interface ImageAnalysisResult { name: string | null; category: string | null; brand: string | null; confidence: number; }

// L-10: Simple in-memory debounce cache for barcode lookups (per Lambda instance)
const barcodeLookupCache = new Map<string, { result: BarcodeLookupResult; expiresAt: number }>();
const DEBOUNCE_MS = 500; // 500ms debounce window

export async function lookupBarcode(tenantId: string, barcode: string): Promise<BarcodeLookupResult> {
    // L-10: Debounce — return cached result if same barcode requested within 500ms
    const cacheKey = `${tenantId}:${barcode}`;
    const cached = barcodeLookupCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
        return cached.result;
    }

    // 1. O(1) lookup via Barcode GSI3 — direct key access
    let result = await queryItems<Record<string, any>>(
        Keys.barcodeGSI3PK(tenantId), Keys.barcodeGSI3SK(barcode),
        {
            indexName: 'GSI3',
            limit: 1,
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
        },
    );

    // 2. Fallback: check altBarcodes (rare, for multi-barcode products)
    if (result.items.length === 0) {
        result = await queryItems<Record<string, any>>(
            Keys.tenantPK(tenantId), 'PRODUCT#',
            {
                filterExpression: 'contains(altBarcodes, :bc) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':bc': barcode, ':false': false },
                limit: 1,
            },
        );
    }

    if (result.items.length > 0) {
        const row = result.items[0];
        const lookupResult: BarcodeLookupResult = {
            found: true, source: 'local',
            data: {
                id: row.id, name: row.name, category: row.category, brand: row.brand,
                barcode: row.barcode, sku: row.sku, unit: row.unit,
                salePriceCents: Number(row.salePriceCents || 0),
                purchasePriceCents: row.purchasePriceCents ? Number(row.purchasePriceCents) : null,
                mrpCents: row.mrpCents ? Number(row.mrpCents) : null,
                currentStock: Number(row.currentStock || 0), hsnCode: row.hsnCode, attributes: row.attributes,
                imageUrl: row.imageUrl || null,
            },
        };
        // L-10: Cache result
        barcodeLookupCache.set(cacheKey, { result: lookupResult, expiresAt: Date.now() + DEBOUNCE_MS });
        return lookupResult;
    }

    // 3. External lookup — H-5 FIX: Added 2s AbortSignal timeout
    try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 2000); // 2s timeout
        try {
            const response = await fetch(
                `https://world.openfoodfacts.org/api/v2/product/${barcode}.json`,
                { signal: controller.signal },
            );
            clearTimeout(timeout);
            if (response.ok) {
                const data = await response.json() as any;
                if (data.status === 1 && data.product) {
                    const p = data.product;
                    const lookupResult: BarcodeLookupResult = {
                        found: true, source: 'openfoodfacts',
                        data: {
                            name: p.product_name || null, brand: p.brands || null,
                            category: p.categories_tags?.[0]?.replace('en:', '') || null,
                            barcode, imageUrl: p.image_url || null,
                        },
                    };
                    barcodeLookupCache.set(cacheKey, { result: lookupResult, expiresAt: Date.now() + DEBOUNCE_MS });
                    return lookupResult;
                }
            }
        } finally {
            clearTimeout(timeout);
        }
    } catch (err) {
        const errName = (err as Error).name;
        if (errName === 'AbortError') {
            logger.warn('External barcode lookup timed out (2s)', { barcode });
        } else {
            logger.warn('External barcode lookup failed', { barcode, error: (err as Error).message });
        }
    }

    const noResult: BarcodeLookupResult = { found: false, source: null, data: null };
    barcodeLookupCache.set(cacheKey, { result: noResult, expiresAt: Date.now() + DEBOUNCE_MS });
    return noResult;
}

export async function analyzeImage(_tenantId: string, imageBuffer: Buffer): Promise<ImageAnalysisResult> {
    try {
        const { RekognitionClient, DetectLabelsCommand } = await import('@aws-sdk/client-rekognition');
        const client = new RekognitionClient({ region: config.aws.region });
        const result = await client.send(new DetectLabelsCommand({ Image: { Bytes: imageBuffer }, MaxLabels: 10, MinConfidence: 70 }));
        const labels = result.Labels || [];
        const categoryKeywords = ['food', 'beverage', 'drink', 'snack', 'medicine', 'electronics', 'clothing', 'grocery'];
        let bestName: string | null = null, bestCategory: string | null = null, bestBrand: string | null = null, bestConfidence = 0;

        for (const label of labels) {
            const name = label.Name?.toLowerCase() || '';
            if (!bestName && (label.Confidence || 0) > bestConfidence) { bestName = label.Name || null; bestConfidence = label.Confidence || 0; }
            if (!bestCategory && categoryKeywords.some(kw => name.includes(kw))) bestCategory = label.Name || null;
        }
        return { name: bestName, category: bestCategory, brand: bestBrand, confidence: Math.round(bestConfidence) };
    } catch (err) {
        logger.warn('Rekognition failed', { error: (err as Error).message });
        return { name: null, category: null, brand: null, confidence: 0 };
    }
}

/**
 * Add stock: creates a new product OR replenishes an existing one.
 * H-1 FIX: If productId is provided, atomically increments currentStock.
 */
export async function addStockItem(
    tenantId: string,
    itemData: Record<string, unknown>,
): Promise<{ id: string; name: string; isNew: boolean; newStock?: number }> {
    const productId = itemData.productId as string | undefined;
    const quantity = Number(itemData.quantity || itemData.currentStock || 0);

    if (quantity < 0) {
        throw new StockError('Stock quantity must be non-negative', 400);
    }
    if (productId && quantity === 0) {
        throw new StockError('Replenishment quantity must be positive', 400);
    }

    // H-1: REPLENISH existing product
    if (productId) {
        const pk = Keys.tenantPK(tenantId);
        const existing = await getItem<Record<string, any>>(pk, Keys.productSK(productId));
        if (!existing || existing.isDeleted) {
            throw new StockError(`Product '${productId}' not found`, 404);
        }

        const now = new Date().toISOString();
        const result = await updateItem(pk, Keys.productSK(productId), {
            updateExpression: 'SET currentStock = currentStock + :qty, updatedAt = :now',
            conditionExpression: 'attribute_exists(PK)',
            expressionAttributeValues: { ':qty': quantity, ':now': now },
        });

        const newStock = Number((result as any)?.currentStock) || 0;

        // Audit log for stock replenishment
        logAudit({
            action: 'STOCK_REPLENISHED',
            resource: 'inventory',
            resourceId: productId,
            metadata: { addedQty: quantity, newStock, productName: existing.name },
        }).catch(() => { });
        await recordRevision(
            tenantId,
            'inventory',
            productId,
            'update',
            'system',
            existing,
            { ...(result || {}), currentStock: newStock },
            { source: 'stock.addStockItem.replenish', addedQty: quantity },
        );

        logger.info('Stock replenished', { tenantId, productId, addedQty: quantity, newStock });
        return { id: productId, name: existing.name, isNew: false, newStock };
    }

    // CREATE new product
    const name = itemData.name as string;
    if (!name) throw new StockError('Item name is required');

    const barcodeVal = (itemData.barcode as string) || null;
    const skuVal = (itemData.sku as string) || null;

    // Enforce barcode uniqueness within tenant
    if (barcodeVal) {
        const existing = await queryItems<Record<string, any>>(
            Keys.barcodeGSI3PK(tenantId), Keys.barcodeGSI3SK(barcodeVal),
            {
                indexName: 'GSI3', limit: 1,
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
            },
        );
        if (existing.items.length > 0) {
            throw new StockError(
                `Barcode '${barcodeVal}' is already assigned to product '${existing.items[0].name}'`,
                409,
            );
        }
    }

    const itemId = uuidv4();
    const now = new Date().toISOString();

    const item: Record<string, unknown> = {
        PK: Keys.tenantPK(tenantId), SK: Keys.productSK(itemId),
        entityType: 'PRODUCT', id: itemId, tenantId,
        name, displayName: (itemData.displayName as string) || name,
        category: (itemData.category as string) || null, brand: (itemData.brand as string) || null,
        barcode: barcodeVal, sku: skuVal,
        unit: (itemData.unit as string) || 'pcs',
        salePriceCents: (itemData.salePriceCents as number) || 0,
        purchasePriceCents: (itemData.purchasePriceCents as number) || null,
        mrpCents: (itemData.mrpCents as number) || null,
        currentStock: quantity,
        hsnCode: (itemData.hsnCode as string) || null,
        productType: (itemData.productType as string) || 'general',
        attributes: itemData.attributes || {},
        imageUrl: (itemData.imageUrl as string) || null,
        isActive: true, isArchived: false, isDeleted: false, isService: false,
        createdAt: now, updatedAt: now,
    };

    // Populate SKU GSI1
    if (skuVal) {
        item.GSI1PK = Keys.tenantPK(tenantId);
        item.GSI1SK = Keys.skuGSI1SK(skuVal);
    }

    // Populate Barcode GSI3 for O(1) barcode lookups
    if (barcodeVal) {
        item.GSI3PK = Keys.barcodeGSI3PK(tenantId);
        item.GSI3SK = Keys.barcodeGSI3SK(barcodeVal);
    }

    await putItem(item, 'attribute_not_exists(PK)');
    await recordRevision(
        tenantId,
        'inventory',
        itemId,
        'create',
        'system',
        null,
        item as Record<string, unknown>,
        { source: 'stock.addStockItem.create' },
    );

    logAudit({
        action: 'STOCK_ITEM_CREATED',
        resource: 'inventory',
        resourceId: itemId,
        metadata: { name, barcode: barcodeVal, quantity },
    }).catch(() => { });

    logger.info('Stock item added', { tenantId, itemId, name, quantity });
    return { id: itemId, name, isNew: true, newStock: quantity };
}

// M-10: StockError now extends AppError for standardized error handling
export class StockError extends AppError {
    constructor(message: string, statusCode = 400) {
        super(message, statusCode, 'STOCK_ERROR');
        this.name = 'StockError';
    }
}
