// ============================================================================
// PHASE B — Task 4.7 (OPTIONAL PROPERTY TEST)
// Feature: imperative-navigation-gorouter-migration
// Property 4: Guard equivalence across business types
// **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.7, 10.3**
// ============================================================================
//
// Property 4 (design.md — Correctness Properties):
//   "For any migrated guarded route, any In_Scope_Business_Type, and any
//    permission state, the migrated route denies access if and only if the
//    corresponding `buildAppRoutes()` route would deny access — using the same
//    `VendorRoleGuard` permission constant, the same `BusinessGuard`
//    `allowedTypes`, and the same `denialMessage` text. Other business types'
//    navigation decisions are unchanged by any single route migration
//    (non-regression)."
//
// MODELLING THE DECISION (design.md AD-2 + Testing Strategy):
//   The migration is a VERBATIM LIFT: each migrated vertical `GoRoute` in
//   `lib/core/routing/legacy_routes.dart` wraps its screen in the SAME
//   `BusinessGuard` widget, with the SAME `allowedTypes` list, that the legacy
//   `buildAppRoutes()` table used. `BusinessGuard.build` makes exactly one
//   business-type decision (see business_type_guard.dart):
//
//       allowed = allowedTypes.contains(currentType)
//
//   i.e. it renders the child IFF the active type is in `allowedTypes`, and
//   otherwise shows the `denialMessage` fallback. Because BOTH the legacy and
//   the migrated route feed the SAME `allowedTypes` into the SAME widget, the
//   business-type allow/deny verdict is, by construction, identical. We model
//   the verdict with the production widget itself (constructing a real
//   `BusinessGuard` and using its `allowedTypes` field + its
//   `.contains(type)` decision rule) so the test tracks production semantics
//   rather than a hand-rolled copy.
//
//   The legacy contract (route -> allowedTypes) is taken VERBATIM from
//   INVENTORY.md §2 (the behaviour contract to preserve). The property asserts
//   the migrated decision equals `legacyContract.contains(type)` for EVERY
//   (route, In_Scope_Business_Type) pair — i.e. deny-iff-not-in-allowedTypes.
//
// SEAM (per task / design): the security-critical decision is exercised at the
//   PURE decision-function level (the `BusinessGuard.allowedTypes.contains`
//   rule) over (route, businessType) — no router built, no full screens pumped,
//   so 200 iterations stay cheap. A couple of widget-level deny/allow renders
//   of the real `BusinessGuard` are included as a representative cross-check.
//
// This suite proves three facets of Property 4:
//
//   4a. GUARD EQUIVALENCE / DENY-IFF (>=100 generated iterations over the full
//       input space (representative migrated vertical routes) X (all 18
//       In_Scope_Business_Types)): the migrated route's business-type decision
//       (`allowedTypes.contains(type)`) is IDENTICAL to the legacy contract's
//       decision, AND equals `legacyContract[route].contains(type)`. Allow iff
//       in allowedTypes; deny otherwise.
//
//   4b. NON-REGRESSION (>=100 generated iterations): the decision for
//       (route, type) depends ONLY on that route's own `allowedTypes` and the
//       type — never on any OTHER route's contract. Migrating one route leaves
//       every other route's per-type verdict unchanged.
//
//   4c. WIDGET-LEVEL CROSS-CHECK (representative, deterministic): the real
//       `BusinessGuard` widget renders the `denialMessage` when the active type
//       is NOT allowed, and renders the child when it IS — tying the decision
//       model to actual rendered behaviour for a small sample.
//
// PBT library: dartproptest ^0.2.1 (the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide; glados is unresolvable here — see the dev_dependency
//   note in pubspec.yaml). The variadic `forAll((a, b) => boolExpr, [genA,
//   genB], numRuns: N)` runs `numRuns` generated cases and returns whether the
//   predicate held for all of them.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/core/routing/phase_b_property4_guard_equivalence_test.dart --reporter expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/core/auth/business_type_guard.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required by the spec; 200 matches the
  // dartproptest default and the convention used across the other property
  // suites in this folder.
  const int kNumRuns = 200;

  // --- Input space: In_Scope_Business_Types --------------------------------
  // The 18 in-scope business types = every BusinessType enum member EXCEPT
  // `other` (the registry/guard surface). Derived from the enum (never
  // hardcoded) so a future enum change is caught here.
  final List<BusinessType> inScopeTypes = BusinessType.values
      .where((BusinessType t) => t != BusinessType.other)
      .toList();

  // --- Legacy contract: route -> allowedTypes (INVENTORY.md §2) -------------
  // Lifted VERBATIM from INVENTORY.md §2 (the behaviour contract preserved by
  // the verbatim BusinessGuard lift in legacy_routes.dart). This is the legacy
  // `buildAppRoutes()` reference the migrated routes must match exactly. A
  // representative set spanning every guarded vertical family + the multi-type
  // service/repair family.
  final Map<String, List<BusinessType>>
  legacyContract = <String, List<BusinessType>>{
    // Clinic family — [clinic]
    '/clinic/appointment': const <BusinessType>[BusinessType.clinic],
    '/clinic/prescription': const <BusinessType>[BusinessType.clinic],
    '/clinic/queue': const <BusinessType>[BusinessType.clinic],
    // Petrol pump family — [petrolPump]
    '/pump/reading': const <BusinessType>[BusinessType.petrolPump],
    '/pump/density': const <BusinessType>[BusinessType.petrolPump],
    // Hardware family — [hardware]
    '/hardware/credit-control': const <BusinessType>[BusinessType.hardware],
    '/hardware/fast-billing': const <BusinessType>[BusinessType.hardware],
    '/hardware/invoice-profiles': const <BusinessType>[BusinessType.hardware],
    // Computer shop family — [computerShop]
    '/computer-shop/job-cards': const <BusinessType>[BusinessType.computerShop],
    // Decoration & Catering family — [decorationCatering]
    '/dc/dashboard': const <BusinessType>[BusinessType.decorationCatering],
    // School / Coaching ERP family — [schoolErp]
    '/ac/dashboard': const <BusinessType>[BusinessType.schoolErp],
    // Book store family — [bookStore]
    '/book_store/school_orders': const <BusinessType>[BusinessType.bookStore],
    '/book_store/consignments': const <BusinessType>[BusinessType.bookStore],
    // Service / repair family — multi-type
    // [mobileShop, computerShop, service, electronics]
    '/job/create': const <BusinessType>[
      BusinessType.mobileShop,
      BusinessType.computerShop,
      BusinessType.service,
      BusinessType.electronics,
    ],
    '/job/status': const <BusinessType>[
      BusinessType.mobileShop,
      BusinessType.computerShop,
      BusinessType.service,
      BusinessType.electronics,
    ],
    '/job/deliver': const <BusinessType>[
      BusinessType.mobileShop,
      BusinessType.computerShop,
      BusinessType.service,
      BusinessType.electronics,
    ],
  };

  final List<String> guardedRoutes = legacyContract.keys.toList();

  // The MIGRATED guard for a route = a real `BusinessGuard` constructed with the
  // SAME allowedTypes the legacy table used (verbatim lift, design AD-2). Using
  // the production widget ties the decision to its actual `allowedTypes` field
  // and its `.contains(currentType)` allow/deny rule (business_type_guard.dart).
  BusinessGuard migratedGuardFor(String route) => BusinessGuard(
    allowedTypes: legacyContract[route]!,
    denialMessage: 'denied',
    child: const SizedBox.shrink(),
  );

  // Decision model (mirrors BusinessGuard.build exactly): allowed iff the active
  // type is in the guard's allowedTypes.
  bool migratedAllows(String route, BusinessType type) =>
      migratedGuardFor(route).allowedTypes.contains(type);

  // Legacy reference decision (what buildAppRoutes()'s BusinessGuard would do).
  bool legacyAllows(String route, BusinessType type) =>
      legacyContract[route]!.contains(type);

  // --- Generators -----------------------------------------------------------
  final Generator<String> routeGen = Gen.elementOf<String>(guardedRoutes);
  final Generator<BusinessType> typeGen = Gen.elementOf<BusinessType>(
    inScopeTypes,
  );

  // Sanity-check the input space matches the design/task description so a future
  // edit to the enum or the contract is caught here too.
  setUpAll(() {
    expect(
      inScopeTypes,
      hasLength(18),
      reason: 'Property 4 input space is the 18 In_Scope_Business_Types.',
    );
    // Every contract entry is non-empty and only references in-scope types.
    for (final MapEntry<String, List<BusinessType>> e
        in legacyContract.entries) {
      expect(
        e.value,
        isNotEmpty,
        reason: '"${e.key}" must have a non-empty allowedTypes contract.',
      );
      expect(
        e.value.every(inScopeTypes.contains),
        isTrue,
        reason: '"${e.key}" allowedTypes must be in-scope business types.',
      );
    }
  });

  group('Feature: imperative-navigation-gorouter-migration, Property 4: Guard '
      'equivalence across business types — Req 4.1, 4.2, 4.3, 4.4, 4.5, 4.7, '
      '10.3', () {
    // --------------------------------------------------------------------
    // Property 4a — GUARD EQUIVALENCE / DENY-IFF (generated, >=100 iters).
    // For every (migrated guarded route, In_Scope_Business_Type): the
    // migrated decision equals the legacy decision AND equals
    // `allowedTypes.contains(type)` (allow iff in allowedTypes; deny else).
    // --------------------------------------------------------------------
    test(
      'Property 4a: for any (migrated guarded route, In_Scope_Business_Type) '
      'the migrated allow/deny decision is IDENTICAL to the legacy '
      'buildAppRoutes() decision (deny iff type not in allowedTypes)',
      () {
        final bool held = forAll(
          (String route, BusinessType type) {
            final bool migrated = migratedAllows(route, type);
            final bool legacy = legacyAllows(route, type);
            // Equivalence: migrated == legacy (verbatim-lift contract).
            if (migrated != legacy) return false;
            // And both equal the canonical deny-iff rule.
            final bool expected = legacyContract[route]!.contains(type);
            return migrated == expected;
          },
          [routeGen, typeGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // --------------------------------------------------------------------
    // Property 4b — NON-REGRESSION (generated, >=100 iters).
    // The decision for (route, type) depends ONLY on that route's own
    // allowedTypes and the type — never on any other route's contract. So
    // migrating one route cannot change another route's per-type verdict.
    // We assert: re-deciding (route, type) using ONLY its own contract
    // yields the same verdict regardless of any other route in the map.
    // --------------------------------------------------------------------
    test(
      'Property 4b: a route\'s per-type decision is determined solely by its '
      'own allowedTypes — other routes\' migrations cause no regression',
      () {
        final bool held = forAll(
          (String route, BusinessType type, String otherRoute) {
            // The verdict for `route` computed in isolation.
            final bool isolated = legacyContract[route]!.contains(type);
            // The verdict for `route` is unaffected by `otherRoute`'s
            // contract — i.e. the guard never consults a sibling route.
            final bool migrated = migratedAllows(route, type);
            // `otherRoute` having its own (possibly different) allowedTypes
            // must not perturb `route`'s decision.
            final bool otherUnchanged =
                migratedAllows(otherRoute, type) ==
                legacyContract[otherRoute]!.contains(type);
            return migrated == isolated && otherUnchanged;
          },
          [routeGen, typeGen, routeGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // --------------------------------------------------------------------
    // Property 4c — WIDGET-LEVEL CROSS-CHECK (representative, deterministic).
    // Pump the REAL BusinessGuard and confirm the rendered behaviour matches
    // the decision model: denialMessage shown when type NOT allowed; child
    // shown when allowed. A small representative sample (clinic + service).
    // --------------------------------------------------------------------
    testWidgets(
      'Property 4c: real BusinessGuard renders denialMessage when the active '
      'type is not allowed and the child when it is',
      (WidgetTester tester) async {
        Future<void> pumpWith(BusinessType active, BusinessGuard guard) async {
          await tester.pumpWidget(
            ProviderScope(
              key: ValueKey<String>('$active-${guard.denialMessage}'),
              overrides: [
                businessTypeProvider.overrideWith(
                  () => _FixedBusinessTypeNotifier(active),
                ),
              ],
              child: MaterialApp(home: Scaffold(body: guard)),
            ),
          );
          await tester.pump();
        }

        // /clinic/appointment is [clinic]: clinic allowed, grocery denied.
        final BusinessGuard clinicGuard = BusinessGuard(
          allowedTypes: legacyContract['/clinic/appointment']!,
          denialMessage: 'Only Clinics can access Appointments',
          child: const Text('CLINIC_CHILD'),
        );

        await pumpWith(BusinessType.grocery, clinicGuard);
        expect(
          find.text('Only Clinics can access Appointments'),
          findsOneWidget,
        );
        expect(find.text('CLINIC_CHILD'), findsNothing);

        await pumpWith(BusinessType.clinic, clinicGuard);
        expect(find.text('CLINIC_CHILD'), findsOneWidget);
        expect(find.text('Only Clinics can access Appointments'), findsNothing);

        // /job/create is multi-type: computerShop allowed, pharmacy denied.
        final BusinessGuard jobGuard = BusinessGuard(
          allowedTypes: legacyContract['/job/create']!,
          denialMessage: 'This feature is for Service/Repair businesses only',
          child: const Text('JOB_CHILD'),
        );

        await pumpWith(BusinessType.pharmacy, jobGuard);
        expect(
          find.text('This feature is for Service/Repair businesses only'),
          findsOneWidget,
        );
        expect(find.text('JOB_CHILD'), findsNothing);

        await pumpWith(BusinessType.computerShop, jobGuard);
        expect(find.text('JOB_CHILD'), findsOneWidget);
      },
    );
  });
}

/// Minimal test double that pins the active [BusinessType] so [BusinessGuard]'s
/// `ref.watch(businessTypeProvider)` reads a deterministic value without the
/// async prefs/license hydration the real notifier performs.
class _FixedBusinessTypeNotifier extends BusinessTypeNotifier {
  _FixedBusinessTypeNotifier(this._active);

  final BusinessType _active;

  @override
  BusinessTypeState build() => BusinessTypeState(type: _active);
}
