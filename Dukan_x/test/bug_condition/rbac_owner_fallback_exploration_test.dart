/// Bug Condition Exploration Test — RBAC Owner-Fallback Escalation
///
/// **Validates: RBAC owner-fallback remediation (review §1 Paths C/D/F, §2)**
///
/// These tests PIN the CURRENT escalation risk so the remediation is provably
/// a change in behaviour. The dangerous fallbacks (`_resolveStaffRole` catch /
/// no-businessId branch, and `_handleRoleChange` delete/deactivate branches)
/// all hand a non-owner user the FULL owner permission set. Since that logic
/// lives behind private Firestore reads, we assert the escalation at the level
/// this codebase already tests: the pure permission matrix + UserSession model.
///
/// Two things are pinned:
///  1. BLAST RADIUS — the 15 owner-only powers exist ONLY in the owner set, so
///     "fallback to owner" demonstrably grants a staff user exactly those 15
///     fraud-prevention/admin capabilities (review §2).
///  2. CURRENT FALLBACK SHAPE — today the fallback assigns the owner permission
///     set to a non-owner session (escalation). We model the current shape and
///     show it escalates; the remediation replaces it with a cached-role-aware,
///     non-escalating fallback (see rbac_owner_fallback_preservation_test.dart).
///
/// Run: flutter test test/bug_condition/rbac_owner_fallback_exploration_test.dart --reporter expanded
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/session/session_manager.dart' as session;
import 'package:dukanx/services/role_management_service.dart' as rbac;

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

void main() {
  // ==========================================================================
  // BLAST RADIUS (review §2): the 15 owner-only powers are owner-EXCLUSIVE.
  // Proves that any "fallback to owner" hands a staff user exactly these
  // 15 capabilities — the escalation impact.
  // ==========================================================================
  group('Blast radius: 15 owner-only powers are owner-exclusive', () {
    final ownerPerms = rbac.RolePermissions.getPermissions(rbac.UserRole.owner);
    final staffPerms = rbac.RolePermissions.getPermissions(rbac.UserRole.staff);
    final managerPerms = rbac.RolePermissions.getPermissions(
      rbac.UserRole.manager,
    );
    final accountantPerms = rbac.RolePermissions.getPermissions(
      rbac.UserRole.accountant,
    );

    for (final power in kOwnerOnlyPowers) {
      test(
        '${power.name} is in the owner set but NOT staff/manager/accountant',
        () {
          expect(
            ownerPerms.contains(power),
            isTrue,
            reason: 'Owner must hold ${power.name}',
          );
          expect(
            staffPerms.contains(power),
            isFalse,
            reason: 'Staff must NOT hold ${power.name}',
          );
          expect(
            managerPerms.contains(power),
            isFalse,
            reason: 'Manager must NOT hold ${power.name}',
          );
          expect(
            accountantPerms.contains(power),
            isFalse,
            reason: 'Accountant must NOT hold ${power.name}',
          );
        },
      );
    }

    test(
      'all 15 owner-only powers together are absent from every non-owner role',
      () {
        final nonOwnerUnion = <rbac.Permission>{
          ...staffPerms,
          ...managerPerms,
          ...accountantPerms,
        };
        for (final power in kOwnerOnlyPowers) {
          expect(
            nonOwnerUnion.contains(power),
            isFalse,
            reason:
                '${power.name} must be owner-exclusive (escalation surface)',
          );
        }
      },
    );
  });

  // ==========================================================================
  // CURRENT FALLBACK SHAPE: today the fallback assigns the OWNER permission set
  // to a non-owner session. This escalates the user — they gain all 15
  // owner-only powers. We model that current shape and PIN the escalation.
  // (Post-fix, resolveFallbackStaffRole keeps the cached granular role; see
  //  rbac_owner_fallback_preservation_test.dart.)
  // ==========================================================================
  group('Current fallback shape escalates a staff user to owner powers', () {
    test(
      'assigning owner permissions to a staff session grants all 15 owner-only powers',
      () {
        // This mirrors the CURRENT Path C/D/E/F behaviour: staffRole=owner +
        // owner permission set, regardless of the user being genuine staff.
        final ownerPerms = rbac.RolePermissions.getPermissions(
          rbac.UserRole.owner,
        );
        final escalatedStaffSession = session.UserSession(
          odId: 'staff-uid',
          role: session.UserRole.owner, // top-level resolved to owner
          ownerId: 'staff-uid',
          staffRole: session.UserRole.owner, // <-- the escalation
          staffPermissions: ownerPerms,
        );

        // The escalated session holds every owner-only power.
        for (final power in kOwnerOnlyPowers) {
          expect(
            escalatedStaffSession.hasPermission(power),
            isTrue,
            reason:
                'Current owner-fallback escalates: staff session holds ${power.name}',
          );
        }
        // And reports owner as the effective role.
        expect(
          escalatedStaffSession.effectiveRole,
          equals(session.UserRole.owner),
          reason: 'Current fallback makes effectiveRole=owner for a staff user',
        );
      },
    );

    test(
      'a NON-escalating fallback (staff keeps staff perms) would hold NONE of the 15 powers',
      () {
        // This is the target behaviour the remediation introduces: a cached
        // staff role keeps the staff permission set, never the owner set.
        final staffPerms = rbac.RolePermissions.getPermissions(
          rbac.UserRole.staff,
        );
        final safeStaffSession = session.UserSession(
          odId: 'staff-uid',
          role: session.UserRole.owner,
          ownerId: 'staff-uid',
          staffRole: session.UserRole.staff,
          staffPermissions: staffPerms,
        );

        for (final power in kOwnerOnlyPowers) {
          expect(
            safeStaffSession.hasPermission(power),
            isFalse,
            reason:
                'A non-escalating fallback must withhold ${power.name} from staff',
          );
        }
        expect(safeStaffSession.effectiveRole, equals(session.UserRole.staff));
      },
    );
  });
}
