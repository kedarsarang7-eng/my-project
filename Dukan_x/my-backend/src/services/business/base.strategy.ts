// ============================================================================
// Base Business Strategy — Default Dashboard Sections
// ============================================================================
// Used by all business types that don't have a specialized strategy.
// Provides: Low stock alerts, top sellers, daily revenue chart, recent sales.
// ============================================================================

import { getPool } from '../../config/db.config';
import { DashboardSection } from '../dashboard.service';

export class BaseStrategy {

    /**
     * Return dashboard sections common to all business types.
     * Specialized strategies extend this and add their own sections.
     */
    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const sections: DashboardSection[] = [];

        // ── Low Stock Alerts ────────────────────────────────────────────────
        const lowStock = await this.getLowStockAlerts(tenantId);
        sections.push({
            id: 'low_stock',
            title: 'Low Stock Alerts',
            type: 'alert',
            data: lowStock,
        });

        // ── Top Selling Products (Last 30 days) ─────────────────────────────
        const topSellers = await this.getTopSellers(tenantId);
        sections.push({
            id: 'top_sellers',
            title: 'Top Selling Products',
            type: 'table',
            data: topSellers,
        });

        // ── Recent Sales ────────────────────────────────────────────────────
        const recentSales = await this.getRecentSales(tenantId);
        sections.push({
            id: 'recent_sales',
            title: 'Recent Sales',
            type: 'table',
            data: recentSales,
        });

        // ── Revenue Trend (Last 7 days) ─────────────────────────────────────
        const revenueTrend = await this.getRevenueTrend(tenantId);
        sections.push({
            id: 'revenue_trend',
            title: 'Revenue Trend (7 Days)',
            type: 'chart',
            data: revenueTrend,
        });

        return sections;
    }

    protected async getLowStockAlerts(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT id, name, current_stock, low_stock_threshold, unit
       FROM inventory
       WHERE tenant_id = $1
         AND current_stock <= low_stock_threshold
         AND is_active = TRUE
         AND is_deleted = FALSE
       ORDER BY (current_stock / NULLIF(low_stock_threshold, 0)) ASC
       LIMIT 10`,
            [tenantId]
        );
        return result.rows;
    }

    protected async getTopSellers(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         i.name,
         COUNT(*) AS sale_count,
         SUM(ti.quantity) AS total_qty,
         SUM(ti.total_cents) AS total_revenue_cents
       FROM transaction_items ti
       JOIN inventory i ON i.id = ti.item_id
       WHERE ti.tenant_id = $1
         AND ti.created_at >= CURRENT_DATE - INTERVAL '30 days'
       GROUP BY i.id, i.name
       ORDER BY total_revenue_cents DESC
       LIMIT 10`,
            [tenantId]
        );
        return result.rows;
    }

    protected async getRecentSales(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT id, invoice_number, total_cents, payment_mode, status, created_at
       FROM transactions
       WHERE tenant_id = $1
       ORDER BY created_at DESC
       LIMIT 15`,
            [tenantId]
        );
        return result.rows;
    }

    protected async getRevenueTrend(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         d.date,
         COALESCE(SUM(t.total_cents), 0) AS revenue_cents,
         COUNT(t.id) AS transaction_count
       FROM generate_series(
         CURRENT_DATE - INTERVAL '6 days',
         CURRENT_DATE,
         '1 day'
       ) AS d(date)
       LEFT JOIN transactions t
         ON t.tenant_id = $1
         AND t.created_at::date = d.date
         AND t.status != 'voided'
       GROUP BY d.date
       ORDER BY d.date ASC`,
            [tenantId]
        );
        return result.rows;
    }
}
