import '../models/sync_types.dart';
import '../sync_queue_state_machine.dart'; // Fixed import for SyncQueueItem
// import '../../database/app_database.dart';els/sync_status_models.dart';

/// Abstract interface for Sync persistence operations.
/// This decouples the Engine from Drift, allowing for testing or swapping.
abstract class SyncRepository {
  /// Stream of pending sync items
  Stream<List<SyncQueueItem>> watchPendingItems();

  /// Get pending items (Snapshot)
  Future<List<SyncQueueItem>> getPendingItems();

  /// Mark item as In Progress
  Future<void> markInProgress(String operationId);

  /// Mark item as Synced and update local entities
  Future<void> markSynced(
    String operationId, {
    required String collection,
    required String docId,
  });

  /// Mark item as Failed (Retryable) with backoff
  Future<void> markFailed(
    String operationId,
    String error,
    int currentRetryCount,
  );

  /// Move item to Dead Letter Queue (Fatal)
  Future<void> moveToDeadLetter(SyncQueueItem item, String reason);

  /// Get current Sync Stats
  Future<SyncStats> getStats();

  /// Get failed items (for manual inspection/retry)
  Future<List<SyncQueueItem>> getFailedItems();
}
