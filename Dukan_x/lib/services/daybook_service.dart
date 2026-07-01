import 'package:drift/drift.dart';
import 'dart:convert';
import '../core/database/app_database.dart';
import '../models/daybook_entry.dart';
import '../core/sync/sync_manager.dart';

/// DayBookService - Offline-First Daily Transaction Summary
class DayBookService {
  final AppDatabase _db;
  // ignore: unused_field
  final SyncManager? _syncManager;

  DayBookService(this._db, {SyncManager? syncManager})
    : _syncManager = syncManager;

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get or create a day book entry (Local First)
  Future<DayBookEntry> getOrCreateEntry(
    String businessId,
    DateTime date,
  ) async {
    final dateKey = _dateKey(date);
    final id = '${businessId}_$dateKey';

    // 1. Try Local DB
    final localEntry = await (_db.select(
      _db.dayBook,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (localEntry != null) {
      return DayBookEntry(
        id: localEntry.id,
        businessId: localEntry.businessId,
        date: localEntry.date,
        openingCashBalance: localEntry.openingCashBalance,
        closingCashBalance: localEntry.closingCashBalance,
        computedClosingBalance: localEntry.computedClosingBalance,
        totalSales: localEntry.totalSales,
        totalCashSales: localEntry.totalCashSales,
        totalCreditSales: localEntry.totalCreditSales,
        totalPurchases: localEntry.totalPurchases,
        totalCashPurchases: localEntry.totalCashPurchases,
        totalCreditPurchases: localEntry.totalCreditPurchases,
        totalExpenses: localEntry.totalExpenses,
        totalCashExpenses: localEntry.totalCashExpenses,
        totalPaymentsReceived: localEntry.totalPaymentsReceived,
        totalPaymentsMade: localEntry.totalPaymentsMade,
        salesCount: localEntry.salesCount,
        purchasesCount: localEntry.purchasesCount,
        expensesCount: localEntry.expensesCount,
        paymentsReceivedCount: localEntry.paymentsReceivedCount,
        paymentsMadeCount: localEntry.paymentsMadeCount,
        isReconciled: localEntry.isReconciled,
        reconciledAt: localEntry.reconciledAt,
        reconciledBy: localEntry.reconciledBy,
        reconciliationNotes: localEntry.reconciliationNotes,
        reconciliationDifference: localEntry.reconciliationDifference,
        createdAt: localEntry.createdAt,
        updatedAt: localEntry.updatedAt,
      );
    }

    // 2. Create New Entry
    // Get previous day's closing balance
    final previousDate = date.subtract(const Duration(days: 1));
    final openingBalance = await _getPreviousClosingBalance(
      businessId,
      previousDate,
    );

    final now = DateTime.now();
    final newEntity = DayBookCompanion.insert(
      id: id,
      businessId: businessId,
      date: date,
      openingCashBalance: Value(openingBalance),
      createdAt: now,
      updatedAt: now,
      isSynced: const Value(false),
    );

    await _db.into(_db.dayBook).insert(newEntity);

    return DayBookEntry.forDate(businessId, date, openingBalance);
  }

  /// Compute and update day book entry from LOCAL transactions.
  Future<DayBookEntry> computeDaySummary(
    String businessId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Ensure entry exists
    await getOrCreateEntry(businessId, date);
    final dateKey = _dateKey(date);
    final id = '${businessId}_$dateKey';

    // 1. SALES (From Bills table)
    final bills =
        await (_db.select(_db.bills)..where(
              (t) =>
                  t.userId.equals(businessId) &
                  t.billDate.isBetweenValues(startOfDay, endOfDay) &
                  t.deletedAt.isNull(),
            ))
            .get();

    double totalSales = 0;
    double cashSales = 0; // Cash + UPI (Realized immediately)
    double creditSales = 0;
    int salesCount = bills.length;

    for (final bill in bills) {
      totalSales += bill.grandTotal;
      // Use cashPaid field if available and > 0, otherwise infer from Payment Mode
      if (bill.cashPaid > 0 || bill.onlinePaid > 0) {
        // Hybrid payment support
        cashSales += (bill.cashPaid + bill.onlinePaid);
      } else if (bill.paymentMode == 'Cash' || bill.paymentMode == 'UPI') {
        // Fallback if split fields are 0 but mode is explicitly Cash/UPI
        cashSales += bill.grandTotal;
      } else {
        // Otherwise assume it's credit/pending
      }

      // Credit is whatever hasn't been paid
      // If paidAmount is tracked fully:
      // creditSales += (bill.grandTotal - bill.paidAmount);
      // Simplified for now based on cashSales logic above:
      creditSales += (bill.grandTotal - (bill.cashPaid + bill.onlinePaid));
      if (creditSales < 0) creditSales = 0; // Safety
    }

    // 2. EXPENSES (From Expenses table)
    final expenses =
        await (_db.select(_db.expenses)..where(
              (t) =>
                  t.userId.equals(businessId) &
                  t.expenseDate.isBetweenValues(startOfDay, endOfDay) &
                  t.deletedAt.isNull(),
            ))
            .get();

    double totalExpenses = 0;
    double cashExpenses = 0;
    int expensesCount = expenses.length;

    for (final exp in expenses) {
      totalExpenses += exp.amount;
      // Assume expenses are Cash/Hypothecated unless specified otherwise
      // Ideally check paymentMode. 'Cash', 'UPI', 'Bank' -> Realized Outflow.
      if (exp.paymentMode == 'Cash') {
        cashExpenses += exp.amount;
      }
    }

    // 3. PURCHASES (From PurchaseOrders)
    final purchases =
        await (_db.select(_db.purchaseOrders)..where(
              (t) =>
                  t.userId.equals(businessId) &
                  t.purchaseDate.isBetweenValues(startOfDay, endOfDay) &
                  t.deletedAt.isNull(),
            ))
            .get();

    double totalPurchases = 0;
    double cashPurchases = 0;
    double creditPurchases = 0;
    int purchasesCount = purchases.length;

    for (final po in purchases) {
      totalPurchases += po.totalAmount;
      // Track actual outflow
      if (po.paidAmount > 0) {
        cashPurchases += po.paidAmount;
      }
      // Remaining is credit
      if (po.totalAmount > po.paidAmount) {
        creditPurchases += (po.totalAmount - po.paidAmount);
      }
    }

    // 4. PAYMENTS RECEIVED (From Payments Table)
    // Tracks money coming in from customers (Settling Dues)
    final payments =
        await (_db.select(_db.payments)..where(
              (t) =>
                  t.userId.equals(businessId) &
                  t.paymentDate.isBetweenValues(startOfDay, endOfDay) &
                  t.deletedAt.isNull(),
            ))
            .get();

    double totalPaymentsReceived = 0; // All modes
    double cashPaymentsReceived = 0; // Only Cash/UPI
    int paymentsReceivedCount = payments.length;

    for (final p in payments) {
      totalPaymentsReceived += p.amount;
      // Differentiate Cash vs Bank?
      // For Closing Cash Balance, we typically care about 'Cash' specifically.
      // But commonly 'Cash In Hand' includes Liquid Digital (UPI).
      if (p.paymentMode == 'Cash' || p.paymentMode == 'UPI') {
        cashPaymentsReceived += p.amount;
      }
    }

    // 5. PAYMENTS MADE (Optional / Future Use)
    // Could track outgoing payments to vendors if separate from PurchaseOrders
    double totalPaymentsMade = 0;
    int paymentsMadeCount = 0;

    // Calculate Closing Balance
    // Need Opening Balance
    final currentEntry = await (_db.select(
      _db.dayBook,
    )..where((t) => t.id.equals(id))).getSingle();

    final computedClosing =
        currentEntry.openingCashBalance +
        cashSales +
        cashPaymentsReceived -
        cashPurchases -
        cashExpenses;

    // Update Local DB
    final updateComp = DayBookCompanion(
      totalSales: Value(totalSales),
      totalCashSales: Value(cashSales),
      totalCreditSales: Value(creditSales),
      totalPurchases: Value(totalPurchases),
      totalCashPurchases: Value(cashPurchases),
      totalCreditPurchases: Value(creditPurchases),
      totalExpenses: Value(totalExpenses),
      totalCashExpenses: Value(cashExpenses),
      totalPaymentsReceived: Value(totalPaymentsReceived), // Persist Total
      totalPaymentsMade: Value(totalPaymentsMade),
      salesCount: Value(salesCount),
      purchasesCount: Value(purchasesCount),
      expensesCount: Value(expensesCount),
      paymentsReceivedCount: Value(paymentsReceivedCount),
      paymentsMadeCount: Value(paymentsMadeCount),
      computedClosingBalance: Value(computedClosing),
      updatedAt: Value(DateTime.now()),
      // Mark as NOT Synced to trigger cloud update
      isSynced: const Value(false),
    );

    await (_db.update(
      _db.dayBook,
    )..where((t) => t.id.equals(id))).write(updateComp);

    // Fetch updated
    final updatedData = await (_db.select(
      _db.dayBook,
    )..where((t) => t.id.equals(id))).getSingle();

    // Trigger Sync
    await _enqueueSync(updatedData);

    return DayBookEntry(
      id: updatedData.id,
      businessId: updatedData.businessId,
      date: updatedData.date,
      openingCashBalance: updatedData.openingCashBalance,
      closingCashBalance: updatedData.closingCashBalance,
      computedClosingBalance: updatedData.computedClosingBalance,
      totalSales: updatedData.totalSales,
      totalCashSales: updatedData.totalCashSales,
      totalCreditSales: updatedData.totalCreditSales,
      totalPurchases: updatedData.totalPurchases,
      totalCashPurchases: updatedData.totalCashPurchases,
      totalCreditPurchases: updatedData.totalCreditPurchases,
      totalExpenses: updatedData.totalExpenses,
      totalCashExpenses: updatedData.totalCashExpenses,
      totalPaymentsReceived: updatedData.totalPaymentsReceived,
      totalPaymentsMade: updatedData.totalPaymentsMade,
      salesCount: updatedData.salesCount,
      purchasesCount: updatedData.purchasesCount,
      expensesCount: updatedData.expensesCount,
      paymentsReceivedCount: updatedData.paymentsReceivedCount,
      paymentsMadeCount: updatedData.paymentsMadeCount,
      isReconciled: updatedData.isReconciled,
      reconciledAt: updatedData.reconciledAt,
      reconciledBy: updatedData.reconciledBy,
      reconciliationNotes: updatedData.reconciliationNotes,
      reconciliationDifference: updatedData.reconciliationDifference,
      createdAt: updatedData.createdAt,
      updatedAt: updatedData.updatedAt,
    );
  }

  /// Get previous closing balance locally
  Future<double> _getPreviousClosingBalance(
    String businessId,
    DateTime date,
  ) async {
    // Look back up to 7 days to find the last closing balance
    for (int i = 1; i <= 7; i++) {
      final previousDate = date.subtract(Duration(days: i));
      final dateKey = _dateKey(previousDate);
      final id = '${businessId}_$dateKey';

      final entry = await (_db.select(
        _db.dayBook,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entry != null) {
        return entry.closingCashBalance;
      }
    }

    return 0.0;
  }

  /// Add DayBook update to Sync Queue
  Future<void> _enqueueSync(DayBookEntryEntity entry) async {
    // Use existing SyncManager if available, or direct DB insert
    // Direct DB insert ensures offline-first reliability even without active manager

    final entryModel = DayBookEntry(
      id: entry.id,
      businessId: entry.businessId,
      date: entry.date,
      openingCashBalance: entry.openingCashBalance,
      closingCashBalance: entry.closingCashBalance,
      computedClosingBalance: entry.computedClosingBalance,
      totalSales: entry.totalSales,
      totalCashSales: entry.totalCashSales,
      totalCreditSales: entry.totalCreditSales,
      totalPurchases: entry.totalPurchases,
      totalCashPurchases: entry.totalCashPurchases,
      totalCreditPurchases: entry.totalCreditPurchases,
      totalExpenses: entry.totalExpenses,
      totalCashExpenses: entry.totalCashExpenses,
      totalPaymentsReceived: entry.totalPaymentsReceived,
      totalPaymentsMade: entry.totalPaymentsMade,
      salesCount: entry.salesCount,
      purchasesCount: entry.purchasesCount,
      expensesCount: entry.expensesCount,
      paymentsReceivedCount: entry.paymentsReceivedCount,
      paymentsMadeCount: entry.paymentsMadeCount,
      isReconciled: entry.isReconciled,
      reconciledAt: entry.reconciledAt,
      reconciledBy: entry.reconciledBy,
      reconciliationNotes: entry.reconciliationNotes,
      reconciliationDifference: entry.reconciliationDifference,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );

    final payload = jsonEncode(entryModel.toMap());
    final operationId =
        'SYNC_DAYBOOK_${entry.id}_${DateTime.now().millisecondsSinceEpoch}';

    await _db
        .into(_db.syncQueue)
        .insert(
          SyncQueueCompanion(
            operationId: Value(operationId),
            operationType: const Value('UPDATE'),
            targetCollection: const Value('day_book'),
            documentId: Value(
              entry.id,
            ), // Use local ID or construct remote ID dynamically
            payload: Value(payload),
            status: const Value('PENDING'),
            createdAt: Value(DateTime.now()),
            retryCount: const Value(0),
            userId: Value(entry.businessId), // Using businessId as owner
          ),
        );
  }

  // ============================================
  // LEGACY WRAPPERS (For API Compatibility)
  // ============================================

  /// Incrementally update Day Book when a sale is made.
  Future<void> recordSaleRealtime({
    required String businessId,
    required DateTime saleDate,
    required double amount,
    required bool isCashSale,
    required double cgst,
    required double sgst,
    required double igst,
  }) async {
    await computeDaySummary(businessId, saleDate);
  }

  /// Incrementally update Day Book when a purchase is recorded.
  Future<void> recordPurchaseRealtime({
    required String businessId,
    required DateTime purchaseDate,
    required double amount,
    required bool isCashPurchase,
  }) async {
    await computeDaySummary(businessId, purchaseDate);
  }

  /// Incrementally update Day Book when a payment is received.
  Future<void> recordPaymentReceivedRealtime({
    required String businessId,
    required DateTime paymentDate,
    required double amount,
    required bool isCash,
  }) async {
    await computeDaySummary(businessId, paymentDate);
  }

  /// Incrementally update Day Book when a payment is made.
  Future<void> recordPaymentMadeRealtime({
    required String businessId,
    required DateTime paymentDate,
    required double amount,
    required bool isCash,
  }) async {
    await computeDaySummary(businessId, paymentDate);
  }

  /// Incrementally update Day Book when an expense is recorded.
  Future<void> recordExpenseRealtime({
    required String businessId,
    required DateTime expenseDate,
    required double amount,
    required bool isCash,
  }) async {
    await computeDaySummary(businessId, expenseDate);
  }

  /// Reverse a sale from Day Book.
  Future<void> reverseSaleRealtime({
    required String businessId,
    required DateTime saleDate,
    required double amount,
    required bool wasCashSale,
    required double cgst,
    required double sgst,
    required double igst,
  }) async {
    await computeDaySummary(businessId, saleDate);
  }

  /// Reverse a purchase from Day Book.
  Future<void> reversePurchaseRealtime({
    required String businessId,
    required DateTime purchaseDate,
    required double amount,
    required bool wasCashPurchase,
  }) async {
    await computeDaySummary(businessId, purchaseDate);
  }

  // ============================================================
  // MANDATORY DAY-END CLOSURE (GAP 6 FIX) - OFFLINE VERSION
  // ============================================================

  Future<DayClosureStatus> isDayClosureRequired(String businessId) async {
    // For now, simpler implementation: check generic settings if available
    // Otherwise return false to avoid blocking offline flow if settings missing
    return const DayClosureStatus(
      isRequired: false,
      reason: 'Offline mode: check disabled',
    );
  }

  Future<void> enforceDayClosure(String businessId) async {
    // No-op for now in offline mode refactor
  }
}

/// Status of day closure requirement check
class DayClosureStatus {
  final bool isRequired;
  final DateTime? pendingDate;
  final String? reason;

  const DayClosureStatus({
    required this.isRequired,
    this.pendingDate,
    this.reason,
  });
}

/// Exception thrown when day closure is required but not done
class DayClosureRequiredException implements Exception {
  final String message;
  final DateTime? pendingDate;

  DayClosureRequiredException({required this.message, this.pendingDate});

  @override
  String toString() =>
      'DayClosureRequiredException: $message (pending: ${pendingDate?.toIso8601String()})';
}
