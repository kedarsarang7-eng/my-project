// ============================================================================
// MONITORING & OBSERVABILITY SERVICE
// ============================================================================
// Enterprise-grade monitoring, logging, and alerting for DukanX
//
// Features:
// - Structured logging with severity levels
// - Performance metrics tracking
// - Error aggregation and reporting
// - Health monitoring
// - Firebase Crashlytics integration
// - Custom analytics events
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Log severity levels
enum LogLevel {
  debug(0, 'DEBUG'),
  info(1, 'INFO'),
  warning(2, 'WARN'),
  error(3, 'ERROR'),
  fatal(4, 'FATAL');

  final int priority;
  final String label;
  const LogLevel(this.priority, this.label);
}

/// Structured log entry
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Map<String, dynamic>? metadata;
  final String? errorType;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.metadata,
    this.errorType,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.label,
    'tag': tag,
    'message': message,
    'metadata': metadata,
    'errorType': errorType,
    'stackTrace': stackTrace,
  };

  @override
  String toString() =>
      '[${level.label}] ${timestamp.toIso8601String()} [$tag] $message';
}

/// Performance metric entry
class PerformanceMetric {
  final String name;
  final String category;
  final Duration duration;
  final bool success;
  final DateTime timestamp;
  final Map<String, dynamic>? attributes;

  PerformanceMetric({
    required this.name,
    required this.category,
    required this.duration,
    required this.success,
    required this.timestamp,
    this.attributes,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'durationMs': duration.inMilliseconds,
    'success': success,
    'timestamp': timestamp.toIso8601String(),
    'attributes': attributes,
  };
}

/// Health status
class HealthStatus {
  final bool isHealthy;
  final Map<String, bool> components;
  final Map<String, dynamic> metrics;
  final DateTime timestamp;

  HealthStatus({
    required this.isHealthy,
    required this.components,
    required this.metrics,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'isHealthy': isHealthy,
    'components': components,
    'metrics': metrics,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Monitoring Service - Singleton
class MonitoringService {
  static MonitoringService? _instance;
  static MonitoringService get instance => _instance ??= MonitoringService._();

  MonitoringService._();

  // Configuration
  LogLevel _minLogLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  bool _crashlyticsEnabled = true;
  int _maxLogBuffer = 1000;

  // State
  bool _isInitialized = false;
  final List<LogEntry> _logBuffer = [];
  final List<PerformanceMetric> _metricsBuffer = [];
  final Map<String, int> _errorCounts = {};
  final Map<String, Stopwatch> _activeTraces = {};

  // Streams for real-time monitoring
  final _logStreamController = StreamController<LogEntry>.broadcast();
  final _metricStreamController =
      StreamController<PerformanceMetric>.broadcast();
  final _healthStreamController = StreamController<HealthStatus>.broadcast();

  Stream<LogEntry> get logStream => _logStreamController.stream;
  Stream<PerformanceMetric> get metricStream => _metricStreamController.stream;
  Stream<HealthStatus> get healthStream => _healthStreamController.stream;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> initialize({
    LogLevel? minLogLevel,
    bool? enableCrashlytics,
    int? maxLogBuffer,
  }) async {
    if (_isInitialized) return;

    if (minLogLevel != null) _minLogLevel = minLogLevel;
    if (enableCrashlytics != null) _crashlyticsEnabled = enableCrashlytics;
    if (maxLogBuffer != null) _maxLogBuffer = maxLogBuffer;

    // Crashlytics removed — error logging handled locally
    if (_crashlyticsEnabled && !kDebugMode) {
      // Errors are captured in local log buffer and exported via exportLogs()
    }

    _isInitialized = true;
    log(LogLevel.info, 'MonitoringService', 'Initialized');
  }

  // ============================================================================
  // LOGGING
  // ============================================================================

  void log(
    LogLevel level,
    String tag,
    String message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.priority < _minLogLevel.priority) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      metadata: metadata,
      errorType: error?.runtimeType.toString(),
      stackTrace: stackTrace?.toString(),
    );

    // Add to buffer
    _logBuffer.add(entry);
    if (_logBuffer.length > _maxLogBuffer) {
      _logBuffer.removeAt(0);
    }

    // Emit to stream
    _logStreamController.add(entry);

    // Console output
    if (kDebugMode) {
      debugPrint(entry.toString());
    }

    // Log errors via dart:developer for monitoring tools
    if (level.priority >= LogLevel.error.priority &&
        _crashlyticsEnabled &&
        !kDebugMode) {
      if (error != null) {
        developer.log(
          '[$tag] $message',
          name: 'MonitoringService',
          level: level == LogLevel.fatal ? 1200 : 1000,
          error: error,
          stackTrace: stackTrace,
        );
      } else {
        developer.log(
          '[$tag] $message',
          name: 'MonitoringService',
          level: 900,
        );
      }

      // Track error counts
      final errorKey = '${error?.runtimeType ?? 'UnknownError'}:$tag';
      _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;
    }
  }

  void debug(String tag, String message, {Map<String, dynamic>? metadata}) =>
      log(LogLevel.debug, tag, message, metadata: metadata);

  void info(String tag, String message, {Map<String, dynamic>? metadata}) =>
      log(LogLevel.info, tag, message, metadata: metadata);

  void warning(String tag, String message, {Map<String, dynamic>? metadata}) =>
      log(LogLevel.warning, tag, message, metadata: metadata);

  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) => log(
    LogLevel.error,
    tag,
    message,
    error: error,
    stackTrace: stackTrace,
    metadata: metadata,
  );

  void fatal(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) => log(
    LogLevel.fatal,
    tag,
    message,
    error: error,
    stackTrace: stackTrace,
    metadata: metadata,
  );

  // ============================================================================
  // PERFORMANCE TRACING
  // ============================================================================

  /// Start a performance trace
  void startTrace(String name) {
    _activeTraces[name] = Stopwatch()..start();
  }

  /// Stop a trace and record the metric
  PerformanceMetric? stopTrace(
    String name, {
    required String category,
    required bool success,
    Map<String, dynamic>? attributes,
  }) {
    final stopwatch = _activeTraces.remove(name);
    if (stopwatch == null) {
      warning('MonitoringService', 'No active trace found for: $name');
      return null;
    }

    stopwatch.stop();
    final metric = PerformanceMetric(
      name: name,
      category: category,
      duration: stopwatch.elapsed,
      success: success,
      timestamp: DateTime.now(),
      attributes: attributes,
    );

    _metricsBuffer.add(metric);
    _metricStreamController.add(metric);

    // Log performance
    final emoji = success ? 'âœ“' : 'âœ—';
    debug(
      'PERF',
      '$emoji $name: ${stopwatch.elapsedMilliseconds}ms',
      metadata: {'category': category, 'success': success, ...?attributes},
    );

    return metric;
  }

  /// Measure an async operation
  Future<T> measure<T>(
    String name,
    String category,
    Future<T> Function() operation, {
    Map<String, dynamic>? attributes,
  }) async {
    startTrace(name);
    try {
      final result = await operation();
      stopTrace(
        name,
        category: category,
        success: true,
        attributes: attributes,
      );
      return result;
    } catch (e, stack) {
      stopTrace(
        name,
        category: category,
        success: false,
        attributes: {...?attributes, 'error': e.toString()},
      );
      error('PERF', 'Operation failed: $name', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // ============================================================================
  // HEALTH MONITORING
  // ============================================================================

  /// Perform health check
  Future<HealthStatus> checkHealth({
    required Future<bool> Function() checkDatabase,
    required Future<bool> Function() checkFirestore,
    required Future<bool> Function() checkConnectivity,
    required Future<int> Function() getPendingSyncCount,
    required Future<int> Function() getDeadLetterCount,
  }) async {
    final components = <String, bool>{};
    final metrics = <String, dynamic>{};

    try {
      components['database'] = await checkDatabase();
    } catch (e) {
      components['database'] = false;
      error('HealthCheck', 'Database check failed', error: e);
    }

    try {
      components['firestore'] = await checkFirestore();
    } catch (e) {
      components['firestore'] = false;
      error('HealthCheck', 'Firestore check failed', error: e);
    }

    try {
      components['connectivity'] = await checkConnectivity();
    } catch (e) {
      components['connectivity'] = false;
    }

    try {
      metrics['pendingSyncCount'] = await getPendingSyncCount();
      components['syncQueue'] = metrics['pendingSyncCount'] < 100;
    } catch (e) {
      components['syncQueue'] = false;
    }

    try {
      metrics['deadLetterCount'] = await getDeadLetterCount();
      components['deadLetter'] = metrics['deadLetterCount'] == 0;
    } catch (e) {
      components['deadLetter'] = false;
    }

    // Add error metrics
    metrics['errorCounts'] = Map.from(_errorCounts);
    metrics['recentLogCount'] = _logBuffer.length;
    metrics['errorLogCount'] = _logBuffer
        .where((l) => l.level.priority >= LogLevel.error.priority)
        .length;

    final isHealthy = components.values.every((v) => v);

    final status = HealthStatus(
      isHealthy: isHealthy,
      components: components,
      metrics: metrics,
      timestamp: DateTime.now(),
    );

    _healthStreamController.add(status);

    if (!isHealthy) {
      warning('HealthCheck', 'System unhealthy', metadata: status.toJson());
    }

    return status;
  }

  // ============================================================================
  // ANALYTICS EVENTS
  // ============================================================================

  void trackEvent(String name, {Map<String, dynamic>? parameters}) {
    info('Analytics', name, metadata: parameters);
    // Firebase Analytics integration
    _sendToFirebaseAnalytics(name, parameters);
  }

  void trackScreen(String screenName) {
    info('Analytics', 'Screen: $screenName');
    // Firebase Analytics integration
    _sendToFirebaseAnalytics('screen_view', {'screen_name': screenName});
  }

  /// Send event to Firebase Analytics (non-blocking)
  void _sendToFirebaseAnalytics(
    String eventName,
    Map<String, dynamic>? parameters,
  ) {
    if (kDebugMode) return; // Skip in debug mode to avoid clutter

    // Use try-catch to handle case where firebase_analytics is not available
    try {
      // Import firebase_analytics dynamically to avoid hard dependency
      // The actual implementation will work when firebase_analytics is added
      // For now, this serves as a documented integration point
      _logAnalyticsEvent(eventName, parameters);
    } catch (e) {
      // Silently fail if analytics not available - non-blocking
      debugPrint('Analytics not available: $e');
    }
  }

  /// Internal method to log analytics event
  /// Analytics events are logged locally via dart:developer.
  void _logAnalyticsEvent(String eventName, Map<String, dynamic>? parameters) {
    // Local analytics logging — Firebase Analytics removed
    developer.log(
      'Analytics: $eventName ${parameters != null ? parameters.toString() : ''}',
      name: 'Analytics',
    );
  }

  void setUserId(String userId) {
    if (_crashlyticsEnabled && !kDebugMode) {
      developer.log('User ID set: ${userId.substring(0, 8)}...', name: 'Analytics');
    }
    info('Analytics', 'User ID set: ${userId.substring(0, 8)}...');
  }

  void setUserProperty(String name, String value) {
    if (_crashlyticsEnabled && !kDebugMode) {
      developer.log('User property: $name = $value', name: 'Analytics');
    }
    debug('Analytics', 'User property: $name = $value');
  }

  // ============================================================================
  // REPORTING
  // ============================================================================

  /// Get recent logs
  List<LogEntry> getRecentLogs({LogLevel? minLevel, int? limit}) {
    var logs = _logBuffer.toList();
    if (minLevel != null) {
      logs = logs.where((l) => l.level.priority >= minLevel.priority).toList();
    }
    if (limit != null && logs.length > limit) {
      logs = logs.sublist(logs.length - limit);
    }
    return logs;
  }

  /// Get error summary
  Map<String, int> getErrorSummary() => Map.from(_errorCounts);

  /// Get performance metrics
  List<PerformanceMetric> getRecentMetrics({int? limit}) {
    if (limit != null && _metricsBuffer.length > limit) {
      return _metricsBuffer.sublist(_metricsBuffer.length - limit);
    }
    return _metricsBuffer.toList();
  }

  /// Get average performance for a category
  Map<String, double> getAveragePerformance(String category) {
    final categoryMetrics = _metricsBuffer
        .where((m) => m.category == category)
        .toList();
    if (categoryMetrics.isEmpty) return {};

    final grouped = <String, List<int>>{};
    for (final m in categoryMetrics) {
      grouped.putIfAbsent(m.name, () => []).add(m.duration.inMilliseconds);
    }

    return grouped.map(
      (name, durations) =>
          MapEntry(name, durations.reduce((a, b) => a + b) / durations.length),
    );
  }

  /// Export logs for debugging
  Future<String> exportLogs() async {
    final data = {
      'exportedAt': DateTime.now().toIso8601String(),
      'logs': _logBuffer.map((l) => l.toJson()).toList(),
      'metrics': _metricsBuffer.map((m) => m.toJson()).toList(),
      'errorSummary': _errorCounts,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Clear buffers (for memory management)
  void clearBuffers() {
    _logBuffer.clear();
    _metricsBuffer.clear();
    _errorCounts.clear();
    info('MonitoringService', 'Buffers cleared');
  }

  /// Dispose
  void dispose() {
    _logStreamController.close();
    _metricStreamController.close();
    _healthStreamController.close();
    _activeTraces.clear();
  }
}

/// Global monitoring shortcuts
MonitoringService get monitoring => MonitoringService.instance;

void logDebug(String tag, String message, {Map<String, dynamic>? metadata}) =>
    monitoring.debug(tag, message, metadata: metadata);

void logInfo(String tag, String message, {Map<String, dynamic>? metadata}) =>
    monitoring.info(tag, message, metadata: metadata);

void logWarning(String tag, String message, {Map<String, dynamic>? metadata}) =>
    monitoring.warning(tag, message, metadata: metadata);

void logError(
  String tag,
  String message, {
  Object? error,
  StackTrace? stackTrace,
  Map<String, dynamic>? metadata,
}) => monitoring.error(
  tag,
  message,
  error: error,
  stackTrace: stackTrace,
  metadata: metadata,
);
