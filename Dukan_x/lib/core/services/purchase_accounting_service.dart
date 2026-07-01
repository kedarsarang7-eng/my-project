import 'package:dukanx/core/compat/firestore_compat.dart';
import '../../../models/purchase_bill.dart';
import '../../../models/transaction_model.dart';
import '../../../models/transaction_item_model.dart';
import 'accounting_engine.dart';

/// Purchase Accounting Service - Integrates PurchaseBill with AccountingEngine.
///
/// This service ensures that every purchase bill:
/// 1. Creates proper double-entry ledger entries
/// 2. Updates supplier (Sundry Creditor) balance
/// 3. Updates stock quantities
/// 4. Records Input GST for credit
class PurchaseAccountingService {
  final AccountingEngine _accountingEngine;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  PurchaseAccountingService({
    AccountingEngine? accountingEngine,
  }) : _accountingEngine = accountingEngine ?? AccountingEngine();

  /// Post a purchase bill to the accounting system.
  ///
  /// Creates:
  /// - Debit: Purchase Account (Expense)
  /// - Debit: Input GST (Asset - reduces tax liability)
  /// - Credit: Supplier Account (Liability - we owe them)
  /// OR Credit: Cash/Bank if paid immediately
  Future<void> postPurchaseBill(PurchaseBill bill) async {
    final txn = TransactionModel(
      txnId: bill.id,
      businessId: bill.ownerId,
      date: bill.date,
      type: TransactionType.purchase,
      refNo: bill.billNumber,
      partyId: bill.supplierId,
      partyName: bill.supplierName,
      subTotal: bill.subtotal,
      taxAmount: bill.totalTax,
      totalAmount: bill.grandTotal,
      balanceAmount: bill.pendingAmount,
      paymentStatus: _mapPaymentStatus(bill.status),
      dueDate: bill.dueDate,
      createdAt: DateTime.now(),
      notes: bill.notes,
    );

    final items = bill.items
        .map(
          (item) => TransactionItem(
            txnItemId: '${bill.id}_${item.itemId}',
            txnId: bill.id,
            itemId: item.itemId,
            itemName: item.itemName,
            qty: item.qty,
            rate: item.rate,
            costPrice: item.rate, // Purchase rate is the cost price
            gstAmount: item.cgst + item.sgst + item.igst,
            gstRate: item.gstRate,
            netAmount: item.total,
          ),
        )
        .toList();

    await _accountingEngine.postTransaction(
      transaction: txn,
      items: items,
      businessId: bill.ownerId,
    );
  }

  /// Record a payment made to a supplier.
  Future<void> recordSupplierPayment({
    required String paymentId,
    required String businessId,
    required String supplierId,
    required double amount,
    required String mode,
    required DateTime date,
    String notes = '',
  }) async {
    await _accountingEngine.postPayment(
      paymentId: paymentId,
      businessId: businessId,
      partyId: supplierId,
      partyType: 'SUPPLIER',
      amount: amount,
      mode: mode,
      date: date,
      notes: notes,
    );
  }

  /// Process a purchase return.
  ///
  /// This reverses the original purchase entries and adjusts stock.
  Future<String> processPurchaseReturn({
    required PurchaseBill originalBill,
    required List<PurchaseBillItem> returnedItems,
    required String returnedBy,
    String? reason,
  }) async {
    // Calculate return totals
    double returnSubtotal = 0;
    double returnTax = 0;

    for (final item in returnedItems) {
      returnSubtotal += item.qty * item.rate;
      returnTax += item.cgst + item.sgst + item.igst;
    }

    final returnTotal = returnSubtotal + returnTax;

    // Create return transaction
    final returnTxn = TransactionModel(
      txnId: 'RET_${originalBill.id}',
      businessId: originalBill.ownerId,
      date: DateTime.now(),
      type: TransactionType.purchaseReturn,
      refNo: 'RET-${originalBill.billNumber}',
      partyId: originalBill.supplierId,
      partyName: originalBill.supplierName,
      subTotal: returnSubtotal,
      taxAmount: returnTax,
      totalAmount: returnTotal,
      paymentStatus: PaymentStatus.paid,
      createdAt: DateTime.now(),
      notes: reason ?? 'Purchase return',
    );

    final returnItems = returnedItems
        .map(
          (item) => TransactionItem(
            txnItemId: 'RET_${originalBill.id}_${item.itemId}',
            txnId: 'RET_${originalBill.id}',
            itemId: item.itemId,
            itemName: item.itemName,
            qty: item.qty,
            rate: item.rate,
            costPrice: item.rate,
            gstAmount: item.cgst + item.sgst + item.igst,
            gstRate: item.gstRate,
            netAmount: item.total,
          ),
        )
        .toList();

    await _accountingEngine.postTransaction(
      transaction: returnTxn,
      items: returnItems,
      businessId: originalBill.ownerId,
    );

    return returnTxn.txnId;
  }

  // ============================================================
  // ADVANCE PAYMENT WORKFLOW (GAP 5 FIX)
  // ============================================================

  /// Record an advance payment made to a supplier before goods receipt.
  ///
  /// Creates:
  /// - Debit: Advance to Suppliers (Asset - we have a right to receive goods)
  /// - Credit: Cash/Bank (Asset - money went out)
  ///
  /// The advance is tracked and adjusted when a purchase bill is created.
  Future<String> recordAdvanceToSupplier({
    required String businessId,
    required String supplierId,
    required String supplierName,
    required double amount,
    required String paymentMode,
    required DateTime paymentDate,
    String? notes,
    String? referenceNumber,
  }) async {
    if (amount <= 0) throw ArgumentError('Advance amount must be positive');

    final advanceId =
        'ADV_${supplierId}_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Post the advance transaction (creates DR: Advance to Supplier, CR: Cash/Bank)
    await _accountingEngine.postAdvancePayment(
      advanceId: advanceId,
      businessId: businessId,
      partyId: supplierId,
      partyType: 'SUPPLIER',
      amount: amount,
      paymentMode: paymentMode,
      date: paymentDate,
      notes: notes ?? 'Advance to $supplierName',
    );

    // 2. Track the advance in Firestore for later adjustment
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('supplier_advances')
        .doc(advanceId)
        .set({
          'advanceId': advanceId,
          'supplierId': supplierId,
          'supplierName': supplierName,
          'amount': amount,
          'usedAmount': 0.0,
          'remainingAmount': amount,
          'paymentMode': paymentMode,
          'paymentDate': Timestamp.fromDate(paymentDate),
          'referenceNumber': referenceNumber,
          'notes': notes,
          'status': 'ACTIVE', // ACTIVE, PARTIALLY_USED, FULLY_USED
          'linkedBills': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        });

    return advanceId;
  }

  /// Adjust advance payment when a purchase bill is created.
  ///
  /// This method should be called during bill creation to:
  /// 1. Check if supplier has unused advance
  /// 2. Apply advance to reduce bill payable
  /// 3. Create journal entry to transfer from Advance to Supplier account
  ///
  /// Returns the amount of advance applied.
  Future<double> adjustAdvanceOnPurchase({
    required String businessId,
    required String supplierId,
    required String billId,
    required double billAmount,
  }) async {
    // Get unused advances for this supplier
    final advancesSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('supplier_advances')
        .where('supplierId', isEqualTo: supplierId)
        .where('status', whereIn: ['ACTIVE', 'PARTIALLY_USED'])
        .orderBy('paymentDate')
        .get();

    if (advancesSnapshot.docs.isEmpty) return 0.0;

    double totalApplied = 0.0;
    double remainingBill = billAmount;

    final batch = WriteBatch();

    for (final doc in advancesSnapshot.docs) {
      if (remainingBill <= 0) break;

      final advance = doc.data();
      final remainingAdvance = (advance['remainingAmount'] as num).toDouble();

      if (remainingAdvance <= 0) continue;

      // Calculate how much to apply
      final applyAmount = remainingAdvance >= remainingBill
          ? remainingBill
          : remainingAdvance;

      // Update advance record
      final newRemaining = remainingAdvance - applyAmount;
      final newUsed = (advance['usedAmount'] as num).toDouble() + applyAmount;
      final linkedBills = List<String>.from(advance['linkedBills'] ?? []);
      linkedBills.add(billId);

      final advanceRef = _db
          .collection('businesses')
          .doc(businessId)
          .collection('supplier_advances')
          .doc(doc.id);
      batch.update(advanceRef, {
        'usedAmount': newUsed,
        'remainingAmount': newRemaining,
        'status': newRemaining <= 0.01 ? 'FULLY_USED' : 'PARTIALLY_USED',
        'linkedBills': linkedBills,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create journal entry to transfer from Advance to Supplier
      // DR: Supplier Account (reduce what we owe)
      // CR: Advance to Supplier (reduce the advance asset)
      await _accountingEngine.adjustAdvanceToPayable(
        businessId: businessId,
        partyId: supplierId,
        amount: applyAmount,
        referenceId: billId,
        date: DateTime.now(),
        notes: 'Advance adjusted against bill $billId',
      );

      totalApplied += applyAmount;
      remainingBill -= applyAmount;
    }

    await batch.commit();
    return totalApplied;
  }

  /// Get total advance balance for a supplier.
  Future<double> getSupplierAdvanceBalance({
    required String businessId,
    required String supplierId,
  }) async {
    final advancesSnapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('supplier_advances')
        .where('supplierId', isEqualTo: supplierId)
        .where('status', whereIn: ['ACTIVE', 'PARTIALLY_USED'])
        .get();

    double totalAdvance = 0.0;
    for (final doc in advancesSnapshot.docs) {
      totalAdvance += (doc.data()['remainingAmount'] as num).toDouble();
    }
    return totalAdvance;
  }

  /// Get all advances for a supplier.
  Future<List<Map<String, dynamic>>> getSupplierAdvances({
    required String businessId,
    required String supplierId,
    bool activeOnly = false,
  }) async {
    Query query = _db
        .collection('businesses')
        .doc(businessId)
        .collection('supplier_advances')
        .where('supplierId', isEqualTo: supplierId);

    if (activeOnly) {
      query = query.where('status', whereIn: ['ACTIVE', 'PARTIALLY_USED']);
    }

    final snapshot = await query.orderBy('paymentDate', descending: true).get();
    return snapshot.docs.map((d) {
      final data = d.data();
      return <String, dynamic>{...data, 'id': d.id};
    }).toList();
  }

  /// Get all pending advances across all suppliers.
  Future<List<Map<String, dynamic>>> getAllPendingAdvances(
    String businessId,
  ) async {
    final snapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('supplier_advances')
        .where('status', whereIn: ['ACTIVE', 'PARTIALLY_USED'])
        .orderBy('paymentDate')
        .get();

    return snapshot.docs.map((d) {
      return <String, dynamic>{...d.data(), 'id': d.id};
    }).toList();
  }

  /// Get supplier aging report showing outstanding amounts by age buckets.
  Future<SupplierAgingReport> getSupplierAging(String businessId) async {
    final billsSnapshot = await _db
        .collection('purchase_bills')
        .where('ownerId', isEqualTo: businessId)
        .where('status', whereIn: ['Unpaid', 'Partial'])
        .get();

    final now = DateTime.now();
    final buckets = AgingBuckets();

    for (final doc in billsSnapshot.docs) {
      final bill = PurchaseBill.fromMap(doc.id, doc.data());
      final daysOutstanding = now.difference(bill.date).inDays;
      final outstanding = bill.pendingAmount;

      if (daysOutstanding <= 30) {
        buckets.current += outstanding;
      } else if (daysOutstanding <= 60) {
        buckets.days31to60 += outstanding;
      } else if (daysOutstanding <= 90) {
        buckets.days61to90 += outstanding;
      } else {
        buckets.over90 += outstanding;
      }
    }

    return SupplierAgingReport(
      businessId: businessId,
      asOfDate: now,
      buckets: buckets,
      total: buckets.total,
    );
  }

  PaymentStatus _mapPaymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'partial':
        return PaymentStatus.partial;
      default:
        return PaymentStatus.unpaid;
    }
  }
}

/// Aging buckets for accounts payable/receivable
class AgingBuckets {
  double current = 0; // 0-30 days
  double days31to60 = 0; // 31-60 days
  double days61to90 = 0; // 61-90 days
  double over90 = 0; // 90+ days

  double get total => current + days31to60 + days61to90 + over90;

  Map<String, double> toMap() => {
    'current': current,
    'days31to60': days31to60,
    'days61to90': days61to90,
    'over90': over90,
    'total': total,
  };
}

/// Supplier aging report
class SupplierAgingReport {
  final String businessId;
  final DateTime asOfDate;
  final AgingBuckets buckets;
  final double total;

  const SupplierAgingReport({
    required this.businessId,
    required this.asOfDate,
    required this.buckets,
    required this.total,
  });
}
