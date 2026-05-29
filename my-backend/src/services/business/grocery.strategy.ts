// ============================================================================
// Grocery Business Strategy — Dashboard Sections (DynamoDB)
// ============================================================================
// AUDIT: Created grocery-specific dashboard strategy.
// Previously, grocery tenants fell through to BaseStrategy,
// missing critical sections: expiring items, dead stock, margin alerts.
//
// Extends BaseStrategy (inherits low stock, top sellers, recent sales, revenue).
// Adds grocery-specific sections on top.
// ============================================================================

import { Keys, queryItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class GroceryStrategy extends BaseStrategy {

    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        // Get base sections (low stock, top sellers, recent sales, revenue)
        const sections = await super.getDashboardSections(tenantId);

        // Add grocery-specific sections
        const [expiringSoon, deadStock, marginAlerts] = await Promise.all([
            this.getExpiringSoon(tenantId),
            this.getDeadStock(tenantId),
            this.getMarginAlerts(tenantId),
        ]);

        // Insert expiry alerts at the top (most urgent for grocery)
        sections.unshift({
            id: 'expiring_soon',
            title: '⚠️ Expiring Soon (7 days)',
            type: 'alert',
            data: expiringSoon,
        });

        // Add dead stock after low stock
        sections.push({
            id: 'dead_stock',
            title: '📦 Dead Stock (No sales in 90 days)',
            type: 'table',
            data: deadStock,
        });

        // Add margin alerts
        sections.push({
            id: 'margin_alerts',
            title: '📉 Negative Margin Items',
            type: 'alert',
            data: marginAlerts,
        });

        return sections;
    }

    /**
     * Products expiring within 7 days — critical for grocery.
     * FSSAI requires removal of expired food from shelves.
     */
    private async getExpiringSoon(tenantId: string) {
        const now = new Date();
        const todayStr = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-${String(now.getUTCDate()).padStart(2, '0')}`;
        const sevenDays = new Date(
            Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 7),
        );
        const sevenDayStr = sevenDays.toISOString().split('T')[0];

        const result = await queryItems<Record<string, any>>(
            Keys.tenantPK(tenantId),
            'PRODUCT#',
            {
                filterExpression:
                    'attribute_exists(expiryDate) AND expiryDate <= :threshold ' +
                    'AND expiryDate >= :today ' +
                    'AND (attribute_not_exists(isDeleted) OR isDeleted = :false) ' +
                    'AND currentStock > :zero',
                expressionAttributeValues: {
                    ':threshold': sevenDayStr,
                    ':today': todayStr,
                    ':false': false,
                    ':zero': 0,
                },
                limit: 20,
            },
        );

        return result.items
            .map(p => {
                const expiryMs = new Date(p.expiryDate + 'T00:00:00Z').getTime();
                const todayMs = new Date(todayStr + 'T00:00:00Z').getTime();
                const daysRemaining = Math.floor((expiryMs - todayMs) / 86400000);
                return {
                    id: p.id,
                    name: p.name,
                    expiry_date: p.expiryDate,
                    days_remaining: daysRemaining,
                    current_stock: p.currentStock,
                    unit: p.unit || 'pcs',
                    stock_value_cents: (Number(p.currentStock) || 0) * (Number(p.salePriceCents) || 0),
                };
            })
            .sort((a, b) => a.days_remaining - b.days_remaining)
            .slice(0, 10);
    }

    /**
     * Products with zero sales in the last 90 days.
     * These tie up capital and shelf space — should be discounted or returned.
     */
    private async getDeadStock(tenantId: string) {
        const ninetyDaysAgo = new Date(Date.now() - 90 * 86400000).toISOString();

        // Get all products with stock > 0
        const products = await queryItems<Record<string, any>>(
            Keys.tenantPK(tenantId),
            'PRODUCT#',
            {
                filterExpression:
                    '(attribute_not_exists(isDeleted) OR isDeleted = :false) ' +
                    'AND currentStock > :zero',
                expressionAttributeValues: { ':false': false, ':zero': 0 },
                limit: 200,
            },
        );

        if (products.items.length === 0) return [];

        // Get recent invoices to find which products had sales
        const invoices = await queryItems<Record<string, any>>(
            Keys.tenantPK(tenantId),
            'INVOICE#',
            {
                filterExpression:
                    'createdAt >= :since AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':since': ninetyDaysAgo, ':false': false },
                limit: 100,
            },
        );

        // Build set of product IDs that had sales
        const soldProductIds = new Set<string>();
        for (const inv of invoices.items) {
            const lineItems = await queryItems<Record<string, any>>(
                `INVOICE#${inv.id}`, 'LINEITEM#', { limit: 50 },
            );
            for (const li of lineItems.items) {
                if (li.productId) soldProductIds.add(li.productId);
            }
        }

        // Filter products with no sales
        return products.items
            .filter(p => !soldProductIds.has(p.id))
            .slice(0, 10)
            .map(p => ({
                id: p.id,
                name: p.name,
                current_stock: p.currentStock,
                unit: p.unit || 'pcs',
                stock_value_cents: (Number(p.currentStock) || 0) * (Number(p.purchasePriceCents) || 0),
                category: p.category,
                last_updated: p.updatedAt,
            }));
    }

    /**
     * Products where sale price < purchase price (negative margin).
     * Common in grocery when wholesale prices fluctuate.
     */
    private async getMarginAlerts(tenantId: string) {
        const result = await queryItems<Record<string, any>>(
            Keys.tenantPK(tenantId),
            'PRODUCT#',
            {
                filterExpression:
                    '(attribute_not_exists(isDeleted) OR isDeleted = :false) ' +
                    'AND attribute_exists(purchasePriceCents) ' +
                    'AND salePriceCents < purchasePriceCents ' +
                    'AND currentStock > :zero',
                expressionAttributeValues: { ':false': false, ':zero': 0 },
                limit: 20,
            },
        );

        return result.items
            .slice(0, 10)
            .map(p => ({
                id: p.id,
                name: p.name,
                sale_price_cents: p.salePriceCents,
                purchase_price_cents: p.purchasePriceCents,
                margin_cents: (Number(p.salePriceCents) || 0) - (Number(p.purchasePriceCents) || 0),
                current_stock: p.currentStock,
                loss_at_current_stock_cents:
                    ((Number(p.purchasePriceCents) || 0) - (Number(p.salePriceCents) || 0)) *
                    (Number(p.currentStock) || 0),
            }));
    }
}
