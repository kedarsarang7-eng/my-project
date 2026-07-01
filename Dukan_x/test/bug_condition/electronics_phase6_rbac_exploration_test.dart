/// Phase 6 Bug-Condition Exploration Test — Electronics RBAC permission gating
///
/// **Validates: Requirements 2.20, 2.21**
///
/// **Property 8: Bug Condition** — RBAC permission gating.
///
/// This test encodes the EXPECTED behavior (what SHOULD happen after the fix).
/// It is run on UNFIXED code and is EXPECTED TO FAIL — failure confirms the bug
/// exists. DO NOT fix the test or the code when it fails here.
///
/// Bug condition (from design):
///   `RbacView` where `businessType == electronics AND sensitiveItem(input)
///    AND input.permission IS null`
///
/// Expected behavior asserted:
///   - 2.20: Sensitive items present in the Electronics sidebar carry a
///     `permission`, so the RBAC filter in `sidebarSectionsProvider` hides them
///     from a non-privileged role (cashier/staff). An item with
///     `permission == null` is shown to everyone — that is the bug.
///   - 2.21: The dashboard "New Repair" quick action applies the same
///     `manageStaff` authority as the `/job/*` route guard — i.e. it routes
///     through the guarded `/job/create` path rather than a raw
///     `AppScreen.serviceJobs` navigation that bypasses the check.
///
/// EXPECTED OUTCOME on UNFIXED code: Test FAILS — the "New Repair" quick action
/// for electronics navigates via raw `AppScreen.serviceJobs`
/// (`onTap: () => nav.navigateTo(AppScreen.serviceJobs)`) and therefore does not
/// apply the `manageStaff` authority the `/job/*` route guard requires (D7).
///
/// IMPORTANT DISCREPANCY (documented):
///   bugfix.md 1.20/2.20 names sensitive items `audit_trail`, `bank_accounts`,
///   `backup`, `expenses`, `accounting_reports`. Phase 4 trimmed the Electronics
///   sidebar to device entries + shared common sections. Of those literal ids
///   only `backup` is present in `_getElectronicsSections()` — and it ALREADY
///   carries `permission: 'manageSettings'`. The other four (`audit_trail`,
///   `bank_accounts`, `expenses`, `accounting_reports`) do NOT appear in the
///   Electronics sidebar at all. So the literal "cashier sees audit_trail /
///   backup" reproduction does not hold post-Phase-4; the genuinely-present,
///   reproducible defect is the 2.21 "New Repair" authority mismatch. The 2.20
///   assertions below still encode the correct gating contract for whatever
///   sensitive items ARE present (so they keep guarding against regressions).
///
/// PBT library: dartproptest ^0.2.1
///
/// Run: flutter test test/bug_condition/electronics_phase6_rbac_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/services/role_management_service.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a map of `id -> permission` for every item in the Electronics
/// sidebar, using the `@visibleForTesting` `getSectionsForBusinessType` entry
/// point (the same mechanism the other phase tests use).
Map<String, String?> _electronicsItemPermissions() {
  final sections = getSectionsForBusinessType(BusinessType.electronics);
  final result = <String, String?>{};
  for (final section in sections) {
    for (final item in section.items) {
      result[item.id] = item.permission;
    }
  }
  return result;
}

/// The literal sensitive ids named in bugfix.md 1.20 / 2.20.
const List<String> _literalSensitiveIds = <String>[
  'audit_trail',
  'bank_accounts',
  'backup',
  'expenses',
  'accounting_reports',
];

/// The non-privileged "cashier-equivalent" role. The unified [UserRole] enum
/// has no dedicated `cashier`; general staff is the least-privilege billing
/// role and (correctly) lacks `viewReports` / `viewGstReports` /
/// `manageSettings` / `viewAuditLog`.
const UserRole _cashierRole = UserRole.staff;

/// Mirrors the RBAC evaluation in `sidebarSectionsProvider`: an item is hidden
/// from [role] when it carries a non-null `permission` that the role lacks.
/// An item with `permission == null` is ALWAYS shown (the bug surface).
bool _isHiddenFromRole(String? permissionName, UserRole role) {
  if (permissionName == null) return false; // null → shown to everyone
  final permission = Permission.values.firstWhere(
    (p) => p.name == permissionName,
    orElse: () => Permission.manageSettings, // restrictive fallback
  );
  return !RolePermissions.hasPermission(role, permission);
}

/// Reads the `business_quick_actions.dart` source and returns the snippet that
/// implements the electronics "New Repair" quick action (the `onTap` window).
/// Source inspection is the approach sanctioned by the task for the 2.21
/// authority-agreement assertion.
String _newRepairOnTapSnippet() {
  final file = File(
    'lib/features/dashboard/v2/widgets/business_quick_actions.dart',
  );
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'business_quick_actions.dart must exist at the expected path. '
        'Resolved from cwd: ${Directory.current.path}',
  );
  final src = file.readAsStringSync();
  final labelIdx = src.indexOf("label: 'New Repair'");
  expect(
    labelIdx,
    greaterThanOrEqualTo(0),
    reason: 'Could not locate the "New Repair" quick action in source.',
  );
  // Capture a window large enough to include the onTap for this action button.
  final end = (labelIdx + 260).clamp(0, src.length);
  return src.substring(labelIdx, end);
}

void main() {
  // =========================================================================
  // (1) 2.20 — Sensitive sidebar items carry a permission and are hidden from
  //     a non-privileged (cashier/staff) role.
  //
  // Bug surface: an item with `permission == null` is shown to every role,
  //   so sensitive financial/system items leak to a cashier.
  // Expected (post-fix): every sensitive item present in the Electronics
  //   sidebar carries a permission the cashier lacks, so it is hidden.
  //
  // NOTE (discrepancy): of the literal 1.20/2.20 ids, only `backup` is present
  //   post-Phase-4 and it is already gated. These assertions therefore PASS
  //   today; they remain to lock in the gating contract.
  // =========================================================================
  group('Phase 6 Bug Condition — sensitive items gated for cashier (2.20)', () {
    test('every present literal-sensitive id carries a non-null permission', () {
      final perms = _electronicsItemPermissions();
      final present = _literalSensitiveIds.where(perms.containsKey).toList();
      final ungated = present
          .where((id) => perms[id] == null)
          .toList(growable: false);
      expect(
        ungated,
        isEmpty,
        reason:
            'Sensitive items present in the Electronics sidebar must carry a '
            '`permission` so the RBAC filter can hide them. Bug condition: '
            'permission == null → shown to everyone. '
            'Counterexample (ungated sensitive ids): $ungated. '
            'Present literal-sensitive ids: $present. '
            'Discrepancy note: literal ids absent post-Phase-4: '
            '${_literalSensitiveIds.where((id) => !perms.containsKey(id)).toList()}',
      );
    });

    test('a cashier/staff role cannot see any present sensitive item', () {
      final perms = _electronicsItemPermissions();
      final present = _literalSensitiveIds.where(perms.containsKey).toList();
      final leaked = present
          .where((id) => !_isHiddenFromRole(perms[id], _cashierRole))
          .toList(growable: false);
      expect(
        leaked,
        isEmpty,
        reason:
            'A non-privileged ($_cashierRole) role must NOT see sensitive '
            'Electronics sidebar items. Counterexample (visible to cashier): '
            '$leaked. Present sensitive ids and permissions: '
            '${{for (final id in present) id: perms[id]}}',
      );
    });
  });

  // =========================================================================
  // (2) 2.21 — "New Repair" quick action applies the same `manageStaff`
  //     authority as the `/job/*` route guard.
  //
  // Bug: `onTap: () => nav.navigateTo(AppScreen.serviceJobs)` — a raw
  //   NavigationController jump that bypasses the route-level
  //   BusinessGuard + manageStaff check (D7). The quick action and the route
  //   guard disagree on who may create a repair job.
  // Expected (post-fix): the action routes through the guarded `/job/create`
  //   path (e.g. `context.push('/job/create')`), so the same authority is
  //   enforced.
  //
  // EXPECTED OUTCOME on UNFIXED code: FAILS — snippet still uses
  //   `AppScreen.serviceJobs` and contains no guarded `/job/` route.
  // =========================================================================
  group(
    'Phase 6 Bug Condition — New Repair routes via guarded path (2.21)',
    () {
      test('New Repair does not use raw AppScreen.serviceJobs navigation', () {
        final snippet = _newRepairOnTapSnippet();
        expect(
          snippet.contains('AppScreen.serviceJobs'),
          isFalse,
          reason:
              'The "New Repair" quick action must NOT navigate via raw '
              '`nav.navigateTo(AppScreen.serviceJobs)`, which bypasses the '
              '`manageStaff` authority the `/job/*` route guard enforces (D7). '
              'Counterexample (unfixed onTap): '
              '${snippet.replaceAll('\n', ' ').trim()}',
        );
      });

      test('New Repair routes through the manageStaff-guarded /job/ path', () {
        final snippet = _newRepairOnTapSnippet();
        expect(
          snippet.contains('/job/'),
          isTrue,
          reason:
              'The "New Repair" quick action must route through the guarded '
              '`/job/create` path so its authority matches the route guard '
              '(manageStaff, D7). Counterexample: no `/job/` route in the '
              'onTap snippet: ${snippet.replaceAll('\n', ' ').trim()}',
        );
      });
    },
  );

  // =========================================================================
  // (3) Scoped PBT — combine the Phase 6 RBAC contract into a single property
  //     over the two sub-requirements. It WILL FAIL on unfixed code because the
  //     2.21 "New Repair" authority is missing.
  //
  //   index 0 → 2.20: no present sensitive item leaks to a cashier
  //   index 1 → 2.21: New Repair routes via the guarded /job/ path (not raw
  //                   AppScreen.serviceJobs)
  // =========================================================================
  group('Phase 6 Bug Condition — PBT: RBAC gating contract (2.20, 2.21)', () {
    test('PBT: sidebar gating AND quick-action/route-guard agreement', () {
      final perms = _electronicsItemPermissions();
      final snippet = _newRepairOnTapSnippet();

      forAll(
        (int idx) {
          if (idx == 0) {
            // 2.20 — no present sensitive item is visible to a cashier.
            final present = _literalSensitiveIds
                .where(perms.containsKey)
                .toList();
            final leaked = present
                .where((id) => !_isHiddenFromRole(perms[id], _cashierRole))
                .toList(growable: false);
            expect(
              leaked,
              isEmpty,
              reason:
                  'Property violated (2.20): sensitive Electronics items must '
                  'be hidden from a $_cashierRole role. Counterexample: '
                  'visible-to-cashier ids = $leaked.',
            );
          } else {
            // 2.21 — New Repair must apply the manageStaff-guarded route.
            final usesRaw = snippet.contains('AppScreen.serviceJobs');
            final usesGuarded = snippet.contains('/job/');
            expect(
              !usesRaw && usesGuarded,
              isTrue,
              reason:
                  'Property violated (2.21): "New Repair" must route through '
                  'the manageStaff-guarded `/job/create` path, not raw '
                  '`AppScreen.serviceJobs`. Counterexample: usesRaw=$usesRaw, '
                  'usesGuarded=$usesGuarded; onTap snippet: '
                  '${snippet.replaceAll('\n', ' ').trim()}',
            );
          }
          return true;
        },
        [Gen.interval(0, 1)],
        numRuns: 2,
      );
    });
  });
}
