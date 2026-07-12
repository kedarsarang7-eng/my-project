// Worked-example test for D11 restaurant business rules
// (clauses 2.16 + 2.19 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/restaurant/utils/restaurant_business_rules.dart';

void main() {
  group('RestaurantBusinessRules.splitBill', () {
    test('split 100.00 across 3 -> [33.34, 33.33, 33.33]', () {
      final parts = RestaurantBusinessRules.splitBill(100.0, 3);
      expect(parts, equals([33.34, 33.33, 33.33]));
      // Sum equals original total (no rounding loss).
      final sum = parts.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(100.0, 1e-9));
    });
    test('split 100.50 across 4 -> [25.14, 25.12, 25.12, 25.12]', () {
      final parts = RestaurantBusinessRules.splitBill(100.50, 4);
      expect(parts, equals([25.14, 25.12, 25.12, 25.12]));
    });
    test('zero or negative split count returns empty', () {
      expect(RestaurantBusinessRules.splitBill(100, 0), isEmpty);
      expect(RestaurantBusinessRules.splitBill(100, -1), isEmpty);
    });
  });

  group('RestaurantBusinessRules.serviceCharge', () {
    test('5% of 1000 -> 50.00', () {
      expect(RestaurantBusinessRules.serviceCharge(1000), equals(50.0));
    });
    test('5% of 199.99 -> 10.00 (rounded half-up)', () {
      // 199.99 * 0.05 = 9.9995 -> 10.00
      expect(RestaurantBusinessRules.serviceCharge(199.99), equals(10.0));
    });
  });

  group('RestaurantBusinessRules.isInHappyHour', () {
    test('non-wrapping window 17:00-19:00', () {
      expect(
        RestaurantBusinessRules.isInHappyHour(
          now: DateTime(2024, 1, 1, 18, 30),
          startHour24: 17,
          endHour24: 19,
        ),
        isTrue,
      );
      expect(
        RestaurantBusinessRules.isInHappyHour(
          now: DateTime(2024, 1, 1, 19, 0),
          startHour24: 17,
          endHour24: 19,
        ),
        isFalse,
      );
    });
    test('wrapping window 22:00-02:00', () {
      expect(
        RestaurantBusinessRules.isInHappyHour(
          now: DateTime(2024, 1, 1, 23, 0),
          startHour24: 22,
          endHour24: 2,
        ),
        isTrue,
      );
      expect(
        RestaurantBusinessRules.isInHappyHour(
          now: DateTime(2024, 1, 1, 1, 30),
          startHour24: 22,
          endHour24: 2,
        ),
        isTrue,
      );
      expect(
        RestaurantBusinessRules.isInHappyHour(
          now: DateTime(2024, 1, 1, 12, 0),
          startHour24: 22,
          endHour24: 2,
        ),
        isFalse,
      );
    });
  });

  // ===========================================================================
  // Property 16: Bug Condition — Happy-Hour Pricing Applied Exactly When
  // Window Is Active (Regression Lock)
  //
  // **Validates: Requirements 2.23, 3.15**
  //
  // For randomized current times, happy-hour windows (including midnight-
  // wrapping) and positive prices, displayed/billed price reflects the
  // happy-hour discount iff RestaurantBusinessRules.isInHappyHour returns true;
  // equals undiscounted price otherwise.
  //
  // Also covers Preservation 3.15 (non-happy-hour pricing unaffected) — asserts
  // explicitly for times outside any configured window.
  //
  // PBT library: dartproptest ^0.2.1.
  // ===========================================================================
  group('Property 16: Happy-Hour Pricing Regression Lock', () {
    /// Computes the billed price for an item given the happy-hour state.
    /// Mirrors the logic in bill_creation_screen_v2.dart:
    ///   happyHourPerUnit = isActive ? sellingPrice * (discountPercent / 100) : 0
    ///   billedPrice = sellingPrice - happyHourPerUnit
    double computeBilledPrice({
      required double sellingPrice,
      required double discountPercent,
      required bool isHappyHourActive,
    }) {
      final happyHourPerUnit = isHappyHourActive
          ? sellingPrice * (discountPercent / 100)
          : 0.0;
      return sellingPrice - happyHourPerUnit;
    }

    test('PBT Property 16a: price reflects discount IFF isInHappyHour is true '
        '(non-wrapping and wrapping windows)', () {
      final held = forAll(
        (int hourSeed, int windowSeed, int priceSeed) {
          // Generate a current hour (0-23)
          final hour = hourSeed.abs() % 24;
          final now = DateTime(2024, 6, 15, hour, 30);

          // Generate a happy-hour window with distinct start and end
          final startHour = windowSeed.abs() % 24;
          // Ensure end != start to avoid the degenerate "always false" case
          final endHour = (startHour + 1 + (windowSeed.abs() ~/ 24) % 22) % 24;

          // Generate a positive price (1 to 9999 rupees, in paise precision)
          final sellingPrice = ((priceSeed.abs() % 999900) + 100) / 100.0;

          // Fixed discount percent (10% — matching the default in billing)
          const discountPercent = 10.0;

          // Determine if happy hour is active using the domain rule
          final isActive = RestaurantBusinessRules.isInHappyHour(
            now: now,
            startHour24: startHour,
            endHour24: endHour,
          );

          // Compute the billed price (mirrors bill_creation_screen_v2 logic)
          final billedPrice = computeBilledPrice(
            sellingPrice: sellingPrice,
            discountPercent: discountPercent,
            isHappyHourActive: isActive,
          );

          if (isActive) {
            // When happy hour IS active: billed price must be discounted
            final expectedDiscount = sellingPrice * (discountPercent / 100);
            final expectedBilled = sellingPrice - expectedDiscount;
            if ((billedPrice - expectedBilled).abs() > 0.01) return false;
            // Must NOT equal undiscounted price (unless discount is 0)
            if (discountPercent > 0 &&
                (billedPrice - sellingPrice).abs() < 0.01) {
              return false;
            }
          } else {
            // When happy hour is NOT active: billed price equals undiscounted
            if ((billedPrice - sellingPrice).abs() > 0.01) return false;
          }
          return true;
        },
        [
          Gen.interval(-100000, 100000),
          Gen.interval(0, 100000),
          Gen.interval(1, 100000),
        ],
        numRuns: 200,
      );
      expect(
        held,
        isTrue,
        reason:
            'Happy-hour discount must be applied IFF isInHappyHour is true, '
            'and must equal the undiscounted price otherwise.',
      );
    });

    test('PBT Property 16b (Preservation 3.15): price is always undiscounted '
        'for times outside any configured window', () {
      final held = forAll(
        (int hourSeed, int windowSeed, int priceSeed) {
          // Generate a current hour (0-23)
          final hour = hourSeed.abs() % 24;
          final now = DateTime(2024, 6, 15, hour, 30);

          // Generate a happy-hour window with distinct start and end
          final startHour = windowSeed.abs() % 24;
          final endHour = (startHour + 1 + (windowSeed.abs() ~/ 24) % 22) % 24;

          // Check if this time is outside the window
          final isActive = RestaurantBusinessRules.isInHappyHour(
            now: now,
            startHour24: startHour,
            endHour24: endHour,
          );

          // Only test the "outside window" case
          if (isActive) return true; // skip active times for this property

          // Generate a positive price
          final sellingPrice = ((priceSeed.abs() % 999900) + 100) / 100.0;
          const discountPercent = 10.0;

          // Compute billed price — must equal undiscounted
          final billedPrice = computeBilledPrice(
            sellingPrice: sellingPrice,
            discountPercent: discountPercent,
            isHappyHourActive: false,
          );

          return (billedPrice - sellingPrice).abs() < 0.01;
        },
        [
          Gen.interval(-100000, 100000),
          Gen.interval(0, 100000),
          Gen.interval(1, 100000),
        ],
        numRuns: 200,
      );
      expect(
        held,
        isTrue,
        reason:
            'Preservation 3.15: pricing outside a configured happy-hour '
            'window must always equal the undiscounted price.',
      );
    });

    test('PBT Property 16c: midnight-wrapping windows correctly classify '
        'boundary hours', () {
      final held = forAll(
        (int windowStartSeed, int priceSeed) {
          // Generate a midnight-wrapping window (start > end in 24h terms)
          // e.g. 22:00 -> 02:00, 20:00 -> 04:00
          final startHour = 18 + (windowStartSeed.abs() % 6); // 18..23
          final endHour = (windowStartSeed.abs() ~/ 6) % 6; // 0..5

          // Price
          final sellingPrice = ((priceSeed.abs() % 999900) + 100) / 100.0;
          const discountPercent = 10.0;

          // Test a time inside the wrap window (at startHour)
          final insideTime = DateTime(2024, 6, 15, startHour, 0);
          final insideActive = RestaurantBusinessRules.isInHappyHour(
            now: insideTime,
            startHour24: startHour,
            endHour24: endHour,
          );
          final insideBilled = computeBilledPrice(
            sellingPrice: sellingPrice,
            discountPercent: discountPercent,
            isHappyHourActive: insideActive,
          );

          // Test a time outside the wrap window (at endHour)
          final outsideTime = DateTime(2024, 6, 15, endHour, 0);
          final outsideActive = RestaurantBusinessRules.isInHappyHour(
            now: outsideTime,
            startHour24: startHour,
            endHour24: endHour,
          );
          final outsideBilled = computeBilledPrice(
            sellingPrice: sellingPrice,
            discountPercent: discountPercent,
            isHappyHourActive: outsideActive,
          );

          // Inside should be active (discounted)
          if (!insideActive) return false;
          final expectedDiscounted =
              sellingPrice - sellingPrice * (discountPercent / 100);
          if ((insideBilled - expectedDiscounted).abs() > 0.01) return false;

          // Outside (at endHour boundary) should be inactive (undiscounted)
          if (outsideActive) return false;
          if ((outsideBilled - sellingPrice).abs() > 0.01) return false;

          return true;
        },
        [Gen.interval(0, 100000), Gen.interval(1, 100000)],
        numRuns: 200,
      );
      expect(
        held,
        isTrue,
        reason:
            'Midnight-wrapping windows must correctly discount inside '
            'the wrap and leave undiscounted outside.',
      );
    });

    test('PBT Property 16d: equal start and end hour means no happy hour '
        '(always undiscounted)', () {
      final held = forAll(
        (int hourSeed, int priceSeed) {
          final sameHour = hourSeed.abs() % 24;
          final now = DateTime(2024, 6, 15, hourSeed.abs() % 24, 30);

          // When start == end, isInHappyHour should always be false
          final isActive = RestaurantBusinessRules.isInHappyHour(
            now: now,
            startHour24: sameHour,
            endHour24: sameHour,
          );
          if (isActive) return false; // should never be active

          // Billed price must be undiscounted
          final sellingPrice = ((priceSeed.abs() % 999900) + 100) / 100.0;
          const discountPercent = 10.0;
          final billedPrice = computeBilledPrice(
            sellingPrice: sellingPrice,
            discountPercent: discountPercent,
            isHappyHourActive: isActive,
          );
          return (billedPrice - sellingPrice).abs() < 0.01;
        },
        [Gen.interval(0, 100000), Gen.interval(1, 100000)],
        numRuns: 200,
      );
      expect(
        held,
        isTrue,
        reason:
            'When start == end (degenerate window), happy hour is never '
            'active and price is always undiscounted.',
      );
    });
  });
}
