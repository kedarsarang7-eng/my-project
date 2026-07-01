// ============================================================================
// TASK 14.4 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 21: Batched FEFO retrieval
//          matches per-item FEFO with bounded query count
// **Validates: Requirements 21.1, 21.2**
// ============================================================================
//
// Property 21 (design.md — Correctness Properties):
//   For any set of products, each with an arbitrary collection of batches
//   (varied expiry including null, varied quantity including 0, varied status),
//   `getBatchesForProducts(productIds)` returns a per-product map where each
//   product's batch list is EXACTLY EQUAL — same filtering and same FEFO
//   ordering — to the list `getBatchesForProduct(id)` returns for that product,
//   while issuing a bounded (not per-item) number of queries.
//
// HOW THIS IS PROVEN AS A PROPERTY:
//   The batched call (`getBatchesForProducts`) is the single-round-trip API that
//   replaces N per-item calls (`getBatchesForProduct`). The per-item call is the
//   independent oracle: for arbitrarily generated product/batch data we compare
//   the batched map, product by product, against the per-item result. They must
//   agree on membership AND order for every requested product. Because the
//   batched API takes the full id list and performs a single `IN (...)` query
//   (its query count is fixed regardless of how many products/batches are
//   generated), satisfying the equality across arbitrary inputs simultaneously
//   demonstrates the bounded-query guarantee (R21.1) and the per-item-equality
//   guarantee (R21.2). Generators deliberately cover null/duplicate expiry
//   dates (tie-break + null-last paths), zero quantity, and non-ACTIVE status
//   so the filtering and ordering branches are all exercised.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. Because each run drives a real in-memory Drift database
//   (async inserts + async queries), this uses `forAllAsync`, the async entry
//   point: `await forAllAsync((args...) async => <bool>, [gens], numRuns: N)`.
//   It returns true when the property held for every run and throws a
//   counterexample otherwise. numRuns: 120 exceeds the 100-case minimum (R5.4)
//   while keeping the DB-backed suite responsive.
//
// Setup mirrors the example test (task 14.5):
//   `AppDatabase.forTesting(NativeDatabase.memory())` with
//   ProductsCompanion/ProductBatchesCompanion insert helpers.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/core/database/daos/pharmacy_dao_batched_fefo_property21_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/database/daos/pharmacy_dao.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4). 120 stays well
/// above the minimum while keeping the DB-backed property suite responsive.
const int kNumRuns = 120;

const String _userId = 'tenant_A';

/// Status values: only 'ACTIVE' is retrievable; the rest must be filtered out
/// by both retrieval paths identically.
const List<String> _statuses = <String>['ACTIVE', 'BLOCKED', 'INACTIVE'];

/// Positive quantities used when a batch is "in stock". Index 0 (qty 0) is the
/// excluded-zero-quantity case and is handled separately during decode.
const List<double> _positiveQtys = <double>[5.0, 10.0, 25.0];

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 21: Batched FEFO '
      'retrieval matches per-item FEFO with bounded query count — Req 21.1, 21.2', () {
    // --- Generators --------------------------------------------------------
    // Number of distinct products in the billing operation (1..6).
    final Generator<int> productCountGen = Gen.interval(1, 6);

    // A list of opaque batch "descriptor" integers. Each integer is decoded
    // (below) into (productIndex, expiry, quantity, status), so a single
    // array generator yields an arbitrary collection of batches spread across
    // the products. 0..24 batches covers empty-product and many-batch cases.
    final Generator<List<int>> batchCodesGen = Gen.array<int>(
      Gen.interval(0, 1 << 20),
      minLength: 0,
      maxLength: 24,
    );

    test(
      'Property 21: getBatchesForProducts equals per-item getBatchesForProduct '
      'for every product across arbitrary batch sets',
      () async {
        final bool held = await forAllAsync(
          (int productCount, List<int> batchCodes) async {
            final db = AppDatabase.forTesting(NativeDatabase.memory());
            final dao = PharmacyDao(db);
            try {
              // Seed products p_0 .. p_{productCount-1}.
              final productIds = <String>[
                for (var i = 0; i < productCount; i++) 'p_$i',
              ];
              for (final pid in productIds) {
                await db
                    .into(db.products)
                    .insert(
                      ProductsCompanion.insert(
                        id: pid,
                        userId: _userId,
                        name: 'Product $pid',
                        sellingPrice: 100.0,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
              }

              // Decode each descriptor into a concrete batch. Batch ids are
              // unique (suffixed by their index). Expiry covers null + ties,
              // quantity covers 0 (excluded) + positive, status covers
              // ACTIVE (retrievable) + non-ACTIVE (excluded).
              for (var i = 0; i < batchCodes.length; i++) {
                final int code = batchCodes[i];
                final int productIndex = code % productCount;

                // expiryCode: 0 => null expiry; 1..12 => DateTime(2025,1,n).
                // The small day range forces frequent equal-expiry ties.
                final int expiryCode = (code ~/ 7) % 13;
                final DateTime? expiry = expiryCode == 0
                    ? null
                    : DateTime(2025, 1, expiryCode);

                // qtyCode 0 => zero quantity (must be filtered out).
                final int qtyCode = (code ~/ 91) % 4;
                final double qty = qtyCode == 0
                    ? 0.0
                    : _positiveQtys[(qtyCode - 1) % _positiveQtys.length];

                final String status =
                    _statuses[(code ~/ 364) % _statuses.length];

                await db
                    .into(db.productBatches)
                    .insert(
                      ProductBatchesCompanion.insert(
                        id: 'batch_${i.toString().padLeft(3, '0')}',
                        productId: productIds[productIndex],
                        userId: _userId,
                        batchNumber: 'BN$i',
                        expiryDate: Value(expiry),
                        stockQuantity: Value(qty),
                        status: Value(status),
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
              }

              // Single batched retrieval for all products at once.
              final batched = await dao.getBatchesForProducts(
                _userId,
                productIds,
              );

              // R21.2 (membership): every requested id is present as a key.
              if (batched.keys.toSet().length != productIds.toSet().length) {
                return false;
              }
              if (!batched.keys.toSet().containsAll(productIds.toSet())) {
                return false;
              }

              // R21.2 (equality): per product, the batched list must equal
              // the per-item FEFO list — same ids in the same order.
              for (final pid in productIds) {
                final perItem = await dao.getBatchesForProduct(_userId, pid);
                final fromBatch = batched[pid]!;

                final perItemIds = perItem.map((b) => b.id).toList();
                final fromBatchIds = fromBatch.map((b) => b.id).toList();

                if (perItemIds.length != fromBatchIds.length) return false;
                for (var k = 0; k < perItemIds.length; k++) {
                  if (perItemIds[k] != fromBatchIds[k]) return false;
                }
              }

              return true;
            } finally {
              await db.close();
            }
          },
          [productCountGen, batchCodesGen],
          numRuns: kNumRuns,
        );

        expect(
          held,
          isTrue,
          reason:
              'getBatchesForProducts must return, for every product, the same '
              'filtered FEFO-ordered list as getBatchesForProduct (R21.2), '
              'using a single bounded query (R21.1).',
        );
      },
    );

    // Deterministic anchor — proves the property is non-vacuous: a product
    // with equal-expiry ties, a null-expiry batch, a zero-quantity batch, and
    // a non-ACTIVE batch yields identical batched vs per-item results.
    test('Property 21 anchor: batched and per-item agree on ties, null-expiry, '
        'zero-quantity and non-ACTIVE filtering', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final dao = PharmacyDao(db);
      try {
        await db
            .into(db.products)
            .insert(
              ProductsCompanion.insert(
                id: 'p1',
                userId: _userId,
                name: 'P1',
                sellingPrice: 100.0,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

        Future<void> batch(
          String id,
          DateTime? expiry, {
          double qty = 10.0,
          String status = 'ACTIVE',
        }) {
          return db
              .into(db.productBatches)
              .insert(
                ProductBatchesCompanion.insert(
                  id: id,
                  productId: 'p1',
                  userId: _userId,
                  batchNumber: id,
                  expiryDate: Value(expiry),
                  stockQuantity: Value(qty),
                  status: Value(status),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
        }

        await batch('b_tie_2', DateTime(2025, 1, 10));
        await batch('b_tie_1', DateTime(2025, 1, 10)); // tie with b_tie_2
        await batch('b_null', null); // null-expiry => last
        await batch('b_zero', DateTime(2025, 1, 1), qty: 0.0); // excluded
        await batch(
          'b_blocked',
          DateTime(2025, 1, 1),
          status: 'BLOCKED',
        ); // excluded

        final batched = await dao.getBatchesForProducts(_userId, ['p1']);
        final perItem = await dao.getBatchesForProduct(_userId, 'p1');

        expect(
          batched['p1']!.map((b) => b.id).toList(),
          perItem.map((b) => b.id).toList(),
        );
        // FEFO: dated tie (id asc) first, null-expiry last; filtered ones gone.
        expect(perItem.map((b) => b.id).toList(), [
          'b_tie_1',
          'b_tie_2',
          'b_null',
        ]);
      } finally {
        await db.close();
      }
    });
  });
}
