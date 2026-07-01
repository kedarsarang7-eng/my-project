// ============================================================================
// PHASE 3 — Task 4.7 (gate): DIRECT-URL capability block WIDGET test
// (go_router navigation migration — security fix S3)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Phase 3 gate criterion — "Router-level guard verified to BLOCK unauthorized
// access via DIRECT navigation (deep link), not just hidden menu items."
// Validates: Requirements 6.1, 6.3 (security fix S3); supports Req 12.1 gate.
//
// WHY THIS TEST EXISTS (and how it differs from the other Phase 3 suites):
//   * Task 4.3 `phase3_capability_guard_test.dart` and Task 4.5
//     `phase3_capability_guard_preservation_test.dart` assert the security
//     decision at the PURE seam `AppRouter.redirectDecision(itemId, type)`.
//   * Task 4.4 `phase3_property5_capability_guard_test.dart` proves ENTRY-PATH
//     INDEPENDENCE (name-resolved itemId == deep-link-path-resolved itemId).
//   These prove the DECISION is correct and path-independent, but they do not
//   literally DRIVE a GoRouter URL navigation and observe the rendered result.
//
//   This widget test closes that gap explicitly for the gate: it performs a
//   REAL deep-link `router.go(<per-item URL>)` under a GROCERY session and
//   asserts the user LANDS ON THE DENY SCREEN — not the real screen, not a
//   blank page, not a crash. It exercises the SAME production guard the live
//   router wires (`AppRouter.capabilityRedirect`) fed by a REAL
//   `GoRouterState` produced by an actual URL navigation, and renders the SAME
//   production deny screen (the deny route's builder is lifted verbatim from
//   the live `appRouterProvider` configuration).
//
// DETERMINISM (documented, per task guidance):
//   The live router's `initialLocation` is `/splash` and its per-item routes
//   build the heavy real screens (SplashScreen, AdaptiveShell, GetIt-backed
//   feature screens) which pull IO/timers and are non-deterministic to pump in
//   a unit test. So instead of pumping the live router wholesale, this test
//   builds a MINIMAL GoRouter that reuses the PRODUCTION pieces that matter for
//   the security claim:
//     (1) the EXACT production redirect guard `AppRouter.capabilityRedirect`,
//         bound to grocery, as the top-level `redirect`; and
//     (2) the EXACT production deny-route builder (the real `_AccessDeniedScreen`),
//         lifted from the live `appRouterProvider` config — so what renders is
//         the real deny screen, not a test stand-in.
//   Only the gated route's destination is a lightweight marker widget (a screen
//   the guard must PREVENT us from ever seeing) and the home is a light stub.
//   This keeps the test deterministic while the security-critical path — URL →
//   guard → deny screen — is entirely production code.
//
// TEST-ONLY: no production behavior is changed by this task.
//
// Run: flutter test test/core/routing/phase3_direct_url_block_widget_test.dart
// ============================================================================

import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A marker the guard must NEVER let us reach for a denied deep link. If this
/// text ever renders, the direct-URL block has FAILED (the bug regressed).
const String kRealScreenMarker = 'REAL_GATED_SCREEN_RENDERED';

/// Recursively finds the [GoRoute] registered for [path] anywhere in the live
/// router configuration and returns its builder, so the test renders the REAL
/// production deny screen (not a stand-in).
GoRouterWidgetBuilder? _findBuilderForPath(
  List<RouteBase> routes,
  String path,
) {
  for (final route in routes) {
    if (route is GoRoute) {
      if (route.path == path) return route.builder;
      final nested = _findBuilderForPath(route.routes, path);
      if (nested != null) return nested;
    } else if (route is ShellRouteBase) {
      final nested = _findBuilderForPath(route.routes, path);
      if (nested != null) return nested;
    }
  }
  return null;
}

/// Builds a minimal GoRouter that reuses the PRODUCTION capability guard
/// ([AppRouter.capabilityRedirect]) bound to [businessType], the PRODUCTION
/// deny screen ([denyBuilder], lifted from the live config), a lightweight home
/// at the shell base, and a lightweight "real gated screen" marker at
/// [gatedItemId]'s real per-item path.
GoRouter _buildHarnessRouter({
  required String businessType,
  required String gatedItemId,
  required GoRouterWidgetBuilder denyBuilder,
}) {
  return GoRouter(
    initialLocation: RoutePaths.shell, // ungated → always allowed
    // The EXACT production top-level guard, fed a REAL GoRouterState produced
    // by URL navigation. Bound to the business type under test, mirroring the
    // live `ref.read(businessTypeProvider).type.name`.
    redirect: (BuildContext context, GoRouterState state) =>
        AppRouter.capabilityRedirect(state, businessType),
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.shell,
        name: RoutePaths.shellName,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('HOME_SHELL'))),
      ),
      // The real per-item path + name for the gated item. The route NAME equals
      // the itemId exactly as the live per-item routes are registered, so the
      // guard resolves the itemId from a real navigation just as it does live.
      GoRoute(
        path: RoutePaths.pathForItemId(gatedItemId),
        name: gatedItemId,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text(kRealScreenMarker))),
      ),
      // The REAL production deny screen (builder lifted from the live config).
      GoRoute(
        path: RoutePaths.denied,
        name: RoutePaths.deniedName,
        builder: denyBuilder,
      ),
    ],
  );
}

void main() {
  late GoRouterWidgetBuilder denyBuilder;

  setUpAll(() {
    // Lift the REAL deny-route builder from the live production router config so
    // the test renders the actual `_AccessDeniedScreen`, not a stand-in.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final liveRouter = container.read(appRouterProvider);
    final builder = _findBuilderForPath(
      liveRouter.configuration.routes,
      RoutePaths.denied,
    );
    expect(
      builder,
      isNotNull,
      reason:
          'The live router must register a deny route ($RoutePaths.denied) '
          'whose builder renders the production deny screen.',
    );
    denyBuilder = builder!;
  });

  group('Feature: gorouter-navigation-migration — Phase 3 DIRECT-URL capability '
      'block (security fix S3 gate) — Req 6.1, 6.3', () {
    // ----------------------------------------------------------------------
    // THE GATE CRITERION: a DIRECT/deep-link URL navigation (not a menu tap)
    // to a capability-denied route lands on the DENY SCREEN.
    // ----------------------------------------------------------------------
    testWidgets(
      'GROCERY deep-link via router.go("/app/return-inwards") is BLOCKED and '
      'renders the deny screen (not the real screen, not blank, not a crash)',
      (tester) async {
        const String groceryType = 'grocery'; // BusinessType.grocery.name
        // Sanity: the seam agrees this item is denied for grocery, so the
        // widget-level expectation below is the live consequence of the guard.
        expect(
          AppRouter.redirectDecision('return_inwards', groceryType),
          RoutePaths.denied,
        );

        final router = _buildHarnessRouter(
          businessType: groceryType,
          gatedItemId: 'return_inwards',
          denyBuilder: denyBuilder,
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Start on the (ungated) home — sanity that the harness routes work.
        expect(find.text('HOME_SHELL'), findsOneWidget);

        // DIRECT URL navigation (deep link), exactly like pasting/opening a URL
        // — NOT a sidebar menu tap.
        router.go(RoutePaths.pathForItemId('return_inwards'));
        await tester.pumpAndSettle();

        // BLOCKED: the guard redirected to the deny route. The current routed
        // location is the deny path.
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          RoutePaths.denied,
          reason:
              'A grocery deep link to a capability-denied route must redirect '
              'to ${RoutePaths.denied} (S3 fix).',
        );

        // The DENY SCREEN renders (the real production `_AccessDeniedScreen`):
        // it is NOT blank and NOT a crash — it shows its recognisable copy and
        // a way back.
        expect(find.text('Not Available'), findsOneWidget);
        expect(find.text('Restricted for your business type'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.text('Back to Dashboard'), findsOneWidget);

        // CRITICAL: the real gated screen NEVER rendered (no leak).
        expect(
          find.text(kRealScreenMarker),
          findsNothing,
          reason:
              'SECURITY: the real gated screen must never render for a denied '
              'grocery deep link.',
        );
      },
    );

    // ----------------------------------------------------------------------
    // POSITIVE CONTROL: the same DIRECT URL for a type that HAS the capability
    // reaches the real screen — proving the block is targeted, not blanket.
    // ----------------------------------------------------------------------
    testWidgets(
      'WHOLESALE deep-link via router.go("/app/return-inwards") is ALLOWED and '
      'reaches the real screen (guard is targeted, not a blunt block)',
      (tester) async {
        final String wholesaleType = BusinessType.wholesale.name;
        expect(
          AppRouter.redirectDecision('return_inwards', wholesaleType),
          isNull,
        );

        final router = _buildHarnessRouter(
          businessType: wholesaleType,
          gatedItemId: 'return_inwards',
          denyBuilder: denyBuilder,
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        router.go(RoutePaths.pathForItemId('return_inwards'));
        await tester.pumpAndSettle();

        // ALLOWED: lands on the real per-item path and renders the real screen.
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          RoutePaths.pathForItemId('return_inwards'),
        );
        expect(find.text(kRealScreenMarker), findsOneWidget);
        expect(find.text('Not Available'), findsNothing);
      },
    );
  });
}
