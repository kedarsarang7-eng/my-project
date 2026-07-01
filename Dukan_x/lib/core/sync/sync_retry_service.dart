import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import 'sync_queue_state_machine.dart';

/// Service to handle smart retries of failed sync operations
///
/// Responsibilities:
/// 1. Analyze items in Dead Letter Queue (DLQ)
/// 2. Classify errors (Transient vs Permanent)
/// 3. Reschedule transient failures
class SyncRetryService {
  final AppDatabase _db;
  SyncRetryService(this._db);

  /// Attempt to rescue items from Dead Letter Queue
  Future<int> processDeadLetterQueue() async {
    int rescuedCount = 0;

    debugPrint('SyncRetryService: Checking Dead Letter Queue...');

    // 1. Fetch Dead Letter Items (Returns List<DeadLetterEntity> from AppDatabase)
    final items = await _db.getDeadLetterItems();

    if (items.isEmpty) return 0;

    for (var item in items) {
      final error = item.failureReason; // DeadLetterEntity has failureReason

      // 2. Classify Error
      if (_isTransientError(error)) {
        // 3. Rescue: Move back to Pending
        // Manually map DeadLetterEntity to SyncQueueItem
        final rescuedItem = SyncQueueItem(
          operationId: item.originalOperationId,
          operationType: SyncOperationType.fromString(item.operationType),
          targetCollection: item.targetCollection,
          documentId: item.documentId,
          payload: jsonDecode(item.payload),
          status: SyncStatus.pending, // Reset to pending
          retryCount: 0, // Reset retries
          lastError: 'Rescued from DLQ: $error',
          createdAt: item.firstAttemptAt,
          lastAttemptAt: DateTime.now(),
          userId: item.userId,
          payloadHash: '',
          ownerId: item.userId,
        );

        await _db.updateSyncQueueItem(rescuedItem);

        // Mark DeadLetterEntity as resolved
        await _db.resolveDeadLetter(item.id, 'Rescued by SyncRetryService');

        rescuedCount++;
      } else {
        // Permanent error (Logic, Auth, Validation)
        // Leave in DLQ for manual intervention
      }
    }

    if (rescuedCount > 0) {
      debugPrint('SyncRetryService: Rescued $rescuedCount items from DLQ');
    }

    return rescuedCount;
  }

  /// Determine if an error is likely transient (network/server issues)
  bool _isTransientError(String error) {
    final lowerError = error.toLowerCase();

    // Network / Connection Errors
    if (lowerError.contains('socketexception') ||
        lowerError.contains('timeoutexception') ||
        lowerError.contains('handshakeexception') ||
        lowerError.contains('connection closed') ||
        lowerError.contains('broken pipe') ||
        lowerError.contains('network is unreachable')) {
      return true;
    }

    // Server 5xx Errors
    if (lowerError.contains('500') ||
        lowerError.contains('502') ||
        lowerError.contains('503') ||
        lowerError.contains('internal server error') ||
        lowerError.contains('service unavailable')) {
      return true;
    }

    // Firestore specific transient codes
    if (lowerError.contains('unavailable') || // code-14
        lowerError.contains('deadline-exceeded')) {
      // code-4
      return true;
    }

    // Permanent Errors (Do NOT retry)
    // - permission-denied
    // - not-found (unless create?)
    // - already-exists (conflict handled separately)
    // - credit limit exceeded
    // - period locked

    return false;
  }
}
