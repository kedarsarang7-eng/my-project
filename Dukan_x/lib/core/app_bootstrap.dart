// ============================================================================
// APPLICATION BOOTSTRAP
// ============================================================================
// Central initialization for all enterprise services
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database/app_database.dart';
import 'sync/sync_manager.dart';
import 'sync/sync_queue_local_ops.dart';
import 'sync/sync_status_manager.dart';
import 'sync/background_sync_service.dart';
import 'monitoring/monitoring_service.dart';
import 'database/database_optimizer.dart';
import 'services/deep_link_service.dart';
import '../features/hardware/hardware_module.dart';

/// Application Bootstrap - Initializes all services in correct order
class AppBootstrap {
  static AppBootstrap? _instance;
  static AppBootstrap get instance => _instance ??= AppBootstrap._();

  AppBootstrap._();

  bool _isInitialized = false;
  AppDatabase? _database;
  MonitoringService? _monitoring;
  SyncManager? _syncManager;
  BackgroundSyncService? _backgroundSync;

  // Getters for services
  AppDatabase get database => _database!;
  MonitoringService get monitoringService =>
      _monitoring ?? MonitoringService.instance;
  SyncManager get syncManager => _syncManager!;
  BackgroundSyncService get backgroundSync => _backgroundSync!;

  bool get isInitialized => _isInitialized;

  /// Initialize all enterprise services
  Future<void> initialize({
    required String userId,
    bool enableBackgroundSync = true,
  }) async {
    if (_isInitialized) {
      monitoringService.warning(
        'AppBootstrap',
        'Already initialized, skipping',
      );
      return;
    }

    final stopwatch = Stopwatch()..start();

    try {
      // 1. Initialize Monitoring (first, so we can log everything else)
      _monitoring = MonitoringService.instance;
      await _monitoring!.initialize(
        minLogLevel: kDebugMode ? LogLevel.debug : LogLevel.info,
        enableCrashlytics: !kDebugMode,
      );
      _monitoring!.info(
        'AppBootstrap',
        'Starting enterprise services initialization',
      );
      _monitoring!.setUserId(userId);

      // 2. Initialize Database
      _monitoring!.info('AppBootstrap', 'Initializing local database...');
      _database = AppDatabase.instance;

      // Verify database health
      final healthCheck = await _database!.performHealthCheck(userId);
      _monitoring!.info(
        'AppBootstrap',
        'Database initialized',
        metadata: healthCheck,
      );

      // 2.5. Enable SQLite WAL mode for better performance
      _monitoring!.info('AppBootstrap', 'Enabling database optimizations...');
      final walEnabled = await DatabaseOptimizer.enableWalMode(_database!);
      _monitoring!.info(
        'AppBootstrap',
        'WAL mode: ${walEnabled ? "enabled" : "failed"}',
      );

      // 3. Initialize Sync Manager
      _monitoring!.info('AppBootstrap', 'Initializing sync manager...');
      final syncQueueOps = SyncQueueLocalOpsImpl(_database!);
      _syncManager = SyncManager.instance;
      await _syncManager!.initialize(
        localOperations: syncQueueOps,
        config: const SyncManagerConfig(
          maxConcurrency: 3,
          batchSize: 10,
          autoStart: true,
        ),
      );
      _monitoring!.info('AppBootstrap', 'Sync manager initialized');

      // 3.5 Initialize Sync Status Manager
      _monitoring!.info('AppBootstrap', 'Initializing sync status manager...');
      await SyncStatusManager.instance.initialize();
      _monitoring!.info('AppBootstrap', 'Sync status manager initialized');

      // 3.6 Wire the hardware vertical module into the live app
      // (bugfix.md 2.17). Attaches HardwareSyncHandler to the live SyncManager
      // and HardwareWsHandler to the live realtime transport. Additive and
      // hardware-namespaced — no other vertical's routing or sync changes.
      _monitoring!.info('AppBootstrap', 'Registering hardware module...');
      HardwareModule.instance.register(syncManager: _syncManager!);
      _monitoring!.info('AppBootstrap', 'Hardware module registered');

      // 4. Initialize Background Sync (optional)
      if (enableBackgroundSync) {
        _monitoring!.info('AppBootstrap', 'Initializing background sync...');
        _backgroundSync = BackgroundSyncService.instance;
        await _backgroundSync!.initialize(
          getPendingCount: () async {
            final items = await _database!.getPendingSyncEntries();
            return items.length;
          },
          performSync: () async {
            final stopwatch = Stopwatch()..start();
            try {
              await _syncManager!.forceSyncAll();
              stopwatch.stop();
              final pending = await _database!.getPendingSyncEntries();
              return BackgroundSyncResult(
                success: pending.isEmpty,
                itemsSynced: pending.isEmpty ? 1 : 0,
                itemsFailed: pending.length,
                duration: stopwatch.elapsed,
                timestamp: DateTime.now(),
              );
            } catch (e) {
              stopwatch.stop();
              return BackgroundSyncResult(
                success: false,
                itemsSynced: 0,
                itemsFailed: 1,
                duration: stopwatch.elapsed,
                timestamp: DateTime.now(),
                error: e.toString(),
              );
            }
          },
          config: const BackgroundSyncConfig(
            minIntervalMinutes: 15,
            wifiOnly: false,
            enabled: true,
          ),
        );
        _monitoring!.info('AppBootstrap', 'Background sync initialized');
      }

      // 5. Initialize Deep Link Service (for QR Customer Entry)
      _monitoring!.info('AppBootstrap', 'Initializing Deep Link Service...');
      await DeepLinkService.instance.initialize();
      _monitoring!.info('AppBootstrap', 'Deep Link Service initialized');

      stopwatch.stop();
      _isInitialized = true;
      _monitoring!.info(
        'AppBootstrap',
        'All services initialized',
        metadata: {
          'initializationTimeMs': stopwatch.elapsedMilliseconds,
          'userId': userId.length > 8 ? userId.substring(0, 8) : userId,
        },
      );
    } catch (e, stack) {
      _monitoring?.fatal(
        'AppBootstrap',
        'Failed to initialize services',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Perform health check on all services
  Future<Map<String, dynamic>> performHealthCheck(String userId) async {
    if (!_isInitialized) {
      return {'error': 'Not initialized'};
    }

    final metrics = await _syncManager!.getHealthMetrics();
    return {
      'isInitialized': _isInitialized,
      'database': true,
      'syncManager': metrics.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Shutdown all services gracefully
  Future<void> shutdown() async {
    if (!_isInitialized) return;

    _monitoring?.info('AppBootstrap', 'Shutting down services...');

    try {
      // 1. Stop background sync
      _backgroundSync?.dispose();

      // 1.5 Tear down hardware module live wiring
      await HardwareModule.instance.unregister();

      // 2. Stop sync manager
      _syncManager?.dispose();

      // 3. Close database
      await _database?.close();

      _isInitialized = false;
      _monitoring?.info('AppBootstrap', 'All services shut down gracefully');
      _monitoring?.dispose();
    } catch (e, stack) {
      _monitoring?.error(
        'AppBootstrap',
        'Error during shutdown',
        error: e,
        stackTrace: stack,
      );
    }
  }
}

/// Global shortcut for app bootstrap
AppBootstrap get appBootstrap => AppBootstrap.instance;
