import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dukanx/features/inventory/data/product_batch_repository.dart';
import 'package:dukanx/features/inventory/services/batch_allocation_service.dart';
import 'package:dukanx/models/bill.dart';
import 'package:dukanx/core/database/app_database.dart';

import 'batch_allocation_service_test.mocks.dart';

@GenerateMocks([ProductBatchRepository])
void main() {
  late BatchAllocationService service;
  late MockProductBatchRepository mockBatchRepo;

  setUp(() {
    mockBatchRepo = MockProductBatchRepository();
    service = BatchAllocationService(productBatchRepository: mockBatchRepo);
  });

  group('BatchAllocationService', () {
    test('Should split item across multiple batches (FEFO)', () async {
      // GIVEN
      const productId = 'prod-123';
      const batchAId = 'batch-a';
      const batchBId = 'batch-b';

      final item = BillItem(
        productId: productId,
        productName: 'Paracetamol',
        qty: 10,
        price: 100,
        gstRate: 18,
        discount: 10,
        cgst: 9, // 9% of (1000 - 10) roughly? No, let's say total tax 18.
        sgst: 9,
      );

      final bill = Bill.empty().copyWith(
        items: [item],
        businessType: 'pharmacy',
      );

      // Batches
      // Batch A: 4 qty (Expiring soon)
      // Batch B: 8 qty (Expiring later)
      final batchA = ProductBatchEntity(
        id: batchAId,
        productId: productId,
        userId: 'user-1',
        batchNumber: 'BATCH-A',
        expiryDate: DateTime.now().add(const Duration(days: 10)),
        stockQuantity: 4,
        openingQuantity: 10,
        purchaseRate: 50,
        sellingRate: 100,
        mrp: 100.0,
        status: 'ACTIVE',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      final batchB = ProductBatchEntity(
        id: batchBId,
        productId: productId,
        userId: 'user-1',
        batchNumber: 'BATCH-B',
        expiryDate: DateTime.now().add(const Duration(days: 20)),
        stockQuantity: 8,
        openingQuantity: 10,
        purchaseRate: 50,
        sellingRate: 100,
        mrp: 100.0,
        status: 'ACTIVE',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      when(
        mockBatchRepo.getBatchesForFefo(productId),
      ).thenAnswer((_) async => [batchA, batchB]);

      // WHEN
      final resultBill = await service.allocateBatches(bill);

      // THEN
      expect(resultBill.items.length, 2, reason: 'Should split into 2 items');

      // First Item: From Batch A (4 qty)
      final item1 = resultBill.items[0];
      expect(item1.batchId, batchAId);
      expect(item1.batchNo, 'BATCH-A');
      expect(item1.qty, 4);
      expect(item1.discount, 4); // Pro-rated discount (10 * 4/10)

      // Second Item: From Batch B (6 qty)
      final item2 = resultBill.items[1];
      expect(item2.batchId, batchBId);
      expect(item2.batchNo, 'BATCH-B');
      expect(item2.qty, 6);
      expect(item2.discount, 6); // Pro-rated discount (10 * 6/10)
    });

    test('Should handle insufficient stock by adding remainder item', () async {
      // GIVEN
      const productId = 'prod-123';

      final item = BillItem(
        productId: productId,
        productName: 'Paracetamol',
        qty: 10, // Want 10
        price: 100,
      );

      final bill = Bill.empty().copyWith(items: [item]);

      // Batch A: Only 3 qty total avail
      final batchA = ProductBatchEntity(
        id: 'batch-a',
        productId: productId,
        userId: 'user-1',
        batchNumber: 'BATCH-A',
        expiryDate: DateTime.now(),
        stockQuantity: 3,
        openingQuantity: 10,
        purchaseRate: 50,
        sellingRate: 100,
        mrp: 100.0,
        status: 'ACTIVE',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      when(
        mockBatchRepo.getBatchesForFefo(productId),
      ).thenAnswer((_) async => [batchA]);

      // WHEN
      final resultBill = await service.allocateBatches(bill);

      // THEN
      expect(resultBill.items.length, 2);

      // Item 1: 3 qty from Batch A
      expect(resultBill.items[0].qty, 3);
      expect(resultBill.items[0].batchId, 'batch-a');

      // Item 2: 7 qty remainder (no batch)
      expect(resultBill.items[1].qty, 7);
      expect(resultBill.items[1].batchId, isNull);
    });

    test(
      'Should skip items that already have a batchId (Manual override)',
      () async {
        // GIVEN
        final item = BillItem(
          productId: 'prod-123',
          productName: 'Manual Selection',
          qty: 5,
          price: 100,
          batchId: 'manual-batch-id', // User already picked one
        );

        final bill = Bill.empty().copyWith(items: [item]);

        // WHEN
        final resultBill = await service.allocateBatches(bill);

        // THEN
        verifyNever(mockBatchRepo.getBatchesForFefo(any));
        expect(resultBill.items.length, 1);
        expect(resultBill.items[0].batchId, 'manual-batch-id');
      },
    );
  });
}
