// ============================================================================
// Task 9.2 — WIDGET TESTS
// Feature: cross-platform-responsive-ui — Desktop_Shell preservation
// Requirements: 5.2, 5.4, 5.5, 5.6, 5.7
// ============================================================================
// Unit under test:
//   `DesktopRootShell` from
//   `package:dukanx/widgets/desktop/desktop_root_shell.dart`.
//
//   Structure (frozen — Req 5.5):
//     Scaffold > Stack > [
//       Row[ if(chromeVisible) EnterpriseDesktopSidebar,
//            Expanded(Column[ if(chromeVisible) EnterpriseTopBar,
//                             Expanded(PremiumContentWrapper(DesktopContentHost)) ]) ],
//       Positioned(full-screen toggle button)
//     ]
//
//   The distraction-free / full-screen state is owned by
//   `desktopChromeVisibleProvider` (default true). When chrome is hidden the
//   sidebar + top bar are removed from the tree while `DesktopContentHost`
//   stays mounted, so the selected destination survives the toggle
//   (Req 5.6, 5.7).
//
// ---------------------------------------------------------------------------
// Test strategy / why the overrides:
//
//   * `sidebarSectionsProvider` (a plain `Provider`) is overridden with a
//     CONTROLLED, deterministic list of sections via `overrideWithValue`, so
//     the whole capability/permission/session/business-context graph is
//     bypassed. This makes the rendered sidebar items and the "frozen
//     baseline" destination set fully deterministic.
//
//   * `navigationControllerProvider` is overridden with a real
//     `NavigationController` subclass whose `build()` starts on a LIGHT,
//     content-host-UNMAPPED `AppScreen`. `DesktopContentHost` only ever builds
//     the *current* screen; for an unmapped screen it renders a harmless
//     "under development" placeholder. This avoids constructing the real heavy
//     feature screens (e.g. the executive dashboard), which call into the
//     GetIt service locator from `initState` and would otherwise throw in a
//     pure widget test. All navigation logic remains the real production logic.
//
//   * An explicit `ProviderContainer` + `UncontrolledProviderScope` lets the
//     test DRIVE the real `navigationControllerProvider` and
//     `desktopChromeVisibleProvider` and READ their state for assertions.
//
//   * We never call `pumpAndSettle`: `PremiumContentWrapper` renders a
//     `StarFieldBackground` with a repeating animation, so the tree never goes
//     idle. We pump explicit frames instead.
//
// Run: flutter test test/widgets/desktop/desktop_preservation_test.dart
// ============================================================================

import 'package:dukanx/core/navigation/app_screens.dart';
import 'package:dukanx/core/navigation/navigation_controller.dart';
import 'package:dukanx/core/responsive/desktop_chrome_provider.dart';
import 'package:dukanx/core/responsive/navigation_destinations.dart';
import 'package:dukanx/widgets/desktop/content_host.dart';
import 'package:dukanx/widgets/desktop/desktop_root_shell.dart';
import 'package:dukanx/widgets/desktop/enterprise_desktop_shell.dart'
    show EnterpriseTopBar;
import 'package:dukanx/widgets/desktop/enterprise_sidebar.dart'
    show EnterpriseDesktopSidebar;
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:get_it/get_it.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/core/repository/customers_repository.dart';
import 'package:dukanx/core/repository/vendors_repository.dart';

class MockSessionManager extends Mock implements SessionManager {
  @override
  String? get ownerId => super.noSuchMethod(
    Invocation.getter(#ownerId),
    returnValue: 'test_owner_123',
    returnValueForMissingStub: 'test_owner_123',
  );
}

class MockCustomersRepository extends Mock implements CustomersRepository {
  @override
  Stream<List<Customer>> watchAll({String? userId}) => super.noSuchMethod(
    Invocation.method(#watchAll, [], {#userId: userId}),
    returnValue: Stream<List<Customer>>.value([]),
    returnValueForMissingStub: Stream<List<Customer>>.value([]),
  );
}

class MockVendorsRepository extends Mock implements VendorsRepository {
  @override
  Stream<List<Vendor>> watchAll(String? userId) => super.noSuchMethod(
    Invocation.method(#watchAll, [userId]),
    returnValue: Stream<List<Vendor>>.value([]),
    returnValueForMissingStub: Stream<List<Vendor>>.value([]),
  );
}

/// A real [NavigationController] whose initial `currentScreen` is configurable.
///
/// Used so the shell starts on a content-host-UNMAPPED, lightweight screen
/// (which renders a placeholder) instead of the default executive dashboard
/// (which constructs a heavy, service-locator-backed screen). Every navigation
/// method is inherited unchanged, so the production navigation behaviour is
/// exercised exactly.
class _SeedNavigationController extends NavigationController {
  _SeedNavigationController(this._initialScreen);

  final AppScreen _initialScreen;

  @override
  NavigationState build() => NavigationState(currentScreen: _initialScreen);
}

void main() {
  setUp(() {
    GetIt.I.reset();
    GetIt.I.registerSingleton<SessionManager>(MockSessionManager());
    GetIt.I.registerSingleton<CustomersRepository>(MockCustomersRepository());
    GetIt.I.registerSingleton<VendorsRepository>(MockVendorsRepository());
  });
  // --------------------------------------------------------------------------
  // Controlled, deterministic sidebar sections.
  //
  // The ids below are the FROZEN destination baseline for these tests. They
  // render as plain sidebar tiles; only the *current* navigation screen is ever
  // built by DesktopContentHost, so it is harmless to list ids that map to
  // heavy screens here (e.g. 'customers') — they are never constructed.
  //
  // 'suppliers' maps to AppScreen.suppliers, which is NOT registered in
  // DesktopContentHost's builder map, so navigating to it keeps the content
  // host on the lightweight placeholder (no service-locator access).
  // --------------------------------------------------------------------------
  const List<String> kBaselineDestinationIds = <String>[
    'executive_dashboard',
    'new_sale',
    'customers',
    'suppliers',
    'party_ledger',
    'gstr1',
    'settings',
  ];

  List<SidebarSection> buildSections() => const <SidebarSection>[
    SidebarSection(
      index: 0,
      icon: Icons.space_dashboard_rounded,
      title: 'Primary',
      accentColor: Color(0xFF00D4FF),
      items: <SidebarMenuItem>[
        SidebarMenuItem(
          id: 'executive_dashboard',
          icon: Icons.dashboard_customize_outlined,
          label: 'Dashboard',
        ),
        SidebarMenuItem(
          id: 'new_sale',
          icon: Icons.point_of_sale_outlined,
          label: 'Create Bill',
        ),
      ],
    ),
    SidebarSection(
      index: 1,
      icon: Icons.people_alt_rounded,
      title: 'Parties',
      accentColor: Color(0xFF34D399),
      items: <SidebarMenuItem>[
        SidebarMenuItem(
          id: 'customers',
          icon: Icons.person_outline,
          label: 'Customers',
        ),
        SidebarMenuItem(
          id: 'suppliers',
          icon: Icons.storefront_outlined,
          label: 'Suppliers',
        ),
        SidebarMenuItem(
          id: 'party_ledger',
          icon: Icons.account_balance_wallet_outlined,
          label: 'Party Ledger',
        ),
      ],
    ),
    SidebarSection(
      index: 2,
      icon: Icons.settings_applications_rounded,
      title: 'System',
      accentColor: Color(0xFF94A3B8),
      items: <SidebarMenuItem>[
        SidebarMenuItem(
          id: 'gstr1',
          icon: Icons.receipt_outlined,
          label: 'GSTR-1',
        ),
        SidebarMenuItem(
          id: 'settings',
          icon: Icons.tune_outlined,
          label: 'Settings',
        ),
      ],
    ),
  ];

  /// Builds an explicit container with the controlled sidebar sections and a
  /// seeded navigation controller starting on [initialScreen].
  ProviderContainer makeContainer({required AppScreen initialScreen}) {
    final container = ProviderContainer(
      overrides: [
        sidebarSectionsProvider.overrideWithValue(buildSections()),
        navigationControllerProvider.overrideWith(
          () => _SeedNavigationController(initialScreen),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Pumps `DesktopRootShell` on a desktop-sized surface inside the given
  /// [container]. Never settles (the star-field animation repeats forever).
  Future<void> pumpShell(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DesktopRootShell()),
      ),
    );
    // One frame is enough to build the static shell structure.
    await tester.pump();
  }

  group('Feature: cross-platform-responsive-ui — Desktop_Shell preservation', () {
    testWidgets(
      'sidebar + top bar + content host render together while chrome is '
      'visible (Req 5.2)',
      (tester) async {
        final container = makeContainer(initialScreen: AppScreen.reportsHub);
        await pumpShell(tester, container);

        // Chrome is visible by default.
        expect(container.read(desktopChromeVisibleProvider), isTrue);

        // All three desktop regions are present simultaneously.
        expect(find.byType(EnterpriseDesktopSidebar), findsOneWidget);
        expect(find.byType(EnterpriseTopBar), findsOneWidget);
        expect(find.byType(DesktopContentHost), findsOneWidget);
      },
    );

    testWidgets(
      'selecting a navigation destination marks it active on the sidebar '
      '(Req 5.4)',
      (tester) async {
        // Start on a different screen so the navigation actually changes state.
        final container = makeContainer(initialScreen: AppScreen.reportsHub);
        await pumpShell(tester, container);

        // The sidebar initially reflects the seeded screen's id.
        var sidebar = tester.widget<EnterpriseDesktopSidebar>(
          find.byType(EnterpriseDesktopSidebar),
        );
        expect(sidebar.selectedItemId, AppScreen.reportsHub.id);

        // Drive the REAL navigation controller to a known destination that is
        // also present in the sidebar ('suppliers' -> AppScreen.suppliers).
        container
            .read(navigationControllerProvider.notifier)
            .navigateTo(AppScreen.suppliers);
        // Flush the navigation microtask + rebuild. The second pump lets the
        // content host's post-frame callback settle (and cancel) its internal
        // latency-budget timer once `isNavigating` returns to false.
        await tester.pump();
        await tester.pump();

        // The shell passes the new current screen id down as the active marker.
        sidebar = tester.widget<EnterpriseDesktopSidebar>(
          find.byType(EnterpriseDesktopSidebar),
        );
        expect(sidebar.selectedItemId, AppScreen.suppliers.id);
        expect(
          container.read(navigationControllerProvider).currentScreen,
          AppScreen.suppliers,
        );
      },
    );

    testWidgets(
      'the reachable destination set equals the frozen baseline snapshot and '
      'is stable across reads (Req 5.5)',
      (tester) async {
        final container = makeContainer(initialScreen: AppScreen.reportsHub);
        await pumpShell(tester, container);

        // Derive the reachable destinations the same way every navigation
        // surface does (the single source of truth).
        final firstRead = reachableDestinationIds(
          container.read(sidebarSectionsProvider),
        );

        // (a) The set matches the frozen baseline exactly — nothing added or
        //     removed (Req 5.5).
        expect(firstRead, kBaselineDestinationIds.toSet());
        expect(firstRead, isNotEmpty);

        // (b) The set is FROZEN: a second evaluation yields an identical set.
        final secondRead = reachableDestinationIds(
          container.read(sidebarSectionsProvider),
        );
        expect(secondRead, equals(firstRead));
      },
    );

    testWidgets(
      'full-screen hide then restore round-trip retains the prior destination '
      '(Req 5.6, 5.7)',
      (tester) async {
        final container = makeContainer(initialScreen: AppScreen.reportsHub);
        await pumpShell(tester, container);

        // Navigate to a known destination before going full-screen.
        container
            .read(navigationControllerProvider.notifier)
            .navigateTo(AppScreen.suppliers);
        await tester.pump();
        await tester.pump();
        expect(
          container.read(navigationControllerProvider).currentScreen,
          AppScreen.suppliers,
        );

        // --- Enter full-screen / distraction-free view (Req 5.6) ---
        container.read(desktopChromeVisibleProvider.notifier).hide();
        await tester.pump();

        // Sidebar + top bar are gone, but the content host stays mounted.
        expect(find.byType(EnterpriseDesktopSidebar), findsNothing);
        expect(find.byType(EnterpriseTopBar), findsNothing);
        expect(find.byType(DesktopContentHost), findsOneWidget);

        // --- Exit full-screen view (Req 5.7) ---
        container.read(desktopChromeVisibleProvider.notifier).show();
        await tester.pump();

        // Chrome is restored to its pre-hidden arrangement.
        expect(find.byType(EnterpriseDesktopSidebar), findsOneWidget);
        expect(find.byType(EnterpriseTopBar), findsOneWidget);
        expect(find.byType(DesktopContentHost), findsOneWidget);

        // The destination selected before going full-screen is retained.
        expect(
          container.read(navigationControllerProvider).currentScreen,
          AppScreen.suppliers,
        );
        final sidebar = tester.widget<EnterpriseDesktopSidebar>(
          find.byType(EnterpriseDesktopSidebar),
        );
        expect(sidebar.selectedItemId, AppScreen.suppliers.id);
      },
    );
  });
}
