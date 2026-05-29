// ============================================================================
// Base Business Strategy — Default Dashboard Sections (DynamoDB)
// ============================================================================
// AUDIT FIXES APPLIED:
//   M-3: getTopSellers now fetches and aggregates line-item data
//   Performance: getLowStockAlerts uses DynamoDB filter server-side
// ============================================================================

import { Keys, queryItems, queryAllItems, batchGetItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';

export class BaseStrategy {

    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const sections: DashboardSection[] = [];
        sections.push({ id: 'low_stock', title: 'Low Stock Alerts', type: 'alert', data: await this.getLowStockAlerts(tenantId) });
        sections.push({ id: 'top_sellers', title: 'Top Selling Products', type: 'table', data: await this.getTopSellers(tenantId) });
        sections.push({ id: 'recent_sales', title: 'Recent Sales', type: 'table', data: await this.getRecentSales(tenantId) });
        sections.push({ id: 'revenue_trend', title: 'Revenue Trend (7 Days)', type: 'chart', data: await this.getRevenueTrend(tenantId) });
        return sections;
    }

    protected async getLowStockAlerts(tenantId: string) {
        // Optimized: DynamoDB filter expression handles threshold comparison server-side
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: 'isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND currentStock <= lowStockThreshold',
            expressionAttributeValues: { ':true': true, ':false': false },
            limit: 20,
        });
        return result.items
            .slice(0, 10)
            .map(p => ({
                id: p.id, name: p.name,
                current_stock: p.currentStock,
                low_stock_threshold: p.lowStockThreshold,
                unit: p.unit,
                is_out_of_stock: (p.currentStock || 0) <= 0,
            }));
    }

    /**
     * M-3 FIX: Get actual top-selling products by aggregating line item data.
     * Fetches recent invoices, then batch-fetches their line items to aggregate
     * real product-level sales data.
     */
    protected async getTopSellers(tenantId: string) {
        const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString();

        // Get recent invoices (limited for performance)
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INVOICE#', {
            filterExpression: 'createdAt >= :since AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND #s <> :voided',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':since': thirtyDaysAgo, ':false': false, ':voided': 'voided' },
            limit: 100, // Cap at 100 recent invoices for performance
        });

        if (result.items.length === 0) {
            return [];
        }

        // Batch fetch line items for these invoices (max 10 concurrent)
        const productSales: Record<string, { name: string; saleCount: number; totalRevenueCents: number; totalQty: number }> = {};

        const invoiceIds = result.items.map(inv => inv.id);
        const BATCH = 10;
        for (let i = 0; i < invoiceIds.length; i += BATCH) {
            const batch = invoiceIds.slice(i, i + BATCH);
            const lineItemPromises = batch.map(invId =>
                queryItems<Record<string, any>>(
                    `INVOICE#${invId}`, 'LINEITEM#', { limit: 50 }
                )
            );
            const lineItemResults = await Promise.all(lineItemPromises);

            for (const liResult of lineItemResults) {
                for (const li of liResult.items) {
                    const key = li.itemId || li.name || 'unknown';
                    if (!productSales[key]) {
                        productSales[key] = { name: li.name || key, saleCount: 0, totalRevenueCents: 0, totalQty: 0 };
                    }
                    productSales[key].saleCount += 1;
                    productSales[key].totalRevenueCents += Number(li.totalCents || 0);
                    productSales[key].totalQty += Number(li.quantity || 0);
                }
            }
        }

        // Sort by total revenue descending, return top 10
        return Object.values(productSales)
            .sort((a, b) => b.totalRevenueCents - a.totalRevenueCents)
            .slice(0, 10)
            .map(p => ({
                name: p.name,
                sale_count: p.saleCount,
                total_revenue_cents: p.totalRevenueCents,
                total_quantity: p.totalQty,
            }));
    }

    protected async getRecentSales(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INVOICE#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND #s <> :voided',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':false': false, ':voided': 'voided' },
            limit: 30,
        });
        return result.items
            .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
            .slice(0, 15)
            .map(inv => ({
                id: inv.id, invoice_number: inv.invoiceNumber,
                customer_name: inv.customerName,
                total_cents: inv.totalCents, payment_mode: inv.paymentMode,
                status: inv.status, created_at: inv.createdAt,
            }));
    }

    protected async getRevenueTrend(tenantId: string) {
        const sevenDaysAgo = new Date(Date.now() - 6 * 86400000).toISOString();
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INVOICE#', {
            filterExpression: 'createdAt >= :since AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND #s <> :voided',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':since': sevenDaysAgo, ':false': false, ':voided': 'voided' },
        });
        // Group by date
        const byDate: Record<string, { revenue: number; count: number }> = {};
        for (let i = 0; i < 7; i++) {
            const d = new Date(Date.now() - (6 - i) * 86400000).toISOString().substring(0, 10);
            byDate[d] = { revenue: 0, count: 0 };
        }
        for (const inv of result.items) {
            const d = (inv.createdAt || '').substring(0, 10);
            if (byDate[d]) { byDate[d].revenue += Number(inv.totalCents || 0); byDate[d].count++; }
        }
        return Object.entries(byDate).map(([date, data]) => ({ date, revenue_cents: data.revenue, transaction_count: data.count }));
    }
}
