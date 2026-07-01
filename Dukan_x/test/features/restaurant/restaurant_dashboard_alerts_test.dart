// ============================================================================
// Task 4.3 — INTEGRATION TEST: Dashboard Live Data
// Feature: restaurant-vertical-remediation
// **Validates: Requirements 2.5, 3.2**
// ============================================================================
//
// Verifies:
//   1. `BusinessAlertsWidget` with `businessType == restaurant` displays
//      dynamic values from the `restaurantAlertCountsProvider` (not hardcoded).
//   2. Counts update when order statuses change (stream emits new values).
//   3. Other business types' alert widgets remain unchanged (grocery still
//      reads from alertCountsProvider, not restaurantAlertCountsProvider).
//
// Testing approach:
//   - Override `restaurantAlertCountsProvider` with controlled stream values.
//   - Override `businessTypeProvider` to pin the restaurant branch.
//   - Override `alertCountsProvider` with an already-resolved empty map so the
//     service-locator-backed provider body never runs.
//   - Assert rendered count texts match supplied values.
//   - For the "counts update" test, use a StreamController to emit new values
//     and verify the widget rebuilds with the updated counts.
//   - For preservation, override to grocery and verify its own provider drives
//     the displayed counts.
//
// Run: flutter test test/features/restaurant/restaurant_dashboard_alerts_test.dart
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukanx/features/dashboard/v2/widgets/business_alerts_widget.dart';
import 'package:dukanx/features/restaurant/providers/restaurant_alert_counts_provider.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Pins the business type to restaurant.
class _RestaurantBusinessTypeNotifier extends BusinessTypeNotifier {
  @override
  BusinessTypeState build() => BusinessTypeState(type: BusinessType.restaurant);
}

/// Pins the business type to grocery.
class _GroceryBusinessTypeNotifier extends BusinessTypeNotifier {
  @override
  BusinessTypeState build() => BusinessTypeState(type: BusinessType.grocery);
}

/// Pumps the [BusinessAlertsWidget] with [businessType] pinned to restaurant
/// and [restaurantAlertCountsProvider] overridden with a stream returning
/// [counts]. [alertCountsProvider] is overridden with an empty map so its
/// service-locator-backed body never executes.
Future<void> pumpRestaurantAlerts(
  WidgetTester tester, {
  required RestaurantAlertCounts counts,
}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues(<String, Object>{});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessTypeProvider.overrideWith(
          () => _RestaurantBusinessTypeNotifier(),
        ),
        alertCountsProvider.overrideWithValue(
          const AsyncValue<Map<String, int>>.data(<String, int>{}),
        ),
        restaurantAlertCountsProvider.overrideWithValue(
          AsyncValue<RestaurantAlertCounts>.data(counts),
        ),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SingleChildScrollView(child: BusinessAlertsWidget()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature: restaurant-vertical-remediation — restaurant dashboard '
      'alert cards render live provider counts (R2.5)', () {
    testWidgets('displays dynamic values from restaurantAlertCountsProvider', (
      tester,
    ) async {
      await pumpRestaurantAlerts(
        tester,
        counts: const RestaurantAlertCounts(
          activeOrders: 3,
          kitchenQueue: 5,
          lowIngredients: 2,
        ),
      );

      // The restaurant branch renders count via _displayCount → plain string.
      // Verify the rendered counts match the supplied values.
      expect(find.text('3'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Confirm old hardcoded values are NOT present.
      expect(find.text('7'), findsNothing);
      expect(find.text('12'), findsNothing);
      expect(find.text('4'), findsNothing);
    });

    testWidgets(
      'renders a second distinct set of values (proves not hardcoded)',
      (tester) async {
        await pumpRestaurantAlerts(
          tester,
          counts: const RestaurantAlertCounts(
            activeOrders: 19,
            kitchenQueue: 8,
            lowIngredients: 0,
          ),
        );

        expect(find.text('19'), findsOneWidget);
        expect(find.text('8'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);

        // Confirm first set's values are not present.
        expect(find.text('3'), findsNothing);
        expect(find.text('5'), findsNothing);
      },
    );

    testWidgets(
      'counts update when restaurantAlertCountsProvider emits new values',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues(<String, Object>{});

        // Use a StreamController to emit multiple values.
        final controller = StreamController<RestaurantAlertCounts>();
        addTearDown(controller.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessTypeProvider.overrideWith(
                () => _RestaurantBusinessTypeNotifier(),
              ),
              alertCountsProvider.overrideWithValue(
                const AsyncValue<Map<String, int>>.data(<String, int>{}),
              ),
              restaurantAlertCountsProvider.overrideWith(
                (ref) => controller.stream,
              ),
            ],
            child: const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: SingleChildScrollView(child: BusinessAlertsWidget()),
              ),
            ),
          ),
        );
        await tester.pump();

        // Before any emission, widget should show '...' (loading state).
        expect(find.text('...'), findsWidgets);

        // Emit first set of counts.
        controller.add(
          const RestaurantAlertCounts(
            activeOrders: 10,
            kitchenQueue: 6,
            lowIngredients: 1,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('10'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);

        // Emit updated counts (simulating order status changes).
        controller.add(
          const RestaurantAlertCounts(
            activeOrders: 15,
            kitchenQueue: 3,
            lowIngredients: 4,
          ),
        );
        await tester.pump();
        await tester.pump();

        // Old values gone, new values present.
        expect(find.text('10'), findsNothing);
        expect(find.text('6'), findsNothing);
        expect(find.text('15'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
      },
    );

    testWidgets('shows "..." while restaurantAlertCountsProvider is loading', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues(<String, Object>{});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessTypeProvider.overrideWith(
              () => _RestaurantBusinessTypeNotifier(),
            ),
            alertCountsProvider.overrideWithValue(
              const AsyncValue<Map<String, int>>.data(<String, int>{}),
            ),
            // Override with loading state.
            restaurantAlertCountsProvider.overrideWithValue(
              const AsyncValue<RestaurantAlertCounts>.loading(),
            ),
          ],
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: SingleChildScrollView(child: BusinessAlertsWidget()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // When restaurantCounts is null (loading/orElse), widget renders '...'.
      expect(find.text('...'), findsWidgets);
    });
  });

  group('Feature: restaurant-vertical-remediation — other business types '
      'alert widgets remain unchanged (R3.2)', () {
    testWidgets(
      'grocery alerts use alertCountsProvider, not restaurantAlertCountsProvider',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues(<String, Object>{});

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessTypeProvider.overrideWith(
                () => _GroceryBusinessTypeNotifier(),
              ),
              // Grocery branch reads lowStock/expiringSoon from this provider.
              alertCountsProvider.overrideWithValue(
                const AsyncValue<Map<String, int>>.data(<String, int>{
                  'lowStock': 11,
                  'expiringSoon': 6,
                }),
              ),
              // Restaurant provider override should have NO effect on grocery.
              restaurantAlertCountsProvider.overrideWithValue(
                const AsyncValue<RestaurantAlertCounts>.data(
                  RestaurantAlertCounts(
                    activeOrders: 99,
                    kitchenQueue: 88,
                    lowIngredients: 77,
                  ),
                ),
              ),
            ],
            child: const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: SingleChildScrollView(child: BusinessAlertsWidget()),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Grocery displays its own counts from alertCountsProvider.
        expect(find.text('11'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);

        // Grocery does NOT display restaurant provider values.
        expect(find.text('99'), findsNothing);
        expect(find.text('88'), findsNothing);
        expect(find.text('77'), findsNothing);

        // Title should be grocery-specific.
        expect(find.text('Expiry & Stock Alerts'), findsOneWidget);
        expect(find.text('Kitchen & Order Status'), findsNothing);
      },
    );
  });
}
