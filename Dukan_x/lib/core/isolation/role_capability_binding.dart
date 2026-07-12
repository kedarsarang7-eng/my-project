/// Role-Capability Binding Registry
///
/// Maps specific [BusinessCapability] values to the set of [UserRole]s that
/// can access them. This is the ROLE-LEVEL gate that complements the
/// BUSINESS-TYPE-LEVEL gate in [FeatureResolver].
///
/// Flow:
///   1. FeatureResolver.canAccess(businessType, capability) → is this capability
///      available to this business type at all?
///   2. RoleCapabilityBinding.canAccess(capability, userRole) → is this specific
///      user's role allowed to use this capability?
///
/// If a capability has NO binding in this registry, it is accessible to ALL
/// roles (preserving existing behaviour for all capabilities that were never
/// role-gated). Only capabilities explicitly listed here are restricted.
///
/// **Requirements: 2.12, 3.9**
library;

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/models/user_role.dart';

/// Central registry of capability → allowed-roles bindings.
///
/// Only capabilities that need role-level restriction are listed here.
/// Unlisted capabilities remain accessible to any role that passes the
/// business-type-level gate (FeatureResolver).
class RoleCapabilityBinding {
  RoleCapabilityBinding._();

  /// The binding table: capability → set of roles allowed to access it.
  ///
  /// Roles NOT in this set are denied access to the capability's gated UI,
  /// even if the business type grants the capability.
  static const Map<BusinessCapability, Set<UserRole>> _bindings = {
    BusinessCapability.useWaiterLinking: {
      UserRole.waiter,
      UserRole.captain,
      UserRole.owner,
      UserRole.manager,
    },
  };

  /// Check if [userRole] can access [capability].
  ///
  /// Returns `true` if:
  ///   - The capability has no binding (no role restriction — all roles pass), OR
  ///   - The capability has a binding and [userRole] is in the allowed set.
  ///
  /// Returns `false` if the capability has a binding and [userRole] is NOT in
  /// the allowed set.
  static bool canAccess(BusinessCapability capability, UserRole userRole) {
    final allowedRoles = _bindings[capability];
    // No binding → unrestricted (all roles pass).
    if (allowedRoles == null) return true;
    return allowedRoles.contains(userRole);
  }

  /// Get the set of roles allowed to access [capability], or null if no
  /// binding exists (meaning all roles are allowed).
  static Set<UserRole>? getAllowedRoles(BusinessCapability capability) {
    return _bindings[capability];
  }

  /// Check if a capability has a role binding defined.
  static bool hasBinding(BusinessCapability capability) {
    return _bindings.containsKey(capability);
  }
}
