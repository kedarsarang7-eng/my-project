/// Preservation / Property Tests — RBAC Owner-Fallback Remediation
///
/// **Validates: RBAC owner-fallback remediation (review §3 owner availability,
///   §4 Options 1 + 3 + 4)**
///
/// Feature: rbac-owner-fallback-remediation
///
/// These tests run AFTER the fix and MUST PASS. They lock in the remediated
/// behaviour of the pure decision functions added to [SessionManager]:
///   - resolveFallbackStaffRole (Option 1) — never escalates a staff user
///   - shouldRevokeOnRemoval     (Option 4) — revokes deactivated/removed staff
/// while preserving genuine-owner availability (review §3).
///
/// Run: flutter test test/bug_condition/rbac_owner_fallback_preservation_test.dart --reporter expanded
library;

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/services/role_management_service.dart' as rbac;

/// Number of property test iterations.
const int kNumRuns = 100;

/// The 15 owner-only powers enumerated in review §2 (blast radius).
const List<rbac.Permission> kOwnerOnlyPowers = [
  rbac.Permission.deleteBill,
  rbac.Permission.deleteCustomer,
  rbac.Permission.deleteSupplier,
  rbac.Permission.editStock,
  rbac.Permission.unlockPeriod,
  rbac.Permission.closeFinancialYear,
  rbac.Permission.manageUsers,
  rbac.Permission.manageSettings,
  rbac.Permission.viewProfit,
  rbac.Permission.viewMargins,
  rbac.Permission.applyHighDiscount,
  rbac.Permission.processRefund,
  rbac.Permission.acceptCashMismatch,
  rbac.Permission.viewSecurityDashboard,
  rbac.Permission.manageFraudAlerts,
];

/// The roles considered "known non-owner staff roles".
const List<UserRole> kStaffRoles = [
  UserRole.manager,
  UserRole.staff,
  UserRole.accountant,
];

void main() {
  // ==========================================================================
  // OPTION 1 — NON-ESCALATION: a cached staff role is preserved, never owner.
  // ==========================================================================
  group('Option 1: resolveFallbackStaffRole never escalates a staff user', () {
    for (final role in kStaffRoles) {
      test('cached $role → resolves to SAME role (no escalation)', () {
        expect(
          SessionManager.resolveFallbackStaffRole(role),
          equals(role),
          reason: 'A cached $role must NOT be escalated to owner',
        );
      });

      test(
        'resolved $role permission set EXCLUDES all 15 owner-only powers',
        () {
          final resolved = SessionManager.resolveFallbackStaffRole(role);
          final perms = rbac.RolePermissions.getPermissions(resolved);
          for (final power in kOwnerOnlyPowers) {
            expect(
              perms.contains(power),
              isFalse,
              reason: 'Fallback for $role must withhold ${power.name}',
            );
          }
        },
      );
    }

    test('cached owner → resolves to owner', () {
      expect(
        SessionManager.resolveFallbackStaffRole(UserRole.owner),
        equals(UserRole.owner),
      );
    });

    test('null cache → resolves to owner (documented residual, §3)', () {
      expect(
        SessionManager.resolveFallbackStaffRole(null),
        equals(UserRole.owner),
        reason:
            'No usable cache falls back to owner for genuine-owner availability',
      );
    });

    test('unknown cache → resolves to owner (availability)', () {
      expect(
        SessionManager.resolveFallbackStaffRole(UserRole.unknown),
        equals(UserRole.owner),
      );
    });
  });

  // ==========================================================================
  // PROPERTY 1 (non-escalation): for all UserRole values + null, the resolved
  // fallback role's permission set is NEVER a STRICT SUPERSET of the input
  // role's permissions when the input is a known non-owner role.
  // **Validates: review §4 Option 1**
  // ==========================================================================
  group('Property 1: fallback never escalates a known non-owner role', () {
    test('Property: resolveFallbackStaffRole(r) is not a strict superset of r '
        '(for known non-owner roles); owner/unknown/null fall back to owner', () {
      // Generate over all roles plus a null sentinel (index 0 == null).
      final candidates = <UserRole?>[null, ...UserRole.values];
      final idxGen = Gen.interval(0, candidates.length - 1);

      forAll(
        (int idx) {
          final UserRole? input = candidates[idx];
          final resolved = SessionManager.resolveFallbackStaffRole(input);

          if (input == UserRole.manager ||
              input == UserRole.staff ||
              input == UserRole.accountant) {
            // Known non-owner role — must be preserved exactly (no escalation).
            expect(
              resolved,
              equals(input),
              reason: 'Known non-owner role $input must be preserved',
            );

            final inputPerms = rbac.RolePermissions.getPermissions(input!);
            final resolvedPerms = rbac.RolePermissions.getPermissions(resolved);
            // resolvedPerms must NOT be a strict superset of inputPerms.
            final isStrictSuperset =
                resolvedPerms.containsAll(inputPerms) &&
                resolvedPerms.length > inputPerms.length;
            expect(
              isStrictSuperset,
              isFalse,
              reason:
                  'Fallback for $input must not gain permissions (no escalation)',
            );
          } else {
            // owner / unknown / null — availability fallback to owner.
            expect(
              resolved,
              equals(UserRole.owner),
              reason:
                  'owner/unknown/null must fall back to owner for availability',
            );
          }
          return true;
        },
        [idxGen],
        numRuns: kNumRuns,
      );
    });
  });

  // ==========================================================================
  // OWNER AVAILABILITY (review §3): a genuine owner keeps owner permissions on
  // fallback (no lockout) whether the cache says owner or is absent.
  // ==========================================================================
  group('Owner availability preserved on fallback', () {
    test('cached owner keeps the FULL owner permission set', () {
      final resolved = SessionManager.resolveFallbackStaffRole(UserRole.owner);
      final perms = rbac.RolePermissions.getPermissions(resolved);
      final ownerPerms = rbac.RolePermissions.getPermissions(UserRole.owner);
      expect(resolved, equals(UserRole.owner));
      expect(perms, equals(ownerPerms));
      // All 15 owner-only powers retained for the genuine owner.
      for (final power in kOwnerOnlyPowers) {
        expect(perms.contains(power), isTrue);
      }
    });

    test('no cache keeps the FULL owner permission set (no lockout)', () {
      final resolved = SessionManager.resolveFallbackStaffRole(null);
      final perms = rbac.RolePermissions.getPermissions(resolved);
      expect(resolved, equals(UserRole.owner));
      expect(
        perms,
        equals(rbac.RolePermissions.getPermissions(UserRole.owner)),
      );
    });
  });

  // ==========================================================================
  // OPTION 4 — PATH F revoke decision: a deactivated/deleted assignment for a
  // non-owner staff role revokes access; a genuine owner is never revoked.
  // ==========================================================================
  group('Option 4: shouldRevokeOnRemoval (exhaustive)', () {
    for (final role in kStaffRoles) {
      test('non-owner $role → revoke (true)', () {
        expect(
          SessionManager.shouldRevokeOnRemoval(role),
          isTrue,
          reason: 'A removed/deactivated $role must lose access',
        );
      });
    }

    test('owner → never revoked (false)', () {
      expect(
        SessionManager.shouldRevokeOnRemoval(UserRole.owner),
        isFalse,
        reason: 'A genuine owner must NOT be logged out by delete/deactivate',
      );
    });

    test('unknown → not revoked (false)', () {
      expect(SessionManager.shouldRevokeOnRemoval(UserRole.unknown), isFalse);
    });

    test('null → not revoked (false)', () {
      expect(SessionManager.shouldRevokeOnRemoval(null), isFalse);
    });

    test(
      'Property: shouldRevokeOnRemoval is true iff role is a known staff role',
      () {
        final candidates = <UserRole?>[null, ...UserRole.values];
        final idxGen = Gen.interval(0, candidates.length - 1);

        forAll(
          (int idx) {
            final UserRole? role = candidates[idx];
            final shouldRevoke = SessionManager.shouldRevokeOnRemoval(role);
            final isStaff =
                role == UserRole.manager ||
                role == UserRole.staff ||
                role == UserRole.accountant;
            expect(
              shouldRevoke,
              equals(isStaff),
              reason:
                  'Revoke decision must match staff-role membership for $role',
            );
            return true;
          },
          [idxGen],
          numRuns: kNumRuns,
        );
      },
    );
  });
}
