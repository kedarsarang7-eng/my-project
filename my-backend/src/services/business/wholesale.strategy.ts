// ============================================================================
// Wholesale Business Strategy — Dashboard Sections (DynamoDB)
// ============================================================================

import { Keys, queryAllItems, queryItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class WholesaleStrategy extends BaseStrategy {
    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const sections = await super.getDashboardSections(tenantId);

        const [bulkSummary, pricingCoverage, pendingPurchaseOrders, creditExposure] = await Promise.all([
            this.getBulkSummary(tenantId),
            this.getPricingCoverage(tenantId),
            this.getPendingPurchaseOrders(tenantId),
            this.getCreditExposure(tenantId),
        ]);

        sections.unshift({
            id: 'wholesale_bulk_summary',
            title: 'Bulk Pricing Summary',
            type: 'metric',
            data: bulkSummary,
        });

        sections.unshift({
            id: 'wholesale_credit_exposure',
            title: 'Credit Exposure',
            type: 'alert',
            data: creditExposure,
        });

        sections.push({
            id: 'wholesale_pricing_coverage',
            title: 'Wholesale Pricing Coverage',
            type: 'table',
            data: pricingCoverage,
        });

        sections.push({
            id: 'wholesale_purchase_orders',
            title: 'Pending Purchase Orders',
            type: 'table',
            data: pendingPurchaseOrders,
        });

        return sections;
    }

    private async getBulkSummary(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: 'isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':true': true, ':false': false },
        });

        let wholesalePriced = 0;
        let tieredPricing = 0;
        let totalStock = 0;

        for (const product of result.items) {
            totalStock += Number(product.currentStock || 0);
            if (Number(product.wholesalePriceCents || 0) > 0) wholesalePriced++;
            if (Array.isArray(product.pricingTiers) && product.pricingTiers.length > 0) tieredPricing++;
        }

        return {
            total_products: result.items.length,
            wholesale_priced_products: wholesalePriced,
            tiered_pricing_products: tieredPricing,
            total_stock: totalStock,
        };
    }

    private async getPricingCoverage(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: 'isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':true': true, ':false': false },
        });

        return result.items
            .filter(p => Number(p.wholesalePriceCents || 0) > 0 || (Array.isArray(p.pricingTiers) && p.pricingTiers.length > 0))
            .slice(0, 10)
            .map(p => ({
                id: p.id,
                name: p.name,
                mrp_cents: Number(p.mrpCents || 0),
                wholesale_price_cents: Number(p.wholesalePriceCents || 0),
                pricing_tiers: Array.isArray(p.pricingTiers) ? p.pricingTiers.length : 0,
                current_stock: Number(p.currentStock || 0),
            }));
    }

    private async getPendingPurchaseOrders(tenantId: string) {
        const allPOs = await queryAllItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PURCHASEORDER#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND (#st = :pending OR attribute_not_exists(#st))',
            expressionAttributeNames: { '#st': 'status' },
            expressionAttributeValues: { ':false': false, ':pending': 'pending' },
        });

        return allPOs
            .sort((a, b) => (b.orderDate || '').localeCompare(a.orderDate || ''))
            .slice(0, 10)
            .map(po => ({
                id: po.id,
                vendor_name: po.vendorName || 'Unknown',
                order_date: po.orderDate,
                status: po.status || 'pending',
                total_cents: Number(po.totalCents || 0),
                due_date: po.dueDate || null,
            }));
    }

    private async getCreditExposure(tenantId: string) {
        // Use queryAllItems (paginated) so ALL open invoices are counted —
        // a limit:100 cap would understate credit exposure for active distributors.
        const invoices = await queryAllItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INVOICE#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND #s <> :voided',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':false': false, ':voided': 'voided' },
        });

        let outstanding = 0;
        let dueSoon = 0;
        const cutoff = Date.now() + 7 * 86400000;

        for (const inv of invoices) {
            const balance = Math.max(Number(inv.totalCents || 0) - Number(inv.paidCents || 0), 0);
            outstanding += balance;
            const dueDate = inv.dueDate ? Date.parse(inv.dueDate) : NaN;
            if (balance > 0 && !Number.isNaN(dueDate) && dueDate <= cutoff) dueSoon += balance;
        }

        return {
            outstanding_cents: outstanding,
            due_soon_cents: dueSoon,
            invoice_count: invoices.length,
        };
    }
}