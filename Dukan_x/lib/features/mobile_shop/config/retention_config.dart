/// Retention Configuration (Flutter)
///
/// Defines client-side retention policies for local state, outbox, and tokens.
/// Server-side retention (idempotency, audit) is enforced by the backend.
///
/// Requirements: 6.27, 7.2–7.3
library;

import 'package:flutter/foundation.dart';

/// Retention configuration for local data and synchronization.
@immutable
class RetentionConfig {
  /// Maximum age of a queued outbox mutation before considered expired.
  final Duration maxOutboxAge;

  /// Duration to retain resolved conflict records locally.
  final Duration resolvedConflictRetention;

  /// Duration to retain sync event inbox entries after processing.
  final Duration processedEventRetention;

  /// Continuation token validity (must match server config).
  final Duration continuationTokenExpiry;

  /// KPI projection stale threshold for UI indicator.
  final Duration projectionStaleThreshold;

  /// Sync checkpoint retention after successful advancement.
  final Duration checkpointRetention;

  const RetentionConfig({
    required this.maxOutboxAge,
    required this.resolvedConflictRetention,
    required this.processedEventRetention,
    required this.continuationTokenExpiry,
    required this.projectionStaleThreshold,
    required this.checkpointRetention,
  });
}

/// Default retention configuration.
const kRetentionConfig = RetentionConfig(
  maxOutboxAge: Duration(days: 7),
  resolvedConflictRetention: Duration(days: 30),
  processedEventRetention: Duration(days: 3),
  continuationTokenExpiry: Duration(minutes: 5),
  projectionStaleThreshold: Duration(seconds: 60),
  checkpointRetention: Duration(days: 14),
);
