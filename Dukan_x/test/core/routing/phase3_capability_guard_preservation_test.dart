// ============================================================================
// PHASE 3 — Task 4.5: Capability router-guard PRESERVATION test
// (go_router navigation migration — security fix S3)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 4.5 — Write preservation test for the guard.
// Validates: Requirements 2.2, 2.3, 6.1, 6.2
//
// WHAT THIS TEST PROVES (post-fix preservation — the bookend of Task 4.2):
//   Task 4.2 (`phase3_capability_bypass_exploration_test.dart`) proved, against
//   the UNCHANGED code, that grocery's six previously-ungated deep-links
//   (return_inwards, proforma_bids, dispatch_notes, booking_orders,
//   stock_reversal, purchase_register) RESOLVED their real screens with NO
//   capability gate — the audit's S3 bypass. Task 4.3 added the router-level
//   guard (`AppRouter.redirectDecision` / `capabilityRedirect`).
//
//   This PRESERVATION test asserts the fix is now closed AND that no in-scope
//   business type lost any legitimate access. It is framed as three claims over
//   the FULL set of 18 in-scope business types (design Data Model 4) — so it is
//   a non-regression / no-over-block proof, not a spot check:
//
//     (1) FIXED (Req 6.1, 6.3 — closes the 4.2 baseline):
//         For GROCERY, `redirectDecision` for each of the SIX items the 4.2
//         exploration showed as bypassed now returns `RoutePaths.denied`. The
//         pre-fix bypass (real screen, no gate) is replaced by a deny verdict.
//
//     (2) ALLOWED-PRESERVED / NO OVER-BLOCK (Req 2.3, 6.2):
//         For EVERY capability-bearing route and EVERY in-scope type that the
//         registry GRANTS the bound capability, the guard ALLOWS the route
//         (`redirectDecision == null`). The "allowed" set is computed
//         EXHAUSTIVELY from `FeatureResolver.canAccess` across all 18 types
//         (NOT hardcoded), so the guard provably never regresses a type's
//         legitimate access to a gated screen. (The symmetric deny side — types
//         that LACK the capability are denied — is asserted too, giving the full
//         biconditional exhaustively over 18 types × 11 gated routes.)
//
//     (3) NON-REGRESSION on UNGATED routes (Req 2.2, 2.3):
//         For ALL 18 types and EVERY ungated itemId, `redirectDecision == null`
//         (never denied). No business type lost access to any non-capability
//         screen as a side effect of adding the guard.
//
// SEAM (per task — no widget pumping):
//   Driven entirely through the PURE, deterministic decision seam
//   `AppRouter.redirectDecision(itemId, businessType)` (extracted from
//   `capabilityRedirect`) over (itemId, type). The router resolves a
//   navigation's itemId via `RoutePaths` (name- or deep-link-path-based) and
//   then keys the verdict solely on (itemId, type); Property 5 (Task 4.4)
//   already proved entry-path independence, so this preservation test asserts
//   the decision directly without constructing GoRouterState or pumping the
//   heavy real screens.
//
// CONTRAST WITH 4.2 (pre-fix → post-fix bookend):
//   4.2: grocery deep-link to the six items → REAL screen, NO gate (bypass).
//   4.5: grocery deep-link to the same six items → `RoutePaths.denied` (gated),
//        while every type that genuinely holds the capability is UNCHANGED
//        (still allowed) — proving the fix is targeted, not a blunt block.
//
// TEST-ONLY: no production code is modified by this task.
//
// Run: flutter test test/core/routing/phase3_capability_guard_preservation_test.dart
// ============================================================================

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // --- Input space ----------------------------------------------------------
  // The 18 in-scope business types (design Data Model 4) = every BusinessType
  // enum member EXCEPT `other` (the registry keys we enforce against). Drive
  // the guard with the enum `.name` exactly as the live router does
  // (`ref.read(businessTypeProvider).type.name`).
  final List<String> inScopeTypes = BusinessType.values
      .where((t) => t != BusinessType.other)
      .map((t) => t.name)
      .toList();

  // Capability-bearing routes = the keys of the guard's binding map, derived
  // from the public seam `requiredCapabilityFor` over the full known itemId
  // inventory so this test tracks the production bindings and cannot drift.
  final List<String> gatedItems = RoutePaths.knownItemIds
      .where((id) => AppRouter.requiredCapabilityFor(id) != null)
      .toList();

  // Ungated routes = known itemIds with NO capability binding.
  final List<String> ungatedItems = RoutePaths.knownItemIds
      .where((id) => AppRouter.requiredCapabilityFor(id) == null)
      .toList();

  // The SIX grocery items the 4.2 exploration proved as bypassed (the baseline
  // this preservation test closes). booking_orders included per the Task 4.1
  // business decision (→ useDispatchNote).
  const List<String> groceryFixedItems = <String>[
    'return_inwards',
    'proforma_bids',
    'dispatch_notes',
    'booking_orders',
    'stock_reversal',
    'purchase_register',
  ];

  const String grocery = 'grocery';

  // Sanity-pin the input surface so a future binding-map edit that changes the
  // gated/ungated split is surfaced here rather than silently passing.
  setUpAll(() {
    expect(
      inScopeTypes,
      hasLength(18),
      reason: 'Preservation must cover all 18 in-scope business types.',
    );
    expect(
      gatedItems.toSet(),
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
      reason: 'capability-bearing routes = the 11 binding-map keys.',
    );
    // Every grocery-fixed item must actually be a gated route now.
    for (final id in groceryFixedItems) {
      expect(
        gatedItems,
        contains(id),
        reason: '"$id" (4.2 baseline) must now carry a capability binding.',
      );
    }
    expect(ungatedItems, isNotEmpty);
  });

  group('Feature: gorouter-navigation-migration — Phase 3 capability guard '
      'PRESERVATION (post-fix, 18 in-scope types) — Req 2.2, 2.3, 6.1, 6.2', () {
    // --------------------------------------------------------------------
    // (1) FIXED — closes the Task 4.2 deep-link bypass baseline.
    //   For grocery, each of the six items the 4.2 exploration proved as
    //   bypassed (real screen, no gate) now REDIRECTS to RoutePaths.denied.
    // --------------------------------------------------------------------
    test('FIXED: grocery deep-link to each of the six 4.2-baseline items now '
        'redirects to the deny screen (S3 closed at the guard level)', () {
      for (final itemId in groceryFixedItems) {
        final cap = AppRouter.requiredCapabilityFor(itemId);
        expect(
          cap,
          isNotNull,
          reason: '"$itemId" must carry a capability binding (Req 6.4).',
        );

        // Pre-condition mirrors the 4.2 PART-1 authority assertion: grocery
        // genuinely lacks the bound capability (else the deny premise is
        // invalid). This is the SAME registry fact 4.2 recorded pre-fix.
        expect(
          FeatureResolver.canAccess(grocery, cap!),
          isFalse,
          reason:
              'grocery must NOT grant ${cap.name} — the 4.2 exploration '
              'baseline for "$itemId".',
        );

        // POST-FIX verdict (contrast with 4.2 BYPASS): denied, not the real
        // screen. The 4.2 test asserted the resolver returned the real
        // screen with no gate; here the guard intercepts first.
        expect(
          AppRouter.redirectDecision(itemId, grocery),
          RoutePaths.denied,
          reason:
              'PRESERVATION: grocery deep-link to "$itemId" must now be '
              'DENIED (4.2 proved it was bypassed pre-fix).',
        );
      }
    });

    // --------------------------------------------------------------------
    // (2) ALLOWED-PRESERVED / NO OVER-BLOCK (Req 2.3, 6.2).
    //   For every capability-bearing route, every in-scope type that the
    //   registry GRANTS the bound capability is ALLOWED (null redirect).
    //   The allowed set is computed EXHAUSTIVELY from canAccess across all
    //   18 types — proving the guard denies ONLY where the registry denies
    //   and regresses no type's legitimate access. The symmetric deny side
    //   is asserted in the same loop, giving the full biconditional over
    //   18 types × 11 gated routes (198 checks).
    // --------------------------------------------------------------------
    test('ALLOWED-PRESERVED: for every gated route, every in-scope type that '
        'GRANTS the capability is allowed (no over-block); types that lack it '
        'are denied — biconditional across all 18 types', () {
      var allowedChecks = 0;
      var deniedChecks = 0;

      for (final itemId in gatedItems) {
        final cap = AppRouter.requiredCapabilityFor(itemId)!;

        for (final type in inScopeTypes) {
          // The authority computes the EXPECTED verdict exhaustively — no
          // hardcoded allow-lists, so this can never silently drift.
          final bool granted = FeatureResolver.canAccess(type, cap);
          final String? decision = AppRouter.redirectDecision(itemId, type);

          if (granted) {
            allowedChecks++;
            expect(
              decision,
              isNull,
              reason:
                  'NO OVER-BLOCK: "$type" GRANTS ${cap.name}, so the guard '
                  'must ALLOW "$itemId" (legitimate access preserved).',
            );
          } else {
            deniedChecks++;
            expect(
              decision,
              RoutePaths.denied,
              reason:
                  '"$type" LACKS ${cap.name}, so the guard must DENY '
                  '"$itemId".',
            );
          }
        }
      }

      // Both arms of the biconditional must be exercised (the registry has
      // both granting and isolating types for these routes).
      expect(
        allowedChecks,
        greaterThan(0),
        reason: 'At least one type must legitimately retain access.',
      );
      expect(
        deniedChecks,
        greaterThan(0),
        reason: 'At least one type must be isolated (else nothing gated).',
      );
      // 18 types × 11 gated routes are all covered.
      expect(
        allowedChecks + deniedChecks,
        inScopeTypes.length * gatedItems.length,
      );
    });

    // --------------------------------------------------------------------
    // (3) NON-REGRESSION on UNGATED routes (Req 2.2, 2.3).
    //   For ALL 18 types and EVERY ungated itemId, the guard ALLOWS
    //   (null redirect). Adding the guard cost no type its access to any
    //   non-capability screen.
    // --------------------------------------------------------------------
    test('NON-REGRESSION: all 18 in-scope types reach EVERY ungated route '
        '(guard never denies a non-capability screen)', () {
      for (final type in inScopeTypes) {
        for (final itemId in ungatedItems) {
          expect(
            AppRouter.redirectDecision(itemId, type),
            isNull,
            reason:
                '"$type" must still reach ungated "$itemId" — no guard '
                'over-reach onto non-capability screens.',
          );
        }
      }
    });

    // --------------------------------------------------------------------
    // Cross-check vs Task 4.2 CONTRAST (wholesale grants all six): the
    // capability-correct contrast type the exploration named keeps full
    // access to the now-gated grocery items — the fix is targeted.
    // --------------------------------------------------------------------
    test('CONTRAST (vs 4.2): wholesale (grants all six) still reaches every '
        'item grocery is now denied — fix is targeted, not a blunt block', () {
      const String wholesale = 'wholesale';
      for (final itemId in groceryFixedItems) {
        final cap = AppRouter.requiredCapabilityFor(itemId)!;
        expect(
          FeatureResolver.canAccess(wholesale, cap),
          isTrue,
          reason: 'wholesale should grant ${cap.name} (4.2 contrast).',
        );
        expect(
          AppRouter.redirectDecision(itemId, wholesale),
          isNull,
          reason:
              'wholesale must still reach "$itemId" while grocery is '
              'denied (no regression for capability-bearing types).',
        );
      }
    });
  });
}
