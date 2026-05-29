// ============================================================================
// Petrol Pump Strategy — Full-Featured Dashboard (DynamoDB)
// ============================================================================
// Aligned to the SK prefixes that pump handlers actually write:
//   FUELTANK#         (tank master)
//   NOZZLEREADING#    (with readingDate field)
//   SHIFT#            (shiftDate field)
//   PRODUCT#          (lubes filtered by category)
//   CASHSETTLEMENT#   (renamed from cash deposit; keep CASHDEPOSIT# fallback)
//   INVOICE#          (fuel sales — joined to PRODUCT for fuelType resolution)
//   FUELPRICELOG#     (price history)
//   LOSSENTRY#        (evaporation/handling losses)
//   FIVELITRE#        (5-litre test records)
// ============================================================================

import { Keys, queryItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class PetrolPumpStrategy extends BaseStrategy {

    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const baseSections = await super.getDashboardSections(tenantId);
        const pumpSections: DashboardSection[] = [
            { id: 'fuel_tank_levels', title: 'Fuel Tank Status', type: 'metric', data: await this.getFuelTankLevels(tenantId) },
            { id: 'nozzle_sales_today', title: "Today's Nozzle Sales", type: 'table', data: await this.getNozzleSalesToday(tenantId) },
            { id: 'shift_summary', title: 'Current Shift Summary', type: 'metric', data: await this.getShiftSummary(tenantId) },
            { id: 'lube_stock', title: 'Lube & Oil Stock', type: 'table', data: await this.getLubeStock(tenantId) },
            { id: 'cash_settlement_summary', title: 'Cash Settlement Summary', type: 'table', data: await this.getCashSettlementSummary(tenantId) },
            { id: 'gst_petrol_sale', title: 'GST-wise Fuel Sale Report', type: 'table', data: await this.getGstWiseFuelSale(tenantId) },
            { id: 'evaporation_loss', title: 'Evaporation / Handling Loss', type: 'table', data: await this.getEvaporationLoss(tenantId) },
            { id: 'five_litre_tests', title: '5-Litre Test Records', type: 'table', data: await this.getFiveLitreTests(tenantId) },
            { id: 'daily_fuel_price', title: 'Daily Fuel Price Trend', type: 'chart', data: await this.getDailyFuelPriceChart(tenantId) },
        ];
        return [...pumpSections, ...baseSections];
    }

    private async getFuelTankLevels(tenantId: string) {
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'FUELTANK#');
        return r.items.map(ft => {
            const cap = Number(ft.capacityLitres ?? ft.capacityLiters ?? 0);
            const cur = Number(ft.currentStockLitres ?? ft.currentStockLiters ?? 0);
            return {
                ...ft,
                fill_percentage: cap > 0 ? Math.round((cur / cap) * 100 * 10) / 10 : 0,
                is_low: cap > 0 && cur < (Number(ft.lowStockThresholdLitres ?? cap * 0.2)),
            };
        });
    }

    private async getNozzleSalesToday(tenantId: string) {
        const today = new Date().toISOString().substring(0, 10);
        // NOZZLEREADING# now writes both readingDate (YYYY-MM-DD) and createdAt;
        // filter on either for backward-compat with older rows.
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'NOZZLEREADING#', {
            filterExpression: 'begins_with(readingDate, :today) OR begins_with(createdAt, :today)',
            expressionAttributeValues: { ':today': today },
        });
        return r.items;
    }

    private async getShiftSummary(tenantId: string) {
        const today = new Date().toISOString().substring(0, 10);
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'SHIFT#', {
            filterExpression: 'begins_with(shiftDate, :today)',
            expressionAttributeValues: { ':today': today },
        });
        return r.items;
    }

    private async getLubeStock(tenantId: string) {
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: 'category IN (:lube, :oil, :lub, :cool) AND isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':lube': 'lube', ':oil': 'oil', ':lub': 'lubricant', ':cool': 'coolant', ':true': true, ':false': false },
        });
        return r.items.map(i => ({ ...i, is_low: (i.currentStock || 0) <= (i.lowStockThreshold || 5) }));
    }

    private async getCashSettlementSummary(tenantId: string) {
        const sevenDaysAgo = new Date(Date.now() - 7 * 86400000).toISOString();
        // Pump handlers write CASHSETTLEMENT#; older code wrote CASHDEPOSIT#.
        const [a, b] = await Promise.all([
            queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'CASHSETTLEMENT#', {
                filterExpression: 'submittedAt >= :since OR createdAt >= :since',
                expressionAttributeValues: { ':since': sevenDaysAgo },
            }),
            queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'CASHDEPOSIT#', {
                filterExpression: 'depositDate >= :since OR createdAt >= :since',
                expressionAttributeValues: { ':since': sevenDaysAgo },
            }),
        ]);
        return [...a.items, ...b.items];
    }

    private async getGstWiseFuelSale(tenantId: string) {
        const monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString();
        // Fuel sales are stored as INVOICE# rows by recordPumpSale.
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INVOICE#', {
            filterExpression: 'createdAt >= :since AND #t = :sale AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeNames: { '#t': 'type' },
            expressionAttributeValues: { ':since': monthStart, ':sale': 'sale', ':false': false },
        });
        // Bucket by fuelType inferred from line items / metadata when present.
        const byType: Record<string, { litres: number; amount: number; cgst: number; sgst: number }> = {};
        for (const s of r.items) {
            const ft = (s.fuelType || s.metadata?.fuelType || 'unknown').toString();
            if (!byType[ft]) byType[ft] = { litres: 0, amount: 0, cgst: 0, sgst: 0 };
            byType[ft].litres += Number(s.netSaleLitres || s.volumeLiters || 0);
            byType[ft].amount += Number(s.totalCents || 0);
            byType[ft].cgst += Number(s.cgstCents || 0);
            byType[ft].sgst += Number(s.sgstCents || 0);
        }
        return Object.entries(byType).map(([fuel_type, data]) => ({ fuel_type, ...data }));
    }

    private async getEvaporationLoss(tenantId: string) {
        const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString();
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'LOSSENTRY#', {
            filterExpression: 'lossDate >= :since OR createdAt >= :since',
            expressionAttributeValues: { ':since': thirtyDaysAgo },
        });
        return r.items;
    }

    private async getFiveLitreTests(tenantId: string) {
        const ninetyDaysAgo = new Date(Date.now() - 90 * 86400000).toISOString();
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'FIVELITRE#', {
            filterExpression: 'testDate >= :since OR createdAt >= :since',
            expressionAttributeValues: { ':since': ninetyDaysAgo },
        });
        return r.items.map(t => ({ ...t, result: Math.abs(t.varianceMl || 0) <= 25 ? 'PASS' : 'FAIL' }));
    }

    private async getDailyFuelPriceChart(tenantId: string) {
        const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString();
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'FUELPRICELOG#', {
            filterExpression: 'effectiveFrom >= :since OR createdAt >= :since',
            expressionAttributeValues: { ':since': thirtyDaysAgo },
        });
        return r.items.sort((a, b) => (a.effectiveFrom || a.createdAt || '').localeCompare(b.effectiveFrom || b.createdAt || ''));
    }
}
