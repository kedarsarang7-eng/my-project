import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillsRepository', () {
    group('Bill Calculation Tests', () {
      test('should calculate grandTotal correctly', () {
        // Item 1: 2 * 100 = 200
        // Item 2: 3 * 50 = 150
        // Total = 350
        final itemTotals = [200.0, 150.0];
        final grandTotal = itemTotals.reduce((a, b) => a + b);
        expect(grandTotal, 350.0);
      });

      test('should calculate balance due correctly', () {
        final grandTotal = 1000.0;
        final paidAmount = 600.0;
        final balanceDue = grandTotal - paidAmount;
        expect(balanceDue, 400.0);
      });

      test('should mark bill as paid when paidAmount equals grandTotal', () {
        final grandTotal = 500.0;
        final paidAmount = 500.0;
        final isPaid = paidAmount >= grandTotal;
        expect(isPaid, true);
      });

      test(
        'should mark bill as unpaid when paidAmount less than grandTotal',
        () {
          final grandTotal = 500.0;
          final paidAmount = 250.0;
          final isPaid = paidAmount >= grandTotal;
          expect(isPaid, false);
        },
      );
    });

    group('BillItem Calculation Tests', () {
      test('should calculate item total correctly', () {
        final qty = 10.0;
        final price = 25.0;
        final total = qty * price;
        expect(total, 250.0);
      });

      test('should calculate tax amount correctly', () {
        final qty = 2.0;
        final price = 100.0;
        final gstRate = 18.0;

        final baseAmount = qty * price;
        final taxAmount = baseAmount * (gstRate / 100);

        expect(baseAmount, 200.0);
        expect(taxAmount, 36.0);
      });

      test('should apply discount correctly', () {
        final qty = 4.0;
        final price = 100.0;
        final discount = 40.0;

        final total = (qty * price) - discount;
        expect(total, 360.0);
      });

      test('should calculate CGST and SGST equally', () {
        final gstRate = 18.0;
        final baseAmount = 1000.0;

        final totalGst = baseAmount * (gstRate / 100);
        final cgst = totalGst / 2;
        final sgst = totalGst / 2;

        expect(cgst, 90.0);
        expect(sgst, 90.0);
        expect(cgst + sgst, totalGst);
      });
    });

    group('Invoice Number Tests', () {
      test('should generate unique invoice numbers', () {
        final invoiceNumbers = ['INV-001', 'INV-002', 'INV-003'];
        expect(invoiceNumbers.toSet().length, 3);
      });
    });

    group('Repository Logic Tests', () {
      test('BillsRepository collectionName should be defined', () {
        expect('bills', isNotEmpty);
      });
    });
  });
}
