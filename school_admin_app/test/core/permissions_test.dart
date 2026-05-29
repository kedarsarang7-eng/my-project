// Reproduction + regression test for D8-school_admin_app-no-rbac-module
// (clause 2.13 of `bugfix.md`).
//
// On F (no Permissions class) this test fails to compile. On F' it passes,
// proving the centralized matrix exists and enforces the documented
// role-action grid.

import 'package:flutter_test/flutter_test.dart';
import 'package:school_admin_app/core/permissions/permissions.dart';

void main() {
  group('AdminApp RBAC matrix', () {
    test('principal is granted every permission', () {
      for (final p in AdminPermission.values) {
        expect(
          Permissions.has(AdminRole.principal, p),
          isTrue,
          reason: 'principal should be granted $p',
        );
      }
    });

    test('viewer is denied every manage / destructive permission', () {
      const denied = <AdminPermission>[
        AdminPermission.manageStudents,
        AdminPermission.manageFaculty,
        AdminPermission.manageFees,
        AdminPermission.recordPayment,
        AdminPermission.publishAnnouncements,
        AdminPermission.manageSettings,
        AdminPermission.deleteRecords,
      ];
      for (final p in denied) {
        expect(
          Permissions.has(AdminRole.viewer, p),
          isFalse,
          reason: 'viewer must not be granted $p',
        );
      }
    });

    test('accountant has finance permissions but not faculty management', () {
      expect(Permissions.has(AdminRole.accountant, AdminPermission.viewFees),
          isTrue);
      expect(Permissions.has(AdminRole.accountant, AdminPermission.manageFees),
          isTrue);
      expect(
          Permissions.has(AdminRole.accountant, AdminPermission.recordPayment),
          isTrue);
      expect(
          Permissions.has(AdminRole.accountant, AdminPermission.manageFaculty),
          isFalse);
      expect(
          Permissions.has(AdminRole.accountant, AdminPermission.deleteRecords),
          isFalse);
    });

    test('only principal can deleteRecords', () {
      for (final r in AdminRole.values) {
        final expected = r == AdminRole.principal;
        expect(
          Permissions.has(r, AdminPermission.deleteRecords),
          expected,
          reason: 'deleteRecords expected=$expected for $r',
        );
      }
    });

    test('hasAny / hasAll convenience helpers behave correctly', () {
      expect(
        Permissions.hasAny(AdminRole.viewer, const [
          AdminPermission.deleteRecords,
          AdminPermission.viewFees,
        ]),
        isTrue,
      );
      expect(
        Permissions.hasAll(AdminRole.viewer, const [
          AdminPermission.viewFees,
          AdminPermission.manageFees,
        ]),
        isFalse,
      );
    });
  });
}
