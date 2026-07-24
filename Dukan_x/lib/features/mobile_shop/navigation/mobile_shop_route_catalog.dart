/// MobileShop Route Catalog — Complete Data-Driven Navigation Entries (Dart)
///
/// Defines every route entry for the mobileShop sidebar, quick actions,
/// deep links, and named routes. The catalog is purely declarative:
/// each entry carries its own permission, capability, category, and route
/// metadata. The sidebar builder filters entries from this catalog without
/// hardcoded if/else chains.
///
/// Categories:
///   - Inventory & Devices: IMEI Tracking, Serial/IMEI History, Second-Hand Intake
///   - Service & Repair: Service Jobs, Exchanges
///   - Warranty: Warranty Management
///   - Finance: Finance Plans/EMI, SIM/Recharge
///   - Reports: Mobile Reports
///   - Settings: Mobile Shop Settings
///   - Quick Actions: IMEI Lookup
///
/// Requirements: 2.1–2.3, 8.3, 8.6
/// Audit: AF-01–AF-04, AF-22–AF-26, AF-48
library;

import 'package:flutter/material.dart';

import '../permissions/mobile_shop_permissions.dart';
import 'mobile_shop_route_entry.dart';

/// The complete route catalog for the mobileShop business type.
///
/// All entries are statically defined. Filtering by permission, capability,
/// and feature gate is performed by [MobileShopSidebarBuilder].
abstract final class MobileShopRouteCatalog {
  MobileShopRouteCatalog._();

  // ─── Inventory & Devices ─────────────────────────────────────────────────

  static const imeiTracking = MobileShopRouteEntry(
    id: 'imei_tracking',
    label: 'IMEI Tracking',
    icon: Icons.qr_code_scanner_outlined,
    routePath: '/mobile-shop/imei',
    requiredPermission: MobileShopPermissions.imeiView,
    requiredCapability: 'useIMEI',
    category: MobileShopRouteCategory.inventoryAndDevices,
    sortOrder: 0,
  );

  static const serialImeiHistory = MobileShopRouteEntry(
    id: 'serial_imei_history',
    label: 'Serial / IMEI History',
    icon: Icons.history_outlined,
    routePath: '/mobile-shop/imei/history',
    requiredPermission: MobileShopPermissions.imeiView,
    requiredCapability: 'useIMEI',
    category: MobileShopRouteCategory.inventoryAndDevices,
    sortOrder: 1,
  );

  static const secondHandIntake = MobileShopRouteEntry(
    id: 'second_hand_intake',
    label: 'Second-Hand Intake',
    icon: Icons.phone_android_outlined,
    routePath: '/mobile-shop/second-hand',
    requiredPermission: MobileShopPermissions.secondHandManage,
    requiredCapability: 'useBuyback',
    category: MobileShopRouteCategory.inventoryAndDevices,
    sortOrder: 2,
  );

  static const reservations = MobileShopRouteEntry(
    id: 'reservations',
    label: 'Reservations',
    icon: Icons.book_online_outlined,
    routePath: '/mobile-shop/reservations',
    requiredPermission: MobileShopPermissions.imeiManage,
    requiredCapability: 'useIMEI',
    category: MobileShopRouteCategory.inventoryAndDevices,
    sortOrder: 3,
  );

  static const demoUnits = MobileShopRouteEntry(
    id: 'demo_units',
    label: 'Demo Units',
    icon: Icons.devices_other_outlined,
    routePath: '/mobile-shop/demo',
    requiredPermission: MobileShopPermissions.imeiManage,
    requiredCapability: 'useIMEI',
    category: MobileShopRouteCategory.inventoryAndDevices,
    sortOrder: 4,
  );

  static const deviceReturns = MobileShopRouteEntry(
    id: 'device_returns',
    label: 'Device Returns',
    icon: Icons.assignment_return_outlined,
    routePath: '/mobile-shop/returns',
    requiredPermission: MobileShopPermissions.imeiManage,
    requiredCapability: 'useIMEI',
    category: MobileShopRouteCategory.inventoryAndDevices,
    sortOrder: 5,
  );

  // ─── Service & Repair ────────────────────────────────────────────────────

  static const serviceJobs = MobileShopRouteEntry(
    id: 'service_jobs',
    label: 'Service Jobs',
    icon: Icons.build_circle_outlined,
    routePath: '/mobile-shop/service-jobs',
    requiredPermission: MobileShopPermissions.serviceView,
    requiredCapability: 'useJobSheets',
    category: MobileShopRouteCategory.serviceAndRepair,
    sortOrder: 0,
  );

  static const exchanges = MobileShopRouteEntry(
    id: 'exchanges',
    label: 'Exchanges',
    icon: Icons.swap_horiz_outlined,
    routePath: '/mobile-shop/exchanges',
    requiredPermission: MobileShopPermissions.exchangeView,
    requiredCapability: 'useExchange',
    category: MobileShopRouteCategory.serviceAndRepair,
    sortOrder: 1,
  );

  // ─── Warranty ────────────────────────────────────────────────────────────

  static const warrantyManagement = MobileShopRouteEntry(
    id: 'warranty_management',
    label: 'Warranty Management',
    icon: Icons.verified_user_outlined,
    routePath: '/mobile-shop/warranty',
    requiredPermission: MobileShopPermissions.warrantyView,
    requiredCapability: 'useWarranty',
    category: MobileShopRouteCategory.warranty,
    sortOrder: 0,
  );

  // ─── Finance ─────────────────────────────────────────────────────────────

  static const financePlansEmi = MobileShopRouteEntry(
    id: 'finance_plans_emi',
    label: 'Finance Plans / EMI',
    icon: Icons.credit_card_outlined,
    routePath: '/mobile-shop/finance',
    requiredPermission: MobileShopPermissions.financeView,
    isFeatureGated: true,
    category: MobileShopRouteCategory.finance,
    sortOrder: 0,
  );

  static const simRecharge = MobileShopRouteEntry(
    id: 'sim_recharge',
    label: 'SIM / Recharge',
    icon: Icons.sim_card_outlined,
    routePath: '/mobile-shop/sim-recharge',
    isFeatureGated: true,
    category: MobileShopRouteCategory.finance,
    sortOrder: 1,
  );

  // ─── Reports ─────────────────────────────────────────────────────────────

  static const mobileReports = MobileShopRouteEntry(
    id: 'mobile_reports',
    label: 'Mobile Reports',
    icon: Icons.assessment_outlined,
    routePath: '/mobile-shop/reports',
    requiredPermission: MobileShopPermissions.reportsView,
    category: MobileShopRouteCategory.reports,
    sortOrder: 0,
  );

  // ─── Settings ────────────────────────────────────────────────────────────

  static const mobileShopSettings = MobileShopRouteEntry(
    id: 'mobile_shop_settings',
    label: 'Mobile Shop Settings',
    icon: Icons.settings_outlined,
    routePath: '/mobile-shop/settings',
    requiredPermission: MobileShopPermissions.settingsView,
    category: MobileShopRouteCategory.settings,
    sortOrder: 0,
  );

  // ─── Quick Actions ───────────────────────────────────────────────────────

  static const imeiLookup = MobileShopRouteEntry(
    id: 'imei_lookup',
    label: 'IMEI Lookup',
    icon: Icons.search_outlined,
    routePath: '/mobile-shop/imei/lookup',
    requiredPermission: MobileShopPermissions.imeiView,
    requiredCapability: 'useIMEI',
    category: MobileShopRouteCategory.quickActions,
    sortOrder: 0,
    isQuickAction: true,
  );

  // ─── Catalog Accessors ───────────────────────────────────────────────────

  /// All entries in the catalog, ordered by category then sort order.
  static const List<MobileShopRouteEntry> all = [
    // Inventory & Devices
    imeiTracking,
    serialImeiHistory,
    secondHandIntake,
    reservations,
    demoUnits,
    deviceReturns,
    // Service & Repair
    serviceJobs,
    exchanges,
    // Warranty
    warrantyManagement,
    // Finance
    financePlansEmi,
    simRecharge,
    // Reports
    mobileReports,
    // Settings
    mobileShopSettings,
    // Quick Actions
    imeiLookup,
  ];

  /// Only quick-action entries.
  static List<MobileShopRouteEntry> get quickActions =>
      all.where((e) => e.isQuickAction).toList();

  /// Entries grouped by category (preserves declaration order).
  static Map<MobileShopRouteCategory, List<MobileShopRouteEntry>>
  get byCategory {
    final map = <MobileShopRouteCategory, List<MobileShopRouteEntry>>{};
    for (final entry in all) {
      map.putIfAbsent(entry.category, () => []).add(entry);
    }
    return map;
  }
}
