import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/features/party_ledger/services/party_ledger_service.dart';
import 'package:dukanx/features/accounting/accounting.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Integration tests for Party Ledger Service
///
/// Tests end-to-end workflows with real database connections
import 'package:mockito/mockito.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
// Note: SyncQueueItem is likely exported by sync_manager or we need explicit import if not
// Checking mocks usually requires exact matching

class MockSyncManager extends Mock implements SyncManager {
  @override
  Future<String> enqueue(SyncQueueItem? item) async {
    return item?.operationId ?? 'mock-id';
  }
}

void main() {
  late AppDatabase db;
  late AccountingRepository accountingRepo;
  late FinancialReportsService reportsService;
  late PartyLedgerService ledgerService;
  late MockSyncManager mockSyncManager;

  setUp(() async {
    // Create in-memory database for testing
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accountingRepo = AccountingRepository(db: db);
    reportsService = FinancialReportsService(repo: accountingRepo);
    mockSyncManager = MockSyncManager();

    ledgerService = PartyLedgerService(
      accountingRepo: accountingRepo,
      reportsService: reportsService,
      db: db,
      syncManager: mockSyncManager,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Party Ledger Integration Tests', () {
    const userId = 'testuser123';
    const customerId = 'customer456';

    test(
      'End-to-end: Create customer → Create bills → Calculate aging',
      () async {
        // 1. Create customer
        await db
            .into(db.customers)
            .insert(
              CustomersCompanion.insert(
                id: customerId,
                userId: userId,
                name: 'Test Customer',
                phone: const Value('1234567890'),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

        // 2. Create ledger account for customer
        await accountingRepo.createLedgerAccount(
          userId: userId,
          accountName: 'Customer - Test Customer',
          accountType: 'RECEIVABLE',
          linkedEntityType: 'CUSTOMER',
          linkedEntityId: customerId,
        );

        // 3. Create bills of different ages
        final now = DateTime.now();
        final bills = [
          _createBillCompanion(
            'bill1',
            userId,
            customerId,
            now.subtract(const Duration(days: 15)),
            1000.0,
          ),
          _createBillCompanion(
            'bill2',
            userId,
            customerId,
            now.subtract(const Duration(days: 45)),
            1500.0,
          ),
          _createBillCompanion(
            'bill3',
            userId,
            customerId,
            now.subtract(const Duration(days: 75)),
            2000.0,
          ),
          _createBillCompanion(
            'bill4',
            userId,
            customerId,
            now.subtract(const Duration(days: 120)),
            2500.0,
          ),
        ];

        for (final bill in bills) {
          await db.into(db.bills).insert(bill);

          // Create journal entry for each bill (debit receivable, credit sales)
          await accountingRepo.recordSalesInvoice(
            userId: userId,
            customerId: customerId,
            billId: bill.id.value,
            amount: bill.grandTotal.value,
            date: bill.billDate.value,
          );
        }

        // 4. Get aging analysis
        final agingReport = await ledgerService.getAgingAnalysis(
          userId: userId,
          partyId: customerId,
          partyType: 'CUSTOMER',
        );

        // 5. Verify results
        expect(agingReport.partyId, customerId);
        expect(agingReport.totalDue, 7000.0); // Sum of all bills
        expect(agingReport.buckets.length, 4);

        // Verify buckets have correct amounts (FIFO allocation)
        expect(agingReport.zeroToThirty, greaterThan(0));
        expect(agingReport.ninetyPlus, greaterThan(0));

        // Total across buckets should match total due
        final totalInBuckets =
            agingReport.zeroToThirty +
            agingReport.thirtyToSixty +
            agingReport.sixtyToNinety +
            agingReport.ninetyPlus;
        expect(totalInBuckets, closeTo(agingReport.totalDue, 0.01));
      },
    );

    test(
      'End-to-end: Record payment → Verify balance update → Verify aging recalculation',
      () async {
        // 1. Setup customer and bills (similar to previous test)
        await db
            .into(db.customers)
            .insert(
              CustomersCompanion.insert(
                id: customerId,
                userId: userId,
                name: 'Test Customer',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

        await accountingRepo.createLedgerAccount(
          userId: userId,
          accountName: 'Customer - Test Customer',
          accountType: 'RECEIVABLE',
          linkedEntityType: 'CUSTOMER',
          linkedEntityId: customerId,
        );

        final billDate = DateTime.now().subtract(const Duration(days: 30));
        await db
            .into(db.bills)
            .insert(
              _createBillCompanion(
                'bill1',
                userId,
                customerId,
                billDate,
                5000.0,
              ),
            );

        await accountingRepo.recordSalesInvoice(
          userId: userId,
          customerId: customerId,
          billId: 'bill1',
          amount: 5000.0,
          date: billDate,
        );

        // 2. Get initial aging
        final initialAging = await ledgerService.getAgingAnalysis(
          userId: userId,
          partyId: customerId,
          partyType: 'CUSTOMER',
        );

        expect(initialAging.totalDue, 5000.0);

        // 3. Record payment of 2000
        await accountingRepo.recordPayment(
          userId: userId,
          customerId: customerId,
          billId: 'bill1',
          amount: 2000.0,
          date: DateTime.now(),
        );

        // 4. Update bill paid amount
        await (db.update(db.bills)..where((t) => t.id.equals('bill1'))).write(
          const BillsCompanion(paidAmount: Value(2000.0)),
        );

        // 5. Get updated aging
        final updatedAging = await ledgerService.getAgingAnalysis(
          userId: userId,
          partyId: customerId,
          partyType: 'CUSTOMER',
        );

        // 6. Verify balance reduced
        expect(updatedAging.totalDue, 3000.0); // 5000 - 2000

        // 7. Sync customer balance
        await ledgerService.syncCustomerBalance(userId, customerId);

        // 8. Verify customer table updated
        final customer = await (db.select(
          db.customers,
        )..where((t) => t.id.equals(customerId))).getSingle();

        expect(customer.totalDues, closeTo(3000.0, 0.01));
      },
    );

    test('Data isolation: Multiple parties do not interfere', () async {
      // 1. Create two customers
      const customer1 = 'cust1';
      const customer2 = 'cust2';

      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: customer1,
              userId: userId,
              name: 'Customer 1',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: customer2,
              userId: userId,
              name: 'Customer 2',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // 2. Create ledgers
      await accountingRepo.createLedgerAccount(
        userId: userId,
        accountName: 'Customer 1',
        accountType: 'RECEIVABLE',
        linkedEntityType: 'CUSTOMER',
        linkedEntityId: customer1,
      );

      await accountingRepo.createLedgerAccount(
        userId: userId,
        accountName: 'Customer 2',
        accountType: 'RECEIVABLE',
        linkedEntityType: 'CUSTOMER',
        linkedEntityId: customer2,
      );

      // 3. Create bills for each
      await db
          .into(db.bills)
          .insert(
            _createBillCompanion(
              'bill_c1',
              userId,
              customer1,
              DateTime.now(),
              1000.0,
            ),
          );

      await db
          .into(db.bills)
          .insert(
            _createBillCompanion(
              'bill_c2',
              userId,
              customer2,
              DateTime.now(),
              2000.0,
            ),
          );

      await accountingRepo.recordSalesInvoice(
        userId: userId,
        customerId: customer1,
        billId: 'bill_c1',
        amount: 1000.0,
        date: DateTime.now(),
      );

      await accountingRepo.recordSalesInvoice(
        userId: userId,
        customerId: customer2,
        billId: 'bill_c2',
        amount: 2000.0,
        date: DateTime.now(),
      );

      // 4. Get balances separately
      final balance1 = await ledgerService.getPartyBalance(
        userId: userId,
        partyId: customer1,
        partyType: 'CUSTOMER',
      );

      final balance2 = await ledgerService.getPartyBalance(
        userId: userId,
        partyId: customer2,
        partyType: 'CUSTOMER',
      );

      // 5. Verify isolation
      expect(balance1.currentBalance, 1000.0);
      expect(balance2.currentBalance, 2000.0);
    });

    test('syncCustomerBalance updates Customers table correctly', () async {
      // 1. Create customer
      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: customerId,
              userId: userId,
              name: 'Sync Test Customer',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // 2. Create ledger with initial balance
      await accountingRepo.createLedgerAccount(
        userId: userId,
        accountName: 'Sync Test Customer',
        accountType: 'RECEIVABLE',
        linkedEntityType: 'CUSTOMER',
        linkedEntityId: customerId,
      );

      // 3. Record a bill
      await db
          .into(db.bills)
          .insert(
            _createBillCompanion(
              'bill_sync',
              userId,
              customerId,
              DateTime.now(),
              3500.0,
            ),
          );

      await accountingRepo.recordSalesInvoice(
        userId: userId,
        customerId: customerId,
        billId: 'bill_sync',
        amount: 3500.0,
        date: DateTime.now(),
      );

      // 4. Sync customer balance
      await ledgerService.syncCustomerBalance(userId, customerId);

      // 5. Verify customer table updated
      final customer = await (db.select(
        db.customers,
      )..where((t) => t.id.equals(customerId))).getSingle();

      expect(customer.totalDues, closeTo(3500.0, 0.01));
    });
  });

  group('Error Handling Integration Tests', () {
    test('handles missing ledger gracefully', () async {
      final balance = await ledgerService.getPartyBalance(
        userId: 'nonexistent',
        partyId: 'nonexistent',
        partyType: 'CUSTOMER',
      );

      expect(balance.currentBalance, 0.0);
      expect(balance.balanceType, 'Dr');
    });

    test('statement generation throws error for missing party', () async {
      expect(
        () => ledgerService.getPartyStatement(
          userId: 'nonexistent',
          partyId: 'nonexistent',
          partyType: 'CUSTOMER',
          startDate: DateTime.now().subtract(const Duration(days: 30)),
          endDate: DateTime.now(),
        ),
        throwsException,
      );
    });
  });
}

// Helper function to create bill companion
BillsCompanion _createBillCompanion(
  String id,
  String userId,
  String customerId,
  DateTime billDate,
  double amount,
) {
  return BillsCompanion.insert(
    id: id,
    userId: userId,
    invoiceNumber: 'INV-$id',
    customerId: Value(customerId),
    customerName: const Value('Test Customer'),
    billDate: billDate,
    subtotal: Value(amount),
    grandTotal: Value(amount),
    itemsJson: '[]',
    createdAt: billDate,
    updatedAt: billDate,
  );
}
