// Reproduction + regression test for D8-school_student_app-no-rbac-module
// (clause 2.13 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:school_student_app/core/permissions/permissions.dart';

void main() {
  group('StudentApp RBAC matrix', () {
    test('only parent can pay fees; student can only view', () {
      expect(
        Permissions.has(StudentAppRole.parent, StudentPermission.payFees),
        isTrue,
      );
      expect(
        Permissions.has(StudentAppRole.student, StudentPermission.payFees),
        isFalse,
      );
      // Both can view fees so nothing changes for read-only flows.
      expect(
        Permissions.has(StudentAppRole.student, StudentPermission.viewFees),
        isTrue,
      );
      expect(
        Permissions.has(StudentAppRole.parent, StudentPermission.viewFees),
        isTrue,
      );
    });

    test('every role can view its own profile and results', () {
      for (final r in StudentAppRole.values) {
        expect(Permissions.has(r, StudentPermission.viewOwnProfile), isTrue);
        expect(Permissions.has(r, StudentPermission.viewResults), isTrue);
        expect(
            Permissions.has(r, StudentPermission.downloadReportCard), isTrue);
      }
    });

    test('hasAll requires every requested permission', () {
      expect(
        Permissions.hasAll(StudentAppRole.student, const [
          StudentPermission.viewFees,
          StudentPermission.payFees,
        ]),
        isFalse,
      );
      expect(
        Permissions.hasAll(StudentAppRole.parent, const [
          StudentPermission.viewFees,
          StudentPermission.payFees,
        ]),
        isTrue,
      );
    });
  });
}
