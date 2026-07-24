/// MobileShop Sync Types — Shared Synchronization DTOs (Dart)
///
/// Result types and enumerations shared across the sync coordinator,
/// outbox push service, and pull service.
///
/// Requirements: 7.2–7.9, 7.13–7.15
library;

import 'package:flutter/foundation.dart';

/// Result of a full push + pull synchronization cycle.
@immutable
class SyncCycleResult {
  /// Number of mutations successfully pushed to the server.
  final int pushedCount;

  /// Number of change events pulled and applied locally.
  final int pulledCount;

  /// Number of durable conflicts created during this cycle.
  final int conflictsCreated;

  /// Whether the server indicated more pull data is available.
  final bool hasMorePull;

  const SyncCycleResult({
    required this.pushedCount,
    required this.pulledCount,
    required this.conflictsCreated,
    required this.hasMorePull,
  });

  /// Empty result for no-op or error cases.
  static const empty = SyncCycleResult(
    pushedCount: 0,
    pulledCount: 0,
    conflictsCreated: 0,
    hasMorePull: false,
  );

  /// Whether any work was performed during this cycle.
  bool get hasWork =>
      pushedCount > 0 || pulledCount > 0 || conflictsCreated > 0;

  SyncCycleResult copyWith({
    int? pushedCount,
    int? pulledCount,
    int? conflictsCreated,
    bool? hasMorePull,
  }) => SyncCycleResult(
    pushedCount: pushedCount ?? this.pushedCount,
    pulledCount: pulledCount ?? this.pulledCount,
    conflictsCreated: conflictsCreated ?? this.conflictsCreated,
    hasMorePull: hasMorePull ?? this.hasMorePull,
  );

  @override
  String toString() =>
      'SyncCycleResult(pushed=$pushedCount, pulled=$pulledCount, '
      'conflicts=$conflictsCreated, hasMore=$hasMorePull)';
}

/// Result of an individual push operation for one mutation.
enum PushOutcome {
  /// Successfully committed on the server.
  committed,

  /// Accepted pending reconciliation.
  acceptedPending,

  /// Conflict detected — durable conflict created.
  conflict,

  /// Rejected by the server (not retryable).
  rejected,

  /// Already applied (idempotent replay).
  alreadyApplied,

  /// Network error — left as queued for next cycle.
  networkError,
}

/// Result of the pull phase.
@immutable
class PullPhaseResult {
  /// Number of change events applied locally.
  final int appliedCount;

  /// Number of conflicts created from version collisions.
  final int conflictsCreated;

  /// Whether more pages remain on the server.
  final bool hasMore;

  const PullPhaseResult({
    required this.appliedCount,
    required this.conflictsCreated,
    required this.hasMore,
  });

  static const empty = PullPhaseResult(
    appliedCount: 0,
    conflictsCreated: 0,
    hasMore: false,
  );
}
