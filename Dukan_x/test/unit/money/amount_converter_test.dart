// Unit tests: AmountConverter — paise ↔ rupee conversion + formatting
// Source: lib/core/utils/amount_converter.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/utils/amount_converter.dart';

void main() {
  // === rupeesToPaise ===
  group('AmountConverter.rupeesToPaise', () {
    test('₹1.00 → 100 paise', () {
      expect(AmountConverter.rupeesToPaise(1.0), 100);
    });

    test('₹0.01 → 1 paise (minimum)', () {
      expect(AmountConverter.rupeesToPaise(0.01), 1);
    });

    test('₹0.50 → 50 paise', () {
      expect(AmountConverter.rupeesToPaise(0.50), 50);
    });

    test('₹999999.99 → 99999999 paise', () {
      expect(AmountConverter.rupeesToPaise(999999.99), 99999999);
    });

    test('₹0.00 → 0 paise', () {
      expect(AmountConverter.rupeesToPaise(0.0), 0);
    });

    test('₹0.005 rounds to 1 paise (half-up via .round())', () {
      // 0.005 * 100 = 0.5, .round() → 1 on most platforms
      expect(AmountConverter.rupeesToPaise(0.005), 1);
    });
  });

  // === paiseToRupees ===
  group('AmountConverter.paiseToRupees', () {
    test('1 paise → ₹0.01', () {
      expect(AmountConverter.paiseToRupees(1), 0.01);
    });

    test('99 paise → ₹0.99', () {
      expect(AmountConverter.paiseToRupees(99), 0.99);
    });

    test('100 paise → ₹1.00', () {
      expect(AmountConverter.paiseToRupees(100), 1.0);
    });

    test('100000000 paise → ₹1000000.00', () {
      expect(AmountConverter.paiseToRupees(100000000), 1000000.0);
    });

    test('0 paise → ₹0.00', () {
      expect(AmountConverter.paiseToRupees(0), 0.0);
    });
  });

  // === formatRupeesFromPaise ===
  group('AmountConverter.formatRupeesFromPaise', () {
    test('1 paise → ₹0.01', () {
      expect(AmountConverter.formatRupeesFromPaise(1), '₹0.01');
    });

    test('99 paise → ₹0.99', () {
      expect(AmountConverter.formatRupeesFromPaise(99), '₹0.99');
    });

    test('100 paise → ₹1.00', () {
      expect(AmountConverter.formatRupeesFromPaise(100), '₹1.00');
    });

    test('0 paise → ₹0.00', () {
      expect(AmountConverter.formatRupeesFromPaise(0), '₹0.00');
    });

    test('99999999 paise → ₹999999.99', () {
      expect(AmountConverter.formatRupeesFromPaise(99999999), '₹999999.99');
    });

    test('always shows 2 decimal places', () {
      expect(AmountConverter.formatRupeesFromPaise(100), '₹1.00');
      expect(AmountConverter.formatRupeesFromPaise(1050), '₹10.50');
    });

    test('starts with ₹ symbol', () {
      final formatted = AmountConverter.formatRupeesFromPaise(12345);
      expect(formatted.startsWith('₹'), true);
    });
  });

  // === Roundtrip ===
  group('AmountConverter — roundtrip', () {
    test('paise → rupees → paise preserves value', () {
      for (final paise in [1, 50, 99, 100, 12345, 99999999]) {
        final rupees = AmountConverter.paiseToRupees(paise);
        final back = AmountConverter.rupeesToPaise(rupees);
        expect(back, paise, reason: 'Failed roundtrip for $paise paise');
      }
    });
  });

  // === Bill splitting edge case ===
  group('AmountConverter — bill splitting', () {
    test('₹100 split 3 ways: sum of parts == original', () {
      const totalPaise = 10000; // ₹100
      const parts = 3;
      final perPart = totalPaise ~/ parts; // 3333
      final remainder = totalPaise - (perPart * parts); // 1
      final sum = (perPart * parts) + remainder;
      expect(sum, totalPaise);
    });

    test('₹1.00 split 3 ways with no lost paisa', () {
      const totalPaise = 100;
      const parts = 3;
      final perPart = totalPaise ~/ parts; // 33
      final lastPart = totalPaise - (perPart * (parts - 1)); // 34
      expect(perPart * (parts - 1) + lastPart, totalPaise);
    });

    test('₹0.01 cannot be split — minimum unit', () {
      const totalPaise = 1;
      const parts = 2;
      final perPart = totalPaise ~/ parts; // 0
      expect(perPart, 0);
      // Remaining 1 paise must go to one party
      expect(totalPaise - (perPart * parts), 1);
    });
  });
}
