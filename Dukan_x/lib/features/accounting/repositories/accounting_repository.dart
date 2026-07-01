import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../models/models.dart';

/// Accounting Repository for managing ledgers, journal entries, and periods
class AccountingRepository {
  final AppDatabase _db;

  AccountingRepository({AppDatabase? db}) : _db = db ?? sl<AppDatabase>();

  // ============================================================================
  // LEDGER ACCOUNTS
  // ============================================================================

  /// Get all ledger accounts for a user.
  ///
  /// When [businessId] is provided, results are scoped to that business plus
  /// any pre-v41 rows that have a NULL business_id (legacy data). When
  /// omitted, all of the user's ledgers are returned (original behaviour).
  Future<List<LedgerAccountModel>> getAllLedgerAccounts(
    String userId, {
    String? businessId,
  }) async {
    final query = _db.select(_db.ledgerAccounts)
      ..where((t) => t.userId.equals(userId) & t.isActive.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);

    if (businessId != null) {
      // Legacy rows (NULL business_id) are treated as belonging to every
      // business so historical data is never hidden after the migration.
      query.where(
        (t) => t.businessId.isNull() | t.businessId.equals(businessId),
      );
    }

    final results = await query.get();
    return results.map(_ledgerEntityToModel).toList();
  }

  /// Get ledger accounts by group
  Future<List<LedgerAccountModel>> getLedgersByGroup(
    String userId,
    AccountGroup group,
  ) async {
    final results =
        await (_db.select(_db.ledgerAccounts)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.accountGroup.equals(group.value) &
                    t.isActive.equals(true),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();

    return results.map(_ledgerEntityToModel).toList();
  }

  /// Get ledger by ID
  Future<LedgerAccountModel?> getLedgerById(String id) async {
    final result = await (_db.select(
      _db.ledgerAccounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (result == null) return null;
    return _ledgerEntityToModel(result);
  }

  /// Get ledger by linked entity (customer/vendor)
  Future<LedgerAccountModel?> getLedgerByLinkedEntity(
    String userId,
    String entityType,
    String entityId,
  ) async {
    final result =
        await (_db.select(_db.ledgerAccounts)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.linkedEntityType.equals(entityType) &
                  t.linkedEntityId.equals(entityId),
            ))
            .getSingleOrNull();

    if (result == null) return null;
    return _ledgerEntityToModel(result);
  }

  /// Save ledger account
  Future<void> saveLedgerAccount(LedgerAccountModel ledger) async {
    await _db
        .into(_db.ledgerAccounts)
        .insertOnConflictUpdate(
          LedgerAccountsCompanion(
            id: Value(ledger.id),
            userId: Value(ledger.userId),
            name: Value(ledger.name),
            type: Value(ledger.type.value), // Required legacy/redundant field
            accountGroup: Value(ledger.group.value),
            accountType: Value(ledger.type.value),
            currentBalance: Value(ledger.currentBalance),
            openingBalance: Value(ledger.openingBalance),
            openingIsDebit: Value(ledger.openingIsDebit),
            isSystem: Value(ledger.isSystem),
            parentId: Value(ledger.parentId),
            linkedEntityType: Value(ledger.linkedEntityType),
            linkedEntityId: Value(ledger.linkedEntityId),
            isActive: Value(ledger.isActive),
            isSynced: const Value(false),
            createdAt: Value(ledger.createdAt),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Update ledger balance
  Future<void> updateLedgerBalance(String ledgerId, double newBalance) async {
    await (_db.update(
      _db.ledgerAccounts,
    )..where((t) => t.id.equals(ledgerId))).write(
      LedgerAccountsCompanion(
        currentBalance: Value(newBalance),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Create system ledgers for a new user
  Future<void> createSystemLedgers(String userId) async {
    final existingCount =
        await (_db.select(_db.ledgerAccounts)
              ..where((t) => t.userId.equals(userId) & t.isSystem.equals(true)))
            .get()
            .then((l) => l.length);

    if (existingCount > 0) return; // Already created

    for (final def in SystemLedgers.defaults) {
      final ledger = LedgerAccountModel(
        id: const Uuid().v4(),
        userId: userId,
        name: def['name'],
        group: AccountGroupExtension.fromString(def['group']),
        type: AccountTypeExtension.fromString(def['type']),
        isSystem: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await saveLedgerAccount(ledger);
    }
  }

  /// Get or create ledger for customer
  Future<LedgerAccountModel> getOrCreateCustomerLedger(
    String userId,
    String customerId,
    String customerName,
  ) async {
    var ledger = await getLedgerByLinkedEntity(userId, 'CUSTOMER', customerId);
    if (ledger != null) return ledger;

    // Create new ledger for customer
    ledger = LedgerAccountModel(
      id: const Uuid().v4(),
      userId: userId,
      name: customerName,
      group: AccountGroup.assets,
      type: AccountType.customer,
      linkedEntityType: 'CUSTOMER',
      linkedEntityId: customerId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await saveLedgerAccount(ledger);
    return ledger;
  }

  /// Get or create ledger for vendor
  Future<LedgerAccountModel> getOrCreateVendorLedger(
    String userId,
    String vendorId,
    String vendorName,
  ) async {
    var ledger = await getLedgerByLinkedEntity(userId, 'VENDOR', vendorId);
    if (ledger != null) return ledger;

    // Create new ledger for vendor
    ledger = LedgerAccountModel(
      id: const Uuid().v4(),
      userId: userId,
      name: vendorName,
      group: AccountGroup.liabilities,
      type: AccountType.supplier,
      linkedEntityType: 'VENDOR',
      linkedEntityId: vendorId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await saveLedgerAccount(ledger);
    return ledger;
  }

  /// Create ledger account (Convenience method for tests/simpler calls)
  Future<void> createLedgerAccount({
    required String userId,
    required String accountName,
    required String accountType,
    required String linkedEntityType,
    required String linkedEntityId,
  }) async {
    final group = _inferGroupFromType(accountType);

    final ledger = LedgerAccountModel(
      id: const Uuid().v4(),
      userId: userId,
      name: accountName,
      group: group,
      type: AccountTypeExtension.fromString(accountType),
      linkedEntityType: linkedEntityType,
      linkedEntityId: linkedEntityId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await saveLedgerAccount(ledger);
  }

  AccountGroup _inferGroupFromType(String type) {
    switch (type.toUpperCase()) {
      case 'RECEIVABLE':
      case 'ASSET':
      case 'BANK':
      case 'CASH':
        return AccountGroup.assets;
      case 'PAYABLE':
      case 'LIABILITY':
        return AccountGroup.liabilities;
      case 'SALES':
      case 'INCOME':
        return AccountGroup.income;
      case 'EXPENSE':
      case 'PURCHASE':
        return AccountGroup.expenses;
      case 'EQUITY':
        return AccountGroup.equity;
      default:
        return AccountGroup.assets;
    }
  }

  LedgerAccountModel _ledgerEntityToModel(LedgerAccountEntity entity) {
    return LedgerAccountModel(
      id: entity.id,
      userId: entity.userId,
      name: entity.name,
      group: AccountGroupExtension.fromString(entity.accountGroup ?? 'ASSETS'),
      type: AccountTypeExtension.fromString(entity.accountType ?? 'GENERAL'),
      currentBalance: entity.currentBalance,
      openingBalance: entity.openingBalance,
      openingIsDebit: entity.openingIsDebit,
      isSystem: entity.isSystem,
      parentId: entity.parentId,
      linkedEntityType: entity.linkedEntityType,
      linkedEntityId: entity.linkedEntityId,
      isActive: entity.isActive,
      isSynced: entity.isSynced,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  // ============================================================================
  // JOURNAL ENTRIES
  // ============================================================================

  /// Get all journal entries for a user.
  ///
  /// When [businessId] is provided, results are scoped to that business plus
  /// any pre-v41 rows with a NULL business_id (legacy data). See
  /// [getAllLedgerAccounts] for the rationale.
  Future<List<JournalEntryModel>> getAllJournalEntries(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
    String? businessId,
  }) async {
    var query = _db.select(_db.journalEntries)
      ..where((t) => t.userId.equals(userId))
      ..orderBy([(t) => OrderingTerm.desc(t.entryDate)]);

    if (businessId != null) {
      query = query
        ..where(
          (t) => t.businessId.isNull() | t.businessId.equals(businessId),
        );
    }
    if (startDate != null) {
      query = query..where((t) => t.entryDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query = query..where((t) => t.entryDate.isSmallerOrEqualValue(endDate));
    }

    final results = await query.get();
    return results.map(_journalEntityToModel).toList();
  }

  /// Watch journal entries for Day Book (Live Stream)
  /// Ordered strictly by: transactionDate, createdAt, entryId
  Stream<List<JournalEntryModel>> watchDayBookEntries(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return (_db.select(_db.journalEntries)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.entryDate.isBiggerOrEqualValue(startDate) &
                t.entryDate.isSmallerOrEqualValue(endDate),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.entryDate),
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id), // Tie-breaker
          ]))
        .watch()
        .map((rows) => rows.map(_journalEntityToModel).toList());
  }

  /// Get journal entry by ID
  Future<JournalEntryModel?> getJournalEntryById(String id) async {
    final result = await (_db.select(
      _db.journalEntries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (result == null) return null;
    return _journalEntityToModel(result);
  }

  /// Get journal entries by source
  Future<List<JournalEntryModel>> getJournalEntriesBySource(
    String sourceType,
    String sourceId,
  ) async {
    final results =
        await (_db.select(_db.journalEntries)..where(
              (t) =>
                  t.sourceType.equals(sourceType) & t.sourceId.equals(sourceId),
            ))
            .get();

    return results.map(_journalEntityToModel).toList();
  }

  /// Save journal entry
  Future<void> saveJournalEntry(JournalEntryModel entry) async {
    if (!entry.isBalanced) {
      throw Exception(
        'Journal entry is not balanced: Debit ${entry.totalDebit} != Credit ${entry.totalCredit}',
      );
    }

    await _db
        .into(_db.journalEntries)
        .insertOnConflictUpdate(
          JournalEntriesCompanion(
            id: Value(entry.id),
            userId: Value(entry.userId),
            voucherNumber: Value(entry.voucherNumber),
            voucherType: Value(entry.voucherType.value),
            entryDate: Value(entry.entryDate),
            narration: Value(entry.narration),
            sourceType: Value(entry.sourceType?.value),
            sourceId: Value(entry.sourceId),
            entriesJson: Value(
              jsonEncode(entry.entries.map((e) => e.toMap()).toList()),
            ),
            date: Value(entry.entryDate), // Legacy required field
            amount: Value(entry.totalDebit), // Legacy required field
            totalDebit: Value(entry.totalDebit),
            totalCredit: Value(entry.totalCredit),
            isLocked: Value(entry.isLocked),
            isSynced: const Value(false),
            createdAt: Value(entry.createdAt),
            updatedAt: Value(DateTime.now()),
          ),
        );

    // Update Ledger Balances
    for (var line in entry.entries) {
      final ledger = await getLedgerById(line.ledgerId);
      if (ledger != null) {
        // Dr + / Cr - rule for signed balance storage
        final newBalance = ledger.currentBalance + line.debit - line.credit;
        await updateLedgerBalance(ledger.id, newBalance);
      }
    }
  }

  /// Get next voucher number
  Future<String> getNextVoucherNumber(String userId, VoucherType type) async {
    final prefix = type.prefix;
    final now = DateTime.now();
    final yearMonth = '${now.year}${now.month.toString().padLeft(2, '0')}';

    final existingCount =
        await (_db.select(_db.journalEntries)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.voucherNumber.like('$prefix-$yearMonth%'),
            ))
            .get()
            .then((l) => l.length);

    return '$prefix-$yearMonth-${(existingCount + 1).toString().padLeft(4, '0')}';
  }

  /// Record Sales Invoice (Convenience)
  Future<void> recordSalesInvoice({
    required String userId,
    required String customerId,
    required String billId,
    required double amount,
    required DateTime date,
  }) async {
    final voucherNumber = await getNextVoucherNumber(userId, VoucherType.sales);

    // Debit Customer (Receivable)
    final debitLine = JournalEntryLine(
      ledgerId: (await getOrCreateCustomerLedger(
        userId,
        customerId,
        'Customer',
      )).id,
      ledgerName: 'Customer',
      debit: amount,
      credit: 0,
    );

    // Credit Sales Account
    final salesLedger = await _getSystemLedger(userId, 'Sales Account');
    final creditLine = JournalEntryLine(
      ledgerId: salesLedger.id,
      ledgerName: salesLedger.name,
      debit: 0,
      credit: amount,
    );

    final entry = JournalEntryModel(
      id: const Uuid().v4(),
      userId: userId,
      voucherNumber: voucherNumber,
      voucherType: VoucherType.sales,
      entryDate: date,
      narration: 'Sales Invoice #$billId',
      sourceType: SourceType.bill,
      sourceId: billId,
      entries: [debitLine, creditLine],
      totalDebit: amount,
      totalCredit: amount,
      isLocked: false,
      isSynced: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await saveJournalEntry(entry);
  }

  /// Record Payment (Convenience)
  Future<void> recordPayment({
    required String userId,
    required String customerId,
    required String billId,
    required double amount,
    required DateTime date,
  }) async {
    final voucherNumber = await getNextVoucherNumber(
      userId,
      VoucherType.receipt,
    );

    // Debit Cash (Asset)
    final cashLedger = await _getSystemLedger(userId, 'Cash on Hand');
    final debitLine = JournalEntryLine(
      ledgerId: cashLedger.id,
      ledgerName: cashLedger.name,
      debit: amount,
      credit: 0,
    );

    // Credit Customer (Reduces Receivable)
    final creditLine = JournalEntryLine(
      ledgerId: (await getOrCreateCustomerLedger(
        userId,
        customerId,
        'Customer',
      )).id,
      ledgerName: 'Customer',
      debit: 0,
      credit: amount,
    );

    final entry = JournalEntryModel(
      id: const Uuid().v4(),
      userId: userId,
      voucherNumber: voucherNumber,
      voucherType: VoucherType.receipt,
      entryDate: date,
      narration: 'Payment Received for #$billId',
      sourceType: SourceType.bill,
      sourceId: billId,
      entries: [debitLine, creditLine],
      totalDebit: amount,
      totalCredit: amount,
      isLocked: false,
      isSynced: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await saveJournalEntry(entry);
  }

  Future<LedgerAccountModel> _getSystemLedger(
    String userId,
    String name,
  ) async {
    final ledger =
        await (_db.select(_db.ledgerAccounts)
              ..where((t) => t.userId.equals(userId) & t.name.equals(name)))
            .getSingleOrNull();

    if (ledger != null) return _ledgerEntityToModel(ledger);

    // Fallback if system ledger missing (should verify createSystemLedgers called)
    // For now, create on fly
    final newLedger = LedgerAccountModel(
      id: const Uuid().v4(),
      userId: userId,
      name: name,
      group: name == 'Sales Account'
          ? AccountGroup.income
          : AccountGroup.assets,
      type: name == 'Sales Account' ? AccountType.sales : AccountType.cash,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await saveLedgerAccount(newLedger);
    return newLedger;
  }

  JournalEntryModel _journalEntityToModel(JournalEntryEntity entity) {
    List<JournalEntryLine> entries = [];
    try {
      final List<dynamic> decoded = jsonDecode(entity.entriesJson ?? '[]');
      entries = decoded.map((e) => JournalEntryLine.fromMap(e)).toList();
    } catch (_) {}

    return JournalEntryModel(
      id: entity.id,
      userId: entity.userId,
      voucherNumber: entity.voucherNumber ?? '',
      voucherType: VoucherTypeExtension.fromString(
        entity.voucherType ?? 'JOURNAL',
      ),
      entryDate: entity.entryDate,
      narration: entity.narration,
      sourceType: entity.sourceType != null
          ? SourceTypeExtension.fromString(entity.sourceType!)
          : null,
      sourceId: entity.sourceId,
      entries: entries,
      totalDebit: entity.totalDebit,
      totalCredit: entity.totalCredit,
      isLocked: entity.isLocked,
      isSynced: entity.isSynced,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  // ============================================================================
  // ACCOUNTING PERIODS
  // ============================================================================

  /// Get all accounting periods
  Future<List<AccountingPeriodModel>> getAllPeriods(String userId) async {
    final results =
        await (_db.select(_db.accountingPeriods)
              ..where((t) => t.userId.equals(userId))
              ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
            .get();

    return results.map(_periodEntityToModel).toList();
  }

  /// Get current period for a date
  Future<AccountingPeriodModel?> getPeriodForDate(
    String userId,
    DateTime date,
  ) async {
    final results =
        await (_db.select(_db.accountingPeriods)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.startDate.isSmallerOrEqualValue(date) &
                  t.endDate.isBiggerOrEqualValue(date),
            ))
            .getSingleOrNull();

    if (results == null) return null;
    return _periodEntityToModel(results);
  }

  /// Save accounting period
  Future<void> saveAccountingPeriod(AccountingPeriodModel period) async {
    await _db
        .into(_db.accountingPeriods)
        .insertOnConflictUpdate(
          AccountingPeriodsCompanion(
            id: Value(period.id),
            userId: Value(period.userId),
            name: Value(period.name),
            startDate: Value(period.startDate),
            endDate: Value(period.endDate),
            isLocked: Value(period.isLocked),
            lockedAt: Value(period.lockedAt),
            lockedByUserId: Value(period.lockedByUserId),
            isSynced: const Value(false),
            createdAt: Value(period.createdAt),
          ),
        );
  }

  /// Lock a period
  Future<void> lockPeriod(String periodId, String lockedByUserId) async {
    await (_db.update(
      _db.accountingPeriods,
    )..where((t) => t.id.equals(periodId))).write(
      AccountingPeriodsCompanion(
        isLocked: const Value(true),
        lockedAt: Value(DateTime.now()),
        lockedByUserId: Value(lockedByUserId),
        isSynced: const Value(false),
      ),
    );
  }

  AccountingPeriodModel _periodEntityToModel(AccountingPeriodEntity entity) {
    return AccountingPeriodModel(
      id: entity.id,
      userId: entity.userId,
      name: entity.name ?? 'Unnamed Period',
      startDate: entity.startDate,
      endDate: entity.endDate,
      isLocked: entity.isLocked,
      lockedAt: entity.lockedAt,
      lockedByUserId: entity.lockedByUserId,
      isSynced: entity.isSynced,
      createdAt: entity.createdAt,
    );
  }
}
