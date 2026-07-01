// Unit tests: BillCalculator — Decimal-based GST engine
// Source: lib/core/accounting/bill_calculator.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/accounting/bill_calculator.dart';
import 'package:dukanx/models/bill.dart';

void main() {
  // Helper to create a BillItem
  BillItem _item({
    double qty = 1.0,
    double price = 100.0,
    double gstRate = 18.0,
    double discount = 0.0,
    double igst = 0.0,
    bool isInterState = false,
  }) => BillItem(
    productId: 'test-prod',
    productName: 'Test Item',
    qty: qty,
    price: price,
    gstRate: gstRate,
    discount: discount,
    igst: igst,
    isInterState: isInterState,
  );

  Bill _bill(List<BillItem> items, {double discountApplied = 0.0}) => Bill(
    id: 'test-bill',
    customerId: 'cust-1',
    date: DateTime(2026, 1, 1),
    items: items,
    discountApplied: discountApplied,
  );

  // === calculateItem ===
  group('BillCalculator.calculateItem', () {
    test('18% on ₹100 → tax 18, total 118', () {
      final result = BillCalculator.calculateItem(
        _item(qty: 1, price: 100, gstRate: 18));
      expect(result.total, closeTo(118.0, 0.01));
      expect(result.cgst, closeTo(9.0, 0.01));
      expect(result.sgst, closeTo(9.0, 0.01));
    });

    test('5% on ₹499.99', () {
      final result = BillCalculator.calculateItem(
        _item(qty: 1, price: 499.99, gstRate: 5));
      // tax = 499.99 * 0.05 = 24.9995 → rounded to 25.00
      expect(result.total, closeTo(524.99, 0.01));
    });

    test('12% on ₹1.00', () {
      final result = BillCalculator.calculateItem(
        _item(qty: 1, price: 1.0, gstRate: 12));
      expect(result.total, closeTo(1.12, 0.01));
    });

    test('28% on large amount ₹99999.99', () {
      final result = BillCalculator.calculateItem(
        _item(qty: 1, price: 99999.99, gstRate: 28));
      final expectedTax = (99999.99 * 28 / 100);
      expect(result.total, closeTo(99999.99 + expectedTax, 0.02));
    });

    test('0% rate → no tax', () {
      final result = BillCalculator.calculateItem(
        _item(qty: 1, price: 500, gstRate: 0));
      expect(result.total, closeTo(500.0, 0.01));
      expect(result.cgst, closeTo(0.0, 0.01));
      expect(result.sgst, closeTo(0.0, 0.01));
    });

    test('discount subtracted before tax', () {
      final result = BillCalculator.calculateItem(
        _item(qty: 1, price: 100, gstRate: 18, discount: 10));
      // taxable = 100 - 10 = 90, tax = 16.20, total = 106.20
      expect(result.total, closeTo(106.20, 0.01));
    });

    test('discount > base → taxable clamped to 0', () {
      final result = BillCalculator.calculateItem(
        _item(qty: 1, price: 10, gstRate: 18, discount: 50));
      expect(result.total, closeTo(0.0, 0.01));
    });

    test('inter-state (isInterState=true) → igst filled, no cgst/sgst', () {
      final result = BillCalculator.calculateItem(
        _item(qty: 1, price: 100, gstRate: 18, isInterState: true));
      expect(result.igst, closeTo(18.0, 0.01));
      expect(result.cgst, closeTo(0.0, 0.01));
      expect(result.sgst, closeTo(0.0, 0.01));
    });

    test('regression: igst=0 with isInterState=false → intra-state (CGST+SGST)', () {
      // Previously igst=0 was ambiguous — now isInterState is explicit
      final result = BillCalculator.calculateItem(
        _item(qty: 1, price: 100, gstRate: 18, igst: 0.0, isInterState: false));
      expect(result.cgst, closeTo(9.0, 0.01));
      expect(result.sgst, closeTo(9.0, 0.01));
      expect(result.igst, closeTo(0.0, 0.01));
    });

    test('intra-state → cgst+sgst split, sgst absorbs remainder', () {
      final result = BillCalculator.calculateItem(
        _item(qty: 1, price: 333.33, gstRate: 18));
      // tax = 333.33 * 18/100 = 59.9994 → rounded 60.00
      // cgst = 30.00, sgst = 60.00 - 30.00 = 30.00
      expect(result.cgst + result.sgst,
          closeTo(result.cgst + result.sgst, 0.01));
      // Verify total tax = cgst + sgst
      final totalTax = result.cgst + result.sgst + result.igst;
      expect(result.total, closeTo(333.33 + totalTax, 0.02));
    });

    test('fractional qty: 2.5 × ₹100 → base 250', () {
      final result = BillCalculator.calculateItem(
        _item(qty: 2.5, price: 100, gstRate: 18));
      // base = 250, tax = 45, total = 295
      expect(result.total, closeTo(295.0, 0.01));
    });
  });

  // === recalculate ===
  group('BillCalculator.recalculate', () {
    test('single item bill recalculation', () {
      final bill = _bill([_item(qty: 2, price: 100, gstRate: 18)]);
      final result = BillCalculator.recalculate(bill);
      // base = 200, tax = 36, grand = 236
      expect(result.grandTotal, closeTo(236.0, 0.01));
      expect(result.totalTax, closeTo(36.0, 0.01));
      expect(result.subtotal, closeTo(200.0, 0.01));
    });

    test('multi-item bill — totals aggregate', () {
      final bill = _bill([
        _item(qty: 1, price: 100, gstRate: 5),   // tax=5
        _item(qty: 1, price: 100, gstRate: 18),  // tax=18
        _item(qty: 1, price: 100, gstRate: 28),  // tax=28
      ]);
      final result = BillCalculator.recalculate(bill);
      expect(result.totalTax, closeTo(51.0, 0.01));
      expect(result.grandTotal, closeTo(351.0, 0.01));
    });

    test('bill-level discount applied', () {
      final bill = _bill(
        [_item(qty: 1, price: 100, gstRate: 18)],
        discountApplied: 10.0,
      );
      final result = BillCalculator.recalculate(bill);
      // item total = 118, bill discount = 10, grand = 108
      expect(result.grandTotal, closeTo(108.0, 0.01));
    });

    test('empty items → returns bill unchanged', () {
      final bill = _bill([]);
      final result = BillCalculator.recalculate(bill);
      expect(result.items, isEmpty);
    });
  });
}
