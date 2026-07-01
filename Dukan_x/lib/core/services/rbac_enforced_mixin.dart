// ============================================================================
// RBAC ENFORCED MIXIN
// ============================================================================
// Mixin for service-layer classes that need RBAC enforcement before CRUD ops.
//
// Usage:
//   class BillService with RbacEnforcedMixin {
//     @override
//     AccessControlService get accessControl => sl<AccessControlService>();
//
//     Future<void> createBill(BillData data) async {
//       await enforcePermission(Permission.createBill);
//       // ... existing Firestore write logic (unchanged)
//     }
//   }
//
// This mixin adds a thin permission-check layer BEFORE writes — it does NOT
// modify existing Firestore write patterns or data flow.
// ============================================================================

import '../../services/role_management_service.dart';
import 'access_control_service.dart';

export 'access_control_service.dart' show AccessDeniedException;

/// Mixin that provides RBAC enforcement helpers for service-layer classes.
///
/// Services using this mixin can call [enforcePermission] or [canPerform]
/// before executing any CRUD operation. The mixin delegates to
/// [AccessControlService] which reads the current user's effective role
/// from [SessionManager].
///
/// Key guarantee: This mixin only adds a permission check layer. It does NOT
/// modify existing Firestore write patterns or data access.
mixin RbacEnforcedMixin {
  /// Subclasses must provide the [AccessControlService] instance.
  AccessControlService get accessControl;

  /// Check if the current user can perform [action].
  ///
  /// Returns `true` if allowed, `false` otherwise.
  /// Does not throw — use [enforcePermission] for throwing behavior.
  bool canPerform(Permission action) {
    return accessControl.canPerform(action);
  }

  /// Enforce that the current user has [action] permission.
  ///
  /// Throws [AccessDeniedException] if the user's effective role does not
  /// include the given permission. Also logs the denial for audit.
  ///
  /// Call this at the top of any CRUD method BEFORE the Firestore write:
  /// ```dart
  /// Future<void> deleteBill(String billId) async {
  ///   await enforcePermission(Permission.deleteBill);
  ///   // existing delete logic...
  /// }
  /// ```
  Future<void> enforcePermission(Permission action) async {
    await accessControl.enforcePermission(action);
  }

  /// Synchronous enforcement — throws immediately without audit logging.
  ///
  /// Use when async is not available. Prefer [enforcePermission].
  void enforcePermissionSync(Permission action) {
    accessControl.enforcePermissionSync(action);
  }

  /// Enforce one of several permissions (any match grants access).
  ///
  /// Throws [AccessDeniedException] for the first permission in [actions]
  /// if NONE of the listed permissions are granted.
  Future<void> enforceAnyPermission(List<Permission> actions) async {
    for (final action in actions) {
      if (accessControl.canPerform(action)) return;
    }
    // None matched — enforce the first one to generate the denial
    await accessControl.enforcePermission(actions.first);
  }
}
