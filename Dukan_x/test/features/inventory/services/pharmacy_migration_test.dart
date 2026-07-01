import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/repository/products_repository.dart';
import 'package:dukanx/core/error/error_handler.dart';
import 'package:dukanx/features/inventory/data/product_batch_repository.dart';
import 'package:dukanx/features/inventory/services/pharmacy_migration_service.dart';

import 'pharmacy_migration_test.mocks.dart';

@GenerateMocks([ProductsRepository, ProductBatchRepository])
void main() {
  late PharmacyMigrationService service;
  late MockProductsRepository mockProductsRepo;
  late MockProductBatchRepository mockBatchRepo;

  setUp(() {
    mockProductsRepo = MockProductsRepository();
    mockBatchRepo = MockProductBatchRepository();
    service = PharmacyMigrationService(mockProductsRepo, mockBatchRepo);
  });

  group('PharmacyMigrationService', () {
    test('Should migrate products with stock > 0 to Legacy Batches', () async {
      // GIVEN
      const userId = 'user-1';
      final product1 = Product(
        id: 'p1',
        userId: userId,
        name: 'Paracetamol',
        sellingPrice: 10,
        stockQuantity: 100, // Has stock, needs migration
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final product2 = Product(
        id: 'p2',
        userId: userId,
        name: 'Syringe',
        sellingPrice: 5,
        stockQuantity: 0, // No stock, should skip
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Mock getAll products
      when(
        mockProductsRepo.getAll(userId: userId),
      ).thenAnswer((_) async => RepositoryResult.success([product1, product2]));

      // Mock check for existing batches (None exist)
      when(mockBatchRepo.getAllBatches('p1')).thenAnswer((_) async => []);

      // Mock create batch
      when(
        mockBatchRepo.createBatch(any),
      ).thenAnswer((_) async => 'batch-id-1');

      // WHEN
      final result = await service.migrateLegacyStock(userId);

      // THEN
      expect(result.success, true);
      expect(result.migratedCount, 1); // Only p1
      expect(result.skippedCount, 0);

      // Verify createBatch called for p1
      // Note: ProductBatchesCompanion fields are Value types
      verify(
        mockBatchRepo.createBatch(
          argThat(
            predicate((batch) {
              if (batch is! ProductBatchesCompanion) return false;
              return batch.productId.value == 'p1' &&
                  batch.batchNumber.value == 'LEGACY_OPENING' &&
                  batch.expiryDate.value == null &&
                  batch.stockQuantity.value == 100;
            }),
          ),
        ),
      ).called(1);
    });

    test('Should skip products that already have batches', () async {
      // GIVEN
      const userId = 'user-1';
      final product1 = Product(
        id: 'p1',
        userId: userId,
        name: 'Paracetamol',
        sellingPrice: 10,
        stockQuantity: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(
        mockProductsRepo.getAll(userId: userId),
      ).thenAnswer((_) async => RepositoryResult.success([product1]));

      // Mock check for existing batches (Exists!)
      final existingBatch = ProductBatchEntity(
        id: 'b1',
        productId: 'p1',
        userId: userId,
        batchNumber: 'BATCH-001',
        expiryDate: DateTime.now(),
        manufacturingDate: null,
        stockQuantity: 50,
        openingQuantity: 50,
        purchaseRate: 5,
        sellingRate: 10,
        mrp: 15,
        status: 'ACTIVE',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: true,
        syncOperationId: null,
      );

      when(
        mockBatchRepo.getAllBatches('p1'),
      ).thenAnswer((_) async => [existingBatch]);

      // WHEN
      final result = await service.migrateLegacyStock(userId);

      // THEN
      expect(result.success, true);
      expect(result.migratedCount, 0);
      expect(result.skippedCount, 1);

      verifyNever(mockBatchRepo.createBatch(any));
    });
  });
}
