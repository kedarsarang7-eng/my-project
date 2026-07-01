// Worked-example test for D11 pharmacy business rules
// (clauses 2.16 + 2.19 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/pharmacy/utils/pharmacy_business_rules.dart';

void main() {
  group('PharmacyBusinessRules.isBatchUsable', () {
    test('expiry tomorrow is usable', () {
      expect(
        PharmacyBusinessRules.isBatchUsable(
          expiryDate: DateTime(2024, 6, 16),
          today: DateTime(2024, 6, 15),
        ),
        isTrue,
      );
    });
    test('same-day expiry is still usable', () {
      expect(
        PharmacyBusinessRules.isBatchUsable(
          expiryDate: DateTime(2024, 6, 15),
          today: DateTime(2024, 6, 15),
        ),
        isTrue,
      );
    });
    test('expiry yesterday is not usable', () {
      expect(
        PharmacyBusinessRules.isBatchUsable(
          expiryDate: DateTime(2024, 6, 14),
          today: DateTime(2024, 6, 15),
        ),
        isFalse,
      );
    });
  });

  group('PharmacyBusinessRules.isExpiringSoon', () {
    test('expires in 30 days, 90-day window -> true', () {
      expect(
        PharmacyBusinessRules.isExpiringSoon(
          expiryDate: DateTime(2024, 7, 15),
          today: DateTime(2024, 6, 15),
        ),
        isTrue,
      );
    });
    test('expires in 120 days, 90-day window -> false', () {
      expect(
        PharmacyBusinessRules.isExpiringSoon(
          expiryDate: DateTime(2024, 10, 13),
          today: DateTime(2024, 6, 15),
        ),
        isFalse,
      );
    });
  });

  group('PharmacyBusinessRules schedule rules', () {
    test('OTC dispenses without prescription', () {
      expect(
        PharmacyBusinessRules.canDispenseWithoutPrescription(DrugSchedule.otc),
        isTrue,
      );
    });
    test('Schedule H needs prescription', () {
      expect(
        PharmacyBusinessRules.canDispenseWithoutPrescription(DrugSchedule.h),
        isFalse,
      );
    });
    test('H1 / X require retention', () {
      expect(
        PharmacyBusinessRules.requiresPrescriptionRetention(DrugSchedule.h1),
        isTrue,
      );
      expect(
        PharmacyBusinessRules.requiresPrescriptionRetention(DrugSchedule.x),
        isTrue,
      );
      expect(
        PharmacyBusinessRules.requiresPrescriptionRetention(DrugSchedule.h),
        isFalse,
      );
    });
  });
}
