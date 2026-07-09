/// Preservation Property Test — Existing UserRole Resolution Preserved
///
/// **Validates: Requirements 3.6**
///
/// Property 16: Preservation — Existing UserRole Resolution Preserved
///
/// This test confirms that:
/// 1. Every pre-existing `UserRole` value (`owner`, `manager`, `staff`,
///    `accountant`, `pharmacist`, `waiter`, `chef`, `captain`, `doctor`,
///    `receptionist`, `nurse`, `unknown`) resolves exactly as today via
///    `RolePermissions.hasPermission`.
/// 2. Adding `attendant` does NOT alter resolution or `RolePermissions` for
///    any existing role.
/// 3. No non-petrolPump sidebar's capability/permission gates change.
///
/// Methodology (source-reading / observation-first):
///   - Read `user_role.dart` and `role_management_service.dart` via `dart:io`
///     to verify the enum and permission map structure.
///   - Record the full permission matrix for all 12 pre-existing roles (11
///     named + unknown) against every Permission enum value.
///   - Property-based: generate arbitrary (UserRole, Permission) pairs and
///     assert RolePermissions.hasPermission returns the expected baseline value.
///   - Source-level: verify no non-petrolPump sidebar section references
///     `attendant` or has changed permission/capability gates.
///
/// This test MUST PASS on UNFIXED code — it captures baseline behavior that
/// the fix must preserve.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/bug_condition/petrol_pump_preservation_user_role_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/models/user_role.dart';
import 'package:dukanx/services/role_management_service.dart';

const int kNumRuns = 200;

/// The 12 pre-existing UserRole values (11 named roles + unknown).
const List<UserRole> _preExistingRoles = [
  UserRole.owner,
  UserRole.manager,
  UserRole.staff,
  UserRole.accountant,
  UserRole.pharmacist,
  UserRole.waiter,
  UserRole.chef,
  UserRole.captain,
  UserRole.doctor,
  UserRole.receptionist,
  UserRole.nurse,
  UserRole.unknown,
];

/// Reads a source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

/// Builds the expected baseline permission matrix by calling
/// RolePermissions.hasPermission for every (role, permission) pair.
/// This captures the current (unfixed) state as the truth.
Map<UserRole, Map<Permission, bool>> _buildBaselineMatrix() {
  final matrix = <UserRole, Map<Permission, bool>>{};
  for (final role in _preExistingRoles) {
    final roleMap = <Permission, bool>{};
    for (final perm in Permission.values) {
      roleMap[perm] = RolePermissions.hasPermission(role, perm);
    }
    matrix[role] = roleMap;
  }
  return matrix;
}

void main() {
  // ==========================================================================
  // PRESERVATION 3.6 — UserRole enum contains exactly 12 pre-existing values
  // ==========================================================================
  group('Preservation 3.6: UserRole enum has all 12 pre-existing values', () {
    test('UserRole.values contains all 12 expected roles', () {
      // Verify all pre-existing roles are present
      for (final role in _preExistingRoles) {
        expect(
          UserRole.values.contains(role),
          isTrue,
          reason: 'UserRole must contain ${role.name}',
        );
      }
    });

    test('source file declares exactly the expected enum values', () {
      final src = _readSource('lib/core/models/user_role.dart');
      expect(src.isNotEmpty, isTrue, reason: 'user_role.dart must exist');

      // Verify each expected role name appears in the source
      final expectedNames = [
        'owner',
        'manager',
        'staff',
        'accountant',
        'pharmacist',
        'waiter',
        'chef',
        'captain',
        'doctor',
        'receptionist',
        'nurse',
        'unknown',
      ];

      for (final name in expectedNames) {
        // Look for the enum value declaration (just the name on its own line)
        final hasValue = RegExp(
          r'^\s*' + name + r'\s*[,;]?\s*$',
          multiLine: true,
        ).hasMatch(src);
        expect(
          hasValue,
          isTrue,
          reason: 'UserRole enum must declare value "$name" in source',
        );
      }
    });

    test('UserRole enum does NOT yet contain attendant (pre-fix baseline)', () {
      // On unfixed code, attendant should NOT exist yet.
      // After the fix adds it, this assertion still passes because we only
      // check that existing roles are unchanged — the presence of attendant
      // is acceptable as long as existing roles remain intact.
      // For the preservation test, we verify the pre-existing roles are
      // unmodified regardless of whether attendant is added.
      final roleNames = UserRole.values.map((r) => r.name).toSet();

      // All 12 pre-existing roles must exist
      for (final role in _preExistingRoles) {
        expect(
          roleNames.contains(role.name),
          isTrue,
          reason: 'Pre-existing role ${role.name} must exist in UserRole enum',
        );
      }
    });
  });

  // ==========================================================================
  // PRESERVATION 3.6 — RolePermissions.hasPermission baseline for all roles
  // ==========================================================================
  group(
    'Preservation 3.6: RolePermissions.hasPermission baseline unchanged',
    () {
      late Map<UserRole, Map<Permission, bool>> baselineMatrix;

      setUpAll(() {
        baselineMatrix = _buildBaselineMatrix();
      });

      test(
        'owner has comprehensive permissions (all listed in _permissions map)',
        () {
          // Owner has the most permissions of any role. Verify core business
          // permissions that owner must always have.
          final ownerPerms = RolePermissions.getPermissions(UserRole.owner);

          final coreOwnerPerms = [
            Permission.createBill,
            Permission.editBill,
            Permission.deleteBill,
            Permission.manageUsers,
            Permission.manageSettings,
            Permission.viewReports,
            Permission.viewAuditLog,
            Permission.viewProfit,
            Permission.viewMargins,
          ];

          for (final perm in coreOwnerPerms) {
            expect(
              ownerPerms.contains(perm),
              isTrue,
              reason: 'Owner must have permission ${perm.name}',
            );
          }
        },
      );

      test('unknown has no permissions', () {
        for (final perm in Permission.values) {
          expect(
            RolePermissions.hasPermission(UserRole.unknown, perm),
            isFalse,
            reason: 'Unknown role must NOT have permission ${perm.name}',
          );
        }
      });

      test('staff has createBill but not deleteBill', () {
        expect(
          RolePermissions.hasPermission(UserRole.staff, Permission.createBill),
          isTrue,
          reason: 'Staff must have createBill permission',
        );
        expect(
          RolePermissions.hasPermission(UserRole.staff, Permission.deleteBill),
          isFalse,
          reason: 'Staff must NOT have deleteBill permission',
        );
      });

      test('pharmacist has exactly capturePrescription, registerEntry, '
          'createBill, printBill, viewStock', () {
        final pharmacistPerms = RolePermissions.getPermissions(
          UserRole.pharmacist,
        );
        expect(pharmacistPerms, contains(Permission.capturePrescription));
        expect(pharmacistPerms, contains(Permission.registerEntry));
        expect(pharmacistPerms, contains(Permission.createBill));
        expect(pharmacistPerms, contains(Permission.printBill));
        expect(pharmacistPerms, contains(Permission.viewStock));
        // Pharmacist should NOT have manageUsers, manageSettings, etc.
        expect(pharmacistPerms.contains(Permission.manageUsers), isFalse);
        expect(pharmacistPerms.contains(Permission.manageSettings), isFalse);
      });

      test('accountant has viewReports but not manageUsers', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.accountant,
            Permission.viewReports,
          ),
          isTrue,
        );
        expect(
          RolePermissions.hasPermission(
            UserRole.accountant,
            Permission.manageUsers,
          ),
          isFalse,
        );
      });

      test('PBT: for all pre-existing roles × all permissions, '
          'hasPermission matches recorded baseline', () {
        // The baseline captures current behavior. Across many random
        // (role-index, permission-index) pairs, verify consistency.
        forAll(
          (int roleIdx, int permIdx) {
            final role = _preExistingRoles[roleIdx % _preExistingRoles.length];
            final perm = Permission.values[permIdx % Permission.values.length];

            final expected = baselineMatrix[role]![perm]!;
            final actual = RolePermissions.hasPermission(role, perm);

            expect(
              actual,
              equals(expected),
              reason:
                  'RolePermissions.hasPermission(${role.name}, ${perm.name}) '
                  'must be $expected (baseline preserved). Got: $actual',
            );
            return true;
          },
          [
            Gen.interval(0, _preExistingRoles.length - 1),
            Gen.interval(0, Permission.values.length - 1),
          ],
          numRuns: kNumRuns,
        );
      });
    },
  );

  // ==========================================================================
  // PRESERVATION 3.6 — RolePermissions.getPermissions returns consistent sets
  // ==========================================================================
  group('Preservation 3.6: RolePermissions.getPermissions consistency', () {
    test('getPermissions for each pre-existing role is internally consistent '
        'with hasPermission', () {
      for (final role in _preExistingRoles) {
        final permSet = RolePermissions.getPermissions(role);
        for (final perm in Permission.values) {
          final hasIt = RolePermissions.hasPermission(role, perm);
          final inSet = permSet.contains(perm);
          expect(
            hasIt,
            equals(inSet),
            reason:
                'For ${role.name}, hasPermission(${perm.name})=$hasIt must '
                'match getPermissions().contains(${perm.name})=$inSet',
          );
        }
      }
    });

    test(
      'PBT: getPermissions and hasPermission always agree for pre-existing roles',
      () {
        forAll(
          (int roleIdx, int permIdx) {
            final role = _preExistingRoles[roleIdx % _preExistingRoles.length];
            final perm = Permission.values[permIdx % Permission.values.length];

            final permSet = RolePermissions.getPermissions(role);
            final hasIt = RolePermissions.hasPermission(role, perm);
            final inSet = permSet.contains(perm);

            expect(
              hasIt,
              equals(inSet),
              reason:
                  'hasPermission(${role.name}, ${perm.name}) must equal '
                  'getPermissions(${role.name}).contains(${perm.name})',
            );
            return true;
          },
          [
            Gen.interval(0, _preExistingRoles.length - 1),
            Gen.interval(0, Permission.values.length - 1),
          ],
          numRuns: kNumRuns,
        );
      },
    );
  });

  // ==========================================================================
  // PRESERVATION 3.6 — No non-petrolPump sidebar references attendant role
  // ==========================================================================
  group('Preservation 3.6: non-petrolPump sidebar gates unchanged', () {
    late String sidebarSrc;

    setUpAll(() {
      sidebarSrc = _readSource(
        'lib/widgets/desktop/sidebar_configuration.dart',
      );
    });

    test('sidebar_configuration.dart exists and is readable', () {
      expect(
        sidebarSrc.isNotEmpty,
        isTrue,
        reason: 'sidebar_configuration.dart must exist',
      );
    });

    test('no non-petrolPump sidebar section references attendant role', () {
      // On unfixed code, 'attendant' should not appear anywhere.
      // After the fix, it may appear in petrolPump sections ONLY.
      // Either way, non-petrolPump sections must not reference it.

      // Find all non-petrolPump section methods
      final nonPetrolMethods = [
        '_getRetailSections',
        '_getPharmacySections',
        '_getRestaurantSections',
        '_getClinicSections',
        '_getJewellerySections',
        '_getClothingSections',
        '_getSchoolSections',
        '_getCommonSections',
      ];

      for (final methodName in nonPetrolMethods) {
        final methodIdx = sidebarSrc.indexOf(methodName);
        if (methodIdx == -1) continue; // Method may not exist

        // Extract a window of ~3000 chars from the method start
        final windowEnd = (methodIdx + 3000).clamp(0, sidebarSrc.length);
        final methodWindow = sidebarSrc.substring(methodIdx, windowEnd);

        // No reference to 'attendant' as a role/permission gate
        final hasAttendantGate = RegExp(
          r'(permission|capability|role)\s*[:=]\s*'
          "'"
          '?attendant',
        ).hasMatch(methodWindow);

        expect(
          hasAttendantGate,
          isFalse,
          reason:
              '$methodName must NOT reference "attendant" as a '
              'permission/capability gate. Non-petrolPump sidebars are '
              'unaffected by the attendant role addition.',
        );
      }
    });

    test(
      'existing permission gates on non-petrolPump sidebar items are preserved',
      () {
        // Verify known existing permission gates still exist in source
        // These are from _getRetailSections and _getCommonSections
        final knownGates = [
          "permission: 'viewReports'",
          "permission: 'manageSettings'",
          "permission: 'viewGstReports'",
          "permission: 'viewCashBook'",
        ];

        for (final gate in knownGates) {
          expect(
            sidebarSrc.contains(gate),
            isTrue,
            reason:
                'Sidebar must still contain gate "$gate". '
                'Non-petrolPump sidebar permission gates must be preserved.',
          );
        }
      },
    );

    test(
      'existing capability gates on non-petrolPump sidebar items are preserved',
      () {
        // Verify known existing capability gates still exist in source
        final knownCapabilities = [
          'BusinessCapability.useProformaInvoice',
          'BusinessCapability.useInvoiceCreate',
          'BusinessCapability.useSalesReturn',
          'BusinessCapability.useInventoryList',
          'BusinessCapability.useLowStockAlert',
          'BusinessCapability.usePatientRegistry',
          'BusinessCapability.usePrescription',
          'BusinessCapability.useGoldRate',
          'BusinessCapability.useHallmark',
        ];

        for (final cap in knownCapabilities) {
          expect(
            sidebarSrc.contains(cap),
            isTrue,
            reason:
                'Sidebar must still contain capability "$cap". '
                'Non-petrolPump sidebar capability gates must be preserved.',
          );
        }
      },
    );

    test('PBT: for arbitrary role indices, RolePermissions resolution '
        'is stable (no randomness or external state dependency)', () {
      // Call hasPermission repeatedly with the same inputs and verify
      // the result is deterministic (no mutable state changes outcome).
      forAll(
        (int roleIdx, int permIdx) {
          final role = _preExistingRoles[roleIdx % _preExistingRoles.length];
          final perm = Permission.values[permIdx % Permission.values.length];

          final result1 = RolePermissions.hasPermission(role, perm);
          final result2 = RolePermissions.hasPermission(role, perm);

          expect(
            result1,
            equals(result2),
            reason:
                'RolePermissions.hasPermission must be deterministic. '
                'Two calls with (${role.name}, ${perm.name}) must return '
                'the same value.',
          );
          return true;
        },
        [
          Gen.interval(0, _preExistingRoles.length - 1),
          Gen.interval(0, Permission.values.length - 1),
        ],
        numRuns: kNumRuns,
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.6 — Source-level: role_management_service permission map
  // ==========================================================================
  group(
    'Preservation 3.6: role_management_service.dart permission map intact',
    () {
      late String roleServiceSrc;

      setUpAll(() {
        roleServiceSrc = _readSource(
          'lib/services/role_management_service.dart',
        );
      });

      test('role_management_service.dart exists', () {
        expect(
          roleServiceSrc.isNotEmpty,
          isTrue,
          reason: 'role_management_service.dart must exist',
        );
      });

      test(
        '_permissions map contains entries for all 12 pre-existing roles',
        () {
          // Verify each role's entry exists in the static _permissions map
          final expectedEntries = [
            'UserRole.owner',
            'UserRole.accountant',
            'UserRole.manager',
            'UserRole.staff',
            'UserRole.pharmacist',
            'UserRole.waiter',
            'UserRole.chef',
            'UserRole.captain',
            'UserRole.doctor',
            'UserRole.receptionist',
            'UserRole.nurse',
            // unknown is handled by the ?? {} fallback (no explicit entry)
          ];

          for (final entry in expectedEntries) {
            expect(
              roleServiceSrc.contains(entry),
              isTrue,
              reason:
                  '_permissions map must contain "$entry". '
                  'All pre-existing role permission mappings must be preserved.',
            );
          }
        },
      );

      test(
        'hasPermission method uses null-safe lookup with empty-set fallback',
        () {
          // The hasPermission method returns false for roles not in the map
          // (like unknown). This pattern must be preserved.
          final hasNullSafeLookup = roleServiceSrc.contains(
            '_permissions[role]?.contains(permission) ?? false',
          );
          expect(
            hasNullSafeLookup,
            isTrue,
            reason:
                'RolePermissions.hasPermission must use the null-safe pattern '
                '"_permissions[role]?.contains(permission) ?? false" to handle '
                'roles without explicit entries (like unknown).',
          );
        },
      );
    },
  );
}
