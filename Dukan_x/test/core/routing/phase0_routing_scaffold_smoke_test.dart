// ============================================================================
// PHASE 0/1 — Routing scaffolding + flag-gated wiring smoke test
// (go_router navigation migration)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Originally: Task 1.2 — Phase 0 smoke test (scaffolding importable but UNUSED).
// Updated by: Task 2.3 — Phase 1 foundation routes + flag-gated app-root
//             selection. The Phase 0 assertions ("no lib file imports
//             core/routing", "app.dart has no GoRouter reference") are
//             LEGITIMATELY broken by Phase 1, which intentionally wires the
//             GoRouter into the app root behind the `useGoRouterShell` flag.
//             This test is updated MINIMALLY to assert the NEW invariant while
//             preserving the original zero-behavior-change intent:
//
//               * the routing scaffolding is importable and builds a usable
//                 GoRouter with the FOUR Phase-1 foundation routes;
//               * the flag-gated wiring is PRESENT at the app root;
//               * AFTER the Phase 8 cutover (Task 9.2) the DEFAULT is now
//                 go_router — the flag defaults to `true` and the app root
//                 drives `MaterialApp.router`. The legacy `MaterialApp` +
//                 `buildAppRoutes()` path remains intact (verbatim) as the
//                 non-default fallback.
//
//             Why the change (not a weakening): Phase 0's "scaffolding unused"
//             guarantee was a Phase-0-only constraint. Phase 1's
//             zero-behavior-change guarantee is enforced by the flag DEFAULT
//             (false → legacy), not by the absence of an import. So we replace
//             the "unused" checks with "wired but default-off" checks.
//
// SEAM NOTE (app-root selection): the full `DukanXApp` widget cannot be pumped
// deterministically in a unit test — its build reads theme/locale providers and
// the GetIt service locator (network/auth/SharedPreferences). The full
// flag-OFF-identical-to-legacy preservation test is Task 2.4. Here we assert
// the most meaningful DETERMINISTIC seam: (a) the flag's default value, and
// (b) that both navigation branches are wired at the app root in source.
//
// Validates: Requirements 1.4, 1.5, 3.1, 3.2, 3.3, 4.1
// ============================================================================

import 'dart:io';

import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Reads a file under the Dukan_x package root (test cwd == package root).
String _readLibFile(String relativePath) {
  final file = File(relativePath);
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Expected file to exist for the wiring check: $relativePath',
  );
  return file.readAsStringSync();
}

void main() {
  group('Routing scaffolding is importable and builds the Phase-1 router '
      '(Req 1.5, 4.1)', () {
    test('appRouterProvider yields a usable GoRouter', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      expect(router, isA<GoRouter>());
    });

    test('router exposes the FOUR foundation routes '
        '(splash, login, business-type resolution, shell)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      final topLevel = router.configuration.routes;

      // NOTE: the exact top-level count check (`hasLength(4)`) was relaxed.
      // The imperative-navigation-gorouter-migration (Task 2.6) additively
      // spreads ~120 legacy GoRoutes at the top level, so the total is no
      // longer exactly 4. The foundation is still verified intact below: the
      // three foundation GoRoutes are present, exactly one ShellRoute exists,
      // and the shell child contains the `/app` base path.

      final goRoutePaths = topLevel
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();
      expect(
        goRoutePaths,
        containsAll(<String>[
          RoutePaths.splash,
          RoutePaths.login,
          RoutePaths.authGate,
        ]),
        reason: 'The three top-level foundation GoRoutes must be registered.',
      );

      // The main shell is a ShellRoute (renders the existing shell scaffold).
      final shellRoutes = topLevel.whereType<ShellRoute>().toList();
      expect(
        shellRoutes,
        hasLength(1),
        reason: 'The main shell must be a single ShellRoute (Req 4.1).',
      );

      // The shell base path is registered as a child of the ShellRoute.
      final shellChildPaths = shellRoutes.single.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();
      expect(
        shellChildPaths,
        contains(RoutePaths.shell),
        reason: 'The shell base path must be a child of the ShellRoute.',
      );
    });

    test('RoutePaths exposes the Phase-1 foundation constants', () {
      // Foundation route constants exist with their documented values.
      expect(RoutePaths.splash, '/splash');
      expect(RoutePaths.login, '/login');
      expect(RoutePaths.authGate, '/auth-gate');
      expect(RoutePaths.shell, '/app');
    });
  });

  group('go_router is the SOLE navigation path at the app root (Task 9.3) '
      '(Req 11.2, 11.3)', () {
    test(
      'app.dart drives navigation via MaterialApp.router (no legacy path)',
      () {
        final appSource = _readLibFile('lib/app/app.dart');

        expect(
          appSource.contains('MaterialApp.router'),
          isTrue,
          reason:
              'The app root must drive navigation via MaterialApp.router '
              '(GoRouter) — go_router is the sole navigation path.',
        );
        expect(
          appSource.contains('appRouterProvider'),
          isTrue,
          reason:
              'The app root must consume the GoRouter via appRouterProvider.',
        );
        // The legacy named-route table is no longer wired into the app root.
        expect(
          appSource.contains('buildAppRoutes()'),
          isFalse,
          reason:
              'Task 9.3 removed the legacy MaterialApp + buildAppRoutes() path '
              'from the app root.',
        );
        // The removed feature flag must no longer be referenced.
        expect(
          appSource.contains('useGoRouterShell'),
          isFalse,
          reason:
              'Task 9.3 removed the useGoRouterShell flag; the app root no '
              'longer reads it.',
        );
      },
    );

    test('main.dart does NOT wire the GoRouter scaffolding (unchanged)', () {
      final mainSource = _readLibFile('lib/main.dart');
      expect(
        mainSource.contains('app_router') ||
            mainSource.contains('AppRouter') ||
            mainSource.contains('GoRouter'),
        isFalse,
        reason:
            'Navigation selection lives in app.dart, not main.dart — main.dart '
            'must remain unchanged.',
      );
    });
  });
}
