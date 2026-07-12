// ============================================================================
// PRESERVATION TEST — expected to PASS on current (unfixed) code.
//
// Task 25.2: Assert that all currently-wired restaurant screens
// (restaurant_tables, kitchen_display, menu_management, daily_summary,
// floor_management, kot_report, recipe_management, delivery_ops,
// restaurant_command_center) continue to resolve correctly.
//
// **Validates: Requirements 3.3, 3.5**
//
// Context:
//   - These 9 screens are ALREADY wired into SidebarNavigationHandler
//   - This test locks in the baseline: after Task 25.3 adds 3 new screens,
//     these existing 9 must remain unaffected.
//   - The exploration test (25.1) Group 4 "Sanity" already covers 3 of these;
//     this test extends coverage to ALL 9.
//
// Run: flutter test test/features/restaurant/restaurant_screen_reachability_preservation_test.dart
// ============================================================================
library;

import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/restaurant/presentation/screens/floor_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/kitchen_display_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/kot_report_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/food_menu_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/recipe_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/restaurant_daily_summary_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/restaurant_delivery_ops_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/restaurant_owner_command_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/table_management_screen.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

/// A real, non-'SYSTEM' tenant id for session resolution.
const String kBusinessId = 'biz_preservation_test_001';

/// Lightweight fake [SessionManager] for sidebar handler's session resolution.
class FakeSessionManager extends Mock implements SessionManager {
  FakeSessionManager(this._businessId);
  final String? _businessId;

  @override
  String? get currentBusinessId => _businessId;

  @override
  String? get userId => _businessId;
}

/// Reads the `vendorId` from a screen widget that declares it as a field.
/// Returns null if the widget doesn't have a vendorId property.
String? _vendorIdOf(Widget? screen) {
  if (screen == null) return null;
  try {
    return (screen as dynamic).vendorId as String?;
  } catch (_) {
    return null;
  }
}

/// The 9 already-wired restaurant screens and their expected widget types.
///
/// Items with vendorId (resolved from SessionManager.currentBusinessId):
///   restaurant_tables, kitchen_display, menu_management, daily_summary,
///   floor_management, kot_report, recipe_management
///
/// Items without vendorId (const constructors):
///   delivery_ops, restaurant_command_center
const Map<String, Type> kWiredScreensWithVendorId = {
  'restaurant_tables': TableManagementScreen,
  'kitchen_display': KitchenDisplayScreen,
  'menu_management': FoodMenuManagementScreen,
  'daily_summary': RestaurantDailySummaryScreen,
  'floor_management': FloorManagementScreen,
  'kot_report': KotReportScreen,
  'recipe_management': RecipeManagementScreen,
};

const Map<String, Type> kWiredScreensWithoutVendorId = {
  'delivery_ops': RestaurantDeliveryOpsScreen,
  'restaurant_command_center': RestaurantOwnerCommandScreen,
};

void main() {
  setUp(() async {
    await GetIt.I.reset();
    GetIt.I.registerSingleton<SessionManager>(FakeSessionManager(kBusinessId));
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  // ===========================================================================
  // GROUP 1: Screens with session-resolved vendorId
  //
  // Each must resolve to the correct widget type with vendorId == kBusinessId.
  // Validates: Requirement 3.3 (GoRouter delivery route unaffected),
  //            Requirement 3.5 (BusinessQuickActions routing unaffected)
  // ===========================================================================
  group(
    'Preservation: wired restaurant screens with vendorId (Req 3.3, 3.5)',
    () {
      for (final entry in kWiredScreensWithVendorId.entries) {
        testWidgets(
          '"${entry.key}" resolves to ${entry.value} with correct vendorId',
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
              entry.key,
              context,
            );

            // 1. Resolves to non-null
            expect(
              screen,
              isNotNull,
              reason:
                  'REGRESSION: "${entry.key}" no longer resolves to a widget. '
                  'This screen was previously wired and must remain reachable '
                  'after new screens are added.',
            );

            // 2. Correct widget type
            expect(
              screen.runtimeType,
              entry.value,
              reason:
                  'REGRESSION: "${entry.key}" resolved to '
                  '${screen.runtimeType} instead of ${entry.value}. '
                  'The widget type must not change when adding new screens.',
            );

            // 3. vendorId is session-resolved (not 'SYSTEM')
            final vendorId = _vendorIdOf(screen);
            expect(
              vendorId,
              isNotNull,
              reason:
                  'REGRESSION: "${entry.key}" resolved with null vendorId. '
                  'Expected session-resolved id "$kBusinessId".',
            );
            expect(
              vendorId,
              kBusinessId,
              reason:
                  'REGRESSION: "${entry.key}" vendorId is "$vendorId" instead '
                  'of the authenticated business id "$kBusinessId". '
                  'Tenant isolation must be preserved.',
            );
          },
        );
      }
    },
  );

  // ===========================================================================
  // GROUP 2: Screens without vendorId (const constructors)
  //
  // Each must resolve to the correct widget type (no vendorId to check).
  // Validates: Requirement 3.3, 3.5
  // ===========================================================================
  group(
    'Preservation: wired restaurant screens without vendorId (Req 3.3, 3.5)',
    () {
      for (final entry in kWiredScreensWithoutVendorId.entries) {
        testWidgets('"${entry.key}" resolves to ${entry.value}', (
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
            entry.key,
            context,
          );

          // 1. Resolves to non-null
          expect(
            screen,
            isNotNull,
            reason:
                'REGRESSION: "${entry.key}" no longer resolves to a widget. '
                'This screen was previously wired and must remain reachable '
                'after new screens are added.',
          );

          // 2. Correct widget type
          expect(
            screen.runtimeType,
            entry.value,
            reason:
                'REGRESSION: "${entry.key}" resolved to '
                '${screen.runtimeType} instead of ${entry.value}. '
                'The widget type must not change when adding new screens.',
          );
        });
      }
    },
  );

  // ===========================================================================
  // GROUP 3: Comprehensive no-crash guarantee for all 9 wired items
  //
  // Single test asserting all 9 resolve without null/crash in a single pump.
  // ===========================================================================
  group(
    'Preservation: all 9 wired restaurant screens resolve (Req 3.3, 3.5)',
    () {
      testWidgets(
        'all 9 already-wired restaurant sidebar items resolve to non-null widgets',
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

          final allWiredItems = [
            ...kWiredScreensWithVendorId.keys,
            ...kWiredScreensWithoutVendorId.keys,
          ];

          for (final itemId in allWiredItems) {
            final screen = SidebarNavigationHandler.tryGetScreenForItem(
              itemId,
              context,
            );
            expect(
              screen,
              isNotNull,
              reason:
                  'REGRESSION: "$itemId" resolved to null — this screen was '
                  'previously wired and navigable. Adding new screens must '
                  'not break existing ones.',
            );
          }
        },
      );
    },
  );
}
