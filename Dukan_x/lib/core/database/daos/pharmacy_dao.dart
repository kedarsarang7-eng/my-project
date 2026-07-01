import 'package:drift/drift.dart';
import '../app_database.dart';

/// Pharmacy DAO (Data Access Object)
///
/// Handles all database operations specific to the Pharmacy / Medical business type.
/// Encapsulates logic for Batches, Expiry, and Prescription linking.
class PharmacyDao {
  final AppDatabase db;

  PharmacyDao(this.db);

  // ==========================================================================
  // BATCH MANAGEMENT
  // ==========================================================================

  /// Get all available batches for a specific product in FEFO order.
  ///
  /// FEFO (First-Expiry-First-Out) ordering rules (Requirements 17.1–17.3):
  /// - Only batches with available quantity > 0 are returned (R17.1).
  /// - Ordered by expiry date ascending, earliest expiry first (R17.1).
  /// - Ties on expiry date are broken by batch identifier (`id`) ascending so
  ///   the ordering is deterministic and repeatable (R17.2).
  /// - Batches with no expiry date are ordered after all dated batches (R17.3).
  ///
  /// STRICT ISOLATION: filtered by [userId] (tenant scope).
  Future<List<ProductBatchEntity>> getBatchesForProduct(
    String userId,
    String productId,
  ) {
    return (db.select(db.productBatches)
          ..where((t) => t.userId.equals(userId))
          ..where((t) => t.productId.equals(productId))
          ..where((t) => t.status.equals('ACTIVE'))
          ..where((t) => t.stockQuantity.isBiggerThanValue(0.0))
          ..orderBy(_fefoOrdering))
        .get();
  }

  /// Batched FEFO retrieval for multiple products in a single query.
  ///
  /// Eliminates the N+1 query pattern (Requirement 21.1): instead of one
  /// round-trip per product, this issues a single `IN (...)` query for all
  /// requested products and groups the results in memory.
  ///
  /// Returns a `Map<productId, List<ProductBatchEntity>>` where every requested
  /// productId is present (mapping to an empty list when it has no available
  /// batches), and each list is ordered by the same FEFO rule as
  /// [getBatchesForProduct] (R17.1–R17.3, R21.2).
  ///
  /// STRICT ISOLATION: filtered by [userId] (tenant scope).
  Future<Map<String, List<ProductBatchEntity>>> getBatchesForProducts(
    String userId,
    List<String> productIds,
  ) async {
    // Pre-seed the result so callers can look up any requested id safely,
    // and de-duplicate to avoid redundant work / oversized IN clauses.
    final result = <String, List<ProductBatchEntity>>{};
    for (final id in productIds) {
      result[id] = <ProductBatchEntity>[];
    }
    if (result.isEmpty) return result;

    // Single batched query (fixed round-trip count, independent of item count).
    final rows =
        await (db.select(db.productBatches)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.productId.isIn(result.keys.toList()))
              ..where((t) => t.status.equals('ACTIVE'))
              ..where((t) => t.stockQuantity.isBiggerThanValue(0.0))
              ..orderBy(_fefoOrdering))
            .get();

    // Grouping preserves the global FEFO ordering within each product, since
    // the query already sorts by (has-expiry, expiry asc, id asc).
    for (final row in rows) {
      (result[row.productId] ??= <ProductBatchEntity>[]).add(row);
    }
    return result;
  }

  /// Shared FEFO ordering terms (Requirements 17.1–17.3).
  ///
  /// The leading `expiryDate.isNull()` term sorts dated batches (false → 0)
  /// before undated batches (true → 1), guaranteeing null-expiry batches come
  /// last regardless of the underlying SQLite NULLS-ordering behaviour.
  static List<OrderingTerm Function($ProductBatchesTable)> get _fefoOrdering =>
      [
        (t) => OrderingTerm.asc(t.expiryDate.isNull()),
        (t) => OrderingTerm.asc(t.expiryDate),
        (t) => OrderingTerm.asc(t.id),
      ];

  /// Get all batches expiring within the next [days] days
  Future<List<ProductBatchEntity>> getExpiringBatches(
    String userId, {
    int days = 30,
  }) {
    final expiryThreshold = DateTime.now().add(Duration(days: days));
    return (db.select(db.productBatches)
          ..where((t) => t.userId.equals(userId))
          ..where((t) => t.expiryDate.isSmallerOrEqualValue(expiryThreshold))
          ..where((t) => t.status.equals('ACTIVE'))
          ..orderBy([(t) => OrderingTerm.asc(t.expiryDate)]))
        .get();
  }

  /// Find a specific batch by its number
  Future<ProductBatchEntity?> getBatchByNumber(
    String userId,
    String productId,
    String batchNumber,
  ) {
    return (db.select(db.productBatches)
          ..where((t) => t.userId.equals(userId))
          ..where((t) => t.productId.equals(productId))
          ..where((t) => t.batchNumber.equals(batchNumber)))
        .getSingleOrNull();
  }

  // ==========================================================================
  // STOCK OPERATIONS
  // ==========================================================================

  /// Consumes stock from a specific batch.
  /// Returns true if successful, false if insufficient stock.
  Future<bool> consumeBatchStock(
    String userId,
    String batchId,
    double quantity,
  ) async {
    return db.transaction(() async {
      final batch =
          await (db.select(db.productBatches)
                ..where((t) => t.id.equals(batchId))
                ..where(
                  (t) => t.userId.equals(userId),
                )) // Double check isolation
              .getSingle();

      if (batch.stockQuantity < quantity) {
        return false; // Insufficient stock
      }

      await (db.update(
        db.productBatches,
      )..where((t) => t.id.equals(batchId))).write(
        ProductBatchesCompanion(
          stockQuantity: Value(batch.stockQuantity - quantity),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Also log movement in generic stock table
      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: '${batchId}_${DateTime.now().millisecondsSinceEpoch}', // Simple ID gen
              userId: userId,
              productId: batch.productId,
              type: 'OUT',
              reason: 'SALE',
              quantity: quantity,
              stockBefore: Value(batch.stockQuantity),
              stockAfter: Value(batch.stockQuantity - quantity),
              batchId: Value(batchId),
              batchNumber: Value(batch.batchNumber),
              date: DateTime.now(),
              createdAt: DateTime.now(),
            ),
          );

      return true;
    });
  }

  // ==========================================================================
  // PRESCRIPTION LINKING
  // ==========================================================================

  // Future methods for Rx linking can be added here
}
