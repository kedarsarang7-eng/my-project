// ============================================================================
// Shell sidebar-tap dispatch test (go_router navigation)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 3.4 — introduced the shell sidebar-tap dispatch seam.
// Task 9.3 (PHASE 8 — legacy removal) — the `useGoRouterShell` flag and the
// legacy `NavigationController` dispatch branch are gone; go_router is the SOLE
// navigation path. This test now proves the (sole) go_router dispatch behavior.
// Validates: Requirements 3.2, 3.3, 5.7, 11.3
//
// WHAT THIS PROVES:
//   1) DISPATCH (Req 3.2, 3.3): a sidebar tap calls
//      `context.go(RoutePaths.pathForItemId(itemId))` (the routed location
//      changes to the correct path). This drives the EXACT seam the shell uses:
//      the standalone `dispatchSidebarItem(context, itemId)` that
//      `DesktopRootShell`'s sidebar `onItemSelected` callback calls.
//
//   2) ROUTED CHILD RENDERING (Req 3.2): the `ShellRoute` builder forwards
//      go_router's routed `child` into the shell content area via
//      `AdaptiveShell.routedChild`. `DesktopRootShell` then renders
//      `routedChild ?? const DesktopContentHost()`, so the routed screen body
//      shows in the shell content region.
//
// SEAM + LIMITATION (stated explicitly):
//   The dispatch half is proven deterministically with a lightweight test
//   `GoRouter` (no heavyweight shell, no `/splash`/`AuthGate`/GetIt). The
//   routed-child half is proven STRUCTURALLY by invoking the REAL
//   `appRouterProvider` `ShellRoute` builder. Pumping the FULL desktop shell is
//   non-deterministic in a widget test (real screens reach into GetIt /
//   SessionManager / SharedPreferences), so end-to-end "tap → routed screen
//   visible inside the live shell" is covered by the Phase 8 integration
//   regression. `sidebarSectionsProvider` capability/RBAC filtering is NOT
//   touched by this task (Req 5.7).
// ============================================================================

import 'package:dukanx/core/responsive/adaptive_shell.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/core/routing/sidebar_dispatch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Builds a lightweight test [GoRouter] that mirrors the shell dispatch seam:
///   * `/`              → a home screen with a button that, on tap, calls the
///                        production `dispatchSidebarItem` for [itemId].
///   * the itemId path  → a marker screen, so we can assert a go_router
///                        navigation actually occurred.
///
/// Using marker widgets (rather than reading private router location state)
/// keeps the assertions robust across go_router versions.
GoRouter _dispatchTestRouter(String itemId) {
  final targetPath = RoutePaths.pathForItemId(itemId);
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => dispatchSidebarItem(context, itemId),
              child: const Text('HOME_TAP'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: targetPath,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('ROUTED_SCREEN'))),
      ),
    ],
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('ROUTE_ERROR'))),
  );
}

/// Pumps the dispatch harness for [itemId].
Future<void> _pumpDispatchHarness(
  WidgetTester tester, {
  required String itemId,
}) async {
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: _dispatchTestRouter(itemId)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature: gorouter-navigation-migration — sidebar dispatch '
      '(Req 3.2, 3.3, 5.7)', () {
    // ----------------------------------------------------------------------
    // 1) DISPATCH (go_router): context.go to the correct path.
    // ----------------------------------------------------------------------
    testWidgets('sidebar tap navigates via context.go to the correct '
        'RoutePaths path', (tester) async {
      await _pumpDispatchHarness(tester, itemId: 'customers');

      expect(find.text('HOME_TAP'), findsOneWidget);

      await tester.tap(find.text('HOME_TAP'));
      await tester.pumpAndSettle();

      // go_router path: navigated to RoutePaths.pathForItemId('customers').
      expect(
        find.text('ROUTED_SCREEN'),
        findsOneWidget,
        reason:
            'A sidebar tap must call '
            'context.go(RoutePaths.pathForItemId(itemId)) and land on the '
            'correct route ("${RoutePaths.pathForItemId('customers')}").',
      );
      expect(find.text('HOME_TAP'), findsNothing);
    });

    // A second itemId confirms the dispatch resolves the path generically
    // (not hardcoded for one item).
    testWidgets('dispatch resolves the path per-itemId (new_sale)', (
      tester,
    ) async {
      await _pumpDispatchHarness(tester, itemId: 'new_sale');

      await tester.tap(find.text('HOME_TAP'));
      await tester.pumpAndSettle();

      expect(find.text('ROUTED_SCREEN'), findsOneWidget);
      // Sanity: the target path used by the harness is the canonical one.
      expect(RoutePaths.pathForItemId('new_sale'), '/app/new-sale');
    });

    // ----------------------------------------------------------------------
    // 2) ROUTED CHILD RENDERING (structural) — the real ShellRoute builder
    //    forwards go_router's routed child into the shell content area.
    // ----------------------------------------------------------------------
    testWidgets('the real ShellRoute forwards the routed child into '
        'AdaptiveShell.routedChild (shell content area)', (tester) async {
      // Capture a real BuildContext + GoRouterState cheaply (the builder is a
      // pure pass-through, so any valid context/state suffices).
      late BuildContext capturedContext;
      late GoRouterState capturedState;
      final tinyRouter = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) {
              capturedContext = context;
              capturedState = state;
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: tinyRouter));
      await tester.pumpAndSettle();

      // Build the REAL application router and locate its ShellRoute.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final appRouter = container.read(appRouterProvider);
      addTearDown(appRouter.dispose);

      final shellRoute = appRouter.configuration.routes
          .whereType<ShellRoute>()
          .first;

      // The sentinel stands in for the per-item routed screen body.
      const sentinel = KeyedSubtree(
        key: ValueKey('routed-child-sentinel'),
        child: SizedBox.shrink(),
      );

      final built = shellRoute.builder!(
        capturedContext,
        capturedState,
        sentinel,
      );

      expect(
        built,
        isA<AdaptiveShell>(),
        reason: 'The ShellRoute must render the existing AdaptiveShell.',
      );
      expect(
        (built as AdaptiveShell).routedChild,
        same(sentinel),
        reason:
            'The ShellRoute must forward go_router\'s routed child into the '
            'shell content area (AdaptiveShell.routedChild) so the routed '
            'screen renders inside the shell.',
      );
    });

    // The extracted shell builder is a pure pass-through (unit-level backstop).
    testWidgets('AppRouter.shellBuilder forwards its child unchanged', (
      tester,
    ) async {
      late BuildContext capturedContext;
      late GoRouterState capturedState;
      final tinyRouter = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) {
              capturedContext = context;
              capturedState = state;
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: tinyRouter));
      await tester.pumpAndSettle();

      const sentinel = SizedBox(key: ValueKey('s'));
      final built = AppRouter.shellBuilder(
        capturedContext,
        capturedState,
        sentinel,
      );
      expect((built as AdaptiveShell).routedChild, same(sentinel));
    });

    // ----------------------------------------------------------------------
    // 3) Req 5.7 guard — the reverse path<->itemId resolver used by the shell
    //    highlight is consistent with pathForItemId (no sidebar-filter change).
    // ----------------------------------------------------------------------
    test('itemIdForPath is the inverse of pathForItemId for known items', () {
      for (final itemId in RoutePaths.knownItemIds) {
        final path = RoutePaths.pathForItemId(itemId);
        expect(
          RoutePaths.itemIdForPath(path),
          itemId,
          reason: 'Round-trip itemId<->path must hold for "$itemId".',
        );
      }
      // Non-item locations (shell base, not-found) map back to null.
      expect(RoutePaths.itemIdForPath(RoutePaths.shell), isNull);
      expect(RoutePaths.itemIdForPath(RoutePaths.notFound), isNull);
    });
  });
}
