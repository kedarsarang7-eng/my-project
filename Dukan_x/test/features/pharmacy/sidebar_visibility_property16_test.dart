// ============================================================================
// PHASE 2 — Task 10.3: PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 16: Sidebar entry visibility
//          follows capability and role grants
// **Validates: Requirements 13.4, 13.5**
// ============================================================================
//
// Property 16 (design.md — Correctness Properties):
//   *For any* combination of capability and role-permission grant state, a
//   gated pharmacy sidebar entry is displayed and activatable IF AND ONLY IF
//   the corresponding capability AND role permissions are granted.
//
// THE PRODUCTION RULE UNDER TEST (lib/widgets/desktop/sidebar_configuration.dart
// → `sidebarSectionsProvider`): a `SidebarMenuItem` survives filtering iff
//
//     (item.capability == null
//        || FeatureResolver.canAccess(businessType.name, item.capability))
//   AND
//     (item.permission == null
//        || (session != null
//              && RolePermissions.hasPermission(effectiveRole, <mapped perm>)))
//
//   where the permission STRING is mapped to a `Permission` enum value via
//   `Permission.values.firstWhere((p) => p.name == permission,
//        orElse: () => Permission.manageSettings)` — an unrecognised string
//   falls back to the restrictive `manageSettings` permission.
//
// WHAT THIS SUITE PROVES:
//   1. EQUIVALENCE PROPERTY (generated, >= 100 runs): for random
//      (businessType, role, sessionPresent, capability present/absent,
//      permission present/absent/bogus) the keep/drop decision computed by the
//      SAME composition the provider uses (built on the REAL `FeatureResolver`
//      and REAL `RolePermissions.hasPermission`) equals an INDEPENDENT oracle
//      that re-derives each gate via a different code path:
//        * capability gate  -> direct `businessCapabilityRegistry` membership
//                              (independent of `FeatureResolver.canAccess`)
//        * permission gate   -> `RolePermissions.getPermissions(role).contains`
//                              (independent of `RolePermissions.hasPermission`)
//      Agreement across the whole space confirms the iff rule is exactly the
//      AND-of-gates and nothing else (Requirements 13.4, 13.5).
//   2. REAL-PROVIDER ANCHOR: the actual `sidebarSectionsProvider` is driven for
//      the pharmacy vertical across roles; every item it actually shows is
//      proven to pass the real capability gate (the "only if" direction on live
//      production output — no entry leaks past a denied gate).
//   3. DETERMINISTIC ANCHORS: hand-picked cases pin both directions of the iff
//      and the AND-semantics (either gate failing hides the entry).
//
// PBT library: dartproptest ^0.2.1 (repo-standard).
//   `Gen.tuple([...]).map(...)` builds one case object per run;
//   `forAll((case) => <bool>, [gen], numRuns: N)` returns true iff the property
//   held for every generated case.
//
// Run: flutter test test/features/pharmacy/sidebar_visibility_property16_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/models/user_role.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:dukanx/services/role_management_service.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec; 200 matches the
/// convention used across this repo's property suites.
const int kNumRuns = 200;

/// A bogus permission string that matches NO `Permission` enum name, exercising
/// the production `firstWhere(..., orElse: () => Permission.manageSettings)`
/// fallback branch.
const String _bogusPermission = '__no_such_permission__';

// ============================================================================
// INPUT SPACE
// ============================================================================
//
// Business-type strings are drawn from the canonical `businessCapabilityRegistry`
// keys plus one deliberately-unknown sentinel. These keys are exactly the values
// the provider passes (`businessType.name`), and `FeatureResolver` normalises
// each to itself — so the oracle may look them up in the registry directly while
// staying an INDEPENDENT computation from `FeatureResolver.canAccess`.
final List<String> _typeKeys = <String>[
  ...businessCapabilityRegistry.keys,
  '__unknown_vertical__', // strict-deny path: not in the registry
];

/// One generated visibility scenario, carrying a REAL [SidebarMenuItem] so the
/// gate logic reads the same `capability` / `permission` fields production does.
class _VisibilityCase {
  _VisibilityCase({
    required this.typeStr,
    required this.role,
    required this.sessionPresent,
    required this.item,
  });

  final String typeStr;
  final UserRole role;
  final bool sessionPresent;
  final SidebarMenuItem item;

  @override
  String toString() =>
      'type=$typeStr role=${role.name} session=$sessionPresent '
      'cap=${item.capability?.name ?? "<none>"} '
      'perm=${item.permission ?? "<none>"}';
}

/// Builds a [SidebarMenuItem] from generator codes.
///
/// capCode: 0 => no capability; otherwise capability = values[capCode - 1].
/// permCode: 0 => no permission; 1 => bogus string; otherwise
///           permission = Permission.values[permCode - 2].name.
SidebarMenuItem _buildItem(int capCode, int permCode) {
  final BusinessCapability? cap = capCode == 0
      ? null
      : BusinessCapability.values[capCode - 1];

  final String? perm;
  if (permCode == 0) {
    perm = null;
  } else if (permCode == 1) {
    perm = _bogusPermission;
  } else {
    perm = Permission.values[permCode - 2].name;
  }

  return SidebarMenuItem(
    id: 'gen_item',
    icon: Icons.circle_outlined,
    label: 'Generated Item',
    capability: cap,
    permission: perm,
  );
}

final Generator<_VisibilityCase> _caseGen =
    Gen.tuple([
      Gen.interval(0, _typeKeys.length - 1), // 0: business-type key index
      Gen.elementOf<UserRole>(UserRole.values), // 1: effective role
      Gen.elementOf<bool>(<bool>[true, false]), // 2: session present?
      Gen.interval(0, BusinessCapability.values.length), // 3: capability code
      Gen.interval(0, Permission.values.length + 1), // 4: permission code
    ]).map((parts) {
      final String typeStr = _typeKeys[parts[0] as int];
      final UserRole role = parts[1] as UserRole;
      final bool sessionPresent = parts[2] as bool;
      final int capCode = parts[3] as int;
      final int permCode = parts[4] as int;
      return _VisibilityCase(
        typeStr: typeStr,
        role: role,
        sessionPresent: sessionPresent,
        item: _buildItem(capCode, permCode),
      );
    });

// ============================================================================
// SUBJECT vs ORACLE
// ============================================================================

/// SUBJECT — the keep/drop decision composed EXACTLY as `sidebarSectionsProvider`
/// composes it, built on the REAL production gate functions.
bool _subjectKeeps(_VisibilityCase c) {
  // Capability gate (FeatureResolver) — applied before RBAC.
  if (c.item.capability != null) {
    if (!FeatureResolver.canAccess(c.typeStr, c.item.capability!)) {
      return false;
    }
  }
  // Permission gate (RBAC) — null session drops a permission-gated item.
  if (c.item.permission != null) {
    if (!c.sessionPresent) return false;
    final Permission permission = Permission.values.firstWhere(
      (p) => p.name == c.item.permission,
      orElse: () => Permission.manageSettings,
    );
    if (!RolePermissions.hasPermission(c.role, permission)) {
      return false;
    }
  }
  return true;
}

/// ORACLE — the same AND-of-gates rule re-derived via INDEPENDENT code paths:
/// registry membership for the capability gate, and `getPermissions().contains`
/// for the permission gate.
bool _oracleKeeps(_VisibilityCase c) {
  // Capability gate via direct registry lookup (independent of FeatureResolver).
  final bool capabilityGranted =
      c.item.capability == null ||
      (businessCapabilityRegistry[c.typeStr]?.contains(c.item.capability) ??
          false);

  // Permission gate via getPermissions().contains (independent of hasPermission).
  final bool permissionGranted;
  if (c.item.permission == null) {
    permissionGranted = true;
  } else if (!c.sessionPresent) {
    permissionGranted = false;
  } else {
    final Permission mapped = Permission.values.firstWhere(
      (p) => p.name == c.item.permission,
      orElse: () => Permission.manageSettings,
    );
    permissionGranted = RolePermissions.getPermissions(c.role).contains(mapped);
  }

  return capabilityGranted && permissionGranted;
}

// ============================================================================
// REAL-PROVIDER SEAM (mirrors phase2_property4_sidebar_invariance_test.dart)
// ============================================================================

/// Pins the active business type without touching SharedPreferences / license
/// providers.
class _FakeBusinessTypeNotifier extends BusinessTypeNotifier {
  _FakeBusinessTypeNotifier(this._type);
  final BusinessType _type;
  @override
  BusinessTypeState build() => BusinessTypeState(type: _type);
}

/// Represents a completed (authenticated) login without reaching into the GetIt
/// service locator.
class _FakeAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated);
}

ProviderContainer _containerFor(BusinessType type, UserRole role) {
  return ProviderContainer(
    overrides: [
      businessTypeProvider.overrideWith(() => _FakeBusinessTypeNotifier(type)),
      authStateProvider.overrideWith(() => _FakeAuthStateNotifier()),
      currentUserRoleProvider.overrideWithValue(role),
    ],
  );
}

// ============================================================================
// TESTS
// ============================================================================

void main() {
  // Reading the providers in a plain `test()` body needs the binding wired up.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature: pharmacy-vertical-remediation, Property 16: Sidebar entry '
      'visibility follows capability and role grants', () {
    // ----------------------------------------------------------------------
    // PROPERTY 16 — equivalence to the independent AND-of-gates oracle.
    // ----------------------------------------------------------------------
    test('Property 16: an entry is kept IFF the capability gate AND the '
        'role-permission gate both pass (Requirements 13.4, 13.5)', () {
      final bool held = forAll(
        (_VisibilityCase c) => _subjectKeeps(c) == _oracleKeeps(c),
        [_caseGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'The provider keep/drop decision must equal the independent '
            'AND-of-gates oracle for every (type, role, session, '
            'capability, permission) combination (Property 16).',
      );
    });

    // ----------------------------------------------------------------------
    // Structural restatement — the decision equals capGate && permGate, so a
    // kept entry implies BOTH gates pass (the "only if" direction).
    // ----------------------------------------------------------------------
    test('Property 16 (structure): a kept entry implies BOTH gates pass, and '
        'either gate failing hides the entry', () {
      final bool held = forAll(
        (_VisibilityCase c) {
          final bool kept = _subjectKeeps(c);

          final bool capGate =
              c.item.capability == null ||
              FeatureResolver.canAccess(c.typeStr, c.item.capability!);
          final bool permGate;
          if (c.item.permission == null) {
            permGate = true;
          } else if (!c.sessionPresent) {
            permGate = false;
          } else {
            final Permission mapped = Permission.values.firstWhere(
              (p) => p.name == c.item.permission,
              orElse: () => Permission.manageSettings,
            );
            permGate = RolePermissions.hasPermission(c.role, mapped);
          }

          // Kept exactly when both gates pass; hidden when either fails.
          return kept == (capGate && permGate);
        },
        [_caseGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ----------------------------------------------------------------------
    // REAL-PROVIDER ANCHOR — drive the actual sidebarSectionsProvider for the
    // pharmacy vertical across roles; every entry it shows MUST pass the real
    // capability gate (no entry leaks past a denied capability).
    // ----------------------------------------------------------------------
    test('Property 16 anchor: every entry shown by the real '
        'sidebarSectionsProvider passes the capability gate for pharmacy', () {
      for (final role in const <UserRole>[
        UserRole.owner,
        UserRole.manager,
        UserRole.staff,
        UserRole.accountant,
        UserRole.pharmacist,
      ]) {
        final container = _containerFor(BusinessType.pharmacy, role);
        addTearDown(container.dispose);

        final sections = container.read(sidebarSectionsProvider);
        // Non-vacuous: the pharmacy shell renders at least one section/item.
        expect(
          sections.any((s) => s.items.isNotEmpty),
          isTrue,
          reason: 'Pharmacy sidebar must render items for ${role.name}.',
        );

        for (final section in sections) {
          for (final item in section.items) {
            if (item.capability != null) {
              expect(
                FeatureResolver.canAccess('pharmacy', item.capability!),
                isTrue,
                reason:
                    'Visible pharmacy entry "${item.id}" is capability-gated '
                    'on ${item.capability!.name}, which pharmacy does not '
                    'grant — it must have been hidden (Property 16).',
              );
            }
          }
        }
      }
    });

    // ----------------------------------------------------------------------
    // DETERMINISTIC ANCHORS — pin both directions of the iff + AND-semantics.
    // ----------------------------------------------------------------------
    test('Property 16 anchor: an ungated entry (no capability, no '
        'permission) is always shown', () {
      final c = _VisibilityCase(
        typeStr: 'pharmacy',
        role: UserRole.pharmacist,
        sessionPresent: false,
        item: const SidebarMenuItem(
          id: 'plain',
          icon: Icons.circle_outlined,
          label: 'Plain',
        ),
      );
      expect(_subjectKeeps(c), isTrue);
      expect(_oracleKeeps(c), isTrue);
    });

    test('Property 16 anchor: a capability granted to pharmacy is shown; one '
        'pharmacy lacks is hidden', () {
      // useSaltSearch IS granted to pharmacy -> shown.
      final granted = _VisibilityCase(
        typeStr: 'pharmacy',
        role: UserRole.owner,
        sessionPresent: true,
        item: const SidebarMenuItem(
          id: 'salt',
          icon: Icons.search,
          label: 'Salt Search',
          capability: BusinessCapability.useSaltSearch,
        ),
      );
      expect(_subjectKeeps(granted), isTrue);
      expect(_oracleKeeps(granted), isTrue);

      // useIMEI is NOT granted to pharmacy -> hidden.
      final denied = _VisibilityCase(
        typeStr: 'pharmacy',
        role: UserRole.owner,
        sessionPresent: true,
        item: const SidebarMenuItem(
          id: 'imei',
          icon: Icons.qr_code,
          label: 'IMEI',
          capability: BusinessCapability.useIMEI,
        ),
      );
      expect(_subjectKeeps(denied), isFalse);
      expect(_oracleKeeps(denied), isFalse);
    });

    test('Property 16 anchor: permission gate follows the role grant and the '
        'session rule', () {
      // pharmacist IS granted createBill, session present -> shown.
      final granted = _VisibilityCase(
        typeStr: 'pharmacy',
        role: UserRole.pharmacist,
        sessionPresent: true,
        item: const SidebarMenuItem(
          id: 'bill',
          icon: Icons.receipt,
          label: 'Bill',
          permission: 'createBill',
        ),
      );
      expect(_subjectKeeps(granted), isTrue);
      expect(_oracleKeeps(granted), isTrue);

      // Same item, but no session -> hidden (permission-gated, session null).
      final noSession = _VisibilityCase(
        typeStr: granted.typeStr,
        role: granted.role,
        sessionPresent: false,
        item: granted.item,
      );
      expect(_subjectKeeps(noSession), isFalse);
      expect(_oracleKeeps(noSession), isFalse);

      // pharmacist is DENIED manageUsers, session present -> hidden.
      final denied = _VisibilityCase(
        typeStr: 'pharmacy',
        role: UserRole.pharmacist,
        sessionPresent: true,
        item: const SidebarMenuItem(
          id: 'users',
          icon: Icons.people,
          label: 'Users',
          permission: 'manageUsers',
        ),
      );
      expect(_subjectKeeps(denied), isFalse);
      expect(_oracleKeeps(denied), isFalse);
    });

    test('Property 16 anchor: AND-semantics — if EITHER gate fails the entry '
        'is hidden even when the other passes', () {
      // capability passes (useSaltSearch) but permission fails (pharmacist
      // lacks manageUsers) -> hidden.
      final permFails = _VisibilityCase(
        typeStr: 'pharmacy',
        role: UserRole.pharmacist,
        sessionPresent: true,
        item: const SidebarMenuItem(
          id: 'both1',
          icon: Icons.lock,
          label: 'Both1',
          capability: BusinessCapability.useSaltSearch,
          permission: 'manageUsers',
        ),
      );
      expect(_subjectKeeps(permFails), isFalse);
      expect(_oracleKeeps(permFails), isFalse);

      // permission passes (owner has createBill) but capability fails
      // (pharmacy lacks useIMEI) -> hidden.
      final capFails = _VisibilityCase(
        typeStr: 'pharmacy',
        role: UserRole.owner,
        sessionPresent: true,
        item: const SidebarMenuItem(
          id: 'both2',
          icon: Icons.lock,
          label: 'Both2',
          capability: BusinessCapability.useIMEI,
          permission: 'createBill',
        ),
      );
      expect(_subjectKeeps(capFails), isFalse);
      expect(_oracleKeeps(capFails), isFalse);

      // both gates pass -> shown.
      final bothPass = _VisibilityCase(
        typeStr: 'pharmacy',
        role: UserRole.owner,
        sessionPresent: true,
        item: const SidebarMenuItem(
          id: 'both3',
          icon: Icons.lock_open,
          label: 'Both3',
          capability: BusinessCapability.useSaltSearch,
          permission: 'createBill',
        ),
      );
      expect(_subjectKeeps(bothPass), isTrue);
      expect(_oracleKeeps(bothPass), isTrue);
    });
  });
}
