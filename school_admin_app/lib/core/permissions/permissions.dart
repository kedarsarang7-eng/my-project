// Centralized RBAC matrix for school_admin_app.
//
// This is the single source-of-truth for role -> permitted-action mapping
// in the admin app. Every entry point (drawer item, deep link, action
// button, search result) MUST consult `Permissions.has` before exposing
// a destination, satisfying clause 2.13 of `bugfix.md`.
//
// Roles match the documented matrix in the design doc:
//   - principal:  full access (school admin)
//   - admin:      all admin features except destructive ones
//   - accountant: fees + payments + ledger only
//   - viewer:     read-only across all features

/// Role for the currently-signed-in user.
enum AdminRole { principal, admin, accountant, viewer }

/// Discrete permissions consulted across the app.
enum AdminPermission {
  // Students
  viewStudents,
  manageStudents,
  // Faculty / staff
  viewFaculty,
  manageFaculty,
  // Fees / payments
  viewFees,
  manageFees,
  recordPayment,
  // Announcements / notifications
  viewAnnouncements,
  publishAnnouncements,
  // Reports / settings
  viewReports,
  manageSettings,
  // Destructive
  deleteRecords,
}

/// Static role -> permission matrix. Keep alphabetised within each set so
/// future diffs are easy to read.
class Permissions {
  Permissions._();

  static const Map<AdminRole, Set<AdminPermission>> _matrix = {
    AdminRole.principal: {
      AdminPermission.viewStudents,
      AdminPermission.manageStudents,
      AdminPermission.viewFaculty,
      AdminPermission.manageFaculty,
      AdminPermission.viewFees,
      AdminPermission.manageFees,
      AdminPermission.recordPayment,
      AdminPermission.viewAnnouncements,
      AdminPermission.publishAnnouncements,
      AdminPermission.viewReports,
      AdminPermission.manageSettings,
      AdminPermission.deleteRecords,
    },
    AdminRole.admin: {
      AdminPermission.viewStudents,
      AdminPermission.manageStudents,
      AdminPermission.viewFaculty,
      AdminPermission.manageFaculty,
      AdminPermission.viewFees,
      AdminPermission.manageFees,
      AdminPermission.recordPayment,
      AdminPermission.viewAnnouncements,
      AdminPermission.publishAnnouncements,
      AdminPermission.viewReports,
      AdminPermission.manageSettings,
    },
    AdminRole.accountant: {
      AdminPermission.viewStudents,
      AdminPermission.viewFees,
      AdminPermission.manageFees,
      AdminPermission.recordPayment,
      AdminPermission.viewReports,
    },
    AdminRole.viewer: {
      AdminPermission.viewStudents,
      AdminPermission.viewFaculty,
      AdminPermission.viewFees,
      AdminPermission.viewAnnouncements,
      AdminPermission.viewReports,
    },
  };

  /// Returns true when [role] is granted [permission].
  static bool has(AdminRole role, AdminPermission permission) {
    return _matrix[role]?.contains(permission) ?? false;
  }

  /// All permissions granted to [role]. Returned set is unmodifiable.
  static Set<AdminPermission> grants(AdminRole role) {
    return Set.unmodifiable(_matrix[role] ?? const <AdminPermission>{});
  }

  /// Convenience for entry-point gating: any-of semantics.
  static bool hasAny(AdminRole role, Iterable<AdminPermission> permissions) {
    return permissions.any((p) => has(role, p));
  }

  /// Convenience for sensitive screens: all-of semantics.
  static bool hasAll(AdminRole role, Iterable<AdminPermission> permissions) {
    return permissions.every((p) => has(role, p));
  }
}
