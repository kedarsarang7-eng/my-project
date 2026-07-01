// ============================================================================
// Dashboard Service — Business-Type Strategy Dispatcher
// ============================================================================
// The core "Multi-Business Switch" — routes dashboard data requests
// to the correct strategy based on the tenant's business type.
// ============================================================================

import { BusinessType } from '../types/tenant.types';
import { getPool } from '../config/db.config';
import { logger } from '../utils/logger';

// Business-specific strategies
import { PetrolPumpStrategy } from './business/petrol-pump.strategy';
import { PharmacyStrategy } from './business/pharmacy.strategy';
import { BaseStrategy } from './business/base.strategy';

/**
 * Dashboard data shape returned to the client.
 * Each business type adds its own sections.
 */
export interface DashboardData {
    businessType: BusinessType;
    tenantId: string;
    summary: {
        todayRevenueCents: number;
        todayTransactions: number;
        activeProducts: number;
        pendingPaymentsCents: number;
    };
    // Business-specific sections
    sections: DashboardSection[];
}

export interface DashboardSection {
    id: string;
    title: string;
    type: 'metric' | 'table' | 'chart' | 'list' | 'alert';
    data: unknown;
}

export class DashboardService {
    private strategies: Map<BusinessType, BaseStrategy>;

    constructor() {
        this.strategies = new Map();

        // ── Register Business Strategies ──────────────────────────────────
        const petrolPump = new PetrolPumpStrategy();
        const pharmacy = new PharmacyStrategy();
        const base = new BaseStrategy();

        this.strategies.set(BusinessType.PETROL_PUMP, petrolPump);
        this.strategies.set(BusinessType.PHARMACY, pharmacy);

        // All other types use the base strategy (common dashboard)
        // You can add more specialized strategies as needed:
        // this.strategies.set(BusinessType.RESTAURANT, new RestaurantStrategy());
        // this.strategies.set(BusinessType.CLOTHING, new ClothingStrategy());
        // etc.

        // Register base for remaining types
        for (const bt of Object.values(BusinessType)) {
            if (!this.strategies.has(bt)) {
                this.strategies.set(bt, base);
            }
        }
    }

    /**
     * Get dashboard data for a tenant.
     *
     * Flow:
     * 1. Fetch common metrics (revenue, transactions, etc.)
     * 2. Dispatch to the business-type strategy for specialized sections
     * 3. Merge and return
     */
    async getDashboard(tenantId: string, businessType: BusinessType): Promise<DashboardData> {
        const db = getPool();

        // ── 1. Common Summary (shared across all business types) ──────────
        const summaryResult = await db.query(
            `SELECT
        COALESCE(SUM(CASE WHEN t.created_at::date = CURRENT_DATE THEN t.total_cents ELSE 0 END), 0)
          AS today_revenue_cents,
        COUNT(CASE WHEN t.created_at::date = CURRENT_DATE THEN 1 END)
          AS today_transactions,
        (SELECT COUNT(*) FROM inventory WHERE tenant_id = $1 AND is_active = TRUE)
          AS active_products,
        COALESCE(SUM(CASE WHEN t.status = 'pending' THEN t.total_cents ELSE 0 END), 0)
          AS pending_payments_cents
       FROM transactions t
       WHERE t.tenant_id = $1`,
            [tenantId]
        );

        const summary = summaryResult.rows[0] || {};

        // ── 2. Business-Specific Sections ─────────────────────────────────
        const strategy = this.strategies.get(businessType) || new BaseStrategy();

        logger.info('Dispatching to strategy', {
            businessType,
            strategy: strategy.constructor.name,
        });

        const sections = await strategy.getDashboardSections(tenantId);

        // ── 3. Merge ──────────────────────────────────────────────────────
        return {
            businessType,
            tenantId,
            summary: {
                todayRevenueCents: parseInt(summary.today_revenue_cents || '0', 10),
                todayTransactions: parseInt(summary.today_transactions || '0', 10),
                activeProducts: parseInt(summary.active_products || '0', 10),
                pendingPaymentsCents: parseInt(summary.pending_payments_cents || '0', 10),
            },
            sections,
        };
    }
}
