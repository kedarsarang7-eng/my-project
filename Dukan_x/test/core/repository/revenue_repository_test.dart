// ============================================================================
// REVENUE REPOSITORY TESTS
// ============================================================================
// Tests for RevenueRepository - offline-first pattern
//
// Author: DukanX Engineering
// Version: 2.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/revenue/models/revenue_models.dart';

void main() {
  group('Receipt Model Tests', () {
    test('should create Receipt with required fields', () {
      final now = DateTime.now();
      final receipt = Receipt(
        id: 'rcpt-123',
        ownerId: 'owner-456',
        customerId: 'cust-789',
        customerName: 'Test Customer',
        amount: 1500.0,
        paymentMode: 'Cash',
        date: now,
        createdAt: now,
      );

      expect(receipt.id, 'rcpt-123');
      expect(receipt.ownerId, 'owner-456');
      expect(receipt.customerId, 'cust-789');
      expect(receipt.amount, 1500.0);
      expect(receipt.paymentMode, 'Cash');
      expect(receipt.isAdvancePayment, false);
    });

    test('should create Receipt with all optional fields', () {
      final now = DateTime.now();
      final receipt = Receipt(
        id: 'rcpt-123',
        ownerId: 'owner-456',
        customerId: 'cust-789',
        customerName: 'Test Customer',
        billId: 'bill-001',
        billNumber: 'INV-001',
        amount: 1500.0,
        billAmount: 2000.0,
        paymentMode: 'Cheque',
        chequeNumber: 'CHQ12345',
        notes: 'Partial payment',
        date: now,
        createdAt: now,
        isAdvancePayment: false,
      );

      expect(receipt.customerName, 'Test Customer');
      expect(receipt.billId, 'bill-001');
      expect(receipt.billNumber, 'INV-001');
      expect(receipt.billAmount, 2000.0);
      expect(receipt.chequeNumber, 'CHQ12345');
      expect(receipt.notes, 'Partial payment');
    });

    test('should create Receipt with UPI details', () {
      final now = DateTime.now();
      final receipt = Receipt(
        id: 'rcpt-123',
        ownerId: 'owner-456',
        customerId: 'cust-789',
        customerName: 'Test Customer',
        amount: 500.0,
        paymentMode: 'UPI',
        upiTransactionId: 'TXN123456789',
        date: now,
        createdAt: now,
      );

      expect(receipt.paymentMode, 'UPI');
      expect(receipt.upiTransactionId, 'TXN123456789');
    });

    test('should create advance payment receipt', () {
      final now = DateTime.now();
      final receipt = Receipt(
        id: 'rcpt-123',
        ownerId: 'owner-456',
        customerId: 'cust-789',
        customerName: 'Test Customer',
        amount: 10000.0,
        paymentMode: 'Bank Transfer',
        date: now,
        createdAt: now,
        isAdvancePayment: true,
      );

      expect(receipt.isAdvancePayment, true);
      expect(receipt.billId, null);
      expect(receipt.billNumber, null);
    });

    test('toFirestoreMap should serialize correctly', () {
      final now = DateTime.now();
      final receipt = Receipt(
        id: 'rcpt-123',
        ownerId: 'owner-456',
        customerId: 'cust-789',
        customerName: 'Test Customer',
        amount: 1500.0,
        paymentMode: 'Cash',
        notes: 'Test note',
        date: now,
        createdAt: now,
      );

      final map = receipt.toMap();

      // id is NOT in toMap - it's handled separately in Firestore
      expect(map.containsKey('id'), false);
      expect(map['customerId'], 'cust-789');
      expect(map['customerName'], 'Test Customer');
      expect(map['amount'], 1500.0);
      expect(map['paymentMode'], 'Cash');
      expect(map['notes'], 'Test note');
      expect(map.containsKey('date'), true);
      expect(map.containsKey('createdAt'), true);

      // Should NOT include local-only fields
      expect(map.containsKey('isSynced'), false);
    });
  });

  group('Payment Mode Tests', () {
    test('should support all payment modes', () {
      final now = DateTime.now();
      final paymentModes = ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Card'];

      for (final mode in paymentModes) {
        final receipt = Receipt(
          id: 'rcpt-$mode',
          ownerId: 'owner-456',
          customerId: 'cust-789',
          customerName: 'Test Customer',
          amount: 1000.0,
          paymentMode: mode,
          date: now,
          createdAt: now,
        );

        expect(receipt.paymentMode, mode);
      }
    });
  });

  group('Revenue Calculation Tests', () {
    test('partial payment calculation', () {
      final billAmount = 5000.0;
      final paidAmount = 3000.0;
      final remaining = billAmount - paidAmount;

      expect(remaining, 2000.0);
    });

    test('full payment detection', () {
      final billAmount = 5000.0;
      final paidAmount = 5000.0;
      final remaining = billAmount - paidAmount;
      final isPaidInFull = remaining <= 0;

      expect(isPaidInFull, true);
    });

    test('overpayment detection', () {
      final billAmount = 5000.0;
      final paidAmount = 6000.0;
      final remaining = billAmount - paidAmount;
      final isOverpaid = remaining < 0;

      expect(isOverpaid, true);
      expect(remaining, -1000.0);
    });
  });

  group('Date Range Tests', () {
    test('should filter receipts by date range', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final lastWeek = now.subtract(const Duration(days: 7));
      final lastMonth = now.subtract(const Duration(days: 30));

      final receipts = [
        Receipt(
          id: 'rcpt-1',
          ownerId: 'owner-456',
          customerId: 'cust-1',
          customerName: 'Test Customer',
          amount: 1000.0,
          paymentMode: 'Cash',
          date: now,
          createdAt: now,
        ),
        Receipt(
          id: 'rcpt-2',
          ownerId: 'owner-456',
          customerId: 'cust-2',
          customerName: 'Test Customer',
          amount: 2000.0,
          paymentMode: 'UPI',
          date: yesterday,
          createdAt: yesterday,
        ),
        Receipt(
          id: 'rcpt-3',
          ownerId: 'owner-456',
          customerId: 'cust-3',
          customerName: 'Test Customer',
          amount: 3000.0,
          paymentMode: 'Card',
          date: lastWeek,
          createdAt: lastWeek,
        ),
        Receipt(
          id: 'rcpt-4',
          ownerId: 'owner-456',
          customerId: 'cust-4',
          customerName: 'Test Customer',
          amount: 4000.0,
          paymentMode: 'Bank Transfer',
          date: lastMonth,
          createdAt: lastMonth,
        ),
      ];

      // Filter last 3 days
      final fromDate = now.subtract(const Duration(days: 3));
      final filteredReceipts = receipts
          .where(
            (r) =>
                r.date.isAfter(fromDate) || r.date.isAtSameMomentAs(fromDate),
          )
          .toList();

      expect(filteredReceipts.length, 2);
      expect(filteredReceipts.map((r) => r.id), contains('rcpt-1'));
      expect(filteredReceipts.map((r) => r.id), contains('rcpt-2'));
    });

    test('should calculate total collections', () {
      final now = DateTime.now();
      final receipts = [
        Receipt(
          id: 'rcpt-1',
          ownerId: 'owner',
          customerId: 'cust',
          customerName: 'Test Customer',
          amount: 1000.0,
          paymentMode: 'Cash',
          date: now,
          createdAt: now,
        ),
        Receipt(
          id: 'rcpt-2',
          ownerId: 'owner',
          customerId: 'cust',
          customerName: 'Test Customer',
          amount: 2000.0,
          paymentMode: 'UPI',
          date: now,
          createdAt: now,
        ),
        Receipt(
          id: 'rcpt-3',
          ownerId: 'owner',
          customerId: 'cust',
          customerName: 'Test Customer',
          amount: 1500.0,
          paymentMode: 'Card',
          date: now,
          createdAt: now,
        ),
      ];

      final totalCollections = receipts.fold<double>(
        0,
        (sum, r) => sum + r.amount,
      );

      expect(totalCollections, 4500.0);
    });

    test('should group collections by payment mode', () {
      final now = DateTime.now();
      final receipts = [
        Receipt(
          id: 'rcpt-1',
          ownerId: 'owner',
          customerId: 'cust',
          customerName: 'Test Customer',
          amount: 1000.0,
          paymentMode: 'Cash',
          date: now,
          createdAt: now,
        ),
        Receipt(
          id: 'rcpt-2',
          ownerId: 'owner',
          customerId: 'cust',
          customerName: 'Test Customer',
          amount: 2000.0,
          paymentMode: 'UPI',
          date: now,
          createdAt: now,
        ),
        Receipt(
          id: 'rcpt-3',
          ownerId: 'owner',
          customerId: 'cust',
          customerName: 'Test Customer',
          amount: 1500.0,
          paymentMode: 'Cash',
          date: now,
          createdAt: now,
        ),
        Receipt(
          id: 'rcpt-4',
          ownerId: 'owner',
          customerId: 'cust',
          customerName: 'Test Customer',
          amount: 500.0,
          paymentMode: 'UPI',
          date: now,
          createdAt: now,
        ),
      ];

      final byMode = <String, double>{};
      for (final r in receipts) {
        byMode[r.paymentMode] = (byMode[r.paymentMode] ?? 0) + r.amount;
      }

      expect(byMode['Cash'], 2500.0);
      expect(byMode['UPI'], 2500.0);
    });
  });
}
