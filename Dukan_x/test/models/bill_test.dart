// ============================================================================
// BILL FINANCIAL LOGIC TESTS
// ============================================================================
// Focused tests for mathematical correctness of Bill and BillItem
// Covering: Line totals, Tax calculations, Grand totals, Edge cases.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/models/bill.dart';

void main() {
  group('BillItem Financial Logic', () {
    test('Calculate basic total: qty * price', () {
      final item = BillItem(
        productId: 'p1',
        productName: 'Item 1',
        qty: 2.0,
        price: 50.0,
      );
      // 2 * 50 = 100
      expect(item.total, 100.0);
    });

    test('Calculate total with discount', () {
      final item = BillItem(
        productId: 'p2',
        productName: 'Item 2',
        qty: 1.0,
        price: 100.0,
        discount: 10.0,
      );
      // 100 - 10 = 90
      expect(item.total, 90.0);
    });

    test('Calculate total with tax (CGST + SGST)', () {
      final item = BillItem(
        productId: 'p3',
        productName: 'Item 3',
        qty: 1.0,
        price: 100.0,
        cgst:
            5.0, // 5% implicitly if rate logic used, but here amounts are absolute
        sgst: 5.0,
      );
      // 100 + 5 + 5 = 110
      expect(item.total, 110.0);
    });

    test(
      'Calculate total with all components: qty * price - discount + tax + labor',
      () {
        final item = BillItem(
          productId: 'p4',
          productName: 'Complex Item',
          qty: 2.0,
          price: 50.0, // Base: 100
          discount: 10.0, // -10 -> 90
          cgst: 4.5, // +4.5 -> 94.5
          sgst: 4.5, // +4.5 -> 99.0
          laborCharge: 20.0, // +20 -> 119.0
        );
        expect(item.total, 119.0);
      },
    );

    test('Edge case: Zero quantity', () {
      final item = BillItem(
        productId: 'p5',
        productName: 'Zero Qty',
        qty: 0.0,
        price: 50.0,
      );
      expect(item.total, 0.0);
    });

    test('Edge case: Zero price', () {
      final item = BillItem(
        productId: 'p6',
        productName: 'Free Item',
        qty: 5.0,
        price: 0.0,
      );
      expect(item.total, 0.0);
    });
  });

  group('Bill Grand Total Logic', () {
    test(
      'Sanitized bill recalculates grand total from safe items logic (mock behavior check)',
      () {
        // Note: Bill.sanitized() creates safeItems but currently relies on existing grandTotal
        // or user logic to sum them up. The Bill model specifically says:
        // "Ideally we should recalculate item totals here too, but for now we trust the item.total"
        // Let's verify if `sanitized` enforces non-negative grandTotal at least.

        final bill = Bill(
          id: 'b1',
          customerId: 'c1',
          date: DateTime.now(),
          items: [],
          grandTotal: -50.0, // Invalid negative
          paidAmount: 100.0,
        ).sanitized();

        expect(bill.grandTotal, 0.0); // Should be clamped to 0
        expect(bill.paidAmount, 0.0); // Paid amount limited by grand total
      },
    );

    test('Paid amount cannot exceed Grand Total', () {
      final bill = Bill(
        id: 'b2',
        customerId: 'c1',
        date: DateTime.now(),
        items: [],
        grandTotal: 100.0,
        paidAmount: 150.0, // Exceeds
      ).sanitized();

      expect(bill.grandTotal, 100.0);
      expect(bill.paidAmount, 100.0); // Clamped
    });

    test('Cash + Online split validation', () {
      // If cash + online > paidAmount, or logical inconsistencies
      final bill = Bill(
        id: 'b3',
        customerId: 'c1',
        date: DateTime.now(),
        items: [],
        grandTotal: 100.0,
        paidAmount: 100.0,
        cashPaid: 60.0,
        onlinePaid: 60.0, // 60+60 = 120 > 100
      ).sanitized();

      // logic in sanitized:
      // safePaid = 100
      // safeCash = 60
      // remainingForOnline = 40
      // safeOnline = clamp(60, 40) = 40

      expect(bill.paidAmount, 100.0);
      expect(bill.cashPaid, 60.0);
      expect(bill.onlinePaid, 40.0);
    });
  });
}
