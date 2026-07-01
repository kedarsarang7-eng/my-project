// ============================================================================
// INTEGRATION TEST: FULL BILLING FLOW
// ============================================================================
// Verifies the core loop: Bill Creation -> Stock Deduction -> DB Persistence
// Uses in-memory database and fake services.
// ============================================================================

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/features/billing/services/billing_service.dart';
import 'package:dukanx/features/inventory/services/inventory_service.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/features/accounting/services/accounting_service.dart';
import 'package:dukanx/features/accounting/services/locking_service.dart';
import 'package:dukanx/features/inventory/data/product_batch_repository.dart';
import 'package:dukanx/features/accounting/models/journal_entry_model.dart';

// --- FAKES ---

class FakeSyncManager extends Fake implements SyncManager {
  @override
  Future<String> enqueue(SyncQueueItem item) async {
    return 'fake-op-id';
  }
}

class FakeAccountingService extends Fake implements AccountingService {
  @override
  Future<JournalEntryModel> createStockEntry({
    required String userId,
    required String referenceId,
    required String type,
    required String reason,
    required double amount,
    required DateTime date,
    String? description,
  }) async {
    return JournalEntryModel(
      id: 'dummy-entry',
      userId: userId,
      voucherNumber: 'JV-001',
      voucherType: VoucherType.journal,
      entryDate: date,
      entries: [],
      totalDebit: amount,
      totalCredit: amount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class FakeLockingService extends Fake implements LockingService {
  @override
  Future<void> validateAction(
    String userId,
    DateTime date, {
    LockOverrideContext? overrideContext,
  }) async {
    // Always valid
  }
}

class FakeProductBatchRepository extends Fake
    implements ProductBatchRepository {
  @override
  Future<double> updateBatchStock(String batchId, double delta) async {
    return 0.0;
  }
}

void main() {
  late AppDatabase db;
  late InventoryService inventoryService;
  late BillingService billingService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());

    inventoryService = InventoryService(
      db,
      FakeLockingService(),
      FakeAccountingService(),
      FakeSyncManager(),
      FakeProductBatchRepository(),
    );

    billingService = BillingService(db, inventoryService);
  });

  tearDown(() async {
    await db.close();
  });

  BillEntity createDummyBill({
    required String id,
    required String userId,
    required String invoiceNumber,
    required double total,
  }) {
    return BillEntity(
      id: id,
      userId: userId,
      invoiceNumber: invoiceNumber,
      billDate: DateTime.now(),
      grandTotal: total,
      itemsJson: '[]',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: 'Paid',

      // Required Defaults
      customerId: null,
      customerName: 'Guest',
      subtotal: total,
      taxAmount: 0.0,
      discountAmount: 0.0,
      paidAmount: total,
      source: 'MANUAL',
      paymentMode: 'CASH',
      businessType: 'grocery',
      serviceCharge: 0.0,
      costOfGoodsSold: 0.0,
      grossProfit: 0.0,
      printCount: 0,
      isSynced: false,
      marketCess: 0.0,
      commissionAmount: 0.0,
      version: 1,
      cashPaid: 0.0,
      onlinePaid: 0.0,
    );
  }

  BillItemEntity createDummyItem({
    required String id,
    required String billId,
    required String productId,
    required double qty,
    required double price,
  }) {
    return BillItemEntity(
      id: id,
      billId: billId,
      productId: productId,
      productName: 'Test Item',
      quantity: qty,
      unitPrice: price,
      totalAmount: qty * price,
      createdAt: DateTime.now(),

      // Required Defaults
      unit: 'pcs',
      taxRate: 0.0,
      taxAmount: 0.0,
      discountAmount: 0.0,
      sortOrder: 0,
      cgstRate: 0.0,
      cgstAmount: 0.0,
      sgstRate: 0.0,
      sgstAmount: 0.0,
      igstRate: 0.0,
      igstAmount: 0.0,
    );
  }

  test('Full Flow: Create Bill -> Deduct Stock -> Persist', () async {
    const userId = 'user-1';
    const productId = 'prod-1';

    // 1. SEED
    await db
        .into(db.shops)
        .insert(
          ShopsCompanion(
            id: Value('shop-1'),
            ownerId: Value(userId),
            businessType: Value('grocery'),
            name: Value('Test Shop'),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
            allowNegativeStock: Value(false),
          ),
        );

    await db
        .into(db.products)
        .insert(
          ProductsCompanion(
            id: Value(productId),
            userId: Value(userId),
            name: Value('Test Item'),
            sellingPrice: Value(100.0),
            costPrice: Value(80.0),
            stockQuantity: Value(10.0),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );

    // 2. PREPARE
    final billEntity = createDummyBill(
      id: 'bill-1',
      userId: userId,
      invoiceNumber: 'INV-001',
      total: 200.0,
    );

    final itemEntity = createDummyItem(
      id: 'item-1',
      billId: 'bill-1',
      productId: productId,
      qty: 2.0,
      price: 100.0,
    );

    // 3. EXECUTE
    final result = await billingService.createBill(
      bill: billEntity,
      items: [itemEntity],
    );

    // 4. VERIFY
    expect(
      result.isSuccess,
      true,
      reason: 'Bill creation failed: ${result.error?.message}',
    );

    final savedBill = await (db.select(
      db.bills,
    )..where((t) => t.id.equals('bill-1'))).getSingle();
    expect(savedBill.grandTotal, 200.0);

    final savedProduct = await (db.select(
      db.products,
    )..where((t) => t.id.equals(productId))).getSingle();
    expect(savedProduct.stockQuantity, 8.0);
  });

  test('Full Flow: Insufficient Stock check', () async {
    const userId = 'user-2';
    const productId = 'prod-2';

    await db
        .into(db.shops)
        .insert(
          ShopsCompanion(
            id: Value('shop-2'),
            ownerId: Value(userId),
            businessType: Value('grocery'),
            name: Value('Strict Shop'),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
            allowNegativeStock: Value(false),
          ),
        );

    await db
        .into(db.products)
        .insert(
          ProductsCompanion(
            id: Value(productId),
            userId: Value(userId),
            name: Value('Low Stock Item'),
            sellingPrice: Value(100.0),
            stockQuantity: Value(1.0),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );

    final billEntity = createDummyBill(
      id: 'bill-2',
      userId: userId,
      invoiceNumber: 'INV-002',
      total: 500.0,
    );

    final itemEntity = createDummyItem(
      id: 'item-2',
      billId: 'bill-2',
      productId: productId,
      qty: 5.0,
      price: 100.0,
    );

    final result = await billingService.createBill(
      bill: billEntity,
      items: [itemEntity],
    );

    expect(result.isSuccess, false);

    final savedBill = await (db.select(
      db.bills,
    )..where((t) => t.id.equals('bill-2'))).getSingleOrNull();
    expect(savedBill, isNull);

    final savedProduct = await (db.select(
      db.products,
    )..where((t) => t.id.equals(productId))).getSingle();
    expect(savedProduct.stockQuantity, 1.0);
  });
}
