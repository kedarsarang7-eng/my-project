import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, TABLE_NAME, queryItems, queryAllItems, transactWrite } from '../config/dynamodb.config';
import { AuthContext, BusinessType, UserRole } from '../types/tenant.types';
import { parseBody, parseQuery } from '../middleware/validation';
import * as response from '../utils/response';
import { logAudit } from '../middleware/audit';
import { logger } from '../utils/logger';
import { recordRevision } from '../services/revision-history.service';

const PUMP_PRICING_OPTS = {
    requiredBusinessType: BusinessType.PETROL_PUMP,
    requiredFeature: FeatureKey.PETROL_BASIC_SHIFT_ENTRY,
};

const fuelPriceUpdateSchema = z.object({
    fuelType: z.enum(['petrol', 'diesel', 'cng', 'other']),
    pricePerLiterCents: z.number().int().positive(),
    effectiveFrom: z.string().datetime().optional(),
    reason: z.string().min(3).max(500),
});

const fuelPriceHistoryQuerySchema = z.object({
    fuelType: z.enum(['petrol', 'diesel', 'cng', 'other']),
    limit: z.coerce.number().int().min(1).max(200).default(50),
});

function latestTankVolumesAsOf(
    dips: Array<Record<string, any>>,
    atgRows: Array<Record<string, any>>,
    asOfDay: string,
): Map<string, { fuelType: string; liters: number; asOf: string }> {
    const latest = new Map<string, { fuelType: string; liters: number; asOf: string }>();
    for (const d of dips) {
        const ts = String(d.recordedAt || d.createdAt || '');
        const day = ts.substring(0, 10);
        if (!day || day > asOfDay) continue;
        const tankId = String(d.tankId || 'unknown');
        const prev = latest.get(tankId);
        if (!prev || ts > prev.asOf) {
            latest.set(tankId, {
                fuelType: String(d.fuelType || 'unknown').toLowerCase(),
                liters: Number(d.observedVolumeLiters || 0),
                asOf: ts,
            });
        }
    }
    for (const a of atgRows) {
        const ts = String(a.measuredAt || a.createdAt || '');
        const day = ts.substring(0, 10);
        if (!day || day > asOfDay) continue;
        const tankId = String(a.tankId || 'unknown');
        const prev = latest.get(tankId);
        if (!prev || ts > prev.asOf) {
            latest.set(tankId, {
                fuelType: String(a.fuelType || prev?.fuelType || 'unknown').toLowerCase(),
                liters: Number(a.measuredVolumeLiters || 0),
                asOf: ts,
            });
        }
    }
    return latest;
}

export const updateFuelPrice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(fuelPriceUpdateSchema, event);
        if (!parsed.success) return parsed.error;

        const { fuelType, pricePerLiterCents, reason } = parsed.data;
        const effectiveFrom = parsed.data.effectiveFrom || new Date().toISOString();
        const now = new Date().toISOString();
        const pk = Keys.tenantPK(auth.tenantId);

        const products = await queryItems<Record<string, any>>(pk, 'PRODUCT#', {
            filterExpression: 'productType = :pt AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':pt': fuelType, ':false': false },
            limit: 1,
        });

        if (products.items.length === 0) {
            return response.error(404, 'FUEL_PRODUCT_NOT_FOUND', `No fuel product found for '${fuelType}'`);
        }

        const product = products.items[0];
        const productId = product.id || String(product.SK || '').replace('PRODUCT#', '');
        const previousPriceCents = Number(product.salePriceCents || 0);
        const changeId = uuidv4();
        const effectiveDay = String(effectiveFrom).substring(0, 10);
        const [tankDips, atgRows] = await Promise.all([
            queryAllItems<Record<string, any>>(pk, 'TANKDIP#', {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
                maxPages: 40,
            }),
            queryAllItems<Record<string, any>>(pk, 'TANKATG#', { maxPages: 40 }),
        ]);
        const latestStockByTank = latestTankVolumesAsOf(tankDips, atgRows, effectiveDay);
        const stockHoldLitersRaw = Array.from(latestStockByTank.values())
            .filter((x) => x.fuelType === String(fuelType).toLowerCase())
            .reduce((acc, x) => acc + Number(x.liters || 0), 0);
        const deltaCents = pricePerLiterCents - previousPriceCents;
        const stockHoldLitersAtChange = Math.round(stockHoldLitersRaw * 1000) / 1000;
        const stockHoldInventoryImpactCentsAtChange = Math.round(stockHoldLitersRaw * deltaCents);

        const transactItems: any[] = [
            {
                Update: {
                    TableName: TABLE_NAME,
                    Key: { PK: pk, SK: Keys.productSK(productId) },
                    UpdateExpression: 'SET salePriceCents = :newPrice, lastPriceChangeAt = :effectiveFrom, updatedAt = :now',
                    ConditionExpression: 'attribute_exists(PK)',
                    ExpressionAttributeValues: {
                        ':newPrice': pricePerLiterCents,
                        ':effectiveFrom': effectiveFrom,
                        ':now': now,
                    },
                },
            },
            {
                Put: {
                    TableName: TABLE_NAME,
                    Item: {
                        PK: pk,
                        SK: `FUELPRICELOG#${fuelType}#${effectiveFrom}#${changeId}`,
                        entityType: 'FUEL_PRICE_LOG',
                        id: changeId,
                        tenantId: auth.tenantId,
                        fuelType,
                        productId,
                        previousPriceCents,
                        newPriceCents: pricePerLiterCents,
                        effectiveFrom,
                        reason,
                        changedBy: auth.sub,
                        changedByRole: auth.role,
                        stockHoldAsOf: effectiveDay,
                        stockHoldLitersAtChange,
                        stockHoldInventoryImpactCentsAtChange,
                        stockHoldComputation: 'persisted_snapshot_v1',
                        createdAt: now,
                    },
                    ConditionExpression: 'attribute_not_exists(PK)',
                },
            },
        ];

        await transactWrite(transactItems);
        await recordRevision(
            auth.tenantId,
            'fuel_pricing',
            productId,
            'update',
            auth.sub,
            {
                salePriceCents: previousPriceCents,
            },
            {
                salePriceCents: pricePerLiterCents,
            },
            {
                source: 'pump-pricing.updateFuelPrice',
                fuelType,
                reason,
                effectiveFrom,
                logId: changeId,
            },
        );

        logAudit({
            action: 'FUEL_PRICE_UPDATED',
            resource: 'fuel_price',
            resourceId: changeId,
            metadata: {
                fuelType,
                productId,
                previousPriceCents,
                newPriceCents: pricePerLiterCents,
                effectiveFrom,
                reason,
            },
        }).catch(() => { });

        logger.info('Fuel price updated', {
            tenantId: auth.tenantId,
            fuelType,
            previousPriceCents,
            newPriceCents: pricePerLiterCents,
            effectiveFrom,
            changedBy: auth.sub,
        });

        return response.success({
            id: changeId,
            fuelType,
            previousPriceCents,
            newPriceCents: pricePerLiterCents,
            effectiveFrom,
            reason,
            changedBy: auth.sub,
            changedAt: now,
        }, 201);
    },
    PUMP_PRICING_OPTS,
);

export const getFuelPriceHistory = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(fuelPriceHistoryQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const { fuelType, limit } = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);

        const logs = await queryItems<Record<string, any>>(pk, `FUELPRICELOG#${fuelType}#`, {
            scanIndexForward: false,
            limit,
        });

        return response.success({
            fuelType,
            items: logs.items.map((l) => ({
                id: l.id,
                previousPriceCents: Number(l.previousPriceCents || 0),
                newPriceCents: Number(l.newPriceCents || 0),
                effectiveFrom: l.effectiveFrom,
                reason: l.reason,
                changedBy: l.changedBy,
                changedByRole: l.changedByRole,
                createdAt: l.createdAt,
            })),
        });
    },
    PUMP_PRICING_OPTS,
);
