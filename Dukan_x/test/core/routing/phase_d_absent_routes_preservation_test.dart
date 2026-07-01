// ============================================================================
// PHASE D — Task 7.2: PRESERVATION TEST for absent routes
// Feature: imperative-navigation-gorouter-migration
// **Validates: Requirements 9.3, 10.2**
// ============================================================================
//
// WHAT THIS PROVES (and WHY it must PASS against the CHANGED code):
//
//   `/upgrade` and `/super-admin/{tenants,licenses,audit,usage}` are pushed
//   imperatively (the trial widgets and the super-admin dashboard) but were
//   NEVER registered in the old `buildAppRoutes()` table — they failed at
//   runtime even under the legacy table (design.md AD-8). Task 7.1 registered
//   each one as a first-class top-level `GoRoute` in `LegacyRoutes.routes()`:
//
//     * the four `/super-admin/*` paths map to their REAL target screens,
//       each wrapped in `VendorRoleGuard(Permissions.systemSettings, …)`
//       (the same permission every other admin / system surface uses); and
//     * `/upgrade` — for which NO upgrade screen exists in the codebase —
//       resolves to a theme-aware not-found PLACEHOLDER
//       (`_UpgradeRouteNotFoundScreen`, "Unknown Screen" / "Feature Not
//       Found"), so the deliberately-absent target degrades GRACEFULLY
//       instead of crashing (Req 9.3 graceful degradation, design AD-8).
//
//   This preservation test pins all of that down across three layers:
//
//   (1) CONFIG-LEVEL (deterministic): the LIVE `appRouterProvider`
//       configuration now registers a top-level `GoRoute` whose `path` equals
//       each of the five absent strings, and `LegacyRoutes.isKnownLegacyPath`
//       reports `true` for each (parity by construction). This is what makes
//       `/upgrade`'s placeholder the route's OWN builder output (registered) —
//       provably DISTINCT from an unregistered-route error.
//
//   (2) WIDGET-LEVEL — guarded `/super-admin/*` (faithful harness, fixed
//       pumps): each `/super-admin/*` path is pushed with the SessionManager
//       still RESOLVING, so its lifted `VendorRoleGuard` renders its
//       "Verifying access..." gate — proving the route resolved to its
//       guard-wrapped builder (NOT the not-found screen) without constructing
//       the heavy super-admin screens.
//
//   (3) WIDGET-LEVEL — `/upgrade` graceful degradation: pushing `/upgrade`
//       renders the theme-aware not-found placeholder ("Unknown Screen" /
//       "Feature Not Found") WITHOUT crashing. The placeholder is the route's
//       OWN builder output (the route is registered — see layer 1), is NOT
//       guarded (no SessionManager gate needed), and is contrasted against a
//       genuinely UNREGISTERED path that falls through to the harness
//       `errorBuilder` not-found AND for which `isKnownLegacyPath` is false.
//
// DETERMINISM (mirrors the established harness rationale in
// `phase_b_guarded_resolution_preservation_test.dart` /
// `phase_c_arg_fallback_preservation_test.dart`):
//   The live router's `initialLocation` is `/splash`, whose `SplashScreen` runs
//   a repeating animation + audio/GetIt init that never settles, so we do NOT
//   pump the heavy `/splash` entry. The widget-level layers pump a MINIMAL
//   `MaterialApp.router` that reuses the EXACT production pieces that matter:
//   the real `LegacyRoutes.routes()` table and the real production not-found
//   builder (lifted from the live router) as the errorBuilder, so a resolved
//   guard render is provably distinct from the not-found fallback. The
//   `/super-admin/*` pumps are FIXED (`pump` + `pump(50ms)`) because the
//   resolving guard's `AuthLoadingScreen` spinner animates forever; the static
//   `/upgrade` placeholder and the not-found screen DO settle, so those use
//   `pumpAndSettle`.
//
// TEST-ONLY: no production/application code is changed by this task.
//
// Run: flutter test \
//   test/core/routing/phase_d_absent_routes_preservation_test.dart \
//   --reporter expanded
// ============================================================================

import 'package:dukanx/core/auth/auth_loading_screen.dart';
import 'package:dukanx/core/auth/role_guard.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

/// The four `/super-admin/*` paths registered by Task 7.1 — each maps to a real
/// target screen wrapped in `VendorRoleGuard(Permissions.systemSettings, …)`.
const List<String> kSuperAdminPaths = <String>[
  '/super-admin/tenants',
  '/super-admin/licenses',
  '/super-admin/audit',
  '/super-admin/usage',
];

/// The deliberately-absent target with no screen in the codebase (Req 9.3).
const String kUpgradePath = '/upgrade';

/// Every absent-route string registered by Task 7.1 (design AD-8).
const List<String> kAbsentRoutePaths = <String>[
  kUpgradePath,
  ...kSuperAdminPaths,
];

/// The theme-aware not-found placeholder body text rendered by BOTH the
/// `/upgrade` placeholder (`_UpgradeRouteNotFoundScreen`) and the live router's
/// `errorBuilder` (`_RouteNotFoundScreen`) — they intentionally mirror.
const String kNotFoundTitle = 'Unknown Screen';
const String kNotFoundSubtitle = 'Feature Not Found';

/// Lightweight ungated home for the harness whose button issues the imperative
/// go_router push under test (the go_router equivalent of the legacy
/// `Navigator.pushNamed('<path>')` call site).
const String kHarnessHomePath = '/harness-home';
const String kHarnessHomeMarker = 'HARNESS_HOME';

// ---------------------------------------------------------------------------
// Harness helpers (mirror the Phase B / Phase C preservation tests).
// ---------------------------------------------------------------------------

/// Recursively collects every [GoRoute] in a route tree (descending through
/// [ShellRouteBase]s and nested routes). Mirrors the established routing-test
/// helper so the assertion tracks the live configuration exactly.
Iterable<GoRoute> _allGoRoutes(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route;
      yield* _allGoRoutes(route.routes);
    } else if (route is ShellRouteBase) {
      yield* _allGoRoutes(route.routes);
    } else {
      yield* _allGoRoutes(route.routes);
    }
  }
}

/// Finds the [GoRoute] registered for [path] anywhere in the router
/// configuration and returns its builder, so the harness can render the REAL
/// production not-found screen (not a stand-in).
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

/// Lifts the REAL production not-found builder from the live router so the
/// harness errorBuilder renders the actual `_RouteNotFoundScreen` (whose body
/// shows "Unknown Screen" / "Feature Not Found"). A genuinely unregistered push
/// is then provably routed to this fallback.
GoRouterWidgetBuilder _liveNotFoundBuilder() {
  final container = ProviderContainer();
  final router = container.read(appRouterProvider);
  final builder = _findBuilderForPath(
    router.configuration.routes,
    RoutePaths.notFound,
  );
  router.dispose();
  container.dispose();
  if (builder == null) {
    throw StateError(
      'The live router must register the not-found route '
      '(${RoutePaths.notFound}) whose builder renders the production '
      '"Feature Not Found" screen.',
    );
  }
  return builder;
}

/// Builds a minimal harness `GoRouter` that registers the ACTUAL
/// `LegacyRoutes.routes()` plus an ungated home whose button pushes [pushPath]
/// (the go_router equivalent of the legacy `Navigator.pushNamed(pushPath)`).
///
/// The top-level redirect consults the SAME production `aliasTargetFor` single
/// source of truth (faithful composition); the absent routes are NOT aliases,
/// so it is a no-op for them. It deliberately does NOT add the router-level
/// capability guard — the `/super-admin/*` routes are protected by their WIDGET
/// guards (Req 4.6 / AD-2).
GoRouter _harnessPushing(String pushPath, GoRouterWidgetBuilder notFound) {
  return GoRouter(
    initialLocation: kHarnessHomePath,
    redirect: (BuildContext context, GoRouterState state) =>
        LegacyRoutes.aliasTargetFor(state.matchedLocation),
    routes: <RouteBase>[
      GoRoute(
        path: kHarnessHomePath,
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.push(pushPath),
              child: const Text(kHarnessHomeMarker),
            ),
          ),
        ),
      ),
      // The REAL migrated absent-route registrations (single source of truth).
      ...LegacyRoutes.routes(),
    ],
    errorBuilder: notFound,
  );
}

/// A lightweight fake [SessionManager] whose auth-state getters are fixed via
/// the constructor (mirrors the helper in the Phase B / Phase C preservation
/// tests). [SessionManager] is a [ChangeNotifier], so `VendorRoleGuard`'s
/// `ListenableBuilder` can listen to it; `Mock` provides the inherited listener
/// no-ops via `noSuchMethod`, while the boolean getters the guard reads are
/// overridden with real backing values.
class FakeSessionManager extends Mock implements SessionManager {
  FakeSessionManager({
    this.isLoading = false,
    this.isInitialized = true,
    this.isAuthenticated = true,
    this.isOwner = true,
    this.isCustomerOnlyMode = false,
  });

  /// Session still resolving -> `VendorRoleGuard` shows the "Verifying
  /// access..." gate (builds no child screen, schedules no redirect).
  factory FakeSessionManager.resolving() =>
      FakeSessionManager(isLoading: true, isInitialized: false);

  @override
  final bool isLoading;
  @override
  final bool isInitialized;
  @override
  final bool isAuthenticated;
  @override
  final bool isOwner;
  @override
  final bool isCustomerOnlyMode;
}

void main() {
  // GoRouter construction needs an initialized binding (it wires up route
  // information providers). Plain `test()` bodies don't auto-initialize it.
  TestWidgetsFlutterBinding.ensureInitialized();

  final GoRouterWidgetBuilder notFound = _liveNotFoundBuilder();

  group('Feature: imperative-navigation-gorouter-migration — Phase D '
      'PRESERVATION: absent routes (/upgrade + /super-admin/*) resolve to '
      'their registered builders; deliberately-absent target degrades to '
      'not-found without crashing (Req 9.3, 10.2)', () {
    // ======================================================================
    // (1) CONFIG-LEVEL — every absent-route string is now a registered
    //     top-level GoRoute under the live AppRouter, and a known legacy path.
    // ======================================================================
    test('the live AppRouter now registers a GoRoute for /upgrade and EACH '
        '/super-admin/* path, and isKnownLegacyPath is true for each '
        '(Req 10.2 — gap closed)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);

      final paths = _allGoRoutes(
        router.configuration.routes,
      ).map((r) => r.path).toSet();

      for (final absentPath in kAbsentRoutePaths) {
        // The absent string resolves to a REGISTERED top-level GoRoute whose
        // path equals that string (Task 7.1 registration, design AD-8).
        expect(
          paths,
          contains(absentPath),
          reason:
              '"$absentPath" must now be a registered GoRoute path under the '
              'live AppRouter (Task 7.1 registration of routes absent from the '
              'legacy table).',
        );
        // Parity: the known-paths set claims it too (so /upgrade\'s placeholder
        // is the route\'s OWN builder output, NOT an unregistered-route error).
        expect(
          LegacyRoutes.isKnownLegacyPath(absentPath),
          isTrue,
          reason:
              'LegacyRoutes.isKnownLegacyPath("$absentPath") must be true now '
              'that its GoRoute is registered.',
        );
      }
    });

    // ======================================================================
    // (2) WIDGET-LEVEL — each /super-admin/* resolves to its lifted
    //     VendorRoleGuard (session-resolving gate), NOT the not-found screen.
    // ======================================================================
    for (final String adminPath in kSuperAdminPaths) {
      testWidgets('pushing "$adminPath" resolves to its lifted VendorRoleGuard '
          '(session-resolving gate), NOT the not-found screen', (tester) async {
        // Resolving session -> VendorRoleGuard renders its gate, so the heavy
        // super-admin target screen is never built.
        await GetIt.I.reset();
        GetIt.I.registerSingleton<SessionManager>(
          FakeSessionManager.resolving(),
        );
        addTearDown(() async => GetIt.I.reset());

        final harness = _harnessPushing(adminPath, notFound);
        addTearDown(harness.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
        await tester.pumpAndSettle();

        // Sanity: we start on the ungated home.
        expect(find.text(kHarnessHomeMarker), findsOneWidget);

        // Issue the go_router equivalent of the legacy push. Use fixed pumps
        // (NOT pumpAndSettle): the resolving guard shows AuthLoadingScreen
        // whose CircularProgressIndicator animates forever.
        await tester.tap(find.text(kHarnessHomeMarker));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // GAP CLOSED: the absent string resolved to its guard-wrapped builder.
        expect(
          find.byType(VendorRoleGuard),
          findsOneWidget,
          reason:
              '"$adminPath" must resolve to its lifted VendorRoleGuard '
              'wrapper (Task 7.1).',
        );
        // The guard is mid-resolution, so it shows its loading gate (not the
        // heavy super-admin screen) — deterministic.
        expect(find.byType(AuthLoadingScreen), findsOneWidget);
        expect(find.text('Verifying access...'), findsOneWidget);
        // And it is NOT the production not-found screen — it resolved to the
        // guard, not the errorBuilder.
        expect(
          find.text(kNotFoundTitle),
          findsNothing,
          reason:
              '"$adminPath" must resolve to its guard, NOT fall through to '
              'the not-found screen — its GoRoute is registered (Task 7.1).',
        );
      });
    }

    // ======================================================================
    // (3a) WIDGET-LEVEL — /upgrade degrades GRACEFULLY to its registered
    //      not-found placeholder (Req 9.3), without crashing. The placeholder
    //      is NOT guarded, so it renders directly (no SessionManager gate).
    // ======================================================================
    testWidgets(
      'pushing "/upgrade" (deliberately-absent target — no upgrade screen '
      'exists) degrades to the not-found placeholder ("Unknown Screen" / '
      '"Feature Not Found") WITHOUT crashing (Req 9.3)',
      (tester) async {
        final harness = _harnessPushing(kUpgradePath, notFound);
        addTearDown(harness.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
        await tester.pumpAndSettle();

        // Sanity: we start on the ungated home.
        expect(find.text(kHarnessHomeMarker), findsOneWidget);

        // Push /upgrade. The placeholder is a static Scaffold -> it settles.
        await tester.tap(find.text(kHarnessHomeMarker));
        await tester.pumpAndSettle();

        // The route resolved to its registered placeholder builder, which
        // renders the theme-aware "Unknown Screen" / "Feature Not Found".
        expect(
          find.text(kNotFoundTitle),
          findsOneWidget,
          reason:
              '"/upgrade" must degrade to its theme-aware not-found '
              'placeholder ("Unknown Screen") instead of crashing (Req 9.3).',
        );
        expect(
          find.text(kNotFoundSubtitle),
          findsOneWidget,
          reason:
              'The "/upgrade" placeholder must render the "Feature Not Found" '
              'subtitle (mirrors the AppRouter not-found screen).',
        );
        // The placeholder is NOT guarded — it renders directly.
        expect(
          find.byType(VendorRoleGuard),
          findsNothing,
          reason:
              'The "/upgrade" placeholder is intentionally unguarded — it must '
              'render directly without a SessionManager gate.',
        );
        // No exception escaped the framework (graceful, not a crash).
        expect(tester.takeException(), isNull);
      },
    );

    // ======================================================================
    // (3b) CONTRAST — a genuinely UNREGISTERED path falls through to the
    //      harness errorBuilder not-found AND is NOT a known legacy path.
    //      This proves /upgrade's placeholder (registered, isKnownLegacyPath
    //      true) is DISTINCT from an unregistered-route error, while BOTH
    //      degrade gracefully (Req 9.3).
    // ======================================================================
    testWidgets(
      'a genuinely unregistered path degrades to the errorBuilder not-found '
      'and is NOT a known legacy path — distinct from /upgrade\'s registered '
      'placeholder (Req 9.3, 10.2)',
      (tester) async {
        const String unregistered = '/__definitely-absent-target__';

        // Distinct from /upgrade: this path is NOT registered / not known.
        expect(
          LegacyRoutes.isKnownLegacyPath(unregistered),
          isFalse,
          reason:
              'The contrast path must NOT be a known legacy path (it is not '
              'registered), unlike "/upgrade".',
        );
        expect(
          LegacyRoutes.isKnownLegacyPath(kUpgradePath),
          isTrue,
          reason:
              '"/upgrade" IS a registered known legacy path — its placeholder '
              'is the route\'s own builder output, not an unregistered error.',
        );

        final harness = _harnessPushing(unregistered, notFound);
        addTearDown(harness.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
        await tester.pumpAndSettle();
        expect(find.text(kHarnessHomeMarker), findsOneWidget);

        await tester.tap(find.text(kHarnessHomeMarker));
        await tester.pumpAndSettle();

        // The unregistered push degrades gracefully via the errorBuilder
        // not-found (no crash) — same graceful outcome, different mechanism.
        expect(
          find.text(kNotFoundTitle),
          findsOneWidget,
          reason:
              'An unregistered path must degrade to the errorBuilder '
              'not-found screen ("Unknown Screen") without crashing.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
