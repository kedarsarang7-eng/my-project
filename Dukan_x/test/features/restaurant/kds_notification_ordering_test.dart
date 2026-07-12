// ============================================================================
// KDS Notification Ordering — Bug Condition Exploration Test
// Feature: restaurant-audit-fixes (Task 22.1)
// **Validates: Requirements 2.22**
// ============================================================================
//
// Bug Condition (from design.md):
//   When kitchen staff mark an order as ready, a "Customer notified!" SnackBar
//   is shown, but `restaurant_notification_service.dart` is never actually
//   invoked. No real customer notification is sent despite the UI implying one
//   was.
//
// Approach:
//   Structural source-code analysis of `kitchen_display_screen.dart`:
//   1. Find the `_markReady` method
//   2. Assert it calls `RestaurantNotificationService` or `notifyOrderReady`
//      — this FAILS today (only a TODO comment exists)
//   3. Verify the SnackBar IS present (confirming the UI claims an action was
//      taken)
//   4. The combination proves: UI shows a confirmation but no actual
//      notification service call exists
//
// Run on UNFIXED code — expect FAILURE (the notification service is never
// actually called from _markReady).
//
// Run: flutter test test/features/restaurant/kds_notification_ordering_test.dart
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String kdsSource;

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
  });

  group('KDS notification ordering (Req 2.22)', () {
    test('_markReady method exists', () {
      expect(
        kdsSource.contains('_markReady'),
        isTrue,
        reason: '_markReady method must exist',
      );
    });

    test('_markReady shows a SnackBar (UI claims action taken)', () {
      // Extract the _markReady method body to confirm it shows a SnackBar.
      final markReadyPattern = RegExp(
        r'Future<void>\s+_markReady\(String\s+orderId\)\s*async\s*\{(.*?)\n  \}',
        dotAll: true,
      );
      final match = markReadyPattern.firstMatch(kdsSource);
      expect(
        match,
        isNotNull,
        reason: '_markReady async method must exist with a body',
      );

      final methodBody = match!.group(1)!;
      expect(
        methodBody.contains('SnackBar'),
        isTrue,
        reason: '_markReady must show a SnackBar',
      );
    });

    test('_markReady calls notifyOrderReady before SnackBar', () {
      // Critical assertion: _markReady MUST call notifyOrderReady before
      // the SnackBar is shown.
      //
      // On UNFIXED code this FAILS — only a TODO comment exists.

      final markReadyPattern = RegExp(
        r'Future<void>\s+_markReady\(String\s+orderId\)\s*async\s*\{(.*?)\n  \}',
        dotAll: true,
      );
      final match = markReadyPattern.firstMatch(kdsSource);
      expect(match, isNotNull, reason: '_markReady must be found');

      final methodBody = match!.group(1)!;

      // Check that notifyOrderReady is actually called (not commented out)
      final hasNotifyCall = RegExp(
        r'(?<!//\s*)(?<!//.*?)notifyOrderReady',
      ).hasMatch(methodBody);

      expect(
        hasNotifyCall,
        isTrue,
        reason:
            '_markReady MUST call notifyOrderReady. Currently only a TODO '
            'comment exists — no real notification is dispatched.',
      );

      // Additionally verify the call appears BEFORE the SnackBar
      if (hasNotifyCall) {
        final notifyIndex = methodBody.indexOf('notifyOrderReady');
        final snackBarIndex = methodBody.indexOf('SnackBar');
        expect(
          notifyIndex,
          lessThan(snackBarIndex),
          reason: 'notifyOrderReady must precede the SnackBar',
        );
      }
    });

    test('source imports RestaurantNotificationService', () {
      // The source file must import or reference the notification service
      // for the notification call to be real.
      final hasServiceRef =
          kdsSource.contains('RestaurantNotificationService') ||
          kdsSource.contains('restaurant_notification_service');

      expect(
        hasServiceRef,
        isTrue,
        reason:
            'kitchen_display_screen.dart must import '
            'RestaurantNotificationService. Currently no such '
            'reference exists.',
      );
    });
  });
}
