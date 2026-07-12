// ============================================================================
// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Bug Condition (Property 22): Every Declared Restaurant Screen Is Reachable
// From a Single Navigation System
//
// **Validates: Requirements 2.4, 2.6**
//
// Context:
//   - The restaurant vertical has ~14 screens under
//     lib/features/restaurant/presentation/screens/
//   - Only 9 of these are wired into SidebarNavigationHandler.tryGetScreenForItem()
//     or the sidebar configuration (_getRestaurantSections)
//   - At least 3 built screens are PERMANENTLY UNREACHABLE in the running app:
//       1. RestaurantInventoryScreen (restaurant_inventory_screen.dart)
//       2. RestaurantPricingAdminScreen (restaurant_pricing_admin_screen.dart)
//       3. RestaurantTableOpsScreen (restaurant_table_ops_screen.dart)
//   - These screens exist as fully-implemented StatefulWidgets with real
//     repository bindings, but no navigation path resolves to them.
//
// This test asserts the CORRECT behavior (these screens SHOULD be reachable
// through the sidebar navigation handler). On UNFIXED code this FAILS because:
//   1. No sidebar item id maps to these screens in SidebarNavigationHandler
//   2. No entry in _getRestaurantSections references these screen ids
//   3. The screens are built but permanently orphaned
//
// COUNTEREXAMPLE (documented after first run):
//   SidebarNavigationHandler.tryGetScreenForItem returns null for
//   'restaurant_inventory', 'pricing_admin', and 'table_ops' — these
//   screens exist in the filesystem but are unreachable from any
//   navigation path in the running app.
//
// Run: flutter test test/features/restaurant/restaurant_screen_reachability_exploration_test.dart
// ============================================================================
library;

import 'dart:io';

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

/// A real, non-'SYSTEM' tenant id for session resolution.
const String kBusinessId = 'biz_test_restaurant_789';

/// Lightweight fake [SessionManager] for the sidebar handler's session resolution.
class FakeSessionManager extends Mock implements SessionManager {
  FakeSessionManager(this._businessId);
  final String? _businessId;

  @override
  String? get currentBusinessId => _businessId;

  @override
  String? get userId => _businessId;
}

/// The 3 restaurant screens that exist in the filesystem but are NOT wired
/// into the sidebar navigation handler — these are the key unreachable screens.
const Map<String, String> kUnreachableScreens = {
  'restaurant_inventory':
      'lib/features/restaurant/presentation/screens/restaurant_inventory_screen.dart',
  'pricing_admin':
      'lib/features/restaurant/presentation/screens/restaurant_pricing_admin_screen.dart',
  'table_ops':
      'lib/features/restaurant/presentation/screens/restaurant_table_ops_screen.dart',
};

/// Sidebar item ids that ARE currently wired (for comparison/validation).
const List<String> kWiredRestaurantItems = [
  'restaurant_tables',
  'kitchen_display',
  'menu_management',
  'daily_summary',
  'floor_management',
  'kot_report',
  'recipe_management',
  'delivery_ops',
  'restaurant_command_center',
];

/// The sidebar navigation handler source file.
const String kSidebarHandlerPath =
    'lib/widgets/desktop/sidebar_navigation_handler.dart';

/// The sidebar configuration source file.
const String kSidebarConfigPath =
    'lib/widgets/desktop/sidebar_configuration.dart';

void main() {
  late String sidebarHandlerSource;
  late String sidebarConfigSource;

  setUpAll(() {
    final handlerFile = File(kSidebarHandlerPath);
    expect(
      handlerFile.existsSync(),
      isTrue,
      reason: 'sidebar_navigation_handler.dart must exist',
    );
    sidebarHandlerSource = handlerFile.readAsStringSync();

    final configFile = File(kSidebarConfigPath);
    expect(
      configFile.existsSync(),
      isTrue,
      reason: 'sidebar_configuration.dart must exist',
    );
    sidebarConfigSource = configFile.readAsStringSync();
  });

  setUp(() async {
    await GetIt.I.reset();
    GetIt.I.registerSingleton<SessionManager>(FakeSessionManager(kBusinessId));
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  // ===========================================================================
  // GROUP 1: Structural assertion — screen files EXIST but their ids are absent
  //          from the sidebar handler switch-case and configuration.
  //
  // On UNFIXED code: FAILS — these screens are NOT reachable.
  // ===========================================================================
  group('Property 22: Unreachable restaurant screens (Req 2.4, 2.6)', () {
    test('screen files exist in the filesystem (precondition)', () {
      for (final entry in kUnreachableScreens.entries) {
        final file = File(entry.value);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Screen file for "${entry.key}" must exist at ${entry.value}',
        );
      }
    });

    for (final entry in kUnreachableScreens.entries) {
      final screenId = entry.key;

      test('"$screenId" is wired into sidebar_navigation_handler.dart', () {
        // The sidebar handler should have a case for this screen id
        final hasCase =
            sidebarHandlerSource.contains("case '$screenId'") ||
            sidebarHandlerSource.contains('case "$screenId"');

        expect(
          hasCase,
          isTrue,
          reason:
              'COUNTEREXAMPLE (Property 22, Req 2.6): '
              'sidebar_navigation_handler.dart has NO case for '
              '"$screenId".\n\n'
              'The screen file EXISTS at:\n'
              '  ${entry.value}\n'
              'but SidebarNavigationHandler.tryGetScreenForItem("$screenId") '
              'returns null — this screen is permanently unreachable.\n\n'
              'Expected: a case \'$screenId\' entry resolves to the '
              'corresponding screen widget.',
        );
      });

      test('"$screenId" has a sidebar menu item in _getRestaurantSections', () {
        final hasMenuItem =
            sidebarConfigSource.contains("id: '$screenId'") ||
            sidebarConfigSource.contains('id: "$screenId"');

        expect(
          hasMenuItem,
          isTrue,
          reason:
              'COUNTEREXAMPLE (Property 22, Req 2.4): '
              'sidebar_configuration.dart\'s _getRestaurantSections() has '
              'NO SidebarMenuItem with id "$screenId".\n\n'
              'The screen exists in the filesystem but is not discoverable '
              'through the sidebar navigation. A restaurant owner cannot '
              'find or navigate to this screen.\n\n'
              'Expected: a SidebarMenuItem(id: \'$screenId\', ...) entry '
              'in _getRestaurantSections().',
        );
      });
    }
  });

  // ===========================================================================
  // GROUP 2: Runtime resolution — tryGetScreenForItem returns null for these ids.
  //
  // On UNFIXED code: FAILS — returns null (no screen resolved).
  // ===========================================================================
  group(
    'Property 22: Runtime reachability via tryGetScreenForItem (Req 2.6)',
    () {
      for (final screenId in kUnreachableScreens.keys) {
        testWidgets(
          'tryGetScreenForItem("$screenId") resolves to a non-null widget',
          (tester) async {
            late BuildContext context;
            await tester.pumpWidget(
              MaterialApp(
                home: Builder(
                  builder: (ctx) {
                    context = ctx;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            );

            final screen = SidebarNavigationHandler.tryGetScreenForItem(
              screenId,
              context,
            );

            expect(
              screen,
              isNotNull,
              reason:
                  'COUNTEREXAMPLE (Property 22, Req 2.6): '
                  'SidebarNavigationHandler.tryGetScreenForItem("$screenId", '
                  'context) returned NULL.\n\n'
                  'The screen widget exists in the codebase but no navigation '
                  'path resolves to it — it is permanently unreachable.\n\n'
                  'Expected: returns a non-null Widget (the corresponding '
                  'restaurant screen).',
            );
          },
        );
      }
    },
  );

  // ===========================================================================
  // GROUP 3: PBT — for any screen id drawn from the unreachable set, the
  //          sidebar handler source must contain a matching case entry AND
  //          the sidebar config must declare a menu item with that id.
  //
  // On UNFIXED code: FAILS — structural invariant not satisfied.
  // ===========================================================================
  group('PBT: Every declared restaurant screen is reachable (Property 22)', () {
    test('PBT: for any unreachable screen id, navigation handler has a case', () {
      final screenIds = kUnreachableScreens.keys.toList();

      final held = forAll(
        (int idx) {
          final screenId = screenIds[idx % screenIds.length];
          // The sidebar handler must have a case for this screen id
          return sidebarHandlerSource.contains("case '$screenId'") ||
              sidebarHandlerSource.contains('case "$screenId"');
        },
        [Gen.interval(0, screenIds.length - 1)],
        numRuns: 30,
      );

      expect(
        held,
        isTrue,
        reason:
            'COUNTEREXAMPLE (PBT, Property 22, Req 2.6): '
            'For at least one screen id in {${kUnreachableScreens.keys.join(', ')}}, '
            'sidebar_navigation_handler.dart has NO matching case.\n\n'
            'These screens exist in the codebase under:\n'
            '  lib/features/restaurant/presentation/screens/\n'
            'but are silently absent from both the sidebar navigation '
            'handler and the sidebar configuration.\n\n'
            'Expected: every declared restaurant screen has a case in '
            'the handler AND a SidebarMenuItem in the configuration.',
      );
    });

    test(
      'PBT: for any unreachable screen id, sidebar config declares a menu item',
      () {
        final screenIds = kUnreachableScreens.keys.toList();

        final held = forAll(
          (int idx) {
            final screenId = screenIds[idx % screenIds.length];
            return sidebarConfigSource.contains("id: '$screenId'") ||
                sidebarConfigSource.contains('id: "$screenId"');
          },
          [Gen.interval(0, screenIds.length - 1)],
          numRuns: 30,
        );

        expect(
          held,
          isTrue,
          reason:
              'COUNTEREXAMPLE (PBT, Property 22, Req 2.4): '
              'For at least one screen id in {${kUnreachableScreens.keys.join(', ')}}, '
              'sidebar_configuration.dart\'s _getRestaurantSections() has NO '
              'SidebarMenuItem entry.\n\n'
              'The screens are built but not discoverable in the navigation '
              'system — a restaurant owner cannot find them.\n\n'
              'Expected: each screen id appears as a SidebarMenuItem in the '
              'restaurant sidebar configuration.',
        );
      },
    );
  });

  // ===========================================================================
  // GROUP 4: Sanity check — currently wired screens DO resolve (validates
  //          test methodology is correct, not a false positive).
  //
  // On UNFIXED code: PASSES — confirms our test approach is valid.
  // ===========================================================================
  group('Sanity: currently wired restaurant screens resolve correctly', () {
    for (final itemId in [
      'restaurant_tables',
      'kitchen_display',
      'menu_management',
    ]) {
      testWidgets('"$itemId" resolves to non-null (baseline sanity)', (
        tester,
      ) async {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) {
                context = ctx;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final screen = SidebarNavigationHandler.tryGetScreenForItem(
          itemId,
          context,
        );

        expect(
          screen,
          isNotNull,
          reason:
              '"$itemId" is a known wired item and should resolve to a '
              'non-null widget. If this fails, test setup is broken.',
        );
      });
    }
  });
}
