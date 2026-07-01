// Reproduction + regression test for D3 monetary-math fixes
// (clause 2.6 + 2.19 of `bugfix.md`).
//
// On F (raw `double` accumulation) the GST-slab worked example below
// drifts by 0.01 paise after enough additions; on F' (MoneyMath.sum) it
// matches the documented expected value exactly.

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/accounting/money_math.dart';

void main() {
  group('MoneyMath.sum — fixed-precision aggregation', () {
    test('classic 0.1 + 0.2 case rounds to 0.30 (not 0.30000000000000004)', () {
      // Raw `double`: 0.1 + 0.2 = 0.30000000000000004
      expect(0.1 + 0.2, isNot(equals(0.30)));
      // MoneyMath: rounded half-up to paise.
      expect(MoneyMath.sum(const [0.1, 0.2]), equals(0.30));
    });

    test('GST 18% slab: 100 invoices of ₹123.45 -> ₹12345.00 exactly', () {
      final values = List<double>.filled(100, 123.45);
      // Raw `double` sum drifts (12344.999999...): exact equality fails.
      var rawAcc = 0.0;
      for (final v in values) {
        rawAcc += v;
      }
      expect(rawAcc, isNot(equals(12345.0)));
      // MoneyMath sum is exact.
      expect(MoneyMath.sum(values), equals(12345.0));
    });

    test('mixed slab aggregation matches documented per-line totals', () {
      // 5%, 12%, 18%, 28% slab line totals (taxable values in rupees).
      const lineTotals = <double>[
        499.99, // 5% slab
        1199.50, // 12% slab
        1899.99, // 18% slab
        2799.00, // 28% slab
      ];
      // Documented expected = sum, half-up to paise.
      // 499.99 + 1199.50 + 1899.99 + 2799.00 = 6398.48
      expect(MoneyMath.sum(lineTotals), equals(6398.48));
    });

    test('empty input returns 0.0', () {
      expect(MoneyMath.sum(const <double>[]), equals(0.0));
    });

    test('addAll keeps Decimal precision for chained aggregations', () {
      // Aggregate twice without intermediate rounding.
      final cgst = MoneyMath.addAll(const [50.005, 50.005]);
      final sgst = MoneyMath.addAll(const [50.005, 50.005]);
      // 50.005 + 50.005 = 100.01 (no double drift), so cgst+sgst = 200.02.
      final total = MoneyMath.roundTo2(cgst + sgst).toDouble();
      expect(total, equals(200.02));
    });

    test('half-up rounding at the .005 boundary', () {
      // 0.005 -> 0.01 (banker's rounding would give 0.00 — we want half-up).
      expect(MoneyMath.sum(const [0.005]), equals(0.01));
      // 0.015 -> 0.02 (half-up).
      expect(MoneyMath.sum(const [0.015]), equals(0.02));
    });
  });
}
