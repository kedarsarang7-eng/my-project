// ============================================================================
// ERROR HANDLING UTILITIES
// ============================================================================
// Centralized, production-ready error handling for DukanX
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../monitoring/monitoring_service.dart';

/// Error severity levels
enum ErrorSeverity {
  /// User can continue - show info snackbar
  low,

  /// User should be aware - show warning dialog
  medium,

  /// Operation failed - show error dialog with retry option
  high,

  /// Critical failure - log + navigate to error screen
  critical,
}

/// Categorized error types for proper handling
enum ErrorCategory {
  network,
  authentication,
  database,
  validation,
  permission,
  fileSystem,
  sync,
  payment,
  unknown,
}

/// Structured app error with context
class AppError implements Exception {
  final String message;
  final String? technicalMessage;
  final ErrorSeverity severity;
  final ErrorCategory category;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;
  final DateTime timestamp;

  AppError({
    required this.message,
    this.technicalMessage,
    this.severity = ErrorSeverity.medium,
    this.category = ErrorCategory.unknown,
    this.originalError,
    this.stackTrace,
    this.context,
  }) : timestamp = DateTime.now();

  @override
  String toString() => message;

  Map<String, dynamic> toJson() => {
    'message': message,
    'technicalMessage': technicalMessage,
    'severity': severity.name,
    'category': category.name,
    'timestamp': timestamp.toIso8601String(),
    'context': context,
  };
}

/// Result type for operations that can fail
class Result<T> {
  final T? data;
  final AppError? error;
  final bool isSuccess;

  Result.success(this.data) : error = null, isSuccess = true;

  Result.failure(this.error) : data = null, isSuccess = false;

  Result.fromException(dynamic e, StackTrace? stack, {String? userMessage})
    : data = null,
      error = ErrorHandler.createAppError(e, stack, userMessage: userMessage),
      isSuccess = false;

  /// Execute callback based on result
  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) {
    if (isSuccess && data != null) {
      return success(data as T);
    } else {
      return failure(error ?? AppError(message: 'Unknown error'));
    }
  }
}

/// Error categories for repository operations
enum RepositoryErrorCategory {
  network,
  authentication,
  validation,
  notFound,
  conflict,
  unknown,
}

/// Result wrapper for repository operations
class RepositoryResult<T> {
  final T? data;
  final bool success;
  final String? errorMessage;
  final RepositoryErrorCategory? errorCategory;

  const RepositoryResult.success(this.data)
    : success = true,
      errorMessage = null,
      errorCategory = null;

  const RepositoryResult.failure(this.errorMessage, [this.errorCategory])
    : data = null,
      success = false;

  bool get isSuccess => success;
  bool get isFailure => !success;
  String? get error => errorMessage; // Alias for cross-compatibility
}

/// Centralized Error Handler
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._();
  static ErrorHandler get instance => _instance;
  ErrorHandler._();

  // For DI compatibility - can take monitoring service
  factory ErrorHandler.withMonitoring(MonitoringService monitoring) {
    return _instance;
  }

  /// Run an async operation safely with error handling
  /// Returns `RepositoryResult<T>` for use in repositories
  Future<RepositoryResult<T>> runSafe<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    try {
      final result = await operation();
      return RepositoryResult.success(result);
    } catch (e, stack) {
      final appError = createAppError(e, stack);
      monitoring.error(
        'ErrorHandler.runSafe',
        'Operation failed: $operationName',
        error: e,
        stackTrace: stack,
      );
      return RepositoryResult.failure(
        appError.message,
        _mapErrorCategory(appError.category),
      );
    }
  }

  /// Map internal ErrorCategory to repository ErrorCategory
  static RepositoryErrorCategory _mapErrorCategory(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return RepositoryErrorCategory.network;
      case ErrorCategory.authentication:
        return RepositoryErrorCategory.authentication;
      case ErrorCategory.validation:
        return RepositoryErrorCategory.validation;
      case ErrorCategory.database:
        return RepositoryErrorCategory.unknown;
      default:
        return RepositoryErrorCategory.unknown;
    }
  }

  /// Create AppError from any exception
  static AppError createAppError(
    dynamic error,
    StackTrace? stackTrace, {
    String? userMessage,
    ErrorSeverity? severity,
    ErrorCategory? category,
  }) {
    // Determine category and message based on error type
    ErrorCategory detectedCategory = category ?? ErrorCategory.unknown;
    ErrorSeverity detectedSeverity = severity ?? ErrorSeverity.medium;
    String message = userMessage ?? 'An unexpected error occurred';
    String? technicalMessage = error.toString();

    final errorStr = error.toString().toLowerCase();

    // Security / Lock / Tamper errors
    if (errorStr.contains('locked') || errorStr.contains('tamper')) {
      detectedCategory = ErrorCategory.permission;
      message = userMessage ?? error.toString().replaceAll('Exception: ', '');
      detectedSeverity = ErrorSeverity.high;
    }
    // Network errors
    else if (errorStr.contains('socket') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        errorStr.contains('network') ||
        errorStr.contains('unreachable')) {
      detectedCategory = ErrorCategory.network;
      message =
          userMessage ??
          'Network connection error. Please check your internet.';
      detectedSeverity = ErrorSeverity.medium;
    }
    // Authentication errors
    else if (errorStr.contains('auth') ||
        errorStr.contains('permission-denied') ||
        errorStr.contains('unauthenticated') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('token')) {
      detectedCategory = ErrorCategory.authentication;
      message = userMessage ?? 'Authentication failed. Please login again.';
      detectedSeverity = ErrorSeverity.high;
    }
    // Firebase/Firestore errors
    else if (errorStr.contains('firestore') ||
        errorStr.contains('firebase') ||
        errorStr.contains('cloud')) {
      if (errorStr.contains('unavailable') || errorStr.contains('offline')) {
        detectedCategory = ErrorCategory.network;
        message =
            userMessage ??
            'Service temporarily unavailable. Data saved locally.';
        detectedSeverity = ErrorSeverity.low;
      } else {
        detectedCategory = ErrorCategory.database;
        message = userMessage ?? 'Database error. Please try again.';
        detectedSeverity = ErrorSeverity.medium;
      }
    }
    // Database errors
    else if (errorStr.contains('database') ||
        errorStr.contains('sqlite') ||
        errorStr.contains('drift') ||
        errorStr.contains('sql')) {
      detectedCategory = ErrorCategory.database;
      message = userMessage ?? 'Local storage error. Please restart the app.';
      detectedSeverity = ErrorSeverity.high;
    }
    // Validation errors
    else if (errorStr.contains('invalid') ||
        errorStr.contains('required') ||
        errorStr.contains('empty') ||
        errorStr.contains('format')) {
      detectedCategory = ErrorCategory.validation;
      message = userMessage ?? 'Invalid input. Please check your data.';
      detectedSeverity = ErrorSeverity.low;
    }
    // File errors
    else if (errorStr.contains('file') ||
        errorStr.contains('path') ||
        errorStr.contains('storage') ||
        errorStr.contains('disk')) {
      detectedCategory = ErrorCategory.fileSystem;
      message = userMessage ?? 'File operation failed.';
      detectedSeverity = ErrorSeverity.medium;
    }
    // Sync errors
    else if (errorStr.contains('sync') ||
        errorStr.contains('conflict') ||
        errorStr.contains('version')) {
      detectedCategory = ErrorCategory.sync;
      message = userMessage ?? 'Sync error. Will retry automatically.';
      detectedSeverity = ErrorSeverity.low;
    }

    return AppError(
      message: message,
      technicalMessage: technicalMessage,
      severity: detectedSeverity,
      category: detectedCategory,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Handle error with logging and optional UI feedback
  static Future<void> handle(
    dynamic error, {
    StackTrace? stackTrace,
    String? userMessage,
    BuildContext? context,
    bool showUI = true,
    VoidCallback? onRetry,
  }) async {
    final appError = error is AppError
        ? error
        : createAppError(error, stackTrace, userMessage: userMessage);

    // Log to monitoring
    monitoring.error(
      'ErrorHandler',
      appError.message,
      error: appError.originalError,
      stackTrace: appError.stackTrace,
      metadata: appError.toJson(),
    );

    // Report high+ severity errors to monitoring service
    if (appError.severity.index >= ErrorSeverity.high.index) {
      try {
        monitoring.fatal(
          'ErrorHandler',
          appError.message,
          error: appError.originalError ?? appError,
          stackTrace: appError.stackTrace,
        );
      } catch (_) {}
    }

    // Show UI feedback if context provided
    if (showUI && context != null && context.mounted) {
      _showErrorUI(context, appError, onRetry: onRetry);
    }
  }

  /// Show appropriate UI based on error severity
  static void _showErrorUI(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    switch (error.severity) {
      case ErrorSeverity.low:
        _showSnackBar(context, error.message, isWarning: false);
        break;
      case ErrorSeverity.medium:
        _showSnackBar(context, error.message, isWarning: true);
        break;
      case ErrorSeverity.high:
        _showErrorDialog(context, error, onRetry: onRetry);
        break;
      case ErrorSeverity.critical:
        _showCriticalErrorDialog(context, error);
        break;
    }
  }

  static void _showSnackBar(
    BuildContext context,
    String message, {
    bool isWarning = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isWarning ? Icons.warning_amber : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isWarning ? Colors.orange.shade700 : Colors.blueGrey,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isWarning ? 4 : 3),
      ),
    );
  }

  static void _showErrorDialog(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Error'),
          ],
        ),
        content: Text(error.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  static void _showCriticalErrorDialog(BuildContext context, AppError error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.report_problem, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Critical Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.message),
            const SizedBox(height: 8),
            Text(
              'Please restart the app. If the problem persists, contact support.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Extension for easy error handling on Futures
extension FutureErrorHandling<T> on Future<T> {
  /// Wrap future in Result type
  Future<Result<T>> toResult({String? errorMessage}) async {
    try {
      final data = await this;
      return Result.success(data);
    } catch (e, stack) {
      return Result.fromException(e, stack, userMessage: errorMessage);
    }
  }

  /// Handle errors with UI feedback
  Future<T?> handleErrors(
    BuildContext context, {
    String? errorMessage,
    VoidCallback? onRetry,
  }) async {
    try {
      return await this;
    } catch (e, stack) {
      await ErrorHandler.handle(
        e,
        stackTrace: stack,
        userMessage: errorMessage,
        context: context,
        onRetry: onRetry,
      );
      return null;
    }
  }
}

/// Run a function with automatic error handling
Future<Result<T>> runSafe<T>(
  Future<T> Function() operation, {
  String? errorMessage,
  BuildContext? context,
  VoidCallback? onRetry,
}) async {
  try {
    final result = await operation();
    return Result.success(result);
  } catch (e, stack) {
    if (context != null) {
      await ErrorHandler.handle(
        e,
        stackTrace: stack,
        userMessage: errorMessage,
        context: context,
        onRetry: onRetry,
      );
    }
    return Result.fromException(e, stack, userMessage: errorMessage);
  }
}
