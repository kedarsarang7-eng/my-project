// Worked-example test for D11 restaurant business rules
// (clauses 2.16 + 2.19 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
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
}
