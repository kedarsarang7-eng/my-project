/// MobileShop Permission Checker (Dart)
///
/// Utility to check permissions from TenantContext on the client side.
/// Respects manage-implies-view semantics.
///
/// Requirements: 8.1–8.2, 8.5–8.7
library;

import '../models/common_models.dart';
import 'mobile_shop_permissions.dart';

/// Result of a permission check.
class PermissionCheckResult {
  /// Whether the permission is granted.
  final bool granted;

  /// Reason for denial (null if granted).
  final String? reason;

  const PermissionCheckResult._({required this.granted, this.reason});

  const PermissionCheckResult.allowed() : this._(granted: true);

  const PermissionCheckResult.denied(String reason)
    : this._(granted: false, reason: reason);
}

/// Expands a set of permissions with manage-implies-view semantics.
///
/// If the set contains a `manage` permission, the corresponding `view`
/// permission is added automatically.
Set<String> expandPermissions(Iterable<String> granted) {
  final expanded = <String>{...granted};
  for (final entry in MobileShopPermissions.implications.entries) {
    if (expanded.contains(entry.key)) {
      expanded.add(entry.value);
    }
  }
  return expanded;
}

/// Checks whether the given [context] has a specific MobileShop permission.
///
/// This checker:
/// 1. Validates the business type is `mobile_shop`
/// 2. Expands permissions (manage implies view)
/// 3. Checks the required permission against the expanded set
PermissionCheckResult checkMobileShopPermission(
  TenantContextWire context,
  String required,
) {
  if (context.businessType != 'mobile_shop') {
    return const PermissionCheckResult.denied(
      'Business type is not mobile_shop',
    );
  }

  final effective = expandPermissions(context.permissions);

  if (effective.contains(required)) {
    return const PermissionCheckResult.allowed();
  }

  return PermissionCheckResult.denied('Missing required permission: $required');
}

/// Checks whether the context has ALL of the specified permissions.
PermissionCheckResult checkAllPermissions(
  TenantContextWire context,
  List<String> required,
) {
  if (context.businessType != 'mobile_shop') {
    return const PermissionCheckResult.denied(
      'Business type is not mobile_shop',
    );
  }

  final effective = expandPermissions(context.permissions);
  final missing = required.where((p) => !effective.contains(p)).toList();

  if (missing.isEmpty) {
    return const PermissionCheckResult.allowed();
  }

  return PermissionCheckResult.denied(
    'Missing required permissions: ${missing.join(', ')}',
  );
}

/// Checks whether the context has ANY of the specified permissions.
PermissionCheckResult checkAnyPermission(
  TenantContextWire context,
  List<String> required,
) {
  if (context.businessType != 'mobile_shop') {
    return const PermissionCheckResult.denied(
      'Business type is not mobile_shop',
    );
  }

  final effective = expandPermissions(context.permissions);
  final granted = required.any((p) => effective.contains(p));

  if (granted) {
    return const PermissionCheckResult.allowed();
  }

  return PermissionCheckResult.denied(
    'None of the required permissions present: ${required.join(', ')}',
  );
}

/// Returns all MobileShop permissions effectively granted to the context,
/// after expanding implications.
Set<String> getEffectiveMobileShopPermissions(TenantContextWire context) {
  if (context.businessType != 'mobile_shop') {
    return {};
  }

  final effective = expandPermissions(context.permissions);

  // Filter to only known MobileShop permissions
  return effective.where((p) => MobileShopPermissions.all.contains(p)).toSet();
}

/// Validates that a given string is a recognized MobileShop permission.
bool isValidMobileShopPermission(String value) {
  return MobileShopPermissions.all.contains(value);
}
