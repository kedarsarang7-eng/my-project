// ============================================================================
// ERROR HANDLER TESTS
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/error/error_handler.dart';

void main() {
  group('AppError', () {
    test('should create with required fields', () {
      final error = AppError(message: 'Test error');

      expect(error.message, 'Test error');
      expect(error.severity, ErrorSeverity.medium);
      expect(error.category, ErrorCategory.unknown);
      expect(error.timestamp, isNotNull);
    });

    test('should create with all fields', () {
      final error = AppError(
        message: 'User-friendly message',
        technicalMessage: 'Technical details',
        severity: ErrorSeverity.high,
        category: ErrorCategory.network,
        context: {'key': 'value'},
      );

      expect(error.message, 'User-friendly message');
      expect(error.technicalMessage, 'Technical details');
      expect(error.severity, ErrorSeverity.high);
      expect(error.category, ErrorCategory.network);
      expect(error.context?['key'], 'value');
    });

    test('toJson should serialize correctly', () {
      final error = AppError(
        message: 'Test',
        severity: ErrorSeverity.critical,
        category: ErrorCategory.database,
      );

      final json = error.toJson();

      expect(json['message'], 'Test');
      expect(json['severity'], 'critical');
      expect(json['category'], 'database');
      expect(json['timestamp'], isNotNull);
    });

    test('toString returns message', () {
      final error = AppError(message: 'My error message');
      expect(error.toString(), 'My error message');
    });
  });

  group('Result', () {
    test('success creates successful result', () {
      final result = Result<int>.success(42);

      expect(result.isSuccess, true);
      expect(result.data, 42);
      expect(result.error, isNull);
    });

    test('failure creates failed result', () {
      final error = AppError(message: 'Failed');
      final result = Result<int>.failure(error);

      expect(result.isSuccess, false);
      expect(result.data, isNull);
      expect(result.error?.message, 'Failed');
    });

    test('fromException creates failed result with AppError', () {
      final exception = Exception('Something went wrong');
      final result = Result<int>.fromException(
        exception,
        StackTrace.current,
        userMessage: 'Custom message',
      );

      expect(result.isSuccess, false);
      expect(result.error?.message, 'Custom message');
    });

    test('when calls success callback on success', () {
      final result = Result<int>.success(42);

      final value = result.when(
        success: (data) => data * 2,
        failure: (error) => -1,
      );

      expect(value, 84);
    });

    test('when calls failure callback on failure', () {
      final result = Result<int>.failure(AppError(message: 'Error'));

      final value = result.when(
        success: (data) => data * 2,
        failure: (error) => -1,
      );

      expect(value, -1);
    });
  });

  group('ErrorHandler.createAppError', () {
    test('detects network errors', () {
      final error = ErrorHandler.createAppError(
        Exception('Connection timeout'),
        null,
      );

      expect(error.category, ErrorCategory.network);
    });

    test('detects auth errors', () {
      final error = ErrorHandler.createAppError(
        Exception('permission-denied'),
        null,
      );

      expect(error.category, ErrorCategory.authentication);
    });

    test('detects database errors', () {
      final error = ErrorHandler.createAppError(
        Exception('SQLite error'),
        null,
      );

      expect(error.category, ErrorCategory.database);
    });

    test('detects validation errors', () {
      final error = ErrorHandler.createAppError(
        Exception('Invalid format'),
        null,
      );

      expect(error.category, ErrorCategory.validation);
    });

    test('detects sync errors', () {
      final error = ErrorHandler.createAppError(
        Exception('Sync conflict detected'),
        null,
      );

      expect(error.category, ErrorCategory.sync);
    });

    test('uses custom message when provided', () {
      final error = ErrorHandler.createAppError(
        Exception('Technical error'),
        null,
        userMessage: 'User friendly message',
      );

      expect(error.message, 'User friendly message');
    });

    test('sets appropriate severity for network errors', () {
      final error = ErrorHandler.createAppError(
        Exception('Network unreachable'),
        null,
      );

      expect(error.severity, ErrorSeverity.medium);
    });

    test('sets high severity for auth errors', () {
      final error = ErrorHandler.createAppError(
        Exception('Unauthenticated request'),
        null,
      );

      expect(error.severity, ErrorSeverity.high);
    });

    test('keeps original error reference', () {
      final original = Exception('Original');
      final error = ErrorHandler.createAppError(original, null);

      expect(error.originalError, original);
    });
  });

  group('ErrorSeverity', () {
    test('has correct order', () {
      expect(ErrorSeverity.low.index < ErrorSeverity.medium.index, true);
      expect(ErrorSeverity.medium.index < ErrorSeverity.high.index, true);
      expect(ErrorSeverity.high.index < ErrorSeverity.critical.index, true);
    });
  });

  group('ErrorCategory', () {
    test('has all expected categories', () {
      expect(ErrorCategory.values, contains(ErrorCategory.network));
      expect(ErrorCategory.values, contains(ErrorCategory.authentication));
      expect(ErrorCategory.values, contains(ErrorCategory.database));
      expect(ErrorCategory.values, contains(ErrorCategory.validation));
      expect(ErrorCategory.values, contains(ErrorCategory.permission));
      expect(ErrorCategory.values, contains(ErrorCategory.fileSystem));
      expect(ErrorCategory.values, contains(ErrorCategory.sync));
      expect(ErrorCategory.values, contains(ErrorCategory.payment));
      expect(ErrorCategory.values, contains(ErrorCategory.unknown));
    });
  });
}
