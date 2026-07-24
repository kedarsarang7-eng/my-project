/// MobileShop Route Entry — Data-Driven Navigation Model (Dart)
///
/// Defines the route entry model and category enum for the dedicated
/// mobileShop sidebar catalog. Every entry declares business type,
/// capability, permission, route, and category metadata.
///
/// Requirements: 2.1–2.3, 8.3, 8.6
/// Audit: AF-01–AF-04, AF-22–AF-26, AF-48
library;

import 'package:flutter/material.dart';

/// Categories for grouping mobile shop route entries in the sidebar.
enum MobileShopRouteCategory {
  /// IMEI tracking, serial history, second-hand intake.
  inventoryAndDevices,

  /// Service jobs, exchanges.
  serviceAndRepair,

  /// Warranty management.
  warranty,

  /// Finance plans, EMI, SIM/recharge.
  finance,

  /// Mobile-specific reports.
  reports,

  /// Mobile shop settings.
  settings,

  /// Quick actions (IMEI lookup, etc.).
  quickActions,
}

/// Extension for display metadata on [MobileShopRouteCategory].
extension MobileShopRouteCategoryX on MobileShopRouteCategory {
  /// Human-readable section title for the sidebar.
  String get sectionTitle => switch (this) {
    MobileShopRouteCategory.inventoryAndDevices => 'Inventory & Devices',
    MobileShopRouteCategory.serviceAndRepair => 'Service & Repair',
    MobileShopRouteCategory.warranty => 'Warranty',
    MobileShopRouteCategory.finance => 'Finance',
    MobileShopRouteCategory.reports => 'Reports',
    MobileShopRouteCategory.settings => 'Settings',
    MobileShopRouteCategory.quickActions => 'Quick Actions',
  };

  /// Icon for the section header.
  IconData get sectionIcon => switch (this) {
    MobileShopRouteCategory.inventoryAndDevices => Icons.inventory_2_rounded,
    MobileShopRouteCategory.serviceAndRepair => Icons.build_rounded,
    MobileShopRouteCategory.warranty => Icons.verified_user_rounded,
    MobileShopRouteCategory.finance => Icons.account_balance_rounded,
    MobileShopRouteCategory.reports => Icons.assessment_rounded,
    MobileShopRouteCategory.settings => Icons.settings_rounded,
    MobileShopRouteCategory.quickActions => Icons.flash_on_rounded,
  };
}

/// A single route entry in the dedicated mobileShop navigation catalog.
///
/// Each entry is self-describing: it carries the capability, permission,
/// route path, category, and sort order needed for data-driven filtering.
/// No hardcoded if/else chains are needed — the sidebar builder filters
/// entries purely from this metadata.
@immutable
class MobileShopRouteEntry {
  /// Stable unique identifier for the entry (used for selection state).
  final String id;

  /// Human-readable label shown in the sidebar.
  final String label;

  /// Icon displayed alongside the label.
  final IconData icon;

  /// The GoRouter route path this entry navigates to.
  final String routePath;

  /// Permission required to see/use this entry.
  /// Null means no specific permission needed beyond business type.
  final String? requiredPermission;

  /// Capability required (e.g. 'useIMEI', 'useWarranty').
  /// Null means the entry is always visible for mobileShop tenants.
  final String? requiredCapability;

  /// Whether this entry is feature-gated (requires a feature flag).
  /// Feature-gated entries are hidden until the feature is enabled.
  final bool isFeatureGated;

  /// The category this entry belongs to in the sidebar.
  final MobileShopRouteCategory category;

  /// Sort order within the category (lower = higher in the list).
  final int sortOrder;

  /// Whether this entry appears as a quick action.
  final bool isQuickAction;

  const MobileShopRouteEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.routePath,
    this.requiredPermission,
    this.requiredCapability,
    this.isFeatureGated = false,
    required this.category,
    required this.sortOrder,
    this.isQuickAction = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MobileShopRouteEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MobileShopRouteEntry($id, category: ${category.name}, '
      'permission: $requiredPermission, capability: $requiredCapability)';
}
