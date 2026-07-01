import '../abstractions/sync_repository.dart';
import '../models/sync_types.dart'; // Was sync_stats.dart
import '../../database/app_database.dart';
import 'package:drift/drift.dart'; // Import Value
import '../sync_queue_state_machine.dart'; // For SyncQueueItem and SyncStatus
import 'dart:convert';

class DriftSyncRepository implements SyncRepository {
  final AppDatabase _db;

  DriftSyncRepository(this._db);

  @override
  Stream<List<SyncQueueItem>> watchPendingItems() {
    return _db.watchPendingSyncEntries().map((rows) {
      // Convert Drift Row/Entry to SyncQueueItem
      // NOTE: AppDatabase.watchPendingSyncEntries returns List<SyncQueueEntry>?
      // Need to verify return type of watchPendingSyncEntries in AppDatabase
      // My previous read showed: Stream<List<SyncQueueEntry>> watchPendingSyncEntries()
      // But SyncQueueEntry seems to be a typedef or class?
      // Ah, SyncQueueItem is the model.
      // Let's assume the list is of SyncQueueItem or mapped.
      // In sync_manager.dart line 668: Stream<List<SyncQueueEntry>> watchPendingSyncEntries()
      // We might need to map it if SyncQueueEntry != SyncQueueItem

      // Let's rely on the fact that sync_manager.dart uses it.
      // Actually, looking at sync_manager.dart line 497, it maps rows manually in getPendingSyncItems
      // But watchPendingSyncEntries (line 668) returns SyncQueueEntry.
      // We need to map SyncQueueEntry to SyncQueueItem.

      return rows
          .map(
            (row) => SyncQueueItem(
              operationId: row.operationId,
              operationType: SyncOperationType.fromString(row.operationType),
              targetCollection: row.targetCollection,
              documentId: row.documentId,
              payload: jsonDecode(row.payload),
              status: SyncStatus.fromString(row.status),
              retryCount: row.retryCount,
              lastError: row.lastError,
              createdAt: row.createdAt,
              lastAttemptAt: row.lastAttemptAt,
              syncedAt: row.syncedAt,
              priority: row.priority,
              parentOperationId: row.parentOperationId,
              stepNumber: row.stepNumber,
              totalSteps: row.totalSteps,
              userId: row.userId,
              deviceId: row.deviceId,
              payloadHash: row.payloadHash,
              dependencyGroup: row.dependencyGroup,
              ownerId: row.ownerId,
            ),
          )
          .toList();
    });
  }

  @override
  Future<List<SyncQueueItem>> getPendingItems() {
    return _db.getPendingSyncItems();
  }

  @override
  Future<void> markInProgress(String operationId) async {
    // We need to fetch the item first OR just update specific fields.
    // SyncManager used `updateSyncQueueItem` which takes the whole item.
    // For efficiency, we should add a method to AppDatabase to just update status.
    // safely, let's fetch, update object, save.
    // Ideally we optimize this later.
    // BUT we don't have direct access to 'update status only' in the interface viewed.
    // Let's assume we can use _db.updateSyncQueueItem with a crafted object?
    // No, that replaces whole row usually.
    // Let's stick to what SyncManager did: "get item, copyWith, update".
    // But here we only have ID.
    // We'll trust the Engine passes the Item usually?
    // The Interface defines `markInProgress(String ID)`.
    // I should probably fetch it from DB to be safe or change interface?
    // Let's change implementation to use custom statement or efficiently if possible.
    // Actually, AppDatabase has `updateSyncQueueItem`.
    // Let's rely on `getPendingItems` being the source of truth for the object handling in Engine.
    // But here, I only have ID.
    // I will read it from DB to be safe.

    // Efficiency Hack for now: We assume the caller (Engine) might hold the item,
    // but the Repo interface is cleaner with ID.
    // I will implementation a fetch-update loop here.

    // Better: Add a strictly typed method to AppDatabase for status update?
    // I cannot easily modify AppDatabase deeply right now without generating code.
    // I will try to use `customStatement` or just `update` with a partial?
    // Drift support partial updates.

    // Re-reading AppDatabase:
    // Future<void> updateSyncQueueItem(SyncQueueItem item)
    // It uses `update(syncQueue)..where..`.write(Companion)
    // It updates ALL fields in the companion passed.

    // So I strictly need to fetch the item to preserve other fields?
    // Or I can create a Companion with ONLY the status field set?
    // `updateSyncQueueItem` implementation in AppDatabase lines 468-477:
    // It writes: status, retryCount, lastError, lastAttemptAt, syncedAt.
    // It does NOT write payload, etc.
    // So it IS a partial update tailored for status!
    // Excellent.

    // However, I need to pass a SyncQueueItem to it.
    // The existing method takes a SyncQueueItem model.
    // I'll construct a dummy SyncQueueItem with the ID and the new status?
    // But the AppDatabase method uses `item.operationId` for WHERE, and `item.status` for SET.
    // It effectively ignores other fields if it constructs the Companion manually as shown in line 471.
    // YES: lines 471-477 construct a Companion with ONLY status, retry, error, attempt, synced.
    // So I can pass a dummy item with just the ID and the new status!
    // I need to be careful about fields I don't want to change (like retryCount).
    // The method writes `retryCount: Value(item.retryCount)`.
    // So if I pass 0, it overwrites with 0. That's bad.
    // So I MUST fetch first.

    // Or simpler: modifying `AppDatabase` is risky without running build_runner.
    // I will fetch from DB using a simple select query first.

    final itemOrNull = await (_db.select(
      _db.syncQueue,
    )..where((t) => t.operationId.equals(operationId))).getSingleOrNull();

    if (itemOrNull != null) {
      final updatedComp = itemOrNull
          .toCompanion(true)
          .copyWith(
            status: const Value('IN_PROGRESS'),
            lastAttemptAt: Value(DateTime.now()),
          );

      await (_db.update(
        _db.syncQueue,
      )..where((t) => t.operationId.equals(operationId))).write(updatedComp);
    }
  }

  @override
  Future<void> markSynced(
    String operationId, {
    required String collection,
    required String docId,
  }) async {
    final itemOrNull = await (_db.select(
      _db.syncQueue,
    )..where((t) => t.operationId.equals(operationId))).getSingleOrNull();

    if (itemOrNull != null) {
      final updatedComp = itemOrNull
          .toCompanion(true)
          .copyWith(
            status: const Value('SYNCED'),
            syncedAt: Value(DateTime.now()),
          );

      await (_db.update(
        _db.syncQueue,
      )..where((t) => t.operationId.equals(operationId))).write(updatedComp);

      // Mark entity synced
      await _db.markDocumentSynced(collection, docId);
    }
  }

  @override
  Future<void> markFailed(
    String operationId,
    String error,
    int currentRetryCount,
  ) async {
    // currentRetryCount is passed from engine which tracks it
    final itemOrNull = await (_db.select(
      _db.syncQueue,
    )..where((t) => t.operationId.equals(operationId))).getSingleOrNull();

    if (itemOrNull != null) {
      final updatedComp = itemOrNull
          .toCompanion(true)
          .copyWith(
            status: const Value('RETRY'),
            lastError: Value(error),
            retryCount: Value(currentRetryCount),
            lastAttemptAt: Value(DateTime.now()),
          );

      await (_db.update(
        _db.syncQueue,
      )..where((t) => t.operationId.equals(operationId))).write(updatedComp);
    }
  }

  @override
  Future<void> moveToDeadLetter(SyncQueueItem item, String reason) async {
    await _db.moveToDeadLetter(item, reason);
  }

  @override
  Future<SyncStats> getStats() async {
    // We can query the DB for this
    // For now, simpler implementation:
    final pending = (await _db.getPendingSyncItems()).length;
    final dead = await _db.getDeadLetterCount();

    // We don't have easy access to "synced today" without query
    // Let's implement a quick query here
    // But 'syncedToday' was in SyncManager's memory checks.
    // We can query SyncQueue for SYNCED items where syncedAt > today
    // But SyncQueue usually cleans up SYNCED items?
    // SyncManager implementation didn't show cleanup logic in the view,
    // but typically we keep them for a bit or delete them.
    // The AppDatabase `markDocumentSynced` implies we update the Entity table.
    // The SyncQueue table might accumulate SYNCED items.

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final syncedQuery = _db.select(_db.syncQueue)
      ..where(
        (t) =>
            t.status.equals('SYNCED') &
            t.syncedAt.isBiggerOrEqualValue(startOfDay),
      );
    final syncedCount = (await syncedQuery.get()).length;

    final failedQuery = _db.select(_db.syncQueue)
      ..where((t) => t.status.isIn(['FAILED', 'RETRY']));
    final failedCount = (await failedQuery.get()).length;

    // InProgress
    final inProgressQuery = _db.select(_db.syncQueue)
      ..where((t) => t.status.equals('IN_PROGRESS'));
    final inProgressCount = (await inProgressQuery.get()).length;

    return SyncStats(
      pendingCount: pending,
      inProgressCount: inProgressCount,
      failedCount: failedCount,
      deadLetterCount: dead,
      syncedCount: syncedCount,
      lastSyncTime: null, // Hard to get efficient MAX without custom query
    );
  }

  @override
  Future<List<SyncQueueItem>> getFailedItems() async {
    final rows = await (_db.select(
      _db.syncQueue,
    )..where((t) => t.status.isIn(['FAILED', 'RETRY']))).get();

    return rows
        .map(
          (row) => SyncQueueItem(
            operationId: row.operationId,
            operationType: SyncOperationType.fromString(row.operationType),
            targetCollection: row.targetCollection,
            documentId: row.documentId,
            payload: jsonDecode(row.payload),
            status: SyncStatus.fromString(row.status),
            retryCount: row.retryCount,
            lastError: row.lastError,
            createdAt: row.createdAt,
            lastAttemptAt: row.lastAttemptAt,
            syncedAt: row.syncedAt,
            priority: row.priority,
            parentOperationId: row.parentOperationId,
            stepNumber: row.stepNumber,
            totalSteps: row.totalSteps,
            userId: row.userId,
            deviceId: row.deviceId,
            payloadHash: row.payloadHash,
            dependencyGroup: row.dependencyGroup,
            ownerId: row.ownerId,
          ),
        )
        .toList();
  }
}
