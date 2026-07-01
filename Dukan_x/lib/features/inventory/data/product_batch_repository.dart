import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

/// Repository for managing Product Batches (Pharmacy Compliance)
/// Handles FEFO (First-Expire-First-Out) logic and batch inventory.
class ProductBatchRepository {
  final AppDatabase _db;

  ProductBatchRepository(this._db);

  /// Get ACTIVE batches for a product, sorted by FEFO (Earliest Expiry First).
  /// Used by the billing engine to auto-allocate stock.
  Future<List<ProductBatchEntity>> getBatchesForFefo(String productId) {
    return (_db.select(_db.productBatches)
          ..where((t) => t.productId.equals(productId))
          ..where((t) => t.status.equals('ACTIVE'))
          ..where(
            (t) => t.stockQuantity.isBiggerThanValue(0),
          ) // Only available stock
          ..orderBy([
            // Primary Sort: Expiry Date ASC (Earliest first)
            (t) =>
                OrderingTerm(expression: t.expiryDate, mode: OrderingMode.asc),
            // Secondary Sort: Created Date ASC (Oldest batch first - FIFO fallback)
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Get all batches for a product (including empty/expired) for management UI
  Future<List<ProductBatchEntity>> getAllBatches(String productId) {
    return (_db.select(_db.productBatches)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.expiryDate, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Create a new batch
  Future<String> createBatch(ProductBatchesCompanion batch) async {
    await _db.into(_db.productBatches).insertOnConflictUpdate(batch);
    return batch.id.value;
  }

  /// Update stock for a specific batch (Atomic delta)
  /// Returns the new quantity
  Future<double> updateBatchStock(String batchId, double deltaQty) async {
    return await _db.transaction(() async {
      final batch = await (_db.select(
        _db.productBatches,
      )..where((t) => t.id.equals(batchId))).getSingle();

      final newQty = batch.stockQuantity + deltaQty;

      // Prevent negative stock strictly?
      // Drift/SQLite can enforce constraints, but soft check here for now.
      if (newQty < 0) {
        // We might allow negative if configured, but for Batch tracking it breaks the model.
        throw Exception("Insufficient stock in batch ${batch.batchNumber}");
      }

      await (_db.update(
        _db.productBatches,
      )..where((t) => t.id.equals(batchId))).write(
        ProductBatchesCompanion(
          stockQuantity: Value(newQty),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false), // Trigger sync
        ),
      );

      return newQty;
    });
  }

  /// Find a specific batch by number and product
  Future<ProductBatchEntity?> getBatchByNumber(
    String productId,
    String batchNumber,
  ) {
    return (_db.select(_db.productBatches)..where(
          (t) =>
              t.productId.equals(productId) & t.batchNumber.equals(batchNumber),
        ))
        .getSingleOrNull();
  }
}
