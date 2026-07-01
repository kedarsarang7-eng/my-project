// ============================================================================
// DATA ARCHIVAL SERVICE TESTS — two-year Local_Store archival partition
// ============================================================================
// Feature: offline-license-activation (Task 19.1)
//
// Verifies the Data_Archival_Service against Requirement 16:
//   16.1  Records older than 2 years (by created_at) are MOVED into the archive
//         store while the remaining (recent) records stay live, and the live
//         data set stays correct and complete.
//   16.2  Indexes are maintained on the high-frequency query columns
//         (created_at, tenant_id) on both the live and the archive tables.
//
// These are example-based unit tests over a real in-memory AppDatabase (the
// same `AppDatabase.forTesting(NativeDatabase.memory())` pattern used across
// the suite). The dedicated property test for Property 33 is task 19.3 and is
// intentionally out of scope here.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/mode/data_archival_service.dart';

void main() {
  late AppDatabase db;
  late DataArchivalService service;
  const userId = 'user_archival';

  // A fixed "now" so the two-year boundary is deterministic.
  final now = DateTime(2024, 6, 15, 10, 30);
  // Strictly older than two years -> must be archived.
  final old = DateTime(2021, 1, 1);
  // Within two years -> must stay live.
  final recent = DateTime(2023, 12, 31);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = DataArchivalService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertBill(String id, DateTime createdAt) {
    return db.insertBill(
      BillsCompanion.insert(
        id: id,
        userId: userId,
        invoiceNumber: 'INV-$id',
        billDate: createdAt,
        itemsJson: '[]',
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
  }

  Future<void> insertPayment(String id, DateTime createdAt) {
    return db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            id: id,
            userId: userId,
            billId: 'bill_for_$id',
            customerId: const Value('cust_1'),
            amount: 100.0,
            paymentMode: 'cash',
            paymentDate: createdAt,
            createdAt: createdAt,
          ),
        );
  }

  Future<void> insertBillItem(String id, String billId, DateTime createdAt) {
    return db
        .into(db.billItems)
        .insert(
          BillItemsCompanion.insert(
            id: id,
            billId: billId,
            productName: 'Item $id',
            quantity: 1,
            unitPrice: 10,
            totalAmount: 10,
            createdAt: createdAt,
          ),
        );
  }

  Future<int> countLive(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM "$table"')
        .getSingle();
    return row.read<int>('c');
  }

  Future<int> countArchive(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM "archive_$table"')
        .getSingle();
    return row.read<int>('c');
  }

  Future<bool> indexExists(String name) async {
    final row = await db
        .customSelect(
          "SELECT 1 AS present FROM sqlite_master "
          "WHERE type = 'index' AND name = ?",
          variables: [Variable<String>(name)],
        )
        .getSingleOrNull();
    return row != null;
  }

  group('archiveCutoff (pure)', () {
    test('computes the two-year-ago boundary on the calendar', () {
      final cutoff = service.archiveCutoff(now);
      expect(cutoff, DateTime(2022, 6, 15, 10, 30));
    });
  });

  group('runArchival — Requirement 16.1 (partition)', () {
    test(
      'moves records older than two years and keeps the remainder live',
      () async {
        await insertBill('old1', old);
        await insertBill('old2', old);
        await insertBill('recent1', recent);

        final result = await service.runArchival(now: now);

        expect(result, isA<ArchivalCompleted>());
        result as ArchivalCompleted;

        // Live store has exactly the recent record.
        expect(await countLive('bills'), 1);
        // Archive store has exactly the two old records.
        expect(await countArchive('bills'), 2);

        // The surviving live row is the recent one (data stays correct).
        final live = await db
            .customSelect('SELECT id FROM bills')
            .map((r) => r.read<String>('id'))
            .get();
        expect(live, ['recent1']);
      },
    );

    test('is a no-op when nothing is older than two years', () async {
      await insertBill('recent1', recent);
      await insertPayment('pay_recent', recent);

      final result = await service.runArchival(now: now) as ArchivalCompleted;

      expect(result.totalArchived, 0);
      expect(await countLive('bills'), 1);
      expect(await countArchive('bills'), 0);
    });

    test('partitions multiple tables in one run', () async {
      await insertBill('old_bill', old);
      await insertBill('recent_bill', recent);
      await insertPayment('old_pay', old);
      await insertPayment('recent_pay', recent);

      final result = await service.runArchival(now: now) as ArchivalCompleted;

      expect(result.totalArchived, 2);
      expect(await countLive('bills'), 1);
      expect(await countLive('payments'), 1);
      expect(await countArchive('bills'), 1);
      expect(await countArchive('payments'), 1);
    });

    test('archives a cascade child together with its old parent so the live '
        'store stays referentially complete', () async {
      // Old parent bill with an old child line item.
      await insertBill('old_bill', old);
      await insertBillItem('old_item', 'old_bill', old);
      // Recent parent bill with a recent child.
      await insertBill('recent_bill', recent);
      await insertBillItem('recent_item', 'recent_bill', recent);

      await service.runArchival(now: now);

      // Both old parent and old child moved; recent pair stays live.
      expect(await countLive('bills'), 1);
      expect(await countLive('bill_items'), 1);
      expect(await countArchive('bills'), 1);
      expect(await countArchive('bill_items'), 1);

      final liveItems = await db
          .customSelect('SELECT id FROM bill_items')
          .map((r) => r.read<String>('id'))
          .get();
      expect(liveItems, ['recent_item']);

      // No orphaned live child references a missing live parent.
      final orphans = await db
          .customSelect(
            'SELECT COUNT(*) AS c FROM bill_items bi '
            'LEFT JOIN bills b ON bi.bill_id = b.id WHERE b.id IS NULL',
          )
          .getSingle();
      expect(orphans.read<int>('c'), 0);
    });

    test('boundary: a record exactly at the cutoff stays live', () async {
      final cutoff = service.archiveCutoff(now);
      await insertBill('at_cutoff', cutoff);

      await service.runArchival(now: now);

      // Predicate is strictly-older-than, so the boundary row remains live.
      expect(await countLive('bills'), 1);
      expect(await countArchive('bills'), 0);
    });

    test('is idempotent across repeated runs', () async {
      await insertBill('old1', old);
      await insertBill('recent1', recent);

      await service.runArchival(now: now);
      final second = await service.runArchival(now: now) as ArchivalCompleted;

      // Second run finds nothing new to move; totals are stable.
      expect(second.totalArchived, 0);
      expect(await countLive('bills'), 1);
      expect(await countArchive('bills'), 1);
    });
  });

  group('ensureIndexes — Requirement 16.2 (index maintenance)', () {
    test(
      'creates created_at and tenant_id indexes on live and archive tables',
      () async {
        await service.ensureIndexes();

        // Live table indexes.
        expect(await indexExists('idx_bills_created_at'), isTrue);
        expect(await indexExists('idx_bills_tenant_id'), isTrue);
        // Archive table indexes.
        expect(await indexExists('idx_archive_bills_created_at'), isTrue);
        expect(await indexExists('idx_archive_bills_tenant_id'), isTrue);
      },
    );

    test('runArchival maintains the high-frequency indexes', () async {
      await insertBill('old1', old);
      await service.runArchival(now: now);

      expect(await indexExists('idx_archive_bills_created_at'), isTrue);
      expect(await indexExists('idx_archive_bills_tenant_id'), isTrue);
    });
  });
}
