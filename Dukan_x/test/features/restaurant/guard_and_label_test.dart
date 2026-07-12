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
// ============================================================================
// TASK 13 — Regression-Lock PBT: RestaurantGuard is a total function with
// no 'hotel' special case (Property 21).
// Feature: restaurant-audit-fixes
// **Validates: Requirements 2.27, 3.18**
// ============================================================================
//
// PBT: for randomized business-type-like strings (including all BusinessType
// enum values, 'hotel', mixed case, null, empty), RestaurantGuard.canAccess(input)
// returns true iff input?.toLowerCase() == 'restaurant'; specifically false for
// 'hotel'. Also covers Preservation 3.18 — assert 'restaurant' (any case) still
// grants access.
//
// Run: flutter test test/features/restaurant/guard_and_label_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
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

  // ==========================================================================
  // Property 21 (Regression Lock): RestaurantGuard Is a Total Function With
  // No 'hotel' Special Case
  // **Validates: Requirements 2.27, 3.18**
  // ==========================================================================
  group('Property 21: RestaurantGuard.canAccess is a total function (PBT)', () {
    // -----------------------------------------------------------------------
    // Generator: produces a nullable String? from a diverse pool covering:
    //   - All BusinessType enum .name values (lowercase enum identifiers)
    //   - 'hotel' (the specifically-rejected value)
    //   - Mixed-case variants of 'restaurant' and 'hotel'
    //   - null, empty string, whitespace, arbitrary fuzz strings
    // -----------------------------------------------------------------------

    /// All BusinessType enum names as lowercase strings.
    final List<String> enumNames = BusinessType.values
        .map((bt) => bt.name)
        .toList();

    /// Pool of interesting string values to test against canAccess.
    final List<String> stringPool = <String>[
      ...enumNames, // grocery, pharmacy, restaurant, clothing, ...
      'hotel', // specific rejection target
      'Hotel', // mixed case hotel
      'HOTEL', // uppercase hotel
      'Restaurant', // capitalized
      'RESTAURANT', // uppercase
      'rEstAuRaNt', // random case restaurant
      'hOtEl', // random case hotel
      '', // empty
      ' ', // whitespace
      '  restaurant  ', // with surrounding whitespace
      'restaurant ', // trailing space
      ' restaurant', // leading space
      'restaurants', // plural (should reject)
      'rest', // prefix (should reject)
      'hotel_restaurant', // compound (should reject)
      'foo', // arbitrary
      'bar', // arbitrary
      '123', // numeric
      'null', // the literal word 'null'
      'undefined', // fuzz
    ];

    /// Generator for nullable String? — 0 means null, 1+ picks from pool.
    final Generator<String?> inputGen = Gen.interval(
      0,
      stringPool.length,
    ).map((idx) => (idx as int) == 0 ? null : stringPool[idx - 1]);

    const int kNumRuns = 200;

    test('canAccess returns true iff input?.toLowerCase() == "restaurant"', () {
      final bool held = forAll(
        (String? input) {
          final bool actual = RestaurantGuard.canAccess(input);
          final bool expected = input?.toLowerCase() == 'restaurant';
          return actual == expected;
        },
        [inputGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('canAccess specifically rejects "hotel" (all case variants)', () {
      // Deterministic exhaustive check for hotel variants
      final hotelVariants = ['hotel', 'Hotel', 'HOTEL', 'hOtEl', 'HoTeL'];
      for (final variant in hotelVariants) {
        expect(
          RestaurantGuard.canAccess(variant),
          isFalse,
          reason: 'canAccess("$variant") must be false — no hotel special case',
        );
      }
    });

    test('Preservation 3.18: "restaurant" (any case) still grants access', () {
      final restaurantVariants = [
        'restaurant',
        'Restaurant',
        'RESTAURANT',
        'rEstAuRaNt',
        'reSTAUrant',
      ];
      for (final variant in restaurantVariants) {
        expect(
          RestaurantGuard.canAccess(variant),
          isTrue,
          reason: 'canAccess("$variant") must be true — Preservation 3.18',
        );
      }
    });

    test('canAccess rejects null and empty inputs', () {
      expect(RestaurantGuard.canAccess(null), isFalse);
      expect(RestaurantGuard.canAccess(''), isFalse);
      expect(RestaurantGuard.canAccess(' '), isFalse);
    });

    test('canAccess rejects all non-restaurant BusinessType enum values', () {
      for (final bt in BusinessType.values) {
        if (bt == BusinessType.restaurant) continue;
        expect(
          RestaurantGuard.canAccess(bt.name),
          isFalse,
          reason: 'canAccess("${bt.name}") must be false',
        );
      }
    });
  });
}
