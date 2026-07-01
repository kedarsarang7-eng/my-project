// ============================================================================
// PHASE 2 — Task 7.2: PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 14: Pharmacist permission
//          set is exactly the granted set
// **Validates: Requirements 10.2, 10.3, 10.4, 10.5, 10.6**
// ============================================================================
//
// Property 14 (design.md — Correctness Properties):
//   *For any* permission, a user with the `pharmacist` role is allowed the
//   permission if and only if it belongs to the granted set (dispensing
//   operations, prescription capture, batch/expiry view, narcotic/H1 register
//   entry); every excluded permission and every other permission is denied with
//   an authorization-denied indication.
//
// WHAT IS PROVEN HERE (pure-logic surface):
//   `RolePermissions.hasPermission(UserRole.pharmacist, p)` is the
//   authorization chokepoint. For ANY `Permission` value `p`, the result MUST
//   be `true` iff `p` is in the canonical granted set and `false` otherwise:
//     granted = { createBill, printBill,         // dispensing operations
//                 capturePrescription,            // prescription capture
//                 viewStock,                      // batch / expiry view
//                 registerEntry }                 // narcotic / H1 register
//   Everything else — including the explicitly excluded pricing override,
//   business settings (manageSettings), financial reports (viewReports), and
//   user management (manageUsers) — is denied by omission (Requirements
//   10.2–10.6).
//
// COVERAGE OF BOTH MATRICES:
//   Task 7.1 added `pharmacist` to the permission matrix in BOTH
//   `lib/core/services/role_management_service.dart` and
//   `lib/services/role_management_service.dart`. These are two distinct
//   `Permission` enums + `RolePermissions` classes, so the property is checked
//   independently against each matrix to guarantee they agree on the exact
//   granted set (Requirement 10.7 keeps both definitions consistent).
//
// PBT library: dartproptest ^0.2.1 (repo-standard). Idiomatic usage:
//   `forAll((arg) => <bool>, [gen], numRuns: N)` returns true iff the property
//   held for every run, else throws a shrinking Exception with a counterexample.
//   `Gen.elementOf(Permission.values)` draws permissions exhaustively from the
//   enum's value space.
//
// Run: flutter test test/features/pharmacy/property14_pharmacist_permission_set_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/models/user_role.dart';
import 'package:dukanx/core/services/role_management_service.dart' as core;
import 'package:dukanx/services/role_management_service.dart' as svc;
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec; 200 is the
/// dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

/// The canonical granted permission set for the `pharmacist` role, expressed by
/// permission NAME so the same expectation applies to both `Permission` enums
/// (core + services). Membership here is the iff-condition of Property 14.
const Set<String> _grantedPermissionNames = <String>{
  'createBill', // dispensing operation
  'printBill', // dispensing operation
  'capturePrescription', // prescription capture
  'viewStock', // batch and expiry view
  'registerEntry', // narcotic / H1 register entry
};

/// The explicitly excluded permissions from Requirement 10.3 that MUST be
/// denied. Anchored deterministically below so the suite cannot pass vacuously.
const Set<String> _explicitlyDeniedNames = <String>{
  'manageSettings', // business settings / pricing override surface
  'viewReports', // financial reports
  'manageUsers', // user management
};

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 14: Pharmacist '
      'permission set is exactly the granted set', () {
    // ----------------------------------------------------------------------
    // Property 14 over the CORE matrix
    // (lib/core/services/role_management_service.dart)
    // ----------------------------------------------------------------------
    test('Property 14 (core matrix): pharmacist is allowed a permission iff it '
        'belongs to the granted set; every other permission is denied', () {
      final Generator<core.Permission> permGen = Gen.elementOf(
        core.Permission.values,
      );

      final bool held = forAll(
        (core.Permission permission) {
          final bool allowed = core.RolePermissions.hasPermission(
            UserRole.pharmacist,
            permission,
          );
          final bool expected = _grantedPermissionNames.contains(
            permission.name,
          );
          // iff: allowed exactly when the permission is in the granted set.
          return allowed == expected;
        },
        [permGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'For the core RolePermissions matrix, UserRole.pharmacist must be '
            'allowed a permission iff it is in {createBill, printBill, '
            'capturePrescription, viewStock, registerEntry}; all others denied '
            '(Property 14 / Requirements 10.2–10.6).',
      );
    });

    // ----------------------------------------------------------------------
    // Property 14 over the SERVICES matrix
    // (lib/services/role_management_service.dart)
    // ----------------------------------------------------------------------
    test('Property 14 (services matrix): pharmacist is allowed a permission iff '
        'it belongs to the granted set; every other permission is denied', () {
      final Generator<svc.Permission> permGen = Gen.elementOf(
        svc.Permission.values,
      );

      final bool held = forAll(
        (svc.Permission permission) {
          final bool allowed = svc.RolePermissions.hasPermission(
            UserRole.pharmacist,
            permission,
          );
          final bool expected = _grantedPermissionNames.contains(
            permission.name,
          );
          return allowed == expected;
        },
        [permGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'For the services RolePermissions matrix, UserRole.pharmacist must '
            'be allowed a permission iff it is in {createBill, printBill, '
            'capturePrescription, viewStock, registerEntry}; all others denied '
            '(Property 14 / Requirements 10.2–10.6).',
      );
    });

    // ----------------------------------------------------------------------
    // Deterministic anchors — prove the property is non-vacuous: the exact
    // granted set is allowed, and the explicitly excluded permissions (10.3)
    // are denied, in BOTH matrices.
    // ----------------------------------------------------------------------
    test(
      'Property 14 anchor: the exact granted set is allowed in both matrices '
      '(Requirements 10.2, 10.4)',
      () {
        for (final name in _grantedPermissionNames) {
          final core.Permission cp = core.Permission.values.firstWhere(
            (p) => p.name == name,
          );
          final svc.Permission sp = svc.Permission.values.firstWhere(
            (p) => p.name == name,
          );

          expect(
            core.RolePermissions.hasPermission(UserRole.pharmacist, cp),
            isTrue,
            reason: 'core: pharmacist must be granted "$name".',
          );
          expect(
            svc.RolePermissions.hasPermission(UserRole.pharmacist, sp),
            isTrue,
            reason: 'services: pharmacist must be granted "$name".',
          );
        }
      },
    );

    test('Property 14 anchor: explicitly excluded permissions are denied in '
        'both matrices (Requirements 10.3, 10.5)', () {
      for (final name in _explicitlyDeniedNames) {
        final core.Permission cp = core.Permission.values.firstWhere(
          (p) => p.name == name,
        );
        final svc.Permission sp = svc.Permission.values.firstWhere(
          (p) => p.name == name,
        );

        expect(
          core.RolePermissions.hasPermission(UserRole.pharmacist, cp),
          isFalse,
          reason: 'core: pharmacist must be denied "$name".',
        );
        expect(
          svc.RolePermissions.hasPermission(UserRole.pharmacist, sp),
          isFalse,
          reason: 'services: pharmacist must be denied "$name".',
        );
      }
    });

    test('Property 14 anchor: the pharmacist granted set has exactly the '
        'expected cardinality in both matrices', () {
      // getPermissions returns the full set; its NAMES must equal the granted
      // set, confirming "exactly the granted set — and nothing else".
      final Set<String> coreNames = core.RolePermissions.getPermissions(
        UserRole.pharmacist,
      ).map((p) => p.name).toSet();
      final Set<String> svcNames = svc.RolePermissions.getPermissions(
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
  });
}
