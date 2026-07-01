// ============================================================================
// TASK 7.3 — OrderType Unit Tests
// Feature: restaurant-vertical-remediation
// **Validates: Requirements 2.13, 3.4**
// ============================================================================
//
// Tests that the OrderType enum correctly parses all 4 supported string values
// (including the newly added 'DELIVERY' and 'PARCEL'), preserves existing
// behavior for 'DINE_IN' and 'TAKEAWAY', and falls back to dineIn for invalid
// inputs.
//
// Run: flutter test test/features/restaurant/order_type_test.dart
// ============================================================================

import 'package:dukanx/features/restaurant/data/models/food_order_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderType', () {
    group('fromString — new enum values (Requirement 2.13)', () {
      test('fromString("DELIVERY") returns OrderType.delivery', () {
        expect(OrderType.fromString('DELIVERY'), equals(OrderType.delivery));
      });

      test('fromString("PARCEL") returns OrderType.parcel', () {
        expect(OrderType.fromString('PARCEL'), equals(OrderType.parcel));
      });
    });

    group('fromString — preserved existing behavior (Requirement 3.4)', () {
      test('fromString("DINE_IN") still returns OrderType.dineIn', () {
        expect(OrderType.fromString('DINE_IN'), equals(OrderType.dineIn));
      });

      test('fromString("TAKEAWAY") still returns OrderType.takeaway', () {
        expect(OrderType.fromString('TAKEAWAY'), equals(OrderType.takeaway));
      });

      test('fromString("INVALID") falls back to OrderType.dineIn', () {
        expect(OrderType.fromString('INVALID'), equals(OrderType.dineIn));
      });
    });

    group('enum completeness (Requirement 2.13)', () {
      test('OrderType.values.length == 4', () {
        expect(OrderType.values.length, equals(4));
      });
    });
  });
}
