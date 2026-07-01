// Unit tests: PaiseCalculator — EXTENDED edge cases
// Covers: percentage discount rounding, tax-inclusive gap, composition scheme
// gap, rounding rule verification, large value overflow, and credit notes.
//
// Source: lib/core/billing/paise_calculator.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/billing/paise_calculator.dart';

void main() {
  // =========================================================================
  // Percentage discount applied as flat paise — rounding verification
  // =========================================================================
  group('PaiseCalculator — percentage discount rounding', () {
    test('12.5% discount on ₹199.99 → correct rounding to nearest paisa', () {
      // ₹199.99 = 19999 paise. 12.5% of 19999 = 2499.875 → round to 2500
      const basePaise = 19999;
      final discountPaise = (basePaise * 1250 + 5000) ~/ 10000;
      // 19999 * 1250 = 24998750, + 5000 = 25003750, ~/10000 = 2500
      expect(discountPaise, 2500);

      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: basePaise,
        quantityMillis: 1000,
        discountPaise: discountPaise,
        gstRateBps: 1800,
        isInterState: false,
      ));
      expect(b.taxablePaise, basePaise - discountPaise);
      // tax = 17499 * 1800 / 10000 = 3149 (floor)
      expect(b.totalTaxPaise, (17499 * 1800) ~/ 10000);
    });

    test('10% discount on ₹0.50 → 5 paise discount', () {
      const basePaise = 50;
      final discountPaise = (basePaise * 1000) ~/ 10000; // 5
      expect(discountPaise, 5);

      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: basePaise,
        quantityMillis: 1000,
        discountPaise: discountPaise,
        gstRateBps: 500,
        isInterState: false,
      ));
      expect(b.taxablePaise, 45);
      expect(b.totalTaxPaise, (45 * 500) ~/ 10000); // 2
    });

    test('33.33% discount on ₹3.00 → 1 paisa precision matters', () {
      const basePaise = 300;
      // 33.33% = 3333 bps; 300 * 3333 / 10000 = 99 (floor)
      final discountPaise = (basePaise * 3333) ~/ 10000;
      expect(discountPaise, 99);

      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: basePaise,
        quantityMillis: 1000,
        discountPaise: discountPaise,
        gstRateBps: 1800,
        isInterState: false,
      ));
      expect(b.taxablePaise, 201);
    });
  });

  // =========================================================================
  // Rounding rule: per-line-item (not invoice-level)
  // =========================================================================
  group('PaiseCalculator — rounding rule verification', () {
    test('tax is computed per line, not on aggregated taxable', () {
      // Two items: ₹3.33 each @ 18%
      // Per-line: tax = 333 * 1800 / 10000 = 59 each → total tax = 118
      // If aggregated first: taxable = 666, tax = 666*1800/10000 = 119
      // PaiseCalculator does per-line, so expect 118.
      final summary = PaiseCalculator.calculateInvoice([
        PaiseLineItem(
          unitPricePaise: 333, quantityMillis: 1000,
          gstRateBps: 1800, isInterState: false,
        ),
        PaiseLineItem(
          unitPricePaise: 333, quantityMillis: 1000,
          gstRateBps: 1800, isInterState: false,
        ),
      ]);
      // Per-line rounding: 59 + 59 = 118 (NOT 119 from aggregate)
      expect(summary.totalTaxPaise, 118);
    });

    test('per-line rounding on 3 items confirms no aggregate bias', () {
      // 3 × ₹1.11 @ 5%: per-line tax = 111*500/10000 = 5 each → 15 total
      // Aggregate: 333*500/10000 = 16
      final summary = PaiseCalculator.calculateInvoice(List.generate(3, (_) =>
        PaiseLineItem(
          unitPricePaise: 111, quantityMillis: 1000,
          gstRateBps: 500, isInterState: false,
        ),
      ));
      expect(summary.totalTaxPaise, 15); // per-line, not 16
    });
  });

  // =========================================================================
  // Discount is applied BEFORE tax (verify existing behavior)
  // =========================================================================
  group('PaiseCalculator — discount timing verification', () {
    test('discount is applied before tax, not after', () {
      // ₹100 item, ₹20 discount, 18% GST
      // BEFORE tax: taxable = 80, tax = 80*1800/10000 = 14, total = 94
      // AFTER tax: tax on full 100 = 18, total = 100+18-20 = 98
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 10000,
        quantityMillis: 1000,
        discountPaise: 2000,
        gstRateBps: 1800,
        isInterState: false,
      ));
      expect(b.taxablePaise, 8000);
      expect(b.totalTaxPaise, 1440); // 8000*1800/10000 = 1440 (before tax)
      expect(b.lineTotalPaise, 9440); // NOT 9800 (after tax)
    });
  });

  // =========================================================================
  // Tax-inclusive pricing — NOW SUPPORTED
  // =========================================================================
  group('PaiseCalculator — tax-inclusive pricing', () {
    test('₹118 MRP inclusive of 18% → base ₹100, tax ₹18', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 11800,
        quantityMillis: 1000,
        gstRateBps: 1800,
        isInterState: false,
        isTaxInclusive: true,
      ));
      // base = 11800 * 10000 / (10000 + 1800) = 118000000 / 11800 = 10000
      expect(b.taxablePaise, 10000);
      expect(b.totalTaxPaise, 1800);
      expect(b.lineTotalPaise, 11800);
    });

    test('₹525 MRP inclusive of 5% → base ₹500, tax ₹25', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 52500,
        quantityMillis: 1000,
        gstRateBps: 500,
        isInterState: false,
        isTaxInclusive: true,
      ));
      expect(b.taxablePaise, 50000);
      expect(b.totalTaxPaise, 2500);
    });

    test('₹128 MRP inclusive of 28% → correct extraction', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 12800,
        quantityMillis: 1000,
        gstRateBps: 2800,
        isInterState: false,
        isTaxInclusive: true,
      ));
      // base = 12800 * 10000 / 12800 = 10000
      expect(b.taxablePaise, 10000);
      expect(b.totalTaxPaise, 2800);
    });

    test('tax-inclusive with 0% rate → no extraction, full amount is taxable', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 10000,
        quantityMillis: 1000,
        gstRateBps: 0,
        isTaxInclusive: true,
      ));
      expect(b.taxablePaise, 10000);
      expect(b.totalTaxPaise, 0);
    });

    test('tax-inclusive inter-state → full IGST, no CGST/SGST', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 11800,
        quantityMillis: 1000,
        gstRateBps: 1800,
        isInterState: true,
        isTaxInclusive: true,
      ));
      expect(b.igstPaise, 1800);
      expect(b.cgstPaise, 0);
      expect(b.sgstPaise, 0);
    });

    test('tax-exclusive (default) unchanged — ₹100 + 18% = ₹118', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 10000,
        quantityMillis: 1000,
        gstRateBps: 1800,
        isTaxInclusive: false, // explicit default
      ));
      expect(b.taxablePaise, 10000);
      expect(b.totalTaxPaise, 1800);
      expect(b.lineTotalPaise, 11800);
    });

    test('tax-inclusive with discount → discount applied to MRP first', () {
      // MRP ₹118 - ₹18 discount = ₹100 inclusive line amount
      // base = 100*10000/11800 = 8474 paise
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 11800,
        quantityMillis: 1000,
        discountPaise: 1800,
        gstRateBps: 1800,
        isTaxInclusive: true,
      ));
      final lineAmount = 11800 - 1800; // 10000
      expect(b.taxablePaise, (lineAmount * 10000) ~/ 11800);
      expect(b.totalTaxPaise, lineAmount - b.taxablePaise);
    });
  });

  // =========================================================================
  // Composition scheme — NOW SUPPORTED
  // =========================================================================
  group('PaiseCalculator — composition scheme', () {
    test('composition merchant: no tax breakup regardless of rate', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 10000,
        quantityMillis: 1000,
        gstRateBps: 1800, // rate is set but ignored
        isCompositionScheme: true,
      ));
      expect(b.totalTaxPaise, 0);
      expect(b.cgstPaise, 0);
      expect(b.sgstPaise, 0);
      expect(b.igstPaise, 0);
      expect(b.rateBps, 0); // shows 0% on invoice
      expect(b.taxablePaise, 10000);
      expect(b.lineTotalPaise, 10000); // no tax added
    });

    test('composition scheme in invoice — all lines tax-free', () {
      final summary = PaiseCalculator.calculateInvoice([
        PaiseLineItem(
          unitPricePaise: 10000, quantityMillis: 1000,
          gstRateBps: 1800, isCompositionScheme: true,
        ),
        PaiseLineItem(
          unitPricePaise: 20000, quantityMillis: 1000,
          gstRateBps: 2800, isCompositionScheme: true,
        ),
      ]);
      expect(summary.totalTaxPaise, 0);
      expect(summary.subtotalPaise, 30000);
      expect(summary.grandTotalPaise, 30000);
    });

    test('composition overrides isInterState — still no tax', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 10000,
        quantityMillis: 1000,
        gstRateBps: 1800,
        isInterState: true,
        isCompositionScheme: true,
      ));
      expect(b.igstPaise, 0);
      expect(b.totalTaxPaise, 0);
    });
  });

  // =========================================================================
  // Large value — no integer overflow (Dart ints are 64-bit)
  // =========================================================================
  group('PaiseCalculator — large value overflow safety', () {
    test('₹10 crore × 100 qty @ 28% — no overflow', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 1000000000,
        quantityMillis: 100000,
        gstRateBps: 2800,
        isInterState: false,
      ));
      expect(b.taxablePaise, 100000000000);
      expect(b.totalTaxPaise, 28000000000);
      expect(b.cgstPaise + b.sgstPaise, b.totalTaxPaise);
    });

    test('large addition in invoice — no overflow', () {
      final items = List.generate(10, (_) => PaiseLineItem(
        unitPricePaise: 100000000,
        quantityMillis: 1000,
        gstRateBps: 2800,
        isInterState: false,
      ));
      final summary = PaiseCalculator.calculateInvoice(items);
      expect(summary.subtotalPaise, 1000000000);
      expect(summary.grandTotalPaise,
          summary.subtotalPaise + summary.totalTaxPaise);
    });
  });

  // =========================================================================
  // Negative amounts (credit note / return) — NOW SUPPORTED
  // =========================================================================
  group('PaiseCalculator — negative amounts (credit notes)', () {
    test('discount > price → negative taxable produces negative tax', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 100,
        quantityMillis: 1000,
        discountPaise: 500,
        gstRateBps: 1800,
        isInterState: false,
      ));
      // taxable = 100 - 500 = -400
      expect(b.taxablePaise, -400);
      // tax = -400 * 1800 / 10000 = -72 (integer division toward zero)
      expect(b.totalTaxPaise, -72);
      expect(b.lineTotalPaise, -400 + (-72));
    });

    test('negative discount (surcharge) increases taxable', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 10000,
        quantityMillis: 1000,
        discountPaise: -500,
        gstRateBps: 1800,
        isInterState: false,
      ));
      expect(b.taxablePaise, 10500);
      expect(b.totalTaxPaise, (10500 * 1800) ~/ 10000);
    });

    test('credit note: cgst+sgst split on negative tax', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 0,
        quantityMillis: 1000,
        discountPaise: 10000,
        gstRateBps: 1800,
        isInterState: false,
      ));
      // taxable = -10000, tax = -1800
      expect(b.totalTaxPaise, -1800);
      expect(b.cgstPaise, -900);
      expect(b.sgstPaise, -900);
      expect(b.cgstPaise + b.sgstPaise, b.totalTaxPaise);
    });

    test('credit note inter-state: negative IGST', () {
      final b = PaiseCalculator.calculateLineItem(PaiseLineItem(
        unitPricePaise: 0,
        quantityMillis: 1000,
        discountPaise: 10000,
        gstRateBps: 1800,
        isInterState: true,
      ));
      expect(b.igstPaise, -1800);
      expect(b.cgstPaise, 0);
      expect(b.sgstPaise, 0);
    });
  });
}

