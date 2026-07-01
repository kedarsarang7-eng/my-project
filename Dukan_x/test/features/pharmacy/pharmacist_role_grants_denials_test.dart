// ============================================================================
// PHASE 2 — Task 7.3: EXAMPLE-BASED UNIT TESTS
// Feature: pharmacy-vertical-remediation
// Pharmacist role grants / denials.
// **Validates: Requirements 10.1, 10.8**
// ============================================================================
//
// Scope (example-based companion to the Property 14 test in
// `property14_pharmacist_permission_set_test.dart`):
//
//   Requirement 10.1 — THE UserRole SHALL include a `pharmacist` role value
//   distinct from all other existing role values.
//
//   Requirement 10.8 — THE System SHALL include automated tests that verify
//   every granted permission (10.2) is allowed for the `pharmacist` role and
//   every excluded permission (10.3) is denied for the `pharmacist` role.
//
// These are concrete, enumerated example assertions (not generated cases):
//   * `UserRole.pharmacist` exists in the enum and is `!=` every other role.
//   * Each of the five granted permissions resolves to ALLOWED.
//   * Each excluded permission (pricing override, business settings, financial
//     reports, user management) resolves to DENIED.
//
// Both `RolePermissions` matrices are checked, since the pharmacist set lives
// in two distinct `Permission` enums + classes:
//   - lib/core/services/role_management_service.dart      (alias `core`)
//   - lib/services/role_management_service.dart           (alias `svc`)
//
// Run: flutter test test/features/pharmacy/pharmacist_role_grants_denials_test.dart
// ============================================================================

import 'package:dukanx/core/models/user_role.dart';
import 'package:dukanx/core/services/role_management_service.dart' as core;
import 'package:dukanx/services/role_management_service.dart' as svc;
import 'package:flutter_test/flutter_test.dart';

/// The exact granted permission set for the `pharmacist` role (Requirement
/// 10.2), expressed by permission NAME so the same expectation applies to both
/// `Permission` enums.
const Set<String> _grantedPermissionNames = <String>{
  'createBill', // dispensing operation
  'printBill', // dispensing operation
  'capturePrescription', // prescription capture
  'viewStock', // batch and expiry view
  'registerEntry', // narcotic / H1 register entry
};

/// The excluded permissions that MUST be denied (Requirement 10.3) mapped to
/// concrete `Permission` enum names:
///   - pricing override   -> applyHighDiscount (price-override surface)
///   - business settings  -> manageSettings
///   - financial reports  -> viewReports
///   - user management    -> manageUsers
const Set<String> _excludedPermissionNames = <String>{
  'applyHighDiscount', // pricing override
  'manageSettings', // business settings
  'viewReports', // financial reports
  'manageUsers', // user management
};

void main() {
  group(
    'Task 7.3 — Pharmacist role grants/denials (Requirements 10.1, 10.8)',
    () {
      // ----------------------------------------------------------------------
      // Requirement 10.1 — role exists and is distinct.
      // ----------------------------------------------------------------------
      group('Requirement 10.1 — pharmacist role exists and is distinct', () {
        test('UserRole enum contains a pharmacist value', () {
          expect(
            UserRole.values.contains(UserRole.pharmacist),
            isTrue,
            reason: 'UserRole must include a `pharmacist` value (R10.1).',
          );
        });

        test('pharmacist is distinct from every other UserRole value', () {
          final others = UserRole.values
              .where((r) => r != UserRole.pharmacist)
              .toList();

          for (final role in others) {
            expect(
              UserRole.pharmacist == role,
              isFalse,
              reason: 'pharmacist must be distinct from $role (R10.1).',
            );
          }

          // Also confirm uniqueness via name + no duplicate enum entries.
          expect(UserRole.pharmacist.name, equals('pharmacist'));
          final names = UserRole.values.map((r) => r.name).toList();
          expect(
            names.toSet().length,
            equals(names.length),
            reason: 'UserRole values must be unique.',
          );
        });
      });

      // ----------------------------------------------------------------------
      // Requirement 10.8 — every granted permission allowed (core matrix).
      // ----------------------------------------------------------------------
      group('Requirement 10.8 — granted permissions are allowed', () {
        test(
          'core matrix: each granted permission is allowed for pharmacist',
          () {
            for (final name in _grantedPermissionNames) {
              final core.Permission p = core.Permission.values.firstWhere(
                (e) => e.name == name,
              );
              expect(
                core.RolePermissions.hasPermission(UserRole.pharmacist, p),
                isTrue,
                reason: 'core: pharmacist must be GRANTED "$name" (R10.8).',
              );
            }
          },
        );

        test(
          'services matrix: each granted permission is allowed for pharmacist',
          () {
            for (final name in _grantedPermissionNames) {
              final svc.Permission p = svc.Permission.values.firstWhere(
                (e) => e.name == name,
              );
              expect(
                svc.RolePermissions.hasPermission(UserRole.pharmacist, p),
                isTrue,
                reason: 'services: pharmacist must be GRANTED "$name" (R10.8).',
              );
            }
          },
        );
      });

      // ----------------------------------------------------------------------
      // Requirement 10.8 — every excluded permission denied.
      // ----------------------------------------------------------------------
      group('Requirement 10.8 — excluded permissions are denied', () {
        test(
          'core matrix: each excluded permission is denied for pharmacist',
          () {
            for (final name in _excludedPermissionNames) {
              final core.Permission p = core.Permission.values.firstWhere(
                (e) => e.name == name,
              );
              expect(
                core.RolePermissions.hasPermission(UserRole.pharmacist, p),
                isFalse,
                reason: 'core: pharmacist must be DENIED "$name" (R10.8).',
              );
            }
          },
        );

        test(
          'services matrix: each excluded permission is denied for pharmacist',
          () {
            for (final name in _excludedPermissionNames) {
              final svc.Permission p = svc.Permission.values.firstWhere(
                (e) => e.name == name,
              );
              expect(
                svc.RolePermissions.hasPermission(UserRole.pharmacist, p),
                isFalse,
                reason: 'services: pharmacist must be DENIED "$name" (R10.8).',
              );
            }
          },
        );
      });

      // ----------------------------------------------------------------------
      // Exactness — the pharmacist set is precisely the granted set and nothing
      // else, in both matrices.
      // ----------------------------------------------------------------------
      test('pharmacist permission set equals the granted set exactly (both '
          'matrices)', () {
        final coreNames = core.RolePermissions.getPermissions(
          UserRole.pharmacist,
        ).map((p) => p.name).toSet();
        final svcNames = svc.RolePermissions.getPermissions(
          UserRole.pharmacist,
        ).map((p) => p.name).toSet();

        expect(
          coreNames,
          equals(_grantedPermissionNames),
          reason: 'core pharmacist set must equal the granted set exactly.',
        );
        expect(
          svcNames,
          equals(_grantedPermissionNames),
          reason: 'services pharmacist set must equal the granted set exactly.',
        );
      });
    },
  );
}
