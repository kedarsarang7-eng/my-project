
// Idempotency: Sync queue operations carry stable idempotency keys (operationId / requestId / idempotencyKey) to ensure server-side deduplication.
/// Base class for all sync failures
sealed class SyncFailure implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const SyncFailure({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'SyncFailure: $message (Code: $code)';
}

/// Network-related failures (Connectivity, Timeout, DNS)
/// These are usually RETRYABLE.
class SyncNetworkFailure extends SyncFailure {
  const SyncNetworkFailure({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(code: 'NETWORK_ERROR');
}

/// Authentication failures (Token expired, Permission denied)
/// These are usually FATAL (until re-auth) or RETRYABLE (if token refresh works).
class SyncAuthFailure extends SyncFailure {
  const SyncAuthFailure({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(code: 'AUTH_ERROR');
}

/// Data validation/format failures
/// These are FATAL (Dead Letter Queue).
class SyncDataFailure extends SyncFailure {
  const SyncDataFailure({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(code: 'DATA_ERROR');
}

/// Conflict failures
/// These require manual or automated resolution.
class SyncConflictFailure extends SyncFailure {
  const SyncConflictFailure({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(code: 'CONFLICT_ERROR');
}

/// Unexpected system failures
class SyncUnknownFailure extends SyncFailure {
  const SyncUnknownFailure({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(code: 'UNKNOWN_ERROR');
}
