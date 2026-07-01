import 'package:dukanx/core/compat/firestore_compat.dart';
import '../models/transaction_model.dart';
import '../models/transaction_item_model.dart';
import '../models/ledger_entry_model.dart';
import '../models/ledger_model.dart';
import '../models/stock_movement_model.dart';

class AccountingEngine {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// CORE FUNCTION: Posts a transaction and creates double-entry journal records
  /// This is atomic. Either everything saves, or nothing does.
  Future<void> postTransaction({
    required TransactionModel transaction,
    required List<TransactionItem> items,
    required String businessId,
  }) async {
    final batch = _firestore.batch();

    // 1. Transaction Document Reference
    final txnRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .doc(transaction.txnId);

    batch.set(txnRef, transaction.toMap());

    // 2. Save Item Lines
    for (var item in items) {
      final itemRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('sale_items')
          .doc(item.txnItemId);
      batch.set(itemRef, item.toMap());
    }

    // 3. GENERATE LEDGER ENTRIES (Double Entry Logic)
    final entries = await _generateLedgerEntries(
      transaction,
      items,
      businessId,
    );

    // Check Equality (Debit = Credit)
    double totalDebit = entries.fold(0, (acc, e) => acc + e.debit);
    double totalCredit = entries.fold(0, (acc, e) => acc + e.credit);

    // Allow small floating point diff
    if ((totalDebit - totalCredit).abs() > 0.01) {
      throw Exception(
        'Accounting Imbalance! Debit: $totalDebit, Credit: $totalCredit',
      );
    }

    // 4. Save Ledger Entries
    for (var entry in entries) {
      final entryRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('ledger_entries')
          .doc(entry.entryId);
      batch.set(entryRef, entry.toMap());
    }

    // 5. STOCK MOVEMENTS (Audit Trail)
    // FIX (C-06): Read current stock before batch to compute stockAfter.
    // We collect all item IDs first, read their current quantities,
    // then build movements with accurate stockAfter values.
    final stockChanges = <String, double>{}; // itemId → qtyChange
    final moveTypes = <String, StockMovementType>{};

    for (var item in items) {
      StockMovementType moveType = StockMovementType.adjustment;
      double qtyChange = 0;

      if (transaction.type == TransactionType.sale ||
          transaction.type == TransactionType.deliveryChallan) {
        moveType = StockMovementType.sale;
        qtyChange = -item.qty; // Reduce stock
      } else if (transaction.type == TransactionType.saleReturn) {
        moveType = StockMovementType.returnIn;
        qtyChange = item.qty; // Increase stock
      } else if (transaction.type == TransactionType.purchase) {
        moveType = StockMovementType.purchase;
        qtyChange = item.qty; // Increase stock
      } else if (transaction.type == TransactionType.purchaseReturn) {
        moveType = StockMovementType.returnOut;
        qtyChange = -item.qty; // Decrease stock
      }

      if (qtyChange != 0) {
        stockChanges[item.itemId] = qtyChange;
        moveTypes[item.itemId] = moveType;
      }
    }

    // Read current stock levels for all affected items
    final currentStockLevels = <String, double>{};
    for (final itemId in stockChanges.keys) {
      try {
        final stockDoc = await _firestore
            .collection('owners')
            .doc(businessId)
            .collection('stock')
            .doc(itemId)
            .get();
        currentStockLevels[itemId] =
            (stockDoc.data()?['quantity'] ?? 0).toDouble();
      } catch (_) {
        currentStockLevels[itemId] = 0;
      }
    }

    // Build stock movement records with accurate stockAfter
    for (var item in items) {
      final qtyChange = stockChanges[item.itemId];
      if (qtyChange == null || qtyChange == 0) continue;

      final currentQty = currentStockLevels[item.itemId] ?? 0;
      final stockAfter = currentQty + qtyChange;

      final moveId = '${transaction.txnId}_${item.itemId}';
      final movement = StockMovementModel(
        movementId: moveId,
        businessId: businessId,
        itemId: item.itemId,
        qtyChange: qtyChange,
        stockAfter: stockAfter,
        type: moveTypes[item.itemId]!,
        reason: 'Txn: ${transaction.refNo}',
        referenceId: transaction.txnId,
        date: transaction.date,
      );

      final moveRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('stock_movements')
          .doc(moveId);

      batch.set(moveRef, movement.toMap());

      // ALIGNMENT FIX: Use 'owners/{id}/stock' to match StockScreen and BuyFlowService
      // FIX (M-01): Use set+merge instead of update to handle missing stock documents
      final itemStockRef = _firestore
          .collection('owners')
          .doc(businessId)
          .collection('stock')
          .doc(item.itemId);

      batch.set(itemStockRef, {
        'quantity': FieldValue.increment(qtyChange),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// The Brain: Decides who gets Debited and who gets Credited
  Future<List<LedgerEntry>> _generateLedgerEntries(
    TransactionModel txn,
    List<TransactionItem> items,
    String businessId,
  ) async {
    List<LedgerEntry> entries = [];

    // Helper to create entry
    LedgerEntry createEntry(String ledgerId, double dr, double cr) {
      return LedgerEntry(
        entryId: '${txn.txnId}_${entries.length}', // deterministic ID
        businessId: businessId,
        txnId: txn.txnId,
        ledgerId: ledgerId,
        date: txn.date,
        debit: dr,
        credit: cr,
        description: 'Txn: ${txn.type.name}',
      );
    }

    // Get System Ledgers (In prod, fetch these IDs dynamically)
    // Non-accounting transactions generate NO ledger entries
    if (txn.type == TransactionType.saleOrder ||
        txn.type == TransactionType.estimate ||
        txn.type == TransactionType.deliveryChallan) {
      return [];
    }

    // A. SALE SCENARIO
    if (txn.type == TransactionType.sale) {
      // 1. Credit Sales Account (Income)
      String salesLedgerId = await _getOrcreateLedgerId(
        businessId,
        'Sales Account',
        LedgerGroup.income,
        LedgerType.sales,
      );
      entries.add(createEntry(salesLedgerId, 0, txn.subTotal));

      // 2. Credit Output GST (Liability)
      if (txn.taxAmount > 0) {
        String taxLedgerId = await _getOrcreateLedgerId(
          businessId,
          'Output GST',
          LedgerGroup.liabilities,
          LedgerType.tax,
        );
        entries.add(createEntry(taxLedgerId, 0, txn.taxAmount));
      }

      // 3. Debit Party OR Cash (Asset)
      if (txn.paymentStatus == PaymentStatus.paid) {
        // Cash Sale
        String cashLedgerId = await _getOrcreateLedgerId(
          businessId,
          'Cash Account',
          LedgerGroup.assets,
          LedgerType.cash,
        );
        entries.add(createEntry(cashLedgerId, txn.totalAmount, 0));
      } else {
        // Credit Sale (Sundry Debtor)
        if (txn.partyId != null) {
          // Ideally party has a linked ledgerId. Using partyId as ledgerId for simplicity in MVP if organized that way,
          // or we fetch the ledger for this party.
          // We assume partyId IS the ledgerId for simplicity here, or we look it up.
          // For this implementation, let's assume we use partyId as ledgerId reference for Debtors.
          String debtorLedgerId = txn.partyId!;
          entries.add(createEntry(debtorLedgerId, txn.totalAmount, 0));
        }
      }
    }
    // B. PURCHASE SCENARIO
    else if (txn.type == TransactionType.purchase) {
      // 1. Debit Purchase Account (Expense/Asset kind of)
      String purchaseLedgerId = await _getOrcreateLedgerId(
        businessId,
        'Purchase Account',
        LedgerGroup.expenses,
        LedgerType.purchase,
      );
      entries.add(
        createEntry(purchaseLedgerId, txn.subTotal, 0),
      ); // Purchases are Debited

      // 2. Debit Input GST (Asset - reduces tax liability)
      if (txn.taxAmount > 0) {
        String inputTaxId = await _getOrcreateLedgerId(
          businessId,
          'Input GST',
          LedgerGroup.assets,
          LedgerType.tax,
        );
        entries.add(createEntry(inputTaxId, txn.taxAmount, 0));
      }

      // 3. Credit Party OR Cash
      if (txn.paymentStatus == PaymentStatus.paid) {
        String cashLedgerId = await _getOrcreateLedgerId(
          businessId,
          'Cash Account',
          LedgerGroup.assets,
          LedgerType.cash,
        );
        entries.add(
          createEntry(cashLedgerId, 0, txn.totalAmount),
        ); // Cash goes OUT (Credit)
      } else {
        if (txn.partyId != null) {
          String creditorLedgerId = txn.partyId!;
          entries.add(
            createEntry(creditorLedgerId, 0, txn.totalAmount),
          ); // We owe money (Credit)
        }
      }
    }
    // C. SALE RETURN (Credit Note)
    else if (txn.type == TransactionType.saleReturn) {
      String salesReturnId = await _getOrcreateLedgerId(
        businessId,
        'Sales Return Account',
        LedgerGroup.income,
        LedgerType.sales,
      );
      entries.add(
        createEntry(salesReturnId, txn.subTotal, 0),
      ); // Debit reduces Income

      if (txn.taxAmount > 0) {
        String taxLedgerId = await _getOrcreateLedgerId(
          businessId,
          'Output GST',
          LedgerGroup.liabilities,
          LedgerType.tax,
        );
        entries.add(
          createEntry(taxLedgerId, txn.taxAmount, 0),
        ); // Debit reduces Liability
      }

      if (txn.paymentStatus == PaymentStatus.paid) {
        String cashLedgerId = await _getOrcreateLedgerId(
          businessId,
          'Cash Account',
          LedgerGroup.assets,
          LedgerType.cash,
        );
        entries.add(
          createEntry(cashLedgerId, 0, txn.totalAmount),
        ); // Credit reduces Asset
      } else {
        if (txn.partyId != null) {
          String debtorLedgerId = txn.partyId!;
          entries.add(
            createEntry(debtorLedgerId, 0, txn.totalAmount),
          ); // Credit reduces Asset (Debtor)
        }
      }
    }
    // D. PAYMENT RECEIVED (Receipt) - Customer pays us
    else if (txn.type == TransactionType.paymentIn) {
      // 1. Debit Cash/Bank (Money comes IN)
      LedgerType targetType = LedgerType.cash;
      String targetLedgerName = 'Cash in Hand';

      // If payment mode implies Bank (e.g., Online, UPI, Cheque), use Bank Account
      // In this model, we don't have explicit mode in TransactionModel, usually in notes or separate field.
      // But typically for MVP, we assume Cash unless specified.
      // Let's rely on looking up ledger by name if we had "Bank" passed, but here we only have txn.
      // We will assume "Cash in Hand" for now or "Primary Bank" if notes contain "Online".
      if (txn.notes?.toLowerCase().contains('online') == true ||
          txn.notes?.toLowerCase().contains('bank') == true ||
          txn.notes?.toLowerCase().contains('upi') == true) {
        targetLedgerName = 'Primary Bank Account';
        targetType = LedgerType.bank;
      }

      String cashBankId = await _getOrcreateLedgerId(
        businessId,
        targetLedgerName,
        LedgerGroup.assets,
        targetType,
      );

      entries.add(createEntry(cashBankId, txn.totalAmount, 0));

      // 2. Credit Customer (Asset reduces)
      if (txn.partyId != null) {
        entries.add(createEntry(txn.partyId!, 0, txn.totalAmount));
      }
    }
    // E. PAYMENT MADE (Payment) - We pay Supplier
    else if (txn.type == TransactionType.paymentOut) {
      // 1. Debit Supplier (Liability reduces)
      if (txn.partyId != null) {
        entries.add(createEntry(txn.partyId!, txn.totalAmount, 0));
      }

      // 2. Credit Cash/Bank (Money goes OUT)
      LedgerType targetType = LedgerType.cash;
      String targetLedgerName = 'Cash in Hand';

      if (txn.notes?.toLowerCase().contains('online') == true ||
          txn.notes?.toLowerCase().contains('bank') == true ||
          txn.notes?.toLowerCase().contains('upi') == true) {
        targetLedgerName = 'Primary Bank Account';
        targetType = LedgerType.bank;
      }

      String cashBankId = await _getOrcreateLedgerId(
        businessId,
        targetLedgerName,
        LedgerGroup.assets,
        targetType,
      );

      entries.add(createEntry(cashBankId, 0, txn.totalAmount));
    }

    return entries;
  }

  /// Adapter: Post a Bill as a Transaction
  Future<void> postBill(
    dynamic bill, {
    TransactionType type = TransactionType.sale,
  }) async {
    // Note: 'bill' is dynamic to avoid circular import or need explicit Bill import if not available
    // In real implementation, import Bill model.
    // Assuming Bill has: id, ownerId, date, invoiceNumber, grandTotal, totalTax, items, etc.

    final txn = TransactionModel(
      txnId: bill.id,
      businessId: bill.ownerId, // or linked shop ID
      date: bill.date,
      type: type, // Use passed type
      refNo: bill.invoiceNumber,
      partyId: bill.customerId.isEmpty ? null : bill.customerId,
      partyName: bill.customerName,
      subTotal: bill.subTotal,
      taxAmount: bill.totalTax,
      totalAmount: bill.grandTotal,
      paymentStatus: bill.isPaid ? PaymentStatus.paid : PaymentStatus.unpaid,
      createdAt: DateTime.now(),
    );

    List<TransactionItem> txnItems = [];
    for (var item in bill.items) {
      txnItems.add(
        TransactionItem(
          txnItemId: item.id.isEmpty
              ? DateTime.now().microsecondsSinceEpoch.toString()
              : item.id,
          txnId: bill.id,
          itemId: item.vegId, // Product ID
          itemName: item.itemName,
          qty: item.qty.toDouble(),
          rate: item.price.toDouble(),
          costPrice: 0, // In prod, fetch from Stock Ledger
          gstAmount: 0, // Calculate from rate % if needed
          gstRate: 0,
          netAmount: item.total.toDouble(),
        ),
      );
    }

    await postTransaction(
      transaction: txn,
      items: txnItems,
      businessId: bill.ownerId,
    );
  }

  /// Adapter: Post a Payment/Receipt
  Future<void> postPayment({
    required String paymentId,
    required String businessId, // ownerId
    required String partyId,
    required String partyType, // 'CUSTOMER' or 'SUPPLIER'
    required double amount,
    required String mode,
    required DateTime date,
    required String notes,
  }) async {
    final type = partyType == 'CUSTOMER'
        ? TransactionType.paymentIn
        : TransactionType.paymentOut;

    // Append mode to notes for Ledger generation logic to pick up 'Bank' vs 'Cash'
    final effectiveNotes = "$notes [Mode: $mode]";

    final txn = TransactionModel(
      txnId: paymentId,
      businessId: businessId,
      date: date,
      type: type,
      refNo: "", // No invoice ref usually, or linked one
      partyId: partyId,
      partyName: "", // Can fetch if needed
      subTotal: 0,
      taxAmount: 0,
      totalAmount: amount,
      paymentStatus: PaymentStatus.paid,
      createdAt: DateTime.now(),
      notes: effectiveNotes,
    );

    // Payments have no items
    await postTransaction(transaction: txn, items: [], businessId: businessId);
  }

  /// Helper to get or create a ledger on the fly (MVP only)
  Future<String> _getOrcreateLedgerId(
    String businessId,
    String name,
    LedgerGroup group,
    LedgerType type,
  ) async {
    // In real app, query by name/type. For MVP, we hash name or use standard IDs.
    String id = '${businessId}_${name.replaceAll(' ', '_').toLowerCase()}';

    // We try to reuse the same ID for standard ledgers
    final docRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('ledgers')
        .doc(id);
    final doc = await docRef.get();

    if (!doc.exists) {
      final newLedger = LedgerModel(
        ledgerId: id,
        businessId: businessId,
        name: name,
        group: group,
        type: type,
        isSystem: true,
      );
      await docRef.set(newLedger.toMap());
    }
    return id;
  }

  // ============================================================
  // REVERSAL ACCOUNTING - Phase 3 Implementation
  // ============================================================

  /// Reverse a transaction by creating opposite ledger entries.
  ///
  /// This method:
  /// 1. Validates the transaction exists and is not already reversed
  /// 2. Creates a reversal voucher for audit trail
  /// 3. Creates reversing ledger entries (Debit ↔ Credit swapped)
  /// 4. Reverses stock movements
  /// 5. Marks the original transaction as reversed
  ///
  /// Returns the reversal transaction ID.
  Future<String> reverseTransaction({
    required String originalTxnId,
    required String businessId,
    required String reason,
    required String reversedBy,
    DateTime? reversalDate,
  }) async {
    final batch = _firestore.batch();
    final effectiveReversalDate = reversalDate ?? DateTime.now();

    // 1. Load and validate original transaction
    final originalDoc = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .doc(originalTxnId)
        .get();

    if (!originalDoc.exists) {
      throw Exception('Transaction not found: $originalTxnId');
    }

    final originalData = originalDoc.data()!;
    if (originalData['isReversed'] == true) {
      throw Exception('Transaction already reversed: $originalTxnId');
    }

    // 2. Load original ledger entries
    final entriesSnapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('ledger_entries')
        .where('txnId', isEqualTo: originalTxnId)
        .get();

    // 3. Generate reversal transaction ID
    final reversalTxnId = 'REV_$originalTxnId';

    // 4. Create reversal voucher
    final reversalVoucherId = 'RV_${DateTime.now().millisecondsSinceEpoch}';
    final reversalVoucherRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('reversal_vouchers')
        .doc(reversalVoucherId);

    batch.set(reversalVoucherRef, {
      'id': reversalVoucherId,
      'businessId': businessId,
      'originalTxnId': originalTxnId,
      'reversalTxnId': reversalTxnId,
      'reason': reason,
      'reversalDate': effectiveReversalDate.toIso8601String(),
      'createdBy': reversedBy,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 5. Create reversing ledger entries (swap Debit ↔ Credit)
    for (final entryDoc in entriesSnapshot.docs) {
      final entry = entryDoc.data();
      final reversalEntryId = 'REV_${entryDoc.id}';

      final reversalEntryRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('ledger_entries')
          .doc(reversalEntryId);

      batch.set(reversalEntryRef, {
        'entryId': reversalEntryId,
        'businessId': businessId,
        'txnId': reversalTxnId,
        'ledgerId': entry['ledgerId'],
        'date': effectiveReversalDate.toIso8601String(),
        'debit': entry['credit'] ?? 0, // SWAP
        'credit': entry['debit'] ?? 0, // SWAP
        'description': 'Reversal: $reason',
        'isReversal': true,
        'originalEntryId': entryDoc.id,
      });
    }

    // 6. Reverse stock movements
    final stockMovesSnapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('stock_movements')
        .where('referenceId', isEqualTo: originalTxnId)
        .get();

    for (final moveDoc in stockMovesSnapshot.docs) {
      final move = moveDoc.data();
      final originalQtyChange = (move['qtyChange'] ?? 0).toDouble();

      if (originalQtyChange != 0) {
        final reversalMoveId = 'REV_${moveDoc.id}';
        final reversalMoveRef = _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('stock_movements')
            .doc(reversalMoveId);

        batch.set(reversalMoveRef, {
          'movementId': reversalMoveId,
          'businessId': businessId,
          'itemId': move['itemId'],
          'qtyChange': -originalQtyChange, // NEGATE
          'type': 'reversal',
          'reason': 'Reversal: $reason',
          'referenceId': reversalTxnId,
          'date': effectiveReversalDate.toIso8601String(),
          'originalMovementId': moveDoc.id,
        });

        // Update stock quantity atomically
        final itemStockRef = _firestore
            .collection('owners')
            .doc(businessId)
            .collection('stock')
            .doc(move['itemId']);

        batch.update(itemStockRef, {
          'quantity': FieldValue.increment(-originalQtyChange),
        });
      }
    }

    // 7. Mark original transaction as reversed
    batch.update(originalDoc.reference, {
      'isReversed': true,
      'reversedByTxnId': reversalTxnId,
      'reversalDate': effectiveReversalDate.toIso8601String(),
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    });

    // 8. Create the reversal transaction record
    final reversalTxnRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .doc(reversalTxnId);

    batch.set(reversalTxnRef, {
      'txnId': reversalTxnId,
      'businessId': businessId,
      'date': effectiveReversalDate.toIso8601String(),
      'type': 'reversal',
      'refNo': 'REV-${originalData['refNo'] ?? ''}',
      'partyId': originalData['partyId'],
      'partyName': originalData['partyName'],
      'subTotal': -(originalData['subTotal'] ?? 0).toDouble(),
      'taxAmount': -(originalData['taxAmount'] ?? 0).toDouble(),
      'totalAmount': -(originalData['totalAmount'] ?? 0).toDouble(),
      'paymentStatus': 'cancelled',
      'reversesOriginalTxnId': originalTxnId,
      'createdBy': reversedBy,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return reversalTxnId;
  }

  /// Update a bill by reversing the original and posting new values.
  ///
  /// This is the correct way to edit a bill in double-entry accounting:
  /// 1. Reverse all entries from the original transaction
  /// 2. Post the updated transaction as new entries
  ///
  /// This ensures audit trail is preserved.
  Future<void> updateBill(
    dynamic originalBill,
    dynamic updatedBill, {
    required String updatedBy,
    TransactionType type = TransactionType.sale,
  }) async {
    // 1. Reverse the original transaction
    await reverseTransaction(
      originalTxnId: originalBill.id,
      businessId: originalBill.ownerId,
      reason: 'Bill edited',
      reversedBy: updatedBy,
    );

    // 2. Post the updated bill as a new transaction
    await postBill(updatedBill, type: type);
  }

  /// Delete/Cancel a bill by reversing its entries.
  ///
  /// Unlike a full delete, this preserves audit trail by:
  /// 1. Creating reversal entries
  /// 2. Marking the bill as cancelled (not actually deleting)
  Future<void> deleteBill(
    dynamic bill, {
    required String deletedBy,
    String reason = 'Bill deleted',
  }) async {
    await reverseTransaction(
      originalTxnId: bill.id,
      businessId: bill.ownerId,
      reason: reason,
      reversedBy: deletedBy,
    );

    // Mark the original bill as cancelled
    await _firestore
        .collection('businesses')
        .doc(bill.ownerId)
        .collection('sales')
        .doc(bill.id)
        .update({
          'status': 'CANCELLED',
          'serverUpdatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Check if a transaction can be modified (not in a locked period).
  Future<bool> canModifyTransaction(
    String businessId,
    DateTime transactionDate,
  ) async {
    // Check if there's a locked period containing this date
    final periodsSnapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('accounting_periods')
        .where('isLocked', isEqualTo: true)
        .get();

    for (final periodDoc in periodsSnapshot.docs) {
      final startDate = DateTime.parse(periodDoc.data()['startDate'] ?? '');
      final endDate = DateTime.parse(periodDoc.data()['endDate'] ?? '');

      if (!transactionDate.isBefore(startDate) &&
          !transactionDate.isAfter(endDate)) {
        return false; // Date falls within a locked period
      }
    }

    return true;
  }

  // ============================================================
  // GAP-1 PATCH: Purchase Accounting Entry
  // ============================================================
  /// Post a purchase transaction with proper double-entry.
  ///
  /// Creates ledger entries:
  /// - DR: Purchase Account / Inventory (expense or asset)
  /// - DR: Input CGST (asset - reduces tax liability)
  /// - DR: Input SGST (asset)
  /// - DR: Input IGST (asset)
  /// - CR: Accounts Payable (liability) OR Cash/Bank (if paid)
  Future<void> postPurchase({
    required String purchaseId,
    required String businessId,
    String? vendorId,
    required String vendorName,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required double subtotal,
    required double cgst,
    required double sgst,
    required double igst,
    required double grandTotal,
    required double paidAmount,
  }) async {
    final batch = _firestore.batch();
    final entriesRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('ledger_entries');

    final totalTax = cgst + sgst + igst;
    final isPaid = paidAmount >= grandTotal;
    final now = DateTime.now();

    // Entry 1: DR Purchase Account (Expense increases)
    final purchaseEntryId = 'PUR_${purchaseId}_PURCHASE';
    batch.set(entriesRef.doc(purchaseEntryId), {
      'entryId': purchaseEntryId,
      'txnId': purchaseId,
      'accountName': 'Purchase Account',
      'accountType': 'EXPENSE',
      'debit': subtotal,
      'credit': 0.0,
      'date': invoiceDate.toIso8601String(),
      'narration': 'Purchase: $invoiceNumber from $vendorName',
      'createdAt': now.toIso8601String(),
    });

    // Entry 2: DR Input GST (Asset increases - we can claim this)
    if (totalTax > 0) {
      if (cgst > 0) {
        final cgstEntryId = 'PUR_${purchaseId}_CGST';
        batch.set(entriesRef.doc(cgstEntryId), {
          'entryId': cgstEntryId,
          'txnId': purchaseId,
          'accountName': 'Input CGST',
          'accountType': 'ASSET',
          'debit': cgst,
          'credit': 0.0,
          'date': invoiceDate.toIso8601String(),
          'narration': 'Input CGST on purchase: $invoiceNumber',
          'createdAt': now.toIso8601String(),
        });
      }
      if (sgst > 0) {
        final sgstEntryId = 'PUR_${purchaseId}_SGST';
        batch.set(entriesRef.doc(sgstEntryId), {
          'entryId': sgstEntryId,
          'txnId': purchaseId,
          'accountName': 'Input SGST',
          'accountType': 'ASSET',
          'debit': sgst,
          'credit': 0.0,
          'date': invoiceDate.toIso8601String(),
          'narration': 'Input SGST on purchase: $invoiceNumber',
          'createdAt': now.toIso8601String(),
        });
      }
      if (igst > 0) {
        final igstEntryId = 'PUR_${purchaseId}_IGST';
        batch.set(entriesRef.doc(igstEntryId), {
          'entryId': igstEntryId,
          'txnId': purchaseId,
          'accountName': 'Input IGST',
          'accountType': 'ASSET',
          'debit': igst,
          'credit': 0.0,
          'date': invoiceDate.toIso8601String(),
          'narration': 'Input IGST on purchase: $invoiceNumber',
          'createdAt': now.toIso8601String(),
        });
      }
    }

    // Entry 3: CR Accounts Payable OR Cash
    if (isPaid) {
      // Paid immediately - Credit Cash/Bank
      final cashEntryId = 'PUR_${purchaseId}_CASH';
      batch.set(entriesRef.doc(cashEntryId), {
        'entryId': cashEntryId,
        'txnId': purchaseId,
        'accountName': 'Cash Account',
        'accountType': 'ASSET',
        'debit': 0.0,
        'credit': grandTotal,
        'date': invoiceDate.toIso8601String(),
        'narration': 'Cash payment for purchase: $invoiceNumber',
        'createdAt': now.toIso8601String(),
      });
    } else {
      // Unpaid - Credit Accounts Payable (Sundry Creditor for vendor)
      final payableEntryId = 'PUR_${purchaseId}_AP';
      batch.set(entriesRef.doc(payableEntryId), {
        'entryId': payableEntryId,
        'txnId': purchaseId,
        'partyId': vendorId,
        'partyName': vendorName,
        'accountName': 'Sundry Creditors - $vendorName',
        'accountType': 'LIABILITY',
        'debit': 0.0,
        'credit': grandTotal,
        'date': invoiceDate.toIso8601String(),
        'narration': 'Payable for purchase: $invoiceNumber',
        'createdAt': now.toIso8601String(),
      });
    }

    await batch.commit();
  }

  // ============================================================
  // ADVANCE PAYMENT ACCOUNTING (GAP 5 SUPPORT)
  // ============================================================

  /// Post an advance payment to a supplier.
  ///
  /// Creates ledger entries:
  /// - DR: Advance to Suppliers (Asset - we have a right to receive goods)
  /// - CR: Cash/Bank (Asset - money went out)
  Future<void> postAdvancePayment({
    required String advanceId,
    required String businessId,
    required String partyId,
    required String partyType, // 'SUPPLIER' or 'CUSTOMER'
    required double amount,
    required String paymentMode,
    required DateTime date,
    String? notes,
  }) async {
    final batch = _firestore.batch();
    final entriesRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('ledger_entries');

    final now = DateTime.now();
    final isSupplier = partyType == 'SUPPLIER';

    // Entry 1: DR Advance Account (Asset - we have right to receive goods/refund)
    final advanceEntryId = '${advanceId}_ADVANCE';
    final advanceAccountName = isSupplier
        ? 'Advance to Suppliers'
        : 'Advance from Customers';
    batch.set(entriesRef.doc(advanceEntryId), {
      'entryId': advanceEntryId,
      'txnId': advanceId,
      'partyId': partyId,
      'accountName': advanceAccountName,
      'accountType': 'ASSET',
      'debit': amount,
      'credit': 0.0,
      'date': date.toIso8601String(),
      'narration': notes ?? 'Advance payment',
      'createdAt': now.toIso8601String(),
    });

    // Entry 2: CR Cash/Bank (Asset - money went out)
    final cashEntryId = '${advanceId}_CASH';
    final cashAccountName =
        paymentMode.toLowerCase().contains('bank') ||
            paymentMode.toLowerCase().contains('upi') ||
            paymentMode.toLowerCase().contains('online')
        ? 'Bank Account'
        : 'Cash Account';

    batch.set(entriesRef.doc(cashEntryId), {
      'entryId': cashEntryId,
      'txnId': advanceId,
      'accountName': cashAccountName,
      'accountType': 'ASSET',
      'debit': 0.0,
      'credit': amount,
      'date': date.toIso8601String(),
      'narration': notes ?? 'Advance payment via $paymentMode',
      'createdAt': now.toIso8601String(),
    });

    await batch.commit();
  }

  /// Adjust advance payment against a payable/receivable.
  ///
  /// When a purchase bill is created and advance exists:
  /// - DR: Supplier Account (LIABILITY reduces - we owe less)
  /// - CR: Advance to Suppliers (ASSET reduces - advance consumed)
  Future<void> adjustAdvanceToPayable({
    required String businessId,
    required String partyId,
    required double amount,
    required String referenceId,
    required DateTime date,
    String? notes,
  }) async {
    final batch = _firestore.batch();
    final entriesRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('ledger_entries');

    final now = DateTime.now();
    final adjustmentId = 'ADJ_${referenceId}_${now.millisecondsSinceEpoch}';

    // Entry 1: DR Supplier Account (LIABILITY reduces - we owe them less)
    final payableEntryId = '${adjustmentId}_PAYABLE';
    batch.set(entriesRef.doc(payableEntryId), {
      'entryId': payableEntryId,
      'txnId': adjustmentId,
      'partyId': partyId,
      'accountName': 'Sundry Creditors',
      'accountType': 'LIABILITY',
      'debit': amount,
      'credit': 0.0,
      'date': date.toIso8601String(),
      'narration': notes ?? 'Advance adjustment against bill $referenceId',
      'createdAt': now.toIso8601String(),
    });

    // Entry 2: CR Advance to Suppliers (ASSET reduces - advance consumed)
    final advanceEntryId = '${adjustmentId}_ADVANCE';
    batch.set(entriesRef.doc(advanceEntryId), {
      'entryId': advanceEntryId,
      'txnId': adjustmentId,
      'partyId': partyId,
      'accountName': 'Advance to Suppliers',
      'accountType': 'ASSET',
      'debit': 0.0,
      'credit': amount,
      'date': date.toIso8601String(),
      'narration': notes ?? 'Advance consumed for bill $referenceId',
      'createdAt': now.toIso8601String(),
    });

    await batch.commit();
  }
}
