// ============================================================================
// SYNC QUEUE LOCAL OPERATIONS - DRIFT IMPLEMENTATION
// ============================================================================
// Implements the abstract SyncQueueLocalOperations interface using Drift
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../sync/sync_queue_state_machine.dart';
import '../sync/sync_manager.dart';

/// Drift implementation of SyncQueueLocalOperations
class SyncQueueLocalOpsImpl implements SyncQueueLocalOperations {
  final AppDatabase _db;

  SyncQueueLocalOpsImpl(this._db);

  @override
  Future<void> insertSyncQueueItem(SyncQueueItem item) async {
    await _db.insertSyncQueueEntry(
      SyncQueueCompanion.insert(
        operationId: item.operationId,
        operationType: item.operationType.value,
        targetCollection: item.targetCollection,
        documentId: item.documentId,
        payload: jsonEncode(item.payload),
        payloadHash: Value(item.payloadHash),
        status: Value(item.status.value),
        retryCount: Value(item.retryCount),
        lastError: Value(item.lastError),
        createdAt: item.createdAt,
        lastAttemptAt: Value(item.lastAttemptAt),
        syncedAt: Value(item.syncedAt),
        priority: Value(item.priority),
        parentOperationId: Value(item.parentOperationId),
        stepNumber: Value(item.stepNumber),
        totalSteps: Value(item.totalSteps),
        userId: item.userId,
        deviceId: Value(item.deviceId),
        dependencyGroup: Value(item.dependencyGroup),
        ownerId: Value(item.ownerId),
      ),
    );
  }

  @override
  Future<void> updateSyncQueueItem(SyncQueueItem item) async {
    await _db.updateSyncQueueEntry(
      SyncQueueEntry(
        operationId: item.operationId,
        operationType: item.operationType.value,
        targetCollection: item.targetCollection,
        documentId: item.documentId,
        payload: jsonEncode(item.payload),
        payloadHash: item.payloadHash,
        status: item.status.value,
        retryCount: item.retryCount,
        lastError: item.lastError,
        createdAt: item.createdAt,
        lastAttemptAt: item.lastAttemptAt,
        syncedAt: item.syncedAt,
        priority: item.priority,
        parentOperationId: item.parentOperationId,
        stepNumber: item.stepNumber,
        totalSteps: item.totalSteps,
        userId: item.userId,
        deviceId: item.deviceId,
        dependencyGroup: item.dependencyGroup,
        ownerId: item.ownerId,
      ),
    );
  }

  @override
  Future<void> deleteSyncQueueItem(String operationId) async {
    await _db.deleteSyncQueueEntry(operationId);
  }

  @override
  Future<List<SyncQueueItem>> getPendingSyncItems() async {
    final entries = await _db.getPendingSyncEntries();
    return entries.map((e) => _entryToItem(e)).toList();
  }

  @override
  Future<void> markDocumentSynced(String collection, String documentId) async {
    // Update the appropriate table based on collection name
    switch (collection) {
      case 'bills':
        await _db.markBillSynced(documentId, null);
        break;
      case 'customers':
        await _db.markCustomerSynced(documentId, null);
        break;
      // Add more collections as needed
    }
  }

  @override
  Future<void> moveToDeadLetter(SyncQueueItem item, String error) async {
    await _db.insertDeadLetter(
      DeadLetterQueueCompanion.insert(
        id: 'dl_${item.operationId}',
        originalOperationId: item.operationId,
        userId: item.userId,
        operationType: item.operationType.value,
        targetCollection: item.targetCollection,
        documentId: item.documentId,
        payload: jsonEncode(item.payload),
        failureReason: error,
        totalAttempts: item.retryCount,
        firstAttemptAt: item.createdAt,
        lastAttemptAt: item.lastAttemptAt ?? DateTime.now(),
        movedToDeadLetterAt: DateTime.now(),
      ),
    );
  }

  /// Convert database entry to domain model
  SyncQueueItem _entryToItem(SyncQueueEntry entry) {
    return SyncQueueItem(
      operationId: entry.operationId,
      operationType: SyncOperationType.fromString(entry.operationType),
      targetCollection: entry.targetCollection,
      documentId: entry.documentId,
      payload: jsonDecode(entry.payload) as Map<String, dynamic>,
      status: SyncStatus.fromString(entry.status),
      retryCount: entry.retryCount,
      lastError: entry.lastError,
      createdAt: entry.createdAt,
      lastAttemptAt: entry.lastAttemptAt,
      syncedAt: entry.syncedAt,
      priority: entry.priority,
      parentOperationId: entry.parentOperationId,
      stepNumber: entry.stepNumber,
      totalSteps: entry.totalSteps,
      userId: entry.userId,
      deviceId: entry.deviceId,
      payloadHash: entry.payloadHash,
      dependencyGroup: entry.dependencyGroup,
      ownerId: entry.ownerId,
    );
  }

  @override
  Future<int> getDeadLetterCount() async {
    final items = await _db.getDeadLetterItems();
    return items.length;
  }

  @override
  Future<void> updateLocalFromServer({
    required String collection,
    required String documentId,
    required Map<String, dynamic> serverData,
  }) async {
    // Update local database with server data after conflict resolution
    // This ensures eventual consistency
    switch (collection) {
      case 'bills':
        await _db.updateBillFromServer(documentId, serverData);
        break;
      case 'customers':
        await _db.updateCustomerFromServer(documentId, serverData);
        break;
      case 'products':
        await _db.updateProductFromServer(documentId, serverData);
        break;
      default:
        // Log unknown collection
        break;
    }
  }
}
