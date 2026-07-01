// ============================================================================
// PHASE A — Task 2.1: EXPLORATION TEST for the imperative-navigation gap
// Feature: imperative-navigation-gorouter-migration
// **Validates: Requirements 10.1**
// ============================================================================
//
// WHAT THIS PROVES (and WHY it must PASS against the UNCHANGED code):
//
//   The prior `gorouter-navigation-migration` spec made
//   `MaterialApp.router(routerConfig: appRouterProvider)` the SOLE navigation
//   root of DukanX. The legacy `MaterialApp.routes` table
//   (`lib/app/routes.dart` -> `buildAppRoutes()`) — which registered
//   `'/sync-status' -> VendorRoleGuard(child: RealSyncScreen())` — is no longer
//   wired into ANY `MaterialApp`. Roughly two dozen files still navigate
//   imperatively against those legacy named strings (e.g.
//   `enterprise_desktop_shell.dart` and `sync_status_indicator.dart` both call
//   `Navigator.of(context).pushNamed('/sync-status')`).
//
//   Under the go_router-only root, `'/sync-status'` is NOT a registered route,
//   so navigating to it does NOT resolve to `RealSyncScreen`; it falls through
//   to the AppRouter `errorBuilder`, which renders the theme-aware
//   "Feature Not Found" (`_RouteNotFoundScreen`) screen. THIS is the gap the
//   migration closes. This exploration test pins that current behavior so the
//   later preservation test can prove the gap is closed.
//
// TWO COMPLEMENTARY ASSERTIONS:
//
//   (1) CONFIG-LEVEL (deterministic): the LIVE `appRouterProvider` router
//       configuration does NOT register a `GoRoute` whose path/name is
//       `'/sync-status'` — i.e. the `buildAppRoutes()` `/sync-status` route is
//       UNWIRED — while the foundation routes (/splash, /app shell) ARE present
//       (confirming this really is the go_router-only root).
//
//   (2) WIDGET-LEVEL (deterministic): pumping `MaterialApp.router` and issuing
//       the go_router equivalent of the legacy push (`context.push('/sync-status')`)
//       lands on the REAL production not-found screen — NOT `RealSyncScreen`.
//
// DETERMINISM (documented, mirroring the established
// `phase3_direct_url_block_widget_test.dart` harness rationale):
//   The live router's `initialLocation` is `/splash`, whose `SplashScreen` runs
//   a REPEATING animation controller, audio/GetIt initialization, and delayed
//   timers — pumping it whole is non-deterministic (`pumpAndSettle` never
//   settles; init touches plugins/service locator). So the widget-level half
//   does not pump the heavy `/splash` entry. Instead it pumps a MINIMAL
//   `MaterialApp.router` that reuses the EXACT production pieces that matter for
//   the gap claim:
//     * the route table genuinely has NO `'/sync-status'` route (the gap —
//       proven independently by assertion (1) against the live config), and
//     * the REAL production not-found builder, lifted verbatim from the live
//       router's `RoutePaths.notFound` route, so what renders is the actual
//       `_RouteNotFoundScreen`, not a stand-in.
//   The security-relevant fact — an unregistered legacy string resolves to the
//   production not-found screen, never to the real screen — is therefore
//   exercised with production code.
//
// TEST-ONLY: no production/application code is changed by this task.
//
// Run: flutter test test/core/routing/imperative_nav_exploration_test.dart \
//        --reporter expanded
// ============================================================================

import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/screens/real_sync_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The representative legacy named string the migration must make resolvable.
/// Today it lives ONLY in the unwired `buildAppRoutes()` table
/// (`lib/app/routes.dart`: `'/sync-status' -> VendorRoleGuard(RealSyncScreen)`).
const String kLegacySyncStatusPath = '/sync-status';

/// Lightweight home for the widget-level harness (an ungated, always-matched
/// route) whose button issues the imperative go_router push under test.
const String kHarnessHomePath = '/harness-home';
const String kHarnessHomeMarker = 'HARNESS_HOME';

/// Recursively collects every [GoRoute] in a route tree (descending through
/// [ShellRoute]s and nested routes). Mirrors the established routing-test
/// helper so the assertion tracks the live configuration exactly.
Iterable<GoRoute> _allGoRoutes(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route;
      yield* _allGoRoutes(route.routes);
    } else if (route is ShellRoute) {
      yield* _allGoRoutes(route.routes);
    } else {
      yield* _allGoRoutes(route.routes);
    }
  }
}

/// Finds the [GoRoute] registered for [path] anywhere in the router
/// configuration and returns its builder, so the harness renders the REAL
/// production screen (not a stand-in). Mirrors the helper in
/// `phase3_direct_url_block_widget_test.dart`.
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

void main() {
  // GoRouter construction needs an initialized binding (it wires up route
  // information providers). Plain `test()` bodies don't auto-initialize it.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature: imperative-navigation-gorouter-migration — Phase A '
      'EXPLORATION: the legacy named-route gap under MaterialApp.router '
      '(Req 10.1)', () {
    // ----------------------------------------------------------------------
    // (1) CONFIG-LEVEL: the legacy `/sync-status` route is UNWIRED.
    // ----------------------------------------------------------------------
    test(
      'the live AppRouter does NOT register "/sync-status" — '
      'buildAppRoutes() legacy route is unwired under the go_router-only root',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final router = container.read(appRouterProvider);
        addTearDown(router.dispose);

        final registered = _allGoRoutes(router.configuration.routes).toList();
        final paths = registered.map((r) => r.path).toSet();
        final names = registered.map((r) => r.name).whereType<String>().toSet();

        // Sanity: this really IS the go_router-only root — its foundation
        // routes are present (so a missing "/sync-status" is the GAP, not a
        // mis-built router).
        expect(
          paths,
          contains(RoutePaths.splash),
          reason:
              'The go_router-only root must expose the /splash foundation '
              'route.',
        );
        expect(
          paths,
          contains(RoutePaths.shell),
          reason: 'The go_router-only root must expose the /app shell route.',
        );

        // THE GAP: the representative legacy named string is NOT a registered
        // GoRoute (neither by path nor by name). Today it exists only in the
        // unwired `buildAppRoutes()` table, so an imperative push to it cannot
        // resolve to RealSyncScreen.
        expect(
          paths,
          isNot(contains(kLegacySyncStatusPath)),
          reason:
              '"$kLegacySyncStatusPath" must be absent from the live router '
              'today — it lives only in the unwired buildAppRoutes() table.',
        );
        expect(
          names,
          isNot(contains('sync-status')),
          reason:
              'No registered route is named for the legacy "/sync-status" '
              'string today.',
        );
      },
      skip:
          'Superseded by Phase B Task 4.4 — /sync-status is now a registered '
          'legacy GoRoute; see phase_b_guarded_resolution_preservation_test.dart',
    );

    // ----------------------------------------------------------------------
    // (2) WIDGET-LEVEL: pushing "/sync-status" lands on the production
    //     not-found screen, NOT RealSyncScreen.
    // ----------------------------------------------------------------------
    testWidgets(
      'pumping MaterialApp.router and pushing "/sync-status" resolves to the '
      'production not-found screen, NOT RealSyncScreen',
      (tester) async {
        // Lift the REAL production not-found builder from the live router so the
        // harness renders the actual `_RouteNotFoundScreen` an unmatched legacy
        // push lands on today.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final liveRouter = container.read(appRouterProvider);
        addTearDown(liveRouter.dispose);

        final notFoundBuilder = _findBuilderForPath(
          liveRouter.configuration.routes,
          RoutePaths.notFound,
        );
        expect(
          notFoundBuilder,
          isNotNull,
          reason:
              'The live router must register the not-found route '
              '(${RoutePaths.notFound}) whose builder renders the production '
              '"Feature Not Found" screen.',
        );

        // Minimal harness: an ungated home + the production not-found builder as
        // the errorBuilder. Crucially, it registers NO "/sync-status" route —
        // exactly the production reality proven by assertion (1) above.
        final harness = GoRouter(
          initialLocation: kHarnessHomePath,
          routes: <RouteBase>[
            GoRoute(
              path: kHarnessHomePath,
              builder: (BuildContext context, GoRouterState state) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    // The go_router equivalent of the legacy
                    // `Navigator.of(context).pushNamed('/sync-status')` call
                    // site — the very navigation this migration will fix.
                    onPressed: () => context.push(kLegacySyncStatusPath),
                    child: const Text(kHarnessHomeMarker),
                  ),
                ),
              ),
            ),
          ],
          errorBuilder: notFoundBuilder,
        );
        addTearDown(harness.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
        await tester.pumpAndSettle();

        // Sanity: we start on the ungated home.
        expect(find.text(kHarnessHomeMarker), findsOneWidget);
        expect(find.byType(RealSyncScreen), findsNothing);

        // Issue the imperative legacy push.
        await tester.tap(find.text(kHarnessHomeMarker));
        await tester.pumpAndSettle();

        // THE GAP, demonstrated: "/sync-status" did NOT resolve to its legacy
        // destination (RealSyncScreen). It fell through to the production
        // not-found screen.
        expect(
          find.byType(RealSyncScreen),
          findsNothing,
          reason:
              'Today "$kLegacySyncStatusPath" must NOT resolve to RealSyncScreen '
              'under the go_router-only root.',
        );
        expect(
          find.text('Unknown Screen'),
          findsOneWidget,
          reason: 'The production not-found screen must render instead.',
        );
        expect(
          find.text('Feature Not Found'),
          findsOneWidget,
          reason: 'The production not-found screen must render instead.',
        );
      },
    );
  });
}
