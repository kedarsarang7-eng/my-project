import '../models/models.dart';
import 'journal_entry_service.dart';
import 'locking_service.dart';

/// Accounting Service - Facade for accounting operations with policy enforcement
class AccountingService {
  final JournalEntryService _journalService;
  final LockingService _lockingService;

  AccountingService(this._journalService, this._lockingService);

  /// Create a sales journal entry with lock validation
  Future<JournalEntryModel> createSalesEntry({
    required String userId,
    required String billId,
    required String customerId,
    required String customerName,
    required double totalAmount,
    required double taxableAmount,
    required double cgstAmount,
    required double sgstAmount,
    required double igstAmount,
    required double discountAmount,
    required DateTime invoiceDate,
    required String invoiceNumber,
  }) async {
    // 1. Validate Period Lock
    await _lockingService.validateAction(userId, invoiceDate);

    // 2. Delegate to Journal Service
    return _journalService.createSalesEntry(
      userId: userId,
      billId: billId,
      customerId: customerId,
      customerName: customerName,
      totalAmount: totalAmount,
      taxableAmount: taxableAmount,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      igstAmount: igstAmount,
      discountAmount: discountAmount,
      invoiceDate: invoiceDate,
      invoiceNumber: invoiceNumber,
    );
  }

  /// Create a purchase journal entry with lock validation
  Future<JournalEntryModel> createPurchaseEntry({
    required String userId,
    required String purchaseOrderId,
    required String vendorId,
    required String vendorName,
    required double totalAmount,
    required double taxableAmount,
    required double cgstAmount,
    required double sgstAmount,
    required double igstAmount,
    required DateTime purchaseDate,
    required String purchaseNumber,
  }) async {
    await _lockingService.validateAction(userId, purchaseDate);

    return _journalService.createPurchaseEntry(
      userId: userId,
      purchaseOrderId: purchaseOrderId,
      vendorId: vendorId,
      vendorName: vendorName,
      totalAmount: totalAmount,
      taxableAmount: taxableAmount,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      igstAmount: igstAmount,
      purchaseDate: purchaseDate,
      purchaseNumber: purchaseNumber,
    );
  }

  /// Create a receipt entry with lock validation
  Future<JournalEntryModel> createReceiptEntry({
    required String userId,
    required String paymentId,
    required String customerId,
    required String customerName,
    required double amount,
    required String paymentMode,
    required DateTime paymentDate,
    String? billId,
  }) async {
    await _lockingService.validateAction(userId, paymentDate);

    return _journalService.createReceiptEntry(
      userId: userId,
      paymentId: paymentId,
      customerId: customerId,
      customerName: customerName,
      amount: amount,
      paymentMode: paymentMode,
      paymentDate: paymentDate,
    );
  }

  /// Create a payment entry with lock validation.
  ///
  /// For bank payments, [bankAccountRef] and [paymentRef] record the bank
  /// account and transaction reference respectively (Requirement 10.7).
  Future<JournalEntryModel> createPaymentEntry({
    required String userId,
    required String paymentId,
    required String vendorId,
    required String vendorName,
    required double amount,
    required String paymentMode,
    required DateTime paymentDate,
    String? bankAccountRef,
    String? paymentRef,
  }) async {
    await _lockingService.validateAction(userId, paymentDate);

    return _journalService.createPaymentEntry(
      userId: userId,
      paymentId: paymentId,
      vendorId: vendorId,
      vendorName: vendorName,
      amount: amount,
      paymentMode: paymentMode,
      paymentDate: paymentDate,
      bankAccountRef: bankAccountRef,
      paymentRef: paymentRef,
    );
  }

  /// Create an expense entry with lock validation
  Future<JournalEntryModel> createExpenseEntry({
    required String userId,
    required String expenseId,
    required String expenseCategory,
    required double amount,
    required String paymentMode,
    required DateTime expenseDate,
    String? description,
  }) async {
    await _lockingService.validateAction(userId, expenseDate);

    return _journalService.createExpenseEntry(
      userId: userId,
      expenseId: expenseId,
      expenseCategory: expenseCategory,
      amount: amount,
      paymentMode: paymentMode,
      expenseDate: expenseDate,
      description: description,
    );
  }

  /// Create a stock journal entry with lock validation
  Future<JournalEntryModel> createStockEntry({
    required String userId,
    required String referenceId,
    required String type,
    required String reason,
    required double amount,
    required DateTime date,
    String? description,
  }) async {
    await _lockingService.validateAction(userId, date);

    return _journalService.createStockEntry(
      userId: userId,
      referenceId: referenceId,
      type: type,
      reason: reason,
      amount: amount,
      date: date,
      description: description,
    );
  }

  /// Create a sales return (credit note) journal entry with lock validation
  ///
  /// This reverses a sale by:
  /// - CR: Customer A/c (reduces receivable)
  /// - DR: Sales Return A/c (reduces revenue)
  Future<JournalEntryModel> createReturnEntry({
    required String userId,
    required String returnId,
    required String customerId,
    required String customerName,
    required double amount,
    required DateTime returnDate,
    required String creditNoteNumber,
    String? originalBillId,
  }) async {
    await _lockingService.validateAction(userId, returnDate);

    return _journalService.createReturnEntry(
      userId: userId,
      returnId: returnId,
      customerId: customerId,
      customerName: customerName,
      amount: amount,
      returnDate: returnDate,
      creditNoteNumber: creditNoteNumber,
      originalBillId: originalBillId,
    );
  }

  // ============================================================
  // GAP-2 PATCH: Period Lock Check for Repository Use
  // ============================================================
  /// Check if a date falls within a locked accounting period.
  Future<bool> isPeriodLocked({
    required String userId,
    required DateTime date,
  }) async {
    try {
      await _lockingService.validateAction(userId, date);
      return false;
    } catch (e) {
      return true;
    }
  }

  /// 🌟 REVERSAL LOGIC: Local Implementation
  /// Safely reverses a transaction by creating contra-entries.
  /// If [reversalDate] is null, uses DateTime.now().
  /// Throws if [reversalDate] is in a locked period.
  Future<void> reverseTransaction({
    required String userId,
    required String sourceType, // 'BILL' or 'PAYMENT'
    required String sourceId,
    required String reason,
    DateTime? reversalDate,
  }) async {
    final date = reversalDate ?? DateTime.now();

    // 1. Validate Lock (Reversal entry itself must be in open period)
    await _lockingService.validateAction(userId, date);

    // 2. Fetch Original Entries
    final entries = await _journalService.getEntriesBySource(
      sourceType,
      sourceId,
    );

    if (entries.isEmpty) {
      // Nothing to reverse (maybe legacy data or draft), just warn/return
      // debugPrint("No journal entries found for $sourceId to reverse.");
      return;
    }

    // 3. Create Reversal Entries
    for (var entry in entries) {
      // Skip if already reversed? Logic complexity here.
      // Simplest: Just reverse what we found.
      await _journalService.createReversalEntry(
        originalEntry: entry,
        reversedByUserId: userId,
        reason: reason,
        reversalDate: date,
      );
    }
  }
}
