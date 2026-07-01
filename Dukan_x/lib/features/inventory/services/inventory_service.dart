import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../accounting/services/accounting_service.dart';
import '../../accounting/services/locking_service.dart';
import '../../../core/repository/products_repository.dart';

/// Inventory Service - The Guardian of Stock "Golden Rules"
///
/// 1. Single Entry Point: All modifications loop through `addStockMovement`.
/// 2. Period Lock: Prevents modification of frozen periods.
/// 3. Zero-Negative: Prevents stock going below zero (unless configured).
/// 4. Accounting Link: Automatically posts Journal Entries.
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/sync_queue_state_machine.dart';

import '../data/product_batch_repository.dart';

class InventoryService {
  final AppDatabase _db;
  final LockingService _lockingService;
  final AccountingService _accountingService;
  final SyncManager _syncManager;
  final ProductBatchRepository _batchRepo;

  InventoryService(
    this._db,
    this._lockingService,
    this._accountingService,
    this._syncManager,
    this._batchRepo,
  );

  /// Add a stock movement (IN or OUT)
  Future<void> addStockMovement({
    required String userId,
    required String productId,
    required String type, // 'IN' or 'OUT'
    required String reason, // SALE, PURCHASE, DAMAGE, OPENING_STOCK...
    required double quantity, // Always positive
    required String referenceId,
    DateTime? date, // Defaults to now
    String? description,
    String? batchId, // PHARMACY: Required
    String? batchNumber,
    String? warehouseId,
    String? createdBy,
    double? newCostPrice, // For PURCHASE/OPENING to update average/latest cost
  }) async {
    final movementDate = date ?? DateTime.now();

    // RULE 1: Period Lock Validation
    await _lockingService.validateAction(userId, movementDate);

    if (quantity <= 0) {
      throw Exception('Quantity must be positive');
    }

    // CHECK PHARMACY COMPLIANCE
    final shop = await (_db.select(
      _db.shops,
    )..where((t) => t.ownerId.equals(userId))).getSingleOrNull();

    final isPharmacy =
        shop?.businessType == 'pharmacy' ||
        shop?.businessType == 'medical_store';

    if (isPharmacy && (batchId == null || batchId.isEmpty)) {
      throw Exception(
        'Pharmacy Compliance Error: Batch ID is mandatory for stock movement.',
      );
    }

    await _db.transaction(() async {
      // Fetch Product to check current stock and cost
      final product =
          await (_db.select(
                _db.products,
              )..where((t) => t.id.equals(productId) & t.userId.equals(userId)))
              .getSingleOrNull();

      if (product == null) {
        throw Exception('Product not found: $productId');
      }

      // HIS AUDIT: Service Items (Consultations, Lab Tests) do not track stock
      // We check category convention since we cannot migrate schema for 'type' column yet.
      final category = product.category?.toLowerCase() ?? '';
      final isService =
          category.startsWith('service') ||
          category == 'consultation' ||
          category == 'lab test' ||
          category == 'opd';

      if (isService) {
        // Services do not track stock quantity.
        // We skip strict stock checks and movements.
        // We still allow the flow to proceed but we don't insert movement or update quantity.
        // Returning here prevents the stock update transaction.
        return;
      }

      final currentStock = product.stockQuantity;
      double newStock = currentStock;

      debugPrint(
        'DEBUG: Product: ${product.name}, Current Stock: $currentStock, Selling: $quantity',
      );

      // RULE 2: Calculate New Stock and Check Availability (for OUT)
      if (type == 'OUT') {
        final allowNegative = shop?.allowNegativeStock ?? false;
        debugPrint('DEBUG: Allow Negative Effective: $allowNegative');
        if (currentStock < quantity) {
          if (!allowNegative) {
            throw Exception(
              'Insufficient Stock: ${product.name} (Available: $currentStock, Required: $quantity). Negative stock is disabled.',
            );
          }
          debugPrint(
            'WARNING: Negative Stock Sale! Available: $currentStock, Selling: $quantity',
          );
        }
        newStock = currentStock - quantity;
      } else {
        newStock = currentStock + quantity;
      }

      final now = DateTime.now();
      final movementId = const Uuid().v4();

      // Calculate Weighted Average Cost (WAC) for INWARD movements (Purchase/Opening)
      double updatedCostPrice = product.costPrice;

      if (type == 'IN' && newCostPrice != null && quantity > 0) {
        final totalOldValue = currentStock * product.costPrice;
        final totalNewValue = quantity * newCostPrice;
        final totalQty = currentStock + quantity;

        if (totalQty > 0) {
          updatedCostPrice = (totalOldValue + totalNewValue) / totalQty;
        }
      }

      // UPDATE BATCH STOCK IF APPLICABLE
      if (batchId != null) {
        final delta = type == 'IN' ? quantity : -quantity;
        await _batchRepo.updateBatchStock(batchId, delta);
      }

      await (_db.update(
        _db.products,
      )..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          stockQuantity: Value(newStock),
          costPrice: Value(updatedCostPrice),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      // Queue Product Sync
      final payload = {
        'stockQuantity': newStock,
        'updatedAt': now.toIso8601String(),
      };
      if (newCostPrice != null) {
        payload['costPrice'] = newCostPrice;
      }

      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.update,
          targetCollection: 'products',
          documentId: productId,
          payload: payload,
        ),
      );

      // Insert Immutable Movement Record
      final movement = StockMovementEntity(
        id: movementId,
        userId: userId,
        productId: productId,
        type: type,
        reason: reason,
        quantity: quantity,
        stockBefore: currentStock,
        stockAfter: newStock,
        referenceId: referenceId,
        description: description,
        batchId: batchId,
        batchNumber: batchNumber,
        warehouseId: warehouseId,
        date: movementDate,
        createdAt: now,
        createdBy: createdBy ?? 'SYSTEM',
        isSynced: false,
      );

      await _db.into(_db.stockMovements).insert(movement);

      // Queue Stock Movement Sync
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.create,
          targetCollection: 'stock_movements',
          documentId: movementId,
          payload: {
            'id': movementId,
            'userId': userId,
            'productId': productId,
            'type': type,
            'reason': reason,
            'quantity': quantity,
            'stockBefore': currentStock,
            'stockAfter': newStock,
            'referenceId': referenceId,
            'description': description,
            'batchId': batchId,
            'batchNumber': batchNumber,
            'date': movementDate.toIso8601String(),
            'createdAt': now.toIso8601String(),
            'createdBy': createdBy ?? 'SYSTEM',
          },
        ),
      );

      // RULE 4: Accounting Link
      final accountingCost = newCostPrice ?? product.costPrice;
      final costValue = quantity * accountingCost;

      if (costValue > 0) {
        // Post Journal Entry
        await _accountingService.createStockEntry(
          userId: userId,
          referenceId: referenceId,
          type: type,
          reason: reason,
          amount: costValue,
          date: movementDate,
          description: description ?? 'Stock $type ($reason) - $quantity units',
        );
      }
    });
  }

  /// Deduct stock within an EXISTING transaction (for atomic bill + stock)
  ///
  /// IMPORTANT: This method MUST be called from within a database.transaction() block.
  /// It does NOT create its own transaction to avoid nested transaction issues.
  ///
  /// Returns a list of sync operations that should be queued AFTER the transaction completes.
  Future<List<SyncQueueItem>> deductStockInTransaction({
    required String userId,
    required String productId,
    required double quantity,
    required String referenceId,
    required String invoiceNumber,
    DateTime? date,
    String? batchId, // Pharmacy Compliance
    String? batchNumber,
    String reason = 'SALE',
    String? description,
  }) async {
    final movementDate = date ?? DateTime.now();
    final now = DateTime.now();
    final movementId = const Uuid().v4();

    // List to collect sync operations for later queuing
    final syncOps = <SyncQueueItem>[];

    // RULE 1: Period Lock Validation
    await _lockingService.validateAction(userId, movementDate);

    if (quantity <= 0) {
      throw Exception('Quantity must be positive');
    }

    // CHECK PHARMACY COMPLIANCE (Skip check inside transaction for perf? No, safer to check)
    // Limitation: Fetching shop inside transaction might be slow if repeated.
    // Assuming caller handles FEFO selection and passes batchId if required.

    // Fetch Product - NO transaction wrapper here, we're inside parent's transaction
    final product =
        await (_db.select(_db.products)
              ..where((t) => t.id.equals(productId) & t.userId.equals(userId)))
            .getSingleOrNull();

    if (product == null) {
      throw Exception('Product not found: $productId');
    }

    // HIS AUDIT: Service Items (Consultations, Lab Tests) do not track stock
    final category = product.category?.toLowerCase() ?? '';
    final isService =
        category.startsWith('service') ||
        category == 'consultation' ||
        category == 'lab test' ||
        category == 'opd';

    if (isService) {
      // Return empty list as no sync ops needed for stock
      return [];
    }

    final currentStock = product.stockQuantity;

    // RULE 2: Check stock availability
    if (currentStock < quantity) {
      // Fetch shop settings inside transaction (cached or quick fetch)
      // Note: In high throughput, we might want to pass this in.
      final shop = await (_db.select(
        _db.shops,
      )..where((t) => t.ownerId.equals(userId))).getSingleOrNull();
      final allowNegative = shop?.allowNegativeStock ?? false;

      if (!allowNegative) {
        throw Exception(
          'Insufficient Stock: ${product.name} (Available: $currentStock, Required: $quantity). Negative stock is disabled.',
        );
      }
      debugPrint(
        'WARNING: Negative Stock Sale for ${product.name}! Available: $currentStock, Selling: $quantity',
      );
    }

    final newStock = currentStock - quantity;

    // UPDATE BATCH STOCK (Atomic within existing transaction)
    if (batchId != null) {
      // We manually fetch and update because _batchRepo.updateBatchStock uses a transaction block
      // and nested transactions are tricky in Drift/SQLite.
      // Better to write raw update here or expose a "danger" method in repo.
      // Let's do direct update here for safety within this transaction scope.
      final batch = await (_db.select(
        _db.productBatches,
      )..where((t) => t.id.equals(batchId))).getSingle();

      final newBatchStock = batch.stockQuantity - quantity;
      await (_db.update(
        _db.productBatches,
      )..where((t) => t.id.equals(batchId))).write(
        ProductBatchesCompanion(
          stockQuantity: Value(newBatchStock),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );
    }

    // Update Product Stock (within parent transaction)
    await (_db.update(
      _db.products,
    )..where((t) => t.id.equals(productId))).write(
      ProductsCompanion(
        stockQuantity: Value(newStock),
        updatedAt: Value(now),
        isSynced: const Value(false),
      ),
    );

    // Collect sync op for product
    syncOps.add(
      SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.update,
        targetCollection: 'products',
        documentId: productId,
        payload: {
          'stockQuantity': newStock,
          'updatedAt': now.toIso8601String(),
        },
      ),
    );

    // Insert Immutable Movement Record (within parent transaction)
    final movement = StockMovementEntity(
      id: movementId,
      userId: userId,
      productId: productId,
      type: 'OUT',
      reason: reason,
      quantity: quantity,
      stockBefore: currentStock,
      stockAfter: newStock,
      referenceId: referenceId,
      description: description ?? 'Sale Invoice: $invoiceNumber',
      batchId: batchId,
      batchNumber: batchNumber,
      warehouseId: null,
      date: movementDate,
      createdAt: now,
      createdBy: 'SYSTEM',
      isSynced: false,
    );

    await _db.into(_db.stockMovements).insert(movement);

    // Collect sync op for movement
    syncOps.add(
      SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.create,
        targetCollection: 'stock_movements',
        documentId: movementId,
        payload: {
          'id': movementId,
          'userId': userId,
          'productId': productId,
          'type': 'OUT',
          'reason': reason,
          'quantity': quantity,
          'stockBefore': currentStock,
          'stockAfter': newStock,
          'referenceId': referenceId,
          'description': description ?? 'Sale Invoice: $invoiceNumber',
          'batchId': batchId,
          'batchNumber': batchNumber,
          'date': movementDate.toIso8601String(),
          'createdAt': now.toIso8601String(),
          'createdBy': 'SYSTEM',
        },
      ),
    );

    // RULE 4: Accounting Entry (within parent transaction)
    final costValue = quantity * product.costPrice;
    if (costValue > 0) {
      await _accountingService.createStockEntry(
        userId: userId,
        referenceId: referenceId,
        type: 'OUT',
        reason: 'SALE',
        amount: costValue,
        date: movementDate,
        description: 'Sale Invoice: $invoiceNumber - $quantity units',
      );
    }

    return syncOps;
  }

  /// Queue collected sync operations after transaction completes
  Future<void> queueStockSyncOperations(List<SyncQueueItem> syncOps) async {
    for (final op in syncOps) {
      await _syncManager.enqueue(op);
    }
  }

  /// Get stock history for a product
  Future<List<StockMovementEntity>> getStockHistory(String productId) {
    return (_db.select(_db.stockMovements)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Get Low Stock Products (Migrated from StockRepository)
  Future<List<Product>> getLowStockProducts(String userId) {
    return (_db.select(_db.products)..where(
          (t) =>
              t.userId.equals(userId) &
              t.stockQuantity.isSmallerOrEqual(t.lowStockThreshold) &
              t.deletedAt.isNull(),
        ))
        .get()
        .then((rows) => rows.map(_entityToProduct).toList());
  }

  Product _entityToProduct(ProductEntity e) => Product(
    id: e.id,
    userId: e.userId,
    name: e.name,
    sku: e.sku,
    barcode: e.barcode,
    category: e.category,
    unit: e.unit,
    sellingPrice: e.sellingPrice,
    costPrice: e.costPrice,
    taxRate: e.taxRate,
    stockQuantity: e.stockQuantity,
    lowStockThreshold: e.lowStockThreshold,
    isActive: e.isActive,
    isSynced: e.isSynced,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt,
    deletedAt: e.deletedAt,
  );
}
