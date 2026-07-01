import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/features/accounting/models/journal_entry_model.dart';
import 'package:dukanx/features/accounting/repositories/accounting_repository.dart';
import 'package:dukanx/features/accounting/services/accounting_service.dart';
import 'package:dukanx/features/accounting/services/journal_entry_service.dart';
import 'package:dukanx/features/accounting/services/locking_service.dart';
import 'package:dukanx/core/repository/bills_repository.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/core/error/error_handler.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Mocks
class MockSyncManager extends Mock implements SyncManager {
  @override
  Future<String> enqueue(SyncQueueItem item) async {
    return 'mock_op_id';
  }
}

class MockErrorHandler extends Mock implements ErrorHandler {
  @override
  Future<RepositoryResult<T>> runSafe<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    final result = await operation();
    return RepositoryResult.success(result);
  }
}

void main() {
  late AppDatabase database;
  late AccountingRepository accRepo;
  late JournalEntryService journalService;
  late LockingService lockingService;
  late AccountingService accountingService;
  late BillsRepository billsRepo;
  late MockSyncManager syncManager;
  late MockErrorHandler errorHandler;

  final userId = 'test_user_123';

  setUp(() async {
    // Correct usage for test DB
    database = AppDatabase.forTesting(NativeDatabase.memory());

    accRepo = AccountingRepository(db: database);
    journalService = JournalEntryService(repo: accRepo);
    lockingService = LockingService(database);
    accountingService = AccountingService(journalService, lockingService);

    syncManager = MockSyncManager();
    errorHandler = MockErrorHandler();

    billsRepo = BillsRepository(
      database: database,
      syncManager: syncManager,
      errorHandler: errorHandler,
      accountingService: accountingService,
    );

    // Seed System Ledgers
    await accRepo.createSystemLedgers(userId);
  });

  tearDown(() async {
    await database.close();
  });

  group('Day Book Refactor - Full Integration', () {
    test('Strict Ordering of Entries', () async {
      final date1 = DateTime(2025, 1, 1, 10, 0);
      final date2 = DateTime(2025, 1, 1, 11, 0);

      final entry1 = JournalEntryModel(
        id: '1',
        userId: userId,
        voucherNumber: 'V1',
        voucherType: VoucherType.sales,
        entryDate: date1,
        entries: [
          JournalEntryLine(
            ledgerId: 'l1',
            ledgerName: 'L1',
            debit: 100,
            credit: 0,
          ),
          JournalEntryLine(
            ledgerId: 'l2',
            ledgerName: 'L2',
            debit: 0,
            credit: 100,
          ),
        ],
        totalDebit: 100,
        totalCredit: 100,
        createdAt: date1,
        updatedAt: date1,
      );

      await accRepo.saveJournalEntry(entry1);

      final entry2 = JournalEntryModel(
        id: '2',
        userId: userId,
        voucherNumber: 'V2',
        voucherType: VoucherType.purchase,
        entryDate: date2,
        entries: [
          JournalEntryLine(
            ledgerId: 'l1',
            ledgerName: 'L1',
            debit: 200,
            credit: 0,
          ),
          JournalEntryLine(
            ledgerId: 'l2',
            ledgerName: 'L2',
            debit: 0,
            credit: 200,
          ),
        ],
        totalDebit: 200,
        totalCredit: 200,
        createdAt: date2,
        updatedAt: date2,
      );
      await accRepo.saveJournalEntry(entry2);

      final date1Later = date1.add(const Duration(minutes: 5));
      final entry3 = JournalEntryModel(
        id: '3',
        userId: userId,
        voucherNumber: 'V3',
        voucherType: VoucherType.payment,
        entryDate: date1,
        entries: [
          JournalEntryLine(
            ledgerId: 'l1',
            ledgerName: 'L1',
            debit: 300,
            credit: 0,
          ),
          JournalEntryLine(
            ledgerId: 'l2',
            ledgerName: 'L2',
            debit: 0,
            credit: 300,
          ),
        ],
        totalDebit: 300,
        totalCredit: 300,
        createdAt: date1Later,
        updatedAt: date1Later,
      );
      await accRepo.saveJournalEntry(entry3);

      final stream = journalService.watchEntriesByDateRange(
        userId,
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 2),
      );
      final list = await stream.first;

      expect(list.length, 3);
      expect(list[0].id, '2'); // Latest Date
      expect(list[1].id, '3'); // Same Date, Later Created
      expect(list[2].id, '1'); // Same Date, Earlier Created
    });

    test('Bill Creation generates Journal Entry', () async {
      // 1. Create Bill
      final item = BillItem(
        productId: 'p1',
        productName: 'Item A',
        qty: 1,
        price: 100,
        gstRate: 0,
        discount: 0,
      );

      final bill = Bill(
        id: 'bill_1',
        ownerId: userId,
        invoiceNumber: 'INV-001',
        customerId: '',
        customerName: 'Cash',
        date: DateTime.now(),
        items: [item],
        subtotal: 100,
        totalTax: 0,
        grandTotal: 100,
        paidAmount: 100,
        status: 'Paid',
        paymentType: 'Cash',
        updatedAt: DateTime.now(),
      );

      await billsRepo.createBill(bill);

      // 2. Verify Journal Entry
      final entries = await journalService.getEntriesBySource('BILL', 'bill_1');
      expect(entries.length, 1);
      final entry = entries.first;
      expect(entry.classification, AccountingEntryClassification.bill);
      expect(entry.totalDebit, 100.0);
    });

    test('Bill Deletion Reverses Journal Entry', () async {
      // 1. Create and verify Bill
      final item = BillItem(
        productId: 'p1',
        productName: 'Item A',
        qty: 1,
        price: 500,
        gstRate: 0,
        discount: 0,
      );
      final bill = Bill(
        id: 'bill_del',
        ownerId: userId,
        invoiceNumber: 'INV-DEL',
        customerId: '',
        customerName: 'Cash',
        date: DateTime.now(),
        items: [item],
        subtotal: 500,
        totalTax: 0,
        grandTotal: 500,
        paidAmount: 500,
        status: 'Paid',
        paymentType: 'Cash',
        updatedAt: DateTime.now(),
      );

      await billsRepo.createBill(bill);
      var entries = await journalService.getEntriesBySource('BILL', 'bill_del');
      expect(entries.length, 1);

      // 2. Delete Bill
      await billsRepo.deleteBill('bill_del', userId);

      // 3. Verify Reversal
      final allEntries = await journalService
          .watchEntriesByDateRange(userId, DateTime(2020), DateTime(3000))
          .first;

      // Should have 2 entries: 1 Bill (retained), 1 Reversal
      expect(allEntries.length, 2);

      final original = allEntries.firstWhere(
        (e) => e.classification == AccountingEntryClassification.bill,
      );
      final reversal = allEntries.firstWhere(
        (e) => e.classification != AccountingEntryClassification.bill,
      );

      expect(reversal.classification, AccountingEntryClassification.adjustment);
      expect(reversal.totalDebit, original.totalDebit);

      // Check narration for 'Reversal' keyword
      expect(
        allEntries.any((e) => (e.narration ?? '').contains('Revers')),
        true,
      );
    });
  });
}
