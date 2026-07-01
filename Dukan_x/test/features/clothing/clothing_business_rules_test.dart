// Worked-example test for D11 clothing business rules
// (clauses 2.16 + 2.19 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/clothing/utils/clothing_business_rules.dart';

void main() {
  group('ClothingBusinessRules.isValidMeasurement', () {
    test('chest 38 inches is valid', () {
      expect(
        ClothingBusinessRules.isValidMeasurement(MeasurementKey.chest, 38),
        isTrue,
      );
    });
    test('chest 80 inches (above max) is rejected', () {
      expect(
        ClothingBusinessRules.isValidMeasurement(MeasurementKey.chest, 80),
        isFalse,
      );
    });
    test('inseam 5 inches (below min) is rejected', () {
      expect(
        ClothingBusinessRules.isValidMeasurement(MeasurementKey.inseam, 5),
        isFalse,
      );
    });
  });

  group('ClothingBusinessRules.sizeForChest', () {
    test('38 inch chest -> M', () {
      expect(ClothingBusinessRules.sizeForChest(38), equals(ClothingSize.m));
    });
    test('30 inch chest -> XS', () {
      expect(ClothingBusinessRules.sizeForChest(30), equals(ClothingSize.xs));
    });
    test('52 inch chest -> XXXL', () {
      expect(ClothingBusinessRules.sizeForChest(52), equals(ClothingSize.xxxl));
    });
    test('boundary value 36 -> M (smaller bucket excluded)', () {
      expect(ClothingBusinessRules.sizeForChest(36), equals(ClothingSize.m));
    });
  });
}
