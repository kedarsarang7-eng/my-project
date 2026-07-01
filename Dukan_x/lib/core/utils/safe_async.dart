// ============================================================================
// SAFE ASYNC UTILITIES
// ============================================================================
// Production-ready async patterns for enterprise applications.
// Provides timeout, retry, and error-safe execution wrappers.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import '../error/error_handler.dart';

/// Execute an async operation safely with timeout and retry support.
///
/// Features:
/// - Automatic retries with exponential backoff
/// - Configurable timeout per attempt
/// - Graceful error handling via Result type
/// - Never throws - always returns Result
///
/// Example:
/// ```dart
/// final result = await safeAsync(
///   operation: () => api.fetchProducts(),
///   errorMessage: 'Failed to load products',
///   maxRetries: 3,
/// );
///
/// result.when(
///   success: (products) => showProducts(products),
///   failure: (error) => showError(error.message),
/// );
/// ```
Future<Result<T>> safeAsync<T>({
  required Future<T> Function() operation,
  Duration timeout = const Duration(seconds: 30),
  int maxRetries = 3,
  String? errorMessage,
  Duration initialDelay = const Duration(milliseconds: 100),
  bool useExponentialBackoff = true,
}) async {
  AppError? lastError;

  for (int attempt = 0; attempt < maxRetries; attempt++) {
    try {
      final result = await operation().timeout(timeout);
      return Result.success(result);
    } on TimeoutException catch (e, stack) {
      lastError = ErrorHandler.createAppError(
        e,
        stack,
        userMessage: errorMessage ?? 'Operation timed out. Please try again.',
        severity: ErrorSeverity.medium,
        category: ErrorCategory.network,
      );
    } catch (e, stack) {
      lastError = ErrorHandler.createAppError(
        e,
        stack,
        userMessage: errorMessage,
      );

      // Don't retry on validation or auth errors
      if (lastError.category == ErrorCategory.validation ||
          lastError.category == ErrorCategory.authentication) {
        break;
      }
    }

    // Wait before retry (with exponential backoff if enabled)
    if (attempt < maxRetries - 1) {
      final delay = useExponentialBackoff
          ? initialDelay *
                (1 << attempt) // 100ms, 200ms, 400ms, etc.
          : initialDelay;
      await Future.delayed(delay);
    }
  }

  return Result.failure(
    lastError ??
        AppError(
          message:
              errorMessage ?? 'Operation failed after $maxRetries attempts',
          severity: ErrorSeverity.medium,
        ),
  );
}

/// Execute multiple async operations in parallel safely.
/// Returns when all complete or first fails (based on [failFast]).
Future<Result<List<T>>> safeAsyncAll<T>({
  required List<Future<T> Function()> operations,
  Duration timeout = const Duration(seconds: 60),
  String? errorMessage,
  bool failFast = true,
}) async {
  try {
    final futures = operations.map((op) => op()).toList();

    final results = await Future.wait(
      futures,
      eagerError: failFast,
    ).timeout(timeout);

    return Result.success(results);
  } catch (e, stack) {
    return Result.failure(
      ErrorHandler.createAppError(e, stack, userMessage: errorMessage),
    );
  }
}

/// Execute an operation with automatic cleanup on error or completion.
/// Similar to Python's context manager or try-with-resources.
Future<Result<T>> safeAsyncWithCleanup<T, R extends Object>({
  required Future<R> Function() setup,
  required Future<T> Function(R resource) operation,
  required Future<void> Function(R resource) cleanup,
  String? errorMessage,
}) async {
  late R resource;
  bool resourceInitialized = false;

  try {
    resource = await setup();
    resourceInitialized = true;
    final result = await operation(resource);
    return Result.success(result);
  } catch (e, stack) {
    return Result.failure(
      ErrorHandler.createAppError(e, stack, userMessage: errorMessage),
    );
  } finally {
    if (resourceInitialized) {
      try {
        await cleanup(resource);
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }
}

/// Debounced async execution.
/// Useful for search-as-you-type and similar patterns.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
  }
}

/// Throttled async execution.
/// Ensures action runs at most once per [interval].
class Throttler {
  final Duration interval;
  DateTime? _lastRun;

  Throttler({this.interval = const Duration(milliseconds: 300)});

  void run(void Function() action) {
    final now = DateTime.now();
    if (_lastRun == null || now.difference(_lastRun!) >= interval) {
      _lastRun = now;
      action();
    }
  }
}

/// Extension to add safe execution to any Future
extension SafeFutureExtension<T> on Future<T> {
  /// Convert this future to a Result type
  Future<Result<T>> toSafe({String? errorMessage}) async {
    try {
      final data = await this;
      return Result.success(data);
    } catch (e, stack) {
      return Result.failure(
        ErrorHandler.createAppError(e, stack, userMessage: errorMessage),
      );
    }
  }

  /// Add timeout with graceful error handling
  Future<Result<T>> withTimeout(
    Duration timeout, {
    String? errorMessage,
  }) async {
    try {
      final data = await this.timeout(timeout);
      return Result.success(data);
    } catch (e, stack) {
      return Result.failure(
        ErrorHandler.createAppError(e, stack, userMessage: errorMessage),
      );
    }
  }
}
