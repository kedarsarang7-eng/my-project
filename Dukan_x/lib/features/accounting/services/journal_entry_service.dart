import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../repositories/accounting_repository.dart';

/// Journal Entry Service - Auto-generates journal entries from transactions
///
/// Implements Tally-style automatic entry creation for:
/// - Sales invoices
/// - Purchase invoices
/// - Payments received
/// - Payments made
/// - Expenses
class JournalEntryService {
  final AccountingRepository _repo;

  JournalEntryService({AccountingRepository? repo})
    : _repo = repo ?? AccountingRepository();

  Future<List<JournalEntryModel>> getEntriesBySource(
    String sourceType,
    String sourceId,
  ) async {
    return _repo.getJournalEntriesBySource(sourceType, sourceId);
  }

  /// Get day book entries by date range (Strict Ledger Order)
  Stream<List<JournalEntryModel>> watchEntriesByDateRange(
    String userId,
    DateTime start,
    DateTime end, {
    bool includeSystemEntries = true,
  }) {
    return _repo.watchDayBookEntries(userId, start, end).map((entries) {
      if (includeSystemEntries) return entries;
      // Filter out purely system/reconcilation entries if requested
      return entries
          .where(
            (e) =>
                e.classification !=
                AccountingEntryClassification.systemGenerated,
          )
          .toList();
    });
  }

  // ============================================================================
  // SALES JOURNAL ENTRIES
  // ============================================================================

  /// Create journal entry for a sales invoice
  ///
  /// Debit: Customer A/c (receivable)
  /// Credit: Sales A/c
  /// Credit: CGST/SGST/IGST Payable (if GST)
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
    final entries = <JournalEntryLine>[];

    // Get/create customer ledger
    final customerLedger = await _repo.getOrCreateCustomerLedger(
      userId,
      customerId,
      customerName,
    );

    // Get system ledgers
    final ledgers = await _repo.getAllLedgerAccounts(userId);
    final salesLedger = _findSystemLedger(ledgers, 'Sales Account');
    final cgstLedger = _findSystemLedger(ledgers, 'CGST Payable');
    final sgstLedger = _findSystemLedger(ledgers, 'SGST Payable');
    final igstLedger = _findSystemLedger(ledgers, 'IGST Payable');
    final discountLedger = _findSystemLedger(ledgers, 'Discount Allowed');

    // Debit: Customer (total amount)
    entries.add(
      JournalEntryLine(
        ledgerId: customerLedger.id,
        ledgerName: customerLedger.name,
        debit: totalAmount,
        description: 'Invoice $invoiceNumber',
      ),
    );

    // Credit: Sales (taxable amount)
    if (salesLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: salesLedger.id,
          ledgerName: salesLedger.name,
          credit: taxableAmount,
          description: 'Sales',
        ),
      );
    }

    // Credit: CGST Payable
    if (cgstAmount > 0 && cgstLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: cgstLedger.id,
          ledgerName: cgstLedger.name,
          credit: cgstAmount,
          description: 'CGST Output',
        ),
      );
    }

    // Credit: SGST Payable
    if (sgstAmount > 0 && sgstLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: sgstLedger.id,
          ledgerName: sgstLedger.name,
          credit: sgstAmount,
          description: 'SGST Output',
        ),
      );
    }

    // Credit: IGST Payable
    if (igstAmount > 0 && igstLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: igstLedger.id,
          ledgerName: igstLedger.name,
          credit: igstAmount,
          description: 'IGST Output',
        ),
      );
    }

    // Debit: Discount (if any) - reduces total
    if (discountAmount > 0 && discountLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: discountLedger.id,
          ledgerName: discountLedger.name,
          debit: discountAmount,
          description: 'Discount Allowed',
        ),
      );
    }

    final totalDebit = entries.fold<double>(0, (sum, e) => sum + e.debit);
    final totalCredit = entries.fold<double>(0, (sum, e) => sum + e.credit);

    final voucherNumber = await _repo.getNextVoucherNumber(
      userId,
      VoucherType.sales,
    );

    final journalEntry = JournalEntryModel(
      id: const Uuid().v4(),
      userId: userId,
      voucherNumber: voucherNumber,
      voucherType: VoucherType.sales,
      entryDate: invoiceDate,
      narration: 'Sales Invoice $invoiceNumber to $customerName',
      sourceType: SourceType.bill,
      sourceId: billId,
      entries: entries,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repo.saveJournalEntry(journalEntry);
    return journalEntry;
  }

  // ============================================================================
  // PURCHASE JOURNAL ENTRIES
  // ============================================================================

  /// Create journal entry for a purchase invoice
  ///
  /// Debit: Purchase A/c
  /// Debit: CGST/SGST/IGST Receivable (if GST - input credit)
  /// Credit: Vendor A/c (payable)
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
    final entries = <JournalEntryLine>[];

    // Get/create vendor ledger
    final vendorLedger = await _repo.getOrCreateVendorLedger(
      userId,
      vendorId,
      vendorName,
    );

    // Get system ledgers
    final ledgers = await _repo.getAllLedgerAccounts(userId);
    final purchaseLedger = _findSystemLedger(ledgers, 'Purchase Account');
    final cgstLedger = _findSystemLedger(ledgers, 'CGST Receivable');
    final sgstLedger = _findSystemLedger(ledgers, 'SGST Receivable');
    final igstLedger = _findSystemLedger(ledgers, 'IGST Receivable');

    // Debit: Purchase (taxable amount)
    if (purchaseLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: purchaseLedger.id,
          ledgerName: purchaseLedger.name,
          debit: taxableAmount,
          description: 'Purchase',
        ),
      );
    }

    // Debit: CGST Receivable (input credit)
    if (cgstAmount > 0 && cgstLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: cgstLedger.id,
          ledgerName: cgstLedger.name,
          debit: cgstAmount,
          description: 'CGST Input',
        ),
      );
    }

    // Debit: SGST Receivable
    if (sgstAmount > 0 && sgstLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: sgstLedger.id,
          ledgerName: sgstLedger.name,
          debit: sgstAmount,
          description: 'SGST Input',
        ),
      );
    }

    // Debit: IGST Receivable
    if (igstAmount > 0 && igstLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: igstLedger.id,
          ledgerName: igstLedger.name,
          debit: igstAmount,
          description: 'IGST Input',
        ),
      );
    }

    // Credit: Vendor (total amount)
    entries.add(
      JournalEntryLine(
        ledgerId: vendorLedger.id,
        ledgerName: vendorLedger.name,
        credit: totalAmount,
        description: 'Purchase $purchaseNumber',
      ),
    );

    final totalDebit = entries.fold<double>(0, (sum, e) => sum + e.debit);
    final totalCredit = entries.fold<double>(0, (sum, e) => sum + e.credit);

    final voucherNumber = await _repo.getNextVoucherNumber(
      userId,
      VoucherType.purchase,
    );

    final journalEntry = JournalEntryModel(
      id: const Uuid().v4(),
      userId: userId,
      voucherNumber: voucherNumber,
      voucherType: VoucherType.purchase,
      entryDate: purchaseDate,
      narration: 'Purchase Invoice $purchaseNumber from $vendorName',
      sourceType: SourceType.purchaseOrder,
      sourceId: purchaseOrderId,
      entries: entries,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repo.saveJournalEntry(journalEntry);
    return journalEntry;
  }

  // ============================================================================
  // PAYMENT RECEIPT JOURNAL ENTRIES
  // ============================================================================

  /// Create journal entry for payment received from customer
  ///
  /// Debit: Cash/Bank A/c
  /// Credit: Customer A/c
  Future<JournalEntryModel> createReceiptEntry({
    required String userId,
    required String paymentId,
    required String customerId,
    required String customerName,
    required double amount,
    required String paymentMode, // CASH, BANK, UPI
    required DateTime paymentDate,
    String? billId,
  }) async {
    final entries = <JournalEntryLine>[];

    // Get customer ledger
    final customerLedger = await _repo.getOrCreateCustomerLedger(
      userId,
      customerId,
      customerName,
    );

    // Get cash/bank ledger
    final ledgers = await _repo.getAllLedgerAccounts(userId);
    final cashBankLedger = paymentMode.toUpperCase() == 'CASH'
        ? _findSystemLedger(ledgers, 'Cash in Hand')
        : _findSystemLedger(ledgers, 'Primary Bank Account');

    // Debit: Cash/Bank
    if (cashBankLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: cashBankLedger.id,
          ledgerName: cashBankLedger.name,
          debit: amount,
          description: 'Payment from $customerName',
        ),
      );
    }

    // Credit: Customer
    entries.add(
      JournalEntryLine(
        ledgerId: customerLedger.id,
        ledgerName: customerLedger.name,
        credit: amount,
        description: 'Payment received',
      ),
    );

    final voucherNumber = await _repo.getNextVoucherNumber(
      userId,
      VoucherType.receipt,
    );

    final journalEntry = JournalEntryModel(
      id: const Uuid().v4(),
      userId: userId,
      voucherNumber: voucherNumber,
      voucherType: VoucherType.receipt,
      entryDate: paymentDate,
      narration: 'Payment received from $customerName via $paymentMode',
      sourceType: SourceType.payment,
      sourceId: paymentId,
      entries: entries,
      totalDebit: amount,
      totalCredit: amount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repo.saveJournalEntry(journalEntry);
    return journalEntry;
  }

  /// Create journal entry for payment made to vendor
  ///
  /// Debit: Vendor A/c
  /// Credit: Cash/Bank A/c
  ///
  /// For bank payments, [bankAccountRef] and [paymentRef] are recorded in the
  /// journal narration to provide an audit trail (Requirement 10.7).
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
    final entries = <JournalEntryLine>[];

    // Get vendor ledger
    final vendorLedger = await _repo.getOrCreateVendorLedger(
      userId,
      vendorId,
      vendorName,
    );

    // Get cash/bank ledger
    final ledgers = await _repo.getAllLedgerAccounts(userId);
    final cashBankLedger = paymentMode.toUpperCase() == 'CASH'
        ? _findSystemLedger(ledgers, 'Cash in Hand')
        : _findSystemLedger(ledgers, 'Primary Bank Account');

    // Debit: Vendor
    entries.add(
      JournalEntryLine(
        ledgerId: vendorLedger.id,
        ledgerName: vendorLedger.name,
        debit: amount,
        description: 'Payment made',
      ),
    );

    // Credit: Cash/Bank
    if (cashBankLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: cashBankLedger.id,
          ledgerName: cashBankLedger.name,
          credit: amount,
          description: 'Payment to $vendorName',
        ),
      );
    }

    // Build narration including bank details when applicable (Requirement 10.7)
    String narration = 'Payment made to $vendorName via $paymentMode';
    if (paymentMode.toUpperCase() == 'BANK' &&
        bankAccountRef != null &&
        paymentRef != null) {
      narration += ' [A/c: $bankAccountRef, Ref: $paymentRef]';
    }

    final voucherNumber = await _repo.getNextVoucherNumber(
      userId,
      VoucherType.payment,
    );

    final journalEntry = JournalEntryModel(
      id: const Uuid().v4(),
      userId: userId,
      voucherNumber: voucherNumber,
      voucherType: VoucherType.payment,
      entryDate: paymentDate,
      narration: narration,
      sourceType: SourceType.payment,
      sourceId: paymentId,
      entries: entries,
      totalDebit: amount,
      totalCredit: amount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repo.saveJournalEntry(journalEntry);
    return journalEntry;
  }

  // ============================================================================
  // EXPENSE JOURNAL ENTRIES
  // ============================================================================

  /// Create journal entry for an expense
  ///
  /// Debit: Expense A/c
  /// Credit: Cash/Bank A/c
  Future<JournalEntryModel> createExpenseEntry({
    required String userId,
    required String expenseId,
    required String expenseCategory,
    required double amount,
    required String paymentMode,
    required DateTime expenseDate,
    String? description,
  }) async {
    final entries = <JournalEntryLine>[];

    // Get expense ledger (or create if doesn't exist)
    final ledgers = await _repo.getAllLedgerAccounts(userId);
    var expenseLedger = _findSystemLedger(ledgers, expenseCategory);
    expenseLedger ??= _findSystemLedger(ledgers, 'Miscellaneous Expenses');

    // Get cash/bank ledger
    final cashBankLedger = paymentMode.toUpperCase() == 'CASH'
        ? _findSystemLedger(ledgers, 'Cash in Hand')
        : _findSystemLedger(ledgers, 'Primary Bank Account');

    // Debit: Expense
    if (expenseLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: expenseLedger.id,
          ledgerName: expenseLedger.name,
          debit: amount,
          description: description ?? expenseCategory,
        ),
      );
    }

    // Credit: Cash/Bank
    if (cashBankLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: cashBankLedger.id,
          ledgerName: cashBankLedger.name,
          credit: amount,
          description: 'Expense payment',
        ),
      );
    }

    final voucherNumber = await _repo.getNextVoucherNumber(
      userId,
      VoucherType.payment,
    );

    final journalEntry = JournalEntryModel(
      id: const Uuid().v4(),
      userId: userId,
      voucherNumber: voucherNumber,
      voucherType: VoucherType.payment,
      entryDate: expenseDate,
      narration: description ?? 'Expense: $expenseCategory',
      sourceType: SourceType.expense,
      sourceId: expenseId,
      entries: entries,
      totalDebit: amount,
      totalCredit: amount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repo.saveJournalEntry(journalEntry);
    return journalEntry;
  }

  // ============================================================================
  // STOCK JOURNAL ENTRIES
  // ============================================================================

  /// Create journal entry for stock adjustment (Perpetual Inventory / Adjustments)
  ///
  /// Stock IN:
  /// Debit: Stock-in-Trade (Asset)
  /// Credit: Stock Adjustment (Income/Equity) works for Opening/Surplus
  ///
  /// Stock OUT:
  /// Debit: Cost of Goods Sold / Stock Adjustment (Expense)
  /// Credit: Stock-in-Trade (Asset)
  Future<JournalEntryModel> createStockEntry({
    required String userId,
    required String referenceId,
    required String type, // 'IN' or 'OUT'
    required String reason, // SALE, PURCHASE, DAMAGE, OPENING...
    required double amount,
    required DateTime date,
    String? description,
  }) async {
    final entries = <JournalEntryLine>[];
    final ledgers = await _repo.getAllLedgerAccounts(userId);

    // 1. Get Stock Asset Ledger
    final stockLedger = _findSystemLedger(ledgers, 'Stock-in-Trade');
    if (stockLedger == null) {
      throw Exception('Stock-in-Trade ledger not found');
    }

    // 2. Determine Offset Ledger based on Reason
    LedgerAccountModel? offsetLedger;

    switch (reason) {
      case 'SALE':
      case 'CONSUMPTION':
        // OUT: Dr COGS
        // We might not have COGS, so use Purchase Account or create COGS
        offsetLedger = _findSystemLedger(
          ledgers,
          'Purchase Account',
        ); // Using Purchase as COGS proxy
        break;
      case 'PURCHASE':
        // IN: Cr Purchase (to move from Expense to Asset)?
        // Or if we already debited Purchase in createPurchaseEntry, we might not want to double count.
        // If we strictly follow: Purchase Entry = Dr Purchase / Cr Vendor.
        // Then Stock Entry = Dr Inventory / Cr Purchase.
        offsetLedger = _findSystemLedger(ledgers, 'Purchase Account');
        break;
      case 'DAMAGE':
      case 'LOSS':
        // OUT: Dr Loss on Goods
        offsetLedger = _findSystemLedger(
          ledgers,
          'Miscellaneous Expenses',
        ); // Fallback
        break;
      case 'OPENING_STOCK':
        // IN: Cr Capital/Opening Balance
        offsetLedger = _findSystemLedger(ledgers, 'Capital Account');
        break;
      default:
        offsetLedger = _findSystemLedger(ledgers, 'Stock Adjustment');
        // If no auto Stock Adjustment ledger, fallback to Misc Expense or Other Income
        offsetLedger ??= _findSystemLedger(ledgers, 'Other Income');
    }

    // If offset still null, fail or specific handling?
    // Let's safe fail to Other Income if not found (very unlikely in defaults)
    offsetLedger ??= _findSystemLedger(ledgers, 'Other Income');

    if (offsetLedger == null) {
      // Should not happen given defaults
      throw Exception('Suitable offset ledger not found for reason: $reason');
    }

    if (type == 'IN') {
      // Dr Stock, Cr Offset
      entries.add(
        JournalEntryLine(
          ledgerId: stockLedger.id,
          ledgerName: stockLedger.name,
          debit: amount,
          description: description ?? 'Stock IN: $reason',
        ),
      );
      entries.add(
        JournalEntryLine(
          ledgerId: offsetLedger.id,
          ledgerName: offsetLedger.name,
          credit: amount,
          description: 'Correction for Stock IN',
        ),
      );
    } else {
      // Dr Offset, Cr Stock
      entries.add(
        JournalEntryLine(
          ledgerId: offsetLedger.id,
          ledgerName: offsetLedger.name,
          debit: amount,
          description: 'Cost/Adjustment for Stock OUT',
        ),
      );
      entries.add(
        JournalEntryLine(
          ledgerId: stockLedger.id,
          ledgerName: stockLedger.name,
          credit: amount,
          description: description ?? 'Stock OUT: $reason',
        ),
      );
    }

    final voucherNumber = await _repo.getNextVoucherNumber(
      userId,
      VoucherType.journal,
    );

    final journalEntry = JournalEntryModel(
      id: const Uuid().v4(),
      userId: userId,
      voucherNumber: voucherNumber,
      voucherType: VoucherType.journal,
      entryDate: date,
      narration: description ?? 'Stock $type ($reason)',
      sourceType:
          SourceType.inventory, // We might need to add this to SourceType enum
      sourceId: referenceId,
      entries: entries,
      totalDebit: amount,
      totalCredit: amount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repo.saveJournalEntry(journalEntry);
    return journalEntry;
  }

  LedgerAccountModel? _findSystemLedger(
    List<LedgerAccountModel> ledgers,
    String name,
  ) {
    try {
      return ledgers.firstWhere(
        (l) => l.name.toLowerCase() == name.toLowerCase() && l.isSystem,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================================
  // RETURN/CREDIT NOTE JOURNAL ENTRIES
  // ============================================================================

  /// Create journal entry for a sales return (credit note)
  ///
  /// This reverses a sale by:
  /// Credit: Customer A/c (reduces receivable - customer owes less)
  /// Debit: Sales Return A/c (contra-revenue - reduces sales)
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
    final entries = <JournalEntryLine>[];

    // Get customer ledger
    final customerLedger = await _repo.getOrCreateCustomerLedger(
      userId,
      customerId,
      customerName,
    );

    // Get system ledgers
    final ledgers = await _repo.getAllLedgerAccounts(userId);

    // Use Sales Return ledger if exists, otherwise use Sales Account as contra
    var salesReturnLedger = _findSystemLedger(ledgers, 'Sales Return');
    salesReturnLedger ??= _findSystemLedger(ledgers, 'Sales Account');

    // Debit: Sales Return (contra-revenue, reduces sales)
    if (salesReturnLedger != null) {
      entries.add(
        JournalEntryLine(
          ledgerId: salesReturnLedger.id,
          ledgerName: salesReturnLedger.name,
          debit: amount,
          description: 'Sales Return $creditNoteNumber',
        ),
      );
    }

    // Credit: Customer (reduces receivable)
    entries.add(
      JournalEntryLine(
        ledgerId: customerLedger.id,
        ledgerName: customerLedger.name,
        credit: amount,
        description:
            'Credit Note $creditNoteNumber${originalBillId != null ? ' (Ref: $originalBillId)' : ''}',
      ),
    );

    final voucherNumber = await _repo.getNextVoucherNumber(
      userId,
      VoucherType.creditNote,
    );

    final journalEntry = JournalEntryModel(
      id: const Uuid().v4(),
      userId: userId,
      voucherNumber: voucherNumber,
      voucherType: VoucherType.creditNote,
      entryDate: returnDate,
      narration:
          'Credit Note $creditNoteNumber - Sales Return from $customerName',
      sourceType: SourceType.returnInward,
      sourceId: returnId,
      entries: entries,
      totalDebit: amount,
      totalCredit: amount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repo.saveJournalEntry(journalEntry);
    return journalEntry;
  }

  // ============================================================================
  // REVERSAL ENTRIES (AUDIT TRAIL)
  // ============================================================================

  /// Create a reversal entry for any previous transaction.
  /// Safely swaps Debits and Credits to nullify the financial impact.
  Future<JournalEntryModel> createReversalEntry({
    required JournalEntryModel originalEntry,
    required String reversedByUserId,
    required String reason,
    DateTime? reversalDate,
  }) async {
    final entries = <JournalEntryLine>[];

    // Swap Debit <-> Credit
    for (var line in originalEntry.entries) {
      entries.add(
        JournalEntryLine(
          ledgerId: line.ledgerId,
          ledgerName: line.ledgerName,
          debit: line.credit, // SWAP
          credit: line.debit, // SWAP
          description: 'Reversal: ${line.description ?? ""}',
        ),
      );
    }

    // Get next voucher number for the same type (or use Journal)
    final voucherNumber = await _repo.getNextVoucherNumber(
      reversedByUserId,
      originalEntry.voucherType,
    );

    final journalEntry = JournalEntryModel(
      id: const Uuid().v4(),
      userId: reversedByUserId,
      voucherNumber: voucherNumber,
      voucherType: originalEntry.voucherType,
      entryDate: reversalDate ?? DateTime.now(),
      narration: 'Reversal of ${originalEntry.voucherNumber}: $reason',
      sourceType: SourceType.reversal,
      sourceId: originalEntry.id,
      entries: entries,
      totalDebit: originalEntry.totalCredit, // Swapped totals
      totalCredit: originalEntry.totalDebit,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repo.saveJournalEntry(journalEntry);
    return journalEntry;
  }
}
