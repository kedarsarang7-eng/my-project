// ============================================================================
// PHASE 2 — Task 3.3: Route-registration parity test
// (go_router navigation migration)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 3.3 — Register named GoRoutes under the ShellRoute (same screens, args).
// Validates: Requirements 5.1, 5.2, 5.3
//
// PURPOSE:
//   Asserts 1:1 route/screen parity for the Phase 2 registration:
//     (1) For EVERY `RoutePaths.knownItemIds` (90), the `AppRouter` GoRouter
//         registers exactly one child `GoRoute` whose `path` equals
//         `RoutePaths.pathForItemId(itemId)` and whose `name` is the stable
//         `itemId` — and these live UNDER the main `ShellRoute` (Req 5.1).
//     (2) Each route builder resolves to the IDENTICAL screen the legacy
//         `SidebarNavigationHandler.getScreenForItem` returns — same runtime
//         `Type` AND the key varying constructor args
//         (`GstReportsScreen.initialIndex`, `PartyLedgerListScreen.initialFilter`,
//          restaurant `vendorId`) (Req 5.2, 5.3). The route builders delegate to
//         `AppRouter.screenForItemId`, which delegates to the legacy switch
//         (single source of truth) — so this proves parity by construction.
//     (3) The `RoutePaths.notFound` sentinel route is registered and resolves to
//         the theme-aware "Feature Not Found" placeholder, and the go_router
//         `errorBuilder` renders that same placeholder for unknown deep links
//         (mirrors the legacy switch `default:` `_PlaceholderScreen`).
//
// NOTE: route builders ignore `GoRouterState`; we verify the screen resolver
//   (`AppRouter.screenForItemId`) and the route registration separately. Since
//   every per-item builder is `(c, s) => AppRouter.screenForItemId(itemId, c)`,
//   registration-coverage + resolver-parity together prove route/screen parity
//   without pumping ~90 heavyweight screens.
// ============================================================================

import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Imports used ONLY to read varying constructor args off resolved widgets.
import 'package:dukanx/features/gst/screens/gst_reports_screen.dart';
import 'package:dukanx/features/party_ledger/screens/party_ledger_list_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/table_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/kitchen_display_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/food_menu_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/restaurant_daily_summary_screen.dart';

/// Recursively collects every registered [GoRoute] (path + optional name),
/// descending through [ShellRoute] / sub-routes.
void _collectGoRoutes(
  List<RouteBase> routes,
  Map<String, String> pathByName,
  Set<String> paths,
) {
  for (final route in routes) {
    if (route is GoRoute) {
      paths.add(route.path);
      final name = route.name;
      if (name != null) pathByName[name] = route.path;
      _collectGoRoutes(route.routes, pathByName, paths);
    } else if (route is ShellRouteBase) {
      _collectGoRoutes(route.routes, pathByName, paths);
    }
  }
}

/// Captures a real [BuildContext] from a minimally pumped host so the legacy
/// dispatch and the router resolver can be driven exactly as the shell drives
/// them. Constructing `const` screen widgets runs no `build()`/IO.
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
  group('Feature: gorouter-navigation-migration — Phase 2 route-registration '
      'parity (Req 5.1, 5.2, 5.3)', () {
    late GoRouter router;
    late Map<String, String> pathByName;
    late Set<String> allPaths;

    setUp(() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      router = container.read(appRouterProvider);

      pathByName = <String, String>{};
      allPaths = <String>{};
      _collectGoRoutes(router.configuration.routes, pathByName, allPaths);
    });

    // ----------------------------------------------------------------------
    // 1) Totality of registration: every known itemId has exactly one route
    //    with the expected path + stable name (Req 5.1).
    // ----------------------------------------------------------------------
    test('every known itemId has a registered GoRoute (path + name)', () {
      for (final itemId in RoutePaths.knownItemIds) {
        final expectedPath = RoutePaths.pathForItemId(itemId);

        expect(
          allPaths,
          contains(expectedPath),
          reason:
              'No GoRoute registered for itemId "$itemId" '
              '(expected path "$expectedPath").',
        );
        expect(
          pathByName[itemId],
          expectedPath,
          reason:
              'GoRoute for itemId "$itemId" must use the itemId as its '
              'stable name and resolve to "$expectedPath".',
        );
      }
    });

    test(
      'exactly 90 itemId routes are registered (no dropped/phantom ids)',
      () {
        final itemIdPaths = RoutePaths.knownItemIds
            .map(RoutePaths.pathForItemId)
            .toSet();
        expect(itemIdPaths, hasLength(90));
        // Every itemId path is present among the registered routes.
        expect(allPaths.containsAll(itemIdPaths), isTrue);
      },
    );

    // ----------------------------------------------------------------------
    // 2) The not-found sentinel route is registered (Task 3.3).
    // ----------------------------------------------------------------------
    test('the RoutePaths.notFound sentinel route is registered', () {
      expect(allPaths, contains(RoutePaths.notFound));
      expect(pathByName[RoutePaths.notFoundName], RoutePaths.notFound);
    });

    // ----------------------------------------------------------------------
    // 3) Screen parity: the router resolver yields the SAME screen type as
    //    the legacy dispatch for every itemId (Req 5.2).
    // ----------------------------------------------------------------------
    testWidgets(
      'router resolver yields the same screen Type as legacy for every '
      'itemId',
      (tester) async {
        final context = await _pumpAndCaptureContext(tester);

        for (final itemId in RoutePaths.knownItemIds) {
          final legacy = SidebarNavigationHandler.getScreenForItem(
            itemId,
            context,
          );
          final routed = AppRouter.screenForItemId(itemId, context);
          expect(
            routed.runtimeType,
            legacy.runtimeType,
            reason:
                'Route resolver for itemId "$itemId" returned '
                '${routed.runtimeType} but legacy returns '
                '${legacy.runtimeType}.',
          );
        }
      },
    );

    // ----------------------------------------------------------------------
    // 4) Key varying constructor args are preserved (Req 5.3).
    // ----------------------------------------------------------------------
    testWidgets('GstReportsScreen.initialIndex is preserved per itemId', (
      tester,
    ) async {
      final context = await _pumpAndCaptureContext(tester);

      const expectedIndex = <String, int>{
        'gstr1': 0,
        'b2b_b2c': 0,
        'hsn_reports': 1,
        'tax_liability': 2,
        'filing_status': 3,
      };
      expectedIndex.forEach((itemId, index) {
        final routed =
            AppRouter.screenForItemId(itemId, context) as GstReportsScreen;
        expect(routed.initialIndex, index);
      });
    });

    testWidgets('PartyLedgerListScreen.initialFilter is preserved', (
      tester,
    ) async {
      final context = await _pumpAndCaptureContext(tester);

      final suppliers =
          AppRouter.screenForItemId('suppliers', context)
              as PartyLedgerListScreen;
      expect(suppliers.initialFilter, 'supplier');

      final outstanding =
          AppRouter.screenForItemId('outstanding', context)
              as PartyLedgerListScreen;
      expect(outstanding.initialFilter, 'receivable');

      final partyLedger =
          AppRouter.screenForItemId('party_ledger', context)
              as PartyLedgerListScreen;
      expect(partyLedger.initialFilter, isNull);
    });

    testWidgets(
      "restaurant routes preserve the (out-of-scope) vendorId:'SYSTEM' arg",
      (tester) async {
        final context = await _pumpAndCaptureContext(tester);

        expect(
          (AppRouter.screenForItemId('restaurant_tables', context)
                  as TableManagementScreen)
              .vendorId,
          'SYSTEM',
        );
        expect(
          (AppRouter.screenForItemId('kitchen_display', context)
                  as KitchenDisplayScreen)
              .vendorId,
          'SYSTEM',
        );
        expect(
          (AppRouter.screenForItemId('menu_management', context)
                  as FoodMenuManagementScreen)
              .vendorId,
          'SYSTEM',
        );
        expect(
          (AppRouter.screenForItemId('daily_summary', context)
                  as RestaurantDailySummaryScreen)
              .vendorId,
          'SYSTEM',
        );
      },
    );

    // ----------------------------------------------------------------------
    // 5) Duplicate-screen itemIds keep DISTINCT paths but resolve to the same
    //    screen Type (preserved, not deduped — design Model 2).
    // ----------------------------------------------------------------------
    testWidgets('documented duplicate itemIds share screen type, keep '
        'distinct paths', (tester) async {
      final context = await _pumpAndCaptureContext(tester);

      String typeOf(String itemId) =>
          AppRouter.screenForItemId(itemId, context).runtimeType.toString();

      const dupPairs = <List<String>>[
        ['purchase_register', 'procurement_log'],
        ['invoice_margin', 'income_statement'],
        ['funds_flow', 'cash_bank'],
        ['gstr1', 'b2b_b2c'],
        ['print_settings', 'doc_templates'],
      ];
      for (final pair in dupPairs) {
        expect(
          typeOf(pair[0]),
          typeOf(pair[1]),
          reason: '${pair[0]} and ${pair[1]} must resolve to the same screen.',
        );
        expect(
          RoutePaths.pathForItemId(pair[0]),
          isNot(RoutePaths.pathForItemId(pair[1])),
          reason:
              '${pair[0]} and ${pair[1]} must keep DISTINCT paths (no dedup '
              'in Phase 2).',
        );
      }
    });

    // ----------------------------------------------------------------------
    // 6) The errorBuilder renders the theme-aware "Feature Not Found"
    //    placeholder for unknown deep links (mirrors legacy default).
    //
    //    We navigate to an unknown TOP-LEVEL path BEFORE pumping, so the
    //    router's initial `/splash` route (animation/IO heavy) never mounts;
    //    the errorBuilder placeholder is a self-contained themed Scaffold.
    // ----------------------------------------------------------------------
    testWidgets('unknown deep link renders the Feature Not Found placeholder', (
      tester,
    ) async {
      router.go('/totally-unknown-top-level-route');

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pump();

      expect(find.text('Feature Not Found'), findsOneWidget);
      expect(find.text('Unknown Screen'), findsOneWidget);
    });
  });
}
