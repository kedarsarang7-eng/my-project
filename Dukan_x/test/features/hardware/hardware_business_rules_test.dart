// Worked-example test for D11 hardware business rules
// (clauses 2.16 + 2.19 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/hardware/utils/hardware_business_rules.dart';

void main() {
  group('HardwareBusinessRules dimension math', () {
    test('squareFeet 10x4 -> 40.00', () {
      expect(HardwareBusinessRules.squareFeet(10, 4), equals(40.0));
    });
    test('cubicFeet 2x3x4 -> 24.00', () {
      expect(HardwareBusinessRules.cubicFeet(2, 3, 4), equals(24.0));
    });
    test('negative inputs clamp to 0', () {
      expect(HardwareBusinessRules.squareFeet(-1, 4), equals(0.0));
      expect(HardwareBusinessRules.cubicFeet(2, -1, 4), equals(0.0));
    });
  });

  group('HardwareBusinessRules unit conversions', () {
    test('mmToFeet 304.8 -> 1.00', () {
      expect(HardwareBusinessRules.mmToFeet(304.8), equals(1.0));
    });
    test('metersToFeet 1 -> 3.28', () {
      expect(HardwareBusinessRules.metersToFeet(1), equals(3.28));
    });
  });

  group('HardwareBusinessRules.cutToSizeCharge', () {
    test('1.1 ft @ ₹50/ft bills as 2 ft -> 100.00', () {
      expect(HardwareBusinessRules.cutToSizeCharge(50, 1.1), equals(100.0));
    });
    test('exactly 5 ft @ ₹50/ft -> 250.00', () {
      expect(HardwareBusinessRules.cutToSizeCharge(50, 5), equals(250.0));
    });
  });

  group('HardwareBusinessRules cut-to-size rounding disclosure (2.27)', () {
    test('wasRoundedUp true for a fractional cut', () {
      expect(HardwareBusinessRules.cutToSizeWasRoundedUp(1.1), isTrue);
    });
    test('wasRoundedUp false for a whole-unit cut', () {
      expect(HardwareBusinessRules.cutToSizeWasRoundedUp(2), isFalse);
    });
    test('rounding note discloses measured vs billed for 1.1 ft', () {
      final note = HardwareBusinessRules.cutToSizeRoundingNote(
        1.1,
        unitLabel: 'ft',
      );
      expect(note, isNotNull);
      expect(note, contains('billed as 2 ft'));
      expect(note, contains('measured 1.1 ft'));
    });
    test('no note when measured units are already whole', () {
      expect(
        HardwareBusinessRules.cutToSizeRoundingNote(2, unitLabel: 'ft'),
        isNull,
      );
    });
    test('no note for zero/negative units', () {
      expect(HardwareBusinessRules.cutToSizeRoundingNote(0), isNull);
      expect(HardwareBusinessRules.cutToSizeRoundingNote(-1), isNull);
    });
  });
}
