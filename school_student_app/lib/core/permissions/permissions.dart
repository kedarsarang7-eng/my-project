// Centralized RBAC matrix for school_student_app.
//
// Single source-of-truth for role -> permitted-action mapping in the
// student app. Every entry point (drawer item, deep link, action button,
// search result) MUST consult `Permissions.has` before exposing a
// destination, satisfying clause 2.13 of `bugfix.md`.
//
// Roles in the student app are simpler than the admin/teacher matrices:
//   - student: own data only — own profile, own results, own fees
//   - parent:  same set scoped to a linked child (or several)

/// Role for the currently-signed-in user of the student app.
enum StudentAppRole { student, parent }

/// Discrete permissions consulted across the app.
enum StudentPermission {
  // Profile
  viewOwnProfile,
  // Results / report cards
  viewResults,
  downloadReportCard,
  // Fees / payments
  viewFees,
  payFees,
  // Library / leave
  viewLibrary,
  requestLeave,
}

/// Static role -> permission matrix.
class Permissions {
  Permissions._();

  static const Map<StudentAppRole, Set<StudentPermission>> _matrix = {
    StudentAppRole.student: {
      StudentPermission.viewOwnProfile,
      StudentPermission.viewResults,
      StudentPermission.downloadReportCard,
      StudentPermission.viewFees,
      StudentPermission.viewLibrary,
      StudentPermission.requestLeave,
    },
    StudentAppRole.parent: {
      StudentPermission.viewOwnProfile,
      StudentPermission.viewResults,
      StudentPermission.downloadReportCard,
      StudentPermission.viewFees,
      StudentPermission.payFees,
      StudentPermission.viewLibrary,
      StudentPermission.requestLeave,
    },
  };

  /// Returns true when [role] is granted [permission].
  static bool has(StudentAppRole role, StudentPermission permission) {
    return _matrix[role]?.contains(permission) ?? false;
  }

  /// All permissions granted to [role]. Returned set is unmodifiable.
  static Set<StudentPermission> grants(StudentAppRole role) {
    return Set.unmodifiable(_matrix[role] ?? const <StudentPermission>{});
  }

  /// Convenience for entry-point gating: any-of semantics.
  static bool hasAny(
      StudentAppRole role, Iterable<StudentPermission> permissions) {
    return permissions.any((p) => has(role, p));
  }

  /// Convenience for sensitive screens: all-of semantics.
  static bool hasAll(
      StudentAppRole role, Iterable<StudentPermission> permissions) {
    return permissions.every((p) => has(role, p));
  }
}
