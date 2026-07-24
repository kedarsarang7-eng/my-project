/// MobileShop Compatibility Matrix — Legacy Role Migration (Dart)
///
/// Maps approved legacy roles/capabilities to new MobileShop permissions.
/// This mapping is:
/// - Additive only: never removes existing access
/// - Idempotent: applying multiple times produces the same result
/// - Explicit: each mapping is documented and reviewable
///
/// Requirements: 8.1–8.2, 8.5–8.7, 8.13
library;

import 'mobile_shop_permissions.dart';

// ─── Role-to-Permission Mapping ──────────────────────────────────────────────

/// Maps legacy user roles to MobileShop permissions.
///
/// Note: `manageStaff` previously gated service/repair routes (AF-40).
/// The matrix assigns dedicated service permissions instead.
const Map<String, List<String>> rolePermissionMap = {
  'owner': [
    MobileShopPermissions.serviceView,
    MobileShopPermissions.serviceManage,
    MobileShopPermissions.imeiView,
    MobileShopPermissions.imeiManage,
    MobileShopPermissions.exchangeView,
    MobileShopPermissions.exchangeManage,
    MobileShopPermissions.warrantyView,
    MobileShopPermissions.warrantyManage,
    MobileShopPermissions.secondHandView,
    MobileShopPermissions.secondHandManage,
    MobileShopPermissions.financeView,
    MobileShopPermissions.financeManage,
    MobileShopPermissions.reportsView,
    MobileShopPermissions.reportsExport,
    MobileShopPermissions.settingsView,
    MobileShopPermissions.settingsManage,
    MobileShopPermissions.auditView,
  ],
  'admin': [
    MobileShopPermissions.serviceView,
    MobileShopPermissions.serviceManage,
    MobileShopPermissions.imeiView,
    MobileShopPermissions.imeiManage,
    MobileShopPermissions.exchangeView,
    MobileShopPermissions.exchangeManage,
    MobileShopPermissions.warrantyView,
    MobileShopPermissions.warrantyManage,
    MobileShopPermissions.secondHandView,
    MobileShopPermissions.secondHandManage,
    MobileShopPermissions.financeView,
    MobileShopPermissions.financeManage,
    MobileShopPermissions.reportsView,
    MobileShopPermissions.reportsExport,
    MobileShopPermissions.settingsView,
    MobileShopPermissions.settingsManage,
    MobileShopPermissions.auditView,
  ],
  'manager': [
    MobileShopPermissions.serviceView,
    MobileShopPermissions.serviceManage,
    MobileShopPermissions.imeiView,
    MobileShopPermissions.imeiManage,
    MobileShopPermissions.exchangeView,
    MobileShopPermissions.exchangeManage,
    MobileShopPermissions.warrantyView,
    MobileShopPermissions.warrantyManage,
    MobileShopPermissions.secondHandView,
    MobileShopPermissions.secondHandManage,
    MobileShopPermissions.financeView,
    MobileShopPermissions.reportsView,
    MobileShopPermissions.reportsExport,
    MobileShopPermissions.settingsView,
    MobileShopPermissions.auditView,
  ],
  'accountant': [
    MobileShopPermissions.imeiView,
    MobileShopPermissions.financeView,
    MobileShopPermissions.financeManage,
    MobileShopPermissions.reportsView,
    MobileShopPermissions.reportsExport,
    MobileShopPermissions.settingsView,
  ],
  'cashier': [
    MobileShopPermissions.serviceView,
    MobileShopPermissions.imeiView,
    MobileShopPermissions.exchangeView,
    MobileShopPermissions.warrantyView,
    MobileShopPermissions.secondHandView,
    MobileShopPermissions.financeView,
  ],
  'staff': [
    MobileShopPermissions.serviceView,
    MobileShopPermissions.imeiView,
    MobileShopPermissions.warrantyView,
  ],
};

// ─── Capability-to-Permission Mapping ────────────────────────────────────────

/// Maps legacy capabilities to MobileShop permissions.
const Map<String, List<String>> capabilityPermissionMap = {
  'useIMEI': [MobileShopPermissions.imeiView, MobileShopPermissions.imeiManage],
  'useWarranty': [
    MobileShopPermissions.warrantyView,
    MobileShopPermissions.warrantyManage,
  ],
  'useBuyback': [
    MobileShopPermissions.secondHandView,
    MobileShopPermissions.secondHandManage,
  ],
  'useExchange': [
    MobileShopPermissions.exchangeView,
    MobileShopPermissions.exchangeManage,
  ],
  'useJobSheets': [
    MobileShopPermissions.serviceView,
    MobileShopPermissions.serviceManage,
  ],
  'useRepairStatus': [MobileShopPermissions.serviceView],
};

// ─── Legacy Permission Mapping ───────────────────────────────────────────────

/// Maps old generic permission strings to MobileShop equivalents.
/// Addresses AF-40 where `manage_staff` gated service/repair routes.
const Map<String, List<String>> legacyPermissionMap = {
  'manage_staff': [
    MobileShopPermissions.serviceView,
    MobileShopPermissions.serviceManage,
  ],
  'view_invoices': [MobileShopPermissions.imeiView],
  'create_invoices': [
    MobileShopPermissions.imeiView,
    MobileShopPermissions.imeiManage,
  ],
  'view_reports': [MobileShopPermissions.reportsView],
  'export_reports': [
    MobileShopPermissions.reportsView,
    MobileShopPermissions.reportsExport,
  ],
};

// ─── Migration Result ────────────────────────────────────────────────────────

/// Result of an idempotent permission migration.
class MigrationResult {
  /// The final permission set (superset of current + migrated).
  final List<String> permissions;

  /// Permissions that were added (empty if already migrated).
  final List<String> added;

  /// Whether any changes were made.
  final bool changed;

  const MigrationResult({
    required this.permissions,
    required this.added,
    required this.changed,
  });
}

// ─── Idempotent Migration Function ──────────────────────────────────────────

/// Computes the migrated permission set for a mobile-shop user.
///
/// This function is idempotent: calling it multiple times with the same input
/// produces the same output. It never removes existing permissions — only adds
/// new ones based on the role and capability mappings.
///
/// [currentPermissions] - permissions already assigned to the user
/// [role] - the user's legacy role identifier
/// [capabilities] - legacy capabilities enabled for the tenant
MigrationResult migratePermissions({
  required List<String> currentPermissions,
  required String role,
  required List<String> capabilities,
}) {
  final existing = <String>{...currentPermissions};

  // 1. Add permissions from the role mapping
  final rolePerms = rolePermissionMap[role];
  if (rolePerms != null) {
    existing.addAll(rolePerms);
  }

  // 2. Add permissions from active capabilities
  for (final cap in capabilities) {
    final capPerms = capabilityPermissionMap[cap];
    if (capPerms != null) {
      existing.addAll(capPerms);
    }
  }

  // 3. Add permissions from legacy permission strings already present
  for (final legacyPerm in currentPermissions) {
    final mapped = legacyPermissionMap[legacyPerm];
    if (mapped != null) {
      existing.addAll(mapped);
    }
  }

  final finalPermissions = existing.toList()..sort();
  final added = finalPermissions
      .where((p) => !currentPermissions.contains(p))
      .toList();

  return MigrationResult(
    permissions: finalPermissions,
    added: added,
    changed: added.isNotEmpty,
  );
}
