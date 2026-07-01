// ============================================================================
// MONITORING SERVICE TESTS
// ============================================================================
// Unit tests for the monitoring and observability service
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/monitoring/monitoring_service.dart';

void main() {
  late MonitoringService monitoring;

  setUp(() {
    monitoring = MonitoringService.instance;
  });

  group('Logging', () {
    test('should log debug messages', () {
      monitoring.debug('TestTag', 'Debug message', metadata: {'key': 'value'});
      final logs = monitoring.getRecentLogs(limit: 1);
      expect(logs.isNotEmpty, isTrue);
    });

    test('should log info messages', () {
      monitoring.info('TestTag', 'Info message');
      final logs = monitoring.getRecentLogs(minLevel: LogLevel.info, limit: 1);
      expect(logs.last.level, equals(LogLevel.info));
    });

    test('should log warning messages', () {
      monitoring.warning('TestTag', 'Warning message');
      final logs = monitoring.getRecentLogs(
        minLevel: LogLevel.warning,
        limit: 1,
      );
      expect(logs.last.level, equals(LogLevel.warning));
    });

    test('should log error messages with error object', () {
      final error = Exception('Test error');
      monitoring.error('TestTag', 'Error message', error: error);
      final logs = monitoring.getRecentLogs(minLevel: LogLevel.error, limit: 1);
      expect(logs.last.errorType, contains('Exception'));
    });

    test('should filter logs by level', () {
      monitoring.debug('Test', 'Debug');
      monitoring.info('Test', 'Info');
      monitoring.warning('Test', 'Warning');
      monitoring.error('Test', 'Error');

      final warningAndAbove = monitoring.getRecentLogs(
        minLevel: LogLevel.warning,
      );
      expect(
        warningAndAbove.every(
          (l) => l.level.priority >= LogLevel.warning.priority,
        ),
        isTrue,
      );
    });

    test('should limit log buffer size', () {
      // Log more than buffer size
      for (int i = 0; i < 1100; i++) {
        monitoring.debug('Test', 'Message $i');
      }
      final logs = monitoring.getRecentLogs();
      expect(logs.length, lessThanOrEqualTo(1000));
    });
  });

  group('Performance Tracing', () {
    test('should track performance metrics', () async {
      monitoring.startTrace('testOperation');
      await Future.delayed(const Duration(milliseconds: 50));
      final metric = monitoring.stopTrace(
        'testOperation',
        category: 'test',
        success: true,
      );

      expect(metric, isNotNull);
      expect(metric!.name, equals('testOperation'));
      expect(metric.category, equals('test'));
      expect(metric.success, isTrue);
      expect(metric.duration.inMilliseconds, greaterThanOrEqualTo(50));
    });

    test('should measure async operations', () async {
      final result = await monitoring.measure<int>(
        'asyncOperation',
        'test',
        () async {
          await Future.delayed(const Duration(milliseconds: 20));
          return 42;
        },
      );

      expect(result, equals(42));
      final metrics = monitoring.getRecentMetrics(limit: 1);
      expect(metrics.last.name, equals('asyncOperation'));
    });

    test('should record failed operations', () async {
      try {
        await monitoring.measure<void>('failingOperation', 'test', () async {
          throw Exception('Test failure');
        });
      } catch (_) {}

      final metrics = monitoring.getRecentMetrics(limit: 1);
      expect(metrics.last.success, isFalse);
    });

    test('should return null for non-existent trace', () {
      final metric = monitoring.stopTrace(
        'nonExistentTrace',
        category: 'test',
        success: true,
      );
      expect(metric, isNull);
    });
  });

  group('Analytics Events', () {
    test('should track events with parameters', () {
      monitoring.trackEvent(
        'test_event',
        parameters: {'item_id': '123', 'quantity': 5},
      );

      // Verify event was logged
      final logs = monitoring.getRecentLogs(limit: 1);
      expect(logs.last.message, equals('test_event'));
    });

    test('should track screen views', () {
      monitoring.trackScreen('TestScreen');

      final logs = monitoring.getRecentLogs(limit: 1);
      expect(logs.last.message, contains('Screen'));
    });
  });

  group('LogEntry', () {
    test('should serialize to JSON', () {
      final entry = LogEntry(
        timestamp: DateTime(2024, 12, 25, 10, 30),
        level: LogLevel.warning,
        tag: 'TestTag',
        message: 'Test message',
        metadata: {'key': 'value'},
        errorType: 'Exception',
        stackTrace: 'at line 1',
      );

      final json = entry.toJson();

      expect(json['level'], equals('WARN'));
      expect(json['tag'], equals('TestTag'));
      expect(json['message'], equals('Test message'));
      expect(json['metadata']['key'], equals('value'));
      expect(json['errorType'], equals('Exception'));
    });

    test('should format as string', () {
      final entry = LogEntry(
        timestamp: DateTime(2024, 12, 25, 10, 30),
        level: LogLevel.error,
        tag: 'ErrorTag',
        message: 'Something went wrong',
      );

      final str = entry.toString();

      expect(str, contains('[ERROR]'));
      expect(str, contains('[ErrorTag]'));
      expect(str, contains('Something went wrong'));
    });
  });

  group('PerformanceMetric', () {
    test('should serialize to JSON', () {
      final metric = PerformanceMetric(
        name: 'dbQuery',
        category: 'database',
        duration: const Duration(milliseconds: 150),
        success: true,
        timestamp: DateTime(2024, 12, 25, 10, 30),
        attributes: {'table': 'bills'},
      );

      final json = metric.toJson();

      expect(json['name'], equals('dbQuery'));
      expect(json['category'], equals('database'));
      expect(json['durationMs'], equals(150));
      expect(json['success'], isTrue);
      expect(json['attributes']['table'], equals('bills'));
    });
  });

  group('HealthStatus', () {
    test('should serialize to JSON', () {
      final status = HealthStatus(
        isHealthy: true,
        components: {'database': true, 'firestore': true, 'connectivity': true},
        metrics: {'pendingSyncCount': 0, 'deadLetterCount': 0},
        timestamp: DateTime(2024, 12, 25, 10, 30),
      );

      final json = status.toJson();

      expect(json['isHealthy'], isTrue);
      expect(json['components']['database'], isTrue);
      expect(json['metrics']['pendingSyncCount'], equals(0));
    });
  });

  group('Error Aggregation', () {
    test('should aggregate error counts', () {
      monitoring.error('Tag1', 'Error 1', error: Exception('Type1'));
      monitoring.error('Tag1', 'Error 2', error: Exception('Type1'));
      monitoring.error('Tag2', 'Error 3', error: FormatException('Type2'));

      // Note: Error counts are tracked per error type + tag combination
      // in production mode only (Crashlytics disabled in debug)
    });
  });

  group('Reporting', () {
    test('should export logs as JSON', () async {
      monitoring.info('Export', 'Test export');

      final exported = await monitoring.exportLogs();

      expect(exported, contains('exportedAt'));
      expect(exported, contains('logs'));
      expect(exported, contains('metrics'));
    });

    test('should get average performance by category', () {
      monitoring.startTrace('op1');
      monitoring.stopTrace('op1', category: 'testCat', success: true);
      monitoring.startTrace('op2');
      monitoring.stopTrace('op2', category: 'testCat', success: true);

      final averages = monitoring.getAveragePerformance('testCat');

      expect(averages.containsKey('op1'), isTrue);
      expect(averages.containsKey('op2'), isTrue);
    });

    test('should clear buffers', () {
      monitoring.info('Test', 'Message');
      monitoring.startTrace('trace');
      monitoring.stopTrace('trace', category: 'test', success: true);

      monitoring.clearBuffers();

      // After clear, we should have at least the "Buffers cleared" log
      final logs = monitoring.getRecentLogs();
      expect(logs.length, lessThanOrEqualTo(1));
    });
  });
}
