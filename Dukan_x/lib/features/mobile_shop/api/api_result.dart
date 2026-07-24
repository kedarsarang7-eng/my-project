/// MobileShop API Result — Generic Result Type (Dart)
///
/// Sealed result type for all MobileShop API calls.
/// Never labels a response as committed without AuthoritativeConfirmation.
///
/// Requirements: 6.3–6.4, 6.42, 12.4–12.5
library;

import 'package:flutter/foundation.dart';

import '../config/error_codes_config.dart';
import '../models/confirmation_models.dart';

/// Sealed result representing all possible outcomes of a MobileShop API call.
sealed class ApiResult<T> {
  const ApiResult();
}

/// Successful response with data and optional authoritative confirmation.
///
/// If [confirmation] is null, the response represents informational/query data.
/// Mutation responses that claim committed/current MUST include confirmation.
@immutable
class ApiSuccess<T> extends ApiResult<T> {
  /// The typed response payload.
  final T data;

  /// Authoritative confirmation from the backend.
  /// Present only when the backend has confirmed DynamoDB persistence.
  final AuthoritativeConfirmation? confirmation;

  /// API version returned by the server.
  final int apiVersion;

  /// Data model version of the response.
  final int dataModelVersion;

  /// Server-echoed correlation ID.
  final String? correlationId;

  const ApiSuccess({
    required this.data,
    this.confirmation,
    required this.apiVersion,
    required this.dataModelVersion,
    this.correlationId,
  });
}

/// Domain error response parsed from a structured backend error.
@immutable
class ApiError<T> extends ApiResult<T> {
  /// The deterministic outcome from the error catalog.
  final DeterministicOutcome outcome;

  /// Whether the same request may be safely retried.
  final bool retryable;

  const ApiError({required this.outcome, required this.retryable});

  /// Convenience constructor that derives retryable from the outcome.
  ApiError.fromOutcome({required this.outcome}) : retryable = outcome.retryable;
}

/// Network-level error (timeout, DNS, connection refused, etc.).
@immutable
class ApiNetworkError<T> extends ApiResult<T> {
  /// Human-readable description of the network issue.
  final String message;

  /// Whether the request can be safely retried.
  final bool retryable;

  const ApiNetworkError({required this.message, required this.retryable});
}
