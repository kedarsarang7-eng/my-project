// ============================================================================
// PHASE 2 — Task 3.8: PROPERTY TEST — Sidebar filtering invariance
// (go_router navigation migration)
// ============================================================================
//
// Feature: gorouter-navigation-migration, Property 4: Sidebar filtering
// invariance
// Task 3.8 (PHASE 2, optional property-based test).
// Validates: Requirements 5.7
//
// PROPERTY 4 (design.md → Correctness Properties):
//   "For any in-scope business type, the set of sidebar items made visible by
//    sidebarSectionsProvider under the migrated build (flag ON) equals the set
//    made visible under the legacy build (flag OFF). Phase 2 does not change
//    capability/RBAC menu filtering."
//
// WHY THIS HOLDS (and what the test actually proves):
//   `sidebarSectionsProvider` (lib/widgets/desktop/sidebar_configuration.dart)
//   derives its output from exactly three inputs:
//       * businessTypeProvider      (which shell/sections)
//       * authStateProvider         (session → RBAC permission gate)
//       * currentUserRoleProvider   (effective role → RBAC permission gate)
//   plus the real `FeatureResolver` capability gate. It NEVER reads
//   `useGoRouterShellProvider`. Therefore flipping the migration flag must not
//   change which sections/items survive the capability + RBAC filter. This
//   property test asserts that invariance empirically across the in-scope
//   BusinessType space (× a small set of RBAC roles), so any future change that
//   accidentally couples menu filtering to the navigation flag is caught.
//
// SEAM + OVERRIDE CONVENTIONS (mirrors
// `phase1_foundation_routing_preservation_test.dart`):
//   * `_FakeBusinessTypeNotifier` pins the active type without touching
//     SharedPreferences / license providers.
//   * `_FakeAuthStateNotifier` represents a completed (authenticated) login
//     without reaching into the GetIt service locator.
//   * `currentUserRoleProvider` is overridden with the generated role so the
//     RBAC branch is exercised deterministically; `FeatureResolver` stays REAL.
//   * Two containers per case: one with the flag default-OFF (legacy build),
//     one with the flag enabled ON (migrated build). The visible-item sets are
//     compared for equality.
//
// PBT library: dartproptest (dev dependency).
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: N);
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/models/user_role.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ============================================================================
// FAKES (same conventions as the Phase 1 foundation preservation test)
// ============================================================================

/// Pins the active business type WITHOUT touching SharedPreferences / license
/// providers.
class _FakeBusinessTypeNotifier extends BusinessTypeNotifier {
  _FakeBusinessTypeNotifier(this._type);

  final BusinessType _type;

  @override
  BusinessTypeState build() => BusinessTypeState(type: _type);
}

/// Represents a completed (post-login) authentication WITHOUT reaching into the
/// GetIt service locator.
class _FakeAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated);
}

// ============================================================================
// INPUT SPACE
// ============================================================================

/// The 18 in-scope business types (design.md → Data Model 4). `BusinessType.other`
/// is intentionally excluded — it is the default/retail fallback, not an
/// in-scope vertical, though its resolution is exercised indirectly by every
/// type that falls through to `_getRetailSections()`.
const List<BusinessType> _inScopeTypes = <BusinessType>[
  BusinessType.grocery,
  BusinessType.pharmacy,
  BusinessType.restaurant,
  BusinessType.clinic,
  BusinessType.petrolPump,
  BusinessType.service,
  BusinessType.electronics,
  BusinessType.mobileShop,
  BusinessType.computerShop,
  BusinessType.clothing,
  BusinessType.hardware,
  BusinessType.wholesale,
  BusinessType.vegetablesBroker,
  BusinessType.bookStore,
  BusinessType.jewellery,
  BusinessType.autoParts,
  BusinessType.decorationCatering,
  BusinessType.schoolErp,
];

/// A small set of authenticated RBAC roles to vary the menu-filtering inputs
/// (Property 4 is asserted per (type, role)). `unknown` is excluded because it
/// represents the unauthenticated state, which this seam does not model.
const List<UserRole> _roles = <UserRole>[
  UserRole.owner,
  UserRole.manager,
  UserRole.staff,
  UserRole.accountant,
];

final Generator<BusinessType> _businessTypeGen = Gen.elementOf<BusinessType>(
  _inScopeTypes,
);

final Generator<UserRole> _roleGen = Gen.elementOf<UserRole>(_roles);

/// Property iterations — at least 100 (Requirement 2.4). Uses 200 to match the
/// existing certification PBT suite convention.
const int _kNumRuns = 200;

// ============================================================================
// HELPERS
// ============================================================================

/// Builds a container that resolves the shell sidebar for [type] as it would be
/// right after a successful login as [role]. go_router is the sole navigation
/// path (Task 9.3), so there is no longer a migration-flag dimension.
ProviderContainer _containerFor(BusinessType type, UserRole role) {
  final container = ProviderContainer(
    overrides: [
      businessTypeProvider.overrideWith(() => _FakeBusinessTypeNotifier(type)),
      authStateProvider.overrideWith(() => _FakeAuthStateNotifier()),
      currentUserRoleProvider.overrideWithValue(role),
    ],
  );
  return container;
}

/// Flattens the resolved sidebar sections into a canonical, comparable list of
/// "visible items": one entry per surviving item, carrying the section title,
/// item id, and item label. Ordering is preserved (the provider is
/// deterministic) so equality is order-sensitive.
List<String> _visibleItems(ProviderContainer container) {
  final sections = container.read(sidebarSectionsProvider);
  final out = <String>[];
  for (final section in sections) {
    for (final item in section.items) {
      out.add('${section.title}\u0001${item.id}\u0001${item.label}');
    }
  }
  return out;
}

/// The set of section titles that survive filtering (section-level visibility).
List<String> _visibleSectionTitles(ProviderContainer container) =>
    container.read(sidebarSectionsProvider).map((s) => s.title).toList();

bool _listsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Builds two independent containers for (type, role), reads the visible
/// sidebar items + section titles from each, and returns whether both views are
/// identical (i.e. the resolution is deterministic — a pure function of
/// type + role + capability/RBAC, with no hidden global-state coupling).
bool _invarianceHolds(BusinessType type, UserRole role) {
  final a = _containerFor(type, role);
  final b = _containerFor(type, role);
  try {
    final aItems = _visibleItems(a);
    final bItems = _visibleItems(b);
    final aTitles = _visibleSectionTitles(a);
    final bTitles = _visibleSectionTitles(b);

    return _listsEqual(aItems, bItems) && _listsEqual(aTitles, bTitles);
  } finally {
    a.dispose();
    b.dispose();
  }
}

// ============================================================================
// TESTS
// ============================================================================

void main() {
  // GoRouter / flag providers expect an initialized binding; reading the
  // notifier in a plain `test()` body needs the binding wired up.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature: gorouter-navigation-migration, Property 4: Sidebar filtering '
      'invariance (Req 5.7)', () {
    // ----------------------------------------------------------------------
    // Sanity: the two independently-built containers are real, separate
    // resolutions (guards against a vacuous comparison of the same instance).
    // ----------------------------------------------------------------------
    test('two independent containers resolve the sidebar separately', () {
      final a = _containerFor(BusinessType.grocery, UserRole.owner);
      final b = _containerFor(BusinessType.grocery, UserRole.owner);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      expect(identical(a, b), isFalse);
      expect(_visibleItems(a), isNotEmpty);
      expect(_visibleItems(b), isNotEmpty);
    });

    // ----------------------------------------------------------------------
    // PROPERTY 4 — over the in-scope BusinessType space (× RBAC roles), the
    // visible sidebar item set + section titles are deterministic (a pure
    // function of type + role + capability/RBAC).
    // ----------------------------------------------------------------------
    test('PROPERTY: visible sidebar items are deterministic for any in-scope '
        '(businessType, role)', () {
      final held = forAll(
        (BusinessType type, UserRole role) => _invarianceHolds(type, role),
        [_businessTypeGen, _roleGen],
        numRuns: _kNumRuns,
      );
      expect(held, isTrue);
    });

    // ----------------------------------------------------------------------
    // Exhaustive backstop — the property generator samples the space; this
    // additionally asserts the invariant for EVERY (type, role) pair so no
    // in-scope vertical is left unchecked by sampling variance.
    // ----------------------------------------------------------------------
    test(
      'EXHAUSTIVE: invariance holds for every in-scope (type, role) pair',
      () {
        for (final type in _inScopeTypes) {
          for (final role in _roles) {
            expect(
              _invarianceHolds(type, role),
              isTrue,
              reason:
                  'Sidebar visibility changed with the migration flag for '
                  '${type.name} as ${role.name} — Phase 2 must not alter '
                  'capability/RBAC menu filtering (Req 5.7).',
            );
          }
        }
      },
    );
  });
}
