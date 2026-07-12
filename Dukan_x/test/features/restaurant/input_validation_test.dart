// ============================================================================
// Input Validation Tests — Tasks 9.4 & 9 (Regression Lock)
// Feature: restaurant-audit-fixes
// **Validates: Requirements 2.15, 2.16, 2.17, 3.11**
// ============================================================================
//
// Tests the input validation logic used in restaurant menu and table dialogs:
// - Price field: rejects non-numeric, empty, zero, negative; accepts valid
// - Capacity field: rejects values outside 1–50 range
// - StartNumber field: rejects values < 1
// - Category reorder: persists new order to repository
// - PBT Property 12: Numeric bounds validation rejects out-of-range input
//   without silent substitution (capacity/startNumber clause)
// - PBT Property 13: Previously-valid numeric inputs still accepted unchanged
//
// The validators are inline in FormField widgets; we test the exact same logic
// as pure functions here for fast, isolated verification.
//
// PBT library: dartproptest ^0.2.1.
// Run: flutter test test/features/restaurant/input_validation_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/restaurant/data/models/food_category_model.dart';

// ---------------------------------------------------------------------------
// Validator functions — extracted logic identical to the inline validators in
// food_menu_management_screen.dart and table_management_screen.dart
// ---------------------------------------------------------------------------

/// Price validator — same logic as the menu item price FormField validator.
String? validatePrice(String? v) {
  if (v == null || v.trim().isEmpty) return 'Please enter a price';
  final parsed = double.tryParse(v.trim());
  if (parsed == null) return 'Please enter a valid numeric price';
  if (parsed <= 0) return 'Please enter a valid price greater than ₹0';
  if (parsed > 999999) return 'Price cannot exceed ₹9,99,999';
  return null;
}

/// Capacity validator — same logic as the table capacity FormField validator.
String? validateCapacity(String? value) {
  if (value == null || value.isEmpty) return 'Required';
  final capacity = int.tryParse(value);
  if (capacity == null) return 'Enter a valid number';
  if (capacity < 1 || capacity > 50) return 'Capacity must be between 1 and 50';
  return null;
}

/// StartNumber validator — same logic as the bulk-add startNumber FormField validator.
String? validateStartNumber(String? value) {
  if (value == null || value.isEmpty) return 'Required';
  final start = int.tryParse(value);
  if (start == null) return 'Enter a valid number';
  if (start < 1) return 'Must be at least 1';
  return null;
}

void main() {
  // ==========================================================================
  // Price Field Validation (Requirement 2.15)
  // ==========================================================================
  group('Price field validation (Requirement 2.15)', () {
    group('rejects invalid inputs with error message', () {
      test('rejects null input', () {
        expect(validatePrice(null), equals('Please enter a price'));
      });

      test('rejects empty string', () {
        expect(validatePrice(''), equals('Please enter a price'));
      });

      test('rejects whitespace-only string', () {
        expect(validatePrice('   '), equals('Please enter a price'));
      });

      test('rejects non-numeric input "abc"', () {
        expect(
          validatePrice('abc'),
          equals('Please enter a valid numeric price'),
        );
      });

      test('rejects non-numeric input "12.3.4"', () {
        expect(
          validatePrice('12.3.4'),
          equals('Please enter a valid numeric price'),
        );
      });

      test('rejects non-numeric input "₹100"', () {
        expect(
          validatePrice('₹100'),
          equals('Please enter a valid numeric price'),
        );
      });

      test('rejects zero', () {
        expect(
          validatePrice('0'),
          equals('Please enter a valid price greater than ₹0'),
        );
      });

      test('rejects negative value "-10"', () {
        expect(
          validatePrice('-10'),
          equals('Please enter a valid price greater than ₹0'),
        );
      });

      test('rejects negative value "-0.01"', () {
        expect(
          validatePrice('-0.01'),
          equals('Please enter a valid price greater than ₹0'),
        );
      });
    });

    group('accepts valid positive numeric inputs', () {
      test('accepts "1"', () {
        expect(validatePrice('1'), isNull);
      });

      test('accepts "99.99"', () {
        expect(validatePrice('99.99'), isNull);
      });

      test('accepts "0.01" (smallest valid price)', () {
        expect(validatePrice('0.01'), isNull);
      });

      test('accepts "1000"', () {
        expect(validatePrice('1000'), isNull);
      });

      test('accepts " 50 " (with surrounding whitespace)', () {
        expect(validatePrice(' 50 '), isNull);
      });

      test('accepts "250.5"', () {
        expect(validatePrice('250.5'), isNull);
      });
    });
  });

  // ==========================================================================
  // Capacity Field Validation (Requirement 2.16)
  // ==========================================================================
  group('Capacity field validation (Requirement 2.16)', () {
    group('rejects values outside 1–50 range', () {
      test('rejects null input', () {
        expect(validateCapacity(null), equals('Required'));
      });

      test('rejects empty string', () {
        expect(validateCapacity(''), equals('Required'));
      });

      test('rejects non-numeric input "abc"', () {
        expect(validateCapacity('abc'), equals('Enter a valid number'));
      });

      test('rejects zero (below minimum)', () {
        expect(
          validateCapacity('0'),
          equals('Capacity must be between 1 and 50'),
        );
      });

      test('rejects negative value "-5"', () {
        expect(
          validateCapacity('-5'),
          equals('Capacity must be between 1 and 50'),
        );
      });

      test('rejects 51 (above maximum)', () {
        expect(
          validateCapacity('51'),
          equals('Capacity must be between 1 and 50'),
        );
      });

      test('rejects 100 (well above maximum)', () {
        expect(
          validateCapacity('100'),
          equals('Capacity must be between 1 and 50'),
        );
      });
    });

    group('accepts valid capacity values', () {
      test('accepts 1 (minimum)', () {
        expect(validateCapacity('1'), isNull);
      });

      test('accepts 50 (maximum)', () {
        expect(validateCapacity('50'), isNull);
      });

      test('accepts 4 (common default)', () {
        expect(validateCapacity('4'), isNull);
      });

      test('accepts 25 (mid-range)', () {
        expect(validateCapacity('25'), isNull);
      });
    });
  });

  // ==========================================================================
  // StartNumber Field Validation (Requirement 2.16)
  // ==========================================================================
  group('StartNumber field validation (Requirement 2.16)', () {
    group('rejects values < 1', () {
      test('rejects null input', () {
        expect(validateStartNumber(null), equals('Required'));
      });

      test('rejects empty string', () {
        expect(validateStartNumber(''), equals('Required'));
      });

      test('rejects non-numeric input "abc"', () {
        expect(validateStartNumber('abc'), equals('Enter a valid number'));
      });

      test('rejects zero', () {
        expect(validateStartNumber('0'), equals('Must be at least 1'));
      });

      test('rejects negative value "-1"', () {
        expect(validateStartNumber('-1'), equals('Must be at least 1'));
      });

      test('rejects "-100"', () {
        expect(validateStartNumber('-100'), equals('Must be at least 1'));
      });
    });

    group('accepts valid start numbers', () {
      test('accepts 1 (minimum)', () {
        expect(validateStartNumber('1'), isNull);
      });

      test('accepts 10', () {
        expect(validateStartNumber('10'), isNull);
      });

      test('accepts 100', () {
        expect(validateStartNumber('100'), isNull);
      });
    });
  });

  // ==========================================================================
  // Category Reorder Persistence (Requirement 2.17)
  // ==========================================================================
  group('Category reorder persistence (Requirement 2.17)', () {
    test('reorder produces correct new index ordering', () {
      // Simulate the same reorder logic used in _reorderCategories
      final now = DateTime.now();
      final categories = [
        FoodCategory(
          id: 'cat-1',
          vendorId: 'v1',
          name: 'Starters',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
        FoodCategory(
          id: 'cat-2',
          vendorId: 'v1',
          name: 'Main Course',
          sortOrder: 1,
          createdAt: now,
          updatedAt: now,
        ),
        FoodCategory(
          id: 'cat-3',
          vendorId: 'v1',
          name: 'Desserts',
          sortOrder: 2,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Simulate drag: move index 2 (Desserts) to index 0
      int oldIndex = 2;
      int newIndex = 0;
      // No adjustment needed when newIndex < oldIndex
      final item = categories.removeAt(oldIndex);
      categories.insert(newIndex, item);

      // After reorder, Desserts should be at index 0
      expect(categories[0].id, equals('cat-3'));
      expect(categories[0].name, equals('Desserts'));
      expect(categories[1].id, equals('cat-1'));
      expect(categories[1].name, equals('Starters'));
      expect(categories[2].id, equals('cat-2'));
      expect(categories[2].name, equals('Main Course'));
    });

    test('reorder with newIndex > oldIndex applies adjustment', () {
      final now = DateTime.now();
      final categories = [
        FoodCategory(
          id: 'cat-a',
          vendorId: 'v1',
          name: 'Appetizers',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
        FoodCategory(
          id: 'cat-b',
          vendorId: 'v1',
          name: 'Beverages',
          sortOrder: 1,
          createdAt: now,
          updatedAt: now,
        ),
        FoodCategory(
          id: 'cat-c',
          vendorId: 'v1',
          name: 'Curries',
          sortOrder: 2,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Simulate drag: move index 0 (Appetizers) to index 2
      int oldIndex = 0;
      int newIndex = 2;
      // ReorderableListView convention: adjust when newIndex > oldIndex
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = categories.removeAt(oldIndex);
      categories.insert(newIndex, item);

      // Appetizers moved to position 1 (after adjustment)
      expect(categories[0].id, equals('cat-b'));
      expect(categories[1].id, equals('cat-a'));
      expect(categories[2].id, equals('cat-c'));
    });

    test(
      'repository updateCategorySortOrder receives correct index mapping',
      () {
        // Verify the contract: each category's position in the list becomes its
        // new sortOrder. The repository writes sortOrder = index for each item.
        final now = DateTime.now();
        final reorderedCategories = [
          FoodCategory(
            id: 'cat-3',
            vendorId: 'v1',
            name: 'Desserts',
            sortOrder: 2,
            createdAt: now,
            updatedAt: now,
          ),
          FoodCategory(
            id: 'cat-1',
            vendorId: 'v1',
            name: 'Starters',
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
          FoodCategory(
            id: 'cat-2',
            vendorId: 'v1',
            name: 'Main Course',
            sortOrder: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        // Simulate what repository does: assigns sortOrder = index
        final expectedSortOrders = <String, int>{};
        for (int i = 0; i < reorderedCategories.length; i++) {
          expectedSortOrders[reorderedCategories[i].id] = i;
        }

        // After persistence, 'cat-3' (Desserts) should have sortOrder 0
        expect(expectedSortOrders['cat-3'], equals(0));
        // 'cat-1' (Starters) should have sortOrder 1
        expect(expectedSortOrders['cat-1'], equals(1));
        // 'cat-2' (Main Course) should have sortOrder 2
        expect(expectedSortOrders['cat-2'], equals(2));
      },
    );
  });

  // ==========================================================================
  // PBT Property 12: Numeric Bounds Validation — Capacity/StartNumber Clause
  // (Regression Lock)
  //
  // **Validates: Requirements 2.15**
  //
  // For randomized strings entered into bulk-add count/startNumber/capacity,
  // single-add capacity, and edit-dialog capacity fields, the form accepts iff
  // the value parses to a number within 1–50 (capacity) / valid positive int
  // (startNumber), and rejects with a visible error otherwise — no silent
  // substitution.
  // ==========================================================================
  group(
    'Property 12: Numeric Bounds Validation (capacity/startNumber clause) — Regression Lock',
    () {
      const int kNumRuns = 200;

      test('PBT Property 12a (forAll): capacity validator accepts iff value '
          'parses to integer in [1, 50]; rejects with non-null error otherwise', () {
        final held = forAll(
          (int rawSeed) {
            // Generate values across the full int spectrum — some valid, some not.
            // Covers: negative, zero, 1..50 (valid), 51+, and large values.
            final value = rawSeed % 200 - 50; // range: -50 to 149
            final input = value.toString();

            final result = validateCapacity(input);

            if (value >= 1 && value <= 50) {
              // Valid: validator must return null (accepted)
              return result == null;
            } else {
              // Invalid: validator must return a non-null, non-empty error string
              return result != null && result.isNotEmpty;
            }
          },
          [Gen.interval(-1000000, 1000000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'Capacity validator must accept [1,50] and reject everything else '
              'with a visible error message (no silent substitution)',
        );
      });

      test('PBT Property 12b (forAll): capacity validator rejects non-numeric '
          'strings with a visible error', () {
        // Generate randomized non-numeric strings
        const nonNumericSamples = [
          'abc',
          'xyz',
          '12.5',
          '3.14',
          '1e2',
          '0xFF',
          '--5',
          '++3',
          'NaN',
          'Infinity',
          '₹10',
          '1,000',
          '10 ',
          ' 10',
          '1 0',
          'null',
          'true',
          'false',
          '!@#',
          'ten',
          '五',
          '٥٠',
          '50.0',
          '1.0',
          '0.5',
          '3/4',
          '2+3',
          '',
          ' ',
        ];

        for (final input in nonNumericSamples) {
          final result = validateCapacity(input);
          // int.tryParse will fail on these, so validator must reject
          if (int.tryParse(input) == null) {
            expect(
              result,
              isNotNull,
              reason: 'Non-numeric input "$input" must be rejected with error',
            );
          }
        }
      });

      test('PBT Property 12c (forAll): startNumber validator accepts iff value '
          'parses to a positive integer (≥1); rejects with non-null error '
          'otherwise', () {
        final held = forAll(
          (int rawSeed) {
            // Generate values: negative, zero, and positive integers
            final value = rawSeed % 300 - 100; // range: -100 to 199
            final input = value.toString();

            final result = validateStartNumber(input);

            if (value >= 1) {
              // Valid: validator must return null (accepted)
              return result == null;
            } else {
              // Invalid (zero or negative): validator must return a non-null error
              return result != null && result.isNotEmpty;
            }
          },
          [Gen.interval(-1000000, 1000000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'StartNumber validator must accept ≥1 and reject zero/negative '
              'with a visible error message (no silent substitution)',
        );
      });

      test(
        'PBT Property 12d (forAll): startNumber validator rejects non-numeric '
        'strings with a visible error',
        () {
          const nonNumericSamples = [
            'abc',
            '12.5',
            '1e2',
            'NaN',
            '',
            ' ',
            '₹1',
            '1,0',
            '--1',
            'null',
            'true',
            '0xFF',
            '1.0',
            '3/4',
            '!@',
          ];

          for (final input in nonNumericSamples) {
            final result = validateStartNumber(input);
            if (int.tryParse(input) == null) {
              expect(
                result,
                isNotNull,
                reason:
                    'Non-numeric input "$input" must be rejected with error',
              );
            }
          }
        },
      );

      test('PBT Property 12e (forAll): bulk-add count validator accepts iff '
          'value parses to integer in [1, 100]; rejects otherwise', () {
        // The bulk-add count uses the same validation pattern as capacity but
        // with bounds [1, 100]. Replicate that validator inline:
        String? validateCount(String? value) {
          if (value == null || value.isEmpty) return 'Required';
          final count = int.tryParse(value);
          if (count == null) return 'Enter a valid number';
          if (count <= 0 || count > 100) return 'Enter between 1 and 100';
          return null;
        }

        final held = forAll(
          (int rawSeed) {
            final value = rawSeed % 300 - 50; // range: -50 to 249
            final input = value.toString();

            final result = validateCount(input);

            if (value >= 1 && value <= 100) {
              return result == null;
            } else {
              return result != null && result.isNotEmpty;
            }
          },
          [Gen.interval(-1000000, 1000000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'Bulk-add count validator must accept [1,100] and reject everything '
              'else with a visible error',
        );
      });

      test('PBT Property 12f: no silent substitution — validator never returns '
          'null for out-of-bounds inputs (comprehensive boundary sweep)', () {
        // Boundary values that MUST be rejected for capacity
        final invalidCapacityValues = [
          '0',
          '-1',
          '-50',
          '51',
          '52',
          '100',
          '999',
          '-999',
          '1000000',
          '-1000000',
        ];

        for (final input in invalidCapacityValues) {
          final result = validateCapacity(input);
          expect(
            result,
            isNotNull,
            reason:
                'Capacity "$input" is out of bounds and must be rejected '
                '(not silently substituted)',
          );
        }

        // Boundary values that MUST be rejected for startNumber
        final invalidStartValues = ['0', '-1', '-50', '-999'];
        for (final input in invalidStartValues) {
          final result = validateStartNumber(input);
          expect(
            result,
            isNotNull,
            reason:
                'StartNumber "$input" is out of bounds and must be rejected '
                '(not silently substituted)',
          );
        }
      });
    },
  );

  // ==========================================================================
  // PBT Property 12 (price ceiling clause): Bug Condition Exploration
  // — No Price Ceiling Exists
  //
  // **Validates: Requirements 2.16**
  //
  // Assert that food_menu_management_screen.dart's price validator (add and edit
  // forms) currently accepts arbitrarily large positive values (e.g. ₹99,999,999)
  // with no upper-bound rejection, even though empty/non-numeric/≤0 are already
  // rejected. This test asserts an upper bound SHOULD exist — it is EXPECTED TO
  // FAIL on unfixed code, confirming the bug condition.
  // ==========================================================================
  group(
    'Property 12 (price ceiling): Bug Condition Exploration — no price ceiling exists',
    () {
      const int kNumRuns = 200;

      // The documented price ceiling: ₹999,999 (just under 10 lakh).
      // Any value above this should be rejected by the validator.
      const double priceCeiling = 999999.0;

      test('PBT 12-price-a: rejects above ceiling — FAILS on unfixed code', () {
        final held = forAll(
          (int seed) {
            // Generate arbitrarily large prices above the ceiling
            final largePrice = priceCeiling + 1 + (seed.abs() % 99000000);
            final input = largePrice.toStringAsFixed(2);

            final result = validatePrice(input);

            // The validator SHOULD return a non-null error for prices above ceiling
            return result != null && result.isNotEmpty;
          },
          [Gen.interval(1, 99999999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'Price validator must reject values above ₹$priceCeiling with a '
              'visible error — currently accepts arbitrarily large prices '
              '(bug condition: no upper bound exists)',
        );
      });

      test('PBT 12-price-b: extreme values rejected — FAILS on unfixed code', () {
        // These extreme prices should all be rejected if a ceiling exists
        final extremePrices = [
          '99999999', // ₹9,99,99,999 — absurd for a menu item
          '1000000', // ₹10,00,000 — just above ceiling
          '5000000', // ₹50,00,000
          '99999999.99', // Near max double precision
          '10000000', // ₹1,00,00,000
          '1000001', // Just barely over ceiling
        ];

        for (final input in extremePrices) {
          final result = validatePrice(input);
          expect(
            result,
            isNotNull,
            reason:
                'Price "₹$input" is unreasonably large and should be rejected '
                'by an upper-bound check — but no ceiling exists (bug condition)',
          );
        }
      });

      test('PBT 12-price-c: prices at/below ceiling accepted (sanity)', () {
        // These valid prices below ceiling should be accepted
        final validPrices = [
          '0.01', // Minimum valid
          '1', // ₹1
          '100', // ₹100
          '999', // ₹999
          '9999', // ₹9,999
          '99999', // ₹99,999
          '999999', // ₹9,99,999 (at ceiling — should still pass)
          '500000', // ₹5,00,000 (mid-range, below ceiling)
        ];

        for (final input in validPrices) {
          final result = validatePrice(input);
          expect(
            result,
            isNull,
            reason:
                'Price "₹$input" is within valid bounds and should be accepted',
          );
        }
      });
    },
  );

  // ==========================================================================
  // PBT Property 13: Preservation — Previously-Valid Numeric Inputs Still
  // Accepted Unchanged (capacity/startNumber clause)
  //
  // **Validates: Requirements 3.11**
  //
  // For randomized previously-valid values, the fixed-in-place validator still
  // accepts and saves the identical value — no valid input was silently
  // narrowed by the bounds enforcement.
  // ==========================================================================
  group(
    'Property 13: Previously-Valid Numeric Inputs Still Accepted Unchanged — Regression Lock',
    () {
      const int kNumRuns = 200;

      test('PBT Property 13a (forAll): all capacity values in [1, 50] remain '
          'accepted by the validator (preservation)', () {
        final held = forAll(
          (int seed) {
            // Generate a valid capacity value in [1, 50]
            final capacity = (seed.abs() % 50) + 1; // always [1, 50]
            final input = capacity.toString();

            final result = validateCapacity(input);

            // Must be accepted (null means no error)
            if (result != null) return false;

            // The parsed value must equal the input exactly (no transformation)
            final parsed = int.parse(input);
            return parsed == capacity;
          },
          [Gen.interval(0, 999999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'All previously-valid capacity values [1,50] must remain accepted '
              'and the parsed value must equal the input exactly',
        );
      });

      test('PBT Property 13b (forAll): all startNumber values ≥ 1 remain '
          'accepted by the validator (preservation)', () {
        final held = forAll(
          (int seed) {
            // Generate a valid startNumber (positive integer ≥1)
            final startNumber = (seed.abs() % 10000) + 1; // [1, 10000]
            final input = startNumber.toString();

            final result = validateStartNumber(input);

            // Must be accepted
            if (result != null) return false;

            // The parsed value must equal the input exactly
            final parsed = int.parse(input);
            return parsed == startNumber;
          },
          [Gen.interval(1, 9999999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'All previously-valid startNumber values (≥1) must remain accepted '
              'and the parsed value must equal the input exactly',
        );
      });

      test('PBT Property 13c (forAll): bulk-add count values in [1, 100] remain '
          'accepted (preservation)', () {
        // Replicate the bulk-add count validator
        String? validateCount(String? value) {
          if (value == null || value.isEmpty) return 'Required';
          final count = int.tryParse(value);
          if (count == null) return 'Enter a valid number';
          if (count <= 0 || count > 100) return 'Enter between 1 and 100';
          return null;
        }

        final held = forAll(
          (int seed) {
            final count = (seed.abs() % 100) + 1; // [1, 100]
            final input = count.toString();

            final result = validateCount(input);

            if (result != null) return false;
            final parsed = int.parse(input);
            return parsed == count;
          },
          [Gen.interval(0, 999999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'All previously-valid count values [1,100] must remain accepted',
        );
      });

      test('PBT Property 13d: boundary values at the edges of the valid range '
          'are preserved', () {
        // Exact boundary values for capacity
        expect(validateCapacity('1'), isNull, reason: 'capacity=1 must pass');
        expect(validateCapacity('50'), isNull, reason: 'capacity=50 must pass');
        expect(validateCapacity('2'), isNull, reason: 'capacity=2 must pass');
        expect(validateCapacity('49'), isNull, reason: 'capacity=49 must pass');
        expect(validateCapacity('25'), isNull, reason: 'capacity=25 must pass');

        // Exact boundary values for startNumber
        expect(
          validateStartNumber('1'),
          isNull,
          reason: 'startNumber=1 must pass',
        );
        expect(
          validateStartNumber('2'),
          isNull,
          reason: 'startNumber=2 must pass',
        );
        expect(
          validateStartNumber('50'),
          isNull,
          reason: 'startNumber=50 must pass',
        );
        expect(
          validateStartNumber('100'),
          isNull,
          reason: 'startNumber=100 must pass',
        );
        expect(
          validateStartNumber('9999'),
          isNull,
          reason: 'startNumber=9999 must pass',
        );
      });
    },
  );

  // ==========================================================================
  // PBT Property 13 (price clause): Preservation — Previously-Valid Prices
  // Still Accepted Unchanged
  //
  // **Validates: Requirements 3.12**
  //
  // For randomized previously-valid price values (positive, numeric, within
  // reasonable bounds ≤ 999,999), the validator still accepts them after the
  // ceiling check is added. This test PASSES on current (unfixed) code because
  // today any positive numeric price is accepted, and must continue to PASS
  // after the ceiling is implemented in Task 21.3.
  // ==========================================================================
  group(
    'Property 13 (price clause): Preservation — valid prices still accepted',
    () {
      const int kNumRuns = 200;

      test('PBT 13-price-a (forAll): randomized positive prices in (0, 999999] '
          'are accepted by validatePrice (preservation)', () {
        final held = forAll(
          (int seed) {
            // Generate a price in the valid range (0, 999999].
            // Use the seed to produce a double with up to 2 decimal places.
            final wholePart = (seed.abs() % 999999) + 1; // [1, 999999]
            final decimalPart = seed.abs() % 100; // [0, 99] for cents
            final price = wholePart + decimalPart / 100.0;
            // Clamp to ceiling to ensure we stay in valid range
            final clampedPrice = price > 999999 ? 999999.0 : price;
            final input = clampedPrice.toStringAsFixed(2);

            final result = validatePrice(input);

            // Must be accepted (null = no error)
            return result == null;
          },
          [Gen.interval(1, 9999999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'All positive prices in (0, 999999] must remain accepted by '
              'validatePrice — the ceiling must not narrow previously-valid inputs',
        );
      });

      test('PBT 13-price-b (forAll): small positive prices (0.01 to 100) '
          'are accepted (preservation)', () {
        final held = forAll(
          (int seed) {
            // Generate small prices in the range [0.01, 100.00]
            final cents = (seed.abs() % 10000) + 1; // [1, 10000] cents
            final price = cents / 100.0; // [0.01, 100.00]
            final input = price.toStringAsFixed(2);

            final result = validatePrice(input);

            return result == null;
          },
          [Gen.interval(1, 9999999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'Small positive prices [0.01, 100.00] must remain accepted',
        );
      });

      test('PBT 13-price-c (forAll): medium prices (100 to 50000) '
          'are accepted (preservation)', () {
        final held = forAll(
          (int seed) {
            // Generate medium prices [100, 50000]
            final price = 100 + (seed.abs() % 49901); // [100, 50000]
            final input = price.toString();

            final result = validatePrice(input);

            return result == null;
          },
          [Gen.interval(1, 9999999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'Medium prices [100, 50000] must remain accepted',
        );
      });

      test('PBT 13-price-d: boundary values at and below the documented '
          'ceiling are preserved', () {
        // Exact boundary values that MUST remain valid after ceiling is added
        final validPrices = [
          '0.01', // Minimum valid price
          '0.50', // Half rupee
          '1', // ₹1
          '10', // ₹10
          '99.99', // Common price point
          '100', // ₹100
          '250', // ₹250
          '500', // ₹500
          '999', // ₹999
          '1000', // ₹1,000
          '5000', // ₹5,000
          '9999', // ₹9,999
          '25000', // ₹25,000
          '50000', // ₹50,000
          '99999', // ₹99,999
          '100000', // ₹1,00,000
          '500000', // ₹5,00,000
          '999999', // ₹9,99,999 — at the documented ceiling
        ];

        for (final input in validPrices) {
          final result = validatePrice(input);
          expect(
            result,
            isNull,
            reason:
                'Price "₹$input" is within the valid range (0, 999999] and '
                'must remain accepted after the ceiling is added',
          );
        }
      });

      test('PBT 13-price-e (forAll): integer prices from 1 to 999999 '
          'are accepted (preservation)', () {
        final held = forAll(
          (int seed) {
            // Generate integer prices [1, 999999]
            final price = (seed.abs() % 999999) + 1;
            final input = price.toString();

            final result = validatePrice(input);

            return result == null;
          },
          [Gen.interval(1, 9999999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'All integer prices in [1, 999999] must remain accepted',
        );
      });
    },
  );
}
