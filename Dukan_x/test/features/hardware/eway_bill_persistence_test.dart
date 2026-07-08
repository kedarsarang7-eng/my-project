// Unit test for HARDWARE-003: E-Way Bill Part-A persistence.
//
// Bug Condition: The `_generate()` method in `eway_bill_screen.dart` only
// produced an in-memory reference string and showed a SnackBar — it did NOT
// persist the Part-A record to a local table or queue it for sync.
//
// This test verifies that after calling persistEWayBillRecord with valid
// above-threshold consignment data, an EWayBill record is persisted to the
// local Drift database and a sync queue entry is created.
//
// Expected: FAILS on unfixed code (persistEWayBillRecord didn't exist).
// After fix: PASSES (record persisted + sync enqueued).
//
// Validates: Requirements 1.3, 2.3

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/features/hardware/presentation/screens/eway_bill_screen.dart';

/// Spy SyncManager that records enqueued items without real sync.
class _SpySyncManager extends Fake implements SyncManager {
  final List<SyncQueueItem> enqueued = [];

  @override
  Future<String> enqueue(SyncQueueItem item) async {
    enqueued.add(item);
    return 'spy-op-${enqueued.length}';
  }
}

void main() {
  late AppDatabase db;
  late _SpySyncManager spySync;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    spySync = _SpySyncManager();
  });

  tearDown(() async {
    await db.close();
  });

  group('E-Way Bill Part-A Persistence (HARDWARE-003)', () {
    test('isEWayBillRequired returns true for value >= 50000', () {
      // Preservation: threshold logic unchanged.
      expect(isEWayBillRequired(50000), isTrue);
      expect(isEWayBillRequired(75000), isTrue);
      expect(isEWayBillRequired(49999), isFalse);
    });

    test('persistEWayBillRecord exists as a callable function', () {
      // On unfixed code this symbol did not exist at all.
      expect(persistEWayBillRecord, isA<Function>());
    });

    test(
      'persistEWayBillRecord persists record to EWayBills table and returns ID',
      () async {
        final result = await persistEWayBillRecord(
          consignmentValueRupees: 60000,
          recipientGstin: '27ABCDE1234F1Z5',
          fromPlace: 'Mumbai',
          toPlace: 'Pune',
          transporterName: 'ABC Transport',
          vehicleNo: 'MH12AB1234',
          deliveryChallanId: 'challan-001',
          userId: 'test-user-001',
          db: db,
          syncManager: spySync,
        );

        // Must return a non-empty ID.
        expect(result, isNotNull);
        expect(result, isA<String>());
        expect(result!.isNotEmpty, isTrue);

        // Verify the record exists in the local database.
        final records = await (db.select(
          db.eWayBills,
        )..where((t) => t.id.equals(result))).get();
        expect(records, hasLength(1));
        expect(records.first.userId, equals('test-user-001'));
        expect(records.first.billId, equals('challan-001'));
        expect(records.first.fromPlace, equals('Mumbai'));
        expect(records.first.toPlace, equals('Pune'));
      },
    );

    test('persistEWayBillRecord enqueues a sync operation', () async {
      await persistEWayBillRecord(
        consignmentValueRupees: 100000,
        recipientGstin: '29XYZAB5678C1Z3',
        fromPlace: 'Bangalore',
        toPlace: 'Chennai',
        transporterName: 'XYZ Logistics',
        vehicleNo: 'KA01CD5678',
        deliveryChallanId: 'challan-002',
        userId: 'user-002',
        db: db,
        syncManager: spySync,
      );

      // Verify a sync queue item was enqueued.
      expect(spySync.enqueued, hasLength(1));
      final item = spySync.enqueued.first;
      expect(item.targetCollection, equals('eway_bills'));
      expect(item.operationType, equals(SyncOperationType.create));
      expect(item.userId, equals('user-002'));
      expect(item.payload['fromPlace'], equals('Bangalore'));
      expect(item.payload['toPlace'], equals('Chennai'));
      expect(item.payload['consignmentValueRupees'], equals(100000));
    });

    test('persistEWayBillRecord returns null when below threshold', () async {
      final result = await persistEWayBillRecord(
        consignmentValueRupees: 30000,
        recipientGstin: '27ABCDE1234F1Z5',
        fromPlace: 'Mumbai',
        toPlace: 'Pune',
        transporterName: 'ABC Transport',
        vehicleNo: 'MH12AB1234',
        deliveryChallanId: 'challan-003',
        userId: 'test-user-001',
        db: db,
        syncManager: spySync,
      );

      // Below threshold — no record persisted, no sync enqueued.
      expect(result, isNull);
      expect(spySync.enqueued, isEmpty);
    });

    test(
      'persistEWayBillRecord links to delivery challan eWayBillNumber',
      () async {
        // Insert a challan to link against.
        await db
            .into(db.deliveryChallans)
            .insert(
              DeliveryChallansCompanion.insert(
                id: 'challan-link-test',
                userId: 'test-user-001',
                challanNumber: 'DC-001',
                challanDate: DateTime.now(),
                itemsJson: '[]',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

        await persistEWayBillRecord(
          consignmentValueRupees: 75000,
          fromPlace: 'Delhi',
          toPlace: 'Jaipur',
          deliveryChallanId: 'challan-link-test',
          userId: 'test-user-001',
          db: db,
          syncManager: spySync,
        );

        // Verify the delivery challan's eWayBillNumber was updated.
        final challan = await (db.select(
          db.deliveryChallans,
        )..where((t) => t.id.equals('challan-link-test'))).getSingle();
        expect(challan.eWayBillNumber, isNotNull);
        expect(challan.eWayBillNumber!.startsWith('EWB-'), isTrue);
      },
    );
  });
}
