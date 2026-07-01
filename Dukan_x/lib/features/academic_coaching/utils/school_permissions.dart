// ============================================================================
// SCHOOL-SPECIFIC PERMISSION LAYER
// ============================================================================
// Scoped permission mapping for the schoolErp vertical.
//
// This is a SEPARATE layer — it does NOT modify the global UserRole enum.
// It maps existing UserRole values to school-specific permissions via a
// total pure function: hasSchoolPermission(UserRole, SchoolPermission) -> bool.
//
// Used by: sidebar filter (sidebarSectionsProvider), /ac/* route guards.
// ============================================================================

import '../../../core/models/user_role.dart';

/// School-specific permissions scoped to the schoolErp vertical.
///
/// Each value represents a distinct school operation that can be gated
/// per user role without touching the global [UserRole] enum.
enum SchoolPermission {
  viewStudents,
  viewFees,
  collectFees,
  markAttendance,
  enterMarks,
  viewStudentPII,
  exportStudentPII,
}

/// Role → permission mapping for the schoolErp vertical.
///
/// - owner: ALL permissions
/// - manager: ALL permissions
/// - staff: viewStudents, markAttendance, enterMarks
/// - accountant: viewStudents, viewFees, collectFees
///
/// Any unmapped (role, permission) pair returns `false` (deny-by-default).
const Map<UserRole, Set<SchoolPermission>> _schoolPermissionMap = {
  UserRole.owner: {
    SchoolPermission.viewStudents,
    SchoolPermission.viewFees,
    SchoolPermission.collectFees,
    SchoolPermission.markAttendance,
    SchoolPermission.enterMarks,
    SchoolPermission.viewStudentPII,
    SchoolPermission.exportStudentPII,
  },
  UserRole.manager: {
    SchoolPermission.viewStudents,
    SchoolPermission.viewFees,
    SchoolPermission.collectFees,
    SchoolPermission.markAttendance,
    SchoolPermission.enterMarks,
    SchoolPermission.viewStudentPII,
    SchoolPermission.exportStudentPII,
  },
  UserRole.staff: {
    SchoolPermission.viewStudents,
    SchoolPermission.markAttendance,
    SchoolPermission.enterMarks,
  },
  UserRole.accountant: {
    SchoolPermission.viewStudents,
    SchoolPermission.viewFees,
    SchoolPermission.collectFees,
  },
};

/// Returns `true` if the given [role] holds the specified school [permission].
///
/// This is a total pure function — it returns `false` (deny-by-default) for
/// any (role, permission) pair not explicitly mapped above, including roles
/// like `pharmacist`, `waiter`, `chef`, etc. that have no school access.
///
/// Reusable by both the sidebar filter and the /ac/* route guards.
bool hasSchoolPermission(UserRole role, SchoolPermission permission) {
  final grants = _schoolPermissionMap[role];
  if (grants == null) return false;
  return grants.contains(permission);
}
