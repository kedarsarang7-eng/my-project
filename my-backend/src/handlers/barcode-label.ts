// ============================================================================
// Lambda Handler — Barcode Label Printing (POST /inventory/labels)
// ============================================================================
// Generates structured label data for barcode printing.
// Actual label rendering happens in Flutter via the `printing` package.
//
// Supports single and batch label generation.
// Returns: product name, barcode, MRP, sale price, HSN, expiry, weight
//
// Access: Owner, Admin, Manager
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { Keys, batchGetItems, getItem } from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { z } from 'zod';
import { parseBody } from '../middleware/validation';

const singleLabelSchema = z.object({
    productId: z.string(),
    labelFormat: z.enum(['38x25mm', '50x30mm', '50x25mm', '100x50mm']).default('50x30mm'),
    copies: z.number().int().min(1).max(500).default(1),
});

const batchLabelsSchema = z.object({
    productIds: z.array(z.string()).min(1).max(100),
    labelFormat: z.enum(['38x25mm', '50x30mm', '50x25mm', '100x50mm']).default('50x30mm'),
    copiesEach: z.number().int().min(1).max(100).default(1),
});

interface LabelData {
    productId: string;
    productName: string;
    barcode?: string;
    sku?: string;
    hsnCode?: string;
    mrpCents?: number;
    salePriceCents: number;
    unit: string;
    category?: string;
    expiryDate?: string;
    weight?: string;
    labelFormat: string;
    copies: number;
    // Pre-formatted for label printing
    mrpDisplay?: string;
    priceDisplay: string;
    barcodeType: 'EAN13' | 'CODE128' | 'QR';
}

/**
 * POST /inventory/{id}/label
 * Generate label data for a single product.
 */
export const generateLabel = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const productId = event.pathParameters?.id;
        if (!productId) return response.badRequest('Missing product ID');

        const parsed = parseBody(singleLabelSchema, event);
        if (!parsed.success) return parsed.error;

        const product = await getItem<Record<string, any>>(
            Keys.tenantPK(auth.tenantId),
            Keys.productSK(productId),
        );

        if (!product || product.isDeleted) {
            return response.notFound('Product not found');
        }

        const label = buildLabelData(product, parsed.data.labelFormat, parsed.data.copies);

        logger.info('Label generated', {
            tenantId: auth.tenantId,
            productId,
            copies: parsed.data.copies,
        });

        return response.success(label);
    },
);

/**
 * POST /inventory/labels
 * Batch generate label data for multiple products.
 */
export const generateBatchLabels = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const parsed = parseBody(batchLabelsSchema, event);
        if (!parsed.success) return parsed.error;

        const { productIds, labelFormat, copiesEach } = parsed.data;

        // Batch fetch all products
        const keys = productIds.map(id => ({
            PK: Keys.tenantPK(auth.tenantId),
            SK: Keys.productSK(id),
        }));

        const products = await batchGetItems<Record<string, any>>(keys);
        const productMap = new Map(products.map(p => [p.id, p]));

        const labels: LabelData[] = [];
        const missing: string[] = [];

        for (const id of productIds) {
            const product = productMap.get(id);
            if (!product || product.isDeleted) {
                missing.push(id);
                continue;
            }
            labels.push(buildLabelData(product, labelFormat, copiesEach));
        }

        logger.info('Batch labels generated', {
            tenantId: auth.tenantId,
            requested: productIds.length,
            generated: labels.length,
            missing: missing.length,
        });

        return response.success({
            labels,
            totalLabels: labels.reduce((sum, l) => sum + l.copies, 0),
            missing,
        });
    },
);

function buildLabelData(
    product: Record<string, any>,
    labelFormat: string,
    copies: number,
): LabelData {
    const salePriceCents = Number(product.salePriceCents) || 0;
    const mrpCents = product.mrpCents ? Number(product.mrpCents) : undefined;
    const barcode = product.barcode || product.sku || '';

    // Determine barcode type based on barcode format
    let barcodeType: 'EAN13' | 'CODE128' | 'QR' = 'CODE128';
    if (barcode.length === 13 && /^\d+$/.test(barcode)) {
        barcodeType = 'EAN13';
    } else if (barcode.length > 20) {
        barcodeType = 'QR';
    }

    return {
        productId: product.id,
        productName: product.name || '',
        barcode: barcode || undefined,
        sku: product.sku,
        hsnCode: product.hsnCode,
        mrpCents,
        salePriceCents,
        unit: product.unit || 'pcs',
        category: product.category,
        expiryDate: product.expiryDate,
        weight: product.weight,
        labelFormat,
        copies,
        mrpDisplay: mrpCents ? `MRP ₹${(mrpCents / 100).toFixed(2)}` : undefined,
        priceDisplay: `₹${(salePriceCents / 100).toFixed(2)}`,
        barcodeType,
    };
}
