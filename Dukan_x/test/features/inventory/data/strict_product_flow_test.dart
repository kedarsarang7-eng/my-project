// Phase 5: Data Flow Verification Test
// Tests that ProductsRepository correctly handles Batch and IMEI inserts
//
// NOTE: This is a simplified unit test that verifies the core logic
// without requiring full Firebase/Monitoring integration.

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:dukanx/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    // In-memory database for testing
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('Strict Product Flow Verification (Direct DB)', () {
    const userId = 'test_owner_1';
    const productId = 'prod_test_1';

    test('Pharmacy Flow: ProductBatches table accepts valid data', () async {
      // Insert a product first
      await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              id: productId,
              userId: userId,
              name: 'Dolo 650',
              sellingPrice: 100.0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // Insert batches
      await database
          .into(database.productBatches)
          .insert(
            ProductBatchesCompanion.insert(
              id: 'batch_1',
              productId: productId,
              userId: userId,
              batchNumber: 'B001',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      await database
          .into(database.productBatches)
          .insert(
            ProductBatchesCompanion.insert(
              id: 'batch_2',
              productId: productId,
              userId: userId,
              batchNumber: 'B002',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // Verify
      final batches = await (database.select(
        database.productBatches,
      )..where((t) => t.productId.equals(productId))).get();

      expect(batches.length, 2);
      expect(batches.any((b) => b.batchNumber == 'B001'), true);
      expect(batches.any((b) => b.batchNumber == 'B002'), true);
    });

    test('Electronics Flow: IMEISerials table accepts valid data', () async {
      const productId2 = 'prod_test_2';

      // Insert a product first
      await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              id: productId2,
              userId: userId,
              name: 'iPhone 15',
              sellingPrice: 80000.0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // Insert IMEIs
      await database
          .into(database.iMEISerials)
          .insert(
            IMEISerialsCompanion.insert(
              id: 'imei_1',
              productId: productId2,
              userId: userId,
              imeiOrSerial: 'IMEI_12345',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      await database
          .into(database.iMEISerials)
          .insert(
            IMEISerialsCompanion.insert(
              id: 'imei_2',
              productId: productId2,
              userId: userId,
              imeiOrSerial: 'IMEI_67890',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // Verify
      final imeis = await (database.select(
        database.iMEISerials,
      )..where((t) => t.productId.equals(productId2))).get();

      expect(imeis.length, 2);
      expect(imeis.any((x) => x.imeiOrSerial == 'IMEI_12345'), true);
      expect(imeis.any((x) => x.imeiOrSerial == 'IMEI_67890'), true);
    });

    test('Unique IMEI constraint prevents duplicates', () async {
      const productId3 = 'prod_test_3';

      await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              id: productId3,
              userId: userId,
              name: 'Samsung Galaxy',
              sellingPrice: 50000.0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      await database
          .into(database.iMEISerials)
          .insert(
            IMEISerialsCompanion.insert(
              id: 'imei_dup_1',
              productId: productId3,
              userId: userId,
              imeiOrSerial: 'DUPLICATE_IMEI',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // Attempt duplicate IMEI for same user should fail
      expect(
        () async => await database
            .into(database.iMEISerials)
            .insert(
              IMEISerialsCompanion.insert(
                id: 'imei_dup_2',
                productId: productId3,
                userId: userId,
                imeiOrSerial: 'DUPLICATE_IMEI', // Same IMEI
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ),
        throwsA(anything), // Expect unique constraint violation
      );
    });
  });
}
