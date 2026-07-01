import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/repository/audit_repository.dart';
import 'package:dukanx/core/repository/bills_repository.dart'; // Also exports Bill
import 'package:dukanx/core/error/error_handler.dart';
import 'package:dukanx/services/audit_service.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:mockito/mockito.dart';

// Mocks
class MockSyncManager extends Mock implements SyncManager {}

class MockAuditService extends Mock implements AuditService {}

void main() {
  late AppDatabase database;
  late AuditRepository auditRepo;
  late BillsRepository billsRepo;
  late MockSyncManager mockSyncManager;
  late MockAuditService mockAuditService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    // Use singleton instance instead of unnamed constructor
    final errorHandler = ErrorHandler.instance;
    auditRepo = AuditRepository(database: database, errorHandler: errorHandler);
    mockSyncManager = MockSyncManager();
    mockAuditService = MockAuditService();

    billsRepo = BillsRepository(
      database: database,
      syncManager: mockSyncManager as SyncManager,
      errorHandler: errorHandler,
      auditService: mockAuditService as AuditService,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Fraud Prevention - Audit Log Hash Chaining', () {
    test('Should create hash chain for consecutive logs', () async {
      final userId = 'user_123';

      // 1. Log Action A
      await auditRepo.logAction(
        userId: userId,
        targetTableName: 'test',
        recordId: '1',
        action: 'CREATE',
        newValueJson: '{"data": "A"}',
      );

      // 2. Log Action B
      await auditRepo.logAction(
        userId: userId,
        targetTableName: 'test',
        recordId: '1',
        action: 'UPDATE',
        newValueJson: '{"data": "B"}',
      );

      // 3. Verify Chain
      final result = await auditRepo.verifyChain(userId);
      expect(result.data, isTrue);

      // 4. Manually check hashes
      final logs = await auditRepo.getLogsForUser(userId: userId);
      expect(logs.data!.length, 2);

      final logB = logs.data![0]; // Descending order, so B is first
      final logA = logs.data![1];

      expect(logB.previousHash, equals(logA.currentHash));
    });

    test('Should detect tampering in the middle of the chain', () async {
      final userId = 'tamper_user';

      // 1. Create Chain A -> B -> C
      await auditRepo.logAction(
        userId: userId,
        targetTableName: 't',
        recordId: '1',
        action: 'A',
      );
      await auditRepo.logAction(
        userId: userId,
        targetTableName: 't',
        recordId: '1',
        action: 'B',
      );
      await auditRepo.logAction(
        userId: userId,
        targetTableName: 't',
        recordId: '1',
        action: 'C',
      );

      // 2. Initial verify
      expect((await auditRepo.verifyChain(userId)).data, isTrue);

      // 3. TAMPER with Log B (Update SQL directly)
      // We need to find ID of B.
      final logs = await auditRepo.getLogsForUser(userId: userId);
      final logB = logs.data![1]; // C, B, A

      await (database.update(database.auditLogs)
            ..where((t) => t.id.equals(logB.id)))
          .write(AuditLogsCompanion(action: Value('TAMPERED')));

      // 4. Verify Chain (Should Fail)
      final result = await auditRepo.verifyChain(userId);
      expect(result.data, isFalse);
    });
  });

  group('Fraud Prevention - Bill Locking', () {
    test('Should block editing of PAID bill without auth', () async {
      final userId = 'owner_1';
      final billId = 'bill_1';

      // 1. Create PAID Bill information
      final bill = Bill(
        id: billId,
        ownerId: userId,
        customerId: 'cust_1',
        date: DateTime.now(),
        items: [],
        grandTotal: 100,
        paidAmount: 100, // Fully Paid
        status: 'Paid',
      );

      // Manual DB Insert
      await database
          .into(database.bills)
          .insert(
            BillsCompanion.insert(
              id: billId,
              userId: userId,
              invoiceNumber: 'INV-1',
              billDate: DateTime.now(),
              grandTotal: const Value(100),
              paidAmount: const Value(100),
              status: const Value('Paid'),
              itemsJson: '[]',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              printCount: const Value(0),
            ),
          );

      // 2. Try to Update
      // We need to pass a Bill object.
      final newBill = bill.copyWith(grandTotal: 50); // Reduction attempt!

      final result = await billsRepo.updateBill(newBill);
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Bill is LOCKED'));
    });

    test('Should ALLOW editing of PAID bill WITH auth', () async {
      final userId = 'owner_2';
      final billId = 'bill_2';

      // 1. Create PAID Bill
      await database
          .into(database.bills)
          .insert(
            BillsCompanion.insert(
              id: billId,
              userId: userId,
              invoiceNumber: 'INV-2',
              billDate: DateTime.now(),
              grandTotal: const Value(100),
              paidAmount: const Value(100),
              status: const Value('Paid'),
              itemsJson: '[]',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final bill = Bill(
        id: billId,
        ownerId: userId,
        customerId: 'cust_1',
        date: DateTime.now(),
        items: [
          BillItem(
            productId: 'p1',
            productName: 'Item',
            qty: 1,
            price: 100,
            cgst: 0,
            sgst: 0,
            igst: 0,
          ),
        ],
        grandTotal: 100,
        subtotal: 100,
        paidAmount: 100,
        status: 'Paid',
      );

      // Update with an item that costs 50
      final newBill = bill.copyWith(
        grandTotal: 50,
        subtotal: 50,
        paidAmount: 50,
        items: [
          BillItem(
            productId: 'p1',
            productName: 'Item',
            qty: 1,
            price: 50,
            cgst: 0,
            sgst: 0,
            igst: 0,
          ),
        ],
      );

      // 2. Update WITH Auth
      await billsRepo.updateBill(
        newBill,
        approverId: 'manager_1',
        editReason: 'Customer refund',
      );

      // 3. Verify Update Happened
      final storedBill = await billsRepo.getById(billId);
      expect(storedBill.data!.grandTotal, 50.0);
    });
  });
}
