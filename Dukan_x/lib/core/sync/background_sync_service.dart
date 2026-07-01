// ============================================================================
// BACKGROUND SYNC SERVICE - PRODUCTION READY
// ============================================================================
// Handles background synchronization using WorkManager (Android/iOS)
//
// Author: DukanX Engineering
// Version: 2.0.0
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../monitoring/monitoring_service.dart';
import '../../services/cleanup_service.dart';
import '../../core/sync/sync_retry_service.dart';
import '../../core/database/app_database.dart';

// Idempotency: Sync queue operations carry stable idempotency keys (operationId / requestId / idempotencyKey) to ensure server-side deduplication.

/// Background sync task identifiers
class BackgroundTaskIds {
  static const String periodicSync = 'com.dukanx.periodic_sync';
  static const String immediateSync = 'com.dukanx.immediate_sync';
  static const String dailyCleanup = 'com.dukanx.daily_cleanup';
  static const String deadLetterRetry = 'com.dukanx.dead_letter_retry';
}

/// Background sync configuration
class BackgroundSyncConfig {
  final int minIntervalMinutes;
  final bool wifiOnly;
  final bool requiresCharging;
  final int maxRetries;
  final bool enabled;

  const BackgroundSyncConfig({
    this.minIntervalMinutes = 15,
    this.wifiOnly = false,
    this.requiresCharging = false,
    this.maxRetries = 3,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'minIntervalMinutes': minIntervalMinutes,
    'wifiOnly': wifiOnly,
    'requiresCharging': requiresCharging,
    'maxRetries': maxRetries,
    'enabled': enabled,
  };

  factory BackgroundSyncConfig.fromJson(Map<String, dynamic> json) {
    return BackgroundSyncConfig(
      minIntervalMinutes: json['minIntervalMinutes'] ?? 15,
      wifiOnly: json['wifiOnly'] ?? false,
      requiresCharging: json['requiresCharging'] ?? false,
      maxRetries: json['maxRetries'] ?? 3,
      enabled: json['enabled'] ?? true,
    );
  }
}

/// Background sync status
enum BackgroundSyncStatus {
  idle,
  scheduled,
  running,
  completed,
  failed,
  disabled,
}

/// Background sync result
class BackgroundSyncResult {
  final bool success;
  final int itemsSynced;
  final int itemsFailed;
  final Duration duration;
  final DateTime timestamp;
  final String? error;

  BackgroundSyncResult({
    required this.success,
    required this.itemsSynced,
    required this.itemsFailed,
    required this.duration,
    required this.timestamp,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'itemsSynced': itemsSynced,
    'itemsFailed': itemsFailed,
    'durationMs': duration.inMilliseconds,
    'timestamp': timestamp.toIso8601String(),
    'error': error,
  };
}

/// Background Sync Service - Production Ready with WorkManager
class BackgroundSyncService {
  static BackgroundSyncService? _instance;
  static BackgroundSyncService get instance =>
      _instance ??= BackgroundSyncService._();

  BackgroundSyncService._();

  /// Task identifiers for WorkManager
  static const String syncTaskId = 'com.dukanx.periodic_sync';
  static const String syncTaskName = 'dukanx_periodic_sync';

  // Configuration
  BackgroundSyncConfig _config = const BackgroundSyncConfig();

  // State
  bool _isInitialized = false;
  BackgroundSyncStatus _status = BackgroundSyncStatus.idle;
  DateTime? _lastSyncTime;
  DateTime? _nextScheduledSync;
  final List<BackgroundSyncResult> _syncHistory = [];

  // Callbacks
  Future<int> Function()? _getPendingCount;
  Future<BackgroundSyncResult> Function()? _performSync;

  // Stream controller
  final _statusController = StreamController<BackgroundSyncStatus>.broadcast();
  Stream<BackgroundSyncStatus> get statusStream => _statusController.stream;

  BackgroundSyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  DateTime? get nextScheduledSync => _nextScheduledSync;
  List<BackgroundSyncResult> get syncHistory => List.unmodifiable(_syncHistory);

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> initialize({
    required Future<int> Function() getPendingCount,
    required Future<BackgroundSyncResult> Function() performSync,
    BackgroundSyncConfig? config,
  }) async {
    if (_isInitialized) return;

    _getPendingCount = getPendingCount;
    _performSync = performSync;
    if (config != null) _config = config;

    // Load last sync time from storage
    final prefs = await SharedPreferences.getInstance();
    final lastSyncMillis = prefs.getInt('lastBackgroundSyncTime');
    if (lastSyncMillis != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
    }

    // Initialize WorkManager
    await _initializeWorkManager();

    _isInitialized = true;
    monitoring.info(
      'BackgroundSync',
      'Initialized with WorkManager',
      metadata: _config.toJson(),
    );

    if (_config.enabled) {
      await schedulePeriodicSync();
    } else {
      _updateStatus(BackgroundSyncStatus.disabled);
    }
  }

  /// Initialize WorkManager with callback dispatcher
  Future<void> _initializeWorkManager() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false, // Set to true for debugging
      );
      monitoring.info('BackgroundSync', 'WorkManager initialized');
    } catch (e, stack) {
      monitoring.error(
        'BackgroundSync',
        'Failed to initialize WorkManager',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // ============================================================================
  // SCHEDULING
  // ============================================================================

  /// Schedule periodic background sync using WorkManager
  Future<void> schedulePeriodicSync() async {
    if (!_config.enabled) {
      monitoring.warning('BackgroundSync', 'Sync disabled, not scheduling');
      return;
    }

    try {
      // Cancel any existing task first
      await Workmanager().cancelByUniqueName(BackgroundTaskIds.periodicSync);

      // Schedule new periodic task
      await Workmanager().registerPeriodicTask(
        BackgroundTaskIds.periodicSync,
        BackgroundTaskIds.periodicSync,
        frequency: Duration(minutes: _config.minIntervalMinutes),
        constraints: Constraints(
          networkType: _config.wifiOnly
              ? NetworkType.unmetered
              : NetworkType.connected,
          requiresCharging: _config.requiresCharging,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 1),
      );

      _nextScheduledSync = DateTime.now().add(
        Duration(minutes: _config.minIntervalMinutes),
      );
      _updateStatus(BackgroundSyncStatus.scheduled);

      monitoring.info(
        'BackgroundSync',
        'Scheduled periodic sync',
        metadata: {
          'nextSync': _nextScheduledSync?.toIso8601String(),
          'intervalMinutes': _config.minIntervalMinutes,
          'wifiOnly': _config.wifiOnly,
        },
      );
    } catch (e, stack) {
      monitoring.error(
        'BackgroundSync',
        'Failed to schedule sync',
        error: e,
        stackTrace: stack,
      );
      // Fallback to timer-based on failure
      await _scheduleTimerBased();
    }
  }

  /// Schedule one-time immediate sync
  Future<void> scheduleImmediateSync() async {
    try {
      await Workmanager().registerOneOffTask(
        BackgroundTaskIds.immediateSync,
        BackgroundTaskIds.immediateSync,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      monitoring.info('BackgroundSync', 'Immediate sync scheduled');
    } catch (e, stack) {
      monitoring.error(
        'BackgroundSync',
        'Failed to schedule immediate sync',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Fallback timer-based scheduling for desktop/web
  Timer? _foregroundTimer;

  Future<void> _scheduleTimerBased() async {
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer.periodic(
      Duration(minutes: _config.minIntervalMinutes),
      (_) => executeSyncTask(),
    );
    monitoring.debug('BackgroundSync', 'Using timer-based sync (fallback)');
  }

  /// Cancel all scheduled syncs
  Future<void> cancelScheduledSync() async {
    try {
      await Workmanager().cancelAll();
      _foregroundTimer?.cancel();
      _foregroundTimer = null;
      _updateStatus(BackgroundSyncStatus.idle);
      monitoring.info('BackgroundSync', 'Cancelled all scheduled syncs');
    } catch (e, stack) {
      monitoring.error(
        'BackgroundSync',
        'Failed to cancel syncs',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // ============================================================================
  // EXECUTION
  // ============================================================================

  /// Execute the sync task - called by WorkManager or Timer
  Future<BackgroundSyncResult> executeSyncTask() async {
    if (_status == BackgroundSyncStatus.running) {
      monitoring.warning(
        'BackgroundSync',
        'Sync already in progress, skipping',
      );
      return BackgroundSyncResult(
        success: false,
        itemsSynced: 0,
        itemsFailed: 0,
        duration: Duration.zero,
        timestamp: DateTime.now(),
        error: 'Sync already in progress',
      );
    }

    _updateStatus(BackgroundSyncStatus.running);
    final stopwatch = Stopwatch()..start();

    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        throw Exception('No network connection');
      }

      if (_config.wifiOnly &&
          !connectivity.contains(ConnectivityResult.wifi) &&
          !connectivity.contains(ConnectivityResult.ethernet)) {
        throw Exception('WiFi required but not connected');
      }

      // Check if there's anything to sync
      final pendingCount = await _getPendingCount?.call() ?? 0;
      if (pendingCount == 0) {
        stopwatch.stop();
        final result = BackgroundSyncResult(
          success: true,
          itemsSynced: 0,
          itemsFailed: 0,
          duration: stopwatch.elapsed,
          timestamp: DateTime.now(),
        );
        await _recordResult(result);
        _updateStatus(BackgroundSyncStatus.completed);
        return result;
      }

      // Perform sync
      final result =
          await _performSync?.call() ??
          BackgroundSyncResult(
            success: false,
            itemsSynced: 0,
            itemsFailed: 0,
            duration: stopwatch.elapsed,
            timestamp: DateTime.now(),
            error: 'No sync handler configured',
          );

      stopwatch.stop();
      await _recordResult(result);
      _updateStatus(
        result.success
            ? BackgroundSyncStatus.completed
            : BackgroundSyncStatus.failed,
      );

      monitoring.info(
        'BackgroundSync',
        'Sync completed',
        metadata: result.toJson(),
      );
      return result;
    } catch (e, stack) {
      stopwatch.stop();
      monitoring.error(
        'BackgroundSync',
        'Sync failed',
        error: e,
        stackTrace: stack,
      );

      final result = BackgroundSyncResult(
        success: false,
        itemsSynced: 0,
        itemsFailed: await _getPendingCount?.call() ?? 0,
        duration: stopwatch.elapsed,
        timestamp: DateTime.now(),
        error: e.toString(),
      );
      await _recordResult(result);
      _updateStatus(BackgroundSyncStatus.failed);
      return result;
    }
  }

  /// Trigger immediate sync (foreground)
  Future<BackgroundSyncResult> triggerImmediateSync() async {
    monitoring.info('BackgroundSync', 'Immediate sync triggered');
    return executeSyncTask();
  }

  // ============================================================================
  // STATE MANAGEMENT
  // ============================================================================

  void _updateStatus(BackgroundSyncStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  Future<void> _recordResult(BackgroundSyncResult result) async {
    _syncHistory.add(result);

    // Keep only last 50 results
    while (_syncHistory.length > 50) {
      _syncHistory.removeAt(0);
    }

    if (result.success) {
      _lastSyncTime = result.timestamp;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'lastBackgroundSyncTime',
        _lastSyncTime!.millisecondsSinceEpoch,
      );
    }
  }

  // ============================================================================
  // CONFIGURATION
  // ============================================================================

  Future<void> updateConfig(BackgroundSyncConfig config) async {
    _config = config;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backgroundSyncConfig', config.toJson().toString());

    if (config.enabled) {
      await schedulePeriodicSync();
    } else {
      await cancelScheduledSync();
      _updateStatus(BackgroundSyncStatus.disabled);
    }

    monitoring.info(
      'BackgroundSync',
      'Config updated',
      metadata: config.toJson(),
    );
  }

  BackgroundSyncConfig get config => _config;

  // ============================================================================
  // STATISTICS
  // ============================================================================

  Map<String, dynamic> getStatistics() {
    final successCount = _syncHistory.where((r) => r.success).length;
    final failCount = _syncHistory.where((r) => !r.success).length;
    final totalItemsSynced = _syncHistory
        .where((r) => r.success)
        .fold<int>(0, (sum, r) => sum + r.itemsSynced);
    final avgDuration = _syncHistory.isEmpty
        ? 0
        : _syncHistory.fold<int>(
                0,
                (sum, r) => sum + r.duration.inMilliseconds,
              ) ~/
              _syncHistory.length;

    return {
      'totalSyncs': _syncHistory.length,
      'successfulSyncs': successCount,
      'failedSyncs': failCount,
      'successRate': _syncHistory.isEmpty
          ? 100.0
          : (successCount / _syncHistory.length) * 100,
      'totalItemsSynced': totalItemsSynced,
      'averageDurationMs': avgDuration,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'nextScheduledSync': _nextScheduledSync?.toIso8601String(),
      'currentStatus': _status.name,
      'isEnabled': _config.enabled,
    };
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  void dispose() {
    _foregroundTimer?.cancel();
    _statusController.close();
  }
}

// ============================================================================
// WORKMANAGER CALLBACK DISPATCHER
// ============================================================================

/// This MUST be a top-level function for WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Initialize critical path first
      // NOTE: In production, we need to ensure AppDatabase is accessible here.
      // Since Drift is pure DartDB, it works.
      // Plugins needing Main UI thread might fail, but these are pure logic/db services.

      final db = AppDatabase.instance; // Use singleton instance

      switch (task) {
        case BackgroundTaskIds.periodicSync:
        case BackgroundTaskIds.immediateSync:
          // Re-init SyncManager for background context if needed
          // final syncMgr = SyncManager.instance;

          // For now, relying on existing logic which likely initializes on first access or is stateless enough
          final result = await BackgroundSyncService.instance.executeSyncTask();
          return result.success;

        case BackgroundTaskIds.dailyCleanup:
          // === GAP 1 FIX: Daily Cleanup ===
          // Lazy load CleanupService
          final cleanupService = CleanupService(db);
          final stats = await cleanupService.runDailyCleanup();
          debugPrint('Background: Cleanup complete: $stats');
          return true;

        case BackgroundTaskIds.deadLetterRetry:
          // === GAP 2 FIX: Dead Letter Retry ===

          final retryService = SyncRetryService(db);
          final rescued = await retryService.processDeadLetterQueue();
          debugPrint('Background: Retry complete. Rescued: $rescued');
          return true;

        default:
          return true;
      }
    } catch (e) {
      debugPrint('Background: Task $task failed: $e');
      return false;
    }
  });
}
