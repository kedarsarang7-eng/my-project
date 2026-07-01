// Unit tests for the P2 hardware remediation logic (bugfix.md 2.13 / 2.14).
//
// Covers the two pieces of pure domain logic added for Task 3.6:
//   * UnitConversionService — ft↔mtr and box↔pcs conversions (2.13)
//   * e-Way bill ₹50,000 threshold rule (2.14)

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/utils/unit_conversion_service.dart';
import 'package:dukanx/features/hardware/presentation/screens/eway_bill_screen.dart';

void main() {
  group('UnitConversionService (bugfix.md 2.13)', () {
    const svc = UnitConversionService();

    test('feet → metre uses the exact international foot', () {
      expect(svc.convert(10, 'ft', 'mtr'), closeTo(3.048, 1e-9));
    });

    test('metre → feet is the inverse of feet → metre', () {
      final back = svc.convert(svc.convert(7, 'ft', 'mtr'), 'mtr', 'ft');
      expect(back, closeTo(7, 1e-9));
    });

    test('same-unit conversion is identity', () {
      expect(svc.convert(42, 'ft', 'feet'), 42);
    });

    test('box → pcs multiplies by the pack size', () {
      expect(svc.convert(3, 'box', 'pcs', piecesPerBox: 12), 36);
    });

    test('pcs → box divides by the pack size', () {
      expect(svc.convert(36, 'pcs', 'box', piecesPerBox: 12), 3);
    });

    test('box↔pcs without a pack size throws', () {
      expect(() => svc.convert(1, 'box', 'pcs'), throwsArgumentError);
    });

    test('cross-family conversion (ft → box) is rejected', () {
      expect(svc.canConvert('ft', 'box'), isFalse);
      expect(() => svc.convert(1, 'ft', 'box'), throwsArgumentError);
    });

    test('unknown units are rejected', () {
      expect(svc.normalise('furlong'), isNull);
      expect(svc.canConvert('furlong', 'mtr'), isFalse);
    });
  });

  group('e-Way bill threshold rule (bugfix.md 2.14)', () {
    test('dispatches at/above ₹50,000 require an e-Way bill', () {
      expect(isEWayBillRequired(50000), isTrue);
      expect(isEWayBillRequired(75000.50), isTrue);
    });

    test('dispatches below ₹50,000 do not require an e-Way bill', () {
      expect(isEWayBillRequired(49999.99), isFalse);
      expect(isEWayBillRequired(0), isFalse);
    });
  });
}
