// ============================================================================
// MOBILE SHOP — KPI METRIC DEFINITIONS
// ============================================================================
// Enumerates all required Live KPI metrics for the mobile shop dashboard.
// Each metric maps to a specific data source, permission, feature policy,
// and filter for navigation drill-down.
//
// Requirement 9.7: repair statuses, overdue repairs, exchange pipeline,
// IMEI stock by lifecycle, warranty expiries/claims, second-hand intake,
// unresolved conflicts, reconciliation failures.
//
// Requirements: 9.1–9.8, 9.13; Audit: AF-33, AF-47
// ============================================================================

import 'package:flutter/material.dart';

/// All required KPI metrics for the mobile shop dashboard.
///
/// Each metric is sourced from confirmed local repository data only.
/// No metric uses hardcoded/fabricated values.
enum KpiMetric {
  /// IMEI units currently in stock (lifecycle: IN_STOCK).
  stockInStock,

  /// IMEI units reserved (lifecycle: RESERVED).
  stockReserved,

  /// IMEI units sold (lifecycle: SOLD).
  stockSold,

  /// IMEI units in demo state.
  stockDemo,

  /// Total active repair/service jobs.
  repairActive,

  /// Overdue repair/service jobs.
  repairOverdue,

  /// Total completed repairs.
  repairCompleted,

  /// Exchange pipeline count (pending exchanges).
  exchangePending,

  /// Exchange pipeline total value (paise).
  exchangeValuePaise,

  /// Completed exchanges.
  exchangeCompleted,

  /// Active warranties.
  warrantyActive,

  /// Warranties expiring soon (within configured threshold).
  warrantyExpiringSoon,

  /// Open warranty claims.
  warrantyClaims,

  /// Second-hand units in intake pipeline.
  usedStockIntake,

  /// Used stock available for sale.
  usedStockAvailable,

  /// Unresolved sync/version conflicts.
  conflictsUnresolved,

  /// Active reconciliation failures.
  reconciliationFailures,

  /// Returned units.
  returnsTotal,

  /// Active finance plans.
  financeActive,
}

/// Configuration for a KPI metric including display and navigation metadata.
class KpiMetricConfig {
  /// The metric identifier.
  final KpiMetric metric;

  /// Human-readable title for display.
  final String title;

  /// Icon for the KPI card.
  final IconData icon;

  /// Required permission to view this KPI.
  final String requiredPermission;

  /// Required feature ID (from FeaturePolicyConfig).
  final String? requiredFeature;

  /// Whether an empty confirmed result shows zero vs. empty state.
  final bool showZeroForEmpty;

  /// Navigation route for drill-down.
  final String filterRoute;

  /// Query params for exact filter navigation.
  final Map<String, String> filterParams;

  const KpiMetricConfig({
    required this.metric,
    required this.title,
    required this.icon,
    required this.requiredPermission,
    this.requiredFeature,
    this.showZeroForEmpty = true,
    required this.filterRoute,
    this.filterParams = const {},
  });
}

/// All KPI metric configurations.
///
/// This catalog defines every metric's display properties, required
/// permissions, and drill-down navigation target.
const List<KpiMetricConfig> kKpiMetricConfigs = [
  // ── Stock/Lifecycle KPIs ─────────────────────────────────────────────────
  KpiMetricConfig(
    metric: KpiMetric.stockInStock,
    title: 'In Stock',
    icon: Icons.inventory_2_outlined,
    requiredPermission: 'mobile_shop:imei:view',
    requiredFeature: 'IMEI_TRACKING',
    filterRoute: '/mobile-shop/inventory',
    filterParams: {'lifecycle': 'IN_STOCK'},
  ),
  KpiMetricConfig(
    metric: KpiMetric.stockReserved,
    title: 'Reserved',
    icon: Icons.bookmark_outlined,
    requiredPermission: 'mobile_shop:imei:view',
    requiredFeature: 'IMEI_TRACKING',
    filterRoute: '/mobile-shop/inventory',
    filterParams: {'lifecycle': 'RESERVED'},
  ),
  KpiMetricConfig(
    metric: KpiMetric.stockSold,
    title: 'Sold',
    icon: Icons.sell_outlined,
    requiredPermission: 'mobile_shop:imei:view',
    requiredFeature: 'IMEI_TRACKING',
    filterRoute: '/mobile-shop/inventory',
    filterParams: {'lifecycle': 'SOLD'},
  ),
  KpiMetricConfig(
    metric: KpiMetric.stockDemo,
    title: 'Demo Units',
    icon: Icons.devices_outlined,
    requiredPermission: 'mobile_shop:imei:view',
    requiredFeature: 'IMEI_TRACKING',
    filterRoute: '/mobile-shop/inventory',
    filterParams: {'lifecycle': 'DEMO'},
  ),

  // ── Repair/Service KPIs ──────────────────────────────────────────────────
  KpiMetricConfig(
    metric: KpiMetric.repairActive,
    title: 'Active Repairs',
    icon: Icons.build_outlined,
    requiredPermission: 'mobile_shop:service:view',
    requiredFeature: 'SERVICE_JOBS',
    filterRoute: '/mobile-shop/service-jobs',
    filterParams: {'status': 'active'},
  ),
  KpiMetricConfig(
    metric: KpiMetric.repairOverdue,
    title: 'Overdue Repairs',
    icon: Icons.warning_amber_outlined,
    requiredPermission: 'mobile_shop:service:view',
    requiredFeature: 'SERVICE_JOBS',
    filterRoute: '/mobile-shop/service-jobs',
    filterParams: {'status': 'overdue'},
  ),
  KpiMetricConfig(
    metric: KpiMetric.repairCompleted,
    title: 'Completed Repairs',
    icon: Icons.check_circle_outlined,
    requiredPermission: 'mobile_shop:service:view',
    requiredFeature: 'SERVICE_JOBS',
    filterRoute: '/mobile-shop/service-jobs',
    filterParams: {'status': 'completed'},
  ),

  // ── Exchange KPIs ────────────────────────────────────────────────────────
  KpiMetricConfig(
    metric: KpiMetric.exchangePending,
    title: 'Pending Exchanges',
    icon: Icons.swap_horiz_outlined,
    requiredPermission: 'mobile_shop:exchange:view',
    requiredFeature: 'EXCHANGES',
    filterRoute: '/mobile-shop/exchanges',
    filterParams: {'status': 'pending'},
  ),
  KpiMetricConfig(
    metric: KpiMetric.exchangeValuePaise,
    title: 'Exchange Pipeline Value',
    icon: Icons.currency_rupee_outlined,
    requiredPermission: 'mobile_shop:exchange:view',
    requiredFeature: 'EXCHANGES',
    showZeroForEmpty: true,
    filterRoute: '/mobile-shop/exchanges',
    filterParams: {'status': 'pending'},
  ),
  KpiMetricConfig(
    metric: KpiMetric.exchangeCompleted,
    title: 'Completed Exchanges',
    icon: Icons.swap_horizontal_circle_outlined,
    requiredPermission: 'mobile_shop:exchange:view',
    requiredFeature: 'EXCHANGES',
    filterRoute: '/mobile-shop/exchanges',
    filterParams: {'status': 'completed'},
  ),

  // ── Warranty KPIs ────────────────────────────────────────────────────────
  KpiMetricConfig(
    metric: KpiMetric.warrantyActive,
    title: 'Active Warranties',
    icon: Icons.verified_user_outlined,
    requiredPermission: 'mobile_shop:warranty:view',
    requiredFeature: 'WARRANTY_MANAGEMENT',
    filterRoute: '/mobile-shop/warranties',
    filterParams: {'status': 'active'},
  ),
  KpiMetricConfig(
    metric: KpiMetric.warrantyExpiringSoon,
    title: 'Expiring Soon',
    icon: Icons.schedule_outlined,
    requiredPermission: 'mobile_shop:warranty:view',
    requiredFeature: 'WARRANTY_MANAGEMENT',
    filterRoute: '/mobile-shop/warranties',
    filterParams: {'status': 'expiring_soon'},
  ),
  KpiMetricConfig(
    metric: KpiMetric.warrantyClaims,
    title: 'Open Claims',
    icon: Icons.assignment_late_outlined,
    requiredPermission: 'mobile_shop:warranty:view',
    requiredFeature: 'WARRANTY_MANAGEMENT',
    filterRoute: '/mobile-shop/warranties',
    filterParams: {'claimStatus': 'open'},
  ),

  // ── Used Stock KPIs ──────────────────────────────────────────────────────
  KpiMetricConfig(
    metric: KpiMetric.usedStockIntake,
    title: 'Intake Pipeline',
    icon: Icons.input_outlined,
    requiredPermission: 'mobile_shop:second_hand:view',
    requiredFeature: 'SECOND_HAND_INTAKE',
    filterRoute: '/mobile-shop/second-hand',
    filterParams: {'status': 'intake'},
  ),
  KpiMetricConfig(
    metric: KpiMetric.usedStockAvailable,
    title: 'Used Stock Available',
    icon: Icons.storefront_outlined,
    requiredPermission: 'mobile_shop:second_hand:view',
    requiredFeature: 'SECOND_HAND_INTAKE',
    filterRoute: '/mobile-shop/second-hand',
    filterParams: {'status': 'available'},
  ),

  // ── Conflict & Reconciliation KPIs ───────────────────────────────────────
  KpiMetricConfig(
    metric: KpiMetric.conflictsUnresolved,
    title: 'Unresolved Conflicts',
    icon: Icons.error_outline,
    requiredPermission: 'mobile_shop:imei:view',
    showZeroForEmpty: true,
    filterRoute: '/mobile-shop/conflicts',
    filterParams: {'status': 'unresolved'},
  ),
  KpiMetricConfig(
    metric: KpiMetric.reconciliationFailures,
    title: 'Reconciliation Issues',
    icon: Icons.sync_problem_outlined,
    requiredPermission: 'mobile_shop:imei:view',
    showZeroForEmpty: true,
    filterRoute: '/mobile-shop/reconciliation',
    filterParams: {'status': 'failed'},
  ),

  // ── Return KPIs ──────────────────────────────────────────────────────────
  KpiMetricConfig(
    metric: KpiMetric.returnsTotal,
    title: 'Returns',
    icon: Icons.assignment_return_outlined,
    requiredPermission: 'mobile_shop:imei:view',
    requiredFeature: 'IMEI_TRACKING',
    filterRoute: '/mobile-shop/inventory',
    filterParams: {'lifecycle': 'RETURNED'},
  ),

  // ── Finance KPIs ─────────────────────────────────────────────────────────
  KpiMetricConfig(
    metric: KpiMetric.financeActive,
    title: 'Active Finance Plans',
    icon: Icons.account_balance_outlined,
    requiredPermission: 'mobile_shop:finance:view',
    requiredFeature: 'FINANCE_PLANS',
    filterRoute: '/mobile-shop/finance',
    filterParams: {'status': 'active'},
  ),
];

/// Lookup a [KpiMetricConfig] by metric identifier.
KpiMetricConfig? findKpiConfig(KpiMetric metric) {
  for (final config in kKpiMetricConfigs) {
    if (config.metric == metric) return config;
  }
  return null;
}
