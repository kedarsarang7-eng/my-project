// ============================================================================
// MOBILE SHOP — LIVE KPI STATE MODEL
// ============================================================================
// Defines the sealed [KpiState] hierarchy representing loading, current,
// empty, stale, unavailable, and error states with watermark/version metadata.
//
// A KPI value is NEVER shown as "current" unless backed by confirmed
// (not pending) data with a valid watermark.
//
// Requirements: 9.1–9.6, 9.13, 12.10; Audit: AF-33, AF-47
// ============================================================================

import 'package:flutter/foundation.dart';

/// Metadata about the freshness and version of a KPI data source.
@immutable
class KpiWatermark {
  /// The server data version associated with this KPI snapshot.
  final int dataVersion;

  /// When the data was last confirmed (server-side confirmation time).
  final DateTime confirmedAt;

  /// When the local refresh last succeeded.
  final DateTime refreshedAt;

  /// The data model version of the source records.
  final int dataModelVersion;

  const KpiWatermark({
    required this.dataVersion,
    required this.confirmedAt,
    required this.refreshedAt,
    required this.dataModelVersion,
  });

  /// Duration since last confirmed refresh.
  Duration get age => DateTime.now().difference(refreshedAt);

  /// Whether this watermark is considered stale given [maxAge].
  bool isStale(Duration maxAge) => age > maxAge;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KpiWatermark &&
          dataVersion == other.dataVersion &&
          confirmedAt == other.confirmedAt &&
          refreshedAt == other.refreshedAt &&
          dataModelVersion == other.dataModelVersion;

  @override
  int get hashCode =>
      Object.hash(dataVersion, confirmedAt, refreshedAt, dataModelVersion);

  @override
  String toString() =>
      'KpiWatermark(v$dataVersion, confirmed=$confirmedAt, '
      'refreshed=$refreshedAt, model=v$dataModelVersion)';
}

/// Sealed class representing a Live KPI's state at any given moment.
///
/// States (per Requirements 9.1–9.6):
/// - [KpiLoading]: Initial fetch in progress, no prior confirmed value
/// - [KpiCurrent]: Fresh confirmed data with watermark
/// - [KpiEmpty]: Confirmed data returned zero/no matching records
/// - [KpiStale]: Previously confirmed value, but watermark is old or
///   refresh is pending/failed
/// - [KpiUnavailable]: Feature not enabled for tenant, no prior value
/// - [KpiError]: Fetch/computation failed with typed error
sealed class KpiState<T> {
  const KpiState();

  /// Returns the display value if available, null otherwise.
  T? get valueOrNull => switch (this) {
    KpiCurrent(:final value) => value,
    KpiStale(:final lastValue) => lastValue,
    KpiEmpty() => null,
    KpiLoading() => null,
    KpiUnavailable() => null,
    KpiError(:final lastValue) => lastValue,
  };

  /// Whether this state has a displayable numeric/value.
  bool get hasValue => valueOrNull != null;

  /// Whether this state represents confirmed fresh data.
  bool get isCurrent => this is KpiCurrent<T>;

  /// Whether we are currently loading/refreshing.
  bool get isLoading => this is KpiLoading<T>;
}

/// Initial fetch in progress, no completed source response and
/// no previously confirmed value.
/// Requirement 9.1
class KpiLoading<T> extends KpiState<T> {
  const KpiLoading();
}

/// Fresh confirmed data with watermark.
/// Requirement 9.2: source returns AuthoritativeConfirmation with records.
class KpiCurrent<T> extends KpiState<T> {
  /// The computed KPI value from confirmed data.
  final T value;

  /// Freshness metadata.
  final KpiWatermark watermark;

  const KpiCurrent({required this.value, required this.watermark});
}

/// Confirmed data returned but no matching records.
/// Requirement 9.3: render documented empty state.
class KpiEmpty<T> extends KpiState<T> {
  /// The watermark of the confirmed empty response.
  final KpiWatermark watermark;

  /// Whether the metric contract defines zero for confirmed empty.
  final bool showZero;

  const KpiEmpty({required this.watermark, this.showZero = false});
}

/// Previously confirmed value exists but watermark is old or
/// refresh is pending/unsuccessful.
/// Requirement 9.4
class KpiStale<T> extends KpiState<T> {
  /// The last confirmed value.
  final T lastValue;

  /// Watermark of the last confirmed value.
  final KpiWatermark lastWatermark;

  /// Current refresh status.
  final KpiRefreshStatus refreshStatus;

  const KpiStale({
    required this.lastValue,
    required this.lastWatermark,
    required this.refreshStatus,
  });
}

/// Feature not enabled for tenant and no previously confirmed value.
/// Requirement 9.5
class KpiUnavailable<T> extends KpiState<T> {
  /// Reason the KPI is unavailable.
  final String reason;

  const KpiUnavailable({required this.reason});
}

/// Fetch/computation failed with typed error.
/// Requirement 9.6: retain previously confirmed value only as visibly stale.
class KpiError<T> extends KpiState<T> {
  /// The typed error that occurred.
  final KpiErrorInfo error;

  /// Previously confirmed value (shown as stale, if available).
  final T? lastValue;

  /// Watermark of the last confirmed value, if any.
  final KpiWatermark? lastWatermark;

  const KpiError({required this.error, this.lastValue, this.lastWatermark});
}

/// Typed error information for KPI failures.
@immutable
class KpiErrorInfo {
  /// Error category for display logic.
  final KpiErrorKind kind;

  /// Human-readable error description.
  final String message;

  /// Correlation ID for debugging.
  final String? correlationId;

  const KpiErrorInfo({
    required this.kind,
    required this.message,
    this.correlationId,
  });
}

/// Categorized error kinds for KPI failures.
enum KpiErrorKind {
  /// Network or connectivity issue.
  network,

  /// Repository/database access failure.
  repository,

  /// Computation error (e.g., unexpected data format).
  computation,

  /// Authorization/permission failure.
  authorization,

  /// Unknown/unclassified error.
  unknown,
}

/// Status of a KPI refresh operation.
enum KpiRefreshStatus {
  /// Refresh is actively in progress.
  refreshing,

  /// Last refresh failed, will retry.
  retryPending,

  /// Refresh was not attempted (e.g., offline).
  notAttempted,
}
