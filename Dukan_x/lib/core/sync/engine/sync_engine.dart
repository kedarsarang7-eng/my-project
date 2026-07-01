import 'dart:async';
import 'package:flutter/foundation.dart';
import '../abstractions/sync_repository.dart';
import 'circuit_breaker.dart';
import 'task_processor.dart';
import '../models/sync_types.dart'; // Was sync_stats.dart
import '../models/sync_failure.dart';
import '../sync_queue_state_machine.dart'; // For SyncQueueItem

/// Headless Sync Engine
/// Orchestrates sync operations without UI coupling.
/// Runs on Microtask queue to avoid blocking frame rendering.
class SyncEngine {
  static SyncEngine? _instance;
  static SyncEngine get instance => _instance ??= SyncEngine._();

  SyncEngine._();

  // Dependencies
  late final SyncRepository _repo;
  late final TaskProcessor _processor;
  final CircuitBreaker _breaker = CircuitBreaker();

  // State
  bool _isInitialized = false;
  bool _isProcessing = false;
  StreamSubscription? _queueSubscription;
  final _statsController = StreamController<SyncStats>.broadcast();
  final _eventController = StreamController<SyncResult>.broadcast();

  /// Public Stats Stream
  Stream<SyncStats> get statsStream => _statsController.stream;

  /// Public Event Stream (for logs)
  Stream<SyncResult> get eventStream => _eventController.stream;

  /// Get Current Stats (Snapshot)
  Future<SyncStats> getStats() => _repo.getStats(); // Added

  /// Watch Pending Items (for UI lists)
  Stream<List<SyncQueueItem>> watchPendingItems() =>
      _repo.watchPendingItems(); // Added

  /// Get Failed Items (for debug/UI)
  Future<List<SyncQueueItem>> getFailedItems() => _repo.getFailedItems();

  /// Initialize Engine
  void initialize({
    required SyncRepository repository,
    TaskProcessor? processor,
  }) {
    if (_isInitialized) return;
    _repo = repository;
    _processor = processor ?? TaskProcessor();
    _isInitialized = true;

    // Start watching queue automatically
    _startWatching();

    debugPrint(
      'SyncEngine: Initialized (Circuit: ${_breaker.isOpen ? "OPEN" : "CLOSED"})',
    );
  }

  void _startWatching() {
    _queueSubscription = _repo.watchPendingItems().listen((items) {
      if (items.isNotEmpty) {
        _scheduleProcessing(items);
      }
      _emitStats();
    });
  }

  /// Manually trigger a sync cycle (e.g. from UI "Sync Now" button)
  Future<void> triggerSync() async {
    if (_isProcessing) return;

    // Fetch pending and process
    final items = await _repo.getPendingItems();
    if (items.isNotEmpty) {
      _scheduleProcessing(items);
    }
  }

  /// Schedule processing on Microtask to unblock UI
  void _scheduleProcessing(List<SyncQueueItem> items) {
    if (_isProcessing) return;

    // Check Circuit Breaker
    if (!_breaker.canExecute) {
      debugPrint('SyncEngine: Circuit OPEN. Skipping batch.');
      return;
    }

    _isProcessing = true;
    _emitStats(); // Update InProgress count

    Future.microtask(() => _processBatch(items));
  }

  /// Process batch logic
  Future<void> _processBatch(List<SyncQueueItem> items) async {
    try {
      // Sort by priority/step (Drift usually does this, but ensure here)
      // items are already sorted by repository query.

      for (final item in items) {
        if (!_breaker.canExecute) break;

        // Skip items that are in retry backoff window
        if (item.status == SyncStatus.retry) {
          if (item.lastAttemptAt != null) {
            // Simple backoff: 1s, 2s, 4s, 8s, 16s
            final delay = Duration(milliseconds: 1000 * (1 << item.retryCount));
            if (DateTime.now().difference(item.lastAttemptAt!) < delay) {
              continue; // Backoff active
            }
          }
        }

        await _repo.markInProgress(item.operationId);

        // Execute
        final stopwatch = Stopwatch()..start();
        try {
          await _processor.process(item);
          stopwatch.stop();

          await _repo.markSynced(
            item.operationId,
            collection: item.targetCollection,
            docId: item.documentId,
          );
          _breaker.onSuccess();

          // Emit Success Event
          _eventController.add(
            SyncResult.success(
              operationId: item.operationId,
              duration: stopwatch.elapsed,
            ),
          );
        } on SyncFailure catch (e) {
          stopwatch.stop();
          unawaited(_handleFailure(item, e));

          // Emit Failure Event
          _eventController.add(
            SyncResult.failure(
              operationId: item.operationId,
              failure: e,
              duration: stopwatch.elapsed,
            ),
          );
        } catch (e) {
          // Unexpected catch-all
          stopwatch.stop();
          final failure = SyncUnknownFailure(
            message: e.toString(),
            originalError: e,
          );
          unawaited(_handleFailure(item, failure));

          // Emit Failure Event
          _eventController.add(
            SyncResult.failure(
              operationId: item.operationId,
              failure: failure,
              duration: stopwatch.elapsed,
            ),
          );
        }
      }
    } catch (e, st) {
      debugPrint('SyncEngine: Fatal Batch Error: $e\n$st');
    } finally {
      _isProcessing = false;
      unawaited(_emitStats());
    }
  }

  Future<void> _handleFailure(SyncQueueItem item, SyncFailure failure) async {
    debugPrint('SyncEngine: Failure for ${item.operationId} - $failure');

    if (failure is SyncDataFailure ||
        failure is SyncConflictFailure ||
        item.retryCount >= 5) {
      // Max 5 retries hardcoded

      // FATAL -> Dead Letter
      await _repo.moveToDeadLetter(item, failure.message);

      // Only record breaker failure for Network/Auth
      if (failure is SyncNetworkFailure || failure is SyncAuthFailure) {
        _breaker.onFailure();
      }
    } else {
      // RETRY
      await _repo.markFailed(
        item.operationId,
        failure.message,
        item.retryCount + 1,
      );

      // Circuit Breaker
      if (failure is SyncNetworkFailure || failure is SyncAuthFailure) {
        _breaker.onFailure();
      }
    }
  }

  Future<void> _emitStats() async {
    try {
      final stats = await _repo.getStats();
      // Inject circuit state
      final fullStats = SyncStats(
        pendingCount: stats.pendingCount,
        inProgressCount: _isProcessing ? stats.inProgressCount : 0, // Approx
        failedCount: stats.failedCount,
        deadLetterCount: stats.deadLetterCount,
        syncedCount: stats.syncedCount,
        isCircuitOpen: _breaker.isOpen,
      );
      _statsController.add(fullStats);
    } catch (e) {
      debugPrint('SyncEngine: Stats emit error $e');
    }
  }

  /// Clean disposal
  void dispose() {
    _queueSubscription?.cancel();
    _statsController.close();
    _eventController.close();
  }
}
