// Worked-example test for D11 clinic business rules
// (clauses 2.16 + 2.19 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/clinic/utils/clinic_business_rules.dart';

void main() {
  group('ClinicBusinessRules.nextToken', () {
    test('first token is 1', () {
      expect(ClinicBusinessRules.nextToken(null), equals(1));
    });
    test('subsequent tokens increment', () {
      expect(ClinicBusinessRules.nextToken(7), equals(8));
    });
  });

  group('ClinicBusinessRules.isValidSlot', () {
    test('15-minute slot is valid', () {
      expect(
        ClinicBusinessRules.isValidSlot(
          DateTime(2024, 6, 15, 10, 0),
          DateTime(2024, 6, 15, 10, 15),
        ),
        isTrue,
      );
    });
    test('zero-length slot rejected', () {
      expect(
        ClinicBusinessRules.isValidSlot(
          DateTime(2024, 6, 15, 10, 0),
          DateTime(2024, 6, 15, 10, 0),
        ),
        isFalse,
      );
    });
    test('over-max slot rejected', () {
      expect(
        ClinicBusinessRules.isValidSlot(
          DateTime(2024, 6, 15, 10, 0),
          DateTime(2024, 6, 15, 13, 0),
        ),
        isFalse,
      );
    });
  });

  group('ClinicBusinessRules.slotsOverlap', () {
    test('overlapping slots detected', () {
      expect(
        ClinicBusinessRules.slotsOverlap(
          DateTime(2024, 6, 15, 10, 0),
          DateTime(2024, 6, 15, 10, 30),
          DateTime(2024, 6, 15, 10, 15),
          DateTime(2024, 6, 15, 10, 45),
        ),
        isTrue,
      );
    });
    test('back-to-back slots do not overlap', () {
      expect(
        ClinicBusinessRules.slotsOverlap(
          DateTime(2024, 6, 15, 10, 0),
          DateTime(2024, 6, 15, 10, 30),
          DateTime(2024, 6, 15, 10, 30),
          DateTime(2024, 6, 15, 11, 0),
        ),
        isFalse,
      );
    });
  });
}
