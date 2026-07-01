// Worked-example test for D11 petrol_pump business rules
// (clauses 2.16 + 2.19 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/petrol_pump/utils/petrol_pump_business_rules.dart';

void main() {
  group('PetrolPumpBusinessRules.dispensedLitres', () {
    test('start 1000 -> end 1500 = 500 litres', () {
      expect(
        PetrolPumpBusinessRules.dispensedLitres(
          startReading: 1000,
          endReading: 1500,
        ),
        equals(500.0),
      );
    });
    test('rolls over correctly: start 999500 -> end 100 = 600', () {
      expect(
        PetrolPumpBusinessRules.dispensedLitres(
          startReading: 999500,
          endReading: 100,
        ),
        equals(600.0),
      );
    });
    test('negative input is clamped to 0', () {
      expect(
        PetrolPumpBusinessRules.dispensedLitres(
          startReading: -1,
          endReading: 100,
        ),
        equals(0.0),
      );
    });
  });

  group('PetrolPumpBusinessRules.saleValue', () {
    test('worked example: 25.5 L @ ₹103.45/L', () {
      // 25.5 * 103.45 = 2637.975 -> half-up to 2637.98
      final v = PetrolPumpBusinessRules.saleValue(
        dispensedLitres: 25.5,
        pricePerLitre: 103.45,
      );
      expect(v, equals(2637.98));
    });
  });

  group('PetrolPumpBusinessRules.cashVariance', () {
    test('short fall yields positive variance', () {
      expect(
        PetrolPumpBusinessRules.cashVariance(
          expectedCash: 10000,
          reportedCash: 9950,
        ),
        equals(50.0),
      );
    });
    test('surplus yields negative variance', () {
      expect(
        PetrolPumpBusinessRules.cashVariance(
          expectedCash: 10000,
          reportedCash: 10025,
        ),
        equals(-25.0),
      );
    });
  });
}
