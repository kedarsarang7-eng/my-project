import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, queryAllItems } from '../config/dynamodb.config';
import { AuthContext, BusinessType, UserRole } from '../types/tenant.types';
import { parseQuery } from '../middleware/validation';
import * as response from '../utils/response';
import { formatVehicleNumber, normalizeVehicleNumber } from '../utils/vehicle.util';

const PUMP_REPORT_OPTS = {
    requiredBusinessType: BusinessType.PETROL_PUMP,
    requiredFeature: FeatureKey.PETROL_BASIC_SHIFT_ENTRY,
};

const dateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

const dsrQuerySchema = z.object({
    date: dateSchema,
});

const rangeQuerySchema = z.object({
    from: dateSchema,
    to: dateSchema,
});

/** p7 — vehicle-wise sale history + udhar dues (canonical INVOICE# rows only) */
const vehicleLedgerQuerySchema = z.object({
    vehicleNumber: z.string().min(2).max(32),
    from: dateSchema.optional(),
    to: dateSchema.optional(),
});

/** p8 — canonical tank stock report window */
const tankStockQuerySchema = z.object({
    from: dateSchema.optional(),
    to: dateSchema.optional(),
});

/** p9 — dip variance trend window */
const dipVarianceQuerySchema = z.object({
    from: dateSchema.optional(),
    to: dateSchema.optional(),
    tankId: z.string().uuid().optional(),
});

/** p16 — tanker receipt report */
const tankerReceiptQuerySchema = z.object({
    from: dateSchema.optional(),
    to: dateSchema.optional(),
    tankId: z.string().uuid().optional(),
    status: z.enum(['ok', 'dip_short']).optional(),
    fuelType: z.enum(['petrol', 'diesel', 'cng', 'other']).optional(),
    supplierSearch: z.string().min(1).max(80).optional(),
    supplierId: z.string().uuid().optional(),
    purchaseOrderId: z.string().uuid().optional(),
});

/** p18 — ATG reading register (TANKATG# rows) */
const atgReadingsQuerySchema = z.object({
    from: dateSchema.optional(),
    to: dateSchema.optional(),
    tankId: z.string().uuid().optional(),
    alertsOnly: z.enum(['true', 'false']).optional(),
});

/** p10 — fuel rate variation trend + volume impact */
const rateVariationQuerySchema = z.object({
    fuelType: z.enum(['petrol', 'diesel', 'cng', 'other']).optional(),
    from: dateSchema.optional(),
    to: dateSchema.optional(),
});

/** p11 — stock valuation variants */
const stockValuationQuerySchema = z.object({
    from: dateSchema.optional(),
    to: dateSchema.optional(),
    fuelType: z.enum(['petrol', 'diesel', 'cng', 'other']).optional(),
    method: z.enum(['fifo', 'purchase_rate', 'sale_rate', 'density_adjusted']).default('fifo'),
    densityFactor: z.coerce.number().positive().max(2).optional(),
    /** ppm at which multiplier would hit ppmFloor if linear (see stock valuation handler) */
    ppmScale: z.coerce.number().positive().max(1_000_000).optional(),
    ppmFloor: z.coerce.number().min(0.5).max(1).optional(),
});

function inRange(date: string, from: string, to: string): boolean {
    return date >= from && date <= to;
}

/** Latest reading per tank on/before report end — used for p4 stock-hold impact at rate change */
function buildLatestTankVolumesByTank(
    tankStockRows: Record<string, unknown>[],
    atgRows: Record<string, unknown>[],
    cutoffDay: string,
): Map<string, { tankId: string; fuelType: string; volumeLiters: number; asOf: string }> {
    const cutoffIso = `${cutoffDay}T23:59:59.999Z`;
    const latestByTank = new Map<string, { tankId: string; fuelType: string; volumeLiters: number; asOf: string }>();
    for (const d of tankStockRows) {
        const row = d as Record<string, unknown>;
        const asOf = String(row.recordedAt || row.createdAt || '');
        if (!asOf || asOf > cutoffIso) continue;
        const tankId = String(row.tankId || 'unknown');
        const prev = latestByTank.get(tankId);
        if (!prev || asOf > prev.asOf) {
            latestByTank.set(tankId, {
                tankId,
                fuelType: String(row.fuelType || 'unknown'),
                volumeLiters: Number(row.observedVolumeLiters || 0),
                asOf,
            });
        }
    }
    for (const a of atgRows) {
        const row = a as Record<string, unknown>;
        const asOf = String(row.measuredAt || row.createdAt || '');
        if (!asOf || asOf > cutoffIso) continue;
        const tankId = String(row.tankId || 'unknown');
        const prev = latestByTank.get(tankId);
        if (!prev || asOf > prev.asOf) {
            latestByTank.set(tankId, {
                tankId,
                fuelType: String(row.fuelType || prev?.fuelType || 'unknown'),
                volumeLiters: Number(row.measuredVolumeLiters || 0),
                asOf,
            });
        }
    }
    return latestByTank;
}

function sumStockLitersForFuel(
    latestByTank: Map<string, { fuelType: string; volumeLiters: number }>,
    fuelType: string,
): number {
    let sum = 0;
    for (const row of latestByTank.values()) {
        if (String(row.fuelType) === fuelType) sum += row.volumeLiters;
    }
    return sum;
}

/** Latest DENSITY# / PPM sample per tank on/before end of `to` day (p17) */
function latestPpmForTank(
    densityRows: Record<string, unknown>[],
    tankId: string,
    toDay: string,
): { ppmValue: number; measuredAt: string } | null {
    const cutoff = `${toDay}T23:59:59.999Z`;
    let best: { ppmValue: number; measuredAt: string } | null = null;
    for (const r of densityRows) {
        if (String((r as { tankId?: string }).tankId) !== tankId) continue;
        const at = String((r as { measuredAt?: string }).measuredAt || (r as { createdAt?: string }).createdAt || '');
        if (!at || at > cutoff) continue;
        const ppm = Number((r as { ppmValue?: unknown }).ppmValue ?? (r as { ppm?: unknown }).ppm ?? NaN);
        if (!Number.isFinite(ppm) || ppm < 0) continue;
        if (!best || at > best.measuredAt) best = { ppmValue: ppm, measuredAt: at };
    }
    return best;
}

export const dsrReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(dsrQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const { date } = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);
        const shifts = await queryAllItems<Record<string, any>>(pk, 'SHIFT#', { maxPages: 10 });
        const dayShifts = shifts.filter((s) => (s.shiftDate || '').startsWith(date) && !s.isDeleted);

        const totals = dayShifts.reduce((acc, s) => {
            acc.totalSalesCents += Number(s.totalSalesCents || 0);
            acc.totalCashCents += Number(s.totalCashCents || 0);
            acc.totalUpiCents += Number(s.totalUpiCents || 0);
            acc.totalUdharCents += Number(s.totalUdharCents || 0);
            acc.totalVolumeLiters += Number(s.totalVolumeLiters || 0);
            acc.saleCount += Number(s.saleCount || 0);
            return acc;
        }, {
            totalSalesCents: 0,
            totalCashCents: 0,
            totalUpiCents: 0,
            totalUdharCents: 0,
            totalVolumeLiters: 0,
            saleCount: 0,
        });

        return response.success({
            date,
            shifts: dayShifts.map((s) => ({
                shiftId: s.id,
                staffId: s.staffId,
                staffName: s.staffName,
                shiftStatus: s.shiftStatus,
                openedAt: s.openedAt,
                closedAt: s.closedAt,
                totalSalesCents: Number(s.totalSalesCents || 0),
                totalCashCents: Number(s.totalCashCents || 0),
                totalUpiCents: Number(s.totalUpiCents || 0),
                totalUdharCents: Number(s.totalUdharCents || 0),
                totalVolumeLiters: Number(s.totalVolumeLiters || 0),
                saleCount: Number(s.saleCount || 0),
            })),
            totals,
        });
    },
    PUMP_REPORT_OPTS,
);

export const nozzleSalesReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(rangeQuerySchema, event);
        if (!parsed.success) return parsed.error;
        const { from, to } = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);

        const shifts = await queryAllItems<Record<string, any>>(pk, 'SHIFT#', { maxPages: 20 });
        const filtered = shifts.filter((s) => inRange(String(s.shiftDate || ''), from, to) && !s.isDeleted);

        const nozzleMap = new Map<string, {
            nozzleId: string;
            nozzleName: string;
            fuelType: string;
            meterDispensedLiters: number;
            recordedSalesLiters: number;
            varianceLiters: number;
        }>();

        for (const s of filtered) {
            const reconciliation = Array.isArray(s.nozzleReconciliation) ? s.nozzleReconciliation : [];
            for (const n of reconciliation) {
                const nozzleId = n.nozzleId || 'unknown';
                const current = nozzleMap.get(nozzleId) || {
                    nozzleId,
                    nozzleName: n.nozzleName || nozzleId,
                    fuelType: n.fuelType || 'unknown',
                    meterDispensedLiters: 0,
                    recordedSalesLiters: 0,
                    varianceLiters: 0,
                };
                current.meterDispensedLiters += Number(n.netMeterDispensedLiters || 0);
                current.recordedSalesLiters += Number(n.recordedSalesLiters || 0);
                current.varianceLiters += Number(n.varianceLiters || 0);
                nozzleMap.set(nozzleId, current);
            }
        }

        return response.success({
            period: { from, to },
            items: Array.from(nozzleMap.values()),
        });
    },
    PUMP_REPORT_OPTS,
);

export const shiftCollectionReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(rangeQuerySchema, event);
        if (!parsed.success) return parsed.error;
        const { from, to } = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);

        const shifts = await queryAllItems<Record<string, any>>(pk, 'SHIFT#', { maxPages: 20 });
        const items = shifts
            .filter((s) => inRange(String(s.shiftDate || ''), from, to) && !s.isDeleted)
            .map((s) => ({
                shiftId: s.id,
                shiftDate: s.shiftDate,
                staffId: s.staffId,
                staffName: s.staffName,
                totalSalesCents: Number(s.totalSalesCents || 0),
                totalCashCents: Number(s.totalCashCents || 0),
                totalUpiCents: Number(s.totalUpiCents || 0),
                totalUdharCents: Number(s.totalUdharCents || 0),
                saleCount: Number(s.saleCount || 0),
                totalVolumeLiters: Number(s.totalVolumeLiters || 0),
                shiftStatus: s.shiftStatus,
            }));

        return response.success({ period: { from, to }, items });
    },
    PUMP_REPORT_OPTS,
);

export const cashierCollectionReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(rangeQuerySchema, event);
        if (!parsed.success) return parsed.error;
        const { from, to } = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);

        const shifts = await queryAllItems<Record<string, any>>(pk, 'SHIFT#', { maxPages: 30 });
        const filtered = shifts.filter((s) => inRange(String(s.shiftDate || ''), from, to) && !s.isDeleted);

        const cashierMap = new Map<string, {
            staffId: string;
            staffName: string;
            shiftCount: number;
            totalSalesCents: number;
            totalCashCents: number;
            totalUpiCents: number;
            totalCardCents: number;
            totalChequeCents: number;
            totalNeftCents: number;
            totalFleetCardCents: number;
            totalUdharCents: number;
            totalVolumeLiters: number;
            totalVarianceLiters: number;
        }>();

        for (const s of filtered) {
            const staffId = String(s.staffId || 'unknown');
            const current = cashierMap.get(staffId) || {
                staffId,
                staffName: String(s.staffName || staffId),
                shiftCount: 0,
                totalSalesCents: 0,
                totalCashCents: 0,
                totalUpiCents: 0,
                totalCardCents: 0,
                totalChequeCents: 0,
                totalNeftCents: 0,
                totalFleetCardCents: 0,
                totalUdharCents: 0,
                totalVolumeLiters: 0,
                totalVarianceLiters: 0,
            };
            current.shiftCount += 1;
            current.totalSalesCents += Number(s.totalSalesCents || 0);
            current.totalCashCents += Number(s.totalCashCents || 0);
            current.totalUpiCents += Number(s.totalUpiCents || 0);
            current.totalCardCents += Number(s.totalCardCents || 0);
            current.totalChequeCents += Number(s.totalChequeCents || 0);
            current.totalNeftCents += Number(s.totalNeftCents || 0);
            current.totalFleetCardCents += Number(s.totalFleetCardCents || 0);
            current.totalUdharCents += Number(s.totalUdharCents || 0);
            current.totalVolumeLiters += Number(s.totalVolumeLiters || 0);

            const recon = Array.isArray(s.nozzleReconciliation) ? s.nozzleReconciliation : [];
            for (const n of recon) {
                current.totalVarianceLiters += Number(n.varianceLiters || 0);
            }
            cashierMap.set(staffId, current);
        }

        const items = Array.from(cashierMap.values()).map((c) => ({
            ...c,
            totalVolumeLiters: Math.round(c.totalVolumeLiters * 1000) / 1000,
            totalVarianceLiters: Math.round(c.totalVarianceLiters * 1000) / 1000,
        }));

        return response.success({ period: { from, to }, items });
    },
    PUMP_REPORT_OPTS,
);

export const vehicleLedgerReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, _auth: AuthContext) => {
        const parsed = parseQuery(vehicleLedgerQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const vn = normalizeVehicleNumber(parsed.data.vehicleNumber);
        if (!vn) {
            return response.badRequest('Invalid vehicle number');
        }

        const { from, to } = parsed.data;
        const pk = Keys.tenantPK(_auth.tenantId);

        const invoices = await queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
            filterExpression:
                'vehicleNumber = :vn AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':vn': vn, ':false': false },
            maxPages: 40,
        });

        const saleRows = invoices.filter((inv) => {
            const t = inv.type ?? inv.metadata?.type;
            return !t || t === 'sale';
        });

        let filtered = saleRows;
        if (from || to) {
            filtered = saleRows.filter((inv) => {
                const d = String(inv.saleDate || (inv.createdAt ? inv.createdAt.substring(0, 10) : ''));
                if (!d) return false;
                if (from && d < from) return false;
                if (to && d > to) return false;
                return true;
            });
        }

        filtered.sort((a, b) => String(a.createdAt || '').localeCompare(String(b.createdAt || '')));

        let totalSalesCents = 0;
        let totalPaidCents = 0;
        let totalOutstandingCents = 0;

        const items = filtered.map((inv) => {
            const totalCents = Number(inv.totalCents || 0);
            const paidCents = Number(inv.paidCents || 0);
            const balanceCents = Number(
                inv.balanceCents ?? Math.max(totalCents - paidCents, 0),
            );
            totalSalesCents += totalCents;
            totalPaidCents += paidCents;
            totalOutstandingCents += balanceCents;

            const sourceRaw = inv.metadata?.source;
            const source =
                sourceRaw === 'staff_sale'
                    ? 'staff_sale'
                    : sourceRaw === 'pump_sale'
                        ? 'pump_sale'
                        : inv.nozzleId
                            ? 'pump_sale'
                            : 'sale';

            return {
                invoiceId: inv.id,
                invoiceNumber: inv.invoiceNumber,
                saleDate: inv.saleDate || (inv.createdAt ? inv.createdAt.substring(0, 10) : null),
                fuelType: inv.fuelType || inv.productType || inv.metadata?.productType || null,
                volumeLiters: Number(inv.volumeLiters || 0),
                totalCents,
                paidCents,
                balanceCents,
                paymentMode: inv.paymentMode,
                customerId: inv.customerId || null,
                shiftId: inv.shiftId || null,
                nozzleId: inv.nozzleId || null,
                source,
            };
        });

        return response.success({
            vehicleNumber: vn,
            vehicleDisplay: formatVehicleNumber(vn),
            period: from && to ? { from, to } : { from: from ?? null, to: to ?? null },
            summary: {
                transactionCount: items.length,
                totalSalesCents,
                totalPaidCents,
                totalOutstandingCents,
            },
            items,
        });
    },
    PUMP_REPORT_OPTS,
);

export const tankStockReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(tankStockQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const from = parsed.data.from || new Date(Date.now() - 30 * 86400000).toISOString().substring(0, 10);
        const to = parsed.data.to || new Date().toISOString().substring(0, 10);
        if (from > to) return response.badRequest('from must be <= to');

        const pk = Keys.tenantPK(auth.tenantId);
        const dips = await queryAllItems<Record<string, any>>(pk, 'TANKDIP#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });
        const atg = await queryAllItems<Record<string, any>>(pk, 'TANKATG#', {
            maxPages: 40,
        });

        const tankMap = new Map<string, {
            tankId: string;
            latestReadingAt: string | null;
            latestDipMm: number | null;
            latestObservedVolumeLiters: number | null;
            latestAtgVolumeLiters: number | null;
            readingCount: number;
            source: 'manual' | 'atg' | 'mixed' | 'unknown';
        }>();

        for (const d of dips) {
            const day = String(d.recordedAt || d.createdAt || '').substring(0, 10);
            if (!day || day < from || day > to) continue;
            const tankId = String(d.tankId || 'unknown');
            const current = tankMap.get(tankId) || {
                tankId,
                latestReadingAt: null,
                latestDipMm: null,
                latestObservedVolumeLiters: null,
                latestAtgVolumeLiters: null,
                readingCount: 0,
                source: 'unknown' as const,
            };
            current.readingCount += 1;
            const recordedAt = String(d.recordedAt || d.createdAt || '');
            if (!current.latestReadingAt || recordedAt > current.latestReadingAt) {
                current.latestReadingAt = recordedAt;
                current.latestDipMm = Number(d.dipLevelMm || 0);
                current.latestObservedVolumeLiters = Number(d.observedVolumeLiters || 0);
            }
            current.source = current.source === 'atg' ? 'mixed' : 'manual';
            tankMap.set(tankId, current);
        }

        for (const a of atg) {
            const day = String(a.measuredAt || a.createdAt || '').substring(0, 10);
            if (!day || day < from || day > to) continue;
            const tankId = String(a.tankId || 'unknown');
            const current = tankMap.get(tankId) || {
                tankId,
                latestReadingAt: null,
                latestDipMm: null,
                latestObservedVolumeLiters: null,
                latestAtgVolumeLiters: null,
                readingCount: 0,
                source: 'unknown' as const,
            };
            current.readingCount += 1;
            const measuredAt = String(a.measuredAt || a.createdAt || '');
            if (!current.latestReadingAt || measuredAt > current.latestReadingAt) {
                current.latestReadingAt = measuredAt;
                current.latestAtgVolumeLiters = Number(a.measuredVolumeLiters || 0);
            } else if (current.latestAtgVolumeLiters == null) {
                current.latestAtgVolumeLiters = Number(a.measuredVolumeLiters || 0);
            }
            current.source = current.source === 'manual' ? 'mixed' : 'atg';
            tankMap.set(tankId, current);
        }

        const items = Array.from(tankMap.values())
            .map((t) => {
                const canonicalVolumeLiters =
                    t.latestAtgVolumeLiters != null ? t.latestAtgVolumeLiters : (t.latestObservedVolumeLiters || 0);
                return {
                    tankId: t.tankId,
                    latestReadingAt: t.latestReadingAt,
                    latestDipMm: t.latestDipMm,
                    latestObservedVolumeLiters: t.latestObservedVolumeLiters,
                    latestAtgVolumeLiters: t.latestAtgVolumeLiters,
                    canonicalVolumeLiters: Math.round(canonicalVolumeLiters * 1000) / 1000,
                    readingCount: t.readingCount,
                    source: t.source,
                };
            })
            .sort((a, b) => String(a.tankId).localeCompare(String(b.tankId)));

        const totals = items.reduce((acc, item) => {
            acc.tankCount += 1;
            acc.totalCanonicalVolumeLiters += Number(item.canonicalVolumeLiters || 0);
            return acc;
        }, { tankCount: 0, totalCanonicalVolumeLiters: 0 });

        totals.totalCanonicalVolumeLiters = Math.round(totals.totalCanonicalVolumeLiters * 1000) / 1000;

        return response.success({
            period: { from, to },
            totals,
            items,
        });
    },
    PUMP_REPORT_OPTS,
);

export const dipVarianceReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(dipVarianceQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const from = parsed.data.from || new Date(Date.now() - 30 * 86400000).toISOString().substring(0, 10);
        const to = parsed.data.to || new Date().toISOString().substring(0, 10);
        if (from > to) return response.badRequest('from must be <= to');

        const pk = Keys.tenantPK(auth.tenantId);
        const shifts = await queryAllItems<Record<string, any>>(pk, 'SHIFT#', { maxPages: 40 });
        const filteredShifts = shifts.filter((s) => {
            const d = String(s.shiftDate || '');
            return d >= from && d <= to && !s.isDeleted;
        });

        const tankMap = new Map<string, {
            tankId: string;
            tankName: string;
            fuelType: string;
            shiftCount: number;
            totalVarianceLiters: number;
            positiveVarianceLiters: number;
            negativeVarianceLiters: number;
            maxAbsVarianceLiters: number;
            exceptionsCount: number;
        }>();

        for (const s of filteredShifts) {
            const recon = Array.isArray(s.nozzleReconciliation) ? s.nozzleReconciliation : [];
            for (const n of recon) {
                const tankId = String(n.tankId || n.nozzleId || 'unknown');
                if (parsed.data.tankId && tankId !== parsed.data.tankId) continue;
                const variance = Number(n.varianceLiters || 0);
                const abs = Math.abs(variance);
                const status = String(n.status || '');
                const isException = status === 'VARIANCE' || abs > 2;

                const current = tankMap.get(tankId) || {
                    tankId,
                    tankName: String(n.tankName || n.nozzleName || tankId),
                    fuelType: String(n.fuelType || 'unknown'),
                    shiftCount: 0,
                    totalVarianceLiters: 0,
                    positiveVarianceLiters: 0,
                    negativeVarianceLiters: 0,
                    maxAbsVarianceLiters: 0,
                    exceptionsCount: 0,
                };

                current.shiftCount += 1;
                current.totalVarianceLiters += variance;
                if (variance >= 0) current.positiveVarianceLiters += variance;
                else current.negativeVarianceLiters += variance;
                current.maxAbsVarianceLiters = Math.max(current.maxAbsVarianceLiters, abs);
                if (isException) current.exceptionsCount += 1;
                tankMap.set(tankId, current);
            }
        }

        const items = Array.from(tankMap.values())
            .map((t) => ({
                ...t,
                avgVarianceLiters: t.shiftCount > 0 ? Math.round((t.totalVarianceLiters / t.shiftCount) * 1000) / 1000 : 0,
                totalVarianceLiters: Math.round(t.totalVarianceLiters * 1000) / 1000,
                positiveVarianceLiters: Math.round(t.positiveVarianceLiters * 1000) / 1000,
                negativeVarianceLiters: Math.round(t.negativeVarianceLiters * 1000) / 1000,
                maxAbsVarianceLiters: Math.round(t.maxAbsVarianceLiters * 1000) / 1000,
            }))
            .sort((a, b) => Math.abs(b.totalVarianceLiters) - Math.abs(a.totalVarianceLiters));

        const totals = items.reduce((acc, item) => {
            acc.tankCount += 1;
            acc.shiftSampleCount += item.shiftCount;
            acc.totalVarianceLiters += item.totalVarianceLiters;
            acc.exceptionsCount += item.exceptionsCount;
            return acc;
        }, { tankCount: 0, shiftSampleCount: 0, totalVarianceLiters: 0, exceptionsCount: 0 });
        totals.totalVarianceLiters = Math.round(totals.totalVarianceLiters * 1000) / 1000;

        return response.success({
            period: { from, to },
            filter: { tankId: parsed.data.tankId || null },
            totals,
            items,
        });
    },
    PUMP_REPORT_OPTS,
);

export const tankerReceiptReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(tankerReceiptQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const from = parsed.data.from || new Date(Date.now() - 30 * 86400000).toISOString().substring(0, 10);
        const to = parsed.data.to || new Date().toISOString().substring(0, 10);
        if (from > to) return response.badRequest('from must be <= to');

        const rows = await queryAllItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'TANKERRECEIPT#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });

        const search = (parsed.data.supplierSearch || '').trim().toLowerCase();

        const filtered = rows
            .filter((r) => {
                const d = String(r.receivedAt || r.createdAt || '').substring(0, 10);
                if (!d || d < from || d > to) return false;
                if (parsed.data.tankId && String(r.tankId) !== parsed.data.tankId) return false;
                if (parsed.data.status && String(r.status) !== parsed.data.status) return false;
                if (parsed.data.fuelType && String(r.fuelType) !== parsed.data.fuelType) return false;
                if (parsed.data.supplierId && String(r.supplierId) !== parsed.data.supplierId) return false;
                if (parsed.data.purchaseOrderId && String(r.purchaseOrderId) !== parsed.data.purchaseOrderId) return false;
                if (search) {
                    const name = String(r.supplierName || '').toLowerCase();
                    if (!name.includes(search)) return false;
                }
                return true;
            })
            .sort((a, b) => String(b.receivedAt || b.createdAt || '').localeCompare(String(a.receivedAt || a.createdAt || '')));

        const items = filtered.map((r) => ({
            id: r.id,
            receivedAt: r.receivedAt || r.createdAt,
            createdAt: r.createdAt || null,
            tankId: r.tankId,
            fuelType: r.fuelType,
            tankerNumber: r.tankerNumber,
            supplierId: r.supplierId ?? null,
            supplierName: r.supplierName || null,
            purchaseOrderId: r.purchaseOrderId ?? null,
            invoiceNumber: r.invoiceNumber || null,
            expectedQtyLiters: Number(r.expectedQtyLiters || 0),
            receivedQtyLiters: Number(r.receivedQtyLiters || 0),
            ratePerLiterCents: r.ratePerLiterCents ?? null,
            totalAmountCents: r.totalAmountCents ?? null,
            shortageLiters: Number(r.shortageLiters || 0),
            excessLiters: Number(r.excessLiters || 0),
            deltaLiters: Number(r.deltaLiters || 0),
            thresholdLiters: Number(r.thresholdLiters || 0),
            isDipShort: Boolean(r.isDipShort),
            status: r.status || 'ok',
            dipBeforeMm: r.dipBeforeMm ?? null,
            dipAfterMm: r.dipAfterMm ?? null,
            dipBeforeLiters: r.dipBeforeLiters ?? null,
            dipAfterLiters: r.dipAfterLiters ?? null,
            notes: r.notes ?? null,
            recordedBy: r.recordedBy ?? null,
        }));

        const totals = items.reduce((acc, row) => {
            acc.receiptCount += 1;
            acc.dipShortCount += row.isDipShort ? 1 : 0;
            acc.expectedQtyLiters += row.expectedQtyLiters;
            acc.receivedQtyLiters += row.receivedQtyLiters;
            acc.shortageLiters += row.shortageLiters;
            acc.excessLiters += row.excessLiters;
            return acc;
        }, { receiptCount: 0, dipShortCount: 0, expectedQtyLiters: 0, receivedQtyLiters: 0, shortageLiters: 0, excessLiters: 0 });

        totals.expectedQtyLiters = Math.round(totals.expectedQtyLiters * 1000) / 1000;
        totals.receivedQtyLiters = Math.round(totals.receivedQtyLiters * 1000) / 1000;
        totals.shortageLiters = Math.round(totals.shortageLiters * 1000) / 1000;
        totals.excessLiters = Math.round(totals.excessLiters * 1000) / 1000;

        type Agg = {
            key: string;
            receiptCount: number;
            dipShortCount: number;
            expectedQtyLiters: number;
            receivedQtyLiters: number;
            shortageLiters: number;
        };
        const bump = (map: Map<string, Agg>, key: string, row: typeof items[0]) => {
            const cur = map.get(key) || {
                key,
                receiptCount: 0,
                dipShortCount: 0,
                expectedQtyLiters: 0,
                receivedQtyLiters: 0,
                shortageLiters: 0,
            };
            cur.receiptCount += 1;
            cur.dipShortCount += row.isDipShort ? 1 : 0;
            cur.expectedQtyLiters += row.expectedQtyLiters;
            cur.receivedQtyLiters += row.receivedQtyLiters;
            cur.shortageLiters += row.shortageLiters;
            map.set(key, cur);
        };

        const byTanker = new Map<string, Agg>();
        const bySupplier = new Map<string, Agg>();
        for (const row of items) {
            bump(byTanker, String(row.tankerNumber || '_unknown'), row);
            bump(bySupplier, row.supplierName?.trim() ? String(row.supplierName) : '_no_supplier', row);
        }

        const sortAgg = (a: Agg, b: Agg) => b.receiptCount - a.receiptCount || a.key.localeCompare(b.key);

        return response.success({
            period: { from, to },
            filter: {
                tankId: parsed.data.tankId || null,
                status: parsed.data.status || null,
                fuelType: parsed.data.fuelType || null,
                supplierSearch: parsed.data.supplierSearch || null,
            },
            totals,
            breakdown: {
                byTanker: Array.from(byTanker.values()).sort(sortAgg).map((x) => ({
                    tankerNumber: x.key === '_unknown' ? null : x.key,
                    receiptCount: x.receiptCount,
                    dipShortCount: x.dipShortCount,
                    expectedQtyLiters: Math.round(x.expectedQtyLiters * 1000) / 1000,
                    receivedQtyLiters: Math.round(x.receivedQtyLiters * 1000) / 1000,
                    shortageLiters: Math.round(x.shortageLiters * 1000) / 1000,
                })),
                bySupplier: Array.from(bySupplier.values()).sort(sortAgg).map((x) => ({
                    supplierName: x.key.startsWith('_no') ? null : x.key,
                    receiptCount: x.receiptCount,
                    dipShortCount: x.dipShortCount,
                    expectedQtyLiters: Math.round(x.expectedQtyLiters * 1000) / 1000,
                    receivedQtyLiters: Math.round(x.receivedQtyLiters * 1000) / 1000,
                    shortageLiters: Math.round(x.shortageLiters * 1000) / 1000,
                })),
            },
            items,
        });
    },
    PUMP_REPORT_OPTS,
);

/**
 * GET /pump/reports/atg-readings — ATG probe rows in window (water/temp/leak fields when present)
 */
export const atgReadingsReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(atgReadingsQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const from = parsed.data.from || new Date(Date.now() - 14 * 86400000).toISOString().substring(0, 10);
        const to = parsed.data.to || new Date().toISOString().substring(0, 10);
        if (from > to) return response.badRequest('from must be <= to');

        const alertsOnly = parsed.data.alertsOnly === 'true';
        const rows = await queryAllItems<Record<string, unknown>>(Keys.tenantPK(auth.tenantId), 'TANKATG#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });

        const filtered = rows
            .filter((r) => {
                const d = String((r as { measuredAt?: string }).measuredAt || (r as { createdAt?: string }).createdAt || '').substring(0, 10);
                if (!d || d < from || d > to) return false;
                if (parsed.data.tankId && String((r as { tankId?: string }).tankId) !== parsed.data.tankId) return false;
                if (alertsOnly) {
                    const leak = Boolean((r as { leakDetected?: boolean }).leakDetected);
                    const hi = Boolean((r as { highWaterAlarm?: boolean }).highWaterAlarm);
                    if (!leak && !hi) return false;
                }
                return true;
            })
            .sort((a, b) => String((b as { measuredAt?: string }).measuredAt || '').localeCompare(String((a as { measuredAt?: string }).measuredAt || '')));

        const items = filtered.map((r) => {
            const row = r as Record<string, unknown>;
            return {
                id: row.id,
                tankId: row.tankId,
                fuelType: row.fuelType ?? null,
                measuredAt: row.measuredAt || row.createdAt,
                measuredVolumeLiters: Math.round(Number(row.measuredVolumeLiters || 0) * 1000) / 1000,
                waterLevelMm: row.waterLevelMm != null ? Number(row.waterLevelMm) : null,
                temperatureCelsius: row.temperatureCelsius != null ? Number(row.temperatureCelsius) : null,
                leakDetected: row.leakDetected === true,
                highWaterAlarm: row.highWaterAlarm === true,
                source: row.source || 'atg',
            };
        });

        const totals = items.reduce(
            (acc, row) => {
                acc.readingCount += 1;
                if (row.leakDetected) acc.leakAlarmCount += 1;
                if (row.highWaterAlarm) acc.highWaterAlarmCount += 1;
                return acc;
            },
            { readingCount: 0, leakAlarmCount: 0, highWaterAlarmCount: 0 },
        );

        return response.success({
            period: { from, to },
            filter: { tankId: parsed.data.tankId || null, alertsOnly },
            note: 'Connector still env-gated on POST /pump/atg/ingest; this report reads stored TANKATG# rows',
            totals,
            items,
        });
    },
    PUMP_REPORT_OPTS,
);

export const rateVariationReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(rateVariationQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const from = parsed.data.from || new Date(Date.now() - 90 * 86400000).toISOString().substring(0, 10);
        const to = parsed.data.to || new Date().toISOString().substring(0, 10);
        if (from > to) return response.badRequest('from must be <= to');

        const pk = Keys.tenantPK(auth.tenantId);
        const logs = await queryAllItems<Record<string, any>>(pk, 'FUELPRICELOG#', { maxPages: 40 });
        const invoices = await queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
            filterExpression: '#t = :sale AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeNames: { '#t': 'type' },
            expressionAttributeValues: { ':sale': 'sale', ':false': false },
            maxPages: 40,
        });

        const tankStockRows = await queryAllItems<Record<string, unknown>>(pk, 'TANKDIP#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });
        const atgRowsAll = await queryAllItems<Record<string, unknown>>(pk, 'TANKATG#', { maxPages: 40 });
        const latestByTankAsOfEnd = buildLatestTankVolumesByTank(tankStockRows, atgRowsAll, to);

        const filteredLogs = logs
            .filter((l) => {
                const fuelType = String(l.fuelType || '');
                if (parsed.data.fuelType && fuelType !== parsed.data.fuelType) return false;
                const d = String(l.effectiveFrom || l.createdAt || '').substring(0, 10);
                return !!d && d >= from && d <= to;
            })
            .sort((a, b) => String(a.effectiveFrom || a.createdAt || '').localeCompare(String(b.effectiveFrom || b.createdAt || '')));

        const saleRows = invoices.filter((inv) => {
            const fuelType = String(inv.fuelType || inv.productType || inv.metadata?.productType || '');
            if (!fuelType) return false;
            if (parsed.data.fuelType && fuelType !== parsed.data.fuelType) return false;
            const d = String(inv.saleDate || (inv.createdAt ? inv.createdAt.substring(0, 10) : ''));
            return !!d && d >= from && d <= to;
        });

        const items = filteredLogs.map((l) => {
            const fuelType = String(l.fuelType || 'unknown');
            const effectiveFrom = String(l.effectiveFrom || l.createdAt || '');
            const prev = Number(l.previousPriceCents || 0);
            const next = Number(l.newPriceCents || 0);
            const deltaCents = next - prev;

            const impacted = saleRows.filter((s) => {
                const sf = String(s.fuelType || s.productType || s.metadata?.productType || '');
                if (sf !== fuelType) return false;
                const sd = String(s.saleDate || (s.createdAt ? s.createdAt.substring(0, 10) : ''));
                return sd >= effectiveFrom.substring(0, 10) && sd <= to;
            });
            const impactedVolumeLiters = impacted.reduce((acc, s) => acc + Number(s.volumeLiters || 0), 0);
            const estimatedValueImpactCents = Math.round(impactedVolumeLiters * deltaCents);

            const persistedStockHoldLiters = l.stockHoldLitersAtChange != null ? Number(l.stockHoldLitersAtChange) : null;
            const persistedStockHoldImpact = l.stockHoldInventoryImpactCentsAtChange != null ? Number(l.stockHoldInventoryImpactCentsAtChange) : null;
            const stockHoldLitersRaw = persistedStockHoldLiters != null
                ? persistedStockHoldLiters
                : sumStockLitersForFuel(latestByTankAsOfEnd, fuelType);
            const stockHoldLiters = Math.round(stockHoldLitersRaw * 1000) / 1000;
            const stockHoldInventoryImpactCents = persistedStockHoldImpact != null
                ? persistedStockHoldImpact
                : Math.round(stockHoldLitersRaw * deltaCents);

            return {
                id: l.id,
                fuelType,
                effectiveFrom,
                previousPriceCents: prev,
                newPriceCents: next,
                deltaCents,
                direction: deltaCents > 0 ? 'increase' : (deltaCents < 0 ? 'decrease' : 'no_change'),
                impactedVolumeLiters: Math.round(impactedVolumeLiters * 1000) / 1000,
                estimatedValueImpactCents,
                stockHoldLiters,
                stockHoldInventoryImpactCents,
                stockHoldSource: persistedStockHoldLiters != null ? 'persisted_at_change' : 'computed_from_period_end_snapshot',
                reason: l.reason || null,
                changedBy: l.changedBy || null,
            };
        });

        const totals = items.reduce((acc, i) => {
            acc.changeCount += 1;
            acc.netDeltaCents += i.deltaCents;
            acc.totalImpactedVolumeLiters += i.impactedVolumeLiters;
            acc.totalEstimatedValueImpactCents += i.estimatedValueImpactCents;
            acc.totalStockHoldInventoryImpactCents += i.stockHoldInventoryImpactCents;
            if (i.deltaCents > 0) acc.increaseCount += 1;
            else if (i.deltaCents < 0) acc.decreaseCount += 1;
            return acc;
        }, {
            changeCount: 0,
            increaseCount: 0,
            decreaseCount: 0,
            netDeltaCents: 0,
            totalImpactedVolumeLiters: 0,
            totalEstimatedValueImpactCents: 0,
            totalStockHoldInventoryImpactCents: 0,
        });
        totals.totalImpactedVolumeLiters = Math.round(totals.totalImpactedVolumeLiters * 1000) / 1000;

        return response.success({
            period: { from, to },
            filter: { fuelType: parsed.data.fuelType || null },
            stockHoldNote: 'stockHoldLiters uses latest tank dip/ATG per tank on or before period `to` — inventory revaluation estimate at each change',
            totals,
            items,
        });
    },
    PUMP_REPORT_OPTS,
);

export const stockValuationReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(stockValuationQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const from = parsed.data.from || new Date(Date.now() - 30 * 86400000).toISOString().substring(0, 10);
        const to = parsed.data.to || new Date().toISOString().substring(0, 10);
        if (from > to) return response.badRequest('from must be <= to');

        const method = parsed.data.method;
        const densityFactor = parsed.data.densityFactor ?? 0.99;
        const pk = Keys.tenantPK(auth.tenantId);

        const tankStockRows = await queryAllItems<Record<string, any>>(pk, 'TANKDIP#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });
        const atgRows = await queryAllItems<Record<string, any>>(pk, 'TANKATG#', { maxPages: 40 });
        const products = await queryAllItems<Record<string, any>>(pk, 'PRODUCT#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 20,
        });
        const tankerReceipts = await queryAllItems<Record<string, any>>(pk, 'TANKERRECEIPT#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });
        const densityRows = await queryAllItems<Record<string, unknown>>(pk, 'DENSITY#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });

        const productByFuel = new Map<string, Record<string, any>>();
        for (const p of products) {
            const fuel = String(p.productType || '').toLowerCase();
            if (fuel && !productByFuel.has(fuel)) productByFuel.set(fuel, p);
        }

        const latestByTank = new Map<string, {
            tankId: string;
            fuelType: string;
            volumeLiters: number;
            asOf: string;
        }>();

        for (const d of tankStockRows) {
            const day = String(d.recordedAt || d.createdAt || '').substring(0, 10);
            if (!day || day < from || day > to) continue;
            const tankId = String(d.tankId || 'unknown');
            const asOf = String(d.recordedAt || d.createdAt || '');
            const prev = latestByTank.get(tankId);
            if (!prev || asOf > prev.asOf) {
                latestByTank.set(tankId, {
                    tankId,
                    fuelType: String(d.fuelType || 'unknown'),
                    volumeLiters: Number(d.observedVolumeLiters || 0),
                    asOf,
                });
            }
        }
        for (const a of atgRows) {
            const day = String(a.measuredAt || a.createdAt || '').substring(0, 10);
            if (!day || day < from || day > to) continue;
            const tankId = String(a.tankId || 'unknown');
            const asOf = String(a.measuredAt || a.createdAt || '');
            const prev = latestByTank.get(tankId);
            if (!prev || asOf > prev.asOf) {
                latestByTank.set(tankId, {
                    tankId,
                    fuelType: String(a.fuelType || prev?.fuelType || 'unknown'),
                    volumeLiters: Number(a.measuredVolumeLiters || 0),
                    asOf,
                });
            }
        }

        const fifoCostByFuel = new Map<string, number>();
        const receiptBuckets = new Map<string, Array<{ receivedAt: string; unitCostCents: number }>>();
        for (const r of tankerReceipts) {
            const day = String(r.receivedAt || r.createdAt || '').substring(0, 10);
            if (!day || day > to) continue;
            const fuel = String(r.fuelType || 'unknown');
            const qty = Number(r.receivedQtyLiters || 0);
            if (qty <= 0) continue;
            const totalCostCents = Number(r.totalCostCents || r.totalAmountCents || 0);
            const unitCostCents = totalCostCents > 0 ? (totalCostCents / qty) : Number(r.unitCostCents || 0);
            if (unitCostCents <= 0) continue;
            const arr = receiptBuckets.get(fuel) || [];
            arr.push({ receivedAt: String(r.receivedAt || r.createdAt || ''), unitCostCents });
            receiptBuckets.set(fuel, arr);
        }
        for (const [fuel, arr] of receiptBuckets.entries()) {
            arr.sort((a, b) => a.receivedAt.localeCompare(b.receivedAt));
            fifoCostByFuel.set(fuel, arr[arr.length - 1].unitCostCents);
        }

        const items: Array<Record<string, any>> = [];
        for (const tank of latestByTank.values()) {
            const fuelType = tank.fuelType.toLowerCase();
            if (parsed.data.fuelType && fuelType !== parsed.data.fuelType) continue;
            const product = productByFuel.get(fuelType);
            const saleRateCents = Number(product?.salePriceCents || 0);
            const purchaseRateCents = Number(product?.purchasePriceCents || 0);
            const fifoRateCents = Number(fifoCostByFuel.get(fuelType) || purchaseRateCents || 0);

            let unitRateCents = fifoRateCents;
            if (method === 'purchase_rate') unitRateCents = purchaseRateCents;
            if (method === 'sale_rate') unitRateCents = saleRateCents;

            let ppmPayload: Record<string, unknown> | null = null;
            if (method === 'density_adjusted') {
                const ppmScale = parsed.data.ppmScale ?? 50_000;
                const ppmFloor = parsed.data.ppmFloor ?? 0.85;
                const ppmSample = latestPpmForTank(densityRows, tank.tankId, to);
                let ppmMultiplier = 1;
                if (ppmSample) {
                    ppmMultiplier = Math.max(ppmFloor, 1 - ppmSample.ppmValue / ppmScale);
                    ppmPayload = {
                        ppmValue: ppmSample.ppmValue,
                        measuredAt: ppmSample.measuredAt,
                        ppmMultiplier: Math.round(ppmMultiplier * 1_000_000) / 1_000_000,
                        ppmScale,
                        ppmFloor,
                    };
                }
                unitRateCents = Math.round(fifoRateCents * densityFactor * ppmMultiplier);
            }

            const valuationCents = Math.round(Number(tank.volumeLiters || 0) * Number(unitRateCents || 0));
            items.push({
                tankId: tank.tankId,
                fuelType,
                asOf: tank.asOf,
                volumeLiters: Math.round(tank.volumeLiters * 1000) / 1000,
                unitRateCents,
                valuationCents,
                method,
                referenceRates: {
                    fifoRateCents,
                    purchaseRateCents,
                    saleRateCents,
                },
                ...(ppmPayload ? { ppm: ppmPayload } : {}),
            });
        }

        items.sort((a, b) => String(a.tankId).localeCompare(String(b.tankId)));
        const totals = items.reduce((acc, i) => {
            acc.tankCount += 1;
            acc.totalVolumeLiters += Number(i.volumeLiters || 0);
            acc.totalValuationCents += Number(i.valuationCents || 0);
            return acc;
        }, { tankCount: 0, totalVolumeLiters: 0, totalValuationCents: 0 });
        totals.totalVolumeLiters = Math.round(totals.totalVolumeLiters * 1000) / 1000;

        return response.success({
            period: { from, to },
            method,
            densityFactor: method === 'density_adjusted' ? densityFactor : null,
            densityPpmNote: method === 'density_adjusted'
                ? 'unitRate = fifoRate × densityFactor × ppmMultiplier; ppmMultiplier = max(ppmFloor, 1 − ppm/ppmScale) from latest DENSITY# row per tank on/before `to`, else multiplier 1'
                : null,
            ppmParams: method === 'density_adjusted'
                ? { ppmScale: parsed.data.ppmScale ?? 50_000, ppmFloor: parsed.data.ppmFloor ?? 0.85 }
                : null,
            filter: { fuelType: parsed.data.fuelType || null },
            totals,
            items,
        });
    },
    PUMP_REPORT_OPTS,
);
