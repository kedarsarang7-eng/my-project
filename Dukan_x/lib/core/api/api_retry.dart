// ============================================================================
// API RETRY MECHANISM - Exponential Backoff for Failed Requests (P2 FIX)
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/logger_service.dart';

/// Configuration for retry behavior
class RetryConfig {
  /// Maximum number of retry attempts
  final int maxRetries;
  
  /// Initial delay between retries (doubles each time)
  final Duration initialDelay;
  
  /// Maximum delay between retries
  final Duration maxDelay;
  
  /// Multiplier for exponential backoff
  final double backoffMultiplier;
  
  /// HTTP status codes that should trigger a retry
  final List<int> retryableStatusCodes;
  
  /// Exception types that should trigger a retry
  final List<Type> retryableExceptions;
  
  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.retryableStatusCodes = const [408, 429, 500, 502, 503, 504],
    this.retryableExceptions = const [
      TimeoutException,
      SocketException,
      HttpException,
    ],
  });
  
  /// Default configuration for most API calls
  static const defaultConfig = RetryConfig();
  
  /// Aggressive retry for critical operations
  static const aggressiveConfig = RetryConfig(
    maxRetries: 5,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 10),
  );
  
  /// Conservative retry for non-critical operations
  static const conservativeConfig = RetryConfig(
    maxRetries: 2,
    initialDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 10),
  );
}

/// Exception thrown when all retry attempts fail
class RetryExhaustedException implements Exception {
  final String message;
  final List<dynamic> errors;
  final int attemptCount;
  
  RetryExhaustedException({
    required this.message,
    required this.errors,
    required this.attemptCount,
  });
  
  @override
  String toString() => 
    'RetryExhaustedException: $message (after $attemptCount attempts)';
}

/// Retry state for tracking attempts
class _RetryState {
  int attempt = 0;
  final List<dynamic> errors = [];
  Duration currentDelay;
  
  _RetryState(Duration initialDelay) : currentDelay = initialDelay;
  
  void recordError(dynamic error) {
    errors.add(error);
    attempt++;
  }
  
  void calculateNextDelay(double multiplier, Duration maxDelay) {
    currentDelay = Duration(
      milliseconds: (currentDelay.inMilliseconds * multiplier)
          .clamp(0, maxDelay.inMilliseconds)
          .toInt(),
    );
  }
}

/// Execute an operation with retry logic
Future<T> withRetry<T>(
  Future<T> Function() operation, {
  RetryConfig config = RetryConfig.defaultConfig,
  void Function(int attempt, dynamic error)? onRetry,
  bool Function(dynamic error)? shouldRetry,
}) async {
  final state = _RetryState(config.initialDelay);
  
  while (true) {
    try {
      return await operation();
    } catch (error) {
      state.recordError(error);
      
      // Check if we should retry this error
      final shouldRetryThis = shouldRetry?.call(error) ?? 
          _defaultShouldRetry(error, config);
      
      if (!shouldRetryThis || state.attempt >= config.maxRetries) {
        throw RetryExhaustedException(
          message: 'All retry attempts failed',
          errors: state.errors,
          attemptCount: state.attempt,
        );
      }
      
      // Notify about retry
      onRetry?.call(state.attempt, error);
      
      if (kDebugMode) {
        LoggerService.d('ApiRetry', '[Retry] Attempt ${state.attempt}/${config.maxRetries} '
            'failed: $error. Retrying in ${state.currentDelay.inMilliseconds}ms...');
      }
      
      // Wait before retry
      await Future.delayed(state.currentDelay);
      
      // Calculate next delay
      state.calculateNextDelay(
        config.backoffMultiplier,
        config.maxDelay,
      );
    }
  }
}

/// Default retry decision logic
bool _defaultShouldRetry(dynamic error, RetryConfig config) {
  // Check exception type
  for (final type in config.retryableExceptions) {
    if (error.runtimeType == type) {
      return true;
    }
  }
  
  // Check for HTTP status codes
  if (error is ApiException) {
    return config.retryableStatusCodes.contains(error.statusCode);
  }
  
  // Check for Dio errors
  if (error.toString().contains('DioError')) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('timeout') ||
           errorStr.contains('connection') ||
           errorStr.contains('socket');
  }
  
  return false;
}

/// API Exception with status code
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic body;
  
  ApiException({
    required this.message,
    required this.statusCode,
    this.body,
  });
  
  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// Mixin for adding retry capability to services
mixin RetryableOperations {
  RetryConfig get retryConfig => RetryConfig.defaultConfig;
  
  Future<T> retry<T>(
    Future<T> Function() operation, {
    RetryConfig? customConfig,
    void Function(int attempt, dynamic error)? onRetry,
  }) async {
    return withRetry(
      operation,
      config: customConfig ?? retryConfig,
      onRetry: onRetry,
    );
  }
}

/// Circuit breaker for preventing cascade failures
class CircuitBreaker {
  final int failureThreshold;
  final Duration resetTimeout;
  
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  bool _isOpen = false;
  
  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(minutes: 1),
  });
  
  bool get isOpen {
    if (!_isOpen) return false;
    
    // Check if we should try to close the circuit
    if (_lastFailureTime != null) {
      final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);
      if (timeSinceLastFailure > resetTimeout) {
        _isOpen = false;
        _failureCount = 0;
        return false;
      }
    }
    
    return true;
  }
  
  void recordSuccess() {
    _failureCount = 0;
    _isOpen = false;
  }
  
  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    
    if (_failureCount >= failureThreshold) {
      _isOpen = true;
    }
  }
  
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (isOpen) {
      throw Exception('Circuit breaker is open - too many failures');
    }
    
    try {
      final result = await operation();
      recordSuccess();
      return result;
    } catch (e) {
      recordFailure();
      rethrow;
    }
  }
}

/// Retry statistics for monitoring
class RetryStatistics {
  int totalAttempts = 0;
  int successfulRetries = 0;
  int failedRetries = 0;
  final Map<String, int> errorTypeCounts = {};
  
  void recordAttempt() => totalAttempts++;
  void recordSuccess() => successfulRetries++;
  void recordFailure(String errorType) {
    failedRetries++;
    errorTypeCounts[errorType] = (errorTypeCounts[errorType] ?? 0) + 1;
  }
  
  double get successRate => 
    totalAttempts > 0 ? successfulRetries / totalAttempts : 0.0;
  
  Map<String, dynamic> toJson() => {
    'totalAttempts': totalAttempts,
    'successfulRetries': successfulRetries,
    'failedRetries': failedRetries,
    'successRate': successRate,
    'errorTypeCounts': errorTypeCounts,
  };
}

// Global retry statistics for monitoring
final retryStats = RetryStatistics();

/// Enhanced retry with statistics tracking
Future<T> withRetryAndStats<T>(
  Future<T> Function() operation, {
  String? operationName,
  RetryConfig config = RetryConfig.defaultConfig,
}) async {
  retryStats.recordAttempt();
  
  try {
    final result = await withRetry(
      operation,
      config: config,
      onRetry: (attempt, error) {
        if (kDebugMode) {
          LoggerService.d('ApiRetry', '[RetryStats] $operationName: Retry attempt $attempt');
        }
      },
    );
    
    retryStats.recordSuccess();
    return result;
  } catch (e) {
    retryStats.recordFailure(e.runtimeType.toString());
    rethrow;
  }
}
