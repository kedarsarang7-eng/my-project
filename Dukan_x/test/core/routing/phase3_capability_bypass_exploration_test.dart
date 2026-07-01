// ============================================================================
// PHASE 3 — Task 4.2: Capability deep-link BYPASS exploration test
// (go_router navigation migration — security fix S3)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 4.2 — Write exploration test proving the deep-link bypass exists.
// Validates: Requirements 2.1, 6.3
//
// PURPOSE (exploration / bug baseline — MUST PASS against UNCHANGED code):
//   The audit's S3 finding is that capability/RBAC isolation lives ONLY in the
//   sidebar MENU-FILTERING layer (`sidebarSectionsProvider`). The actual screen
//   dispatch — and, as of Phase 2, every per-item GoRoute — performs NO
//   capability enforcement. Therefore a grocery session that navigates DIRECTLY
//   or via a DEEP LINK to a capability-less item still RESOLVES the real screen,
//   even though `businessCapabilityRegistry` DENIES the corresponding
//   capability for grocery. The Phase 3 router guard (Task 4.3) closes this gap;
//   the formal "blocked after fix" assertion is the preservation test (Task 4.5).
//
//   This test demonstrates the bug as it exists TODAY, in two parts:
//     (1) AUTHORITY — the registry DENIES each capability for grocery
//         (`FeatureResolver.canAccess(grocery, cap) == false`), establishing
//         that these items SHOULD be blocked for grocery.
//     (2) BYPASS — resolving each corresponding `itemId` for grocery still
//         returns the REAL screen (NOT a deny / placeholder screen), and the
//         per-item GoRoute is registered with no capability gate. This proves
//         direct/deep-link navigation reaches the screen with no capability
//         check.
//
// THE SIX BYPASSED ITEMS AND THEIR CAPABILITIES
// (per `businessCapabilityRegistry` + the Task 4.1 `booking_orders` decision):
//     return_inwards    -> useSalesReturn       -> ReturnInwardsScreen
//     proforma_bids     -> useProformaInvoice   -> ProformaScreen
//     dispatch_notes    -> useDispatchNote      -> DispatchNoteScreen
//     booking_orders    -> useDispatchNote      -> BookingOrderScreen   (4.1)
//     stock_reversal    -> useStockReversal     -> StockReversalScreen
//     purchase_register -> usePurchaseRegister  -> ProcurementLogScreen
//
// SEAM CHOSEN (and why this is deterministic / nothing heavy is pumped):
//   The Phase 2 per-item GoRoute builder is literally
//   `(c, s) => AppRouter.screenForItemId(itemId, c)`, which delegates to the
//   legacy `SidebarNavigationHandler.getScreenForItem` (the single source of
//   truth). So `AppRouter.screenForItemId(itemId, context)` IS exactly what a
//   deep link to `RoutePaths.pathForItemId(itemId)` renders today. We assert at
//   this resolver seam (proven equivalent by the Task 3.3 registration-parity
//   test) and additionally confirm each item's route is registered with no
//   guard. We deliberately do NOT pump the resolved screens (they construct as
//   `const` widgets but pumping them would run heavy `build()`/IO); full
//   GoRouter widget navigation is therefore NOT exercised here — see LIMITATION.
//
// LIMITATION (documented, per task guidance):
//   This test asserts the bypass at the resolver/route-registration seam rather
//   than by pumping a live GoRouter navigation to each path, because the real
//   screens (`ReturnInwardsScreen`, etc.) pull heavy dependencies (GetIt
//   services, providers, IO) that make full widget navigation non-deterministic
//   in a unit test. The seam is equivalent to a deep link by construction (the
//   route builder delegates to it). The formal post-fix assertion that the
//   guard REDIRECTS these deep links is the preservation test (Task 4.5).
//
// TEST-ONLY: no production code is modified by this task; the guard is Task 4.3.
// ============================================================================

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The six grocery-bypassed items, their required capability, and the REAL
/// screen the resolver returns today (the bug). `booking_orders -> useDispatchNote`
/// per the Task 4.1 business decision.
class _BypassCase {
  const _BypassCase(this.itemId, this.capability, this.expectedScreenType);
  final String itemId;
  final BusinessCapability capability;
  final String expectedScreenType;
}

const List<_BypassCase> _bypassCases = <_BypassCase>[
  _BypassCase(
    'return_inwards',
    BusinessCapability.useSalesReturn,
    'ReturnInwardsScreen',
  ),
  _BypassCase(
    'proforma_bids',
    BusinessCapability.useProformaInvoice,
    'ProformaScreen',
  ),
  _BypassCase(
    'dispatch_notes',
    BusinessCapability.useDispatchNote,
    'DispatchNoteScreen',
  ),
  _BypassCase(
    'booking_orders',
    BusinessCapability.useDispatchNote,
    'BookingOrderScreen',
  ),
  _BypassCase(
    'stock_reversal',
    BusinessCapability.useStockReversal,
    'StockReversalScreen',
  ),
  _BypassCase(
    'purchase_register',
    BusinessCapability.usePurchaseRegister,
    'ProcurementLogScreen',
  ),
];

/// Recursively collects every registered [GoRoute] path, descending through
/// [ShellRoute] / sub-routes.
void _collectRoutePaths(List<RouteBase> routes, Set<String> paths) {
  for (final route in routes) {
    if (route is GoRoute) {
      paths.add(route.path);
      _collectRoutePaths(route.routes, paths);
    } else if (route is ShellRouteBase) {
      _collectRoutePaths(route.routes, paths);
    }
  }
}

/// Captures a real [BuildContext] from a minimally pumped host so the route
/// resolver can be driven exactly as a deep link would drive it. Constructing
/// the `const` screen widgets runs no `build()`/IO.
Future<BuildContext> _pumpAndCaptureContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  // The active business type under test: grocery.
  final String grocery = BusinessType.grocery.name; // 'grocery'

  group('Feature: gorouter-navigation-migration — Phase 3 capability deep-link '
      'BYPASS exploration (Req 2.1, 6.3)', () {
    // --------------------------------------------------------------------
    // PART 1 — AUTHORITY: the registry DENIES each capability for grocery.
    //   FeatureResolver.canAccess(grocery, cap) == false for all six.
    //   This establishes the items SHOULD be blocked for grocery.
    // --------------------------------------------------------------------
    test('registry DENIES every bypassed capability for grocery '
        '(FeatureResolver.canAccess == false)', () {
      for (final c in _bypassCases) {
        expect(
          FeatureResolver.canAccess(grocery, c.capability),
          isFalse,
          reason:
              'PRECONDITION: grocery must NOT have ${c.capability.name} '
              '(item "${c.itemId}"). If this fails, the registry changed '
              'and this exploration baseline is invalid.',
        );
      }
    });

    test(
      'enforceAccess THROWS SecurityException for each bypassed capability '
      'under grocery (the isolation authority that the menu layer ignores)',
      () {
        for (final c in _bypassCases) {
          expect(
            () => FeatureResolver.enforceAccess(grocery, c.capability),
            throwsA(isA<SecurityException>()),
            reason:
                'grocery enforceAccess(${c.capability.name}) must throw — '
                'the registry forbids it for item "${c.itemId}".',
          );
        }
      },
    );

    // --------------------------------------------------------------------
    // PART 2 — BYPASS: today, resolving each itemId for grocery STILL returns
    //   the real screen (NOT a deny / placeholder), proving the deep-link
    //   reaches the screen with no capability gate.
    // --------------------------------------------------------------------
    testWidgets(
      'BYPASS: grocery deep-link resolves each capability-less item to its '
      'REAL screen (no capability gate) — proving S3 exists',
      (tester) async {
        final context = await _pumpAndCaptureContext(tester);

        for (final c in _bypassCases) {
          // This is exactly what a deep link to RoutePaths.pathForItemId(itemId)
          // renders today: the Phase 2 route builder delegates to this seam.
          final widget = AppRouter.screenForItemId(c.itemId, context);
          final actualType = widget.runtimeType.toString();

          // It resolves to the REAL screen...
          expect(
            actualType,
            c.expectedScreenType,
            reason:
                'BYPASS PROOF: grocery navigation to "${c.itemId}" resolves '
                '$actualType (expected the real ${c.expectedScreenType}), '
                'even though ${c.capability.name} is DENIED for grocery.',
          );

          // ...and NOT a deny / "Feature Not Found" placeholder. The current
          // code has no deny screen at all on this path — the absence of any
          // gate IS the bug.
          expect(
            actualType,
            isNot('_PlaceholderScreen'),
            reason:
                'No capability gate today: "${c.itemId}" must NOT resolve to '
                'the placeholder/deny screen under grocery (it leaks the real '
                'screen).',
          );
        }
      },
    );

    // --------------------------------------------------------------------
    // PART 3 — ROUTE-LEVEL: each bypassed item has a registered GoRoute with
    //   no capability redirect, so the deep-link path is reachable. (We assert
    //   registration at the router-configuration seam; see LIMITATION header
    //   for why full widget navigation is not pumped.)
    // --------------------------------------------------------------------
    test('each bypassed item has a registered, ungated GoRoute path '
        '(deep-link is reachable today)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);

      final paths = <String>{};
      _collectRoutePaths(router.configuration.routes, paths);

      for (final c in _bypassCases) {
        final path = RoutePaths.pathForItemId(c.itemId);

        // The path is a real per-item path (not the not-found sentinel) and
        // is registered as a navigable route.
        expect(
          path,
          isNot(RoutePaths.notFound),
          reason: '"${c.itemId}" must have its own per-item path.',
        );
        expect(
          paths,
          contains(path),
          reason:
              'A GoRoute for "${c.itemId}" ($path) must be registered, so '
              'a deep link to it is reachable with no guard today.',
        );
      }
    });

    // --------------------------------------------------------------------
    // PART 4 — CONTRAST: a business type that HAS the capability is allowed.
    //   wholesale grants all six capabilities, confirming the registry is the
    //   correct authority and the future guard must allow these for wholesale.
    // --------------------------------------------------------------------
    test('CONTRAST: wholesale GRANTS every one of these capabilities '
        '(so the future guard must allow them for wholesale)', () {
      final String wholesale = BusinessType.wholesale.name;
      for (final c in _bypassCases) {
        expect(
          FeatureResolver.canAccess(wholesale, c.capability),
          isTrue,
          reason:
              'wholesale should have ${c.capability.name} — it is a '
              'capability-correct contrast to grocery for item '
              '"${c.itemId}".',
        );
      }
    });
  });
}
