/// Sidebar item id → minimum subscription plan required when no explicit backend flag exists.
///
/// Keys align with [SidebarMenuItem.id]. Tune via backend `feature_flags` / JSON flags first;
/// this matrix is the fallback for "show locked until upgrade".
///
/// Plan hierarchy: basic(0) < pro(1) < premium(2) < enterprise(3)
/// Rules from dukanx_feature_tier_spec.md:
///   - Basic: core billing, basic inventory, customer ledger, daily snapshot
///   - Pro: advanced reports, barcode label printing, stock valuation, analytics, business-specific growth tools
///   - Premium: GST compliance reports, audit trail, cloud backup, aging reports, compliance registers, advanced roles
///   - Enterprise: multi-branch, API access, financial reconciliation, centralized sync, BI hub
class FeaturePlanMatrix {
  FeaturePlanMatrix._();

  /// Minimum plan tier name (see [planTierRank]) or null = no plan gate for this item.
  static String? minPlanForSidebarItem(String itemId) {
    return _matrix[itemId];
  }

  static const Map<String, String> _matrix = {
    // ── BASIC (always unlocked — null means no gate) ─────────────────────────
    // Dashboard & core ops — available to all plans, so not in map (null = open)

    // ── PRO — Growth & Insight ────────────────────────────────────────────────

    // Analytics / BI
    'analytics_hub': 'pro',
    'insights': 'pro',
    'margin_analysis': 'pro',
    'turnover_analysis': 'pro',
    'procurement_insights': 'pro',
    'product_performance': 'pro',
    'doctor_revenue': 'pro',
    'restaurant_owner_command': 'pro',

    // Stock / inventory growth tools (Pro+)
    'stock_valuation': 'pro',
    'batch_tracking': 'pro',

    // Barcode label printing (Pro+)
    'barcode_label_printing': 'pro',

    // Hardware specific phase (Pro+)
    'hardware_phase12': 'pro',

    // Reports (Pro+)
    'kot_reports': 'pro',
    'fuel_profit_report': 'pro',
    'nozzle_sales_report': 'pro',
    'shift_report': 'pro',

    // Purchase register & stock reversal — Pro for pharmacy/wholesale, Premium for grocery/hardware
    // Using conservative Pro gate (backend can override per business type)
    'purchase_register': 'pro',
    'stock_reversal': 'pro',

    // Book store specific analytics (Pro+)
    'book_analytics': 'pro',

    // Jewellery / auto parts growth (Pro+)
    'karigar_analytics': 'pro',
    'vehicle_revenue_report': 'pro',

    // ── PREMIUM — Compliance & Control ───────────────────────────────────────

    // Financial reports suite
    'accounting_reports': 'premium',
    'invoice_margin': 'premium',
    'income_statement': 'premium',
    'funds_flow': 'premium',
    'financial_position': 'premium',

    // GST & Tax compliance (Premium+ for ALL business types — no exceptions)
    'gstr1': 'premium',
    'b2b_b2c': 'premium',
    'hsn_reports': 'premium',
    'tax_liability': 'premium',
    'filing_status': 'premium',

    // Audit & backup (Premium+ — spec explicitly says NOT enterprise)
    'audit_trail': 'premium',
    'backup': 'premium',

    // Aging / outstanding reports (Premium+)
    'outstanding': 'premium',

    // Advanced role / operations (Premium+)
    'activity_logs': 'premium',

    // Compliance registers (Pharmacy — Premium+)
    'narcotic_register': 'premium',
    'h1_register': 'premium',
    'schedule_h1_register': 'premium',

    // Petrol pump compliance (Premium+)
    'du_calibration': 'premium',

    // Jewellery compliance (Premium+)
    'high_value_reporting': 'premium',

    // Inventory export (Premium+)
    'inventory_export': 'premium',

    // ── ENTERPRISE — Scale Tools ──────────────────────────────────────────────

    // Multi-branch (Enterprise for ALL business types — no exceptions)
    'multi_branch': 'enterprise',
    'branch_management': 'enterprise',
    'centralized_inventory': 'enterprise',

    // API / integrations (Enterprise — no exceptions)
    'api_access': 'enterprise',

    // Financial reconciliation engine
    'financial_reconciliation': 'enterprise',
    'financial_position_adv': 'enterprise',

    // Hierarchical roles
    'role_management': 'enterprise',

    // Online order integrations (restaurant-specific Enterprise)
    'online_orders': 'enterprise',
  };
}
