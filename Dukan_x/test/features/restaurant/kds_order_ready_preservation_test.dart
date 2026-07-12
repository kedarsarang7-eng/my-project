// ============================================================================
// KDS Order-Ready Status Update — Preservation Test
// Feature: restaurant-audit-fixes (Task 22.2)
// **Validates: Requirements 2.22 (preservation for status update mechanism)**
// ============================================================================
//
// Preservation Goal:
//   After Task 22.3 adds a `RestaurantNotificationService.notifyOrderReady(...)`
//   call into `_markReady`, the core status-update logic must remain intact:
//     1. `_orderRepo.markReady(orderId)` is still called (updates order to READY)
//     2. The SnackBar confirmation is still shown to kitchen staff
//     3. The `mounted` guard protects the UI call
//
//   These three elements are the "status update mechanism" that must survive
//   any notification-service wiring changes.
//
// Approach:
//   Structural source-code analysis of `kitchen_display_screen.dart`:
//   - Parse the `_markReady` method body
//   - Assert the repository call, mounted guard, and SnackBar are present
//
// Run on UNFIXED code — expect PASS (the status update logic works correctly
// today; the bug is only that no notification service call exists).
//
// Run: flutter test test/features/restaurant/kds_order_ready_preservation_test.dart
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String kdsSource;
  late String markReadyBody;

  setUpAll(() {
    final kdsFile = File(
      'lib/features/restaurant/presentation/screens/'
      'kitchen_display_screen.dart',
    );
    expect(
      kdsFile.existsSync(),
      isTrue,
      reason: 'kitchen_display_screen.dart must exist',
    );
    kdsSource = kdsFile.readAsStringSync();

    // Extract the _markReady method body (use full signature to avoid
    // matching the call site `_markReady(order.id)` earlier in the file)
    final markReadyPattern = RegExp(
      r'Future<void>\s+_markReady\(String\s+orderId\)\s*async\s*\{(.*?)\n  \}',
      dotAll: true,
    );
    final match = markReadyPattern.firstMatch(kdsSource);
    expect(
      match,
      isNotNull,
      reason:
          '_markReady async method must exist in kitchen_display_screen.dart',
    );
    markReadyBody = match!.group(1)!;
  });

  group('KDS order-ready status update preservation (Req 2.22 — preservation)', () {
    test('_markReady calls _orderRepo.markReady(orderId) to update status', () {
      // The core status-update mechanism: _orderRepo.markReady(orderId) changes
      // the order status to FoodOrderStatus.ready in the local DB and enqueues
      // a sync operation. This call MUST remain present after notification wiring.
      expect(
        markReadyBody.contains('_orderRepo.markReady(orderId)'),
        isTrue,
        reason:
            '_markReady MUST call _orderRepo.markReady(orderId) to transition '
            'the order status to READY. This is the core status-update mechanism.',
      );
    });

    test('_markReady awaits the repository call (not fire-and-forget)', () {
      // The status update must be awaited so the order is actually persisted
      // before any subsequent UI feedback or notification dispatch.
      expect(
        markReadyBody.contains('await _orderRepo.markReady(orderId)'),
        isTrue,
        reason:
            '_markReady MUST await the repository call to ensure the status '
            'update is persisted before showing UI feedback.',
      );
    });

    test('_markReady shows a SnackBar confirmation to kitchen staff', () {
      // After successfully updating the status, the UI shows a SnackBar
      // confirming the action. This feedback must survive notification wiring.
      expect(
        markReadyBody.contains('SnackBar'),
        isTrue,
        reason:
            '_markReady MUST show a SnackBar confirmation after marking '
            'the order as ready.',
      );

      expect(
        markReadyBody.contains('Order marked ready'),
        isTrue,
        reason:
            'The SnackBar must contain "Order marked ready" text to confirm '
            'the status transition to kitchen staff.',
      );
    });

    test('_markReady guards SnackBar display with mounted check', () {
      // The mounted check prevents showing a SnackBar after the widget has
      // been disposed (e.g., user navigated away during the async operation).
      expect(
        markReadyBody.contains('if (mounted)'),
        isTrue,
        reason:
            '_markReady MUST check `mounted` before showing the SnackBar '
            'to avoid calling setState/ScaffoldMessenger on a disposed widget.',
      );
    });

    test('_markReady repository call precedes SnackBar (correct ordering)', () {
      // The order of operations must be: update status FIRST, then show
      // confirmation. This ensures the UI only confirms a completed action.
      final repoCallIndex = markReadyBody.indexOf('_orderRepo.markReady');
      final snackBarIndex = markReadyBody.indexOf('SnackBar');

      expect(
        repoCallIndex,
        greaterThanOrEqualTo(0),
        reason: '_orderRepo.markReady must exist in the method body',
      );
      expect(
        snackBarIndex,
        greaterThanOrEqualTo(0),
        reason: 'SnackBar must exist in the method body',
      );
      expect(
        repoCallIndex,
        lessThan(snackBarIndex),
        reason:
            '_orderRepo.markReady MUST be called BEFORE the SnackBar is shown. '
            'The status update happens first, then the UI confirms it.',
      );
    });

    test('FoodOrderRepository declares markReady routing to ready status', () {
      // Verify the repository's markReady method routes to FoodOrderStatus.ready.
      // This confirms the full chain: _markReady → _orderRepo.markReady → updateOrderStatus(ready)
      final repoFile = File(
        'lib/features/restaurant/data/repositories/food_order_repository.dart',
      );
      expect(
        repoFile.existsSync(),
        isTrue,
        reason: 'food_order_repository.dart must exist',
      );
      final repoSource = repoFile.readAsStringSync();

      // markReady must delegate to updateOrderStatus with FoodOrderStatus.ready
      expect(
        repoSource.contains('FoodOrderStatus.ready'),
        isTrue,
        reason:
            'food_order_repository.dart must reference FoodOrderStatus.ready '
            'as the target status for markReady.',
      );

      // Confirm markReady method exists
      expect(
        repoSource.contains('markReady'),
        isTrue,
        reason: 'food_order_repository.dart must declare a markReady method.',
      );
    });

    test('KDS screen uses FoodOrderRepository for order operations', () {
      // Confirm the KDS screen instantiates and uses FoodOrderRepository,
      // ensuring the status update goes through the proper data layer.
      expect(
        kdsSource.contains('FoodOrderRepository'),
        isTrue,
        reason:
            'kitchen_display_screen.dart must use FoodOrderRepository for '
            'order status operations.',
      );
      expect(
        kdsSource.contains('_orderRepo'),
        isTrue,
        reason:
            'kitchen_display_screen.dart must declare _orderRepo as the '
            'repository instance used in _markReady.',
      );
    });
  });
}
