// ============================================================================
// TASK 5.3 — NAVIGATION TESTS FOR NEWLY-WIRED SCREENS
// Feature: restaurant-vertical-remediation
// Phase 1B — Orphaned Screen Navigation
// **Validates: Requirements 2.6, 3.6**
// ============================================================================
//
// Verifies that each of the 5 new sidebar items added in task 5.2 resolves to
// the correct screen widget type via SidebarNavigationHandler.tryGetScreenForItem.
//
// For items with vendorId (floor_management, kot_report, recipe_management):
//   - Assert the returned widget is the correct type
//   - Assert vendorId == SessionManager.currentBusinessId (not 'SYSTEM')
//
// For items without vendorId (delivery_ops, restaurant_command_center):
//   - Assert the returned widget is the correct type
//
// Also verifies no crash (widget resolves to non-null) for each item.
//
// Run: flutter test test/features/restaurant/restaurant_navigation_test.dart
// ============================================================================

import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/restaurant/presentation/screens/floor_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/kot_report_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/recipe_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/restaurant_delivery_ops_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/restaurant_owner_command_screen.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

/// A real, non-'SYSTEM' tenant id for session resolution.
const String kBusinessId = 'usr_pizza_palace_123';

/// Lightweight fake [SessionManager] — provides currentBusinessId for the
/// sidebar handler's session-resolved vendorId pattern.
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

void main() {
  setUp(() async {
    await GetIt.I.reset();
    GetIt.I.registerSingleton<SessionManager>(FakeSessionManager(kBusinessId));
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  group('Phase 1B — Orphaned Screen Navigation (Task 5.3)', () {
    // ------------------------------------------------------------------
    // Items WITH vendorId: floor_management, kot_report, recipe_management
    // ------------------------------------------------------------------

    group('Items with session-resolved vendorId', () {
      const itemsWithVendorId = <String, Type>{
        'floor_management': FloorManagementScreen,
        'kot_report': KotReportScreen,
        'recipe_management': RecipeManagementScreen,
      };

      for (final entry in itemsWithVendorId.entries) {
        testWidgets(
          '"${entry.key}" resolves to ${entry.value} with vendorId == currentBusinessId',
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

            // 1. Resolves to non-null (no crash)
            expect(
              screen,
              isNotNull,
              reason:
                  '"${entry.key}" should resolve to a widget, not null. '
                  'Navigation to this orphaned screen would crash.',
            );

            // 2. Correct widget type
            expect(
              screen.runtimeType,
              entry.value,
              reason:
                  '"${entry.key}" should resolve to ${entry.value}, '
                  'got ${screen.runtimeType}.',
            );

            // 3. vendorId is session-resolved (not 'SYSTEM')
            final vendorId = _vendorIdOf(screen);
            expect(
              vendorId,
              isNot('SYSTEM'),
              reason:
                  '"${entry.key}" resolved with vendorId "SYSTEM" — '
                  'tenant isolation breach.',
            );
            expect(
              vendorId,
              kBusinessId,
              reason:
                  '"${entry.key}" vendorId should be the authenticated '
                  'tenant ($kBusinessId), got "$vendorId".',
            );
          },
        );
      }
    });

    // ------------------------------------------------------------------
    // Items WITHOUT vendorId: delivery_ops, restaurant_command_center
    // ------------------------------------------------------------------

    group('Items without vendorId (type-only verification)', () {
      const itemsWithoutVendorId = <String, Type>{
        'delivery_ops': RestaurantDeliveryOpsScreen,
        'restaurant_command_center': RestaurantOwnerCommandScreen,
      };

      for (final entry in itemsWithoutVendorId.entries) {
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

          // 1. Resolves to non-null (no crash)
          expect(
            screen,
            isNotNull,
            reason:
                '"${entry.key}" should resolve to a widget, not null. '
                'Navigation to this orphaned screen would crash.',
          );

          // 2. Correct widget type
          expect(
            screen.runtimeType,
            entry.value,
            reason:
                '"${entry.key}" should resolve to ${entry.value}, '
                'got ${screen.runtimeType}.',
          );
        });
      }
    });

    // ------------------------------------------------------------------
    // Comprehensive: all 5 items resolve without crash
    // ------------------------------------------------------------------

    group('No-crash guarantee for all new items', () {
      const allNewItems = <String>[
        'floor_management',
        'kot_report',
        'recipe_management',
        'delivery_ops',
        'restaurant_command_center',
      ];

      testWidgets(
        'all 5 new sidebar items resolve to non-null widgets (no crash)',
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

          for (final itemId in allNewItems) {
            final screen = SidebarNavigationHandler.tryGetScreenForItem(
              itemId,
              context,
            );
            expect(
              screen,
              isNotNull,
              reason:
                  '"$itemId" resolved to null — navigation would show a '
                  'placeholder or crash instead of the orphaned screen.',
            );
          }
        },
      );
    });
  });
}
