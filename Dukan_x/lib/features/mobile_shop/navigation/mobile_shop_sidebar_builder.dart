/// MobileShop Sidebar Builder — TenantContext-Based Filtering (Dart)
///
/// Builds the mobileShop sidebar by filtering [MobileShopRouteCatalog]
/// entries against the resolved [TenantContext]. Entries are excluded when:
///   - The required permission is not in the context's permission set
///   - The required capability is absent from tenant metadata
///   - The entry is feature-gated and the feature is not enabled
///
/// This replaces the generic `_getRetailSections()` path for mobileShop,
/// providing a data-driven, declarative sidebar without hardcoded if/else.
///
/// The same filtering logic applies uniformly to sidebar, quick actions,
/// deep links, and named routes (task 13.2 wires routing).
///
/// Requirements: 2.1–2.3, 8.3, 8.6
/// Audit: AF-01–AF-04, AF-22–AF-26, AF-48
library;

import 'package:flutter/material.dart';

import '../auth/tenant_context.dart';
import 'mobile_shop_route_catalog.dart';
import 'mobile_shop_route_entry.dart';

/// A visible sidebar section after filtering.
///
/// Contains only entries that the current tenant has permission and
/// capability to access.
@immutable
class MobileShopSidebarSection {
  /// The category this section represents.
  final MobileShopRouteCategory category;

  /// Section display title.
  final String title;

  /// Section icon.
  final IconData icon;

  /// Visible entries within this section (already filtered).
  final List<MobileShopRouteEntry> entries;

  const MobileShopSidebarSection({
    required this.category,
    required this.title,
    required this.icon,
    required this.entries,
  });

  /// Whether this section has any visible entries.
  bool get isNotEmpty => entries.isNotEmpty;
}

/// Builds the mobileShop sidebar from the route catalog.
///
/// All filtering is data-driven: entries declare their own permission,
/// capability, and feature-gate requirements. The builder evaluates each
/// entry against the [TenantContext] and optional capability/feature
/// metadata and returns only the sections with visible entries.
///
/// Usage:
/// ```dart
/// final builder = MobileShopSidebarBuilder();
/// final sections = builder.buildSidebar(
///   context: tenantContext,
///   capabilities: {'useIMEI', 'useWarranty', 'useJobSheets'},
/// );
/// ```
class MobileShopSidebarBuilder {
  const MobileShopSidebarBuilder();

  /// Builds sidebar sections from the catalog, filtered by tenant context.
  ///
  /// [context] — The resolved TenantContext (must be mobileShop).
  /// [capabilities] — Active capability strings for the tenant (e.g. 'useIMEI').
  /// [enabledFeatures] — Feature flag identifiers that are currently enabled.
  ///
  /// Returns ordered sections with only visible entries. Empty sections
  /// are excluded. Quick-action entries are included in their category
  /// section but also available separately via [buildQuickActions].
  List<MobileShopSidebarSection> buildSidebar({
    required TenantContext context,
    Set<String> capabilities = const {},
    Set<String> enabledFeatures = const {},
  }) {
    final visibleEntries = _filterEntries(
      entries: MobileShopRouteCatalog.all,
      context: context,
      capabilities: capabilities,
      enabledFeatures: enabledFeatures,
    );

    return _groupIntoSections(visibleEntries);
  }

  /// Returns only the quick-action entries visible to the current tenant.
  ///
  /// Uses the same filtering logic as [buildSidebar].
  List<MobileShopRouteEntry> buildQuickActions({
    required TenantContext context,
    Set<String> capabilities = const {},
    Set<String> enabledFeatures = const {},
  }) {
    return _filterEntries(
      entries: MobileShopRouteCatalog.quickActions,
      context: context,
      capabilities: capabilities,
      enabledFeatures: enabledFeatures,
    );
  }

  /// Checks if a specific route entry is accessible to the tenant.
  ///
  /// Useful for deep link and named route guards.
  bool isEntryAccessible({
    required MobileShopRouteEntry entry,
    required TenantContext context,
    Set<String> capabilities = const {},
    Set<String> enabledFeatures = const {},
  }) {
    return _isVisible(
      entry: entry,
      context: context,
      capabilities: capabilities,
      enabledFeatures: enabledFeatures,
    );
  }

  /// Finds an entry by id, or null if not in the catalog.
  MobileShopRouteEntry? findById(String id) {
    for (final entry in MobileShopRouteCatalog.all) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  /// Filters entries by permission, capability, and feature gate.
  List<MobileShopRouteEntry> _filterEntries({
    required List<MobileShopRouteEntry> entries,
    required TenantContext context,
    required Set<String> capabilities,
    required Set<String> enabledFeatures,
  }) {
    return entries.where((entry) {
      return _isVisible(
        entry: entry,
        context: context,
        capabilities: capabilities,
        enabledFeatures: enabledFeatures,
      );
    }).toList();
  }

  /// Evaluates visibility of a single entry against context.
  bool _isVisible({
    required MobileShopRouteEntry entry,
    required TenantContext context,
    required Set<String> capabilities,
    required Set<String> enabledFeatures,
  }) {
    // 1. Business type must be mobileShop
    if (!context.isMobileShop) return false;

    // 2. Required permission must be granted
    if (entry.requiredPermission != null &&
        !context.hasPermission(entry.requiredPermission!)) {
      return false;
    }

    // 3. Required capability must be present
    if (entry.requiredCapability != null &&
        !capabilities.contains(entry.requiredCapability!)) {
      return false;
    }

    // 4. Feature-gated entries require the feature to be enabled
    if (entry.isFeatureGated && !enabledFeatures.contains(entry.id)) {
      return false;
    }

    return true;
  }

  /// Groups filtered entries into sidebar sections by category.
  ///
  /// Sections with no visible entries are excluded from the result.
  /// Sections are ordered by the category enum declaration order.
  List<MobileShopSidebarSection> _groupIntoSections(
    List<MobileShopRouteEntry> entries,
  ) {
    final grouped = <MobileShopRouteCategory, List<MobileShopRouteEntry>>{};

    for (final entry in entries) {
      grouped.putIfAbsent(entry.category, () => []).add(entry);
    }

    // Sort entries within each category by sortOrder
    for (final list in grouped.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // Build sections in category enum order, exclude empty
    final sections = <MobileShopSidebarSection>[];
    for (final category in MobileShopRouteCategory.values) {
      final categoryEntries = grouped[category];
      if (categoryEntries != null && categoryEntries.isNotEmpty) {
        sections.add(
          MobileShopSidebarSection(
            category: category,
            title: category.sectionTitle,
            icon: category.sectionIcon,
            entries: List.unmodifiable(categoryEntries),
          ),
        );
      }
    }

    return sections;
  }
}
