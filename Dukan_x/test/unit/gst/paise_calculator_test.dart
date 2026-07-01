// Unit tests: PaiseCalculator — Paise-Only GST Calculator
// Source: lib/core/billing/paise_calculator.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/billing/paise_calculator.dart';

void main() {
  PaiseLineItem _intra({
    required int unitPricePaise,
    int quantityMillis = 1000,
    int discountPaise = 0,
    required int gstRateBps,
  }) => PaiseLineItem(
    unitPricePaise: unitPricePaise, quantityMillis: quantityMillis,
    discountPaise: discountPaise, gstRateBps: gstRateBps, isInterState: false,
  );

  PaiseLineItem _inter({
    required int unitPricePaise,
    int quantityMillis = 1000,
    int discountPaise = 0,
    required int gstRateBps,
  }) => PaiseLineItem(
    unitPricePaise: unitPricePaise, quantityMillis: quantityMillis,
    discountPaise: discountPaise, gstRateBps: gstRateBps, isInterState: true,
  );

  // === Intra-State CGST+SGST ===
  group('calculateLineItem — intra-state', () {
    test('18% on ₹100 → tax 1800, cgst 900, sgst 900', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 10000, gstRateBps: 1800));
      expect(b.taxablePaise, 10000);
      expect(b.totalTaxPaise, 1800);
      expect(b.cgstPaise, 900);
      expect(b.sgstPaise, 900);
      expect(b.igstPaise, 0);
      expect(b.lineTotalPaise, 11800);
    });

    test('5% slab on ₹499.99', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 49999, gstRateBps: 500));
      expect(b.totalTaxPaise, 2499);
      expect(b.cgstPaise, 1249);
      expect(b.sgstPaise, 1250); // absorbs remainder
      expect(b.cgstPaise + b.sgstPaise, b.totalTaxPaise);
    });

    test('12% slab on ₹1', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 100, gstRateBps: 1200));
      expect(b.totalTaxPaise, 12);
      expect(b.cgstPaise, 6);
      expect(b.sgstPaise, 6);
    });

    test('28% slab on ₹999999.99', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 99999999, gstRateBps: 2800));
      expect(b.totalTaxPaise, 27999999);
      expect(b.cgstPaise + b.sgstPaise, b.totalTaxPaise);
    });

    test('0% slab — zero tax', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 50000, gstRateBps: 0));
      expect(b.totalTaxPaise, 0);
      expect(b.cgstPaise, 0);
      expect(b.sgstPaise, 0);
    });

    test('odd tax → SGST absorbs rounding remainder', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 333, gstRateBps: 1800));
      expect(b.totalTaxPaise, 59);
      expect(b.cgstPaise, 29);
      expect(b.sgstPaise, 30);
    });
  });

  // === Inter-State IGST ===
  group('calculateLineItem — inter-state', () {
    test('18% inter → full IGST, no CGST/SGST', () {
      final b = PaiseCalculator.calculateLineItem(
        _inter(unitPricePaise: 10000, gstRateBps: 1800));
      expect(b.igstPaise, 1800);
      expect(b.cgstPaise, 0);
      expect(b.sgstPaise, 0);
    });

    test('every slab inter-state: CGST & SGST always 0', () {
      for (final bps in [0, 500, 1200, 1800, 2800]) {
        final b = PaiseCalculator.calculateLineItem(
          _inter(unitPricePaise: 10000, gstRateBps: bps));
        expect(b.cgstPaise, 0);
        expect(b.sgstPaise, 0);
        expect(b.igstPaise, b.totalTaxPaise);
      }
    });
  });

  // === Quantity handling ===
  group('calculateLineItem — quantity', () {
    test('1.5 kg × ₹100/kg → taxable 15000 paise', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 10000, quantityMillis: 1500, gstRateBps: 1800));
      expect(b.taxablePaise, 15000);
    });

    test('0.001 unit × ₹1000 → taxable 100 paise', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 100000, quantityMillis: 1, gstRateBps: 1800));
      expect(b.taxablePaise, 100);
    });
  });

  // === Discount ===
  group('calculateLineItem — discount', () {
    test('₹10 discount on ₹100 → taxable 9000 paise', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 10000, discountPaise: 1000, gstRateBps: 1800));
      expect(b.taxablePaise, 9000);
      expect(b.totalTaxPaise, 1620);
    });

    test('discount > price → negative taxable (credit note)', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 100, discountPaise: 500, gstRateBps: 1800));
      expect(b.taxablePaise, -400);
      expect(b.totalTaxPaise, -72);
    });

    test('discount == price → taxable 0', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 5000, discountPaise: 5000, gstRateBps: 1800));
      expect(b.taxablePaise, 0);
      expect(b.totalTaxPaise, 0);
    });
  });

  // === Zero edge cases ===
  group('calculateLineItem — zero edge cases', () {
    test('zero quantity → no crash', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 10000, quantityMillis: 0, gstRateBps: 1800));
      expect(b.taxablePaise, 0);
      expect(b.totalTaxPaise, 0);
    });

    test('zero price → no crash', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 0, gstRateBps: 1800));
      expect(b.taxablePaise, 0);
    });
  });

  // === Full Invoice ===
  group('calculateInvoice', () {
    test('multi-line different slabs sum correctly', () {
      final summary = PaiseCalculator.calculateInvoice([
        _intra(unitPricePaise: 49999, gstRateBps: 500),
        _intra(unitPricePaise: 10000, gstRateBps: 1200),
        _intra(unitPricePaise: 10000, gstRateBps: 1800),
        _intra(unitPricePaise: 10000, gstRateBps: 2800),
      ]);
      expect(summary.subtotalPaise, 49999 + 10000 + 10000 + 10000);
      expect(summary.grandTotalPaise,
          summary.subtotalPaise + summary.totalTaxPaise);
    });

    test('mixed intra+inter → cgst/sgst vs igst', () {
      final s = PaiseCalculator.calculateInvoice([
        _intra(unitPricePaise: 10000, gstRateBps: 1800),
        _inter(unitPricePaise: 10000, gstRateBps: 1800),
      ]);
      expect(s.totalCgstPaise, 900);
      expect(s.totalSgstPaise, 900);
      expect(s.totalIgstPaise, 1800);
    });

    test('empty invoice → all zeroes', () {
      final s = PaiseCalculator.calculateInvoice([]);
      expect(s.subtotalPaise, 0);
      expect(s.totalTaxPaise, 0);
      expect(s.grandTotalPaise, 0);
    });

    test('grandTotal always equals subtotal + totalTax', () {
      final s = PaiseCalculator.calculateInvoice([
        _intra(unitPricePaise: 12345, gstRateBps: 500),
        _inter(unitPricePaise: 67890, gstRateBps: 2800),
      ]);
      expect(s.grandTotalPaise, s.subtotalPaise + s.totalTaxPaise);
    });
  });

  // === PaiseLineItem.fromRupees ===
  group('PaiseLineItem.fromRupees', () {
    test('₹123.45 → 12345 paise', () {
      final item = PaiseLineItem.fromRupees(
        unitPrice: 123.45, quantity: 1.0, gstRatePercent: 18.0);
      expect(item.unitPricePaise, 12345);
      expect(item.quantityMillis, 1000);
      expect(item.gstRateBps, 1800);
    });

    test('₹0.01 → 1 paise', () {
      final item = PaiseLineItem.fromRupees(
        unitPrice: 0.01, quantity: 1.0, gstRatePercent: 5.0);
      expect(item.unitPricePaise, 1);
    });
  });

  // === Conversion utilities ===
  group('PaiseCalculator — conversions', () {
    test('rupeesToPaise roundtrip', () {
      expect(PaiseCalculator.rupeesToPaise(1.0), 100);
      expect(PaiseCalculator.rupeesToPaise(0.50), 50);
      expect(PaiseCalculator.rupeesToPaise(999999.99), 99999999);
    });

    test('paiseToRupees', () {
      expect(PaiseCalculator.paiseToRupees(1), 0.01);
      expect(PaiseCalculator.paiseToRupees(99), 0.99);
      expect(PaiseCalculator.paiseToRupees(100000000), 1000000.00);
    });

    test('percentToBps / bpsToPercent', () {
      expect(PaiseCalculator.percentToBps(18.0), 1800);
      expect(PaiseCalculator.bpsToPercent(2800), 28.0);
    });

    test('roundtrip paise→rupees→paise', () {
      const original = 12345;
      expect(PaiseCalculator.rupeesToPaise(
        PaiseCalculator.paiseToRupees(original)), original);
    });
  });

  // === Display getters ===
  group('PaiseTaxBreakup — display getters', () {
    test('rupee getters correct', () {
      final b = PaiseCalculator.calculateLineItem(
        _intra(unitPricePaise: 10000, gstRateBps: 1800));
      expect(b.taxableRupees, 100.0);
      expect(b.totalTaxRupees, 18.0);
      expect(b.cgstRupees, 9.0);
      expect(b.sgstRupees, 9.0);
      expect(b.lineTotalRupees, 118.0);
      expect(b.ratePercent, 18.0);
      expect(b.halfRatePercent, 9.0);
    });
  });
}
