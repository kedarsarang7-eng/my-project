// ============================================================================
// Lambda Handler — Weighing Scale Integration (POST /weighscale/read)
// ============================================================================
// Receives weight readings from USB/serial weighing scales connected to the
// Flutter desktop POS. Calculates line total in integer paise.
//
// Supports: Essae DS-852, Contech CBW-6, CAS SW-1C (standard protocols)
//
// This is a STATELESS endpoint — it computes totals only.
// Actual billing happens via createInvoice with weight as quantity.
//
// Access: All roles (grocery business type, requires GROCERY_WEIGHING_SCALE feature)
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { Keys, getItem } from '../config/dynamodb.config';
import { FeatureKey } from '../config/plan-feature-registry';
import { BusinessType } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { z } from 'zod';
import { parseBody } from '../middleware/validation';

const weighScaleSchema = z.object({
    weight: z.number().positive('Weight must be positive'),
    unit: z.enum(['kg', 'g']).default('kg'),
    productId: z.string().optional(),
    scaleModel: z.string().optional(), // e.g. 'essae_ds852', 'contech_cbw6'
    tare: z.number().min(0).default(0), // Tare weight in same unit
});

/**
 * POST /weighscale/read
 *
 * Input:
 *   { weight: 2.350, unit: 'kg', productId?: 'prod-onion', tare?: 0.050 }
 *
 * Output:
 *   { netWeight, unit, productName?, unitPriceCents?, lineTotalCents?,
 *     displayWeight, displayTotal }
 */
export const readWeighScale = authorizedHandler(
    [], // All roles
    async (event, _context, auth) => {
        const parsed = parseBody(weighScaleSchema, event);
        if (!parsed.success) return parsed.error;

        const { weight, unit, productId, tare } = parsed.data;

        // Calculate net weight (subtract tare)
        let netWeight = weight - (tare || 0);
        if (netWeight < 0) netWeight = 0;

        // Normalize to kg for price calculation
        const netWeightKg = unit === 'g' ? netWeight / 1000 : netWeight;

        logger.info('Weighing scale reading', {
            tenantId: auth.tenantId,
            weight, unit, tare, netWeight, netWeightKg,
            productId: productId || 'none',
        });

        let result: Record<string, unknown> = {
            netWeight,
            netWeightKg,
            unit,
            tare: tare || 0,
            displayWeight: unit === 'kg'
                ? `${netWeight.toFixed(3)} kg`
                : `${netWeight.toFixed(0)} g`,
        };

        // If productId provided, lookup price and calculate line total
        if (productId) {
            const product = await getItem<Record<string, any>>(
                Keys.tenantPK(auth.tenantId),
                Keys.productSK(productId),
            );

            if (!product || product.isDeleted) {
                return response.notFound('Product not found');
            }

            const unitPriceCents = Number(product.salePriceCents) || 0;
            // Price is per kg — multiply by weight in kg
            const lineTotalCents = Math.round(unitPriceCents * netWeightKg);

            result = {
                ...result,
                productId: product.id,
                productName: product.name,
                unitPriceCents,
                unit: product.unit || 'kg',
                lineTotalCents,
                displayPrice: `₹${(unitPriceCents / 100).toFixed(2)}/kg`,
                displayTotal: `₹${(lineTotalCents / 100).toFixed(2)}`,
                mrpCents: product.mrpCents || null,
                currentStock: product.currentStock,
                hsnCode: product.hsnCode,
            };

            // Warn if stock is insufficient
            if (product.currentStock !== undefined && netWeightKg > product.currentStock) {
                (result as any).warning = {
                    type: 'INSUFFICIENT_STOCK',
                    message: `Only ${product.currentStock} ${product.unit || 'kg'} available`,
                    currentStock: product.currentStock,
                };
            }
        }

        return response.success(result);
    },
    {
        requiredBusinessType: BusinessType.GROCERY,
        requiredFeature: FeatureKey.GROCERY_WEIGHING_SCALE,
    },
);
