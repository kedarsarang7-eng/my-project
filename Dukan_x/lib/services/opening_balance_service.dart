import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/ledger_model.dart';
import '../features/accounting/services/journal_entry_service.dart';

/// Opening Balance Entry for a specific account type
class OpeningBalanceEntry {
  final String accountId;
  final String accountName;
  final String accountType; // 'CASH', 'BANK', 'CUSTOMER', 'SUPPLIER', 'PRODUCT'
  final double balance;
  final DateTime asOfDate;

  const OpeningBalanceEntry({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.balance,
    required this.asOfDate,
  });

  Map<String, dynamic> toMap() => {
    'accountId': accountId,
    'accountName': accountName,
    'accountType': accountType,
    'balance': balance,
    'asOfDate': asOfDate.toIso8601String(),
  };
}

/// Opening Balance Setup Result
class OpeningBalanceResult {
  final bool success;
  final int cashEntriesCreated;
  final int bankEntriesCreated;
  final int customerEntriesCreated;
  final int supplierEntriesCreated;
  final int stockEntriesCreated;
  final List<String> errors;

  const OpeningBalanceResult({
    required this.success,
    this.cashEntriesCreated = 0,
    this.bankEntriesCreated = 0,
    this.customerEntriesCreated = 0,
    this.supplierEntriesCreated = 0,
    this.stockEntriesCreated = 0,
    this.errors = const [],
  });

  int get totalEntriesCreated =>
      cashEntriesCreated +
      bankEntriesCreated +
      customerEntriesCreated +
      supplierEntriesCreated +
      stockEntriesCreated;

  Map<String, dynamic> toMap() => {
    'success': success,
    'cashEntriesCreated': cashEntriesCreated,
    'bankEntriesCreated': bankEntriesCreated,
    'customerEntriesCreated': customerEntriesCreated,
    'supplierEntriesCreated': supplierEntriesCreated,
    'stockEntriesCreated': stockEntriesCreated,
    'totalEntriesCreated': totalEntriesCreated,
    'errors': errors,
  };
}

/// Opening Balance Service - Sets up opening balances for new businesses.
///
/// ## Features
/// - Sets opening stock for all products
/// - Sets opening cash balance
/// - Sets opening bank balance
/// - Sets customer opening balances (receivables)
/// - Sets supplier opening balances (payables)
/// - Creates proper ledger entries for all opening balances
/// - Marks onboarding as complete
///
/// ## Accounting Treatment
/// Opening balances are recorded as:
/// - DR: Assets (Cash, Bank, Stock, Receivables) with positive opening
/// - CR: Capital/Equity to balance
/// OR
/// - DR: Capital/Equity to balance
/// - CR: Liabilities (Payables) with positive opening
class OpeningBalanceService {
  final FirebaseFirestore _firestore;
  // Reserved for future journal entry validation support
  // ignore: unused_field
  final JournalEntryService? _journalService;

  OpeningBalanceService({
    FirebaseFirestore? firestore,
    JournalEntryService? journalService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _journalService = journalService;

  // ============================================================
  // CASH OPENING BALANCE
  // ============================================================

  /// Set opening cash balance.
  ///
  /// Creates:
  /// - Cash ledger with opening balance
  /// - Opening journal entry (DR: Cash, CR: Capital)
  Future<void> setCashOpeningBalance({
    required String userId,
    required double amount,
    required DateTime asOfDate,
    String? notes,
  }) async {
    if (amount < 0) throw ArgumentError('Opening balance cannot be negative');

    final batch = _firestore.batch();
    final ledgerId = 'CASH_$userId';

    // 1. Create/Update Cash Ledger
    final ledgerRef = _firestore
        .collection('businesses')
        .doc(userId)
        .collection('ledgers')
        .doc(ledgerId);

    final ledger = LedgerModel(
      ledgerId: ledgerId,
      businessId: userId,
      name: 'Cash Account',
      group: LedgerGroup.assets,
      type: LedgerType.cash,
      openingBalance: amount,
      openingBalanceDate: asOfDate,
      isSystem: true,
    );

    batch.set(ledgerRef, ledger.toFirestore(), SetOptions(merge: true));

    // 2. Create Opening Journal Entry
    final entryId = const Uuid().v4();
    final entryRef = _firestore
        .collection('businesses')
        .doc(userId)
        .collection('journal_entries')
        .doc(entryId);

    batch.set(entryRef, {
      'id': entryId,
      'userId': userId,
      'date': Timestamp.fromDate(asOfDate),
      'type': 'OPENING_BALANCE',
      'description': 'Opening Cash Balance',
      'notes':
          notes ?? 'Opening balance as of ${asOfDate.toString().split(' ')[0]}',
      'entries': [
        {'ledgerId': ledgerId, 'debit': amount, 'credit': 0},
        {'ledgerId': 'CAPITAL_$userId', 'debit': 0, 'credit': amount},
      ],
      'totalAmount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Ensure Capital ledger exists
    final capitalRef = _firestore
        .collection('businesses')
        .doc(userId)
        .collection('ledgers')
        .doc('CAPITAL_$userId');

    batch.set(capitalRef, {
      'ledgerId': 'CAPITAL_$userId',
      'businessId': userId,
      'name': 'Capital Account',
      'group': 'equity',
      'type': 'capital',
      'openingBalance': 0,
      'isSystem': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    debugPrint('[OPENING] Cash balance set: ₹$amount as of $asOfDate');
  }

  // ============================================================
  // BANK OPENING BALANCE
  // ============================================================

  /// Set opening bank balance for a bank account.
  Future<void> setBankOpeningBalance({
    required String userId,
    required String bankAccountId,
    required String bankName,
    required double amount,
    required DateTime asOfDate,
    String? accountNumber,
    String? notes,
  }) async {
    if (amount < 0) throw ArgumentError('Opening balance cannot be negative');

    final batch = _firestore.batch();
    final ledgerId = 'BANK_${bankAccountId}_$userId';

    // 1. Create/Update Bank Ledger
    final ledgerRef = _firestore
        .collection('businesses')
        .doc(userId)
        .collection('ledgers')
        .doc(ledgerId);

    batch.set(ledgerRef, {
      'ledgerId': ledgerId,
      'businessId': userId,
      'name': bankName,
      'group': 'assets',
      'type': 'bank',
      'openingBalance': amount,
      'openingBalanceDate': Timestamp.fromDate(asOfDate),
      'isSystem': false,
      'bankAccountId': bankAccountId,
      'accountNumber': accountNumber,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Create Opening Journal Entry
    final entryId = const Uuid().v4();
    final entryRef = _firestore
        .collection('businesses')
        .doc(userId)
        .collection('journal_entries')
        .doc(entryId);

    batch.set(entryRef, {
      'id': entryId,
      'userId': userId,
      'date': Timestamp.fromDate(asOfDate),
      'type': 'OPENING_BALANCE',
      'description': 'Opening Bank Balance - $bankName',
      'notes':
          notes ?? 'Opening balance as of ${asOfDate.toString().split(' ')[0]}',
      'entries': [
        {'ledgerId': ledgerId, 'debit': amount, 'credit': 0},
        {'ledgerId': 'CAPITAL_$userId', 'debit': 0, 'credit': amount},
      ],
      'totalAmount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint(
      '[OPENING] Bank balance set: $bankName ₹$amount as of $asOfDate',
    );
  }

  // ============================================================
  // CUSTOMER OPENING BALANCE (Receivables)
  // ============================================================

  /// Set opening balance for a customer (amount they owe us).
  Future<void> setCustomerOpeningBalance({
    required String userId,
    required String customerId,
    required String customerName,
    required double amount,
    required DateTime asOfDate,
    String? notes,
  }) async {
    if (amount < 0) throw ArgumentError('Opening balance cannot be negative');

    final batch = _firestore.batch();
    final ledgerId = 'CUST_${customerId}_$userId';

    // 1. Create/Update Customer Ledger (Sundry Debtor)
    final ledgerRef = _firestore
        .collection('businesses')
        .doc(userId)
        .collection('ledgers')
        .doc(ledgerId);

    batch.set(ledgerRef, {
      'ledgerId': ledgerId,
      'businessId': userId,
      'name': customerName,
      'group': 'assets', // Receivables are assets
      'type': 'customer',
      'openingBalance': amount,
      'openingBalanceDate': Timestamp.fromDate(asOfDate),
      'isSystem': false,
      'partyId': customerId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Update Customer record with opening balance
    final customerRef = _firestore.collection('customers').doc(customerId);
    batch.update(customerRef, {
      'totalDues': amount,
      'openingBalance': amount,
      'openingBalanceDate': Timestamp.fromDate(asOfDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 3. Create Opening Journal Entry (DR: Customer, CR: Capital)
    final entryId = const Uuid().v4();
    final entryRef = _firestore
        .collection('businesses')
        .doc(userId)
        .collection('journal_entries')
        .doc(entryId);

    batch.set(entryRef, {
      'id': entryId,
      'userId': userId,
      'date': Timestamp.fromDate(asOfDate),
      'type': 'OPENING_BALANCE',
      'description': 'Opening Balance - $customerName (Receivable)',
      'notes':
          notes ?? 'Opening balance as of ${asOfDate.toString().split(' ')[0]}',
      'entries': [
        {'ledgerId': ledgerId, 'debit': amount, 'credit': 0},
        {'ledgerId': 'CAPITAL_$userId', 'debit': 0, 'credit': amount},
      ],
      'totalAmount': amount,
      'partyId': customerId,
      'partyType': 'CUSTOMER',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('[OPENING] Customer balance set: $customerName ₹$amount');
  }

  // ============================================================
  // SUPPLIER OPENING BALANCE (Payables)
  // ============================================================

  /// Set opening balance for a supplier (amount we owe them).
  Future<void> setSupplierOpeningBalance({
    required String userId,
    required String supplierId,
    required String supplierName,
    required double amount,
    required DateTime asOfDate,
    String? notes,
  }) async {
    if (amount < 0) throw ArgumentError('Opening balance cannot be negative');

    final batch = _firestore.batch();
    final ledgerId = 'SUPP_${supplierId}_$userId';

    // 1. Create/Update Supplier Ledger (Sundry Creditor)
    final ledgerRef = _firestore
        .collection('businesses')
        .doc(userId)
        .collection('ledgers')
        .doc(ledgerId);

    batch.set(ledgerRef, {
      'ledgerId': ledgerId,
      'businessId': userId,
      'name': supplierName,
      'group': 'liabilities', // Payables are liabilities
      'type': 'supplier',
      'openingBalance': amount,
      'openingBalanceDate': Timestamp.fromDate(asOfDate),
      'isSystem': false,
      'partyId': supplierId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Update Supplier/Vendor record with opening balance
    final supplierRef = _firestore.collection('vendors').doc(supplierId);
    batch.set(supplierRef, {
      'totalDues': amount,
      'openingBalance': amount,
      'openingBalanceDate': Timestamp.fromDate(asOfDate),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Create Opening Journal Entry (DR: Capital, CR: Supplier)
    // For liability opening, we debit capital to balance
    final entryId = const Uuid().v4();
    final entryRef = _firestore
        .collection('businesses')
        .doc(userId)
        .collection('journal_entries')
        .doc(entryId);

    batch.set(entryRef, {
      'id': entryId,
      'userId': userId,
      'date': Timestamp.fromDate(asOfDate),
      'type': 'OPENING_BALANCE',
      'description': 'Opening Balance - $supplierName (Payable)',
      'notes':
          notes ?? 'Opening balance as of ${asOfDate.toString().split(' ')[0]}',
      'entries': [
        {'ledgerId': 'CAPITAL_$userId', 'debit': amount, 'credit': 0},
        {'ledgerId': ledgerId, 'debit': 0, 'credit': amount},
      ],
      'totalAmount': amount,
      'partyId': supplierId,
      'partyType': 'SUPPLIER',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('[OPENING] Supplier balance set: $supplierName ₹$amount');
  }

  // ============================================================
  // STOCK OPENING BALANCE
  // ============================================================

  /// Set opening stock for a product.
  ///
  /// Creates stock movement with reason 'OPENING_STOCK'.
  Future<void> setProductOpeningStock({
    required String userId,
    required String productId,
    required String productName,
    required double quantity,
    required double costPrice,
    required DateTime asOfDate,
    String? notes,
  }) async {
    if (quantity < 0) {
      throw ArgumentError('Opening quantity cannot be negative');
    }
    if (costPrice < 0) {
      throw ArgumentError('Cost price cannot be negative');
    }

    final totalValue = quantity * costPrice;
    final batch = _firestore.batch();

    // 1. Update Product Stock Quantity
    final productRef = _firestore
        .collection('owners')
        .doc(userId)
        .collection('products')
        .doc(productId);

    batch.update(productRef, {
      'stockQty': quantity,
      'costPrice': costPrice,
      'openingQty': quantity,
      'openingCostPrice': costPrice,
      'openingDate': Timestamp.fromDate(asOfDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Create Stock Movement Record
    final movementId = const Uuid().v4();
    final movementRef = _firestore
        .collection('owners')
        .doc(userId)
        .collection('stock_movements')
        .doc(movementId);

    batch.set(movementRef, {
      'id': movementId,
      'userId': userId,
      'productId': productId,
      'productName': productName,
      'type': 'IN',
      'reason': 'OPENING_STOCK',
      'quantity': quantity,
      'costPrice': costPrice,
      'totalValue': totalValue,
      'date': Timestamp.fromDate(asOfDate),
      'description': 'Opening stock balance',
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Create Stock Journal Entry (DR: Stock, CR: Capital)
    final entryId = const Uuid().v4();
    final entryRef = _firestore
        .collection('businesses')
        .doc(userId)
        .collection('journal_entries')
        .doc(entryId);

    batch.set(entryRef, {
      'id': entryId,
      'userId': userId,
      'date': Timestamp.fromDate(asOfDate),
      'type': 'OPENING_BALANCE',
      'description': 'Opening Stock - $productName',
      'notes': notes ?? 'Opening stock: $quantity units @ ₹$costPrice',
      'entries': [
        {'ledgerId': 'STOCK_$userId', 'debit': totalValue, 'credit': 0},
        {'ledgerId': 'CAPITAL_$userId', 'debit': 0, 'credit': totalValue},
      ],
      'totalAmount': totalValue,
      'productId': productId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 4. Ensure Stock ledger exists
    final stockLedgerRef = _firestore
        .collection('businesses')
        .doc(userId)
        .collection('ledgers')
        .doc('STOCK_$userId');

    batch.set(stockLedgerRef, {
      'ledgerId': 'STOCK_$userId',
      'businessId': userId,
      'name': 'Inventory/Stock',
      'group': 'assets',
      'type': 'fixedAsset',
      'openingBalance': 0,
      'isSystem': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    debugPrint('[OPENING] Stock set: $productName $quantity @ ₹$costPrice');
  }

  // ============================================================
  // BULK OPENING BALANCE SETUP
  // ============================================================

  /// Set all opening balances in bulk.
  ///
  /// This is the main method for onboarding wizard.
  Future<OpeningBalanceResult> setAllOpeningBalances({
    required String userId,
    required DateTime asOfDate,
    double? cashBalance,
    List<Map<String, dynamic>>? bankAccounts,
    List<Map<String, dynamic>>? customerBalances,
    List<Map<String, dynamic>>? supplierBalances,
    List<Map<String, dynamic>>? stockBalances,
  }) async {
    final errors = <String>[];
    int cashEntries = 0;
    int bankEntries = 0;
    int customerEntries = 0;
    int supplierEntries = 0;
    int stockEntries = 0;

    try {
      // 1. Set Cash Balance
      if (cashBalance != null && cashBalance > 0) {
        try {
          await setCashOpeningBalance(
            userId: userId,
            amount: cashBalance,
            asOfDate: asOfDate,
          );
          cashEntries = 1;
        } catch (e) {
          errors.add('Cash balance error: $e');
        }
      }

      // 2. Set Bank Balances
      if (bankAccounts != null) {
        for (final bank in bankAccounts) {
          try {
            await setBankOpeningBalance(
              userId: userId,
              bankAccountId: bank['id'] ?? const Uuid().v4(),
              bankName: bank['name'] ?? 'Bank Account',
              amount: (bank['balance'] as num?)?.toDouble() ?? 0,
              asOfDate: asOfDate,
              accountNumber: bank['accountNumber'],
            );
            bankEntries++;
          } catch (e) {
            errors.add('Bank ${bank['name']} error: $e');
          }
        }
      }

      // 3. Set Customer Balances
      if (customerBalances != null) {
        for (final customer in customerBalances) {
          try {
            await setCustomerOpeningBalance(
              userId: userId,
              customerId: customer['id'] ?? '',
              customerName: customer['name'] ?? 'Customer',
              amount: (customer['balance'] as num?)?.toDouble() ?? 0,
              asOfDate: asOfDate,
            );
            customerEntries++;
          } catch (e) {
            errors.add('Customer ${customer['name']} error: $e');
          }
        }
      }

      // 4. Set Supplier Balances
      if (supplierBalances != null) {
        for (final supplier in supplierBalances) {
          try {
            await setSupplierOpeningBalance(
              userId: userId,
              supplierId: supplier['id'] ?? '',
              supplierName: supplier['name'] ?? 'Supplier',
              amount: (supplier['balance'] as num?)?.toDouble() ?? 0,
              asOfDate: asOfDate,
            );
            supplierEntries++;
          } catch (e) {
            errors.add('Supplier ${supplier['name']} error: $e');
          }
        }
      }

      // 5. Set Stock Balances
      if (stockBalances != null) {
        for (final product in stockBalances) {
          try {
            await setProductOpeningStock(
              userId: userId,
              productId: product['id'] ?? '',
              productName: product['name'] ?? 'Product',
              quantity: (product['quantity'] as num?)?.toDouble() ?? 0,
              costPrice: (product['costPrice'] as num?)?.toDouble() ?? 0,
              asOfDate: asOfDate,
            );
            stockEntries++;
          } catch (e) {
            errors.add('Product ${product['name']} error: $e');
          }
        }
      }

      // 6. Mark Onboarding Complete
      await _firestore.collection('businesses').doc(userId).set({
        'openingBalanceSetupComplete': true,
        'openingBalanceDate': Timestamp.fromDate(asOfDate),
        'openingBalanceSetupAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        '[OPENING] Bulk setup complete: Cash=$cashEntries, '
        'Banks=$bankEntries, Customers=$customerEntries, '
        'Suppliers=$supplierEntries, Stock=$stockEntries',
      );

      return OpeningBalanceResult(
        success: errors.isEmpty,
        cashEntriesCreated: cashEntries,
        bankEntriesCreated: bankEntries,
        customerEntriesCreated: customerEntries,
        supplierEntriesCreated: supplierEntries,
        stockEntriesCreated: stockEntries,
        errors: errors,
      );
    } catch (e) {
      debugPrint('[OPENING] Bulk setup failed: $e');
      return OpeningBalanceResult(
        success: false,
        cashEntriesCreated: cashEntries,
        bankEntriesCreated: bankEntries,
        customerEntriesCreated: customerEntries,
        supplierEntriesCreated: supplierEntries,
        stockEntriesCreated: stockEntries,
        errors: [...errors, e.toString()],
      );
    }
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  /// Check if opening balance setup is complete for a user.
  Future<bool> isSetupComplete(String userId) async {
    final doc = await _firestore.collection('businesses').doc(userId).get();
    if (!doc.exists) return false;
    return doc.data()?['openingBalanceSetupComplete'] == true;
  }

  /// Get opening balance setup date for a user.
  Future<DateTime?> getSetupDate(String userId) async {
    final doc = await _firestore.collection('businesses').doc(userId).get();
    if (!doc.exists) return null;
    final timestamp = doc.data()?['openingBalanceDate'] as Timestamp?;
    return timestamp?.toDate();
  }

  /// Clear all opening balances (for testing/reset).
  ///
  /// WARNING: This is destructive!
  Future<void> clearAllOpeningBalances(String userId) async {
    // Delete all opening balance journal entries
    final entriesSnap = await _firestore
        .collection('businesses')
        .doc(userId)
        .collection('journal_entries')
        .where('type', isEqualTo: 'OPENING_BALANCE')
        .get();

    final batch = _firestore.batch();
    for (final doc in entriesSnap.docs) {
      batch.delete(doc.reference);
    }

    // Reset business flag
    batch.update(_firestore.collection('businesses').doc(userId), {
      'openingBalanceSetupComplete': false,
      'openingBalanceDate': FieldValue.delete(),
    });

    await batch.commit();
    debugPrint('[OPENING] All opening balances cleared for $userId');
  }
}
