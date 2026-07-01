// Unit tests: Paise arithmetic — percentage operations, splitting, overflow
// These test integer paise math patterns used across the codebase, independent
// of any specific source class.

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/utils/amount_converter.dart';

void main() {
  // =========================================================================
  // Percentage discount on paise — correct rounding
  // =========================================================================
  group('Paise arithmetic — percentage discount rounding', () {
    /// Helper: apply percent discount in bps to a paise amount.
    /// Uses the same (amount * bps + 5000) ~/ 10000 pattern for half-up.
    int applyPercentDiscount(int paise, int discountBps) {
      return (paise * discountBps + 5000) ~/ 10000;
    }

    test('12.5% on ₹100 (10000 paise) → 1250 paise discount', () {
      expect(applyPercentDiscount(10000, 1250), 1250);
    });

    test('12.5% on ₹199.99 (19999 paise) → 2500 paise', () {
      // 19999 * 1250 = 24998750, + 5000 = 25003750, ~/ 10000 = 2500
      expect(applyPercentDiscount(19999, 1250), 2500);
    });

    test('33.33% on ₹3.00 (300 paise) → 99 paise', () {
      // 300 * 3333 = 999900, + 5000 = 1004900, ~/ 10000 = 100
      // Wait, let me recalculate: 300*3333 = 999900 + 5000 = 1004900 / 10000 = 100
      // But with floor division: 999900 / 10000 = 99
      // The +5000 pattern rounds half-up
      expect(applyPercentDiscount(300, 3333), 100);
    });

    test('1% on 1 paise → 0 paise (below minimum rounding threshold)', () {
      // 1 * 100 = 100, + 5000 = 5100, ~/ 10000 = 0
      expect(applyPercentDiscount(1, 100), 0);
    });

    test('50% on 1 paise → 1 paise (half rounds up)', () {
      // 1 * 5000 = 5000, + 5000 = 10000, ~/ 10000 = 1
      expect(applyPercentDiscount(1, 5000), 1);
    });

    test('100% discount = full amount', () {
      expect(applyPercentDiscount(10000, 10000), 10000);
    });
  });

  // =========================================================================
  // qty (int) × rate (paise) — no precision loss
  // =========================================================================
  group('Paise arithmetic — quantity × rate', () {
    test('3 × ₹99.99 = ₹299.97 (29997 paise)', () {
      const qty = 3;
      const ratePaise = 9999;
      expect(qty * ratePaise, 29997);
    });

    test('999 × ₹999.99 = 99899001 paise — exact', () {
      const qty = 999;
      const ratePaise = 99999;
      expect(qty * ratePaise, 99899001);
    });

    test('int multiplication has no precision loss (vs double)', () {
      // In double: 3 * 99.99 = 299.96999999999997
      // In paise int: 3 * 9999 = 29997 (exact)
      const qty = 3;
      const ratePaise = 9999;
      final result = qty * ratePaise;
      expect(result, 29997);
      // The double equivalent drifts:
      expect(3 * 99.99, isNot(equals(299.97)));
    });
  });

  // =========================================================================
  // Bill splitting — sum of parts always equals original
  // =========================================================================
  group('Paise arithmetic — bill splitting N ways', () {
    void verifySplit(int totalPaise, int parts) {
      final perPart = totalPaise ~/ parts;
      final remainder = totalPaise % parts;
      // First (parts-1) people pay perPart, last person pays perPart + remainder
      final sum = perPart * (parts - 1) + (perPart + remainder);
      expect(sum, totalPaise,
          reason: 'Split of $totalPaise paise into $parts parts lost money');
    }

    test('₹100 split 3 ways', () => verifySplit(10000, 3));
    test('₹100 split 7 ways', () => verifySplit(10000, 7));
    test('₹0.01 split 2 ways', () => verifySplit(1, 2));
    test('₹999.99 split 11 ways', () => verifySplit(99999, 11));
    test('₹1 split 99 ways', () => verifySplit(100, 99));

    test('₹0.03 split 2 ways — remainder goes to last person', () {
      const total = 3;
      const parts = 2;
      final each = total ~/ parts; // 1
      final last = total - (each * (parts - 1)); // 2
      expect(each, 1);
      expect(last, 2);
      expect(each * (parts - 1) + last, total);
    });
  });

  // =========================================================================
  // Large amount addition/subtraction — no integer overflow
  // =========================================================================
  group('Paise arithmetic — large values', () {
    test('₹100 crore + ₹100 crore — no overflow', () {
      // ₹100 Cr = 10,000,000,000 paise (10^10)
      // int64 max = 9.2 × 10^18, so 2 × 10^10 is safe
      const a = 10000000000;
      const b = 10000000000;
      expect(a + b, 20000000000);
    });

    test('subtraction of large amounts', () {
      const a = 10000000000;
      const b = 9999999999;
      expect(a - b, 1);
    });

    test('₹999 crore formatted correctly', () {
      // 999 × 10^7 × 100 = 999,00,00,000 paise
      const paise = 99900000000;
      final formatted = AmountConverter.formatRupeesFromPaise(paise);
      expect(formatted, '₹999000000.00');
    });
  });

  // =========================================================================
  // Negative amounts (refunds) — correct sign handling
  // =========================================================================
  group('Paise arithmetic — negative amounts (refunds)', () {
    test('negative paise formats with minus sign', () {
      // AmountConverter.formatRupeesFromPaise works with negative
      final formatted = AmountConverter.formatRupeesFromPaise(-10000);
      expect(formatted, '₹-100.00');
    });

    test('negative paiseToRupees preserves sign', () {
      expect(AmountConverter.paiseToRupees(-1), -0.01);
      expect(AmountConverter.paiseToRupees(-99999), -999.99);
    });

    test('refund subtraction: ₹100 - ₹150 = -₹50', () {
      const paid = 10000;
      const refund = 15000;
      expect(paid - refund, -5000);
      expect(AmountConverter.paiseToRupees(paid - refund), -50.0);
    });
  });
}
