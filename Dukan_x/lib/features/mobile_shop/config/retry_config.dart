/// Retry and Backoff Configuration (Flutter)
///
/// Defines retry budgets, base/max delays, jitter, and throttling behavior
/// for client-side operations (sync push, provider calls, WebSocket reconnect).
///
/// Requirement: 6.38, 7.2–7.3
library;

import 'package:flutter/foundation.dart';

/// A single retry policy.
@immutable
class RetryPolicy {
  /// Maximum retry attempts before giving up.
  final int maxRetries;

  /// Initial delay before first retry.
  final Duration baseDelay;

  /// Maximum delay cap.
  final Duration maxDelay;

  /// Jitter factor (0–1): randomness added to prevent thundering herd.
  final double jitterFactor;

  /// Backoff multiplier per attempt (exponential backoff).
  final double backoffMultiplier;

  const RetryPolicy({
    required this.maxRetries,
    required this.baseDelay,
    required this.maxDelay,
    required this.jitterFactor,
    required this.backoffMultiplier,
  });
}

/// Retry configuration for all Flutter client operations.
@immutable
class RetryConfig {
  /// Sync push retries (outbox → backend).
  final RetryPolicy syncPush;

  /// External provider call retries.
  final RetryPolicy providerCall;

  /// WebSocket reconnection retries.
  final RetryPolicy websocketReconnect;

  /// API request retries (general).
  final RetryPolicy apiRequest;

  const RetryConfig({
    required this.syncPush,
    required this.providerCall,
    required this.websocketReconnect,
    required this.apiRequest,
  });
}

/// Default retry configuration.
const kRetryConfig = RetryConfig(
  syncPush: RetryPolicy(
    maxRetries: 5,
    baseDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 60),
    jitterFactor: 0.25,
    backoffMultiplier: 2.0,
  ),
  providerCall: RetryPolicy(
    maxRetries: 3,
    baseDelay: Duration(milliseconds: 200),
    maxDelay: Duration(seconds: 5),
    jitterFactor: 0.2,
    backoffMultiplier: 2.0,
  ),
  websocketReconnect: RetryPolicy(
    maxRetries: 10,
    baseDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 60),
    jitterFactor: 0.5,
    backoffMultiplier: 1.5,
  ),
  apiRequest: RetryPolicy(
    maxRetries: 3,
    baseDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 10),
    jitterFactor: 0.25,
    backoffMultiplier: 2.0,
  ),
);
