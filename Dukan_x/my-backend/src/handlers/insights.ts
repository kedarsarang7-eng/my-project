// ============================================================================
// Lambda Handler — AI Insights
// ============================================================================
// Endpoint:
//   POST /insights/ai-insight  — Generate AI-powered business insight
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { getPool } from '../config/db.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

/**
 * POST /insights/ai-insight
 * Generate a business insight based on today's data.
 * Uses rule-based logic (no external AI dependency for free tier).
 */
export const aiInsight = authorizedHandler([], async (event, _context, auth) => {
    const db = getPool();

    try {
        // 1. Get today's sales summary
        const salesResult = await db.query(
            `SELECT
                COUNT(*)::int AS bill_count,
                COALESCE(SUM(total_cents), 0)::bigint AS total_cents,
                COALESCE(AVG(total_cents), 0)::bigint AS avg_bill_cents
             FROM transactions
             WHERE tenant_id = $1
               AND DATE(created_at) = CURRENT_DATE
               AND NOT is_deleted
               AND status != 'voided'`,
            [auth.tenantId]
        );

        const sales = salesResult.rows[0];
        const totalRupees = Number(sales.total_cents) / 100;
        const billCount = sales.bill_count;
        const avgBillRupees = Number(sales.avg_bill_cents) / 100;

        // 2. Get low stock count
        const lowStockResult = await db.query(
            `SELECT COUNT(*)::int AS low_count
             FROM inventory
             WHERE tenant_id = $1
               AND current_stock <= low_stock_threshold
               AND is_active AND NOT is_deleted AND NOT is_service`,
            [auth.tenantId]
        );
        const lowStockCount = lowStockResult.rows[0].low_count;

        // 3. Get yesterday's sales for comparison
        const yesterdayResult = await db.query(
            `SELECT COALESCE(SUM(total_cents), 0)::bigint AS total_cents
             FROM transactions
             WHERE tenant_id = $1
               AND DATE(created_at) = CURRENT_DATE - INTERVAL '1 day'
               AND NOT is_deleted
               AND status != 'voided'`,
            [auth.tenantId]
        );
        const yesterdayRupees = Number(yesterdayResult.rows[0].total_cents) / 100;

        // 4. Generate insight
        let insight: string;

        if (billCount === 0) {
            insight = 'No sales recorded yet today. Consider running a promotion or checking if your shop is visible online.';
        } else if (totalRupees > yesterdayRupees * 1.2 && yesterdayRupees > 0) {
            const pctUp = Math.round(((totalRupees - yesterdayRupees) / yesterdayRupees) * 100);
            insight = `Sales are up ${pctUp}% compared to yesterday (₹${totalRupees.toLocaleString()} vs ₹${yesterdayRupees.toLocaleString()}). Great momentum! `;
            if (lowStockCount > 0) {
                insight += `Watch out: ${lowStockCount} items are running low on stock.`;
            }
        } else if (totalRupees < yesterdayRupees * 0.8 && yesterdayRupees > 0) {
            const pctDown = Math.round(((yesterdayRupees - totalRupees) / yesterdayRupees) * 100);
            insight = `Sales are down ${pctDown}% vs yesterday. Average bill is ₹${avgBillRupees.toFixed(0)}. Consider upselling or bundling products.`;
        } else if (lowStockCount > 5) {
            insight = `${lowStockCount} items are below reorder level. Prioritize restocking to avoid lost sales. Today's revenue: ₹${totalRupees.toLocaleString()}.`;
        } else {
            insight = `Steady day so far — ${billCount} bills totaling ₹${totalRupees.toLocaleString()} (avg ₹${avgBillRupees.toFixed(0)}/bill). Keep it up!`;
        }

        return response.success({
            ai_insight: insight,
            stats: {
                todaySalesRupees: totalRupees,
                billCount,
                avgBillRupees,
                yesterdaySalesRupees: yesterdayRupees,
                lowStockCount,
            },
        });
    } catch (err) {
        logger.error('Insights generation failed', { error: (err as Error).message });
        return response.success({
            ai_insight: 'Unable to generate insights right now. Please try again later.',
        });
    }
});
