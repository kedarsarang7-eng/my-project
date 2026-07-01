import 'sync_failure.dart';

/// Represents the result of a single sync operation
class SyncResult {
  final String operationId;
  final bool isSuccess;
  final SyncFailure? failure;
  final DateTime timestamp;
  final Duration duration;

  const SyncResult({
    required this.operationId,
    required this.isSuccess,
    this.failure,
    required this.timestamp,
    required this.duration,
  });

  factory SyncResult.success({
    required String operationId,
    required Duration duration,
  }) {
    return SyncResult(
      operationId: operationId,
      isSuccess: true,
      timestamp: DateTime.now(),
      duration: duration,
    );
  }

  factory SyncResult.failure({
    required String operationId,
    required SyncFailure failure,
    required Duration duration,
  }) {
    return SyncResult(
      operationId: operationId,
      isSuccess: false,
      failure: failure,
      timestamp: DateTime.now(),
      duration: duration,
    );
  }
}

/// Aggregated statistics for the Sync Engine
class SyncStats {
  final int pendingCount;
  final int inProgressCount;
  final int failedCount;
  final int deadLetterCount;
  final int syncedCount;
  final DateTime? lastSyncTime;
  final bool isCircuitOpen;

  const SyncStats({
    this.pendingCount = 0,
    this.inProgressCount = 0,
    this.failedCount = 0,
    this.deadLetterCount = 0,
    this.syncedCount = 0,
    this.lastSyncTime,
    this.isCircuitOpen = false,
  });

  /// True if the engine is completely idle and drained
  bool get isIdle => pendingCount == 0 && inProgressCount == 0;
}
