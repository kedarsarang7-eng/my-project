import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/repository/bills_repository.dart';
import 'package:dukanx/core/repository/shop_link_repository.dart';
import 'package:dukanx/features/inventory/services/inventory_service.dart';
// import 'package:dukanx/core/di/service_locator.dart'; // Unused
// import 'package:dukanx/models/bill.dart'; // Unused
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/error/error_handler.dart';
import 'package:dukanx/features/inventory/data/product_batch_repository.dart';
import 'package:dukanx/features/accounting/services/accounting_service.dart';
import 'package:dukanx/features/accounting/services/locking_service.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/features/accounting/models/journal_entry_model.dart';

// ... (Mocks remain unchanged)

// Mocks
class MockSyncManager extends Mock implements SyncManager {
  @override
  Future<String> enqueue(SyncQueueItem? item) async {
    return 'mock-op-id';
  }
}

class MockErrorHandler extends Mock implements ErrorHandler {
  @override
  Future<RepositoryResult<T>> runSafe<T>(
    Future<T> Function() block,
    String operation,
  ) async {
    final result = await block();
    return RepositoryResult.success(result);
  }
}

class MockProductBatchRepository extends Mock
    implements ProductBatchRepository {}

// ... other imports ...

class MockAccountingService extends Mock implements AccountingService {
  @override
  Future<JournalEntryModel> createStockEntry({
    required String userId,
    required String referenceId,
    required String type,
    required String reason,
    required double amount,
    required DateTime date,
    String? description,
    String? transactionId,
  }) async {
    return JournalEntryModel(
      id: 'mock-entry',
      userId: userId,
      voucherNumber: 'JV-001',
      voucherType: VoucherType.journal,
      entryDate: date,
      narration: description ?? 'Mock Entry',
      sourceType: SourceTypeExtension.fromString(type),
      sourceId: referenceId,
      entries: [
        JournalEntryLine(
          ledgerId: 'acc1',
          ledgerName: 'Debit A/c',
          debit: amount,
        ),
        JournalEntryLine(
          ledgerId: 'acc2',
          ledgerName: 'Credit A/c',
          credit: amount,
        ),
      ],
      totalDebit: amount,
      totalCredit: amount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
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
    return JournalEntryModel(
      id: 'mock-sales-entry',
      userId: userId,
      voucherNumber: invoiceNumber,
      voucherType: VoucherType.sales,
      entryDate: invoiceDate,
      narration: 'Mock Sales Entry',
      sourceType: SourceType.bill,
      sourceId: billId,
      entries: [
        JournalEntryLine(
          ledgerId: 'acc1',
          ledgerName: 'Debit A/c',
          debit: totalAmount,
        ),
        JournalEntryLine(
          ledgerId: 'acc2',
          ledgerName: 'Credit A/c',
          credit: totalAmount,
        ),
      ],
      totalDebit: totalAmount,
      totalCredit: totalAmount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<bool> isPeriodLocked({
    required String userId,
    required DateTime date,
  }) async {
    return false;
  }
}

class MockLockingService extends Mock implements LockingService {
  @override
  Future<void> validateAction(
    String userId,
    DateTime date, {
    LockOverrideContext? overrideContext,
  }) async {}
}

void main() {
  late AppDatabase database;
  late BillsRepository billsRepo;
  late ShopLinkRepository shopLinkRepo;
  late InventoryService inventoryService;

  setUp(() {
    // In-memory database
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final mockSyncManager = MockSyncManager();
    final mockErrorHandler = MockErrorHandler();

    // Initialize Repositories
    billsRepo = BillsRepository(
      database: database,
      syncManager: mockSyncManager,
      errorHandler: mockErrorHandler,
    );
    shopLinkRepo = ShopLinkRepository(
      database: database,
      syncManager: mockSyncManager,
      errorHandler: mockErrorHandler,
    );

    inventoryService = InventoryService(
      database,
      MockLockingService(),
      MockAccountingService(),
      mockSyncManager,
      MockProductBatchRepository(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Audit Fix Verification', () {
    test('1. Data Isolation: filtered by businessId', () async {
      // 1. Create two bills for same user but different businesses
      await database
          .into(database.bills)
          .insert(
            BillsCompanion.insert(
              id: 'bill1',
              userId: 'user1',
              invoiceNumber: 'INV1',
              billDate: DateTime.now(),
              itemsJson: '[]',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              businessId: const Value('businessA'), // Shop A
            ),
          );

      await database
          .into(database.bills)
          .insert(
            BillsCompanion.insert(
              id: 'bill2',
              userId: 'user1', // Same User
              invoiceNumber: 'INV2',
              billDate: DateTime.now(),
              itemsJson: '[]',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              businessId: const Value('businessB'), // Shop B
            ),
          );

      // 2. Fetch for Business A
      final resultA = await billsRepo.getAll(
        userId: 'user1',
        businessId: 'businessA',
      );
      expect(resultA.data!.length, 1);
      expect(resultA.data!.first.id, 'bill1');

      // 3. Fetch for Business B
      final resultB = await billsRepo.getAll(
        userId: 'user1',
        businessId: 'businessB',
      );
      expect(resultB.data!.length, 1);
      expect(resultB.data!.first.id, 'bill2');

      // 4. Fetch without businessId (should return both if allowed by repo, or filter logic dependent)
      // The updated repo logic: if (businessId != null) query.where(...)
      // So passing null should return both? Or does it enforce one?
      // Based on my edit: if passed, it filters. If not, it returns all for user.
      final resultAll = await billsRepo.getAll(userId: 'user1');
      expect(resultAll.data!.length, 2);
    });

    test('2. Security: ShopLink ID is deterministic', () async {
      final customerId = 'cust123';
      final shopId = 'shop456';

      final link = await shopLinkRepo.createLink(
        customerId: customerId,
        shopId: shopId,
        customerProfileId: 'prof1',
        shopName: 'Test Shop',
      );

      final expectedId = '${customerId}_$shopId';
      expect(link.data!.id, expectedId);
    });

    test('3. Inventory: Negative Stock Blocking', () async {
      final userId = 'owner_neg_verify';
      final productId = 'prod_neg_verify';

      // 1. Setup - NO SHOP implies allowNegativeStock = FALSE (Default)
      // Ensure no shop exists
      // (No insert here)

      // 2. Add Product with stock 5
      await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              id: productId,
              userId: userId,
              name: 'Test Product',
              sellingPrice: 100,
              stockQuantity: const Value(5.0),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // 3. Try to sell 10 (Should fail - default is false)
      await expectLater(
        () async => await inventoryService.addStockMovement(
          userId: userId,
          productId: productId,
          type: 'OUT',
          reason: 'SALE',
          quantity: 10.0,
          referenceId: 'ref1',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Negative stock is disabled'),
          ),
        ),
      );

      // 4. Create Shop with allowNegativeStock = TRUE
      await database
          .into(database.shops)
          .insert(
            ShopsCompanion.insert(
              id: 'shop_neg_verify',
              name: 'My Shop',
              ownerId: userId,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              allowNegativeStock: const Value(true),
            ),
          );

      // 5. Try to sell 10 again (Should succeed)
      await inventoryService.addStockMovement(
        userId: userId,
        productId: productId,
        type: 'OUT',
        reason: 'SALE',
        quantity: 10.0,
        referenceId: 'ref2',
      );

      // Verify stock is -5
      final product = await (database.select(
        database.products,
      )..where((t) => t.id.equals(productId))).getSingle();
      expect(product.stockQuantity, -5.0);
    });
  });
}
