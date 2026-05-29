// Centralized RBAC matrix for school_teacher_app.
//
// Single source-of-truth for role -> permitted-action mapping in the
// teacher app. Every entry point (drawer item, deep link, action button,
// search result) MUST consult `Permissions.has` before exposing a
// destination, satisfying clause 2.13 of `bugfix.md`.
//
// Roles align with the documented matrix:
//   - teacher:        teach own classes (attendance, homework, exams)
//   - classTeacher:   teacher + class-level operations (announcements)
//   - headOfDept:     classTeacher + department-level review actions

/// Role for the currently-signed-in teacher.
enum TeacherRole { teacher, classTeacher, headOfDept }

/// Discrete permissions consulted across the app.
enum TeacherPermission {
  // Attendance
  viewAttendance,
  markAttendance,
  // Homework / lesson plans / materials
  viewHomework,
  assignHomework,
  viewLessonPlans,
  manageLessonPlans,
  viewMaterials,
  manageMaterials,
  // Exams
  viewExams,
  manageExams,
  enterMarks,
  // Announcements / leave
  viewAnnouncements,
  publishAnnouncements,
  viewLeave,
  approveLeave,
  // Profile
  viewProfile,
}

/// Static role -> permission matrix.
class Permissions {
  Permissions._();

  static const Map<TeacherRole, Set<TeacherPermission>> _matrix = {
    TeacherRole.teacher: {
      TeacherPermission.viewAttendance,
      TeacherPermission.markAttendance,
      TeacherPermission.viewHomework,
      TeacherPermission.assignHomework,
      TeacherPermission.viewLessonPlans,
      TeacherPermission.manageLessonPlans,
      TeacherPermission.viewMaterials,
      TeacherPermission.manageMaterials,
      TeacherPermission.viewExams,
      TeacherPermission.enterMarks,
      TeacherPermission.viewAnnouncements,
      TeacherPermission.viewLeave,
      TeacherPermission.viewProfile,
    },
    TeacherRole.classTeacher: {
      TeacherPermission.viewAttendance,
      TeacherPermission.markAttendance,
      TeacherPermission.viewHomework,
      TeacherPermission.assignHomework,
      TeacherPermission.viewLessonPlans,
      TeacherPermission.manageLessonPlans,
      TeacherPermission.viewMaterials,
      TeacherPermission.manageMaterials,
      TeacherPermission.viewExams,
      TeacherPermission.manageExams,
      TeacherPermission.enterMarks,
      TeacherPermission.viewAnnouncements,
      TeacherPermission.publishAnnouncements,
      TeacherPermission.viewLeave,
      TeacherPermission.viewProfile,
    },
    TeacherRole.headOfDept: {
      TeacherPermission.viewAttendance,
      TeacherPermission.markAttendance,
      TeacherPermission.viewHomework,
      TeacherPermission.assignHomework,
      TeacherPermission.viewLessonPlans,
      TeacherPermission.manageLessonPlans,
      TeacherPermission.viewMaterials,
      TeacherPermission.manageMaterials,
      TeacherPermission.viewExams,
      TeacherPermission.manageExams,
      TeacherPermission.enterMarks,
      TeacherPermission.viewAnnouncements,
      TeacherPermission.publishAnnouncements,
      TeacherPermission.viewLeave,
      TeacherPermission.approveLeave,
      TeacherPermission.viewProfile,
    },
  };

  /// Returns true when [role] is granted [permission].
  static bool has(TeacherRole role, TeacherPermission permission) {
    return _matrix[role]?.contains(permission) ?? false;
  }

  /// All permissions granted to [role]. Returned set is unmodifiable.
  static Set<TeacherPermission> grants(TeacherRole role) {
    return Set.unmodifiable(_matrix[role] ?? const <TeacherPermission>{});
  }

  /// Convenience for entry-point gating: any-of semantics.
  static bool hasAny(
      TeacherRole role, Iterable<TeacherPermission> permissions) {
    return permissions.any((p) => has(role, p));
  }

  /// Convenience for sensitive screens: all-of semantics.
  static bool hasAll(
      TeacherRole role, Iterable<TeacherPermission> permissions) {
    return permissions.every((p) => has(role, p));
  }
}
