// ============================================================================
// PHASE A — Task 2.7: PRESERVATION TEST for foundation wiring
// Feature: imperative-navigation-gorouter-migration
// **Validates: Requirements 10.2, 10.3**
// ============================================================================
//
// WHAT THIS PROVES (and WHY it must PASS against the CHANGED code):
//
//   Task 2.6 wired the Legacy-Compatible Route Layer into the live AppRouter:
//     * it spreads `...LegacyRoutes.routes()` into the top-level `routes:` list,
//       and
//     * it PREPENDS an alias check (`LegacyRoutes.aliasTargetFor`) to the
//       existing composed `redirect` callback, falling through to the existing
//       `capabilityRedirect` guard verbatim.
//
//   This preservation test asserts that change did NOT regress the foundation:
//
//   (Req 10.2) The live `appRouterProvider` configuration STILL registers the
//   foundation routes (`/splash`, `/login`, `/auth-gate`), the `/app`
//   `ShellRoute`, and the not-found sentinel — i.e. wiring LegacyRoutes added
//   routes additively without removing or altering the existing ones — AND the
//   composed redirect now resolves legacy alias paths to their canonical
//   foundation targets.
//
//   (Req 10.3) The foundation routes are NOT capability-bound, so they resolve
//   identically regardless of the active business type. We prove this by
//   rebuilding the router under several In_Scope_Business_Type overrides and
//   asserting the foundation route set is present and identical every time.
//
// HOW THE "redirect resolves aliases" CLAIM IS ASSERTED:
//   The top-level redirect itself is awkward to invoke in isolation (it needs a
//   live BuildContext + GoRouterState and reads a provider). So, mirroring the
//   established determinism approach in `imperative_nav_exploration_test.dart`
//   (do NOT pump the heavy `/splash` entry), the claim is proven at three
//   complementary, deterministic levels:
//     1. DECISION FUNCTION (pure): `LegacyRoutes.aliasTargetFor` returns the
//        canonical `RoutePaths` target for every alias (and `null` for
//        non-aliases / already-canonical targets — idempotent, no loop).
//     2. COMPOSITION PRESENT: the live router's top-level redirect is present
//        on the configuration (`configuration.topRedirect`), i.e. the composed
//        redirect (alias check + capability guard) is wired on the router.
//     3. WIDGET-LEVEL (faithful harness): a minimal `MaterialApp.router` whose
//        redirect consults the SAME production `LegacyRoutes.aliasTargetFor`
//        single source of truth lands an alias navigation on the canonical
//        foundation route's screen — exercising go_router's real redirect
//        engine without pumping `/splash`.
//
// TEST-ONLY: no production/application code is changed by this task.
//
// Run: flutter test \
//        test/core/routing/phase_a_foundation_wiring_preservation_test.dart \
//        --reporter expanded
// ============================================================================

import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Recursively collects every [GoRoute] in a route tree (descending through
/// [ShellRoute]s and nested routes). Mirrors the established routing-test
/// helper (`imperative_nav_exploration_test.dart`) so the assertion tracks the
/// live configuration exactly.
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

/// Whether the route tree contains a top-level [ShellRoute] (the `/app` shell).
bool _hasShellRoute(List<RouteBase> routes) {
  for (final route in routes) {
    if (route is ShellRoute) return true;
  }
  return false;
}

/// Builds the live router under [container] and returns the set of registered
/// paths and names (walking through the shell).
({Set<String> paths, Set<String> names, List<RouteBase> routes}) _liveConfig(
  ProviderContainer container,
) {
  final router = container.read(appRouterProvider);
  addTearDown(router.dispose);
  final registered = _allGoRoutes(router.configuration.routes).toList();
  return (
    paths: registered.map((r) => r.path).toSet(),
    names: registered.map((r) => r.name).whereType<String>().toSet(),
    routes: router.configuration.routes,
  );
}

/// A [BusinessTypeNotifier] pinned to a fixed type, used to override
/// [businessTypeProvider] without touching SharedPreferences (the real
/// notifier's `build()` kicks off an async prefs load). This lets the Req 10.3
/// non-regression check rebuild the router under different business types
/// deterministically.
class _FixedBusinessTypeNotifier extends BusinessTypeNotifier {
  _FixedBusinessTypeNotifier(this._fixed);
  final BusinessType _fixed;

  @override
  BusinessTypeState build() => BusinessTypeState(type: _fixed);
}

void main() {
  // GoRouter construction needs an initialized binding (it wires up route
  // information providers). Plain `test()` bodies don't auto-initialize it.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature: imperative-navigation-gorouter-migration — Phase A '
      'PRESERVATION: foundation wiring after LegacyRoutes is composed in '
      '(Req 10.2, 10.3)', () {
    // ----------------------------------------------------------------------
    // (Req 10.2) FOUNDATION ROUTES STILL REGISTERED.
    // ----------------------------------------------------------------------
    test('the live AppRouter STILL registers the foundation routes (/splash, '
        '/login, /auth-gate), the /app ShellRoute, and the not-found sentinel '
        'after LegacyRoutes is wired', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = _liveConfig(container);

      // Foundation paths preserved (wiring LegacyRoutes was additive).
      expect(
        config.paths,
        containsAll(<String>[
          RoutePaths.splash, // /splash
          RoutePaths.login, // /login
          RoutePaths.authGate, // /auth-gate
          RoutePaths.shell, // /app  (the ShellRoute base child)
          RoutePaths.notFound, // /app/not-found
        ]),
        reason:
            'Wiring LegacyRoutes must NOT remove or alter the foundation '
            'routes or the /app shell base / not-found routes.',
      );

      // Foundation route NAMES preserved too (resolution by name unchanged).
      expect(
        config.names,
        containsAll(<String>[
          RoutePaths.splashName,
          RoutePaths.loginName,
          RoutePaths.authGateName,
          RoutePaths.shellName,
          RoutePaths.notFoundName,
        ]),
        reason: 'Foundation route names must be preserved.',
      );

      // The /app shell is still a real ShellRoute (not flattened away).
      expect(
        _hasShellRoute(config.routes),
        isTrue,
        reason: 'The /app shell must remain a ShellRoute.',
      );
    });

    // ----------------------------------------------------------------------
    // (Req 10.2) COMPOSED REDIRECT RESOLVES ALIASES TO CANONICAL TARGETS.
    // Level 1: pure decision function (deterministic).
    // ----------------------------------------------------------------------
    test('LegacyRoutes.aliasTargetFor resolves every legacy alias to its '
        'canonical foundation target (the redirect consults this)', () {
      // Each alias -> canonical RoutePaths target.
      expect(LegacyRoutes.aliasTargetFor('/auth_gate'), RoutePaths.authGate);
      expect(LegacyRoutes.aliasTargetFor('/'), RoutePaths.splash);
      expect(LegacyRoutes.aliasTargetFor('/startup'), RoutePaths.authGate);
      expect(LegacyRoutes.aliasTargetFor('/owner_login'), RoutePaths.login);
      expect(LegacyRoutes.aliasTargetFor('/customer_login'), RoutePaths.login);
      expect(LegacyRoutes.aliasTargetFor('/signup'), RoutePaths.login);

      // Non-aliases (incl. already-canonical targets) return null, so the
      // redirect falls through to the capability guard and never loops
      // (idempotent — Req 7.7).
      expect(LegacyRoutes.aliasTargetFor(RoutePaths.authGate), isNull);
      expect(LegacyRoutes.aliasTargetFor(RoutePaths.splash), isNull);
      expect(LegacyRoutes.aliasTargetFor(RoutePaths.login), isNull);
      expect(LegacyRoutes.aliasTargetFor('/app/new-sale'), isNull);
      expect(LegacyRoutes.aliasTargetFor('/not-an-alias'), isNull);
    });

    // ----------------------------------------------------------------------
    // (Req 10.2) Level 2: the composed top-level redirect is PRESENT on the
    // live router configuration (alias check + capability guard are wired).
    // ----------------------------------------------------------------------
    test('the live AppRouter has a composed top-level redirect on its '
        'configuration', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);

      // The top-level redirect callback is present on the router (this is the
      // composed alias + capability redirect wired in Task 2.6).
      expect(
        router.configuration.topRedirect,
        isNotNull,
        reason:
            'The router must expose the composed top-level redirect that '
            'consults LegacyRoutes.aliasTargetFor before the capability guard.',
      );
    });

    // ----------------------------------------------------------------------
    // (Req 10.2) Level 3: WIDGET-LEVEL — navigating to an alias lands on the
    // canonical foundation route's screen, using a faithful harness that
    // reuses the SAME production alias function (no heavy /splash pump).
    // ----------------------------------------------------------------------
    testWidgets(
      'navigating to legacy aliases lands on the canonical foundation screen '
      'via the production alias resolution (faithful harness)',
      (tester) async {
        const String authGateMarker = 'AUTH_GATE_SCREEN';
        const String splashMarker = 'SPLASH_SCREEN';
        const String loginMarker = 'LOGIN_SCREEN';

        Widget marker(String text) => Scaffold(body: Center(child: Text(text)));

        // The harness mirrors the production composition: its top-level
        // redirect consults the REAL `LegacyRoutes.aliasTargetFor` (single
        // source of truth) and registers lightweight canonical foundation
        // screens. It does NOT pump the heavy production /splash entry.
        GoRouter harnessFor(String initialLocation) => GoRouter(
          initialLocation: initialLocation,
          redirect: (BuildContext context, GoRouterState state) =>
              LegacyRoutes.aliasTargetFor(state.matchedLocation),
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.splash,
              builder: (_, __) => marker(splashMarker),
            ),
            GoRoute(
              path: RoutePaths.login,
              builder: (_, __) => marker(loginMarker),
            ),
            GoRoute(
              path: RoutePaths.authGate,
              builder: (_, __) => marker(authGateMarker),
            ),
          ],
        );

        // /auth_gate (underscore alias) -> /auth-gate canonical screen.
        final r1 = harnessFor('/auth_gate');
        addTearDown(r1.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: r1));
        await tester.pumpAndSettle();
        expect(
          find.text(authGateMarker),
          findsOneWidget,
          reason: '/auth_gate must resolve to the canonical /auth-gate screen.',
        );

        // /owner_login -> /login canonical screen.
        final r2 = harnessFor('/owner_login');
        addTearDown(r2.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: r2));
        await tester.pumpAndSettle();
        expect(
          find.text(loginMarker),
          findsOneWidget,
          reason: '/owner_login must resolve to the canonical /login screen.',
        );

        // / (root alias) -> /splash canonical screen.
        final r3 = harnessFor('/');
        addTearDown(r3.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: r3));
        await tester.pumpAndSettle();
        expect(
          find.text(splashMarker),
          findsOneWidget,
          reason: '/ must resolve to the canonical /splash screen.',
        );
      },
    );

    // ----------------------------------------------------------------------
    // (Req 10.3) MULTI-BUSINESS-TYPE NON-REGRESSION.
    // The foundation routes are NOT capability-bound, so they resolve
    // identically regardless of the active business type. Rebuild the router
    // under several In_Scope_Business_Type overrides and assert the foundation
    // route set is present and identical every time.
    // ----------------------------------------------------------------------
    test('the foundation route set is present and identical across business '
        'types (foundation routes are not capability-bound)', () {
      const List<BusinessType> types = <BusinessType>[
        BusinessType.grocery,
        BusinessType.pharmacy,
        BusinessType.restaurant,
        BusinessType.clinic,
        BusinessType.petrolPump,
      ];

      const Set<String> foundationPaths = <String>{
        RoutePaths.splash,
        RoutePaths.login,
        RoutePaths.authGate,
        RoutePaths.shell,
        RoutePaths.notFound,
      };

      Set<String>? reference;
      for (final type in types) {
        final container = ProviderContainer(
          overrides: [
            businessTypeProvider.overrideWith(
              () => _FixedBusinessTypeNotifier(type),
            ),
          ],
        );
        addTearDown(container.dispose);

        final config = _liveConfig(container);

        // Foundation routes present for THIS business type.
        expect(
          config.paths,
          containsAll(foundationPaths),
          reason:
              'Foundation routes must be present for business type '
              '${type.name}.',
        );

        // The foundation slice is identical across every business type (no
        // type-dependent divergence in the foundation wiring).
        final foundationSlice = config.paths.intersection(foundationPaths);
        reference ??= foundationSlice;
        expect(
          foundationSlice,
          equals(reference),
          reason:
              'Foundation route set for ${type.name} must match the other '
              'business types (foundation routes are not capability-bound).',
        );
      }

      expect(reference, equals(foundationPaths));
    });
  });
}
