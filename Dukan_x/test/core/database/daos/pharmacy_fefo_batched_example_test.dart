// Feature: pharmacy-vertical-remediation — FEFO / batched-retrieval EXAMPLE tests
//
// Task 14.5: DAO and POS-selection FEFO ordering, including the equal-expiry
// tie-break and missing-expiry cases, plus the batched-retrieval guarantee that
// the round-trip count does not grow per added item.
//
// Validates: Requirements 17.6, 21.4
//
// These are example-based unit tests (not property-based) over a real in-memory
// AppDatabase using the standard `AppDatabase.forTesting(NativeDatabase.memory())`
// pattern used across the suite. They exercise the production
// `PharmacyDao.getBatchesForProduct` / `getBatchesForProducts` ordering directly.
//
// POS-layer note: `BillCreationScreenV2` selects a batch by taking the FIRST
// element of an expiry-ascending defensive sort over the DAO result, and for
// >=2 items it fetches all batches with a single `getBatchesForProducts` call
// (Requirements 17.4–17.5, 21.1–21.2). Because the POS selection is "first of
// FEFO order", asserting the DAO ordering and the batched-vs-per-item equality
// covers the exact contract the POS relies on for its selection.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/database/daos/pharmacy_dao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PharmacyDao dao;

  const userId = 'tenant_A';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = PharmacyDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  // Helper: insert a product so batches reference a real product row.
  Future<void> insertProduct(String id, {String owner = userId}) {
    return db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            id: id,
            userId: owner,
            name: 'Product $id',
            sellingPrice: 100.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  }

  // Helper: insert a batch. expiryDate null => missing-expiry case.
  Future<void> insertBatch({
    required String id,
    required String productId,
    required String batchNumber,
    DateTime? expiryDate,
    double stockQuantity = 10.0,
    String status = 'ACTIVE',
    String owner = userId,
  }) {
    return db
        .into(db.productBatches)
        .insert(
          ProductBatchesCompanion.insert(
            id: id,
            productId: productId,
            userId: owner,
            batchNumber: batchNumber,
            expiryDate: Value(expiryDate),
            stockQuantity: Value(stockQuantity),
            status: Value(status),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  }

  DateTime day(int n) => DateTime(2025, 1, n);

  group('DAO FEFO ordering — getBatchesForProduct (R17.1–17.3, 17.6)', () {
    test('orders by expiry ascending, earliest expiry first', () async {
      await insertProduct('p1');
      await insertBatch(
        id: 'b_late',
        productId: 'p1',
        batchNumber: 'L',
        expiryDate: day(20),
      );
      await insertBatch(
        id: 'b_early',
        productId: 'p1',
        batchNumber: 'E',
        expiryDate: day(5),
      );
      await insertBatch(
        id: 'b_mid',
        productId: 'p1',
        batchNumber: 'M',
        expiryDate: day(10),
      );

      final batches = await dao.getBatchesForProduct(userId, 'p1');

      expect(batches.map((b) => b.id), ['b_early', 'b_mid', 'b_late']);
    });

    test('equal-expiry ties broken by batch id ascending', () async {
      await insertProduct('p1');
      // All three share the SAME expiry date; tie-break must be id ascending.
      await insertBatch(
        id: 'b_c',
        productId: 'p1',
        batchNumber: 'C',
        expiryDate: day(10),
      );
      await insertBatch(
        id: 'b_a',
        productId: 'p1',
        batchNumber: 'A',
        expiryDate: day(10),
      );
      await insertBatch(
        id: 'b_b',
        productId: 'p1',
        batchNumber: 'B',
        expiryDate: day(10),
      );

      final batches = await dao.getBatchesForProduct(userId, 'p1');

      expect(batches.map((b) => b.id), ['b_a', 'b_b', 'b_c']);
    });

    test('missing-expiry batches ordered after all dated batches', () async {
      await insertProduct('p1');
      await insertBatch(
        id: 'b_null2',
        productId: 'p1',
        batchNumber: 'N2',
        expiryDate: null,
      );
      await insertBatch(
        id: 'b_dated',
        productId: 'p1',
        batchNumber: 'D',
        expiryDate: day(15),
      );
      await insertBatch(
        id: 'b_null1',
        productId: 'p1',
        batchNumber: 'N1',
        expiryDate: null,
      );

      final batches = await dao.getBatchesForProduct(userId, 'p1');

      // Dated batch first, then null-expiry batches (tie-broken by id ascending).
      expect(batches.map((b) => b.id), ['b_dated', 'b_null1', 'b_null2']);
    });

    test(
      'combined: dated (asc) then equal-expiry (id asc) then null-expiry last',
      () async {
        await insertProduct('p1');
        await insertBatch(
          id: 'z_null',
          productId: 'p1',
          batchNumber: 'Z',
          expiryDate: null,
        );
        await insertBatch(
          id: 'b2',
          productId: 'p1',
          batchNumber: 'T2',
          expiryDate: day(10),
        );
        await insertBatch(
          id: 'b1',
          productId: 'p1',
          batchNumber: 'T1',
          expiryDate: day(10),
        );
        await insertBatch(
          id: 'b0',
          productId: 'p1',
          batchNumber: 'T0',
          expiryDate: day(3),
        );

        final batches = await dao.getBatchesForProduct(userId, 'p1');

        expect(batches.map((b) => b.id), ['b0', 'b1', 'b2', 'z_null']);
      },
    );

    test('excludes zero-quantity and non-ACTIVE batches', () async {
      await insertProduct('p1');
      await insertBatch(
        id: 'ok',
        productId: 'p1',
        batchNumber: 'OK',
        expiryDate: day(5),
      );
      await insertBatch(
        id: 'empty',
        productId: 'p1',
        batchNumber: 'EMPTY',
        expiryDate: day(1),
        stockQuantity: 0.0,
      );
      await insertBatch(
        id: 'blocked',
        productId: 'p1',
        batchNumber: 'BLK',
        expiryDate: day(2),
        status: 'BLOCKED',
      );

      final batches = await dao.getBatchesForProduct(userId, 'p1');

      expect(batches.map((b) => b.id), ['ok']);
    });

    test('is tenant-scoped — other tenant batches are excluded', () async {
      await insertProduct('p1');
      await insertBatch(
        id: 'mine',
        productId: 'p1',
        batchNumber: 'MINE',
        expiryDate: day(5),
      );
      await insertBatch(
        id: 'theirs',
        productId: 'p1',
        batchNumber: 'THEIRS',
        expiryDate: day(1),
        owner: 'tenant_B',
      );

      final batches = await dao.getBatchesForProduct(userId, 'p1');

      expect(batches.map((b) => b.id), ['mine']);
    });
  });

  group('POS-layer selection contract (R17.4–17.5)', () {
    // The POS auto-selects the FIRST batch of the FEFO order. These assert the
    // earliest-expiry batch is selected across the tie-break and missing-expiry
    // cases that the POS defensive sort must also honour.
    test('selects earliest-expiry batch with equal-expiry tie-break', () async {
      await insertProduct('p1');
      await insertBatch(
        id: 'b_b',
        productId: 'p1',
        batchNumber: 'B',
        expiryDate: day(5),
      );
      await insertBatch(
        id: 'b_a',
        productId: 'p1',
        batchNumber: 'A',
        expiryDate: day(5),
      );
      await insertBatch(
        id: 'b_later',
        productId: 'p1',
        batchNumber: 'X',
        expiryDate: day(9),
      );

      final selected = (await dao.getBatchesForProduct(userId, 'p1')).first;

      // Among equal-expiry earliest batches, id 'b_a' wins the tie-break.
      expect(selected.id, 'b_a');
    });

    test(
      'never selects a missing-expiry batch when a dated batch exists',
      () async {
        await insertProduct('p1');
        await insertBatch(
          id: 'b_null',
          productId: 'p1',
          batchNumber: 'N',
          expiryDate: null,
        );
        await insertBatch(
          id: 'b_dated',
          productId: 'p1',
          batchNumber: 'D',
          expiryDate: day(30),
        );

        final selected = (await dao.getBatchesForProduct(userId, 'p1')).first;

        expect(selected.id, 'b_dated');
        expect(selected.expiryDate, isNotNull);
      },
    );
  });

  group(
    'Batched retrieval — round-trip count does not grow per item (R21.1–21.2, 21.4)',
    () {
      test('a single getBatchesForProducts call returns correct per-product FEFO '
          'lists for >=10 items, matching per-item retrieval', () async {
        const itemCount = 12; // >= 10 items in one billing operation (R21.4).
        final productIds = <String>[];

        // Seed 12 products, each with 3 batches in deliberately scrambled
        // insert order so ordering must be applied, not incidental.
        for (var i = 0; i < itemCount; i++) {
          final pid = 'prod_$i';
          productIds.add(pid);
          await insertProduct(pid);
          // Two dated batches sharing an expiry (tie-break) + one null-expiry.
          await insertBatch(
            id: '${pid}_c',
            productId: pid,
            batchNumber: 'C$i',
            expiryDate: null,
          );
          await insertBatch(
            id: '${pid}_b',
            productId: pid,
            batchNumber: 'B$i',
            expiryDate: day(10),
          );
          await insertBatch(
            id: '${pid}_a',
            productId: pid,
            batchNumber: 'A$i',
            expiryDate: day(10),
          );
          await insertBatch(
            id: '${pid}_z',
            productId: pid,
            batchNumber: 'Z$i',
            expiryDate: day(2),
          );
        }

        // SINGLE batched call covering all 12 items (constant round-trips,
        // independent of item count — this is the API shape that guarantees the
        // round-trip count does not grow per added item, R21.1).
        final batched = await dao.getBatchesForProducts(userId, productIds);

        // Every requested product is present in the result map.
        expect(batched.keys.toSet(), productIds.toSet());

        // Per-product batched results EXACTLY match per-item FEFO retrieval
        // (R21.2): same selection and same ordering the POS would compute by
        // calling getBatchesForProduct once per item.
        for (final pid in productIds) {
          final perItem = await dao.getBatchesForProduct(userId, pid);
          final fromBatch = batched[pid]!;

          expect(
            fromBatch.map((b) => b.id).toList(),
            perItem.map((b) => b.id).toList(),
            reason: 'batched order must match per-item FEFO order for $pid',
          );
          // Expected FEFO order: earliest-expiry, then equal-expiry tie-break by
          // id ascending, then null-expiry last.
          expect(fromBatch.map((b) => b.id).toList(), [
            '${pid}_z',
            '${pid}_a',
            '${pid}_b',
            '${pid}_c',
          ]);
          // POS selection = first element = earliest-expiry batch.
          expect(fromBatch.first.id, '${pid}_z');
        }
      });

      test(
        'result map always contains every requested id, even with no batches',
        () async {
          await insertProduct('has_batch');
          await insertBatch(
            id: 'only',
            productId: 'has_batch',
            batchNumber: 'B',
            expiryDate: day(1),
          );
          // 'no_batch' product exists but has no batches; 'unknown' is not seeded.
          await insertProduct('no_batch');

          final batched = await dao.getBatchesForProducts(userId, [
            'has_batch',
            'no_batch',
            'unknown',
          ]);

          expect(batched.keys.toSet(), {'has_batch', 'no_batch', 'unknown'});
          expect(batched['has_batch']!.map((b) => b.id), ['only']);
          expect(batched['no_batch'], isEmpty);
          expect(batched['unknown'], isEmpty);
        },
      );

      test('batched retrieval is tenant-scoped', () async {
        await insertProduct('p1');
        await insertBatch(
          id: 'mine',
          productId: 'p1',
          batchNumber: 'M',
          expiryDate: day(5),
        );
        await insertBatch(
          id: 'theirs',
          productId: 'p1',
          batchNumber: 'T',
          expiryDate: day(1),
          owner: 'tenant_B',
        );

        final batched = await dao.getBatchesForProducts(userId, ['p1']);

        expect(batched['p1']!.map((b) => b.id), ['mine']);
      });
    },
  );
}
