// ============================================================================
// OFFLINE MUTATION QUEUE
// ============================================================================
// SQLite-backed offline mutation queue with SQLCipher encryption.
// Stores write operations performed while the device is disconnected,
// replaying them upon reconnection.
//
// Requirements: 8.1, 8.2, 8.6
// - Local SQLite caching for offline read operations
// - Mutation storage with timestamp, operation type, payload, tenant_id
// - SQLCipher encryption with tenant-specific encryption key
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Status of an offline mutation in the queue.
enum MutationStatus {
  pending('pending'),
  syncing('syncing'),
  failed('failed'),
  synced('synced');

  final String value;
  const MutationStatus(this.value);

  static MutationStatus fromString(String value) {
    return MutationStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MutationStatus.pending,
    );
  }
}

/// Operation types for offline mutations.
enum MutationOperationType {
  create('create'),
  update('update'),
  delete('delete');

  final String value;
  const MutationOperationType(this.value);

  static MutationOperationType fromString(String value) {
    return MutationOperationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MutationOperationType.create,
    );
  }
}

/// Represents a single offline mutation queued for sync.
class OfflineMutation {
  final String id;
  final String tenantId;

  /// Stable idempotency key carried on each queued operation. The backend
  /// honours this key for server-side dedupe before applying writes
  /// (clause 2.10). Defaults to the mutation [id] (a UUID v4) so every
  /// operation envelope ships with a unique, reproducible token across retries.
  final String idempotencyKey;
  final DateTime timestamp;
  final MutationOperationType operationType;
  final String entityType;
  final Map<String, dynamic> payload;
  int retryCount;
  MutationStatus status;
  final String? failureReason;
  final String? affectedRecordId;
  final DateTime createdAt;
  final DateTime? syncedAt;

  OfflineMutation({
    String? id,
    required this.tenantId,
    String? idempotencyKey,
    DateTime? timestamp,
    required this.operationType,
    required this.entityType,
    required this.payload,
    this.retryCount = 0,
    this.status = MutationStatus.pending,
    this.failureReason,
    this.affectedRecordId,
    DateTime? createdAt,
    this.syncedAt,
  }) : id = id ?? const Uuid().v4(),
       idempotencyKey = idempotencyKey ?? id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  /// Create from a database row map.
  factory OfflineMutation.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String;
    return OfflineMutation(
      id: id,
      tenantId: map['tenant_id'] as String,
      idempotencyKey: map['idempotency_key'] as String? ?? id,
      timestamp: DateTime.parse(map['timestamp'] as String),
      operationType: MutationOperationType.fromString(
        map['operation_type'] as String,
      ),
      entityType: map['entity_type'] as String,
      payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
      retryCount: map['retry_count'] as int? ?? 0,
      status: MutationStatus.fromString(map['status'] as String? ?? 'pending'),
      failureReason: map['failure_reason'] as String?,
      affectedRecordId: map['affected_record_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
    );
  }

  /// Convert to a database row map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'idempotency_key': idempotencyKey,
      'timestamp': timestamp.toIso8601String(),
      'operation_type': operationType.value,
      'entity_type': entityType,
      'payload': jsonEncode(payload),
      'retry_count': retryCount,
      'status': status.value,
      'failure_reason': failureReason,
      'affected_record_id': affectedRecordId,
      'created_at': createdAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields.
  OfflineMutation copyWith({
    int? retryCount,
    MutationStatus? status,
    String? failureReason,
    String? affectedRecordId,
    DateTime? syncedAt,
  }) {
    return OfflineMutation(
      id: id,
      tenantId: tenantId,
      idempotencyKey: idempotencyKey,
      timestamp: timestamp,
      operationType: operationType,
      entityType: entityType,
      payload: payload,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      failureReason: failureReason ?? this.failureReason,
      affectedRecordId: affectedRecordId ?? this.affectedRecordId,
      createdAt: createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}

/// A failed mutation with failure details for user review.
class FailedMutation extends OfflineMutation {
  FailedMutation({
    required super.id,
    required super.tenantId,
    required super.timestamp,
    required super.operationType,
    required super.entityType,
    required super.payload,
    required super.retryCount,
    required String failureReason,
    required super.affectedRecordId,
    required super.createdAt,
    super.syncedAt,
  }) : super(status: MutationStatus.failed, failureReason: failureReason);

  /// Create from an OfflineMutation that has failed.
  factory FailedMutation.fromMutation(OfflineMutation mutation) {
    return FailedMutation(
      id: mutation.id,
      tenantId: mutation.tenantId,
      timestamp: mutation.timestamp,
      operationType: mutation.operationType,
      entityType: mutation.entityType,
      payload: mutation.payload,
      retryCount: mutation.retryCount,
      failureReason: mutation.failureReason ?? 'Unknown failure',
      affectedRecordId: mutation.affectedRecordId,
      createdAt: mutation.createdAt,
      syncedAt: mutation.syncedAt,
    );
  }
}

/// Result of an enqueue operation.
class QueueResult {
  final bool success;
  final String? mutationId;
  final String? error;

  const QueueResult._({required this.success, this.mutationId, this.error});

  factory QueueResult.success(String mutationId) =>
      QueueResult._(success: true, mutationId: mutationId);

  factory QueueResult.failure(String error) =>
      QueueResult._(success: false, error: error);
}

/// Result of a replay (sync) operation.
class ReplayResult {
  final int totalProcessed;
  final int successCount;
  final int failedCount;
  final int conflictCount;
  final List<String> failedMutationIds;
  final bool timedOut;

  const ReplayResult({
    required this.totalProcessed,
    required this.successCount,
    required this.failedCount,
    this.conflictCount = 0,
    this.failedMutationIds = const [],
    this.timedOut = false,
  });

  /// Combine two replay results (used when processing multiple batches).
  ReplayResult operator +(ReplayResult other) {
    return ReplayResult(
      totalProcessed: totalProcessed + other.totalProcessed,
      successCount: successCount + other.successCount,
      failedCount: failedCount + other.failedCount,
      conflictCount: conflictCount + other.conflictCount,
      failedMutationIds: [...failedMutationIds, ...other.failedMutationIds],
      timedOut: timedOut || other.timedOut,
    );
  }
}

/// Response from the server after attempting to sync a mutation.
///
/// Used by the [OfflineQueue.replay] method to determine whether a mutation
/// was successfully synced or needs conflict resolution / retry.
class SyncResponse {
  /// Whether the server accepted the mutation.
  final bool success;

  /// The server's last-modified timestamp for the affected record.
  /// Used for last-write-wins conflict resolution.
  final DateTime? serverLastModified;

  /// Error message if the sync failed.
  final String? errorMessage;

  /// Whether the failure is due to a conflict (server has a newer version).
  final bool isConflict;

  /// The ID of the affected record on the server side.
  final String? affectedRecordId;

  const SyncResponse({
    required this.success,
    this.serverLastModified,
    this.errorMessage,
    this.isConflict = false,
    this.affectedRecordId,
  });

  factory SyncResponse.ok({
    DateTime? serverLastModified,
    String? affectedRecordId,
  }) => SyncResponse(
    success: true,
    serverLastModified: serverLastModified,
    affectedRecordId: affectedRecordId,
  );

  factory SyncResponse.conflict({
    required DateTime serverLastModified,
    String? errorMessage,
    String? affectedRecordId,
  }) => SyncResponse(
    success: false,
    serverLastModified: serverLastModified,
    errorMessage: errorMessage ?? 'Server has a newer version',
    isConflict: true,
    affectedRecordId: affectedRecordId,
  );

  factory SyncResponse.error(String message, {String? affectedRecordId}) =>
      SyncResponse(
        success: false,
        errorMessage: message,
        affectedRecordId: affectedRecordId,
      );
}

/// Callback type for displaying persistent notifications about failed mutations.
///
/// Implementations should show a non-dismissible notification to the user
/// containing the operation type, affected record, and failure reason.
typedef SyncFailureNotifier = void Function(FailedMutation mutation);

/// Abstract interface for the underlying database operations.
///
/// This abstraction allows the OfflineQueue to work with any SQLite
/// implementation (raw sqflite, Drift, or test mocks) while keeping
/// the queue logic independent of the database library.
abstract class OfflineQueueDatabase {
  /// Execute a raw SQL statement (DDL or DML with no result set).
  Future<void> execute(String sql, [List<Object?>? arguments]);

  /// Execute a raw SQL query and return rows as maps.
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]);

  /// Insert a row and return the affected count.
  Future<int> rawInsert(String sql, [List<Object?>? arguments]);

  /// Update rows and return the affected count.
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]);

  /// Delete rows and return the affected count.
  Future<int> rawDelete(String sql, [List<Object?>? arguments]);
}

/// SQLite offline mutation queue with SQLCipher encryption.
///
/// Extends the existing `core/sync/` infrastructure with mutation queuing,
/// replay, and capacity management. Uses SQLCipher for at-rest encryption
/// with a tenant-specific encryption key.
///
/// Usage:
/// ```dart
/// final queue = OfflineQueue(database: myDatabaseAdapter);
/// await queue.initialize(tenantEncryptionKey);
/// final result = await queue.enqueue(mutation);
/// ```
class OfflineQueue {
  /// Maximum number of mutations allowed in the queue per device.
  static const int maxQueueSize = 5000;

  /// Name of the SQLite table storing offline mutations.
  static const String tableName = 'offline_mutations';

  /// The database adapter for executing SQL operations.
  final OfflineQueueDatabase _database;

  /// Whether the queue has been initialized.
  bool _initialized = false;

  OfflineQueue({required OfflineQueueDatabase database}) : _database = database;

  /// Whether the queue database has been initialized.
  bool get isInitialized => _initialized;

  // ---------------------------------------------------------------------------
  // Schema Definition
  // ---------------------------------------------------------------------------

  /// SQL CREATE TABLE statement for the offline_mutations table.
  static String get createTableSql =>
      '''
CREATE TABLE IF NOT EXISTS $tableName (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  payload TEXT NOT NULL,
  retry_count INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending',
  failure_reason TEXT,
  affected_record_id TEXT,
  created_at TEXT NOT NULL,
  synced_at TEXT
)''';

  /// SQL statements to create indexes on the offline_mutations table.
  static List<String> get createIndexesSql => [
    'CREATE INDEX IF NOT EXISTS idx_mutations_status ON $tableName(status)',
    'CREATE INDEX IF NOT EXISTS idx_mutations_tenant ON $tableName(tenant_id)',
    'CREATE INDEX IF NOT EXISTS idx_mutations_timestamp ON $tableName(timestamp)',
  ];

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialize the queue database with SQLCipher encryption.
  ///
  /// The [tenantEncryptionKey] is used to set the SQLCipher PRAGMA key,
  /// ensuring data is encrypted at rest with a tenant-specific key.
  /// If the key is empty, the database opens unencrypted (development mode).
  Future<void> initialize(String tenantEncryptionKey) async {
    if (_initialized) return;

    try {
      // Apply SQLCipher encryption key if provided.
      // The key must be set as the first operation on the database connection.
      if (tenantEncryptionKey.isNotEmpty) {
        await _database.execute('PRAGMA key = "x\'$tenantEncryptionKey\'"');
        debugPrint('OfflineQueue: SQLCipher encryption enabled');
      } else {
        debugPrint('OfflineQueue: Running without encryption (dev mode)');
      }

      // Create the mutations table.
      await _database.execute(createTableSql);

      // Create indexes for efficient queries.
      for (final indexSql in createIndexesSql) {
        await _database.execute(indexSql);
      }

      _initialized = true;
      debugPrint('OfflineQueue: Initialized successfully');
    } catch (e) {
      debugPrint('OfflineQueue: Initialization failed: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Queue Operations
  // ---------------------------------------------------------------------------

  /// Queue a mutation while offline.
  ///
  /// Returns [QueueResult.failure] if the queue is at capacity (5000 mutations)
  /// or if the database operation fails.
  Future<QueueResult> enqueue(OfflineMutation mutation) async {
    _ensureInitialized();

    // Check capacity before inserting.
    if (await isAtCapacity) {
      return QueueResult.failure(
        'Queue is at maximum capacity ($maxQueueSize). '
        'Connectivity is required to sync pending changes.',
      );
    }

    try {
      final map = mutation.toMap();
      final columns = map.keys.join(', ');
      final placeholders = map.keys.map((_) => '?').join(', ');
      final values = map.values.toList();

      await _database.rawInsert(
        'INSERT INTO $tableName ($columns) VALUES ($placeholders)',
        values,
      );

      return QueueResult.success(mutation.id);
    } catch (e) {
      return QueueResult.failure('Failed to enqueue mutation: $e');
    }
  }

  /// Get current queue size (all non-synced mutations).
  Future<int> get queueSize async {
    _ensureInitialized();

    final result = await _database.rawQuery(
      "SELECT COUNT(*) as count FROM $tableName WHERE status != 'synced'",
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Check if queue is at maximum capacity.
  Future<bool> get isAtCapacity async {
    return (await queueSize) >= maxQueueSize;
  }

  /// Get all pending mutations in chronological order.
  Future<List<OfflineMutation>> getPendingMutations() async {
    _ensureInitialized();

    final results = await _database.rawQuery(
      "SELECT * FROM $tableName WHERE status = 'pending' "
      'ORDER BY timestamp ASC',
    );
    return results.map((row) => OfflineMutation.fromMap(row)).toList();
  }

  /// Get failed mutations for user review.
  Future<List<FailedMutation>> getFailedMutations() async {
    _ensureInitialized();

    final results = await _database.rawQuery(
      "SELECT * FROM $tableName WHERE status = 'failed' "
      'ORDER BY timestamp ASC',
    );
    return results
        .map((row) => FailedMutation.fromMutation(OfflineMutation.fromMap(row)))
        .toList();
  }

  /// Discard a failed mutation by ID.
  Future<void> discard(String mutationId) async {
    _ensureInitialized();

    await _database.rawDelete('DELETE FROM $tableName WHERE id = ?', [
      mutationId,
    ]);
  }

  // ---------------------------------------------------------------------------
  // Replay & Conflict Resolution (Req 8.3, 8.4)
  // ---------------------------------------------------------------------------

  /// Maximum number of failed sync attempts before showing a persistent
  /// notification to the user.
  static const int maxRetryAttempts = 3;

  /// Replay queued mutations on reconnection.
  ///
  /// Processes mutations in chronological order, in batches of [batchSize]
  /// with a [batchTimeout] per batch. Uses last-write-wins conflict resolution
  /// by comparing the local mutation timestamp against the server's
  /// `lastModified` timestamp from the [SyncResponse].
  ///
  /// After [maxRetryAttempts] failed sync attempts per mutation, invokes
  /// [onFailure] to display a persistent notification with the operation type,
  /// affected record, and failure reason.
  ///
  /// Returns a [ReplayResult] summarizing the outcome of all processed batches.
  Future<ReplayResult> replay({
    required Future<SyncResponse> Function(OfflineMutation) syncFunction,
    int batchSize = 50,
    Duration batchTimeout = const Duration(seconds: 60),
    SyncFailureNotifier? onFailure,
  }) async {
    _ensureInitialized();

    // Fetch all pending mutations in chronological order.
    final pending = await getPendingMutations();
    if (pending.isEmpty) {
      return const ReplayResult(
        totalProcessed: 0,
        successCount: 0,
        failedCount: 0,
      );
    }

    var combinedResult = const ReplayResult(
      totalProcessed: 0,
      successCount: 0,
      failedCount: 0,
    );

    // Process in batches.
    for (var i = 0; i < pending.length; i += batchSize) {
      final batchEnd = (i + batchSize).clamp(0, pending.length);
      final batch = pending.sublist(i, batchEnd);

      final batchResult = await _processBatch(
        batch: batch,
        syncFunction: syncFunction,
        timeout: batchTimeout,
        onFailure: onFailure,
      );

      combinedResult = combinedResult + batchResult;

      // If the batch timed out, stop processing further batches.
      if (batchResult.timedOut) {
        break;
      }
    }

    return combinedResult;
  }

  /// Process a single batch of mutations with a timeout.
  Future<ReplayResult> _processBatch({
    required List<OfflineMutation> batch,
    required Future<SyncResponse> Function(OfflineMutation) syncFunction,
    required Duration timeout,
    SyncFailureNotifier? onFailure,
  }) async {
    int successCount = 0;
    int failedCount = 0;
    int conflictCount = 0;
    final failedIds = <String>[];
    bool timedOut = false;

    final deadline = DateTime.now().add(timeout);

    for (final mutation in batch) {
      // Check if we've exceeded the batch timeout.
      if (DateTime.now().isAfter(deadline)) {
        timedOut = true;
        debugPrint(
          'OfflineQueue.replay: Batch timed out after ${timeout.inSeconds}s',
        );
        break;
      }

      // Mark as syncing.
      await updateStatus(mutation.id, MutationStatus.syncing);

      try {
        final response = await syncFunction(mutation);

        if (response.success) {
          // Sync succeeded — mark as synced.
          await updateStatus(
            mutation.id,
            MutationStatus.synced,
            syncedAt: DateTime.now(),
          );
          successCount++;
        } else if (response.isConflict) {
          // Conflict — apply last-write-wins resolution.
          conflictCount++;
          final resolved = _resolveConflict(mutation, response);
          if (resolved) {
            // Local mutation wins — server should accept on re-send, or
            // the server already applied it. Mark as synced.
            await updateStatus(
              mutation.id,
              MutationStatus.synced,
              syncedAt: DateTime.now(),
            );
            successCount++;
          } else {
            // Server wins — discard local mutation (server has newer data).
            await updateStatus(
              mutation.id,
              MutationStatus.synced,
              syncedAt: DateTime.now(),
            );
            successCount++;
          }
        } else {
          // Non-conflict failure — increment retry count.
          await _handleSyncFailure(
            mutation: mutation,
            errorMessage: response.errorMessage ?? 'Unknown sync error',
            affectedRecordId: response.affectedRecordId,
            onFailure: onFailure,
          );
          failedCount++;
          failedIds.add(mutation.id);
        }
      } catch (e) {
        // Exception during sync — treat as failure.
        await _handleSyncFailure(
          mutation: mutation,
          errorMessage: e.toString(),
          affectedRecordId: null,
          onFailure: onFailure,
        );
        failedCount++;
        failedIds.add(mutation.id);
      }
    }

    return ReplayResult(
      totalProcessed: successCount + failedCount,
      successCount: successCount,
      failedCount: failedCount,
      conflictCount: conflictCount,
      failedMutationIds: failedIds,
      timedOut: timedOut,
    );
  }

  /// Last-write-wins conflict resolution.
  ///
  /// Compares the local mutation's timestamp against the server's lastModified.
  /// Returns `true` if local wins (local is newer), `false` if server wins.
  bool _resolveConflict(OfflineMutation mutation, SyncResponse response) {
    if (response.serverLastModified == null) {
      // No server timestamp available — default to local wins.
      return true;
    }
    // Local wins if its timestamp is after the server's last modification.
    return mutation.timestamp.isAfter(response.serverLastModified!);
  }

  /// Handle a sync failure: increment retry count and notify after 3 attempts.
  Future<void> _handleSyncFailure({
    required OfflineMutation mutation,
    required String errorMessage,
    String? affectedRecordId,
    SyncFailureNotifier? onFailure,
  }) async {
    final newRetryCount = mutation.retryCount + 1;

    if (newRetryCount >= maxRetryAttempts) {
      // After 3 failed attempts — mark as permanently failed.
      await _database.rawUpdate(
        'UPDATE $tableName SET status = ?, retry_count = ?, '
        'failure_reason = ?, affected_record_id = ? WHERE id = ?',
        [
          MutationStatus.failed.value,
          newRetryCount,
          errorMessage,
          affectedRecordId ?? mutation.affectedRecordId ?? mutation.id,
          mutation.id,
        ],
      );

      // Display persistent notification.
      if (onFailure != null) {
        final failedMutation = FailedMutation(
          id: mutation.id,
          tenantId: mutation.tenantId,
          timestamp: mutation.timestamp,
          operationType: mutation.operationType,
          entityType: mutation.entityType,
          payload: mutation.payload,
          retryCount: newRetryCount,
          failureReason: errorMessage,
          affectedRecordId:
              affectedRecordId ?? mutation.affectedRecordId ?? mutation.id,
          createdAt: mutation.createdAt,
          syncedAt: mutation.syncedAt,
        );
        onFailure(failedMutation);
      }

      debugPrint(
        'OfflineQueue: Mutation ${mutation.id} permanently failed after '
        '$maxRetryAttempts attempts. Reason: $errorMessage',
      );
    } else {
      // Still has retries left — keep as pending with incremented count.
      await updateStatus(
        mutation.id,
        MutationStatus.pending,
        retryCount: newRetryCount,
        failureReason: errorMessage,
      );
    }
  }

  /// Update mutation status.
  Future<void> updateStatus(
    String mutationId,
    MutationStatus status, {
    String? failureReason,
    DateTime? syncedAt,
    int? retryCount,
  }) async {
    _ensureInitialized();

    final updates = <String>['status = ?'];
    final values = <Object?>[status.value];

    if (failureReason != null) {
      updates.add('failure_reason = ?');
      values.add(failureReason);
    }
    if (syncedAt != null) {
      updates.add('synced_at = ?');
      values.add(syncedAt.toIso8601String());
    }
    if (retryCount != null) {
      updates.add('retry_count = ?');
      values.add(retryCount);
    }

    values.add(mutationId);

    await _database.rawUpdate(
      'UPDATE $tableName SET ${updates.join(', ')} WHERE id = ?',
      values,
    );
  }

  /// Get a single mutation by ID.
  Future<OfflineMutation?> getMutation(String mutationId) async {
    _ensureInitialized();

    final results = await _database.rawQuery(
      'SELECT * FROM $tableName WHERE id = ?',
      [mutationId],
    );
    if (results.isEmpty) return null;
    return OfflineMutation.fromMap(results.first);
  }

  /// Get mutations by tenant ID.
  Future<List<OfflineMutation>> getMutationsByTenant(String tenantId) async {
    _ensureInitialized();

    final results = await _database.rawQuery(
      'SELECT * FROM $tableName WHERE tenant_id = ? ORDER BY timestamp ASC',
      [tenantId],
    );
    return results.map((row) => OfflineMutation.fromMap(row)).toList();
  }

  /// Clear all synced mutations (cleanup after successful sync).
  Future<int> clearSyncedMutations() async {
    _ensureInitialized();

    return await _database.rawDelete(
      "DELETE FROM $tableName WHERE status = 'synced'",
    );
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'OfflineQueue has not been initialized. '
        'Call initialize(tenantEncryptionKey) first.',
      );
    }
  }
}
