// ============================================================================
// Pharmacy Strategy — Full-Featured Dashboard
// ============================================================================
// Returns all pharmacy-specific dashboard sections:
//   - Near-Expiry Medicine Alerts
//   - Batch-Wise Stock Status
//   - Drug Schedule Compliance
//   - Prescription-Linked Sales
//   - CDSCO Compliance Report
//   - Supplier Drug-wise Purchase Summary
//   - Controlled Substance Register
//   - Rack/Location Wise Stock
//   - Monthly Return Analysis
// ============================================================================

import { getPool } from '../../config/db.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class PharmacyStrategy extends BaseStrategy {

    /**
     * Override base to prepend pharmacy-specific sections.
     */
    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const baseSections = await super.getDashboardSections(tenantId);

        const pharmacySections: DashboardSection[] = [
            {
                id: 'near_expiry_medicines',
                title: '⚠️ Near-Expiry Medicines (Next 90 Days)',
                type: 'alert',
                data: await this.getNearExpiryMedicines(tenantId),
            },
            {
                id: 'expired_medicines',
                title: '🚫 Expired Medicines (Requires Action)',
                type: 'alert',
                data: await this.getExpiredMedicines(tenantId),
            },
            {
                id: 'batch_stock',
                title: 'Batch-Wise Stock Status',
                type: 'table',
                data: await this.getBatchWiseStock(tenantId),
            },
            {
                id: 'drug_schedule_compliance',
                title: 'Drug Schedule Compliance',
                type: 'table',
                data: await this.getDrugScheduleCompliance(tenantId),
            },
            {
                id: 'prescription_sales',
                title: 'Prescription-Linked Sales (Today)',
                type: 'table',
                data: await this.getPrescriptionSales(tenantId),
            },
            {
                id: 'controlled_substances',
                title: 'Controlled Substance Register',
                type: 'table',
                data: await this.getControlledSubstanceRegister(tenantId),
            },
            {
                id: 'supplier_purchase',
                title: 'Supplier Drug-wise Purchase Summary',
                type: 'table',
                data: await this.getSupplierPurchaseSummary(tenantId),
            },
            {
                id: 'rack_stock',
                title: 'Rack/Location Wise Stock',
                type: 'table',
                data: await this.getRackWiseStock(tenantId),
            },
            {
                id: 'return_analysis',
                title: 'Monthly Return Analysis',
                type: 'chart',
                data: await this.getReturnAnalysis(tenantId),
            },
        ];

        return [...pharmacySections, ...baseSections];
    }

    // ── Near-Expiry Medicines ───────────────────────────────────────────────

    private async getNearExpiryMedicines(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         mb.id,
         i.name AS drug_name,
         mb.batch_number,
         mb.expiry_date,
         mb.current_qty,
         i.unit,
         mb.mrp_cents,
         (mb.expiry_date - CURRENT_DATE) AS days_until_expiry,
         i.attributes->>'manufacturer' AS manufacturer,
         i.attributes->>'composition' AS composition
       FROM medicine_batches mb
       JOIN inventory i ON i.id = mb.product_id
       WHERE mb.tenant_id = $1
         AND mb.current_qty > 0
         AND mb.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'
       ORDER BY mb.expiry_date ASC`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Expired Medicines ───────────────────────────────────────────────────

    private async getExpiredMedicines(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         mb.id,
         i.name AS drug_name,
         mb.batch_number,
         mb.expiry_date,
         mb.current_qty,
         mb.mrp_cents,
         i.attributes->>'manufacturer' AS manufacturer,
         ABS(mb.expiry_date - CURRENT_DATE) AS days_since_expired
       FROM medicine_batches mb
       JOIN inventory i ON i.id = mb.product_id
       WHERE mb.tenant_id = $1
         AND mb.current_qty > 0
         AND mb.expiry_date < CURRENT_DATE
       ORDER BY mb.expiry_date ASC`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Batch-Wise Stock ────────────────────────────────────────────────────

    private async getBatchWiseStock(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         i.name AS drug_name,
         mb.batch_number,
         mb.manufacturing_date,
         mb.expiry_date,
         mb.initial_qty,
         mb.current_qty,
         mb.purchase_price_cents,
         mb.sale_price_cents,
         mb.mrp_cents,
         i.attributes->>'rackLocation' AS rack_location
       FROM medicine_batches mb
       JOIN inventory i ON i.id = mb.product_id
       WHERE mb.tenant_id = $1
         AND mb.current_qty > 0
       ORDER BY i.name, mb.expiry_date ASC
       LIMIT 100`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Drug Schedule Compliance ────────────────────────────────────────────

    private async getDrugScheduleCompliance(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         i.attributes->>'drugSchedule' AS drug_schedule,
         COUNT(*) AS total_products,
         SUM(CASE WHEN i.attributes->>'requiresPrescription' = 'true' THEN 1 ELSE 0 END)
           AS requires_prescription,
         SUM(i.current_stock) AS total_stock
       FROM inventory i
       WHERE i.tenant_id = $1
         AND i.product_type = 'medicine'
         AND i.is_active = TRUE
         AND i.is_deleted = FALSE
         AND i.attributes->>'drugSchedule' IS NOT NULL
       GROUP BY i.attributes->>'drugSchedule'
       ORDER BY drug_schedule`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Prescription-Linked Sales ───────────────────────────────────────────

    private async getPrescriptionSales(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         t.id,
         t.invoice_number,
         t.total_cents,
         t.customer_name,
         t.created_at,
         t.metadata->>'prescriptionId' AS prescription_id,
         t.metadata->>'doctorName' AS doctor_name,
         CASE WHEN t.metadata->>'prescriptionId' IS NOT NULL
              THEN TRUE ELSE FALSE END AS has_prescription
       FROM transactions t
       WHERE t.tenant_id = $1
         AND t.created_at::date = CURRENT_DATE
       ORDER BY t.created_at DESC
       LIMIT 20`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Controlled Substance Register ───────────────────────────────────────

    private async getControlledSubstanceRegister(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         i.name AS drug_name,
         i.attributes->>'drugSchedule' AS schedule,
         i.current_stock,
         i.unit,
         (SELECT COUNT(*)
          FROM transaction_items ti
          WHERE ti.item_id = i.id
            AND ti.created_at >= CURRENT_DATE - INTERVAL '30 days'
         ) AS sales_last_30_days,
         (SELECT SUM(ti.quantity)
          FROM transaction_items ti
          WHERE ti.item_id = i.id
            AND ti.created_at >= CURRENT_DATE - INTERVAL '30 days'
         ) AS qty_sold_last_30_days
       FROM inventory i
       WHERE i.tenant_id = $1
         AND i.product_type = 'medicine'
         AND i.attributes->>'drugSchedule' IN ('H', 'H1', 'X')
         AND i.is_active = TRUE
         AND i.is_deleted = FALSE
       ORDER BY i.attributes->>'drugSchedule', i.name`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Supplier Purchase Summary ───────────────────────────────────────────

    private async getSupplierPurchaseSummary(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         v.name AS supplier_name,
         COUNT(DISTINCT po.id) AS total_orders,
         SUM(po.total_cents) AS total_purchase_cents,
         v.current_balance_cents AS outstanding_cents,
         MAX(po.order_date) AS last_order_date
       FROM purchase_orders po
       JOIN vendors v ON v.id = po.vendor_id
       WHERE po.tenant_id = $1
         AND po.order_date >= CURRENT_DATE - INTERVAL '90 days'
       GROUP BY v.id, v.name, v.current_balance_cents
       ORDER BY total_purchase_cents DESC`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Rack/Location Wise Stock ────────────────────────────────────────────

    private async getRackWiseStock(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         COALESCE(i.attributes->>'rackLocation', 'Unassigned') AS rack_location,
         COUNT(*) AS product_count,
         SUM(i.current_stock) AS total_stock,
         SUM(i.current_stock * i.sale_price_cents) AS stock_value_cents
       FROM inventory i
       WHERE i.tenant_id = $1
         AND i.product_type = 'medicine'
         AND i.is_active = TRUE
         AND i.is_deleted = FALSE
       GROUP BY i.attributes->>'rackLocation'
       ORDER BY rack_location`,
            [tenantId]
        );
        return result.rows;
    }

    // ── Monthly Return Analysis ─────────────────────────────────────────────

    private async getReturnAnalysis(tenantId: string) {
        const db = getPool();
        const result = await db.query(
            `SELECT
         DATE_TRUNC('month', r.return_date)::date AS month,
         COUNT(*) AS return_count,
         SUM(r.amount_cents) AS return_amount_cents,
         STRING_AGG(DISTINCT r.reason, ', ') AS reasons
       FROM returns r
       WHERE r.tenant_id = $1
         AND r.return_date >= CURRENT_DATE - INTERVAL '6 months'
       GROUP BY DATE_TRUNC('month', r.return_date)
       ORDER BY month DESC`,
            [tenantId]
        );
        return result.rows;
    }
}
