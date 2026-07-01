// ============================================================================
// Petrol Pump Strategy — Full-Featured Dashboard
// ============================================================================
// Returns all petrol-pump-specific dashboard sections:
//   - Fuel Tank Levels (with capacity & dip-stick readings)
//   - Nozzle Sales (per shift)
//   - Shift Summaries (cash collection, credit sales)
//   - Lube / Oil Stock
//   - Cash Deposit Summary
//   - GST-wise Petrol Sale Report
//   - Evaporation / Handling Loss Tracking
//   - 5-Litre Test Records
//   - Daily Fuel Price Chart
// ============================================================================

import { getPool } from '../../config/db.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class PetrolPumpStrategy extends BaseStrategy {

    /**
     * Override base to prepend petrol-pump-specific sections.
     */
    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        // Get base sections first (low stock, top sellers, etc.)
        const baseSections = await super.getDashboardSections(tenantId);

        // Add petrol-pump-specific sections BEFORE base sections
        const pumpSections: DashboardSection[] = [
            {
                id: 'fuel_tank_levels',
                title: 'Fuel Tank Status',
                type: 'metric',
                data: await this.getFuelTankLevels(tenantId),
            },
            {
                id: 'nozzle_sales_today',
                title: "Today's Nozzle Sales",
                type: 'table',
                data: await this.getNozzleSalesToday(tenantId),
            },
            {
                id: 'shift_summary',
                title: 'Current Shift Summary',
                type: 'metric',
                data: await this.getShiftSummary(tenantId),
            },
            {
                id: 'lube_stock',
                title: 'Lube & Oil Stock',
                type: 'table',
                data: await this.getLubeStock(tenantId),
            },
            {
                id: 'cash_deposit_summary',
                title: 'Cash Deposit Summary',
                type: 'table',
                data: await this.getCashDepositSummary(tenantId),
            },
            {
                id: 'gst_petrol_sale',
                title: 'GST-wise Fuel Sale Report',
                type: 'table',
                data: await this.getGstWiseFuelSale(tenantId),
            },
            {
                id: 'evaporation_loss',
                title: 'Evaporation / Handling Loss',
                type: 'table',
                data: await this.getEvaporationLoss(tenantId),
            },
            {
                id: 'five_litre_tests',
                title: '5-Litre Test Records',
                type: 'table',
                data: await this.getFiveLitreTests(tenantId),
            },
            {
                id: 'daily_fuel_price',
                title: 'Daily Fuel Price Trend',
                type: 'chart',
                data: await this.getDailyFuelPriceChart(tenantId),
            },
        ];

        return [...pumpSections, ...baseSections];
    }

    // ── Fuel Tanks ──────────────────────────────────────────────────────────

    private async getFuelTankLevels(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         ft.id,
         ft.tank_name,
         ft.fuel_type,
         ft.capacity_litres,
         ft.current_stock_litres,
         ROUND((ft.current_stock_litres / NULLIF(ft.capacity_litres, 0)) * 100, 1)
           AS fill_percentage,
         ft.last_dip_reading,
         ft.last_dip_at
       FROM fuel_tanks ft
       WHERE ft.tenant_id = $1
       ORDER BY ft.tank_name`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Nozzle Sales ────────────────────────────────────────────────────────

    private async getNozzleSalesToday(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         n.nozzle_name,
         n.fuel_type,
         nr.opening_reading,
         nr.closing_reading,
         (nr.closing_reading - nr.opening_reading) AS litres_sold,
         nr.testing_qty,
         ((nr.closing_reading - nr.opening_reading) - COALESCE(nr.testing_qty, 0))
           AS net_sale_litres,
         nr.amount_cents,
         s.shift_name
       FROM nozzle_readings nr
       JOIN nozzles n ON n.id = nr.nozzle_id
       LEFT JOIN shifts s ON s.id = nr.shift_id
       WHERE nr.tenant_id = $1
         AND nr.reading_date = CURRENT_DATE
       ORDER BY s.start_time, n.nozzle_name`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Shift Summary ───────────────────────────────────────────────────────

    private async getShiftSummary(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         s.id,
         s.shift_name,
         s.staff_name,
         s.start_time,
         s.end_time,
         s.status,
         COALESCE(SUM(nr.amount_cents), 0) AS total_fuel_sales_cents,
         COALESCE(SUM(
           CASE WHEN nr.payment_mode = 'CASH' THEN nr.amount_cents ELSE 0 END
         ), 0) AS cash_sales_cents,
         COALESCE(SUM(
           CASE WHEN nr.payment_mode = 'CREDIT' THEN nr.amount_cents ELSE 0 END
         ), 0) AS credit_sales_cents,
         COALESCE(SUM(
           CASE WHEN nr.payment_mode = 'UPI' THEN nr.amount_cents ELSE 0 END
         ), 0) AS upi_sales_cents
       FROM shifts s
       LEFT JOIN nozzle_readings nr ON nr.shift_id = s.id
       WHERE s.tenant_id = $1
         AND s.shift_date = CURRENT_DATE
       GROUP BY s.id
       ORDER BY s.start_time DESC`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Lube Stock ──────────────────────────────────────────────────────────

    private async getLubeStock(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         i.id,
         i.name,
         i.brand,
         i.current_stock,
         i.unit,
         i.sale_price_cents,
         i.low_stock_threshold,
         CASE WHEN i.current_stock <= i.low_stock_threshold
              THEN TRUE ELSE FALSE END AS is_low
       FROM inventory i
       WHERE i.tenant_id = $1
         AND i.category IN ('lube', 'oil', 'lubricant', 'coolant')
         AND i.is_active = TRUE
         AND i.is_deleted = FALSE
       ORDER BY i.name`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Cash Deposit Summary ────────────────────────────────────────────────

    private async getCashDepositSummary(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         cd.deposit_date,
         cd.shift_name,
         cd.staff_name,
         cd.expected_cash_cents,
         cd.actual_cash_cents,
         (cd.actual_cash_cents - cd.expected_cash_cents) AS difference_cents,
         cd.bank_deposited_cents,
         cd.notes
       FROM cash_deposits cd
       WHERE cd.tenant_id = $1
         AND cd.deposit_date >= CURRENT_DATE - INTERVAL '7 days'
       ORDER BY cd.deposit_date DESC, cd.shift_name`,
            [tenantId]
        );
        return result.rows;
    }

    // ── GST-wise Fuel Sale Report ───────────────────────────────────────────

    private async getGstWiseFuelSale(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         fuel_type,
         SUM(net_sale_litres) AS total_litres,
         SUM(amount_cents) AS total_amount_cents,
         SUM(cgst_cents) AS total_cgst_cents,
         SUM(sgst_cents) AS total_sgst_cents,
         SUM(cess_cents) AS total_cess_cents,
         SUM(amount_cents - cgst_cents - sgst_cents - cess_cents) AS taxable_cents
       FROM fuel_sales_gst_view
       WHERE tenant_id = $1
         AND sale_date >= DATE_TRUNC('month', CURRENT_DATE)
       GROUP BY fuel_type
       ORDER BY fuel_type`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Evaporation / Handling Loss ─────────────────────────────────────────

    private async getEvaporationLoss(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         le.id,
         le.loss_date,
         le.fuel_type,
         le.loss_type,
         le.quantity_litres,
         le.reason,
         ft.tank_name
       FROM loss_entries le
       JOIN fuel_tanks ft ON ft.id = le.tank_id
       WHERE le.tenant_id = $1
         AND le.loss_date >= CURRENT_DATE - INTERVAL '30 days'
       ORDER BY le.loss_date DESC`,
            [tenantId]
        );
        return result.rows;
    }

    // ── 5-Litre Test Records ────────────────────────────────────────────────

    private async getFiveLitreTests(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         ft.id,
         ft.test_date,
         ft.nozzle_name,
         ft.fuel_type,
         ft.measured_quantity_ml,
         ft.expected_quantity_ml,
         ft.variance_ml,
         CASE
           WHEN ABS(ft.variance_ml) <= 25 THEN 'PASS'
           ELSE 'FAIL'
         END AS result,
         ft.tested_by,
         ft.notes
       FROM five_litre_tests ft
       WHERE ft.tenant_id = $1
         AND ft.test_date >= CURRENT_DATE - INTERVAL '90 days'
       ORDER BY ft.test_date DESC`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Daily Fuel Price Chart ──────────────────────────────────────────────

    private async getDailyFuelPriceChart(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         fp.effective_date,
         fp.fuel_type,
         fp.price_per_litre_cents
       FROM fuel_prices fp
       WHERE fp.tenant_id = $1
         AND fp.effective_date >= CURRENT_DATE - INTERVAL '30 days'
       ORDER BY fp.effective_date ASC, fp.fuel_type`,
            [tenantId]
        );
        return result.rows;
    }
}
