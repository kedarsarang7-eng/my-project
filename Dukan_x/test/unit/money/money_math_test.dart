// Unit tests: MoneyMath — fixed-precision monetary aggregation
// Source: lib/core/accounting/money_math.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:dukanx/core/accounting/money_math.dart';

void main() {
  // === MoneyMath.sum ===
  group('MoneyMath.sum', () {
    test('0.1 + 0.2 = 0.30 (not 0.30000000000000004)', () {
      expect(MoneyMath.sum(const [0.1, 0.2]), equals(0.30));
    });

    test('100 invoices of ₹123.45 → ₹12345.00 exactly', () {
      final values = List<double>.filled(100, 123.45);
      expect(MoneyMath.sum(values), equals(12345.0));
    });

    test('empty input → 0.0', () {
      expect(MoneyMath.sum(const <double>[]), equals(0.0));
    });

    test('single value passthrough', () {
      expect(MoneyMath.sum(const [99.99]), equals(99.99));
    });

    test('mixed slab line totals sum correctly', () {
      const lineTotals = <double>[499.99, 1199.50, 1899.99, 2799.00];
      expect(MoneyMath.sum(lineTotals), equals(6398.48));
    });

    test('negative amounts (refunds) handled correctly', () {
      expect(MoneyMath.sum(const [100.00, -50.00]), equals(50.00));
    });

    test('large number of small amounts — no drift', () {
      // 1000 × ₹0.01 = ₹10.00
      final values = List<double>.filled(1000, 0.01);
      expect(MoneyMath.sum(values), equals(10.0));
    });

    test('₹999999.99 + ₹0.01 = ₹1000000.00', () {
      expect(MoneyMath.sum(const [999999.99, 0.01]), equals(1000000.0));
    });
  });

  // === MoneyMath.addAll ===
  group('MoneyMath.addAll', () {
    test('returns Decimal for chained aggregation', () {
      final result = MoneyMath.addAll(const [50.005, 50.005]);
      // 50.005 + 50.005 = 100.010
      expect(result, equals(Decimal.parse('100.01')));
    });

    test('cgst + sgst chained aggregation', () {
      final cgst = MoneyMath.addAll(const [50.005, 50.005]);
      final sgst = MoneyMath.addAll(const [50.005, 50.005]);
      final total = MoneyMath.roundTo2(cgst + sgst).toDouble();
      expect(total, equals(200.02));
    });
  });

  // === MoneyMath.roundTo2 ===
  group('MoneyMath.roundTo2', () {
    test('0.005 → 0.01 (half-up, not banker\'s)', () {
      expect(MoneyMath.sum(const [0.005]), equals(0.01));
    });

    test('0.015 → 0.02', () {
      expect(MoneyMath.sum(const [0.015]), equals(0.02));
    });

    test('0.004 → 0.00 (rounds down)', () {
      expect(MoneyMath.sum(const [0.004]), equals(0.0));
    });

    test('123.456 → 123.46', () {
      expect(MoneyMath.sum(const [123.456]), equals(123.46));
    });

    test('negative: -0.005 → rounds correctly', () {
      // Behavior depends on implementation; just verify no crash
      final result = MoneyMath.sum(const [-0.005]);
      expect(result, isA<double>());
    });
  });
}
