// ============================================================================
// PHASE 3 — Task 4.4: PROPERTY TEST
// Feature: gorouter-navigation-migration, Property 5: Capability guard
// correctness (deny iff lacking, entry-path independent)
// **Validates: Requirements 6.1, 6.2, 6.3, 6.4**
// ============================================================================
//
// Property 5 (design.md):
//   "For any business type and any capability-bearing route, the Capability_Guard
//    allows the screen to render IF AND ONLY IF businessCapabilityRegistry grants
//    that capability to the type; the access decision is the same whether
//    navigation arrives via sidebar menu or via a direct/deep link. In
//    particular, for grocery and the items return_inwards, proforma_bids,
//    dispatch_notes, stock_reversal, purchase_register, navigation is denied."
//
// This suite proves four facets of that property:
//
//   5a. CORE BICONDITIONAL (>=100 generated iterations over the full input
//       space (18 in-scope business types) X (11 capability-bearing route ids)):
//         redirectDecision(itemId, type) == null
//                   IFF
//         FeatureResolver.canAccess(type, requiredCapabilityFor(itemId)!)
//       i.e. the guard ALLOWS (null redirect) iff the registry grants the bound
//       capability, and DENIES (-> RoutePaths.denied) otherwise. Also pins that
//       every capability-bearing route HAS a non-null binding (Req 6.1, 6.2).
//
//   5b. NO FALSE DENIALS for ungated routes (>=100 generated iterations over
//       the in-scope types X a sample of knownItemIds NOT in the binding map):
//       redirectDecision == null ALWAYS (an ungated screen is never blocked).
//
//   5c. GROCERY-SPECIFIC (Req 6.3, 6.4): for grocery, ALL SIX named items
//       (return_inwards, proforma_bids, dispatch_notes, stock_reversal,
//       purchase_register, and booking_orders per the Task 4.1 decision) are
//       DENIED — closing the audit's S3 deep-link bypass.
//
//   5d. ENTRY-PATH INDEPENDENCE (Req 6.3): the guard verdict depends ONLY on
//       (itemId, type), not on HOW the route was reached. The router resolves
//       the itemId for a navigation via `_itemIdForState`, which prefers the
//       route NAME (== itemId for per-item routes) and falls back to a PATH
//       lookup for deep-link URLs. We prove that, for every capability-bearing
//       route, the name-resolved itemId and the deep-link-path-resolved itemId
//       are identical, hence `redirectDecision` (keyed solely on the resolved
//       itemId + type) returns the same verdict for both entry paths. See the
//       "ENTRY-PATH INDEPENDENCE" group doc below for the full rationale.
//
// SEAM (per task): the security-critical decision is driven directly through
//   the PURE, deterministic seam `AppRouter.redirectDecision(itemId, type)`
//   (extracted from `capabilityRedirect`) over (itemId, businessType) — no
//   widget pumping, no GoRouterState construction. Entry-path independence is
//   asserted separately via the name-vs-path itemId resolution round-trip
//   (`RoutePaths` is the single source of truth both `_itemIdForState` paths
//   consult), which is exactly what the live `capabilityRedirect` does.
//
// PBT library: dartproptest ^0.2.1 (glados is unresolvable here — see the
//   dev_dependency note in pubspec.yaml). The variadic
//   `forAll((a, b) => boolExpr, [genA, genB], numRuns: N)` runs `numRuns`
//   generated cases and returns whether the predicate held for all of them.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/core/routing/phase3_property5_capability_guard_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required by the spec; 200 matches the default
  // and the convention used across the other property suites in this folder.
  const int kNumRuns = 200;

  // --- Input space ----------------------------------------------------------
  // The 18 in-scope business types (design Data Model 4) — the registry keys,
  // i.e. every BusinessType enum member EXCEPT `other`. We drive the guard with
  // the enum `.name` exactly as the live router does
  // (`ref.read(businessTypeProvider).type.name`).
  final List<String> inScopeTypes = BusinessType.values
      .where((t) => t != BusinessType.other)
      .map((t) => t.name)
      .toList();

  // Capability-bearing routes = the keys of the guard's binding map. We derive
  // them from the public seam `requiredCapabilityFor` over the full known
  // itemId inventory so the test tracks the production binding map and cannot
  // silently drift from it (no hand-copied list to rot).
  final List<String> capabilityBearingItems = RoutePaths.knownItemIds
      .where((id) => AppRouter.requiredCapabilityFor(id) != null)
      .toList();

  // Ungated routes = known itemIds with NO capability binding. Used to prove
  // the guard never produces a FALSE denial.
  final List<String> ungatedItems = RoutePaths.knownItemIds
      .where((id) => AppRouter.requiredCapabilityFor(id) == null)
      .toList();

  // The six grocery items the design names explicitly (Req 6.3/6.4):
  // booking_orders included per the Task 4.1 business decision.
  const List<String> groceryDeniedItems = <String>[
    'return_inwards',
    'proforma_bids',
    'dispatch_notes',
    'stock_reversal',
    'purchase_register',
    'booking_orders',
  ];

  // Sanity-check the input space is what the design/task describe, so a future
  // edit to the binding map that changes the surface is caught here too.
  setUpAll(() {
    expect(
      inScopeTypes,
      hasLength(18),
      reason: 'Property 5 input space is the 18 in-scope business types.',
    );
    expect(
      capabilityBearingItems.toSet(),
      <String>{
        // 5 mirrored from sidebar_configuration.dart
        'scan_qr',
        'prescriptions',
        'medicine_master',
        'batch_tracking',
        'restaurant_tables',
        // 6 new bindings (incl. booking_orders per Task 4.1)
        'return_inwards',
        'proforma_bids',
        'dispatch_notes',
        'booking_orders',
        'stock_reversal',
        'purchase_register',
      },
      reason:
          'capability-bearing routes = the 11 binding-map keys '
          '(5 mirrored + 6 new).',
    );
    expect(ungatedItems, isNotEmpty);
  });

  // --- Generators -----------------------------------------------------------
  final Generator<String> typeGen = Gen.elementOf<String>(inScopeTypes);
  final Generator<String> gatedItemGen = Gen.elementOf<String>(
    capabilityBearingItems,
  );
  final Generator<String> ungatedItemGen = Gen.elementOf<String>(ungatedItems);

  group('Feature: gorouter-navigation-migration, Property 5: Capability guard '
      'correctness (deny iff lacking, entry-path independent) — '
      'Req 6.1, 6.2, 6.3, 6.4', () {
    // ----------------------------------------------------------------------
    // Property 5a — CORE BICONDITIONAL (allow iff registry grants).
    // ----------------------------------------------------------------------
    test(
      'Property 5: for any (type, capability-bearing route), the guard '
      'ALLOWS iff the registry grants the bound capability (else denies)',
      () {
        final held = forAll(
          (String type, String itemId) {
            final BusinessCapability? cap = AppRouter.requiredCapabilityFor(
              itemId,
            );
            // Every capability-bearing route MUST have a binding (Req 6.1/6.2):
            // if this is null the input space is wrong, fail the case.
            if (cap == null) return false;

            final bool granted = FeatureResolver.canAccess(type, cap);
            final String? decision = AppRouter.redirectDecision(itemId, type);

            // Biconditional: allowed (null) IFF granted; denied otherwise.
            if (granted) {
              return decision == null;
            }
            return decision == RoutePaths.denied;
          },
          [typeGen, gatedItemGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ----------------------------------------------------------------------
    // Property 5b — NO FALSE DENIALS for ungated routes.
    // ----------------------------------------------------------------------
    test('Property 5: for any (type, UNGATED route), the guard always ALLOWS '
        '(null redirect) — no false denials', () {
      final held = forAll(
        (String type, String itemId) {
          // Ungated by construction; the guard must never block it.
          return AppRouter.redirectDecision(itemId, type) == null;
        },
        [typeGen, ungatedItemGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ----------------------------------------------------------------------
    // Property 5c — GROCERY-SPECIFIC denials (Req 6.3, 6.4 / S3 fix).
    // Deterministic (small, named set) — asserted directly.
    // ----------------------------------------------------------------------
    test('Property 5: grocery navigation to all six named items is DENIED '
        '(return_inwards, proforma_bids, dispatch_notes, stock_reversal, '
        'purchase_register, booking_orders)', () {
      const String grocery = 'grocery';
      for (final itemId in groceryDeniedItems) {
        final cap = AppRouter.requiredCapabilityFor(itemId);
        expect(
          cap,
          isNotNull,
          reason: '"$itemId" must carry a capability binding.',
        );
        // Precondition: grocery genuinely lacks the bound capability.
        expect(
          FeatureResolver.canAccess(grocery, cap!),
          isFalse,
          reason:
              'grocery must NOT grant ${cap.name} (else the deny premise '
              'is invalid).',
        );
        // Verdict: denied.
        expect(
          AppRouter.redirectDecision(itemId, grocery),
          RoutePaths.denied,
          reason: 'grocery deep-link/menu nav to "$itemId" must be denied.',
        );
      }
    });

    // ----------------------------------------------------------------------
    // Property 5d — ENTRY-PATH INDEPENDENCE (Req 6.3).
    //
    // The live guard resolves a navigation's itemId via
    // `AppRouter._itemIdForState`, which:
    //   (1) prefers the route NAME — and per-item GoRoutes are registered with
    //       `name == itemId`, so a SIDEBAR-MENU tap (which navigates by name)
    //       yields `state.name == itemId`; and
    //   (2) falls back to a PATH lookup (`RoutePaths.itemIdForPath`) so a
    //       DIRECT/DEEP-LINK navigation by URL still resolves the same itemId.
    // Both paths consult the SAME `RoutePaths` single source of truth, so they
    // must agree. `redirectDecision` is then keyed SOLELY on the resolved
    // (itemId, type) — it has no notion of "how" the route was reached — so the
    // verdict is identical for menu vs deep-link entry.
    //
    // We assert that equivalence as a property: for every capability-bearing
    // route and every in-scope type, the NAME-resolved itemId and the
    // PATH-resolved itemId are identical AND yield the same guard verdict. This
    // is exactly the (itemId, type) keying `capabilityRedirect` relies on, so
    // it is asserted without constructing a heavy GoRouterState.
    // ----------------------------------------------------------------------
    test(
      'Property 5: guard verdict is ENTRY-PATH INDEPENDENT — name-resolved '
      'and deep-link-path-resolved itemId agree and give the same verdict',
      () {
        final held = forAll(
          (String type, String itemId) {
            // (1) Menu/name entry: per-item route name == itemId, recognised by
            //     the guard's name branch.
            if (!RoutePaths.isKnownItemId(itemId)) return false;
            final String nameResolved = itemId;

            // (2) Deep-link/path entry: resolve the itemId from the route's URL
            //     path, exactly as the guard's path-fallback branch does.
            final String path = RoutePaths.pathForItemId(itemId);
            final String? pathResolved = RoutePaths.itemIdForPath(path);

            // Both entry paths must resolve to the SAME itemId...
            if (pathResolved != nameResolved) return false;

            // ...and therefore the guard verdict must be identical.
            final String? viaName = AppRouter.redirectDecision(
              nameResolved,
              type,
            );
            final String? viaPath = AppRouter.redirectDecision(
              pathResolved,
              type,
            );
            return viaName == viaPath;
          },
          [typeGen, gatedItemGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );
  });
}
