// ============================================================================
// TASK 14.3 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 20: FEFO ordering and selection
// **Validates: Requirements 17.1, 17.2, 17.3, 17.4, 17.5**
// ============================================================================
//
// Property 20 (design.md — Correctness Properties):
//   For any set of batches for a product, the returned batches include only
//   those with available quantity greater than 0, ordered by expiry date
//   ascending, with ties broken by batch identifier ascending and batches
//   lacking an expiry date ordered after all dated batches; the auto-selected
//   batch (after the POS defensive inline sort) is the earliest-expiry batch in
//   that order.
//
// HOW THIS IS PROVEN AS A PROPERTY:
//   The production FEFO ordering lives in `PharmacyDao.getBatchesForProduct`
//   (SQL ordering, task 14.1) and is re-asserted by the POS defensive inline
//   sort `BillCreationScreenV2._fefoSorted` (task 14.2). Because `_fefoSorted`
//   is private, this test exercises the real DAO ordering against a real
//   in-memory Drift database AND compares it, batch-for-batch, to an INDEPENDENT
//   PURE ORACLE that re-implements the documented spec rule directly:
//
//       keep qty > 0; sort by expiry ascending; ties by batch id ascending;
//       null-expiry batches after all dated batches.
//
//   The oracle also stands in for the POS defensive resort: applying it to the
//   DAO result (a second, independent sort) must leave the earliest-expiry
//   batch first, proving the auto-selected batch (`batches.first`) is the
//   earliest-expiry batch (R17.4–R17.5). Generators deliberately cover null
//   expiry (null-last path), duplicate expiry dates (tie-break path), and zero
//   quantity (the qty>0 filter), and randomise batch ids independently of
//   insertion order so the id tie-break is genuinely exercised.
//
// PBT library: dartproptest ^0.2.1 — the repo-standard QuickCheck/Hypothesis-
//   inspired library. Each run drives a real in-memory Drift database (async
//   inserts + async queries), so this uses `forAllAsync`. numRuns: 200 far
//   exceeds the 100-case minimum (R5.4).
//
// Setup mirrors the batched-FEFO property test (task 14.4) and the example test
//   (task 14.5): `AppDatabase.forTesting(NativeDatabase.memory())` with
//   ProductsCompanion / ProductBatchesCompanion insert helpers.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/pharmacy/fefo_ordering_property20_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/database/daos/pharmacy_dao.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4). 200 stays well
/// above the minimum while keeping the DB-backed property suite responsive.
const int kNumRuns = 200;

const String _userId = 'tenant_A';

/// Positive quantities used when a batch is "in stock". The decode below also
/// produces qty 0 (the excluded, must-not-be-returned case for R17.1).
const List<double> _positiveQtys = <double>[5.0, 10.0, 25.0];

/// A decoded batch description used by the independent oracle.
class _ExpectedBatch {
  const _ExpectedBatch(this.id, this.expiry, this.qty);
  final String id;
  final DateTime? expiry;
  final double qty;
}

/// Independent oracle: re-implements the Property 20 rule directly.
///
/// Keeps only qty > 0 (R17.1), then sorts by expiry ascending (R17.2) with ties
/// broken by batch id ascending (R17.3) and null-expiry batches ordered after
/// all dated batches. The comparator fully resolves ties via id, so the result
/// is deterministic regardless of the (unstable) underlying sort.
List<_ExpectedBatch> _oracleFefo(List<_ExpectedBatch> batches) {
  final kept = batches.where((b) => b.qty > 0.0).toList();
  kept.sort((a, b) {
    final aExp = a.expiry;
    final bExp = b.expiry;
    if (aExp == null && bExp == null) return a.id.compareTo(b.id);
    if (aExp == null) return 1; // null expiry sorts last
    if (bExp == null) return -1;
    final cmp = aExp.compareTo(bExp);
    return cmp != 0 ? cmp : a.id.compareTo(b.id);
  });
  return kept;
}

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 20: FEFO ordering and '
      'selection — Req 17.1, 17.2, 17.3, 17.4, 17.5', () {
    // --- Generator ---------------------------------------------------------
    // A list of opaque batch "descriptor" integers. Each integer is decoded
    // (below) into (expiry, quantity, idLabel). 0..20 batches covers the
    // no-batch, single-batch and many-batch cases.
    final Generator<List<int>> batchCodesGen = Gen.array<int>(
      Gen.interval(0, 1 << 20),
      minLength: 0,
      maxLength: 20,
    );

    test('Property 20: getBatchesForProduct returns only qty>0 batches in FEFO '
        'order (expiry asc, id tie-break, null-last) and the auto-selected batch '
        'is the earliest-expiry one', () async {
      final bool held = await forAllAsync(
        (List<int> batchCodes) async {
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          final dao = PharmacyDao(db);
          try {
            await db
                .into(db.products)
                .insert(
                  ProductsCompanion.insert(
                    id: 'p1',
                    userId: _userId,
                    name: 'Product p1',
                    sellingPrice: 100.0,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );

            // Decode each descriptor into a concrete batch and insert it.
            // Batch ids embed a RANDOM label (independent of insertion order)
            // so the id tie-break path is genuinely exercised, suffixed with
            // the index to guarantee uniqueness.
            final expected = <_ExpectedBatch>[];
            for (var i = 0; i < batchCodes.length; i++) {
              final int code = batchCodes[i];

              // expiryCode: 0 => null expiry; 1..8 => DateTime(2025,1,n).
              // The small day range forces frequent equal-expiry ties.
              final int expiryCode = (code ~/ 7) % 9;
              final DateTime? expiry = expiryCode == 0
                  ? null
                  : DateTime(2025, 1, expiryCode);

              // qtyCode 0 => zero quantity (must be filtered out, R17.1).
              final int qtyCode = (code ~/ 131) % 4;
              final double qty = qtyCode == 0
                  ? 0.0
                  : _positiveQtys[(qtyCode - 1) % _positiveQtys.length];

              // Random id label (0..999) decoupled from insertion order.
              final int label = code % 1000;
              final String id =
                  'b${label.toString().padLeft(3, '0')}_${i.toString().padLeft(3, '0')}';

              expected.add(_ExpectedBatch(id, expiry, qty));

              await db
                  .into(db.productBatches)
                  .insert(
                    ProductBatchesCompanion.insert(
                      id: id,
                      productId: 'p1',
                      userId: _userId,
                      batchNumber: 'BN$i',
                      expiryDate: Value(expiry),
                      stockQuantity: Value(qty),
                      // Property 20 scope is the qty>0 filter + ordering, so
                      // all generated batches are ACTIVE.
                      status: const Value('ACTIVE'),
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
            }

            final actual = await dao.getBatchesForProduct(_userId, 'p1');
            final actualIds = actual.map((b) => b.id).toList();
            final oracle = _oracleFefo(expected);
            final oracleIds = oracle.map((b) => b.id).toList();

            // R17.1–R17.3: returned list equals the oracle exactly (same
            // members in the same FEFO order; zero-qty batches excluded).
            if (actualIds.length != oracleIds.length) return false;
            for (var k = 0; k < actualIds.length; k++) {
              if (actualIds[k] != oracleIds[k]) return false;
            }

            // R17.1: no returned batch has qty <= 0.
            for (final b in actual) {
              if (b.stockQuantity <= 0.0) return false;
            }

            // R17.4–R17.5: the POS defensive inline resort over the DAO
            // result still selects the earliest-expiry batch. Re-applying the
            // independent oracle to the DAO result (a second, independent
            // sort) must leave the same first element as the global oracle.
            if (oracle.isNotEmpty) {
              final resorted = _oracleFefo(
                actual
                    .map(
                      (b) =>
                          _ExpectedBatch(b.id, b.expiryDate, b.stockQuantity),
                    )
                    .toList(),
              );
              if (resorted.first.id != oracle.first.id) return false;
              if (actualIds.first != oracle.first.id) return false;
            }

            return true;
          } finally {
            await db.close();
          }
        },
        [batchCodesGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'getBatchesForProduct must return only qty>0 batches ordered by '
            'expiry asc, ties by id asc, null-expiry last (R17.1–R17.3), and '
            'the auto-selected batch must be the earliest-expiry one '
            '(R17.4–R17.5).',
      );
    });

    // Deterministic anchor — proves the property is non-vacuous: a product with
    // equal-expiry ties (id tie-break), a null-expiry batch (last), and a
    // zero-quantity batch (excluded) yields the exact documented FEFO order,
    // and the first element is the earliest-expiry batch to auto-select.
    test(
      'Property 20 anchor: ties break by id ascending, null-expiry sorts '
      'last, zero-quantity is excluded, and the first batch is selected',
      () async {
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

          Future<void> batch(String id, DateTime? expiry, {double qty = 10.0}) {
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
                    status: const Value('ACTIVE'),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );
          }

          // Insert deliberately out of FEFO order to prove the ordering is
          // applied, not incidental to insertion order.
          await batch('b_null', null); // null-expiry => must sort last
          await batch('b_tie_2', DateTime(2025, 1, 10)); // tie, id 2
          await batch('b_early', DateTime(2025, 1, 5)); // earliest => selected
          await batch('b_tie_1', DateTime(2025, 1, 10)); // tie, id 1 (before 2)
          await batch('b_zero', DateTime(2025, 1, 1), qty: 0.0); // excluded

          final result = await dao.getBatchesForProduct(_userId, 'p1');
          final ids = result.map((b) => b.id).toList();

          expect(ids, ['b_early', 'b_tie_1', 'b_tie_2', 'b_null']);
          // R17.5: auto-selected batch is the earliest-expiry batch.
          expect(ids.first, 'b_early');
          // R17.1: the zero-quantity batch is never returned.
          expect(ids, isNot(contains('b_zero')));
        } finally {
          await db.close();
        }
      },
    );
  });
}
