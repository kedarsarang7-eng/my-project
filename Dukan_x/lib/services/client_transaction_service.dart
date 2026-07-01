import 'package:dukanx/core/compat/firestore_compat.dart';
import '../models/bill.dart'; // Ensure these models exist or adapt import
import '../models/payment.dart';

/// Service to handle free, client-side atomic business transactions.
/// Replaces Cloud Functions for standard users (No Blaze Plan).
class ClientTransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ATOMIC: Create Sale -> Update Stock -> Update Balance -> Ledger
  Future<void> createSaleTransaction(String userId, Bill bill) async {
    final userRef = _db.collection('users').doc(userId);
    final saleRef = userRef.collection('sales').doc(); // Auto-ID
    final customerRef = userRef.collection('customers').doc(bill.customerId);
    final ledgerRef = userRef.collection('transactions').doc();

    // Prepare Sale Data
    final saleData = bill.toMap();
    saleData['id'] = saleRef.id;
    saleData['createdAt'] = FieldValue.serverTimestamp();
    saleData['status'] = bill.paidAmount >= bill.grandTotal
        ? 'PAID'
        : (bill.paidAmount > 0 ? 'PARTIAL' : 'UNPAID');

    return _db.runTransaction((transaction) async {
      // 1. Read Customer
      final customerSnap = await transaction.get(customerRef);
      if (!customerSnap.exists) {
        throw Exception("Customer not found!");
      }

      // 2. Read All Items (for Stock Check)
      // Note: Reading many docs in transaction can be expensive.
      // If list is huge, this might hit limits. For typical bills (1-20 items), it's fine.
      List<DocumentSnapshot> itemSnaps = [];
      for (var item in bill.items) {
        // assuming item.vegId is the Item ID
        final itemRef = userRef.collection('items').doc(item.vegId);
        final snap = await transaction.get(itemRef);
        itemSnaps.add(snap);
      }

      // 3. Logic: Stock Reduction
      for (int i = 0; i < bill.items.length; i++) {
        final item = bill.items[i];
        final snap = itemSnaps[i];

        if (!snap.exists) {
          // Optional: Auto-create item or throw?
          // Throwing is safer for stock integrity.
          // throw Exception("Item ${item.itemName} not found in inventory.");
          continue; // Skip if item doesn't track stock (service item)
        }

        final currentStock = (snap.data() as Map)['stockQty'] ?? 0;
        final newStock = currentStock - item.qty;

        if (newStock < 0) {
          // Allow negative? Or Throw?
          // throw Exception("Insufficient stock for ${item.itemName}");
          // For simple apps, allow negative to prevent blocking sales at counter
        }

        transaction.update(snap.reference, {'stockQty': newStock});
      }

      // 4. Logic: Customer Balance
      // Bill increases Receivable (Debit)
      // We add the PENDING amount to balance? Or Total?
      // Standard: Balance += GrandTotal (Debit). Payment will do Balance -= Amount (Credit).
      // Wait, if bill.paidAmount > 0, does that mean we already have a payment?
      // If the UI sends 'paidAmount', we usually CREATE a Payment record too?
      // Or we just Net it off?
      // SIMPLEST: Balance += (GrandTotal - PaidAmount)
      final currentBal = (customerSnap.data() as Map)['balance'] ?? 0.0;
      final pendingAmt = bill.grandTotal - bill.paidAmount;
      final newBal = currentBal + pendingAmt;

      transaction.update(customerRef, {
        'balance': newBal,
        'lastTransactionDate': FieldValue.serverTimestamp(),
      });

      // 5. Writes
      transaction.set(saleRef, saleData);

      // Ledger Entry (Sale)
      transaction.set(ledgerRef, {
        'type': 'SALE',
        'refId': saleRef.id,
        'customerId': bill.customerId,
        'amount': bill.grandTotal,
        'balanceAfter': newBal, // Approximation if multiple parallel txns
        'description': 'Invoice #${bill.invoiceNumber}',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // If there was an instant payment in this bill object
      if (bill.paidAmount > 0) {
        final payRef = userRef.collection('payments').doc();
        final payLedgerRef = userRef.collection('transactions').doc();

        transaction.set(payRef, {
          'customerId': bill.customerId,
          'amount': bill.paidAmount,
          'linkedSaleIds': [saleRef.id],
          'paymentMode': 'CASH', // Default or from Bill
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Note: We already netted the balance above (newBal = old + pending).
        // So we don't reduce balance again here.
        // But we should log the Ledger entry for record.
        transaction.set(payLedgerRef, {
          'type': 'PAYMENT',
          'refId': payRef.id,
          'customerId': bill.customerId,
          'amount': bill.paidAmount,
          'balanceAfter': newBal, // Same balance state
          'description': 'Instant Payment for #${bill.invoiceNumber}',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// ATOMIC: Record Payment -> Update Balance -> Update Invoices -> Ledger
  Future<void> createPaymentTransaction(String userId, Payment payment) async {
    final userRef = _db.collection('users').doc(userId);
    final payRef = userRef.collection('payments').doc();
    final customerRef = userRef.collection('customers').doc(payment.customerId);
    final ledgerRef = userRef.collection('transactions').doc();

    return _db.runTransaction((transaction) async {
      final customerSnap = await transaction.get(customerRef);
      if (!customerSnap.exists) throw Exception("Customer not found");

      final currentBal = (customerSnap.data() as Map)['balance'] ?? 0.0;
      final newBal = currentBal - payment.amount;

      transaction.update(customerRef, {
        'balance': newBal,
        'lastTransactionDate': FieldValue.serverTimestamp(),
      });

      transaction.set(payRef, {
        ...payment.toMap(),
        'id': payRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(ledgerRef, {
        'type': 'PAYMENT',
        'refId': payRef.id,
        'customerId': payment.customerId,
        'amount': payment.amount,
        'balanceAfter': newBal,
        'description': 'Payment Received (${payment.method})',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Note: Auto-clearing invoice status ('linkedSaleIds') is complex in Client Txn
      // without reading all open invoices.
      // For MVP Free Plan: Just update Balance.
      // Advanced: User selects specific invoices to clear in UI.
    });
  }
}
