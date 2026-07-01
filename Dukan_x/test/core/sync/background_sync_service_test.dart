// ============================================================================
// BACKGROUND SYNC SERVICE TESTS
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/sync/background_sync_service.dart';

void main() {
  group('BackgroundSyncConfig', () {
    test('should use default values', () {
      const config = BackgroundSyncConfig();

      expect(config.minIntervalMinutes, 15);
      expect(config.wifiOnly, false);
      expect(config.requiresCharging, false);
      expect(config.maxRetries, 3);
      expect(config.enabled, true);
    });

    test('should accept custom values', () {
      const config = BackgroundSyncConfig(
        minIntervalMinutes: 30,
        wifiOnly: true,
        requiresCharging: true,
        maxRetries: 5,
        enabled: false,
      );

      expect(config.minIntervalMinutes, 30);
      expect(config.wifiOnly, true);
      expect(config.requiresCharging, true);
      expect(config.maxRetries, 5);
      expect(config.enabled, false);
    });

    test('toJson should serialize correctly', () {
      const config = BackgroundSyncConfig(
        minIntervalMinutes: 20,
        wifiOnly: true,
      );

      final json = config.toJson();

      expect(json['minIntervalMinutes'], 20);
      expect(json['wifiOnly'], true);
      expect(json['requiresCharging'], false);
    });

    test('fromJson should deserialize correctly', () {
      final config = BackgroundSyncConfig.fromJson({
        'minIntervalMinutes': 45,
        'wifiOnly': true,
        'requiresCharging': true,
        'maxRetries': 10,
        'enabled': false,
      });

      expect(config.minIntervalMinutes, 45);
      expect(config.wifiOnly, true);
      expect(config.requiresCharging, true);
      expect(config.maxRetries, 10);
      expect(config.enabled, false);
    });

    test('fromJson should use defaults for missing values', () {
      final config = BackgroundSyncConfig.fromJson({});

      expect(config.minIntervalMinutes, 15);
      expect(config.wifiOnly, false);
      expect(config.enabled, true);
    });
  });

  group('BackgroundSyncResult', () {
    test('should create success result', () {
      final result = BackgroundSyncResult(
        success: true,
        itemsSynced: 10,
        itemsFailed: 0,
        duration: const Duration(seconds: 5),
        timestamp: DateTime(2024, 1, 1),
      );

      expect(result.success, true);
      expect(result.itemsSynced, 10);
      expect(result.itemsFailed, 0);
      expect(result.duration.inSeconds, 5);
      expect(result.error, isNull);
    });

    test('should create failure result with error', () {
      final result = BackgroundSyncResult(
        success: false,
        itemsSynced: 0,
        itemsFailed: 5,
        duration: const Duration(seconds: 2),
        timestamp: DateTime(2024, 1, 1),
        error: 'Network timeout',
      );

      expect(result.success, false);
      expect(result.itemsFailed, 5);
      expect(result.error, 'Network timeout');
    });

    test('toJson should serialize correctly', () {
      final result = BackgroundSyncResult(
        success: true,
        itemsSynced: 15,
        itemsFailed: 2,
        duration: const Duration(milliseconds: 1500),
        timestamp: DateTime(2024, 1, 15, 10, 30),
        error: null,
      );

      final json = result.toJson();

      expect(json['success'], true);
      expect(json['itemsSynced'], 15);
      expect(json['itemsFailed'], 2);
      expect(json['durationMs'], 1500);
      expect(json['timestamp'], '2024-01-15T10:30:00.000');
      expect(json['error'], isNull);
    });
  });

  group('BackgroundSyncStatus', () {
    test('should have all expected statuses', () {
      expect(BackgroundSyncStatus.values, contains(BackgroundSyncStatus.idle));
      expect(
        BackgroundSyncStatus.values,
        contains(BackgroundSyncStatus.scheduled),
      );
      expect(
        BackgroundSyncStatus.values,
        contains(BackgroundSyncStatus.running),
      );
      expect(
        BackgroundSyncStatus.values,
        contains(BackgroundSyncStatus.completed),
      );
      expect(
        BackgroundSyncStatus.values,
        contains(BackgroundSyncStatus.failed),
      );
      expect(
        BackgroundSyncStatus.values,
        contains(BackgroundSyncStatus.disabled),
      );
    });
  });

  group('BackgroundTaskIds', () {
    test('should have correct task identifiers', () {
      expect(BackgroundTaskIds.periodicSync, 'com.dukanx.periodic_sync');
      expect(BackgroundTaskIds.immediateSync, 'com.dukanx.immediate_sync');
      expect(BackgroundTaskIds.dailyCleanup, 'com.dukanx.daily_cleanup');
      expect(BackgroundTaskIds.deadLetterRetry, 'com.dukanx.dead_letter_retry');
    });
  });

  group('BackgroundSyncService', () {
    setUp(() {
      // Get fresh instance for each test
      // Note: In real tests, you'd want to reset singleton
    });

    test('instance should return singleton', () {
      final instance1 = BackgroundSyncService.instance;
      final instance2 = BackgroundSyncService.instance;

      expect(identical(instance1, instance2), true);
    });

    test('should start with idle status', () {
      final service = BackgroundSyncService.instance;
      expect(service.status, BackgroundSyncStatus.idle);
    });

    test('syncHistory should start empty', () {
      final service = BackgroundSyncService.instance;
      expect(service.syncHistory, isEmpty);
    });

    test('config getter should return current config', () {
      final service = BackgroundSyncService.instance;
      final config = service.config;

      expect(config, isA<BackgroundSyncConfig>());
    });

    test('getStatistics should return valid stats object', () {
      final service = BackgroundSyncService.instance;
      final stats = service.getStatistics();

      expect(stats.containsKey('totalSyncs'), true);
      expect(stats.containsKey('successfulSyncs'), true);
      expect(stats.containsKey('failedSyncs'), true);
      expect(stats.containsKey('successRate'), true);
      expect(stats.containsKey('currentStatus'), true);
      expect(stats.containsKey('isEnabled'), true);
    });

    test('statistics successRate should be 100% with no syncs', () {
      final service = BackgroundSyncService.instance;
      final stats = service.getStatistics();

      // With no sync history, default success rate should be 100
      expect(stats['successRate'], 100.0);
    });
  });
}
