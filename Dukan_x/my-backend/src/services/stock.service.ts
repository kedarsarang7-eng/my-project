// ============================================================================
// Stock Service — Barcode Lookup, Image Analysis, Manual Add
// ============================================================================
// Provides stock management operations for the Flutter StockService client.
// All queries are tenant-scoped via RLS (set by authorizedHandler).
// ============================================================================

import { getPool } from '../config/db.config';
import { logger } from '../utils/logger';

// ---- Types ----

export interface BarcodeLookupResult {
    found: boolean;
    source: 'local' | 'openfoodfacts' | null;
    data: Record<string, unknown> | null;
}

export interface ImageAnalysisResult {
    name: string | null;
    category: string | null;
    brand: string | null;
    confidence: number;
}

// ---- Service Functions ----

/**
 * Lookup a product by barcode within the tenant's inventory.
 * Falls back to external API (Open Food Facts) if not found locally.
 */
export async function lookupBarcode(
    tenantId: string,
    barcode: string
): Promise<BarcodeLookupResult> {
    const db = getPool();

    // 1. Local lookup
    const localResult = await db.query(
        `SELECT id, name, category, brand, barcode, sku, unit,
                sale_price_cents, purchase_price_cents, mrp_cents,
                current_stock, hsn_code, attributes
         FROM inventory
         WHERE tenant_id = $1 AND (barcode = $2 OR $2 = ANY(
             SELECT jsonb_array_elements_text(alt_barcodes)
         )) AND NOT is_deleted
         LIMIT 1`,
        [tenantId, barcode]
    );

    if (localResult.rows.length > 0) {
        const row = localResult.rows[0];
        return {
            found: true,
            source: 'local',
            data: {
                id: row.id,
                name: row.name,
                category: row.category,
                brand: row.brand,
                barcode: row.barcode,
                sku: row.sku,
                unit: row.unit,
                salePriceCents: Number(row.sale_price_cents),
                purchasePriceCents: row.purchase_price_cents ? Number(row.purchase_price_cents) : null,
                mrpCents: row.mrp_cents ? Number(row.mrp_cents) : null,
                currentStock: Number(row.current_stock),
                hsnCode: row.hsn_code,
                attributes: row.attributes,
            },
        };
    }

    // 2. External lookup (Open Food Facts — free, no API key)
    try {
        const response = await fetch(`https://world.openfoodfacts.org/api/v2/product/${barcode}.json`);
        if (response.ok) {
            const data = await response.json() as any;
            if (data.status === 1 && data.product) {
                const p = data.product;
                return {
                    found: true,
                    source: 'openfoodfacts',
                    data: {
                        name: p.product_name || p.product_name_en || null,
                        brand: p.brands || null,
                        category: p.categories_tags?.[0]?.replace('en:', '') || null,
                        barcode,
                        imageUrl: p.image_url || null,
                        quantity: p.quantity || null,
                    },
                };
            }
        }
    } catch (err) {
        logger.warn('External barcode lookup failed', { barcode, error: (err as Error).message });
    }

    return { found: false, source: null, data: null };
}

/**
 * Analyze a product image to extract name/category using AWS Rekognition.
 * Falls back to empty result if Rekognition is unavailable.
 */
export async function analyzeImage(
    _tenantId: string,
    imageBuffer: Buffer
): Promise<ImageAnalysisResult> {
    try {
        const { RekognitionClient, DetectLabelsCommand } = await import('@aws-sdk/client-rekognition');
        const client = new RekognitionClient({ region: process.env.AWS_REGION || 'ap-south-1' });

        const command = new DetectLabelsCommand({
            Image: { Bytes: imageBuffer },
            MaxLabels: 10,
            MinConfidence: 70,
        });

        const result = await client.send(command);
        const labels = result.Labels || [];

        // Map Rekognition labels to product attributes
        // Category heuristic: first label that looks like a product category
        const categoryKeywords = [
            'food', 'beverage', 'drink', 'snack', 'medicine', 'tablet', 'bottle',
            'electronics', 'clothing', 'hardware', 'tool', 'cosmetic', 'grocery',
            'fruit', 'vegetable', 'dairy', 'meat', 'candy', 'chip', 'soap',
        ];

        let bestName: string | null = null;
        let bestCategory: string | null = null;
        let bestBrand: string | null = null;
        let bestConfidence = 0;

        for (const label of labels) {
            const name = label.Name?.toLowerCase() || '';
            const confidence = label.Confidence || 0;

            if (!bestName && confidence > bestConfidence) {
                bestName = label.Name || null;
                bestConfidence = confidence;
            }

            if (!bestCategory && categoryKeywords.some(kw => name.includes(kw))) {
                bestCategory = label.Name || null;
            }
        }

        // Check for text detection (brand names)
        try {
            const { DetectTextCommand } = await import('@aws-sdk/client-rekognition');
            const textCmd = new DetectTextCommand({
                Image: { Bytes: imageBuffer },
            });
            const textResult = await client.send(textCmd);
            const detectedTexts = textResult.TextDetections || [];

            // First LINE-type detection is likely the brand/product name
            const lineTexts = detectedTexts
                .filter((t: any) => t.Type === 'LINE' && (t.Confidence || 0) > 80)
                .sort((a: any, b: any) => (b.Confidence || 0) - (a.Confidence || 0));

            if (lineTexts.length > 0) {
                bestBrand = lineTexts[0].DetectedText || null;
                if (lineTexts.length > 1 && !bestName) {
                    bestName = lineTexts[1].DetectedText || null;
                }
            }
        } catch (textErr) {
            logger.warn('Text detection failed, skipping brand extraction', {
                error: (textErr as Error).message,
            });
        }

        logger.info('Image analysis completed via Rekognition', {
            labelsCount: labels.length,
            bestName,
            bestCategory,
            bestConfidence,
        });

        return {
            name: bestName,
            category: bestCategory,
            brand: bestBrand,
            confidence: Math.round(bestConfidence),
        };
    } catch (err) {
        logger.warn('Rekognition analysis failed, returning empty result', {
            error: (err as Error).message,
        });
        return { name: null, category: null, brand: null, confidence: 0 };
    }
}

/**
 * Add a new stock item to the tenant's inventory.
 */
export async function addStockItem(
    tenantId: string,
    itemData: Record<string, unknown>
): Promise<{ id: string; name: string }> {
    const db = getPool();

    const name = itemData.name as string;
    if (!name) {
        throw new StockError('Item name is required');
    }

    const result = await db.query(
        `INSERT INTO inventory
         (tenant_id, name, display_name, category, brand, barcode, sku, unit,
          sale_price_cents, purchase_price_cents, mrp_cents, current_stock,
          hsn_code, product_type, attributes)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
         RETURNING id, name`,
        [
            tenantId,
            name,
            (itemData.displayName as string) || name,
            (itemData.category as string) || null,
            (itemData.brand as string) || null,
            (itemData.barcode as string) || null,
            (itemData.sku as string) || null,
            (itemData.unit as string) || 'pcs',
            (itemData.salePriceCents as number) || 0,
            (itemData.purchasePriceCents as number) || null,
            (itemData.mrpCents as number) || null,
            (itemData.currentStock as number) || 0,
            (itemData.hsnCode as string) || null,
            (itemData.productType as string) || 'general',
            JSON.stringify(itemData.attributes || {}),
        ]
    );

    const created = result.rows[0];
    logger.info('Stock item added', { tenantId, itemId: created.id, name: created.name });

    return { id: created.id, name: created.name };
}

// ---- Errors ----

export class StockError extends Error {
    public statusCode: number;
    constructor(message: string, statusCode = 400) {
        super(message);
        this.name = 'StockError';
        this.statusCode = statusCode;
    }
}
