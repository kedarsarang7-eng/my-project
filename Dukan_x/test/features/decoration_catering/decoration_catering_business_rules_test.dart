// Worked-example test for D11 decoration_catering business rules
// (clauses 2.16 + 2.19 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/decoration_catering/utils/decoration_catering_business_rules.dart';

void main() {
  group('DecorationCateringBusinessRules.computeQuoteTotal', () {
    test('₹450/head x 120 - 1000 disc + 5400 tax = 58400', () {
      final total = DecorationCateringBusinessRules.computeQuoteTotal(
        perHeadPrice: 450,
        headcount: 120,
        discount: 1000,
        taxAmount: 5400,
      );
      // 450*120 = 54000, +5400 = 59400, -1000 = 58400
      expect(total, equals(58400.0));
    });
    test('zero headcount -> 0', () {
      expect(
        DecorationCateringBusinessRules.computeQuoteTotal(
          perHeadPrice: 450,
          headcount: 0,
        ),
        equals(0.0),
      );
    });
    test('half-up rounding to paise', () {
      // 33.33 * 3 = 99.99 (no rounding artefact thanks to Decimal)
      final total = DecorationCateringBusinessRules.computeQuoteTotal(
        perHeadPrice: 33.33,
        headcount: 3,
      );
      expect(total, equals(99.99));
    });
  });

  group('DecorationCateringBusinessRules.advanceForfeitedOnCancel', () {
    test('cancel inside 7-day window forfeits', () {
      expect(
        DecorationCateringBusinessRules.advanceForfeitedOnCancel(
          DateTime(2024, 6, 10),
          DateTime(2024, 6, 5),
        ),
        isTrue,
      );
    });
    test('cancel outside window does not forfeit', () {
      expect(
        DecorationCateringBusinessRules.advanceForfeitedOnCancel(
          DateTime(2024, 6, 10),
          DateTime(2024, 5, 20),
        ),
        isFalse,
      );
    });
    test('cancel on lock-in cutoff still forfeits', () {
      // event 2024-06-10, 7-day window -> cutoff 2024-06-03; cancel on 06-03
      expect(
        DecorationCateringBusinessRules.advanceForfeitedOnCancel(
          DateTime(2024, 6, 10),
          DateTime(2024, 6, 3),
        ),
        isTrue,
      );
    });
  });
}
