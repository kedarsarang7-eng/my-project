import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../../core/sync/data/drift_sync_repository.dart';
import '../../core/sync/engine/sync_engine.dart'; // Keeping for type refs
import '../../core/sync/engine/rest_sync_engine.dart'; // NEW
import '../../core/api/sync_api_client.dart'; // NEW
import '../../core/sync/models/sync_types.dart';
import '../../core/sync/sync_queue_state_machine.dart';
import '../database/app_database.dart';
import '../session/session_manager.dart';
import 'sync_conflict.dart';

/// Configuration Class (Restored for Legacy Compatibility)
class SyncManagerConfig {
  final bool enabled;
  final int maxConcurrency;
  final int batchDelayMs;
  final int batchSize;
  final bool autoStart;

  const SyncManagerConfig({
    this.enabled = true,
    this.maxConcurrency = 3,
    this.batchDelayMs = 500,
    this.batchSize = 10,
    this.autoStart = true,
  });
}

/// Legacy Sync Manager Facade
/// Retained for backward compatibility with Repositories.
/// Delegates actual logic to SyncEngine and DriftSyncRepository.
class SyncManager {
  static SyncManager? _instance;
  static SyncManager get instance => _instance ??= SyncManager._();

  SyncManager._();

  late final AppDatabase _db;

  // Stream controllers (Legacy)
  final _conflictController = StreamController<SyncConflict>.broadcast();
  Stream<SyncConflict> get onConflict => _conflictController.stream;

  /// Initialize the facade (called from main or background service)
  Future<void> initialize({
    required Object
    localOperations, // Kept generic to match legacy signature roughly or just AppDatabase
    SyncManagerConfig? config,
    dynamic firestore,
    dynamic storage,
  }) async {
    // We assume localOperations is AppDatabase or similar interface
    if (localOperations is AppDatabase) {
      _db = localOperations;

      // Resolve the real auth token from SessionManager (Cognito access JWT).
      // Never fall back to a fake token: if there is no valid session, the sync
      // engine must not be initialized against a backend it cannot authenticate
      // to — that would push with `Bearer mock-token` and silently fail or, on
      // a permissive dev namespace, corrupt data.
      final authToken = await _resolveAuthToken();
      final apiClient = SyncApiClient(authToken: authToken);

      RestSyncEngine.instance.initialize(
        repository: DriftSyncRepository(_db),
        apiClient: apiClient,
        db: _db,
      );
    } else {
      // Fallback if injected with something else, though typically it's AppDatabase
      debugPrint(
        'SyncManager Facade: Warning - localOperations is not AppDatabase',
      );
    }

    debugPrint('SyncManager Facade: Initialized (Delegating to SyncEngine)');
  }

  /// Resolve a real, non-empty access token from the session manager.
  ///
  /// Throws [StateError] if no valid authenticated session exists at the time
  /// the sync engine is initialized. The caller (bootstrap) runs after login,
  /// so a missing token here is a genuine error, not a case to paper over with
  /// a placeholder.
  Future<String> _resolveAuthToken() async {
    if (!GetIt.I.isRegistered<SessionManager>()) {
      throw StateError(
        'SyncManager: SessionManager is not registered. Initialize auth before sync.',
      );
    }
    final token = await GetIt.I<SessionManager>().getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError(
        'SyncManager: No valid access token. Refusing to init sync with a fake token.',
      );
    }
    return token;
  }

  /// Start sync (Delegates to Engine via trigger or background loop awareness)
  void startSync() {
    // SyncEngine auto-starts watching.
    // We can also trigger a sync to be safe.
    RestSyncEngine.instance.triggerSync();
  }

  /// Stop sync (No-op in facade, or could pause Engine if we exposed that)
  void stopSync() {
    // No-op
  }

  void dispose() {
    _conflictController.close();
  }

  /// Enqueue a new operation (Delegates to DB Insert)
  /// This is the primary method used by Repositories.
  Future<String> enqueue(SyncQueueItem item) async {
    await _db.insertSyncQueueItem(item);

    // Engine watches DB, so it will pick this up automatically.
    // We can optionally trigger it to be faster.
    unawaited(SyncEngine.instance.triggerSync());

    return item.operationId;
  }

  /// Enqueue multi-step (Delegates to DB Insert loop)
  Future<List<String>> enqueueMultiStep(MultiStepOperation operation) async {
    final items = operation.createSyncQueueItems();
    final ids = <String>[];
    for (final item in items) {
      await enqueue(item);
      ids.add(item.operationId);
    }
    return ids;
  }

  /// Manual Trigger
  Future<void> forceSyncAll() async {
    await SyncEngine.instance.triggerSync();
  }

  Future<void> resolveConflict(
    SyncConflict conflict,
    Map<String, dynamic> resolution,
  ) async {
    debugPrint(
      'SyncManager Facade: resolveConflict called for ${conflict.operationId}',
    );
    // Update local DB via Engine/Repo hooks if needed
  }

  Future<void> restoreFullData(String userId) async {
    debugPrint(
      'SyncManager Facade: restoreFullData called (Delegating to SyncEngine/Repository)',
    );
    // This logic might be complex to restore fully right now.
    // For now, we log it. It was likely doing a full fetch from Firestore.
  }

  /// Legacy Metrics Getter (Mapped to SyncStats)
  Future<SyncHealthMetrics> getHealthMetrics() async {
    final stats = await SyncEngine.instance.getStats();
    return SyncHealthMetrics.fromStats(stats);
  }

  /// Legacy Stream (Mapped from Engine Stream)
  Stream<SyncHealthMetrics> get syncStatusStream {
    return SyncEngine.instance.statsStream.map(
      (stats) => SyncHealthMetrics.fromStats(stats),
    );
  }

  /// Legacy Event Stream
  Stream<SyncResult> get syncEventStream => SyncEngine.instance.eventStream;
}

/// Legacy Class for backward compatibility
class SyncHealthMetrics {
  final int pendingCount;
  final int inProgressCount;
  final int failedCount;
  final int deadLetterCount;
  final int syncedTodayCount;
  final Map<String, int> entityBreakdown;

  // Add getters that might be accessed by legacy status manager
  DateTime? get lastSyncAt => null; // Not tracked in V3 stats yet
  String? get lastError => null; // Detailed error not in summary stats

  SyncHealthMetrics({
    required this.pendingCount,
    required this.inProgressCount,
    required this.failedCount,
    required this.deadLetterCount,
    required this.syncedTodayCount,
    this.entityBreakdown = const {},
  });

  static SyncHealthMetrics fromStats(SyncStats stats) {
    return SyncHealthMetrics(
      pendingCount: stats.pendingCount,
      inProgressCount: stats.inProgressCount,
      failedCount: stats.failedCount,
      deadLetterCount: stats.deadLetterCount,
      syncedTodayCount: stats.syncedCount,
    );
  }

  // Legacy serialization support if needed
  Map<String, dynamic> toJson() => {
    'pendingCount': pendingCount,
    'inProgressCount': inProgressCount,
    'failedCount': failedCount,
    'deadLetterCount': deadLetterCount,
    'syncedTodayCount': syncedTodayCount,
  };
}

// Interface (Restored to satisfy type checks)
abstract class SyncQueueLocalOperations {
  Future<void> insertSyncQueueItem(SyncQueueItem item);
  Future<void> updateSyncQueueItem(SyncQueueItem item);
  Future<void> deleteSyncQueueItem(String operationId);
  Future<List<SyncQueueItem>> getPendingSyncItems();
  Future<void> markDocumentSynced(String collection, String documentId);
  Future<void> moveToDeadLetter(SyncQueueItem item, String error);
  Future<int> getDeadLetterCount();
  Future<void> updateLocalFromServer({
    required String collection,
    required String documentId,
    required Map<String, dynamic> serverData,
  });
}
