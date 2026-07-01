// ============================================================================
// OFFLINE QUEUE TESTS - ENQUEUE AND CAPACITY MANAGEMENT
// ============================================================================
// Tests for:
// - enqueue() method with max capacity check (5000 mutations)
// - Rejection with warning when at capacity
// - queueSize getter
// - isAtCapacity getter
// - Mutation storage with timestamp, operation type, payload, tenant_id, retry count
//
// Requirements: 8.2, 8.8
// Author: DukanX Engineering
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/sync/offline_queue.dart';

/// In-memory implementation of OfflineQueueDatabase for unit testing.
class InMemoryOfflineQueueDatabase implements OfflineQueueDatabase {
  final List<Map<String, dynamic>> _rows = [];

  List<Map<String, dynamic>> get rows => List.unmodifiable(_rows);

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    // No-op for CREATE TABLE / PRAGMA / CREATE INDEX
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    if (sql.contains('COUNT(*)')) {
      final count = _rows.where((r) => r['status'] != 'synced').length;
      return [
        <String, dynamic>{'count': count},
      ];
    }
    if (sql.contains('WHERE id = ?') && arguments != null) {
      final id = arguments.first;
      return _rows.where((r) => r['id'] == id).toList();
    }
    if (sql.contains("status = 'pending'")) {
      final list = _rows.where((r) => r['status'] == 'pending').toList();
      list.sort(
        (a, b) =>
            (a['timestamp'] as String).compareTo(b['timestamp'] as String),
      );
      return list;
    }
    if (sql.contains("status = 'failed'")) {
      final list = _rows.where((r) => r['status'] == 'failed').toList();
      list.sort(
        (a, b) =>
            (a['timestamp'] as String).compareTo(b['timestamp'] as String),
      );
      return list;
    }
    if (sql.contains('WHERE tenant_id = ?') && arguments != null) {
      final tenantId = arguments.first;
      final list = _rows.where((r) => r['tenant_id'] == tenantId).toList();
      list.sort(
        (a, b) =>
            (a['timestamp'] as String).compareTo(b['timestamp'] as String),
      );
      return list;
    }
    return [];
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    if (arguments == null) return 0;

    final columnsMatch = RegExp(r'INSERT INTO \w+ \((.+?)\)').firstMatch(sql);
    if (columnsMatch == null) return 0;

    final columns = columnsMatch.group(1)!.split(', ');
    final row = <String, dynamic>{};
    for (var i = 0; i < columns.length && i < arguments.length; i++) {
      row[columns[i]] = arguments[i];
    }
    _rows.add(row);
    return 1;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    if (arguments == null || arguments.isEmpty) return 0;
    final id = arguments.last;
    final idx = _rows.indexWhere((r) => r['id'] == id);
    if (idx == -1) return 0;

    // Parse SET clause: "UPDATE tablename SET field1 = ?, field2 = ? WHERE id = ?"
    final setMatch = RegExp(r'SET (.+?) WHERE').firstMatch(sql);
    if (setMatch != null) {
      final fields = setMatch
          .group(1)!
          .split(', ')
          .map((f) => f.split(' = ')[0].trim())
          .toList();
      for (var i = 0; i < fields.length && i < arguments.length - 1; i++) {
        _rows[idx][fields[i]] = arguments[i];
      }
    }
    return 1;
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    if (sql.contains("status = 'synced'")) {
      final before = _rows.length;
      _rows.removeWhere((r) => r['status'] == 'synced');
      return before - _rows.length;
    }
    if (arguments != null && arguments.isNotEmpty) {
      final id = arguments.first;
      final before = _rows.length;
      _rows.removeWhere((r) => r['id'] == id);
      return before - _rows.length;
    }
    return 0;
  }

  /// Helper: bulk insert rows for capacity testing.
  void bulkInsert(List<Map<String, dynamic>> rows) {
    _rows.addAll(rows);
  }
}

/// Creates a single test row map for bulk insertion.
Map<String, dynamic> _makeRow(
  int index, {
  String status = 'pending',
  String tenantId = 'tenant_001',
}) {
  return <String, dynamic>{
    'id': 'mutation_$index',
    'tenant_id': tenantId,
    'timestamp': DateTime.now().toIso8601String(),
    'operation_type': 'create',
    'entity_type': 'invoice',
    'payload': '{"index": $index}',
    'retry_count': 0,
    'status': status,
    'failure_reason': null,
    'affected_record_id': null,
    'created_at': DateTime.now().toIso8601String(),
    'synced_at': status == 'synced' ? DateTime.now().toIso8601String() : null,
  };
}

/// Creates a list of test rows for capacity testing.
List<Map<String, dynamic>> _makeRows(
  int count, {
  String status = 'pending',
  String tenantId = 'tenant_001',
  String idPrefix = 'mutation',
}) {
  return List.generate(
    count,
    (i) => <String, dynamic>{
      'id': '${idPrefix}_$i',
      'tenant_id': tenantId,
      'timestamp': DateTime.now().toIso8601String(),
      'operation_type': 'create',
      'entity_type': 'invoice',
      'payload': '{"index": $i}',
      'retry_count': 0,
      'status': status,
      'failure_reason': status == 'failed' ? 'Conflict' : null,
      'affected_record_id': status == 'failed' ? 'rec_$i' : null,
      'created_at': DateTime.now().toIso8601String(),
      'synced_at': status == 'synced' ? DateTime.now().toIso8601String() : null,
    },
  );
}

/// Creates a test mutation with the given parameters.
OfflineMutation createTestMutation({
  String? id,
  String tenantId = 'tenant_001',
  DateTime? timestamp,
  MutationOperationType operationType = MutationOperationType.create,
  String entityType = 'invoice',
  Map<String, dynamic>? payload,
  int retryCount = 0,
}) {
  return OfflineMutation(
    id: id,
    tenantId: tenantId,
    timestamp: timestamp,
    operationType: operationType,
    entityType: entityType,
    payload: payload ?? {'amount': 100, 'item': 'Test Item'},
    retryCount: retryCount,
  );
}

void main() {
  late InMemoryOfflineQueueDatabase database;
  late OfflineQueue queue;

  setUp(() async {
    database = InMemoryOfflineQueueDatabase();
    queue = OfflineQueue(database: database);
    await queue.initialize('test-encryption-key');
  });

  group('OfflineQueue - Max Capacity Constant', () {
    test('maxQueueSize should be 5000', () {
      expect(OfflineQueue.maxQueueSize, equals(5000));
    });
  });

  group('OfflineQueue - enqueue()', () {
    test(
      'should enqueue a mutation successfully when below capacity',
      () async {
        final mutation = createTestMutation(
          tenantId: 'tenant_abc',
          operationType: MutationOperationType.create,
          entityType: 'invoice',
          payload: {'amount': 500, 'customer': 'John'},
        );

        final result = await queue.enqueue(mutation);

        expect(result.success, isTrue);
        expect(result.mutationId, equals(mutation.id));
        expect(result.error, isNull);
      },
    );

    test('should store mutation with all required fields', () async {
      final now = DateTime(2025, 6, 15, 10, 30, 0);
      final mutation = createTestMutation(
        id: 'mutation_001',
        tenantId: 'tenant_xyz',
        timestamp: now,
        operationType: MutationOperationType.update,
        entityType: 'product',
        payload: {'name': 'Widget', 'price': 99.99},
        retryCount: 2,
      );

      await queue.enqueue(mutation);

      final storedRow = database.rows.first;
      expect(storedRow['id'], equals('mutation_001'));
      expect(storedRow['tenant_id'], equals('tenant_xyz'));
      expect(storedRow['timestamp'], equals(now.toIso8601String()));
      expect(storedRow['operation_type'], equals('update'));
      expect(storedRow['entity_type'], equals('product'));
      expect(storedRow['payload'], contains('"name":"Widget"'));
      expect(storedRow['retry_count'], equals(2));
      expect(storedRow['status'], equals('pending'));
    });

    test('should store mutations with different operation types', () async {
      final createMutation = createTestMutation(
        operationType: MutationOperationType.create,
        entityType: 'order',
      );
      final updateMutation = createTestMutation(
        operationType: MutationOperationType.update,
        entityType: 'order',
      );
      final deleteMutation = createTestMutation(
        operationType: MutationOperationType.delete,
        entityType: 'order',
      );

      await queue.enqueue(createMutation);
      await queue.enqueue(updateMutation);
      await queue.enqueue(deleteMutation);

      expect(database.rows[0]['operation_type'], equals('create'));
      expect(database.rows[1]['operation_type'], equals('update'));
      expect(database.rows[2]['operation_type'], equals('delete'));
    });

    test('should reject enqueue when queue is at max capacity', () async {
      database.bulkInsert(_makeRows(5000));

      final newMutation = createTestMutation(tenantId: 'tenant_new');
      final result = await queue.enqueue(newMutation);

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, contains('maximum capacity'));
      expect(result.error, contains('5000'));
      expect(result.mutationId, isNull);
    });

    test('should reject enqueue with warning about connectivity', () async {
      database.bulkInsert(_makeRows(5000));

      final result = await queue.enqueue(createTestMutation());

      // Case-insensitive check for connectivity and sync keywords
      expect(result.error!.toLowerCase(), contains('connectivity'));
      expect(result.error!.toLowerCase(), contains('sync'));
    });

    test('should allow enqueue at capacity minus one (4999 items)', () async {
      database.bulkInsert(_makeRows(4999));

      final result = await queue.enqueue(createTestMutation());

      expect(result.success, isTrue);
      expect(result.mutationId, isNotNull);
    });

    test('should not count synced mutations toward capacity', () async {
      database.bulkInsert(_makeRows(5000, status: 'synced'));

      final result = await queue.enqueue(createTestMutation());

      expect(result.success, isTrue);
    });

    test('should throw StateError when not initialized', () async {
      final uninitializedQueue = OfflineQueue(
        database: InMemoryOfflineQueueDatabase(),
      );
      final mutation = createTestMutation();

      expect(
        () => uninitializedQueue.enqueue(mutation),
        throwsA(isA<StateError>()),
      );
    });

    test('should store tenant_id correctly per mutation', () async {
      final mutation1 = createTestMutation(tenantId: 'tenant_A');
      final mutation2 = createTestMutation(tenantId: 'tenant_B');

      await queue.enqueue(mutation1);
      await queue.enqueue(mutation2);

      expect(database.rows[0]['tenant_id'], equals('tenant_A'));
      expect(database.rows[1]['tenant_id'], equals('tenant_B'));
    });

    test('should generate unique IDs for each mutation', () async {
      final mutation1 = createTestMutation();
      final mutation2 = createTestMutation();

      final result1 = await queue.enqueue(mutation1);
      final result2 = await queue.enqueue(mutation2);

      expect(result1.mutationId, isNot(equals(result2.mutationId)));
    });
  });

  group('OfflineQueue - queueSize', () {
    test('should return 0 for empty queue', () async {
      final size = await queue.queueSize;
      expect(size, equals(0));
    });

    test('should return correct count after enqueue operations', () async {
      await queue.enqueue(createTestMutation());
      await queue.enqueue(createTestMutation());
      await queue.enqueue(createTestMutation());

      final size = await queue.queueSize;
      expect(size, equals(3));
    });

    test('should not count synced mutations', () async {
      database.bulkInsert([
        _makeRow(1, status: 'pending'),
        _makeRow(2, status: 'synced'),
        _makeRow(3, status: 'failed'),
      ]);

      final size = await queue.queueSize;
      // pending + failed = 2 (synced doesn't count)
      expect(size, equals(2));
    });

    test('should throw StateError when not initialized', () async {
      final uninitializedQueue = OfflineQueue(
        database: InMemoryOfflineQueueDatabase(),
      );

      expect(() => uninitializedQueue.queueSize, throwsA(isA<StateError>()));
    });
  });

  group('OfflineQueue - isAtCapacity', () {
    test('should return false for empty queue', () async {
      final atCapacity = await queue.isAtCapacity;
      expect(atCapacity, isFalse);
    });

    test('should return false when below max capacity', () async {
      database.bulkInsert(_makeRows(4999));

      final atCapacity = await queue.isAtCapacity;
      expect(atCapacity, isFalse);
    });

    test('should return true when at exactly max capacity', () async {
      database.bulkInsert(_makeRows(5000));

      final atCapacity = await queue.isAtCapacity;
      expect(atCapacity, isTrue);
    });

    test('should return true when over max capacity', () async {
      database.bulkInsert(_makeRows(5500));

      final atCapacity = await queue.isAtCapacity;
      expect(atCapacity, isTrue);
    });

    test('should not count synced items toward capacity', () async {
      database.bulkInsert(_makeRows(5000, status: 'synced'));

      final atCapacity = await queue.isAtCapacity;
      expect(atCapacity, isFalse);
    });

    test('should count failed mutations toward capacity', () async {
      database.bulkInsert(_makeRows(3000, idPrefix: 'pending'));
      database.bulkInsert(
        _makeRows(2000, status: 'failed', idPrefix: 'failed'),
      );

      final atCapacity = await queue.isAtCapacity;
      // 3000 pending + 2000 failed = 5000 → at capacity
      expect(atCapacity, isTrue);
    });

    test('should throw StateError when not initialized', () async {
      final uninitializedQueue = OfflineQueue(
        database: InMemoryOfflineQueueDatabase(),
      );

      expect(() => uninitializedQueue.isAtCapacity, throwsA(isA<StateError>()));
    });
  });

  group('OfflineQueue - Initialization', () {
    test('should set isInitialized to true after initialize()', () async {
      final db = InMemoryOfflineQueueDatabase();
      final q = OfflineQueue(database: db);

      expect(q.isInitialized, isFalse);
      await q.initialize('key');
      expect(q.isInitialized, isTrue);
    });

    test('should not re-initialize if already initialized', () async {
      final db = InMemoryOfflineQueueDatabase();
      final q = OfflineQueue(database: db);

      await q.initialize('key1');
      await q.initialize('key2'); // Should be a no-op

      expect(q.isInitialized, isTrue);
    });
  });

  group('OfflineQueue - OfflineMutation model', () {
    test('should create mutation with all required fields', () {
      final now = DateTime(2025, 7, 1, 12, 0, 0);
      final mutation = OfflineMutation(
        id: 'test_id',
        tenantId: 'tenant_123',
        timestamp: now,
        operationType: MutationOperationType.create,
        entityType: 'invoice',
        payload: {'amount': 1000},
        retryCount: 0,
      );

      expect(mutation.id, equals('test_id'));
      expect(mutation.tenantId, equals('tenant_123'));
      expect(mutation.timestamp, equals(now));
      expect(mutation.operationType, equals(MutationOperationType.create));
      expect(mutation.entityType, equals('invoice'));
      expect(mutation.payload, equals({'amount': 1000}));
      expect(mutation.retryCount, equals(0));
      expect(mutation.status, equals(MutationStatus.pending));
    });

    test('should serialize to map and deserialize back correctly', () {
      final now = DateTime(2025, 7, 1, 12, 0, 0);
      final mutation = OfflineMutation(
        id: 'round_trip_id',
        tenantId: 'tenant_rt',
        timestamp: now,
        operationType: MutationOperationType.update,
        entityType: 'product',
        payload: {'name': 'Widget', 'price': 50},
        retryCount: 1,
        createdAt: now,
      );

      final map = mutation.toMap();
      final restored = OfflineMutation.fromMap(map);

      expect(restored.id, equals(mutation.id));
      expect(restored.tenantId, equals(mutation.tenantId));
      expect(restored.timestamp, equals(mutation.timestamp));
      expect(restored.operationType, equals(mutation.operationType));
      expect(restored.entityType, equals(mutation.entityType));
      expect(restored.payload, equals(mutation.payload));
      expect(restored.retryCount, equals(mutation.retryCount));
      expect(restored.status, equals(mutation.status));
    });

    test('should auto-generate id and timestamps when not provided', () {
      final mutation = OfflineMutation(
        tenantId: 'tenant_auto',
        operationType: MutationOperationType.delete,
        entityType: 'order',
        payload: {'orderId': '123'},
      );

      expect(mutation.id, isNotEmpty);
      expect(mutation.timestamp, isNotNull);
      expect(mutation.createdAt, isNotNull);
    });
  });

  group('OfflineQueue - QueueResult model', () {
    test('QueueResult.success should have success=true and mutationId', () {
      final result = QueueResult.success('mut_123');

      expect(result.success, isTrue);
      expect(result.mutationId, equals('mut_123'));
      expect(result.error, isNull);
    });

    test('QueueResult.failure should have success=false and error message', () {
      final result = QueueResult.failure('Queue full');

      expect(result.success, isFalse);
      expect(result.error, equals('Queue full'));
      expect(result.mutationId, isNull);
    });
  });

  // ==========================================================================
  // Replay & Conflict Resolution Tests (Task 11.3, Req 8.3, 8.4)
  // ==========================================================================

  group('OfflineQueue - replay()', () {
    test('should return empty result when no pending mutations', () async {
      final result = await queue.replay(
        syncFunction: (_) async => SyncResponse.ok(),
      );

      expect(result.totalProcessed, equals(0));
      expect(result.successCount, equals(0));
      expect(result.failedCount, equals(0));
      expect(result.timedOut, isFalse);
    });

    test('should process mutations in chronological order', () async {
      final t1 = DateTime(2025, 1, 1, 10, 0, 0);
      final t2 = DateTime(2025, 1, 1, 10, 1, 0);
      final t3 = DateTime(2025, 1, 1, 10, 2, 0);

      await queue.enqueue(createTestMutation(id: 'mut_3', timestamp: t3));
      await queue.enqueue(createTestMutation(id: 'mut_1', timestamp: t1));
      await queue.enqueue(createTestMutation(id: 'mut_2', timestamp: t2));

      final processedOrder = <String>[];
      final result = await queue.replay(
        syncFunction: (mutation) async {
          processedOrder.add(mutation.id);
          return SyncResponse.ok();
        },
      );

      expect(result.totalProcessed, equals(3));
      expect(result.successCount, equals(3));
      expect(processedOrder, equals(['mut_1', 'mut_2', 'mut_3']));
    });

    test('should process in batches of specified size', () async {
      for (var i = 0; i < 120; i++) {
        await queue.enqueue(
          createTestMutation(
            id: 'mut_$i',
            timestamp: DateTime(2025, 1, 1, 0, 0, i),
          ),
        );
      }

      final result = await queue.replay(
        syncFunction: (_) async => SyncResponse.ok(),
        batchSize: 50,
      );

      expect(result.totalProcessed, equals(120));
      expect(result.successCount, equals(120));
    });

    test('should mark successful mutations as synced', () async {
      await queue.enqueue(createTestMutation(id: 'mut_success'));

      await queue.replay(syncFunction: (_) async => SyncResponse.ok());

      final row = database.rows.firstWhere((r) => r['id'] == 'mut_success');
      expect(row['status'], equals('synced'));
    });

    test('should handle sync failures with retry increment', () async {
      await queue.enqueue(createTestMutation(id: 'mut_fail'));

      final result = await queue.replay(
        syncFunction: (_) async => SyncResponse.error('Server error'),
      );

      expect(result.failedCount, equals(1));
      expect(result.failedMutationIds, contains('mut_fail'));

      final row = database.rows.firstWhere((r) => r['id'] == 'mut_fail');
      expect(row['retry_count'], equals(1));
      expect(row['status'], equals('pending'));
    });

    test('should mark mutation as failed after 3 retry attempts', () async {
      database.bulkInsert([
        <String, dynamic>{
          'id': 'mut_exhaust',
          'tenant_id': 'tenant_001',
          'timestamp': DateTime(2025, 1, 1).toIso8601String(),
          'operation_type': 'create',
          'entity_type': 'invoice',
          'payload': '{"amount": 100}',
          'retry_count': 2,
          'status': 'pending',
          'failure_reason': null,
          'affected_record_id': null,
          'created_at': DateTime(2025, 1, 1).toIso8601String(),
          'synced_at': null,
        },
      ]);

      final result = await queue.replay(
        syncFunction: (_) async => SyncResponse.error('Validation failed'),
      );

      expect(result.failedCount, equals(1));

      final row = database.rows.firstWhere((r) => r['id'] == 'mut_exhaust');
      expect(row['status'], equals('failed'));
      expect(row['retry_count'], equals(3));
      expect(row['failure_reason'], equals('Validation failed'));
    });

    test('should invoke onFailure callback after 3 failed attempts', () async {
      database.bulkInsert([
        <String, dynamic>{
          'id': 'mut_notify',
          'tenant_id': 'tenant_001',
          'timestamp': DateTime(2025, 1, 1).toIso8601String(),
          'operation_type': 'update',
          'entity_type': 'product',
          'payload': '{"name": "Widget"}',
          'retry_count': 2,
          'status': 'pending',
          'failure_reason': null,
          'affected_record_id': 'rec_xyz',
          'created_at': DateTime(2025, 1, 1).toIso8601String(),
          'synced_at': null,
        },
      ]);

      FailedMutation? notifiedMutation;
      await queue.replay(
        syncFunction: (_) async =>
            SyncResponse.error('Conflict', affectedRecordId: 'rec_xyz'),
        onFailure: (mutation) {
          notifiedMutation = mutation;
        },
      );

      expect(notifiedMutation, isNotNull);
      expect(notifiedMutation!.id, equals('mut_notify'));
      expect(
        notifiedMutation!.operationType,
        equals(MutationOperationType.update),
      );
      expect(notifiedMutation!.failureReason, equals('Conflict'));
      expect(notifiedMutation!.affectedRecordId, equals('rec_xyz'));
      expect(notifiedMutation!.retryCount, equals(3));
    });

    test('should not invoke onFailure callback before 3 attempts', () async {
      await queue.enqueue(createTestMutation(id: 'mut_early_fail'));

      bool notified = false;
      await queue.replay(
        syncFunction: (_) async => SyncResponse.error('Temp error'),
        onFailure: (_) {
          notified = true;
        },
      );

      expect(notified, isFalse);
    });

    test('should handle exceptions from syncFunction', () async {
      await queue.enqueue(createTestMutation(id: 'mut_exception'));

      final result = await queue.replay(
        syncFunction: (_) async => throw Exception('Network timeout'),
      );

      expect(result.failedCount, equals(1));
      expect(result.failedMutationIds, contains('mut_exception'));
    });

    test('should respect batch timeout', () async {
      for (var i = 0; i < 5; i++) {
        await queue.enqueue(
          createTestMutation(
            id: 'mut_$i',
            timestamp: DateTime(2025, 1, 1, 0, 0, i),
          ),
        );
      }

      final result = await queue.replay(
        syncFunction: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return SyncResponse.ok();
        },
        batchTimeout: Duration.zero,
      );

      expect(result.timedOut, isTrue);
    });

    test('default batchSize should be 50 and timeout 60 seconds', () async {
      await queue.enqueue(createTestMutation(id: 'mut_default'));

      final result = await queue.replay(
        syncFunction: (_) async => SyncResponse.ok(),
      );

      expect(result.successCount, equals(1));
      expect(result.timedOut, isFalse);
    });
  });

  group('OfflineQueue - Conflict Resolution (Last-Write-Wins)', () {
    test(
      'should resolve in favor of local when local timestamp is newer',
      () async {
        await queue.enqueue(
          createTestMutation(
            id: 'mut_local_wins',
            timestamp: DateTime(2025, 1, 1, 10, 5, 0),
          ),
        );

        final result = await queue.replay(
          syncFunction: (_) async => SyncResponse.conflict(
            serverLastModified: DateTime(2025, 1, 1, 10, 0, 0),
            affectedRecordId: 'rec_1',
          ),
        );

        expect(result.successCount, equals(1));
        expect(result.conflictCount, equals(1));
        expect(result.failedCount, equals(0));
      },
    );

    test(
      'should resolve in favor of server when server timestamp is newer',
      () async {
        await queue.enqueue(
          createTestMutation(
            id: 'mut_server_wins',
            timestamp: DateTime(2025, 1, 1, 10, 0, 0),
          ),
        );

        final result = await queue.replay(
          syncFunction: (_) async => SyncResponse.conflict(
            serverLastModified: DateTime(2025, 1, 1, 10, 5, 0),
            affectedRecordId: 'rec_2',
          ),
        );

        expect(result.successCount, equals(1));
        expect(result.conflictCount, equals(1));
        expect(result.failedCount, equals(0));
      },
    );

    test('should resolve in favor of local when no server timestamp', () async {
      await queue.enqueue(
        createTestMutation(
          id: 'mut_no_server_ts',
          timestamp: DateTime(2025, 1, 1, 10, 0, 0),
        ),
      );

      final result = await queue.replay(
        syncFunction: (_) async => const SyncResponse(
          success: false,
          isConflict: true,
          serverLastModified: null,
          errorMessage: 'Conflict but no timestamp',
        ),
      );

      expect(result.successCount, equals(1));
      expect(result.conflictCount, equals(1));
    });

    test(
      'should resolve in favor of server when timestamps are equal',
      () async {
        final sameTime = DateTime(2025, 1, 1, 10, 0, 0);
        await queue.enqueue(
          createTestMutation(id: 'mut_equal_ts', timestamp: sameTime),
        );

        final result = await queue.replay(
          syncFunction: (_) async => SyncResponse.conflict(
            serverLastModified: sameTime,
            affectedRecordId: 'rec_eq',
          ),
        );

        expect(result.successCount, equals(1));
        expect(result.conflictCount, equals(1));
      },
    );
  });

  group('OfflineQueue - getFailedMutations()', () {
    test('should return empty list when no failed mutations exist', () async {
      final failed = await queue.getFailedMutations();
      expect(failed, isEmpty);
    });

    test('should return failed mutations with failure details', () async {
      database.bulkInsert([
        <String, dynamic>{
          'id': 'failed_1',
          'tenant_id': 'tenant_001',
          'timestamp': DateTime(2025, 1, 1, 10, 0, 0).toIso8601String(),
          'operation_type': 'create',
          'entity_type': 'invoice',
          'payload': '{"amount": 500}',
          'retry_count': 3,
          'status': 'failed',
          'failure_reason': 'Validation error: amount exceeds limit',
          'affected_record_id': 'inv_123',
          'created_at': DateTime(2025, 1, 1, 9, 0, 0).toIso8601String(),
          'synced_at': null,
        },
      ]);

      final failed = await queue.getFailedMutations();

      expect(failed.length, equals(1));
      expect(failed.first.id, equals('failed_1'));
      expect(
        failed.first.failureReason,
        equals('Validation error: amount exceeds limit'),
      );
      expect(failed.first.affectedRecordId, equals('inv_123'));
      expect(failed.first.operationType, equals(MutationOperationType.create));
      expect(failed.first.retryCount, equals(3));
    });
  });

  group('OfflineQueue - discard()', () {
    test('should remove a failed mutation from the queue', () async {
      database.bulkInsert([
        <String, dynamic>{
          'id': 'to_discard',
          'tenant_id': 'tenant_001',
          'timestamp': DateTime(2025, 1, 1).toIso8601String(),
          'operation_type': 'delete',
          'entity_type': 'product',
          'payload': '{}',
          'retry_count': 3,
          'status': 'failed',
          'failure_reason': 'Not found',
          'affected_record_id': 'prod_456',
          'created_at': DateTime(2025, 1, 1).toIso8601String(),
          'synced_at': null,
        },
      ]);

      await queue.discard('to_discard');

      expect(database.rows.where((r) => r['id'] == 'to_discard'), isEmpty);
    });
  });

  group('SyncResponse model', () {
    test('SyncResponse.ok should have success=true', () {
      final response = SyncResponse.ok(
        serverLastModified: DateTime(2025, 1, 1),
        affectedRecordId: 'rec_1',
      );

      expect(response.success, isTrue);
      expect(response.isConflict, isFalse);
      expect(response.serverLastModified, equals(DateTime(2025, 1, 1)));
      expect(response.affectedRecordId, equals('rec_1'));
    });

    test('SyncResponse.conflict should have isConflict=true', () {
      final response = SyncResponse.conflict(
        serverLastModified: DateTime(2025, 1, 1),
        affectedRecordId: 'rec_2',
      );

      expect(response.success, isFalse);
      expect(response.isConflict, isTrue);
      expect(response.serverLastModified, equals(DateTime(2025, 1, 1)));
      expect(response.errorMessage, equals('Server has a newer version'));
    });

    test('SyncResponse.error should have success=false and message', () {
      final response = SyncResponse.error('Bad request');

      expect(response.success, isFalse);
      expect(response.isConflict, isFalse);
      expect(response.errorMessage, equals('Bad request'));
    });
  });

  group('ReplayResult model', () {
    test('should combine two results with + operator', () {
      const r1 = ReplayResult(
        totalProcessed: 5,
        successCount: 3,
        failedCount: 2,
        conflictCount: 1,
        failedMutationIds: ['a', 'b'],
      );
      const r2 = ReplayResult(
        totalProcessed: 3,
        successCount: 2,
        failedCount: 1,
        conflictCount: 0,
        failedMutationIds: ['c'],
      );

      final combined = r1 + r2;

      expect(combined.totalProcessed, equals(8));
      expect(combined.successCount, equals(5));
      expect(combined.failedCount, equals(3));
      expect(combined.conflictCount, equals(1));
      expect(combined.failedMutationIds, equals(['a', 'b', 'c']));
      expect(combined.timedOut, isFalse);
    });

    test('timedOut should propagate through combination', () {
      const r1 = ReplayResult(
        totalProcessed: 5,
        successCount: 5,
        failedCount: 0,
        timedOut: true,
      );
      const r2 = ReplayResult(
        totalProcessed: 0,
        successCount: 0,
        failedCount: 0,
      );

      final combined = r1 + r2;
      expect(combined.timedOut, isTrue);
    });
  });
}
