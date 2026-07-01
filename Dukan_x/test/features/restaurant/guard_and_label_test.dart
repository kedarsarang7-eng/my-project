// ============================================================================
// TASK 12.3 — Guard & Label Tests
// Feature: restaurant-vertical-remediation
// **Validates: Requirements 2.23, 2.24**
// ============================================================================
//
// Tests that RestaurantGuard.canAccess correctly rejects invalid business types
// (including the formerly-dead 'hotel' branch) and accepts 'restaurant'. Also
// verifies that sidebar labels match their navigation destinations accurately
// after the Phase 3 relabeling (Task 12.2).
//
// Run: flutter test test/features/restaurant/guard_and_label_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/restaurant/domain/guards/restaurant_guard.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';

void main() {
  group('RestaurantGuard.canAccess (Requirement 2.23)', () {
    test('does not accept "hotel" as a valid type', () {
      expect(RestaurantGuard.canAccess('hotel'), isFalse);
    });

    test('accepts "restaurant" as a valid type', () {
      expect(RestaurantGuard.canAccess('restaurant'), isTrue);
    });

    test('accepts "RESTAURANT" (case-insensitive)', () {
      expect(RestaurantGuard.canAccess('RESTAURANT'), isTrue);
    });

    test('rejects null', () {
      expect(RestaurantGuard.canAccess(null), isFalse);
    });

    test('rejects empty string', () {
      expect(RestaurantGuard.canAccess(''), isFalse);
    });

    test('rejects other business types', () {
      expect(RestaurantGuard.canAccess('grocery'), isFalse);
      expect(RestaurantGuard.canAccess('pharmacy'), isFalse);
      expect(RestaurantGuard.canAccess('clinic'), isFalse);
      expect(RestaurantGuard.canAccess('hardware'), isFalse);
    });
  });

  group('RestaurantGuard.isValidBusinessType (Requirement 2.23)', () {
    test('hotel is not in validBusinessTypes', () {
      expect(RestaurantGuard.isValidBusinessType('hotel'), isFalse);
    });

    test('restaurant is a valid business type', () {
      expect(RestaurantGuard.isValidBusinessType('restaurant'), isTrue);
    });

    test('null is not a valid business type', () {
      expect(RestaurantGuard.isValidBusinessType(null), isFalse);
    });
  });

  group('Sidebar labels match navigation destinations (Requirement 2.24)', () {
    // Access the restaurant sections structurally via the public
    // sidebarSectionsProvider-backing helper. Since _getRestaurantSections()
    // is private, we test via _getSectionsForBusiness(BusinessType.restaurant)
    // which is also private. Instead, we verify the labels structurally by
    // calling the public provider logic through its known type dispatch.
    //
    // The sidebar_configuration.dart exports SidebarSection/SidebarMenuItem as
    // public classes, and the _getSectionsForBusiness dispatches based on
    // BusinessType. We use getSectionsForBusinessType helper to access sections.

    late List<SidebarSection> restaurantSections;

    setUp(() {
      // Access the restaurant sidebar sections via the testable helper.
      // _getSectionsForBusiness is private, but it returns restaurant sections
      // when BusinessType.restaurant is dispatched. We rely on the exported
      // getSectionsForBusinessType test helper if available, otherwise we
      // construct them directly from the provider's source-of-truth.
      restaurantSections = getSectionsForBusinessType(BusinessType.restaurant);
    });

    test('"Stock Dashboard" is used instead of "Ingredients Stock"', () {
      // Find the item with id 'item_stock' in all restaurant sections
      final allItems = restaurantSections.expand((s) => s.items).toList();
      final itemStock = allItems.where((item) => item.id == 'item_stock');

      expect(
        itemStock,
        isNotEmpty,
        reason: 'item_stock sidebar item should exist in restaurant sections',
      );
      expect(
        itemStock.first.label,
        equals('Stock Dashboard'),
        reason:
            'item_stock label should be "Stock Dashboard", not "Ingredients Stock"',
      );
    });

    test('"P&L Report" is used instead of "Profit & Loss"', () {
      // Find the item with id 'invoice_margin' in all restaurant sections
      final allItems = restaurantSections.expand((s) => s.items).toList();
      final pnlItem = allItems.where((item) => item.id == 'invoice_margin');

      expect(
        pnlItem,
        isNotEmpty,
        reason:
            'invoice_margin sidebar item should exist in restaurant sections',
      );
      expect(
        pnlItem.first.label,
        equals('P&L Report'),
        reason:
            'invoice_margin label should be "P&L Report", not "Profit & Loss"',
      );
    });

    test('label "Ingredients Stock" does not appear in restaurant sidebar', () {
      final allLabels = restaurantSections
          .expand((s) => s.items)
          .map((i) => i.label);
      expect(
        allLabels,
        isNot(contains('Ingredients Stock')),
        reason:
            'Old label "Ingredients Stock" should not appear in restaurant sidebar',
      );
    });

    test('"Profit & Loss" does not appear in restaurant sidebar', () {
      final allLabels = restaurantSections
          .expand((s) => s.items)
          .map((i) => i.label);
      expect(
        allLabels,
        isNot(contains('Profit & Loss')),
        reason:
            'Old label "Profit & Loss" should not appear in restaurant sidebar',
      );
    });
  });
}
