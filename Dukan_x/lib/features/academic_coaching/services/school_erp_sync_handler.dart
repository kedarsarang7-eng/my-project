// ============================================================================
// SCHOOL ERP SYNC HANDLER (Requirement 8.2, 8.3, 8.4, 8.5)
// ============================================================================
// Offline-first sync handler for the schoolErp vertical.
// Extends synchronization beyond `school_students` to also cover fees,
// attendance, and exams (Requirement 8.2).
//
// Implements idempotent, order-independent reconciliation keyed by RID
// (Requirement 8.3, 8.4, 8.5):
//
// - On connectivity restore, reconciles local (Drift cache) and remote (API
//   response) state so each RID has exactly one stored version with no
//   duplicate.
// - An upsert whose RID exists at the same-or-newer syncVersion is a no-op
//   (applying the same change more than once equals a single application).
// - When a WebSocket event and a sync operation target the same RID, the
//   operations are serialized via a per-RID lock, applied at most once, and
//   reach a single resulting version independent of arrival order.
//
// Requirement 8.7: A failed sync retains its pending local change, leaves
// successfully synced records unaffected, and retries on the next
// connectivity-restored event without discarding it.
//
// Uses `syncVersion` field in the cache tables as a version counter.
// On upsert: compare incoming version with stored version; only apply if
// incoming > stored.
//
// RID format: {tenantId}-{timestamp_ms}-{uuid_v4_short}
// Money: integer Paise. Tenant isolation on every query.
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/models/sync_types.dart';
import '../../../core/sync/sync_queue_state_machine.dart';

// ============================================================================
// RECONCILIATION RESULT
// ============================================================================

/// Result of a full reconciliation cycle.
class SchoolSyncCycleResult {
  /// Number of entities successfully reconciled/synced.
  final int reconciledCount;

  /// Number of entities skipped (already at same-or-newer version).
  final int skippedCount;

  /// Entities that failed, keyed by RID with the error message.
  final Map<String, String> failures;

  const SchoolSyncCycleResult({
    required this.reconciledCount,
    required this.skippedCount,
    required this.failures,
  });

  bool get isSuccess => failures.isEmpty;
  bool get isNoop =>
      reconciledCount == 0 && skippedCount == 0 && failures.isEmpty;
}

// ============================================================================
// PER-RID LOCK — SERIALIZATION (Requirement 8.5)
// ============================================================================

/// A per-RID lock that serializes concurrent operations targeting the same
/// record. This ensures that when a WebSocket event and a sync operation both
/// target the same RID, they are serialized, applied at most once, and reach a
/// single resulting version independent of arrival order.
class _RidLock {
  final _locks = <String, Completer<void>>{};

  /// Acquire a lock for [rid]. If another operation is already holding the lock
  /// for this RID, this method waits until that operation completes.
  Future<void> acquire(String rid) async {
    while (_locks.containsKey(rid)) {
      await _locks[rid]!.future;
    }
    _locks[rid] = Completer<void>();
  }

  /// Release the lock for [rid], allowing any waiting operation to proceed.
  void release(String rid) {
    final completer = _locks.remove(rid);
    completer?.complete();
  }
}

// ============================================================================
// SCHOOL SYNC HANDLER
// ============================================================================

/// Offline-first sync handler for the schoolErp vertical.
///
/// Targets: school_students, school_fees, school_attendance, school_exams.
///
/// Implements idempotent, order-independent reconciliation:
/// - Each RID has exactly one stored version (no duplicates).
/// - An upsert at the same-or-newer version is a no-op.
/// - WebSocket events and sync operations targeting the same RID are
///   serialized via a per-RID lock, applied at most once.
class SchoolErpSyncHandler {
  SchoolErpSyncHandler(this._syncManager, this._db);

  final SyncManager _syncManager;
  final AppDatabase _db;
  StreamSubscription<SyncResult>? _eventSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _connectivitySyncTimer;
  bool _attached = false;

  /// Per-RID lock for serializing concurrent operations (Requirement 8.5).
  final _ridLock = _RidLock();

  /// Maximum number of sync attempts per entity before excluding from cycle.
  static const int maxSyncAttempts = 5;

  /// Maximum delay (seconds) before triggering a sync cycle after
  /// connectivity is restored (Requirement 8.2).
  static const int connectivitySyncDelaySecs = 60;

  /// Collections targeted by this handler.
  static const String studentsCollection = 'school_students';
  static const String feesCollection = 'school_fees';
  static const String attendanceCollection = 'school_attendance';
  static const String examsCollection = 'school_exams';

  /// All collections managed by this handler.
  static const List<String> managedCollections = [
    studentsCollection,
    feesCollection,
    attendanceCollection,
    examsCollection,
  ];

  /// Collection → API base path mapping (Requirement 8.2).
  /// Each collection maps to its corresponding `/ac/*` endpoint for sync.
  static const Map<String, String> collectionApiPaths = {
    studentsCollection: '/ac/students',
    feesCollection: '/ac/fees',
    attendanceCollection: '/ac/attendance',
    examsCollection: '/ac/exams',
  };

  /// In-memory retry counter per entity RID.
  final Map<String, int> _syncAttempts = {};

  /// Whether the last-known connectivity state was offline.
  bool _wasOffline = false;

  /// User ID (tenantId) for the current session.
  String? _tenantId;

  bool get isAttached => _attached;

  /// Expose retry attempts for testing/debugging.
  int getSyncAttempts(String entityRid) => _syncAttempts[entityRid] ?? 0;

  /// Reset retry counter for an entity (e.g. after manual intervention).
  void resetSyncAttempts(String entityRid) => _syncAttempts.remove(entityRid);

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  /// Attach to the live [SyncManager] event stream and start connectivity
  /// monitoring. Idempotent.
  void attach({String? tenantId}) {
    if (_attached) return;
    _attached = true;
    _tenantId = tenantId;

    _eventSub = _syncManager.syncEventStream.listen(
      _onSyncEvent,
      onError: (Object e) {
        if (kDebugMode) {
          debugPrint('SchoolErpSyncHandler sync error: $e');
        }
      },
    );

    _startConnectivityMonitoring();

    if (kDebugMode) {
      debugPrint('SchoolErpSyncHandler attached to live SyncManager');
    }
  }

  /// Observe sync results from the engine for school-specific reconciliation.
  void _onSyncEvent(SyncResult result) {
    if (kDebugMode) {
      debugPrint(
        'SchoolErpSyncHandler: operation ${result.operationId} '
        '${result.isSuccess ? "synced" : "failed"}',
      );
    }
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _connectivitySyncTimer?.cancel();
    _connectivitySyncTimer = null;
    _attached = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONNECTIVITY MONITORING (Requirement 8.2)
  // ─────────────────────────────────────────────────────────────────────────

  void _startConnectivityMonitoring() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    Connectivity().checkConnectivity().then(_setInitialConnectivity);
  }

  void _setInitialConnectivity(List<ConnectivityResult> results) {
    _wasOffline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOffline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);

    if (_wasOffline && !isOffline) {
      _scheduleSyncOnConnectivity();
    }
    _wasOffline = isOffline;
  }

  void _scheduleSyncOnConnectivity() {
    if (_connectivitySyncTimer?.isActive == true) return;

    if (kDebugMode) {
      debugPrint(
        'SchoolErpSyncHandler: connectivity restored, scheduling '
        'reconciliation within $connectivitySyncDelaySecs seconds',
      );
    }

    _connectivitySyncTimer = Timer(
      const Duration(seconds: 1),
      _triggerConnectivitySync,
    );
  }

  void _triggerConnectivitySync() {
    if (_tenantId != null) {
      // Requirement 8.7: On connectivity restore, retry ALL failed entries
      // first, then reconcile pending ones.
      retryFailedEntries(_tenantId!).then((_) => reconcile(_tenantId!));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IDEMPOTENT RECONCILIATION (Requirement 8.3, 8.4, 8.5)
  // ─────────────────────────────────────────────────────────────────────────

  /// Run a full reconciliation cycle for the given tenant.
  ///
  /// On connectivity restore, reconciles local and remote state so each RID
  /// has exactly one stored version with no duplicate.
  ///
  /// - An upsert whose RID exists at the same-or-newer syncVersion is a no-op.
  /// - Applying the same change more than once equals a single application.
  /// - Operations targeting the same RID are serialized via the per-RID lock.
  ///
  /// Returns [SchoolSyncCycleResult] summarizing reconciled, skipped, failures.
  Future<SchoolSyncCycleResult> reconcile(String tenantId) async {
    _tenantId = tenantId;
    int reconciledCount = 0;
    int skippedCount = 0;
    final failures = <String, String>{};

    // Process each entity type in the sync queue.
    for (final collection in managedCollections) {
      final pendingEntries = await _getPendingSyncEntries(tenantId, collection);

      for (final entry in pendingEntries) {
        final rid = entry['entity_rid'] as String;
        final attempts = _syncAttempts[rid] ?? 0;

        // Skip entities that have exhausted retries (R8.7 — retained, not
        // discarded; retried on next cycle after reset).
        if (attempts >= maxSyncAttempts) {
          failures[rid] =
              'Max sync attempts ($maxSyncAttempts) reached; entity retained locally';
          if (kDebugMode) {
            debugPrint(
              'SchoolErpSyncHandler: skipping $rid (max attempts reached)',
            );
          }
          continue;
        }

        try {
          // Acquire the per-RID lock (R8.5) — serializes against WebSocket
          // events targeting the same RID.
          await _ridLock.acquire(rid);

          try {
            final applied = await _reconcileEntity(
              tenantId: tenantId,
              collection: collection,
              entry: entry,
            );

            if (applied) {
              reconciledCount++;
              _syncAttempts.remove(rid);
            } else {
              skippedCount++;
              _syncAttempts.remove(rid);
            }
          } finally {
            _ridLock.release(rid);
          }
        } catch (e) {
          _syncAttempts[rid] = attempts + 1;
          failures[rid] = e.toString();
          // Requirement 8.7: Retain the failed entry — never discard.
          // Increment retryCount, store lastError, set failed = true.
          await _markSyncEntryFailed(
            rid: rid,
            collection: collection,
            retryCount: attempts + 1,
            lastError: e.toString(),
          );
          if (kDebugMode) {
            debugPrint(
              'SchoolErpSyncHandler: failed to reconcile $rid '
              '(attempt ${attempts + 1}/$maxSyncAttempts): $e',
            );
          }
        }
      }
    }

    return SchoolSyncCycleResult(
      reconciledCount: reconciledCount,
      skippedCount: skippedCount,
      failures: failures,
    );
  }

  /// Reconcile a single entity.
  ///
  /// Returns `true` if the entity was applied (newer version), `false` if
  /// skipped (same-or-newer version already exists — idempotent no-op).
  ///
  /// The caller MUST hold the per-RID lock before invoking this method.
  Future<bool> _reconcileEntity({
    required String tenantId,
    required String collection,
    required Map<String, dynamic> entry,
  }) async {
    final rid = entry['entity_rid'] as String;
    final incomingVersion = (entry['sync_version'] as num?)?.toInt() ?? 0;
    final operation = entry['operation'] as String? ?? 'upsert';

    // Look up the stored version for this RID in the cache table.
    final storedVersion = await _getStoredVersion(collection, rid, tenantId);

    // Core idempotency rule (R8.3, R8.4):
    // An upsert whose RID exists at the same-or-newer version is a no-op.
    if (storedVersion != null && incomingVersion <= storedVersion) {
      if (kDebugMode) {
        debugPrint(
          'SchoolErpSyncHandler: skipping $rid — stored version '
          '$storedVersion >= incoming $incomingVersion (idempotent no-op)',
        );
      }
      // Mark the sync queue entry as synced (already at desired state).
      await _markSyncEntryComplete(rid, collection);
      return false;
    }

    // Apply the change: enqueue through SyncManager for server push, then
    // update the local cache with the new version.
    final payload = _extractPayload(entry);

    await _syncManager.enqueue(
      SyncQueueItem.create(
        userId: tenantId,
        operationType: operation == 'delete'
            ? SyncOperationType.delete
            : SyncOperationType.update,
        targetCollection: collection,
        documentId: rid,
        payload: payload,
      ),
    );

    // Update local cache version to prevent re-application.
    await _upsertCacheVersion(collection, rid, tenantId, incomingVersion);

    // Mark the sync queue entry as complete.
    await _markSyncEntryComplete(rid, collection);

    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RETRY FAILED ENTRIES (Requirement 8.7)
  // ─────────────────────────────────────────────────────────────────────────

  /// Retry all entries in the sync queue that have `failed = true`.
  ///
  /// Requirement 8.7: A failed sync entry is NEVER discarded. It retains its
  /// pending local change, leaves successfully synced records unaffected, and
  /// is retried on the next connectivity-restored event.
  ///
  /// On success: the entry is removed from the queue.
  /// On failure: the entry is retained with retryCount incremented, lastError
  /// updated, and failed flag remaining true for the next retry cycle.
  ///
  /// Processing is per-record — a failure in one entry does NOT affect other
  /// entries in the queue.
  Future<SchoolSyncCycleResult> retryFailedEntries(String tenantId) async {
    _tenantId = tenantId;
    int reconciledCount = 0;
    int skippedCount = 0;
    final failures = <String, String>{};

    // Query all entries with failed = true (regardless of collection).
    final failedEntries = await _getFailedSyncEntries(tenantId);

    if (failedEntries.isEmpty) {
      return const SchoolSyncCycleResult(
        reconciledCount: 0,
        skippedCount: 0,
        failures: {},
      );
    }

    if (kDebugMode) {
      debugPrint(
        'SchoolErpSyncHandler: retrying ${failedEntries.length} failed entries',
      );
    }

    for (final entry in failedEntries) {
      final rid = entry['entity_rid'] as String;
      final collection = entry['entity_type'] as String;

      try {
        // Acquire the per-RID lock (R8.5) — serializes against WebSocket
        // events targeting the same RID.
        await _ridLock.acquire(rid);

        try {
          final applied = await _reconcileEntity(
            tenantId: tenantId,
            collection: collection,
            entry: entry,
          );

          if (applied) {
            reconciledCount++;
            _syncAttempts.remove(rid);
          } else {
            skippedCount++;
            _syncAttempts.remove(rid);
          }
        } finally {
          _ridLock.release(rid);
        }
      } catch (e) {
        // Per-record failure handling (Requirement 8.7):
        // - Retain the entry (never discard)
        // - Increment retryCount
        // - Store lastError
        // - Keep failed = true for the next retry cycle
        final currentRetryCount = (entry['retry_count'] as num?)?.toInt() ?? 0;
        await _markSyncEntryFailed(
          rid: rid,
          collection: collection,
          retryCount: currentRetryCount + 1,
          lastError: e.toString(),
        );
        _syncAttempts[rid] = (currentRetryCount + 1);
        failures[rid] = e.toString();

        if (kDebugMode) {
          debugPrint(
            'SchoolErpSyncHandler: retry failed for $rid '
            '(attempt ${currentRetryCount + 1}): $e',
          );
        }
      }
    }

    if (kDebugMode) {
      debugPrint(
        'SchoolErpSyncHandler: retry cycle complete — '
        'synced=$reconciledCount, skipped=$skippedCount, '
        'still-failed=${failures.length}',
      );
    }

    return SchoolSyncCycleResult(
      reconciledCount: reconciledCount,
      skippedCount: skippedCount,
      failures: failures,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WEBSOCKET EVENT RECONCILIATION (Requirement 8.5)
  // ─────────────────────────────────────────────────────────────────────────

  /// Handle an incoming WebSocket event for a school entity.
  ///
  /// This method is called by the WebSocket consumer when a `school.*` event
  /// arrives. It acquires the per-RID lock to serialize against any ongoing
  /// sync operation for the same RID, then applies the version check:
  /// - If the incoming version > stored version: apply and update cache.
  /// - Otherwise: no-op (the local state is already at-or-ahead of the event).
  ///
  /// Returns `true` if the event was applied, `false` if it was a no-op.
  Future<bool> handleWebSocketEvent({
    required String tenantId,
    required String collection,
    required String rid,
    required int syncVersion,
    required Map<String, dynamic> payload,
  }) async {
    // Tenant isolation: ignore events for a different tenant.
    if (_tenantId != null && tenantId != _tenantId) {
      return false;
    }

    await _ridLock.acquire(rid);
    try {
      final storedVersion = await _getStoredVersion(collection, rid, tenantId);

      // Same-or-newer version already stored → idempotent no-op.
      if (storedVersion != null && syncVersion <= storedVersion) {
        if (kDebugMode) {
          debugPrint(
            'SchoolErpSyncHandler: WS event for $rid is a no-op — '
            'stored $storedVersion >= incoming $syncVersion',
          );
        }
        return false;
      }

      // Apply: update local cache with the newer version.
      await _upsertCacheVersion(collection, rid, tenantId, syncVersion);

      if (kDebugMode) {
        debugPrint(
          'SchoolErpSyncHandler: WS event applied for $rid — '
          'version $syncVersion (was ${storedVersion ?? 'null'})',
        );
      }
      return true;
    } finally {
      _ridLock.release(rid);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CACHE VERSION QUERIES (using raw SQL for pre-codegen compatibility)
  // ─────────────────────────────────────────────────────────────────────────

  /// Get the stored syncVersion for a given RID in the specified collection.
  /// Returns `null` if no record exists for this RID.
  Future<int?> _getStoredVersion(
    String collection,
    String rid,
    String tenantId,
  ) async {
    final tableName = _cacheTableName(collection);
    final rows = await _db
        .customSelect(
          'SELECT sync_version FROM "$tableName" '
          'WHERE id = ? AND tenant_id = ?',
          variables: [Variable<String>(rid), Variable<String>(tenantId)],
        )
        .get();

    if (rows.isEmpty) return null;
    return rows.first.data['sync_version'] as int?;
  }

  /// Upsert the syncVersion for a given RID. If the row exists, update the
  /// version; if not, insert a minimal row with the RID and version.
  ///
  /// This is the single point of truth for version state — both sync
  /// reconciliation and WebSocket events go through this method.
  Future<void> _upsertCacheVersion(
    String collection,
    String rid,
    String tenantId,
    int syncVersion,
  ) async {
    final tableName = _cacheTableName(collection);
    final now = DateTime.now().toIso8601String();

    // Use INSERT OR REPLACE to guarantee exactly one row per RID (no
    // duplicates). The primary key is `id`, so this replaces any existing row
    // with the same RID while preserving the idempotency contract.
    await _db.customStatement(
      'INSERT OR REPLACE INTO "$tableName" '
      '(id, tenant_id, sync_version, updated_at) '
      'VALUES (?, ?, ?, ?)',
      <Object?>[rid, tenantId, syncVersion, now],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SYNC QUEUE QUERIES
  // ─────────────────────────────────────────────────────────────────────────

  /// Get pending sync entries for a collection, scoped by tenant.
  /// Reads from the `school_sync_queue` table (created in task 11.2).
  Future<List<Map<String, dynamic>>> _getPendingSyncEntries(
    String tenantId,
    String collection,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM school_sync_queue '
          'WHERE tenant_id = ? AND entity_type = ? AND failed = 0 '
          'ORDER BY created_at ASC',
          variables: [Variable<String>(tenantId), Variable<String>(collection)],
        )
        .get();
    return rows.map((r) => r.data).toList();
  }

  /// Get ALL failed sync entries for a tenant, across all collections.
  ///
  /// Requirement 8.7: On connectivity-restored, all entries with failed = true
  /// are retried. They are never discarded.
  Future<List<Map<String, dynamic>>> _getFailedSyncEntries(
    String tenantId,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM school_sync_queue '
          'WHERE tenant_id = ? AND failed = 1 '
          'ORDER BY created_at ASC',
          variables: [Variable<String>(tenantId)],
        )
        .get();
    return rows.map((r) => r.data).toList();
  }

  /// Mark a sync queue entry as failed without discarding it.
  ///
  /// Requirement 8.7: A failed sync entry is retained in the queue with:
  /// - retryCount incremented
  /// - lastError storing the most recent error
  /// - failed = true so it is retried on the next connectivity-restored event
  ///
  /// The entry is NEVER deleted or discarded on failure.
  Future<void> _markSyncEntryFailed({
    required String rid,
    required String collection,
    required int retryCount,
    required String lastError,
  }) async {
    await _db.customStatement(
      'UPDATE school_sync_queue SET '
      'retry_count = ?, last_error = ?, failed = 1 '
      'WHERE entity_rid = ? AND entity_type = ?',
      <Object?>[retryCount, lastError, rid, collection],
    );
  }

  /// Mark a sync queue entry as complete (synced) — removes it from the queue.
  Future<void> _markSyncEntryComplete(String rid, String collection) async {
    await _db.customStatement(
      'DELETE FROM school_sync_queue '
      'WHERE entity_rid = ? AND entity_type = ?',
      <Object?>[rid, collection],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Map a collection name to its corresponding Drift cache table name.
  String _cacheTableName(String collection) {
    switch (collection) {
      case studentsCollection:
        return 'school_students_cache';
      case feesCollection:
        return 'school_fees_cache';
      case attendanceCollection:
        return 'school_attendance_cache';
      case examsCollection:
        return 'school_exams_cache';
      default:
        return 'school_students_cache';
    }
  }

  /// Extract the payload from a sync queue entry for transmission.
  Map<String, dynamic> _extractPayload(Map<String, dynamic> entry) {
    // The payload is stored as a JSON-encoded string in the `payload` column.
    final raw = entry['payload'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // Fall through to fallback.
      }
    }
    // Fallback: return the entire entry minus internal bookkeeping columns.
    final payload = Map<String, dynamic>.from(entry)
      ..remove('retry_count')
      ..remove('last_error')
      ..remove('failed')
      ..remove('created_at')
      ..remove('updated_at');
    return payload;
  }
}
