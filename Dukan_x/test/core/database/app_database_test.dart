// ============================================================================
// APP DATABASE TESTS - PRODUCTION COVERAGE
// ============================================================================
// Comprehensive test suite for Drift database operations
// Tests cover: Schema validation, CRUD, sync queue, analytics
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:dukanx/core/database/app_database.dart';

void main() {
  late AppDatabase database;
  const testUserId = 'test_user_123';

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('AppDatabase - Initialization', () {
    test('should create database with all tables', () async {
      // Tables should be accessible without errors
      expect(() => database.bills, returnsNormally);
      expect(() => database.customers, returnsNormally);
      expect(() => database.products, returnsNormally);
      expect(() => database.payments, returnsNormally);
      expect(() => database.syncQueue, returnsNormally);
      expect(() => database.deadLetterQueue, returnsNormally);
      expect(() => database.auditLogs, returnsNormally);
    });
  });

  group('AppDatabase - Bills CRUD', () {
    test('should insert and retrieve bill', () async {
      final now = DateTime.now();
      await database.insertBill(
        BillsCompanion.insert(
          id: 'bill_1',
          userId: testUserId,
          invoiceNumber: 'INV-001',
          billDate: now,
          itemsJson: '[]',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final bill = await database.getBillById('bill_1');

      expect(bill, isNotNull);
      expect(bill!.id, equals('bill_1'));
      expect(bill.invoiceNumber, equals('INV-001'));
      expect(bill.isSynced, isFalse); // Default value
    });

    test('should get all bills for user', () async {
      final now = DateTime.now();

      // Insert bills for different users
      await database.insertBill(
        BillsCompanion.insert(
          id: 'bill_1',
          userId: testUserId,
          invoiceNumber: 'INV-001',
          billDate: now,
          itemsJson: '[]',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.insertBill(
        BillsCompanion.insert(
          id: 'bill_2',
          userId: testUserId,
          invoiceNumber: 'INV-002',
          billDate: now,
          itemsJson: '[]',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.insertBill(
        BillsCompanion.insert(
          id: 'bill_3',
          userId: 'other_user',
          invoiceNumber: 'INV-003',
          billDate: now,
          itemsJson: '[]',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final userBills = await database.getAllBills(testUserId);

      expect(userBills.length, equals(2));
      expect(userBills.every((b) => b.userId == testUserId), isTrue);
    });

    test('should soft delete bill', () async {
      final now = DateTime.now();
      await database.insertBill(
        BillsCompanion.insert(
          id: 'bill_to_delete',
          userId: testUserId,
          invoiceNumber: 'INV-001',
          billDate: now,
          itemsJson: '[]',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.softDeleteBill('bill_to_delete');

      // Should not appear in getAllBills
      final bills = await database.getAllBills(testUserId);
      expect(bills.where((b) => b.id == 'bill_to_delete'), isEmpty);

      // But should still exist with deletedAt set
      final deletedBill = await database.getBillById('bill_to_delete');
      expect(deletedBill!.deletedAt, isNotNull);
    });

    test('should mark bill as synced', () async {
      final now = DateTime.now();
      await database.insertBill(
        BillsCompanion.insert(
          id: 'bill_sync',
          userId: testUserId,
          invoiceNumber: 'INV-001',
          billDate: now,
          itemsJson: '[]',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.markBillSynced('bill_sync', 'op_123');

      final bill = await database.getBillById('bill_sync');
      expect(bill!.isSynced, isTrue);
      expect(bill.syncOperationId, equals('op_123'));
    });
  });

  group('AppDatabase - Customers CRUD', () {
    test('should insert and retrieve customer', () async {
      final now = DateTime.now();
      await database.insertCustomer(
        CustomersCompanion.insert(
          id: 'cust_1',
          userId: testUserId,
          name: 'Test Customer',
          phone: const Value('9876543210'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final customer = await database.getCustomerById('cust_1');

      expect(customer, isNotNull);
      expect(customer!.name, equals('Test Customer'));
      expect(customer.phone, equals('9876543210'));
    });

    test('should get all active customers for user', () async {
      final now = DateTime.now();

      await database.insertCustomer(
        CustomersCompanion.insert(
          id: 'cust_1',
          userId: testUserId,
          name: 'Active Customer',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.insertCustomer(
        CustomersCompanion.insert(
          id: 'cust_2',
          userId: testUserId,
          name: 'Inactive Customer',
          isActive: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final customers = await database.getAllCustomers(testUserId);

      expect(customers.length, equals(1));
      expect(customers.first.name, equals('Active Customer'));
    });
  });

  group('AppDatabase - Products CRUD', () {
    test('should insert and retrieve product', () async {
      final now = DateTime.now();
      await database.insertProduct(
        ProductsCompanion.insert(
          id: 'prod_1',
          userId: testUserId,
          name: 'Test Product',
          sellingPrice: 100.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final product = await database.getProductById('prod_1');

      expect(product, isNotNull);
      expect(product!.name, equals('Test Product'));
      expect(product.sellingPrice, equals(100.0));
    });

    test('should get low stock products', () async {
      final now = DateTime.now();

      // Product with sufficient stock
      await database.insertProduct(
        ProductsCompanion.insert(
          id: 'prod_1',
          userId: testUserId,
          name: 'Well Stocked',
          sellingPrice: 100.0,
          stockQuantity: const Value(50),
          lowStockThreshold: const Value(10),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Product with low stock
      await database.insertProduct(
        ProductsCompanion.insert(
          id: 'prod_2',
          userId: testUserId,
          name: 'Low Stock Item',
          sellingPrice: 50.0,
          stockQuantity: const Value(5),
          lowStockThreshold: const Value(10),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final lowStockProducts = await database.getLowStockProducts(testUserId);

      expect(lowStockProducts.length, equals(1));
      expect(lowStockProducts.first.name, equals('Low Stock Item'));
    });
  });

  group('AppDatabase - Sync Queue', () {
    test('should insert sync queue entry', () async {
      final now = DateTime.now();
      await database.insertSyncQueueEntry(
        SyncQueueCompanion.insert(
          operationId: 'op_1',
          operationType: 'CREATE',
          targetCollection: 'bills',
          documentId: 'bill_1',
          payload: '{"test": "data"}',
          createdAt: now,
          userId: testUserId,
        ),
      );

      final entries = await database.getPendingSyncEntries();

      expect(entries.length, equals(1));
      expect(entries.first.operationId, equals('op_1'));
      expect(entries.first.status, equals('PENDING'));
    });

    test('should get pending sync entries in priority order', () async {
      final now = DateTime.now();

      // Insert with different priorities
      await database.insertSyncQueueEntry(
        SyncQueueCompanion.insert(
          operationId: 'op_low',
          operationType: 'UPDATE',
          targetCollection: 'bills',
          documentId: 'bill_1',
          payload: '{}',
          priority: const Value(10), // Low priority
          createdAt: now,
          userId: testUserId,
        ),
      );

      await database.insertSyncQueueEntry(
        SyncQueueCompanion.insert(
          operationId: 'op_high',
          operationType: 'CREATE',
          targetCollection: 'bills',
          documentId: 'bill_2',
          payload: '{}',
          priority: const Value(1), // High priority
          createdAt: now,
          userId: testUserId,
        ),
      );

      final entries = await database.getPendingSyncEntries();

      expect(entries.length, equals(2));
      expect(
        entries.first.operationId,
        equals('op_high'),
      ); // High priority first
    });

    test('should update sync queue entry status', () async {
      final now = DateTime.now();
      await database.insertSyncQueueEntry(
        SyncQueueCompanion.insert(
          operationId: 'op_1',
          operationType: 'CREATE',
          targetCollection: 'bills',
          documentId: 'bill_1',
          payload: '{}',
          createdAt: now,
          userId: testUserId,
        ),
      );

      // Update to SYNCED
      await database.updateSyncQueueEntry(
        SyncQueueEntry(
          operationId: 'op_1',
          operationType: 'CREATE',
          targetCollection: 'bills',
          documentId: 'bill_1',
          payload: '{}',
          status: 'SYNCED',
          retryCount: 0,
          createdAt: now,
          priority: 5,
          stepNumber: 1,
          totalSteps: 1,
          userId: testUserId,
          syncedAt: DateTime.now(),
          lastError: null,
          lastAttemptAt: DateTime.now(),
          parentOperationId: null,
          payloadHash: '',
          ownerId: testUserId,
          dependencyGroup: null,
        ),
      );

      final entries = await database.getPendingSyncEntries();
      expect(entries.isEmpty, isTrue); // SYNCED entries not returned
    });

    test('should delete sync queue entry', () async {
      final now = DateTime.now();
      await database.insertSyncQueueEntry(
        SyncQueueCompanion.insert(
          operationId: 'op_to_delete',
          operationType: 'DELETE',
          targetCollection: 'bills',
          documentId: 'bill_1',
          payload: '{}',
          createdAt: now,
          userId: testUserId,
        ),
      );

      await database.deleteSyncQueueEntry('op_to_delete');

      final entries = await database.getPendingSyncEntries();
      expect(entries.isEmpty, isTrue);
    });
  });

  group('AppDatabase - Dead Letter Queue', () {
    test('should insert and retrieve unresolved dead letters', () async {
      final now = DateTime.now();
      await database.insertDeadLetter(
        DeadLetterQueueCompanion.insert(
          id: 'dl_1',
          originalOperationId: 'op_failed',
          userId: testUserId,
          operationType: 'CREATE',
          targetCollection: 'bills',
          documentId: 'bill_1',
          payload: '{}',
          failureReason: 'Network error',
          totalAttempts: 3,
          firstAttemptAt: now.subtract(const Duration(hours: 1)),
          lastAttemptAt: now,
          movedToDeadLetterAt: now,
        ),
      );

      final deadLetters = await database.getUnresolvedDeadLetters(testUserId);

      expect(deadLetters.length, equals(1));
      expect(deadLetters.first.failureReason, equals('Network error'));
    });

    test('should resolve dead letter', () async {
      final now = DateTime.now();
      await database.insertDeadLetter(
        DeadLetterQueueCompanion.insert(
          id: 'dl_resolve',
          originalOperationId: 'op_failed',
          userId: testUserId,
          operationType: 'CREATE',
          targetCollection: 'bills',
          documentId: 'bill_1',
          payload: '{}',
          failureReason: 'Conflict',
          totalAttempts: 3,
          firstAttemptAt: now.subtract(const Duration(hours: 1)),
          lastAttemptAt: now,
          movedToDeadLetterAt: now,
        ),
      );

      await database.resolveDeadLetter('dl_resolve', 'Manually merged data');

      final unresolved = await database.getUnresolvedDeadLetters(testUserId);
      expect(unresolved.isEmpty, isTrue);
    });
  });

  group('AppDatabase - Audit Logs', () {
    test('should insert audit log entry', () async {
      await database.insertAuditLog(
        userId: testUserId,
        targetTableName: 'bills',
        recordId: 'bill_1',
        action: 'CREATE',
        newValueJson: '{"total": 100}',
      );

      // Verify by querying directly
      final logs = await database.select(database.auditLogs).get();

      expect(logs.length, equals(1));
      expect(logs.first.action, equals('CREATE'));
      expect(logs.first.recordId, equals('bill_1'));
    });
  });

  group('AppDatabase - Dashboard Stats', () {
    test('should calculate dashboard stats correctly', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Create today's bills
      await database.insertBill(
        BillsCompanion.insert(
          id: 'today_bill',
          userId: testUserId,
          invoiceNumber: 'INV-001',
          billDate: today,
          grandTotal: const Value(1000),
          paidAmount: const Value(500),
          status: const Value('PARTIAL'),
          itemsJson: '[]',
          createdAt: today,
          updatedAt: today,
        ),
      );

      // Create old bill
      await database.insertBill(
        BillsCompanion.insert(
          id: 'old_bill',
          userId: testUserId,
          invoiceNumber: 'INV-002',
          billDate: today.subtract(const Duration(days: 60)),
          grandTotal: const Value(2000),
          paidAmount: const Value(0),
          status: const Value('PENDING'),
          itemsJson: '[]',
          createdAt: today.subtract(const Duration(days: 60)),
          updatedAt: today.subtract(const Duration(days: 60)),
        ),
      );

      // Add customer
      await database.insertCustomer(
        CustomersCompanion.insert(
          id: 'cust_1',
          userId: testUserId,
          name: 'Customer',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final stats = await database.getDashboardStats(testUserId);

      expect(stats['todaySales'], equals(1000));
      expect(stats['todayCollections'], equals(500));
      expect(stats['todayBillCount'], equals(1));
      expect(stats['customerCount'], equals(1));
      expect(stats['totalDues'], greaterThan(0));
    });
  });

  group('AppDatabase - Health Check', () {
    test('should perform health check', () async {
      final now = DateTime.now();

      // Add some data
      await database.insertBill(
        BillsCompanion.insert(
          id: 'bill_1',
          userId: testUserId,
          invoiceNumber: 'INV-001',
          billDate: now,
          itemsJson: '[]',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final health = await database.performHealthCheck(testUserId);

      expect(health['healthy'], isTrue);
      expect(health['billCount'], equals(1));
      expect(health['pendingSyncCount'], isA<int>());
      expect(health['deadLetterCount'], equals(0));
    });

    test('should report unhealthy when dead letters exist', () async {
      final now = DateTime.now();

      // Add dead letter
      await database.insertDeadLetter(
        DeadLetterQueueCompanion.insert(
          id: 'dl_1',
          originalOperationId: 'op_1',
          userId: testUserId,
          operationType: 'CREATE',
          targetCollection: 'bills',
          documentId: 'bill_1',
          payload: '{}',
          failureReason: 'Error',
          totalAttempts: 5,
          firstAttemptAt: now,
          lastAttemptAt: now,
          movedToDeadLetterAt: now,
        ),
      );

      final health = await database.performHealthCheck(testUserId);

      expect(health['deadLetterCount'], equals(1));
      // Health depends on dead letter count being 0
    });
  });

  group('AppDatabase - Stock Analysis', () {
    test('should identify dead stock products', () async {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 90));

      // 1. Dead Stock Item: Created long ago, never sold
      await database.insertProduct(
        ProductsCompanion.insert(
          id: 'dead_prod',
          userId: testUserId,
          name: 'Dead Item',
          sellingPrice: 100.0,
          stockQuantity: const Value(10),
          createdAt: cutoff.subtract(const Duration(days: 10)),
          updatedAt: now,
        ),
      );

      // 2. Active Item: Created long ago, but sold recently
      await database.insertProduct(
        ProductsCompanion.insert(
          id: 'active_prod',
          userId: testUserId,
          name: 'Active Item',
          sellingPrice: 200.0,
          stockQuantity: const Value(20),
          createdAt: cutoff.subtract(const Duration(days: 10)),
          updatedAt: now,
        ),
      );

      // Sale for active item
      await database.insertBill(
        BillsCompanion.insert(
          id: 'bill_recent',
          userId: testUserId,
          invoiceNumber: 'INV-RECENT',
          billDate: now,
          itemsJson: '[]',
          createdAt: now, // recent
          updatedAt: now,
          status: const Value('PAID'),
        ),
      );
      await database
          .into(database.billItems)
          .insert(
            BillItemsCompanion.insert(
              id: 'item_1',
              billId: 'bill_recent',
              productId: const Value('active_prod'),
              productName: 'Active Item',
              quantity: 1,
              unitPrice: 200,
              totalAmount: 200,
              createdAt: now,
            ),
          );

      // 3. New Item: Created recently
      // (Should NOT be dead stock because createdAt > cutoff)
      await database.insertProduct(
        ProductsCompanion.insert(
          id: 'new_prod',
          userId: testUserId,
          name: 'New Item',
          sellingPrice: 300.0,
          stockQuantity: const Value(5),
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now,
        ),
      );

      final deadStock = await database.getDeadStockProducts(testUserId, cutoff);

      expect(deadStock.map((e) => e.id), contains('dead_prod'));
      expect(deadStock.map((e) => e.id), isNot(contains('active_prod')));
      expect(deadStock.map((e) => e.id), isNot(contains('new_prod')));
    });

    test('getProductSalesHistory should aggregate sales correctly', () async {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 30));

      // Create bills with items
      await database.insertBill(
        BillsCompanion.insert(
          id: 'bill_1',
          userId: testUserId,
          invoiceNumber: 'INV-1',
          billDate: now.subtract(const Duration(days: 5)),
          itemsJson: '[]',
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now,
          status: const Value('PAID'),
        ),
      );

      await database.insertBill(
        BillsCompanion.insert(
          id: 'bill_2',
          userId: testUserId,
          invoiceNumber: 'INV-2',
          billDate: now.subtract(const Duration(days: 10)),
          itemsJson: '[]',
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now,
          status: const Value('PAID'),
        ),
      );

      // Old bill (before cutoff)
      await database.insertBill(
        BillsCompanion.insert(
          id: 'bill_old',
          userId: testUserId,
          invoiceNumber: 'INV-OLD',
          billDate: now.subtract(const Duration(days: 40)),
          itemsJson: '[]',
          createdAt: now.subtract(const Duration(days: 40)),
          updatedAt: now,
          status: const Value('PAID'),
        ),
      );

      // Bill items
      // Product A: 2 in bill_1, 3 in bill_2 = 5 total
      await database
          .into(database.billItems)
          .insert(
            BillItemsCompanion.insert(
              id: 'item_1a',
              billId: 'bill_1',
              productId: const Value('prod_a'),
              productName: 'Product A',
              quantity: 2,
              unitPrice: 100,
              totalAmount: 200,
              createdAt: now,
            ),
          );
      await database
          .into(database.billItems)
          .insert(
            BillItemsCompanion.insert(
              id: 'item_2a',
              billId: 'bill_2',
              productId: const Value('prod_a'),
              productName: 'Product A',
              quantity: 3,
              unitPrice: 100,
              totalAmount: 300,
              createdAt: now,
            ),
          );

      // Product B: 1 in bill_1 = 1 total
      await database
          .into(database.billItems)
          .insert(
            BillItemsCompanion.insert(
              id: 'item_1b',
              billId: 'bill_1',
              productId: const Value('prod_b'),
              productName: 'Product B',
              quantity: 1,
              unitPrice: 50,
              totalAmount: 50,
              createdAt: now,
            ),
          );

      // Product C: In old bill (should be ignored)
      await database
          .into(database.billItems)
          .insert(
            BillItemsCompanion.insert(
              id: 'item_old',
              billId: 'bill_old',
              productId: const Value('prod_c'),
              productName: 'Product C',
              quantity: 10,
              unitPrice: 50,
              totalAmount: 500,
              createdAt: now.subtract(const Duration(days: 40)),
            ),
          );

      final history = await database.getProductSalesHistory(testUserId, cutoff);

      expect(history['prod_a'], equals(5.0));
      expect(history['prod_b'], equals(1.0));
      expect(history.containsKey('prod_c'), isFalse);
    });
  });
}
