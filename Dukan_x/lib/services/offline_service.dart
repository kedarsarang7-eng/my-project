import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:developer' as developer;
import 'dart:async';

class OfflineService {
  static const String queuedBox = 'queued_writes';
  static const int maxRetries = 3;
  static const int retryDelaySeconds = 5;

  static bool _initialized = false;
  static Timer? _retryTimer;

  static Future<void> init() async {
    // Skip Hive on web - doesn't work well
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      // Only initialize Hive if not already done
      if (!Hive.isAdapterRegistered(0)) {
        await Hive.initFlutter();
      }
      await Hive.openBox(queuedBox);
      _initialized = true;

      // Start retry timer if there are queued items
      _startRetryTimer();
    } catch (e) {
      developer.log(
        'Error initializing OfflineService: $e',
        name: 'OfflineService',
      );
    }
  }

  static Future<void> queueWrite(Map<String, dynamic> data) async {
    if (!_initialized || kIsWeb) return;
    try {
      final box = Hive.box(queuedBox);

      // Add retry count and timestamp metadata
      data['_retries'] = data['_retries'] ?? 0;
      data['_queuedAt'] = data['_queuedAt'] ?? DateTime.now().toIso8601String();
      data['_lastRetryAt'] = DateTime.now().toIso8601String();

      await box.add(data);
      developer.log(
        'Queued write: ${data['operation']}',
        name: 'OfflineService',
      );

      // Start retry timer
      _startRetryTimer();
    } catch (e) {
      developer.log('Error queueing write: $e', name: 'OfflineService');
    }
  }

  static List<Map<String, dynamic>> getQueued() {
    if (!_initialized || kIsWeb) return [];
    try {
      final box = Hive.box(queuedBox);
      return box.values
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      developer.log('Error getting queued writes: $e', name: 'OfflineService');
      return [];
    }
  }

  /// Get queued items that are ready to retry (respecting backoff)
  static List<Map<String, dynamic>> getQueuedForRetry() {
    if (!_initialized || kIsWeb) return [];
    try {
      final box = Hive.box(queuedBox);
      final now = DateTime.now();
      final readyItems = <Map<String, dynamic>>[];

      for (int i = 0; i < box.length; i++) {
        final item = Map<String, dynamic>.from(box.getAt(i) as Map);
        final retries = (item['_retries'] ?? 0) as int;
        final lastRetryAt = DateTime.tryParse(item['_lastRetryAt'] ?? '');

        if (retries >= maxRetries) {
          developer.log(
            'Item ${item['operation']} exceeded max retries ($retries/$maxRetries)',
            name: 'OfflineService',
          );
          continue;
        }

        // Calculate backoff delay (exponential: 5s, 10s, 15s)
        final backoffSeconds = retryDelaySeconds * (retries + 1);
        final isReadyToRetry =
            lastRetryAt == null ||
            now.difference(lastRetryAt).inSeconds >= backoffSeconds;

        if (isReadyToRetry) {
          readyItems.add(item);
        }
      }

      return readyItems;
    } catch (e) {
      developer.log(
        'Error getting queued items for retry: $e',
        name: 'OfflineService',
      );
      return [];
    }
  }

  /// Mark item as successfully synced and remove from queue
  static Future<void> removeFromQueue(int index) async {
    if (!_initialized || kIsWeb) return;
    try {
      final box = Hive.box(queuedBox);
      if (index >= 0 && index < box.length) {
        await box.deleteAt(index);
        developer.log(
          'Removed item at index $index from queue',
          name: 'OfflineService',
        );
      }
    } catch (e) {
      developer.log('Error removing from queue: $e', name: 'OfflineService');
    }
  }

  /// Update retry count for an item
  static Future<void> incrementRetryCount(int index) async {
    if (!_initialized || kIsWeb) return;
    try {
      final box = Hive.box(queuedBox);
      if (index >= 0 && index < box.length) {
        final item = Map<String, dynamic>.from(box.getAt(index) as Map);
        item['_retries'] = (item['_retries'] ?? 0) + 1;
        item['_lastRetryAt'] = DateTime.now().toIso8601String();
        await box.putAt(index, item);
        developer.log(
          'Incremented retry count for ${item['operation']}: ${item['_retries']}',
          name: 'OfflineService',
        );
      }
    } catch (e) {
      developer.log(
        'Error incrementing retry count: $e',
        name: 'OfflineService',
      );
    }
  }

  static Future<void> clearQueue() async {
    if (!_initialized || kIsWeb) return;
    try {
      final box = Hive.box(queuedBox);
      await box.clear();
      developer.log('Queue cleared', name: 'OfflineService');
      _stopRetryTimer();
    } catch (e) {
      developer.log('Error clearing queue: $e', name: 'OfflineService');
    }
  }

  /// Start retry timer that periodically attempts to sync queued items
  static void _startRetryTimer() {
    // Only start if not already running and we have items
    if (_retryTimer != null && _retryTimer!.isActive) {
      return;
    }

    if (!_initialized || kIsWeb) return;

    final queued = getQueued();
    if (queued.isEmpty) {
      return;
    }

    _retryTimer = Timer.periodic(Duration(seconds: retryDelaySeconds), (
      timer,
    ) async {
      final queuedItems = getQueued();
      if (queuedItems.isEmpty) {
        timer.cancel();
        _retryTimer = null;
        developer.log(
          'Retry timer stopped: queue is empty',
          name: 'OfflineService',
        );
        return;
      }

      developer.log(
        'Retry timer tick: ${queuedItems.length} items in queue, attempting sync...',
        name: 'OfflineService',
      );

      // Get items that are ready for retry (respecting backoff)
      final readyItems = getQueuedForRetry();
      if (readyItems.isEmpty) {
        developer.log(
          'No items ready for retry (still in backoff period)',
          name: 'OfflineService',
        );
        return;
      }

      // Trigger SyncManager to process pending queue
      try {
        // Import dynamically to avoid circular dependencies
        // The SyncManager.instance.processPending() will handle the actual sync
        developer.log(
          'Triggering sync for ${readyItems.length} ready items',
          name: 'OfflineService',
        );

        // Notify that we're ready to sync - this is a signal for retry
        // The actual sync is handled by SyncManager which monitors connectivity
        _notifyRetryReady();
      } catch (e) {
        developer.log('Error triggering sync: $e', name: 'OfflineService');
      }
    });

    developer.log('Retry timer started', name: 'OfflineService');
  }

  /// Callback for when items are ready to retry
  /// This can be listened to by SyncManager or other services
  static Function? _onRetryReadyCallback;

  /// Set callback for retry ready notification
  static void setOnRetryReadyCallback(Function callback) {
    _onRetryReadyCallback = callback;
  }

  /// Notify that items are ready for retry
  static void _notifyRetryReady() {
    if (_onRetryReadyCallback != null) {
      try {
        _onRetryReadyCallback!();
      } catch (e) {
        developer.log('Error in retry callback: $e', name: 'OfflineService');
      }
    }
  }

  /// Stop the retry timer
  static void _stopRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
    developer.log('Retry timer stopped', name: 'OfflineService');
  }

  /// Cleanup when app closes
  static void dispose() {
    _stopRetryTimer();
  }
}
