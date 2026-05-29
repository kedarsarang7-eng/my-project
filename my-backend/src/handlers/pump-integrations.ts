import { config } from '../config/environment';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseBody, parseQuery } from '../middleware/validation';
import { BusinessType, UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, putItem, getItem, updateItem, queryItems, queryAllItems } from '../config/dynamodb.config';
import { pollAtgReadingsForTenant } from '../services/atg-connector.service';
import { recordRevision } from '../services/revision-history.service';
import * as response from '../utils/response';

const PUMP_INTEGRATION_OPTS = {
    requiredBusinessType: BusinessType.PETROL_PUMP,
    requiredFeature: FeatureKey.PETROL_DIP_READING,
};

function hasEnv(name: string): boolean {
    const value = process.env[name];
    return typeof value === 'string' && value.trim().length > 0;
}

const fleetAuthSchema = z.object({
    provider: z.enum(['fuelnet', 'smartfleet', 'other']),
    cardNumber: z.string().min(4).max(40),
    amountCents: z.number().int().positive(),
    vehicleNumber: z.string().max(20).optional(),
});

const manualDipSchema = z.object({
    tankId: z.string().uuid(),
    dipLevelMm: z.number().positive(),
    observedVolumeLiters: z.number().positive(),
    notes: z.string().max(500).optional(),
});

const atgIngestSchema = z.object({
    tankId: z.string().uuid(),
    source: z.enum(['atg']),
    measuredVolumeLiters: z.number().positive(),
    measuredAt: z.string().datetime(),
    rawPayload: z.record(z.string(), z.unknown()).optional(),
    /** p18 — probe / ATG annex fields (optional) */
    waterLevelMm: z.number().nonnegative().optional(),
    temperatureCelsius: z.number().optional(),
    leakDetected: z.boolean().optional(),
    highWaterAlarm: z.boolean().optional(),
});

const atgPollSchema = z.object({
    dryRun: z.boolean().optional(),
});

const dipChartUploadSchema = z.object({
    tankId: z.string().uuid(),
    chartName: z.string().min(2).max(120).optional(),
    effectiveFrom: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    points: z.array(z.object({
        mm: z.number().nonnegative(),
        liters: z.number().nonnegative(),
    })).min(2),
});

const dipConvertSchema = z.object({
    tankId: z.string().uuid(),
    dipLevelMm: z.coerce.number().nonnegative(),
    atDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

/** p17 — PPM / impurity reading (stored as DENSITY# for sync `density_records`) */
const ppmReadingSchema = z.object({
    tankId: z.string().uuid(),
    ppmValue: z.number().nonnegative(),
    measuredAt: z.string().datetime().optional(),
    temperatureCelsius: z.number().min(-50).max(150).optional(),
    dipLevelMm: z.number().nonnegative().optional(),
    observedVolumeLiters: z.number().nonnegative().optional(),
    notes: z.string().max(500).optional(),
});

const tankerReceiptSchema = z.object({
    tankId: z.string().uuid(),
    fuelType: z.enum(['petrol', 'diesel', 'cng', 'other']),
    tankerNumber: z.string().min(3).max(40),
    supplierName: z.string().min(2).max(120).optional(),
    supplierId: z.string().uuid().optional(),
    purchaseOrderId: z.string().uuid().optional(),
    invoiceNumber: z.string().max(80).optional(),
    expectedQtyLiters: z.number().positive(),
    receivedQtyLiters: z.number().positive(),
    ratePerLiterCents: z.number().int().positive().optional(),
    totalAmountCents: z.number().int().positive().optional(),
    dipBeforeMm: z.number().nonnegative().optional(),
    dipAfterMm: z.number().nonnegative().optional(),
    dipBeforeLiters: z.number().nonnegative().optional(),
    dipAfterLiters: z.number().nonnegative().optional(),
    thresholdLiters: z.number().nonnegative().default(20),
    receivedAt: z.string().datetime().optional(),
    notes: z.string().max(500).optional(),
});

function normalizeChartPoints(
    points: Array<{ mm: number; liters: number }>,
): Array<{ mm: number; liters: number }> {
    const byMm = new Map<number, number>();
    for (const p of points) {
        byMm.set(Number(p.mm), Number(p.liters));
    }
    return Array.from(byMm.entries())
        .map(([mm, liters]) => ({ mm, liters }))
        .sort((a, b) => a.mm - b.mm);
}

function interpolateLiters(
    points: Array<{ mm: number; liters: number }>,
    dipLevelMm: number,
): number {
    if (points.length === 0) return 0;
    if (dipLevelMm <= points[0].mm) return points[0].liters;
    if (dipLevelMm >= points[points.length - 1].mm) return points[points.length - 1].liters;

    for (let i = 1; i < points.length; i += 1) {
        const p2 = points[i];
        const p1 = points[i - 1];
        if (dipLevelMm <= p2.mm) {
            const spanMm = p2.mm - p1.mm;
            if (spanMm <= 0) return p2.liters;
            const ratio = (dipLevelMm - p1.mm) / spanMm;
            return p1.liters + ((p2.liters - p1.liters) * ratio);
        }
    }
    return points[points.length - 1].liters;
}

export const authorizeFleetCard = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.PUMPBOY],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(fleetAuthSchema, event);
        if (!parsed.success) return parsed.error;

        const fleetIntegrationEnabled = (process.env.PUMP_FLEET_INTEGRATION_ENABLED ?? config.extendedPump.fleetIntegrationEnabled) === 'true';
        if (!fleetIntegrationEnabled) {
            return response.error(
                501,
                'FLEET_INTEGRATION_NOT_CONFIGURED',
                'Fleet card integration not configured. Set PUMP_FLEET_INTEGRATION_ENABLED=true and provider credentials.',
            );
        }
        if (!hasEnv('PUMP_FLEET_PROVIDER_API_KEY')) {
            return response.error(
                501,
                'FLEET_INTEGRATION_CREDENTIALS_MISSING',
                'Fleet integration enabled but credentials missing (PUMP_FLEET_PROVIDER_API_KEY).',
            );
        }

        return response.success({
            provider: parsed.data.provider,
            approved: false,
            status: 'pending_provider_integration',
            message: 'Provider hook not implemented yet.',
        });
    },
    PUMP_INTEGRATION_OPTS,
);

export const recordManualDip = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(manualDipSchema, event);
        if (!parsed.success) return parsed.error;

        const id = uuidv4();
        const now = new Date().toISOString();
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `TANKDIP#${parsed.data.tankId}#${now}#${id}`,
            entityType: 'TANK_DIP_READING',
            id,
            tenantId: auth.tenantId,
            tankId: parsed.data.tankId,
            dipLevelMm: parsed.data.dipLevelMm,
            observedVolumeLiters: parsed.data.observedVolumeLiters,
            notes: parsed.data.notes || null,
            source: 'manual',
            recordedBy: auth.sub,
            recordedAt: now,
            createdAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'tank_dips',
            id,
            'create',
            auth.sub,
            null,
            {
                id,
                tankId: parsed.data.tankId,
                dipLevelMm: parsed.data.dipLevelMm,
                observedVolumeLiters: parsed.data.observedVolumeLiters,
                recordedAt: now,
            },
            { source: 'pump-integrations.recordManualDip' },
        );

        return response.success({ id, source: 'manual' }, 201);
    },
    PUMP_INTEGRATION_OPTS,
);

export const ingestAtgReading = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(atgIngestSchema, event);
        if (!parsed.success) return parsed.error;

        const atgEnabled = (process.env.PUMP_ATG_INTEGRATION_ENABLED ?? config.extendedPump.atgIntegrationEnabled) === 'true';
        if (!atgEnabled) {
            return response.error(
                501,
                'ATG_INTEGRATION_NOT_CONFIGURED',
                'ATG integration not configured. Set PUMP_ATG_INTEGRATION_ENABLED=true and connector credentials.',
            );
        }
        if (!hasEnv('PUMP_ATG_CONNECTOR_TOKEN')) {
            return response.error(
                501,
                'ATG_INTEGRATION_CREDENTIALS_MISSING',
                'ATG integration enabled but connector credentials missing (PUMP_ATG_CONNECTOR_TOKEN).',
            );
        }

        const id = uuidv4();
        const now = new Date().toISOString();
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `TANKATG#${parsed.data.tankId}#${parsed.data.measuredAt}#${id}`,
            entityType: 'TANK_ATG_READING',
            id,
            tenantId: auth.tenantId,
            tankId: parsed.data.tankId,
            measuredVolumeLiters: parsed.data.measuredVolumeLiters,
            measuredAt: parsed.data.measuredAt,
            rawPayload: parsed.data.rawPayload || null,
            waterLevelMm: parsed.data.waterLevelMm ?? null,
            temperatureCelsius: parsed.data.temperatureCelsius ?? null,
            leakDetected: parsed.data.leakDetected ?? null,
            highWaterAlarm: parsed.data.highWaterAlarm ?? null,
            source: 'atg',
            createdBy: auth.sub,
            createdAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'tank_atg_readings',
            id,
            'create',
            auth.sub,
            null,
            {
                id,
                tankId: parsed.data.tankId,
                measuredVolumeLiters: parsed.data.measuredVolumeLiters,
                measuredAt: parsed.data.measuredAt,
            },
            { source: 'pump-integrations.ingestAtgReading' },
        );

        return response.success({ id, source: 'atg' }, 201);
    },
    PUMP_INTEGRATION_OPTS,
);

/**
 * p18 — Pull latest ATG samples from configured connector and persist as TANKATG rows.
 */
export const pollAtgReadings = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(atgPollSchema, event);
        if (!parsed.success) return parsed.error;

        const atgEnabled = config.extendedPump.atgIntegrationEnabled === 'true';
        if (!atgEnabled) {
            return response.error(
                501,
                'ATG_INTEGRATION_NOT_CONFIGURED',
                'ATG integration not configured. Set PUMP_ATG_INTEGRATION_ENABLED=true and connector credentials.',
            );
        }

        if (parsed.data.dryRun) {
            return response.success({ dryRun: true, message: 'Dry run accepted. No ATG polling performed.' });
        }

        const result = await pollAtgReadingsForTenant(auth.tenantId, auth.sub);
        return response.success(result, 200);
    },
    PUMP_INTEGRATION_OPTS,
);

/**
 * p14 — Upload dip chart points (mm -> liters) for a tank.
 */
export const uploadDipChart = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(dipChartUploadSchema, event);
        if (!parsed.success) return parsed.error;

        const now = new Date().toISOString();
        const effectiveFrom = parsed.data.effectiveFrom || now.substring(0, 10);
        const chartId = uuidv4();
        const points = normalizeChartPoints(parsed.data.points);

        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `DIPCHART#${parsed.data.tankId}#${effectiveFrom}#${chartId}`,
            entityType: 'TANK_DIP_CHART',
            id: chartId,
            tenantId: auth.tenantId,
            tankId: parsed.data.tankId,
            chartName: parsed.data.chartName || `Chart ${effectiveFrom}`,
            effectiveFrom,
            points,
            pointCount: points.length,
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        });
        await recordRevision(
            auth.tenantId,
            'tank_calibration_charts',
            chartId,
            'create',
            auth.sub,
            null,
            {
                id: chartId,
                tankId: parsed.data.tankId,
                effectiveFrom,
                pointCount: points.length,
            },
            { source: 'pump-integrations.uploadDipChart' },
        );

        return response.success({
            id: chartId,
            tankId: parsed.data.tankId,
            effectiveFrom,
            pointCount: points.length,
        }, 201);
    },
    PUMP_INTEGRATION_OPTS,
);

/**
 * p14 — Convert dip mm -> liters using latest chart for tank.
 */
export const convertDipToVolume = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.PUMPBOY],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseQuery(dipConvertSchema, event);
        if (!parsed.success) return parsed.error;

        const atDate = parsed.data.atDate || new Date().toISOString().substring(0, 10);
        const charts = await queryAllItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'DIPCHART#', {
            filterExpression:
                'tankId = :tankId AND effectiveFrom <= :atDate AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: {
                ':tankId': parsed.data.tankId,
                ':atDate': atDate,
                ':false': false,
            },
            maxPages: 20,
        });

        if (!charts.length) {
            return response.error(404, 'DIP_CHART_NOT_FOUND', 'No dip chart found for this tank');
        }

        charts.sort((a, b) => String(b.effectiveFrom || '').localeCompare(String(a.effectiveFrom || '')));
        const chart = charts[0];
        const points = normalizeChartPoints(Array.isArray(chart.points) ? chart.points : []);
        if (points.length < 2) {
            return response.error(422, 'DIP_CHART_INVALID', 'Dip chart requires at least 2 valid points');
        }

        const volumeLiters = interpolateLiters(points, Number(parsed.data.dipLevelMm));
        return response.success({
            tankId: parsed.data.tankId,
            dipLevelMm: Number(parsed.data.dipLevelMm),
            volumeLiters: Math.round(volumeLiters * 1000) / 1000,
            chartId: chart.id,
            chartEffectiveFrom: chart.effectiveFrom,
            pointsUsed: points.length,
        });
    },
    PUMP_INTEGRATION_OPTS,
);

/**
 * p16 — Record tanker/bowser receipt with dip-short detection.
 */
export const recordTankerReceipt = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(tankerReceiptSchema, event);
        if (!parsed.success) return parsed.error;

        const body = parsed.data;
        const now = new Date().toISOString();
        const receivedAt = body.receivedAt ? new Date(body.receivedAt).toISOString() : now;
        const expectedQtyLiters = Number(body.expectedQtyLiters || 0);
        const receivedQtyLiters = Number(body.receivedQtyLiters || 0);
        const shortageLiters = Math.max(expectedQtyLiters - receivedQtyLiters, 0);
        const excessLiters = Math.max(receivedQtyLiters - expectedQtyLiters, 0);
        const deltaLiters = Math.round((receivedQtyLiters - expectedQtyLiters) * 1000) / 1000;
        const thresholdLiters = Number(body.thresholdLiters || 0);
        const isDipShort = shortageLiters > thresholdLiters;
        const status = isDipShort ? 'dip_short' : 'ok';
        const id = uuidv4();

        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `TANKERRECEIPT#${receivedAt}#${id}`,
            entityType: 'TANKER_RECEIPT',
            id,
            tenantId: auth.tenantId,
            tankId: body.tankId,
            fuelType: body.fuelType,
            tankerNumber: body.tankerNumber,
            supplierId: body.supplierId || null,
            supplierName: body.supplierName || null,
            purchaseOrderId: body.purchaseOrderId || null,
            invoiceNumber: body.invoiceNumber || null,
            expectedQtyLiters,
            receivedQtyLiters,
            ratePerLiterCents: body.ratePerLiterCents || null,
            totalAmountCents: body.totalAmountCents || null,
            shortageLiters: Math.round(shortageLiters * 1000) / 1000,
            excessLiters: Math.round(excessLiters * 1000) / 1000,
            deltaLiters,
            thresholdLiters,
            isDipShort,
            status,
            dipBeforeMm: body.dipBeforeMm ?? null,
            dipAfterMm: body.dipAfterMm ?? null,
            dipBeforeLiters: body.dipBeforeLiters ?? null,
            dipAfterLiters: body.dipAfterLiters ?? null,
            notes: body.notes || null,
            receivedAt,
            recordedBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
            // GSI for PO-based lookups
            GSI1PK: body.purchaseOrderId ? `PO#${body.purchaseOrderId}` : null,
            GSI1SK: `TANKERRECEIPT#${receivedAt}`,
        });
        await recordRevision(
            auth.tenantId,
            'tanker_deliveries',
            id,
            'create',
            auth.sub,
            null,
            {
                id,
                tankId: body.tankId,
                fuelType: body.fuelType,
                expectedQtyLiters,
                receivedQtyLiters,
                shortageLiters: Math.round(shortageLiters * 1000) / 1000,
                status,
                receivedAt,
            },
            { source: 'pump-integrations.recordTankerReceipt' },
        );

        return response.success({
            id,
            status,
            isDipShort,
            expectedQtyLiters,
            receivedQtyLiters,
            shortageLiters: Math.round(shortageLiters * 1000) / 1000,
            excessLiters: Math.round(excessLiters * 1000) / 1000,
            deltaLiters,
        }, 201);
    },
    PUMP_INTEGRATION_OPTS,
);

/**
 * p17 — Record PPM (impurity) reading for density-adjusted workflows.
 */
export const recordPpmReading = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.PUMPBOY],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(ppmReadingSchema, event);
        if (!parsed.success) return parsed.error;

        const id = uuidv4();
        const now = new Date().toISOString();
        const measuredAt = parsed.data.measuredAt ? new Date(parsed.data.measuredAt).toISOString() : now;

        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `DENSITY#${id}`,
            entityType: 'DENSITY_RECORD',
            id,
            tenantId: auth.tenantId,
            tankId: parsed.data.tankId,
            ppmValue: parsed.data.ppmValue,
            measuredAt,
            temperatureCelsius: parsed.data.temperatureCelsius ?? null,
            dipLevelMm: parsed.data.dipLevelMm ?? null,
            observedVolumeLiters: parsed.data.observedVolumeLiters ?? null,
            notes: parsed.data.notes ?? null,
            recordedBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        });
        await recordRevision(
            auth.tenantId,
            'density_records',
            id,
            'create',
            auth.sub,
            null,
            {
                id,
                tankId: parsed.data.tankId,
                ppmValue: parsed.data.ppmValue,
                measuredAt,
                temperatureCelsius: parsed.data.temperatureCelsius ?? null,
                dipLevelMm: parsed.data.dipLevelMm ?? null,
                observedVolumeLiters: parsed.data.observedVolumeLiters ?? null,
            },
            { source: 'pump-integrations.recordPpmReading' },
        );

        return response.success({
            id,
            tankId: parsed.data.tankId,
            ppmValue: parsed.data.ppmValue,
            measuredAt,
            temperatureCelsius: parsed.data.temperatureCelsius ?? null,
            dipLevelMm: parsed.data.dipLevelMm ?? null,
            observedVolumeLiters: parsed.data.observedVolumeLiters ?? null,
        }, 201);
    },
    PUMP_INTEGRATION_OPTS,
);

// ============================================================================
// Fleet Vehicle Management (BUG-FIX: Fleet vehicle management endpoints)
// ============================================================================

const fleetVehicleSchema = z.object({
    vehicleNumber: z.string().min(4).max(20),
    customerId: z.string().uuid(),
    vehicleType: z.enum(['two_wheeler', 'car', 'auto', 'bus', 'truck', 'tractor', 'other']).default('car'),
    fuelType: z.enum(['petrol', 'diesel', 'cng', 'other']).default('petrol'),
    make: z.string().max(50).optional(),
    model: z.string().max(50).optional(),
    year: z.number().int().min(1990).max(2030).optional(),
    driverName: z.string().max(100).optional(),
    driverPhone: z.string().max(20).optional(),
    creditLimitCents: z.number().int().min(0).default(0),
    isActive: z.boolean().default(true),
    notes: z.string().max(500).optional(),
});

const updateFleetVehicleSchema = fleetVehicleSchema.partial().omit({ customerId: true });

const fleetVehicleQuerySchema = z.object({
    customerId: z.string().uuid().optional(),
    vehicleNumber: z.string().max(20).optional(),
    fuelType: z.enum(['petrol', 'diesel', 'cng', 'other']).optional(),
    isActive: z.enum(['true', 'false']).optional(),
    limit: z.coerce.number().int().min(1).max(100).default(50),
});

/**
 * POST /pump/fleet-vehicles — Create fleet vehicle
 */
export const createFleetVehicle = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(fleetVehicleSchema, event);
        if (!parsed.success) return parsed.error;

        const body = parsed.data;
        const now = new Date().toISOString();
        const id = uuidv4();

        // Verify customer exists and is a fleet type
        const customer = await getItem<Record<string, any>>(
            Keys.tenantPK(auth.tenantId),
            Keys.customerSK(body.customerId),
        );
        if (!customer || customer.isDeleted) {
            return response.notFound('Customer');
        }
        if (customer.customerType !== 'fleet' && customer.tier !== 'fleet') {
            return response.error(400, 'INVALID_CUSTOMER_TYPE', 'Vehicle can only be linked to fleet customers');
        }

        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `FLEETVEHICLE#${id}`,
            entityType: 'FLEET_VEHICLE',
            id,
            tenantId: auth.tenantId,
            customerId: body.customerId,
            vehicleNumber: body.vehicleNumber,
            normalizedVehicleNumber: body.vehicleNumber.replace(/[^a-zA-Z0-9]/g, '').toUpperCase(),
            vehicleType: body.vehicleType,
            fuelType: body.fuelType,
            make: body.make || null,
            model: body.model || null,
            year: body.year || null,
            driverName: body.driverName || null,
            driverPhone: body.driverPhone || null,
            creditLimitCents: body.creditLimitCents,
            isActive: body.isActive,
            notes: body.notes || null,
            totalFuelings: 0,
            totalLiters: 0,
            totalAmountCents: 0,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
            // GSI for customer-based lookups
            GSI1PK: `CUSTOMER#${body.customerId}`,
            GSI1SK: `FLEETVEHICLE#${body.vehicleNumber}`,
        });

        await recordRevision(
            auth.tenantId,
            'fleet_vehicles',
            id,
            'create',
            auth.sub,
            null,
            {
                id,
                customerId: body.customerId,
                vehicleNumber: body.vehicleNumber,
                vehicleType: body.vehicleType,
                fuelType: body.fuelType,
                createdAt: now,
            },
            { source: 'pump-integrations.createFleetVehicle' },
        );

        return response.success({
            id,
            customerId: body.customerId,
            vehicleNumber: body.vehicleNumber,
            message: 'Fleet vehicle created successfully',
        }, 201);
    },
    PUMP_INTEGRATION_OPTS,
);

/**
 * PUT /pump/fleet-vehicles/{id} — Update fleet vehicle
 */
export const updateFleetVehicle = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(updateFleetVehicleSchema, event);
        if (!parsed.success) return parsed.error;

        const vehicleId = event.pathParameters?.id;
        if (!vehicleId) return response.error(400, 'MISSING_ID', 'Vehicle ID required');

        const pk = Keys.tenantPK(auth.tenantId);
        const vehicle = await getItem<Record<string, any>>(pk, `FLEETVEHICLE#${vehicleId}`);
        if (!vehicle || vehicle.isDeleted) return response.notFound('Fleet vehicle');

        const body = parsed.data;
        const now = new Date().toISOString();

        const updateExpr: string[] = ['updatedAt = :now'];
        const exprValues: Record<string, any> = { ':now': now };
        const exprNames: Record<string, string> = {};

        if (body.vehicleNumber !== undefined) {
            updateExpr.push('vehicleNumber = :vn');
            updateExpr.push('normalizedVehicleNumber = :nvn');
            exprValues[':vn'] = body.vehicleNumber;
            exprValues[':nvn'] = body.vehicleNumber.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
        }
        if (body.vehicleType !== undefined) {
            updateExpr.push('vehicleType = :vt');
            exprValues[':vt'] = body.vehicleType;
        }
        if (body.fuelType !== undefined) {
            updateExpr.push('fuelType = :ft');
            exprValues[':ft'] = body.fuelType;
        }
        if (body.make !== undefined) {
            updateExpr.push('#mk = :mk');
            exprNames['#mk'] = 'make';
            exprValues[':mk'] = body.make;
        }
        if (body.model !== undefined) {
            updateExpr.push('#mo = :mo');
            exprNames['#mo'] = 'model';
            exprValues[':mo'] = body.model;
        }
        if (body.year !== undefined) {
            updateExpr.push('#yr = :yr');
            exprNames['#yr'] = 'year';
            exprValues[':yr'] = body.year;
        }
        if (body.driverName !== undefined) {
            updateExpr.push('driverName = :dn');
            exprValues[':dn'] = body.driverName;
        }
        if (body.driverPhone !== undefined) {
            updateExpr.push('driverPhone = :dp');
            exprValues[':dp'] = body.driverPhone;
        }
        if (body.creditLimitCents !== undefined) {
            updateExpr.push('creditLimitCents = :cl');
            exprValues[':cl'] = body.creditLimitCents;
        }
        if (body.isActive !== undefined) {
            updateExpr.push('isActive = :ia');
            exprValues[':ia'] = body.isActive;
        }
        if (body.notes !== undefined) {
            updateExpr.push('notes = :nt');
            exprValues[':nt'] = body.notes;
        }

        await updateItem(pk, `FLEETVEHICLE#${vehicleId}`, {
            updateExpression: `SET ${updateExpr.join(', ')}`,
            expressionAttributeValues: exprValues,
            ...(Object.keys(exprNames).length > 0 && { expressionAttributeNames: exprNames }),
        });

        await recordRevision(
            auth.tenantId,
            'fleet_vehicles',
            vehicleId,
            'update',
            auth.sub,
            vehicle,
            { ...vehicle, ...body, updatedAt: now },
            { source: 'pump-integrations.updateFleetVehicle' },
        );

        return response.success({
            id: vehicleId,
            updatedFields: Object.keys(body),
            message: 'Fleet vehicle updated successfully',
        });
    },
    PUMP_INTEGRATION_OPTS,
);

/**
 * GET /pump/fleet-vehicles — List fleet vehicles
 */
export const listFleetVehicles = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseQuery(fleetVehicleQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const { customerId, vehicleNumber, fuelType, isActive, limit } = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);

        let vehicles: Record<string, any>[] = [];

        if (customerId) {
            // Use GSI for customer-based query
            const gsiResult = await queryItems<Record<string, any>>(
                `CUSTOMER#${customerId}`,
                'FLEETVEHICLE#',
                { indexName: 'GSI1Index', limit },
            );
            vehicles = gsiResult.items;
        } else {
            // Scan all fleet vehicles for tenant
            const result = await queryAllItems<Record<string, any>>(pk, 'FLEETVEHICLE#', { maxPages: 10 });
            vehicles = result;
        }

        // Apply filters
        const filtered = vehicles
            .filter((v) => !v.isDeleted)
            .filter((v) => {
                if (vehicleNumber) {
                    const normalized = vehicleNumber.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
                    return v.normalizedVehicleNumber?.includes(normalized);
                }
                if (fuelType && v.fuelType !== fuelType) return false;
                if (isActive !== undefined && String(v.isActive) !== isActive) return false;
                return true;
            })
            .slice(0, limit);

        const items = filtered.map((v) => ({
            id: v.id,
            customerId: v.customerId,
            vehicleNumber: v.vehicleNumber,
            vehicleType: v.vehicleType,
            fuelType: v.fuelType,
            make: v.make,
            model: v.model,
            year: v.year,
            driverName: v.driverName,
            driverPhone: v.driverPhone,
            creditLimitCents: v.creditLimitCents,
            isActive: v.isActive,
            totalFuelings: v.totalFuelings || 0,
            totalLiters: v.totalLiters || 0,
            totalAmountCents: v.totalAmountCents || 0,
            notes: v.notes,
            createdAt: v.createdAt,
            updatedAt: v.updatedAt,
        }));

        return response.success({
            count: items.length,
            filter: { customerId: customerId || null, vehicleNumber: vehicleNumber || null, fuelType: fuelType || null },
            items,
        });
    },
    PUMP_INTEGRATION_OPTS,
);

/**
 * DELETE /pump/fleet-vehicles/{id} — Soft delete fleet vehicle
 */
export const deleteFleetVehicle = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const vehicleId = event.pathParameters?.id;
        if (!vehicleId) return response.error(400, 'MISSING_ID', 'Vehicle ID required');

        const pk = Keys.tenantPK(auth.tenantId);
        const vehicle = await getItem<Record<string, any>>(pk, `FLEETVEHICLE#${vehicleId}`);
        if (!vehicle || vehicle.isDeleted) return response.notFound('Fleet vehicle');

        const now = new Date().toISOString();

        await updateItem(pk, `FLEETVEHICLE#${vehicleId}`, {
            updateExpression: 'SET isDeleted = :del, deletedAt = :at, deletedBy = :by, updatedAt = :now, isActive = :inactive',
            expressionAttributeValues: {
                ':del': true,
                ':at': now,
                ':by': auth.sub,
                ':now': now,
                ':inactive': false,
            },
        });

        await recordRevision(
            auth.tenantId,
            'fleet_vehicles',
            vehicleId,
            'delete',
            auth.sub,
            vehicle,
            { ...vehicle, isDeleted: true, deletedAt: now, deletedBy: auth.sub },
            { source: 'pump-integrations.deleteFleetVehicle' },
        );

        return response.success({
            id: vehicleId,
            message: 'Fleet vehicle deleted successfully',
            deletedAt: now,
        });
    },
    PUMP_INTEGRATION_OPTS,
);
