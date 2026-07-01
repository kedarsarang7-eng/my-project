import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:mockito/mockito.dart';
import 'package:drift/native.dart';
import 'package:dukanx/core/database/app_database.dart';

import 'package:dukanx/core/repository/products_repository.dart';
import 'package:dukanx/features/inventory/data/product_batch_repository.dart';
import 'package:dukanx/features/inventory/services/batch_allocation_service.dart';
import 'package:dukanx/features/inventory/services/pharmacy_migration_service.dart';

import 'package:dukanx/models/bill.dart';

import 'package:dukanx/core/error/error_handler.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late ProductBatchRepository batchRepo;
  late ProductsRepository productsRepo;

  late BatchAllocationService batchAllocationService;
  late PharmacyMigrationService migrationService;

  setUp(() {
    // 1. In-Memory Database
    db = AppDatabase.forTesting(NativeDatabase.memory());

    // 2. Real Repositories
    batchRepo = ProductBatchRepository(db);

    // Mock dependencies for ProductsRepository
    final mockSyncManager = MockSyncManager();

    productsRepo = ProductsRepository(
      database: db,
      syncManager: mockSyncManager,
      errorHandler: ErrorHandler.instance,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('E2E Pharmacy Flow: Purchase -> Migration -> FEFO Sale -> Stock Update', () async {
    const userId = 'user-e2e';

    // =================================================================
    // STEP 1: SETUP PRODUCT (Legacy Stock)
    // =================================================================
    final productId = const Uuid().v4();
    await db
        .into(db.products)
        .insert(
          ProductsCompanion(
            id: Value(productId),
            userId: Value(userId),
            name: Value('Dolo 650'),
            stockQuantity: Value(10), // Legacy stock
            sellingPrice: Value(100),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );

    // =================================================================
    // STEP 2: RUN MIGRATION
    // =================================================================
    // Need to instantiate MigrationService manually with real repos
    migrationService = PharmacyMigrationService(productsRepo, batchRepo);

    final migrationResult = await migrationService.migrateLegacyStock(userId);
    expect(migrationResult.success, true);
    expect(migrationResult.migratedCount, 1);

    // Verify Legacy Batch Created
    final batches = await batchRepo.getAllBatches(productId);
    expect(batches.length, 1);
    expect(batches.first.batchNumber, 'LEGACY_OPENING');
    expect(batches.first.expiryDate, isNull);
    expect(batches.first.stockQuantity, 10);

    // =================================================================
    // STEP 3: ADD NEW BATCH (Purchase)
    // =================================================================
    // Simulate a purchase adding a new batch with expiration
    final newBatchId = const Uuid().v4();
    await batchRepo.createBatch(
      ProductBatchesCompanion(
        id: Value(newBatchId),
        productId: Value(productId),
        userId: Value(userId),
        batchNumber: Value('BATCH-2026'),
        expiryDate: Value(
          DateTime.now().add(const Duration(days: 365)),
        ), // Future expiry
        stockQuantity: Value(20),
        openingQuantity: Value(20),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // =================================================================
    // STEP 4: FEFO ALLOCATION (Simulate Bill Creation)
    // =================================================================
    batchAllocationService = BatchAllocationService(
      productBatchRepository: batchRepo,
    );

    // Scenario: User buys 15 items.
    // Legacy (10, Null Expiry - Wait, FEFO logic puts NULL expiry last usually? Or first?)
    // Actually, NULL expiry usually means "Unknown", safest to sell first? or Last?
    // Let's check logic:
    // Sort: ExpiryDate ASC. Nulls usually come last in SQL unless specified.
    // Wait, Drift/SQLite default for NULLs in ORDER BY ASC is usually FIRST or LAST depending on DB.
    // Let's assume we want to sell Legacy (Old) stock first if we treat it as "Oldest".
    // BUT we don't know expiry.

    // Ref: ProductBatchRepository.getBatchesForFefo
    // ..orderBy([(t) => OrderingTerm(expression: t.expiryDate, mode: OrderingMode.asc)])

    // SQLite: NULLs are smallest (come first in ASC) or largest?
    // In SQLite, NULLs are considered smaller than any other value. So they come FIRST in ASC.
    // So 'LEGACY_OPENING' (Null Expiry) should be picked FIRST.

    final billItem = BillItem(
      productId: productId,
      productName: 'Dolo 650',
      qty: 15,
      price: 100,
    );

    final bill = Bill.empty().copyWith(
      businessType: 'pharmacy',
      items: [billItem],
    );

    final allocatedBill = await batchAllocationService.allocateBatches(bill);

    // EXPECTATION:
    // Item 1: 10 units from Legacy Batch (Null expiry)
    // Item 2: 5 units from New Batch (BATCH-2026)

    expect(
      allocatedBill.items.length,
      2,
      reason: 'Should split into Legacy + New',
    );

    final item1 = allocatedBill.items[0];
    expect(item1.batchNo, 'LEGACY_OPENING');
    expect(item1.qty, 10);

    final item2 = allocatedBill.items[1];
    expect(item2.batchNo, 'BATCH-2026');
    expect(item2.qty, 5);
  });
}

class MockSyncManager extends Mock implements SyncManager {}

class MockErrorHandler extends Mock implements ErrorHandler {}
