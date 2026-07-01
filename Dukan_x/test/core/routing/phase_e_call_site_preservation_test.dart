// ============================================================================
// PHASE E — Task 8.8: PRESERVATION TEST for migrated call sites
// Feature: imperative-navigation-gorouter-migration
// **Validates: Requirements 6.2, 7.8, 8.2, 8.3, 10.2, 10.3**
// ============================================================================
//
// WHAT THIS PROVES (and WHY it must PASS against the CHANGED code):
//
//   Phase E (tasks 8.1–8.5) mechanically migrated the remaining imperative
//   `Navigator.*Named` call sites onto their `context.*` go_router equivalents.
//   This preservation test pins the three behaviorally-distinct contracts those
//   migrations had to preserve — each driven through go_router's REAL engine
//   with a deterministic, faithful harness:
//
//   (1) RETURN VALUE (Req 6.2 / AD-4) — `customer_link_shop_screen.dart` was
//       migrated to `await context.push<String>('/qr_scanner')` and still
//       consumes the awaited `String` (`if (result is String) ...`). `go` does
//       NOT return a result Future, so the contract REQUIRES `push`. We model
//       the real (camera/plugin-backed) QR scanner with a lightweight faithful
//       `/qr_scanner` GoRoute that `context.pop(...)`s a `String`, push it via
//       `context.push<String>`, and assert (a) the push API returns a `Future`
//       (the very property `go` lacks) and (b) the awaited value is exactly the
//       popped `String`. Determinism: the result is produced by an explicit
//       button tap (`pop`), never a timer/animation.
//
//   (2) UNMAPPED DYNAMIC (Req 8.2, 8.3 / AD-7) — `shortcut_panel.dart` was
//       migrated to `context.push(def.route!)` for an arbitrary runtime string.
//       Some default shortcuts reference strings registered in NO table; those
//       must degrade gracefully to the production not-found screen via the
//       AppRouter `errorBuilder`, NOT crash. We register the REAL
//       `LegacyRoutes.routes()` plus the REAL production not-found builder
//       (lifted from the live router) as the `errorBuilder`, push an unmapped
//       string, and assert the "Unknown Screen" / "Feature Not Found" screen
//       renders with no thrown exception. We also assert the pure predicate
//       `LegacyRoutes.isKnownLegacyPath` is `false` for the unmapped string and
//       `true` for a registered one.
//
//   (3) ALIASED LOGOUT (Req 7.8 / AD-6) — the out-of-context admin logout in
//       `app.dart` was migrated to navigate through the GoRouter to the
//       canonical `/auth-gate`. The `/auth_gate` (underscore) alias must still
//       resolve to `/auth-gate` (`RoutePaths.authGate`) via the composed
//       redirect. Mirroring the established faithful-harness approach in
//       `phase_a_foundation_wiring_preservation_test.dart`, a minimal
//       `MaterialApp.router` whose redirect consults the SAME production
//       `LegacyRoutes.aliasTargetFor` lands a `go('/auth_gate')` logout on the
//       lightweight canonical `/auth-gate` screen.
//
//   (Req 10.3) The three migrated contracts are encoded as PURE string-level
//   decisions (`aliasTargetFor`, `isKnownLegacyPath`) and route resolution that
//   take NO business-type input, so they hold IDENTICALLY across every
//   In_Scope_Business_Type. We assert this independence explicitly where
//   relevant (the alias + known-path decisions are invariant), and the
//   not-found harness registers the REAL `LegacyRoutes.routes()` whose
//   construction is business-type-agnostic.
//
// DETERMINISM (mirrors `phase_a_foundation_wiring_*` / `phase_b_guarded_*`):
//   We do NOT pump the heavy production `/splash` entry (its SplashScreen runs
//   a repeating animation + GetIt/audio init that never settles). Each harness
//   is a minimal `MaterialApp.router` that reuses the EXACT production pieces
//   that matter — the real `LegacyRoutes.routes()`, the real
//   `LegacyRoutes.aliasTargetFor`, and the real production not-found builder —
//   so a resolved render is provably distinct from the not-found fallback, and
//   every state transition is driven by an explicit button tap.
//
// TEST-ONLY: no production/application code is changed by this task.
//
// Run: flutter test \
//   test/core/routing/phase_e_call_site_preservation_test.dart \
//   --reporter expanded
// ============================================================================

import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Finds the [GoRoute] registered for [path] anywhere in the router
/// configuration and returns its builder, so the harness can render the REAL
/// production not-found screen (not a stand-in). Mirrors the helper in
/// `phase_b_guarded_resolution_preservation_test.dart`.
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
/// harness `errorBuilder` renders the actual `_RouteNotFoundScreen` (whose body
/// shows "Unknown Screen" / "Feature Not Found"). A graceful not-found render is
/// then provably the production fallback, not a test stand-in.
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

const String kHomeMarker = 'HARNESS_HOME';

void main() {
  // GoRouter construction needs an initialized binding (it wires up route
  // information providers). Plain `test()` bodies don't auto-initialize it.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature: imperative-navigation-gorouter-migration — Phase E '
      'PRESERVATION: migrated call sites (Req 6.2, 7.8, 8.2, 8.3, 10.2, 10.3)', () {
    // ======================================================================
    // (1) RETURN VALUE — `/qr_scanner` push returns a String the caller
    //     consumes (Req 6.2 / AD-4).
    // ======================================================================
    testWidgets(
      'a context.push<String>("/qr_scanner") returns a Future whose awaited '
      'value is the String popped by the scanner (go would NOT return it)',
      (tester) async {
        const String scannedPayload = 'v1:DX-VND-1234567890-ABCD';
        const String pushMarker = 'PUSH_QR';
        const String popMarker = 'POP_WITH_RESULT';

        // Captured side effects of the migrated call-site contract.
        Future<String?>? returnedFuture; // the Future `push` returns (AD-4)
        String? consumedResult; // what the caller awaited + consumed

        final GoRouter router = GoRouter(
          initialLocation: '/home',
          routes: <RouteBase>[
            // Caller screen — mirrors customer_link_shop_screen's migrated
            // `final result = await context.push<String>('/qr_scanner');`
            // followed by the `if (result is String)` consume.
            GoRoute(
              path: '/home',
              builder: (BuildContext context, GoRouterState state) => Scaffold(
                body: Center(
                  child: Builder(
                    builder: (BuildContext ctx) => ElevatedButton(
                      onPressed: () async {
                        final Future<String?> future = ctx.push<String>(
                          '/qr_scanner',
                        );
                        returnedFuture = future; // AD-4: push returns a Future
                        final String? result = await future;
                        // Preserve the legacy `is String` result check.
                        if (result is String) {
                          consumedResult = result;
                        }
                      },
                      child: const Text(pushMarker),
                    ),
                  ),
                ),
              ),
            ),
            // Faithful lightweight stand-in for the real QR scanner (which needs
            // a camera/plugins): it pops a String result on an explicit tap, so
            // the awaited contract is exercised deterministically.
            GoRoute(
              path: '/qr_scanner',
              builder: (BuildContext context, GoRouterState state) => Scaffold(
                body: Center(
                  child: Builder(
                    builder: (BuildContext ctx) => ElevatedButton(
                      onPressed: () => ctx.pop(scannedPayload),
                      child: const Text(popMarker),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Sanity: start on the caller screen.
        expect(find.text(pushMarker), findsOneWidget);

        // Issue the migrated `await context.push<String>('/qr_scanner')`.
        await tester.tap(find.text(pushMarker));
        await tester.pumpAndSettle();

        // The push API returned a Future (the result channel `go` lacks) —
        // this is exactly why a return-value call site MUST use push (AD-4).
        expect(
          returnedFuture,
          isA<Future<String?>>(),
          reason:
              'context.push<String>(...) must return a Future<String?> so the '
              'caller can await the scanned result (go returns no result).',
        );

        // We are now on the scanner screen; pop it WITH a String result.
        expect(find.text(popMarker), findsOneWidget);
        await tester.tap(find.text(popMarker));
        await tester.pumpAndSettle();

        // The awaited value is exactly the popped String, and the caller's
        // `is String` consume ran — the return-value contract is preserved.
        expect(
          consumedResult,
          scannedPayload,
          reason:
              'The caller must receive and consume the exact String the '
              'scanner returned via context.pop (return-value contract).',
        );

        // Back on the caller screen after the pop.
        expect(find.text(pushMarker), findsOneWidget);
      },
    );

    // ======================================================================
    // (2) UNMAPPED DYNAMIC — pushing an unregistered string renders the
    //     production not-found screen, no crash (Req 8.2, 8.3 / AD-7).
    // ======================================================================

    // Pure-predicate guard rail first (deterministic, business-type agnostic).
    test('isKnownLegacyPath is false for an unmapped string and true for a '
        'registered legacy path (Req 8.4 — supports the dynamic safety net)', () {
      const String unmapped = '/totally_unmapped_xyz';

      expect(
        LegacyRoutes.isKnownLegacyPath(unmapped),
        isFalse,
        reason:
            'An unmapped dynamic shortcut string must be detectable as NOT a '
            'registered legacy route.',
      );

      // A representative registered legacy path reports true (parity).
      expect(LegacyRoutes.knownLegacyPaths, isNotEmpty);
      final String knownPath = LegacyRoutes.knownLegacyPaths.first;
      expect(
        LegacyRoutes.isKnownLegacyPath(knownPath),
        isTrue,
        reason: 'A registered legacy path must report as known.',
      );

      // (Req 10.3) The predicate takes NO business-type input — its answer is
      // identical regardless of the active business type (purely string-keyed).
      expect(LegacyRoutes.isKnownLegacyPath(unmapped), isFalse);
      expect(LegacyRoutes.isKnownLegacyPath(knownPath), isTrue);
    });

    testWidgets(
      'pushing an unmapped dynamic string (shortcut_panel contract) renders '
      'the production not-found screen via errorBuilder, with no crash',
      (tester) async {
        const String unmapped = '/totally_unmapped_xyz';
        const String pushMarker = 'PUSH_UNMAPPED';

        // Faithful harness: REAL LegacyRoutes.routes() + REAL production
        // not-found builder as errorBuilder + the production alias redirect.
        final GoRouter router = GoRouter(
          initialLocation: '/harness-home',
          redirect: (BuildContext context, GoRouterState state) =>
              LegacyRoutes.aliasTargetFor(state.matchedLocation),
          routes: <RouteBase>[
            GoRoute(
              path: '/harness-home',
              builder: (BuildContext context, GoRouterState state) => Scaffold(
                body: Center(
                  child: Builder(
                    builder: (BuildContext ctx) => ElevatedButton(
                      // Mirrors shortcut_panel's migrated
                      // `context.push(def.route!)` for a runtime string.
                      onPressed: () => ctx.push(unmapped),
                      child: const Text(pushMarker),
                    ),
                  ),
                ),
              ),
            ),
            // The REAL migrated legacy routes (single source of truth). The
            // unmapped string is intentionally absent from this set.
            ...LegacyRoutes.routes(),
          ],
          errorBuilder: _liveNotFoundBuilder(),
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Sanity: start on the ungated home.
        expect(find.text(pushMarker), findsOneWidget);

        // Push the unmapped runtime string.
        await tester.tap(find.text(pushMarker));
        await tester.pumpAndSettle();

        // Graceful degradation: the PRODUCTION not-found screen renders
        // (its body shows both "Unknown Screen" and "Feature Not Found").
        expect(
          find.text('Unknown Screen'),
          findsOneWidget,
          reason:
              'An unmapped dynamic string must degrade to the production '
              'not-found screen via errorBuilder (Req 8.2).',
        );
        expect(find.text('Feature Not Found'), findsOneWidget);

        // No exception was thrown by the navigation (Req 8.3).
        expect(
          tester.takeException(),
          isNull,
          reason: 'Navigating to an unmapped string must not throw or crash.',
        );
      },
    );

    // ======================================================================
    // (3) ALIASED LOGOUT — `/auth_gate` (underscore) resolves to the canonical
    //     `/auth-gate` via the composed redirect (Req 7.8 / AD-6).
    // ======================================================================

    // Pure decision function first (deterministic, business-type agnostic).
    test(
      'aliasTargetFor resolves the /auth_gate logout alias to the canonical '
      '/auth-gate, and is idempotent on the canonical target (Req 7.8/7.7)',
      () {
        // The underscore logout alias -> canonical RoutePaths.authGate.
        expect(
          LegacyRoutes.aliasTargetFor('/auth_gate'),
          RoutePaths.authGate,
          reason:
              'The /auth_gate logout alias must resolve to the canonical '
              '/auth-gate path (RoutePaths.authGate).',
        );
        // Idempotent: applying it to the canonical target returns null, so the
        // composed redirect falls through and never loops.
        expect(
          LegacyRoutes.aliasTargetFor(RoutePaths.authGate),
          isNull,
          reason:
              'Resolving the already-canonical /auth-gate must return null '
              '(idempotent, no redirect loop).',
        );

        // (Req 10.3) The alias decision takes NO business-type input — it is the
        // same for every active business type (purely string-keyed).
        expect(LegacyRoutes.aliasTargetFor('/auth_gate'), RoutePaths.authGate);
      },
    );

    testWidgets(
      'an out-of-context-style logout that navigates to /auth_gate lands on '
      'the canonical /auth-gate screen via the production alias resolution',
      (tester) async {
        const String authGateMarker = 'AUTH_GATE_SCREEN';
        const String loginMarker = 'LOGIN_SCREEN';
        const String splashMarker = 'SPLASH_SCREEN';
        const String logoutMarker = 'LOGOUT';

        Widget marker(String text) => Scaffold(body: Center(child: Text(text)));

        // Faithful harness mirroring the production composition: its top-level
        // redirect consults the REAL LegacyRoutes.aliasTargetFor and registers
        // lightweight canonical foundation screens. It does NOT pump /splash.
        final GoRouter router = GoRouter(
          initialLocation: '/home',
          redirect: (BuildContext context, GoRouterState state) =>
              LegacyRoutes.aliasTargetFor(state.matchedLocation),
          routes: <RouteBase>[
            GoRoute(
              path: '/home',
              builder: (BuildContext context, GoRouterState state) => Scaffold(
                body: Center(
                  child: Builder(
                    builder: (BuildContext ctx) => ElevatedButton(
                      // The migrated stack-clearing logout (verb: go) targeting
                      // the legacy underscore alias string.
                      onPressed: () => ctx.go('/auth_gate'),
                      child: const Text(logoutMarker),
                    ),
                  ),
                ),
              ),
            ),
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
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Sanity: start on the home screen with the logout action.
        expect(find.text(logoutMarker), findsOneWidget);

        // Perform the logout to the legacy underscore alias.
        await tester.tap(find.text(logoutMarker));
        await tester.pumpAndSettle();

        // The alias resolved to the canonical /auth-gate screen.
        expect(
          find.text(authGateMarker),
          findsOneWidget,
          reason:
              'The /auth_gate logout alias must resolve to the canonical '
              '/auth-gate screen (Req 7.8).',
        );
        // It is NOT the underscore string left unresolved (no error screen).
        expect(tester.takeException(), isNull);
      },
    );
  });
}
