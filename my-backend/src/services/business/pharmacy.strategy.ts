// ============================================================================
// Pharmacy Strategy — Full-Featured Dashboard (DynamoDB)
// ============================================================================

import { Keys, queryItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class PharmacyStrategy extends BaseStrategy {

    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const baseSections = await super.getDashboardSections(tenantId);
        const pharmacySections: DashboardSection[] = [
            { id: 'near_expiry_medicines', title: '⚠️ Near-Expiry Medicines (Next 90 Days)', type: 'alert', data: await this.getNearExpiryMedicines(tenantId) },
            { id: 'expired_medicines', title: '🚫 Expired Medicines (Requires Action)', type: 'alert', data: await this.getExpiredMedicines(tenantId) },
            { id: 'batch_stock', title: 'Batch-Wise Stock Status', type: 'table', data: await this.getBatchWiseStock(tenantId) },
            { id: 'drug_schedule_compliance', title: 'Drug Schedule Compliance', type: 'table', data: await this.getDrugScheduleCompliance(tenantId) },
            { id: 'prescription_sales', title: 'Prescription-Linked Sales (Today)', type: 'table', data: await this.getPrescriptionSales(tenantId) },
            { id: 'controlled_substances', title: 'Controlled Substance Register', type: 'table', data: await this.getControlledSubstanceRegister(tenantId) },
            { id: 'supplier_purchase', title: 'Supplier Drug-wise Purchase Summary', type: 'table', data: await this.getSupplierPurchaseSummary(tenantId) },
            { id: 'rack_stock', title: 'Rack/Location Wise Stock', type: 'table', data: await this.getRackWiseStock(tenantId) },
            { id: 'return_analysis', title: 'Monthly Return Analysis', type: 'chart', data: await this.getReturnAnalysis(tenantId) },
        ];
        return [...pharmacySections, ...baseSections];
    }

    private async getNearExpiryMedicines(tenantId: string) {
        const now = new Date();
        const ninetyDaysLater = new Date(now.getTime() + 90 * 86400000).toISOString();
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'MEDBATCH#', {
            filterExpression: 'currentQty > :zero AND expiryDate <= :expiry AND expiryDate >= :now',
            expressionAttributeValues: { ':zero': 0, ':expiry': ninetyDaysLater, ':now': now.toISOString() },
        });
        return r.items.sort((a, b) => (a.expiryDate || '').localeCompare(b.expiryDate || ''));
    }

    private async getExpiredMedicines(tenantId: string) {
        const now = new Date().toISOString();
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'MEDBATCH#', {
            filterExpression: 'currentQty > :zero AND expiryDate < :now',
            expressionAttributeValues: { ':zero': 0, ':now': now },
        });
        return r.items;
    }

    private async getBatchWiseStock(tenantId: string) {
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'MEDBATCH#', {
            filterExpression: 'currentQty > :zero',
            expressionAttributeValues: { ':zero': 0 },
            limit: 100,
        });
        return r.items;
    }

    private async getDrugScheduleCompliance(tenantId: string) {
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: 'productType = :medicine AND isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':medicine': 'medicine', ':true': true, ':false': false },
        });
        // Group by drugSchedule
        const bySchedule: Record<string, { total: number; requiresRx: number; stock: number }> = {};
        for (const p of r.items) {
            const sched = p.attributes?.drugSchedule || 'Unknown';
            if (!bySchedule[sched]) bySchedule[sched] = { total: 0, requiresRx: 0, stock: 0 };
            bySchedule[sched].total++;
            if (p.attributes?.requiresPrescription === 'true' || p.attributes?.requiresPrescription === true) bySchedule[sched].requiresRx++;
            bySchedule[sched].stock += Number(p.currentStock || 0);
        }
        return Object.entries(bySchedule).map(([drug_schedule, data]) => ({ drug_schedule, total_products: data.total, requires_prescription: data.requiresRx, total_stock: data.stock }));
    }

    private async getPrescriptionSales(tenantId: string) {
        const today = new Date().toISOString().substring(0, 10);
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INVOICE#', {
            filterExpression: 'begins_with(createdAt, :today)',
            expressionAttributeValues: { ':today': today },
            limit: 20,
        });
        return r.items.map(t => ({ ...t, has_prescription: !!t.metadata?.prescriptionId }));
    }

    private async getControlledSubstanceRegister(tenantId: string) {
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: 'productType = :medicine AND isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':medicine': 'medicine', ':true': true, ':false': false },
        });
        const controlled = r.items.filter(p => ['H', 'H1', 'X'].includes(p.attributes?.drugSchedule));
        return controlled.map(p => ({ drug_name: p.name, schedule: p.attributes?.drugSchedule, current_stock: p.currentStock, unit: p.unit }));
    }

    private async getSupplierPurchaseSummary(tenantId: string) {
        const ninetyDaysAgo = new Date(Date.now() - 90 * 86400000).toISOString();
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PURCHASEORDER#', {
            filterExpression: 'orderDate >= :since',
            expressionAttributeValues: { ':since': ninetyDaysAgo },
        });
        // Group by vendor
        const byVendor: Record<string, { orders: number; total: number; lastDate: string }> = {};
        for (const po of r.items) {
            const v = po.vendorName || 'Unknown';
            if (!byVendor[v]) byVendor[v] = { orders: 0, total: 0, lastDate: '' };
            byVendor[v].orders++;
            byVendor[v].total += Number(po.totalCents || 0);
            if (po.orderDate > byVendor[v].lastDate) byVendor[v].lastDate = po.orderDate;
        }
        return Object.entries(byVendor).map(([supplier_name, data]) => ({ supplier_name, total_orders: data.orders, total_purchase_cents: data.total, last_order_date: data.lastDate }));
    }

    private async getRackWiseStock(tenantId: string) {
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: 'productType = :medicine AND isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':medicine': 'medicine', ':true': true, ':false': false },
        });
        const byRack: Record<string, { count: number; stock: number; value: number }> = {};
        for (const p of r.items) {
            const rack = p.attributes?.rackLocation || 'Unassigned';
            if (!byRack[rack]) byRack[rack] = { count: 0, stock: 0, value: 0 };
            byRack[rack].count++;
            byRack[rack].stock += Number(p.currentStock || 0);
            byRack[rack].value += Number(p.currentStock || 0) * Number(p.salePriceCents || 0);
        }
        return Object.entries(byRack).map(([rack, data]) => ({ rack_location: rack, product_count: data.count, total_stock: data.stock, stock_value_cents: data.value }));
    }

    private async getReturnAnalysis(tenantId: string) {
        const sixMonthsAgo = new Date(Date.now() - 180 * 86400000).toISOString();
        const r = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'RETURN#', {
            filterExpression: 'returnDate >= :since',
            expressionAttributeValues: { ':since': sixMonthsAgo },
        });
        // Group by month
        const byMonth: Record<string, { count: number; amount: number; reasons: Set<string> }> = {};
        for (const ret of r.items) {
            const month = (ret.returnDate || '').substring(0, 7);
            if (!byMonth[month]) byMonth[month] = { count: 0, amount: 0, reasons: new Set() };
            byMonth[month].count++;
            byMonth[month].amount += Number(ret.amountCents || 0);
            if (ret.reason) byMonth[month].reasons.add(ret.reason);
        }
        return Object.entries(byMonth).map(([month, data]) => ({ month, return_count: data.count, return_amount_cents: data.amount, reasons: Array.from(data.reasons).join(', ') })).sort((a, b) => b.month.localeCompare(a.month));
    }
}
