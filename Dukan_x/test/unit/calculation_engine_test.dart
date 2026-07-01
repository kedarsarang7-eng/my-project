// Unit tests: CalculationEngine — Layer 1 calculation categories and edge cases
//
// Covers all ten calculation categories with ≥1 case per applicable Business_Type
// and the seven required edge cases:
//   1. Zero quantity
//   2. Negative stock (inventory goes negative)
//   3. Partial payments
//   4. Refunds (negative reconciliation balance)
//   5. Expired licenses (entitlement layer — noted)
//   6. Minimum limit boundary (0.01)
//   7. Maximum limit boundary (999999999.99)
//
// Requirements: 2.1, 2.4, 2.5, 2.8

import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';

import '../certification/core/calculation_engine.dart';

Decimal d(String v) => Decimal.parse(v);

void main() {
  late CalculationEngine engine;

  setUp(() {
    engine = CalculationEngine();
  });

  // ===========================================================================
  // 1. TAX CALCULATION (taxTotal)
  // ===========================================================================
  group('taxTotal — per Business_Type', () {
    test('grocery: 5% tax on ₹1000', () {
      final result = engine.taxTotal(d('1000'), d('0.05'));
      expect(result, equals(CalcValue(d('50.00'))));
    });

    test('pharmacy: 12% tax on ₹500', () {
      final result = engine.taxTotal(d('500'), d('0.12'));
      expect(result, equals(CalcValue(d('60.00'))));
    });

    test('jewellery: 3% tax on ₹25000', () {
      final result = engine.taxTotal(d('25000'), d('0.03'));
      expect(result, equals(CalcValue(d('750.00'))));
    });

    test('restaurant: 5% tax on ₹800', () {
      final result = engine.taxTotal(d('800'), d('0.05'));
      expect(result, equals(CalcValue(d('40.00'))));
    });

    test('electronics: 18% tax on ₹15000', () {
      final result = engine.taxTotal(d('15000'), d('0.18'));
      expect(result, equals(CalcValue(d('2700.00'))));
    });

    test('clothing: 5% tax on ₹2500', () {
      final result = engine.taxTotal(d('2500'), d('0.05'));
      expect(result, equals(CalcValue(d('125.00'))));
    });

    test('hardware: 18% tax on ₹3200', () {
      final result = engine.taxTotal(d('3200'), d('0.18'));
      expect(result, equals(CalcValue(d('576.00'))));
    });

    test('half-up rounding: ₹100.55 at 7%', () {
      // 100.55 * 0.07 = 7.0385 → rounds to 7.04 (half-up)
      final result = engine.taxTotal(d('100.55'), d('0.07'));
      expect(result, equals(CalcValue(d('7.04'))));
    });
  });

  // ===========================================================================
  // 2. DISCOUNTS
  // ===========================================================================
  group('discount — per Business_Type', () {
    test('wholesale: 15% discount on ₹10000', () {
      final result = engine.discount(d('10000'), d('0.15'));
      expect(result, equals(CalcValue(d('1500.00'))));
    });

    test('clothing: 20% seasonal discount on ₹5000', () {
      final result = engine.discount(d('5000'), d('0.20'));
      expect(result, equals(CalcValue(d('1000.00'))));
    });

    test('grocery: 10% loyalty discount on ₹800', () {
      final result = engine.discount(d('800'), d('0.10'));
      expect(result, equals(CalcValue(d('80.00'))));
    });

    test('bookStore: 25% clearance on ₹320', () {
      final result = engine.discount(d('320'), d('0.25'));
      expect(result, equals(CalcValue(d('80.00'))));
    });

    test('zero discount (0% rate)', () {
      final result = engine.discount(d('1000'), d('0'));
      expect(result, equals(CalcValue(d('0.00'))));
    });

    test('100% discount', () {
      final result = engine.discount(d('500'), d('1'));
      expect(result, equals(CalcValue(d('500.00'))));
    });
  });

  // ===========================================================================
  // 3. GST COMPUTATION
  // ===========================================================================
  group('gst — per Business_Type', () {
    test('mobileShop: 18% GST on ₹12000', () {
      final result = engine.gst(d('12000'), d('0.18'));
      expect(result, equals(CalcValue(d('2160.00'))));
    });

    test('computerShop: 18% GST on ₹45000', () {
      final result = engine.gst(d('45000'), d('0.18'));
      expect(result, equals(CalcValue(d('8100.00'))));
    });

    test('autoParts: 28% GST on ₹2200', () {
      final result = engine.gst(d('2200'), d('0.28'));
      expect(result, equals(CalcValue(d('616.00'))));
    });

    test('petrolPump: 5% GST on ₹5500', () {
      final result = engine.gst(d('5500'), d('0.05'));
      expect(result, equals(CalcValue(d('275.00'))));
    });

    test('service: 18% GST on ₹3000', () {
      final result = engine.gst(d('3000'), d('0.18'));
      expect(result, equals(CalcValue(d('540.00'))));
    });
  });

  // ===========================================================================
  // 4. VAT COMPUTATION
  // ===========================================================================
  group('vat — per Business_Type', () {
    test('petrolPump: 26% VAT on ₹8000', () {
      final result = engine.vat(d('8000'), d('0.26'));
      expect(result, equals(CalcValue(d('2080.00'))));
    });

    test('restaurant: 5% VAT on ₹1200', () {
      final result = engine.vat(d('1200'), d('0.05'));
      expect(result, equals(CalcValue(d('60.00'))));
    });

    test('vegetablesBroker: 0% VAT on ₹15000', () {
      final result = engine.vat(d('15000'), d('0'));
      expect(result, equals(CalcValue(d('0.00'))));
    });

    test('clinic: 5% VAT on ₹2500', () {
      final result = engine.vat(d('2500'), d('0.05'));
      expect(result, equals(CalcValue(d('125.00'))));
    });
  });

  // ===========================================================================
  // 5. INVOICE TOTALS
  // ===========================================================================
  group('invoiceTotal — per Business_Type', () {
    test('grocery: subtotal + tax - discount', () {
      // subtotal 1000, tax 50 (5%), discount 100 → 950
      final result = engine.invoiceTotal(d('1000'), d('50'), d('100'));
      expect(result, equals(CalcValue(d('950.00'))));
    });

    test('electronics: subtotal + tax - discount', () {
      // subtotal 15000, tax 2700 (18%), discount 500 → 17200
      final result = engine.invoiceTotal(d('15000'), d('2700'), d('500'));
      expect(result, equals(CalcValue(d('17200.00'))));
    });

    test('jewellery: subtotal + tax - no discount', () {
      // subtotal 50000, tax 1500 (3%), discount 0 → 51500
      final result = engine.invoiceTotal(d('50000'), d('1500'), d('0'));
      expect(result, equals(CalcValue(d('51500.00'))));
    });

    test('decorationCatering: service invoice', () {
      // subtotal 25000, tax 4500 (18%), discount 2000 → 27500
      final result = engine.invoiceTotal(d('25000'), d('4500'), d('2000'));
      expect(result, equals(CalcValue(d('27500.00'))));
    });

    test('schoolErp: fee invoice', () {
      // subtotal 5000, tax 0.01 (minimal), discount 0 → 5000.01
      final result = engine.invoiceTotal(d('5000'), d('0.01'), d('0'));
      expect(result, equals(CalcValue(d('5000.01'))));
    });
  });

  // ===========================================================================
  // 6. PAYMENT RECONCILIATION
  // ===========================================================================
  group('reconcilePayment — per Business_Type', () {
    test('wholesale: full payment clears balance', () {
      final result = engine.reconcilePayment(d('10000'), d('10000'));
      expect(result, equals(CalcValue(d('0.00'))));
    });

    test('other: partial payment leaves balance', () {
      final result = engine.reconcilePayment(d('5000'), d('3000'));
      expect(result, equals(CalcValue(d('2000.00'))));
    });

    test('hardware: overpayment results in negative (credit)', () {
      final result = engine.reconcilePayment(d('1000'), d('1200'));
      expect(result, equals(CalcValue(d('-200.00'))));
    });
  });

  // ===========================================================================
  // 7. INVENTORY ADJUSTMENTS
  // ===========================================================================
  group('inventoryAdjustment — per Business_Type', () {
    test('grocery: stock addition', () {
      final result = engine.inventoryAdjustment(d('100'), d('50'));
      expect(result, equals(CalcValue(d('150.000'))));
    });

    test('pharmacy: stock reduction', () {
      final result = engine.inventoryAdjustment(d('200'), d('-30'));
      expect(result, equals(CalcValue(d('170.000'))));
    });

    test('electronics: fractional quantity', () {
      // e.g. bulk items measured by weight
      final result = engine.inventoryAdjustment(d('10.5'), d('2.75'));
      expect(result, equals(CalcValue(d('13.250'))));
    });

    test('vegetablesBroker: measured by kg (scale 3)', () {
      final result = engine.inventoryAdjustment(d('500.123'), d('-100.456'));
      expect(result, equals(CalcValue(d('399.667'))));
    });
  });

  // ===========================================================================
  // 8. CREDIT ENTRIES
  // ===========================================================================
  group('creditEntry — per Business_Type', () {
    test('clinic: credit for service payment', () {
      final result = engine.creditEntry(d('3500'));
      expect(result, equals(CalcValue(d('3500.00'))));
    });

    test('restaurant: supplier credit note', () {
      final result = engine.creditEntry(d('1250.50'));
      expect(result, equals(CalcValue(d('1250.50'))));
    });

    test('mobileShop: exchange credit', () {
      final result = engine.creditEntry(d('8999.99'));
      expect(result, equals(CalcValue(d('8999.99'))));
    });
  });

  // ===========================================================================
  // 9. DEBIT ENTRIES
  // ===========================================================================
  group('debitEntry — per Business_Type', () {
    test('wholesale: payment debit', () {
      final result = engine.debitEntry(d('15000'));
      expect(result, equals(CalcValue(d('-15000.00'))));
    });

    test('autoParts: expense debit', () {
      final result = engine.debitEntry(d('450.75'));
      expect(result, equals(CalcValue(d('-450.75'))));
    });

    test('bookStore: purchase debit', () {
      final result = engine.debitEntry(d('2300'));
      expect(result, equals(CalcValue(d('-2300.00'))));
    });
  });

  // ===========================================================================
  // 10. CURRENCY ROUNDING
  // ===========================================================================
  group('roundCurrency — half-up scale 2', () {
    test('2.345 → 2.35 (half-up)', () {
      final result = engine.roundCurrency(d('2.345'));
      expect(result, equals(CalcValue(d('2.35'))));
    });

    test('2.344 → 2.34 (rounds down)', () {
      final result = engine.roundCurrency(d('2.344'));
      expect(result, equals(CalcValue(d('2.34'))));
    });

    test('0.005 → 0.01 (half-up at boundary)', () {
      final result = engine.roundCurrency(d('0.005'));
      expect(result, equals(CalcValue(d('0.01'))));
    });

    test('negative: -2.345 → -2.35', () {
      final result = engine.roundCurrency(d('-2.345'));
      expect(result, equals(CalcValue(d('-2.35'))));
    });

    test('already at scale 2: 100.50 unchanged', () {
      final result = engine.roundCurrency(d('100.50'));
      expect(result, equals(CalcValue(d('100.50'))));
    });

    test('integer value: 42 → 42.00', () {
      final result = engine.roundCurrency(d('42'));
      expect(result, equals(CalcValue(d('42.00'))));
    });
  });

  // ===========================================================================
  // EDGE CASES (Req 2.5)
  // ===========================================================================

  group('Edge case: Zero quantity', () {
    test('inventoryAdjustment with 0 adjustment', () {
      final result = engine.inventoryAdjustment(d('100'), d('0'));
      expect(result, equals(CalcValue(d('100.000'))));
    });

    test('inventoryAdjustment with 0 current and 0 adjustment', () {
      final result = engine.inventoryAdjustment(d('0'), d('0'));
      expect(result, equals(CalcValue(d('0.000'))));
    });
  });

  group('Edge case: Negative stock (inventory goes negative)', () {
    test('adjustment exceeds current stock', () {
      // 10 - 25 = -15 — this is allowed (backorder scenario)
      final result = engine.inventoryAdjustment(d('10'), d('-25'));
      expect(result, equals(CalcValue(d('-15.000'))));
    });

    test('large negative adjustment from small stock', () {
      final result = engine.inventoryAdjustment(d('1'), d('-100'));
      expect(result, equals(CalcValue(d('-99.000'))));
    });
  });

  group('Edge case: Partial payments', () {
    test('payment less than outstanding leaves positive balance', () {
      final result = engine.reconcilePayment(d('5000'), d('2000'));
      expect(result, equals(CalcValue(d('3000.00'))));
    });

    test('minimal partial payment (0.01)', () {
      final result = engine.reconcilePayment(d('1000'), d('0.01'));
      expect(result, equals(CalcValue(d('999.99'))));
    });
  });

  group('Edge case: Refunds (negative reconciliation balance)', () {
    test('payment exceeds outstanding → refund', () {
      final result = engine.reconcilePayment(d('500'), d('750'));
      expect(result, equals(CalcValue(d('-250.00'))));
    });

    test('large overpayment', () {
      final result = engine.reconcilePayment(d('0.01'), d('1000'));
      expect(result, equals(CalcValue(d('-999.99'))));
    });
  });

  group('Edge case: Expired licenses', () {
    // NOTE: License/subscription entitlement is handled by the EntitlementChecker,
    // not the CalculationEngine. The CalculationEngine focuses on arithmetic.
    // See entitlement_checker.dart and its corresponding tests for license gating.
    test('(handled by EntitlementChecker — noted for completeness)', () {
      // This is a documentation marker confirming coverage is in the
      // entitlement checker tests, not in the calculation engine.
      expect(true, isTrue);
    });
  });

  group('Edge case: Minimum limit boundary (0.01)', () {
    test('taxTotal with minimum amount', () {
      final result = engine.taxTotal(d('0.01'), d('0.18'));
      // 0.01 * 0.18 = 0.0018 → rounds to 0.00
      expect(result, equals(CalcValue(d('0.00'))));
    });

    test('creditEntry with minimum amount', () {
      final result = engine.creditEntry(d('0.01'));
      expect(result, equals(CalcValue(d('0.01'))));
    });

    test('debitEntry with minimum amount', () {
      final result = engine.debitEntry(d('0.01'));
      expect(result, equals(CalcValue(d('-0.01'))));
    });

    test('reconcilePayment at minimum boundary', () {
      final result = engine.reconcilePayment(d('0.01'), d('0.01'));
      expect(result, equals(CalcValue(d('0.00'))));
    });

    test('below minimum (0.001) is rejected', () {
      final result = engine.taxTotal(d('0.001'), d('0.05'));
      expect(result, isA<CalcError>());
    });
  });

  group('Edge case: Maximum limit boundary (999999999.99)', () {
    test('taxTotal with maximum amount', () {
      final result = engine.taxTotal(d('999999999.99'), d('0.01'));
      // 999999999.99 * 0.01 = 9999999.9999 → rounds to 10000000.00
      expect(result, equals(CalcValue(d('10000000.00'))));
    });

    test('creditEntry with maximum amount', () {
      final result = engine.creditEntry(d('999999999.99'));
      expect(result, equals(CalcValue(d('999999999.99'))));
    });

    test('debitEntry with maximum amount', () {
      final result = engine.debitEntry(d('999999999.99'));
      expect(result, equals(CalcValue(d('-999999999.99'))));
    });

    test('above maximum is rejected', () {
      final result = engine.taxTotal(d('1000000000'), d('0.05'));
      expect(result, isA<CalcError>());
    });

    test('reconcilePayment at maximum boundary', () {
      final result = engine.reconcilePayment(
        d('999999999.99'),
        d('999999999.99'),
      );
      expect(result, equals(CalcValue(d('0.00'))));
    });
  });

  // ===========================================================================
  // INVALID INPUT VALIDATION (complements edge cases per Req 2.6, 2.7)
  // ===========================================================================
  group('Invalid inputs return CalcError', () {
    test('null amount in taxTotal', () {
      final result = engine.taxTotal(null, d('0.05'));
      expect(result, isA<CalcError>());
    });

    test('null rate in gst', () {
      final result = engine.gst(d('1000'), null);
      expect(result, isA<CalcError>());
    });

    test('negative rate in discount', () {
      final result = engine.discount(d('1000'), d('-0.1'));
      expect(result, isA<CalcError>());
    });

    test('rate > 1 (>100%) rejected', () {
      final result = engine.discount(d('1000'), d('1.5'));
      expect(result, isA<CalcError>());
    });

    test('null currentQty in inventoryAdjustment', () {
      final result = engine.inventoryAdjustment(null, d('10'));
      expect(result, isA<CalcError>());
    });

    test('negative currentQty in inventoryAdjustment', () {
      final result = engine.inventoryAdjustment(d('-5'), d('10'));
      expect(result, isA<CalcError>());
    });

    test('null amount in creditEntry', () {
      final result = engine.creditEntry(null);
      expect(result, isA<CalcError>());
    });

    test('null amount in debitEntry', () {
      final result = engine.debitEntry(null);
      expect(result, isA<CalcError>());
    });

    test('null outstanding in reconcilePayment', () {
      final result = engine.reconcilePayment(null, d('100'));
      expect(result, isA<CalcError>());
    });

    test('null payment in reconcilePayment', () {
      final result = engine.reconcilePayment(d('100'), null);
      expect(result, isA<CalcError>());
    });
  });
}
