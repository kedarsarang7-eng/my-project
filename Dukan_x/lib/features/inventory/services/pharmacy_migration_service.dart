import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/repository/products_repository.dart';
import '../data/product_batch_repository.dart';

/// One-time migration service to make existing data pharmacy-compliant.
/// Converts flat stock into "Legacy Batches".
class PharmacyMigrationService {
  final ProductsRepository _productsRepo;
  final ProductBatchRepository _batchRepo;

  PharmacyMigrationService(this._productsRepo, this._batchRepo);

  /// Run migration for a specific user tenant.
  /// idempotency: checks if batches already exist for products.
  Future<MigrationResult> migrateLegacyStock(String userId) async {
    int migratedCount = 0;
    int skippedCount = 0;
    List<String> errors = [];

    try {
      // 1. Get all active products
      // Ideally we'd filter by stock>0 in query, but repo getAll doesn't support it.
      // We'll fetch all and filter in memory.
      // This is a one-time migration, so performance hit is acceptable.
      final result = await _productsRepo.getAll(userId: userId);
      if (result.data == null) {
        return MigrationResult(
          success: false,
          migratedCount: 0,
          skippedCount: 0,
          error: "Failed to fetch products: ${result.error}",
        );
      }

      final products = result.data!.where((p) => p.stockQuantity > 0).toList();

      for (var p in products) {
        try {
          // 2. Check if ANY batches exist for this product
          final batches = await _batchRepo.getAllBatches(p.id);
          if (batches.isNotEmpty) {
            // Already compliant or partially migrated
            skippedCount++;
            continue;
          }

          // 3. Create a LEGACY batch for the entire current stock
          // "Legacy stock must be assigned expiry before pharmacy sales enabled" - User Rule
          // We set expiry to NULL to flag it as legacy/unsafe.
          final legacyBatch = ProductBatchesCompanion(
            id: Value(const Uuid().v4()),
            productId: Value(p.id),
            userId: Value(userId),
            // Unique batch name per product
            batchNumber: Value('LEGACY_OPENING'),
            expiryDate: const Value(null), // Flag: Needs manual update
            manufacturingDate: const Value(null),
            mrp: Value(p.sellingPrice),
            sellingRate: Value(p.sellingPrice),
            purchaseRate: Value(p.costPrice),
            openingQuantity: Value(p.stockQuantity),
            stockQuantity: Value(p.stockQuantity),
            status: const Value('ACTIVE'),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          );

          await _batchRepo.createBatch(legacyBatch);
          migratedCount++;
        } catch (e) {
          errors.add("Failed to migrate product ${p.name} (${p.id}): $e");
        }
      }
    } catch (e) {
      return MigrationResult(
        success: false,
        migratedCount: migratedCount,
        skippedCount: skippedCount,
        error: "Fatal Migration Error: $e",
      );
    }

    return MigrationResult(
      success: errors.isEmpty,
      migratedCount: migratedCount,
      skippedCount: skippedCount,
      error: errors.isNotEmpty ? errors.join('\n') : null,
    );
  }
}

class MigrationResult {
  final bool success;
  final int migratedCount;
  final int skippedCount;
  final String? error;

  MigrationResult({
    required this.success,
    required this.migratedCount,
    required this.skippedCount,
    this.error,
  });

  @override
  String toString() =>
      'MigrationResult(success: $success, migrated: $migratedCount, skipped: $skippedCount, error: $error)';
}
