/// Pagination Configuration (Flutter)
///
/// Defines page sizes and token handling for bounded list queries.
///
/// Requirements: 6.14–6.17, 6.29
library;

import 'package:flutter/foundation.dart';

/// Pagination configuration for list queries.
@immutable
class PaginationConfig {
  /// Default page size when not specified.
  final int defaultPageSize;

  /// Maximum allowed page size (client cannot request more).
  final int maxPageSize;

  /// Minimum allowed page size.
  final int minPageSize;

  /// Continuation token validity (seconds) — must match server.
  final int tokenExpirySeconds;

  const PaginationConfig({
    required this.defaultPageSize,
    required this.maxPageSize,
    required this.minPageSize,
    required this.tokenExpirySeconds,
  });

  /// Clamps a requested page size to the allowed range.
  int clampPageSize(int requested) {
    if (requested < minPageSize) return minPageSize;
    if (requested > maxPageSize) return maxPageSize;
    return requested;
  }
}

/// Default pagination configuration.
const kPaginationConfig = PaginationConfig(
  defaultPageSize: 25,
  maxPageSize: 100,
  minPageSize: 1,
  tokenExpirySeconds: 5 * 60, // 5 minutes
);
