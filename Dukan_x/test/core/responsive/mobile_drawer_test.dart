// ============================================================================
// Task 7.5 — WIDGET TEST
// Feature: cross-platform-responsive-ui — Mobile_Drawer behavior
// Requirements: 3.3, 3.5, 3.6
// ============================================================================
// Unit under test:
//   `MobileDrawer` (ConsumerWidget) from
//   `package:dukanx/core/responsive/mobile_drawer.dart`.
//
// The drawer consumes `sidebarSectionsProvider` (the SAME source as the desktop
// sidebar) and the `navigationControllerProvider`. It resolves a tapped
// destination through the pure `DestinationResolver`:
//   - resolved    -> navigate via NavigationController, then close the drawer
//   - unavailable -> keep the drawer open, retain the current screen, show a
//                    SnackBar error indication
//
// Test strategy:
//   * Override `sidebarSectionsProvider` (a plain `Provider`) with a controlled
//     list of sections via `overrideWithValue`, so the whole
//     capability/permission/session graph is bypassed and inputs are
//     deterministic.
//   * Use an `UncontrolledProviderScope` backed by an explicit
//     `ProviderContainer` so the test can read the REAL
//     `navigationControllerProvider` state (`currentScreen`) for assertions.
//   * One section contains `executive_dashboard`, which maps to the default
//     `currentScreen` (AppScreen.executiveDashboard); the drawer auto-expands
//     that section, so its tiles render and are tappable.
//
// Controlled destinations:
//   - 'executive_dashboard' -> AppScreen.executiveDashboard (the current screen)
//   - 'new_sale'            -> AppScreen.newSale            (resolvable)
//   - 'garbage_unknown_xyz' -> AppScreen.unknown            (unresolvable)
//
// Run: flutter test test/core/responsive/mobile_drawer_test.dart
// ============================================================================

import 'package:dukanx/core/navigation/app_screens.dart';
import 'package:dukanx/core/navigation/navigation_controller.dart';
import 'package:dukanx/core/responsive/mobile_drawer.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A single controlled section. It includes the screen that matches the
  // default `currentScreen` (executive_dashboard) so the section auto-expands
  // and all of its tiles are visible and tappable.
  List<SidebarSection> buildSections() => const <SidebarSection>[
    SidebarSection(
      index: 0,
      icon: Icons.space_dashboard_rounded,
      title: 'Main',
      items: <SidebarMenuItem>[
        // Maps to AppScreen.executiveDashboard == the default currentScreen,
        // so its parent section is initially expanded.
        SidebarMenuItem(
          id: 'executive_dashboard',
          icon: Icons.home_outlined,
          label: 'Dashboard Home',
        ),
        // Maps to a known, navigable AppScreen.newSale -> resolvable.
        SidebarMenuItem(
          id: 'new_sale',
          icon: Icons.point_of_sale_outlined,
          label: 'Create Bill',
        ),
        // Garbage id -> AppScreen.fromId == unknown -> unresolvable.
        SidebarMenuItem(
          id: 'garbage_unknown_xyz',
          icon: Icons.error_outline,
          label: 'Broken Destination',
        ),
      ],
    ),
  ];

  /// Pumps a `MobileDrawer` inside a `Scaffold` (drawer slot) wrapped in a
  /// `MaterialApp`, opens the drawer, and settles. Returns the explicit
  /// `ProviderContainer` so the test can read navigation state.
  Future<ProviderContainer> pumpOpenDrawer(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [sidebarSectionsProvider.overrideWithValue(buildSections())],
    );
    addTearDown(container.dispose);

    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            drawer: const MobileDrawer(),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    // Open the navigation drawer and let the open animation finish.
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    return container;
  }

  group('Feature: cross-platform-responsive-ui — Mobile_Drawer behavior', () {
    testWidgets(
      'displays every enabled destination from the active sections (Req 3.3)',
      (tester) async {
        await pumpOpenDrawer(tester);

        // The drawer itself is rendered.
        expect(find.byType(MobileDrawer), findsOneWidget);

        // The section title and each item label are present.
        expect(find.text('Main'), findsOneWidget);
        expect(find.text('Dashboard Home'), findsOneWidget);
        expect(find.text('Create Bill'), findsOneWidget);
        expect(find.text('Broken Destination'), findsOneWidget);
      },
    );

    testWidgets(
      'a resolvable selection navigates and closes the drawer (Req 3.5)',
      (tester) async {
        final container = await pumpOpenDrawer(tester);

        // Sanity: start on the default screen.
        expect(
          container.read(navigationControllerProvider).currentScreen,
          AppScreen.executiveDashboard,
        );

        // Tap a known, navigable destination.
        await tester.tap(find.text('Create Bill'));
        await tester.pumpAndSettle();

        // The drawer closed: its content is no longer in the tree.
        expect(find.byType(MobileDrawer), findsNothing);
        expect(find.text('Create Bill'), findsNothing);

        // Navigation occurred to the resolved screen.
        expect(
          container.read(navigationControllerProvider).currentScreen,
          AppScreen.newSale,
        );
      },
    );

    testWidgets(
      'an unresolvable selection keeps the drawer open, shows an error '
      'indication, and retains the current screen (Req 3.6)',
      (tester) async {
        final container = await pumpOpenDrawer(tester);

        // Tap the garbage destination (maps to AppScreen.unknown).
        await tester.tap(find.text('Broken Destination'));
        // Let the SnackBar animate in (no full settle: SnackBar lingers).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        // An error indication (SnackBar) is shown.
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('unavailable'), findsOneWidget);

        // The drawer stays open: its content is still present.
        expect(find.byType(MobileDrawer), findsOneWidget);
        expect(find.text('Broken Destination'), findsOneWidget);

        // The current screen is unchanged.
        expect(
          container.read(navigationControllerProvider).currentScreen,
          AppScreen.executiveDashboard,
        );
      },
    );
  });
}
