// Worked-example test for D11 auto_parts business rules
// (clauses 2.16 + 2.19 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/auto_parts/utils/auto_parts_business_rules.dart';

void main() {
  group('AutoPartsBusinessRules.isValidTransition', () {
    test('intake -> diagnosis is allowed', () {
      expect(
        AutoPartsBusinessRules.isValidTransition(
          JobCardStatus.intake,
          JobCardStatus.diagnosis,
        ),
        isTrue,
      );
    });
    test('intake -> delivered is rejected', () {
      expect(
        AutoPartsBusinessRules.isValidTransition(
          JobCardStatus.intake,
          JobCardStatus.delivered,
        ),
        isFalse,
      );
    });
    test('any -> cancelled is allowed except from terminal states', () {
      for (final s in JobCardStatus.values) {
        final allowed = AutoPartsBusinessRules.isValidTransition(
          s,
          JobCardStatus.cancelled,
        );
        final expected =
            s != JobCardStatus.cancelled && s != JobCardStatus.delivered;
        expect(allowed, expected, reason: 'cancel from $s');
      }
    });
    test('delivered is terminal', () {
      for (final s in JobCardStatus.values) {
        expect(
          AutoPartsBusinessRules.isValidTransition(JobCardStatus.delivered, s),
          isFalse,
        );
      }
    });
  });

  group('AutoPartsBusinessRules.computeJobCardTotal', () {
    test('worked example: labour 500 + parts (199.99 + 50.01) -> 750', () {
      final total = AutoPartsBusinessRules.computeJobCardTotal(
        labourCharges: 500,
        partsLineTotals: const [199.99, 50.01],
      );
      expect(total, equals(750.0));
    });
    test('discount and tax apply with paise precision', () {
      final total = AutoPartsBusinessRules.computeJobCardTotal(
        labourCharges: 500,
        partsLineTotals: const [100, 200],
        discount: 50,
        taxAmount: 90,
      );
      // 500 + 300 - 50 + 90 = 840
      expect(total, equals(840.0));
    });
  });
}
