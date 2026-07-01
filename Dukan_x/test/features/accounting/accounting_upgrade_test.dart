import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/accounting/bill_calculator.dart';
import 'package:dukanx/models/bill.dart';

void main() {
  group('BillCalculator Tally-Grade Verification', () {
    test('Calculates simple 18% GST correctly', () {
      final item = BillItem(
        productId: '1',
        productName: 'Test Item',
        qty: 1,
        price: 100,
        gstRate: 18,
        discount: 0,
      );

      final calculated = BillCalculator.calculateItem(item);

      // Base: 100, Tax: 18, Total: 118
      expect(calculated.total, 118.0);
      expect(calculated.taxAmount, 18.0);
    });

    test('Calculates item with quantity decimal precision', () {
      // 0.333 kg @ 100/kg
      final item = BillItem(
        productId: '2',
        productName: 'Sugar',
        qty: 0.333,
        price: 100,
        gstRate: 0,
        discount: 0,
      );

      final calculated = BillCalculator.calculateItem(item);
      // 33.3 -> Round to 2 decimals = 33.30
      expect(calculated.total, 33.30);
    });

    test('Calculates Bill Total strictness', () {
      final items = [
        BillItem(
          productId: '1',
          productName: 'A',
          qty: 1,
          price: 100.55,
          gstRate: 0,
          discount: 0,
        ), // 100.55
        BillItem(
          productId: '2',
          productName: 'B',
          qty: 1,
          price: 200.55,
          gstRate: 0,
          discount: 0,
        ), // 200.55
      ];
      // Total = 301.10

      final bill = Bill.empty().copyWith(items: items);
      final calcBill = BillCalculator.recalculate(bill);

      expect(calcBill.grandTotal, 301.10);
      expect(calcBill.subtotal, 301.10);
    });

    test('Calculates GST split correctly', () {
      final item = BillItem(
        productId: '1',
        productName: 'GST Item',
        qty: 1,
        price: 100,
        gstRate: 18,
        discount: 0,
        igst: 0, // Implies Intra-state
      );

      final calculated = BillCalculator.calculateItem(item);

      expect(calculated.cgst, 9.0);
      expect(calculated.sgst, 9.0);
      expect(calculated.igst, 0.0);
      expect(calculated.taxAmount, 18.0);
    });

    test('Calculates IGST split correctly', () {
      final item = BillItem(
        productId: '1',
        productName: 'GST Item',
        qty: 1,
        price: 100,
        gstRate: 18,
        discount: 0,
        igst: 1, // Implies Inter-state (non-zero placeholder)
      );

      final calculated = BillCalculator.calculateItem(item);

      expect(calculated.cgst, 0.0);
      expect(calculated.sgst, 0.0);
      expect(calculated.igst, 18.0);
      expect(calculated.taxAmount, 18.0);
    });
  });
}
