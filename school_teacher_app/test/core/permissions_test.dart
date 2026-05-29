// Reproduction + regression test for D8-school_teacher_app-no-rbac-module
// (clause 2.13 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:school_teacher_app/core/permissions/permissions.dart';

void main() {
  group('TeacherApp RBAC matrix', () {
    test('plain teacher cannot publish announcements or approve leave', () {
      expect(
        Permissions.has(
            TeacherRole.teacher, TeacherPermission.publishAnnouncements),
        isFalse,
      );
      expect(
        Permissions.has(TeacherRole.teacher, TeacherPermission.approveLeave),
        isFalse,
      );
    });

    test('classTeacher can publish announcements but not approve leave', () {
      expect(
        Permissions.has(
            TeacherRole.classTeacher, TeacherPermission.publishAnnouncements),
        isTrue,
      );
      expect(
        Permissions.has(
            TeacherRole.classTeacher, TeacherPermission.approveLeave),
        isFalse,
      );
    });

    test('headOfDept can approve leave', () {
      expect(
        Permissions.has(TeacherRole.headOfDept, TeacherPermission.approveLeave),
        isTrue,
      );
    });

    test('every role can mark attendance and enter marks', () {
      for (final r in TeacherRole.values) {
        expect(Permissions.has(r, TeacherPermission.markAttendance), isTrue);
        expect(Permissions.has(r, TeacherPermission.enterMarks), isTrue);
      }
    });
  });
}
