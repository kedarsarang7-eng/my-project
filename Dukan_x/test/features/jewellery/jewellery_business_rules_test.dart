// Worked-example test for D11 jewellery business rules
// (clauses 2.16 + 2.19 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/jewellery/utils/jewellery_business_rules.dart';

void main() {
  group('JewelleryBusinessRules.finenessFor', () {
    test('24K is 1.0', () {
      expect(JewelleryBusinessRules.finenessFor(GoldPurity.k24), equals(1.0));
    });
    test('22K is 22/24', () {
      expect(
        JewelleryBusinessRules.finenessFor(GoldPurity.k22),
        closeTo(0.9166666, 1e-6),
      );
    });
    test('14K is 14/24', () {
      expect(
        JewelleryBusinessRules.finenessFor(GoldPurity.k14),
        closeTo(0.5833333, 1e-6),
      );
    });
  });

  group('JewelleryBusinessRules.billTotal', () {
    test('22K, 10g, ₹6000/g, ₹500 making, no tax/discount', () {
      // gold = 10 * 22/24 * 6000 = 55000.00
      // total = 55000 + 500 = 55500
      final total = JewelleryBusinessRules.billTotal(
        grossWeightGrams: 10,
        purity: GoldPurity.k22,
        ratePerGram24K: 6000,
        makingCharges: 500,
      );
      expect(total, equals(55500.0));
    });
    test('discount and tax adjust the gross', () {
      // gold = 100.00, +10 making, +5 tax, -15 discount = 100.00
      final total = JewelleryBusinessRules.billTotal(
        grossWeightGrams: 1,
        purity: GoldPurity.k24,
        ratePerGram24K: 100,
        makingCharges: 10,
        taxAmount: 5,
        discount: 15,
      );
      expect(total, equals(100.0));
    });
    test('negative weight clamps to 0', () {
      expect(
        JewelleryBusinessRules.billTotal(
          grossWeightGrams: -1,
          purity: GoldPurity.k24,
          ratePerGram24K: 100,
        ),
        equals(0.0),
      );
    });
  });

  group('JewelleryBusinessRules.exchangeCredit', () {
    test('worked example: 5g 22K @ ₹5800/g buyback', () {
      final credit = JewelleryBusinessRules.exchangeCredit(
        grossWeightGrams: 5,
        purity: GoldPurity.k22,
        buybackRatePerGram24K: 5800,
      );
      // 5 * 22/24 * 5800 = 26583.333... -> 26583.33
      expect(credit, equals(26583.33));
    });
  });
}
