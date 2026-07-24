/// Correlation ID Configuration (Flutter)
///
/// Defines format, header name, and propagation rules for correlation IDs
/// used across API calls, telemetry, and audit trails.
///
/// Requirements: 6.23, 12.3
library;

import 'package:flutter/foundation.dart';

/// Correlation ID configuration.
@immutable
class CorrelationConfig {
  /// HTTP header name used to propagate correlation ID.
  final String headerName;

  /// Prefix for client-generated correlation IDs.
  final String prefix;

  /// Maximum length of a correlation ID.
  final int maxLength;

  /// Regex pattern for validation.
  final String pattern;

  /// Whether to generate a new ID if not provided.
  final bool generateIfMissing;

  const CorrelationConfig({
    required this.headerName,
    required this.prefix,
    required this.maxLength,
    required this.pattern,
    required this.generateIfMissing,
  });

  /// Validates a correlation ID against the configured pattern.
  bool isValid(String id) {
    if (id.isEmpty || id.length > maxLength) return false;
    return RegExp(pattern).hasMatch(id);
  }
}

/// Default correlation configuration.
const kCorrelationConfig = CorrelationConfig(
  headerName: 'X-Correlation-Id',
  prefix: 'ms-',
  maxLength: 64,
  pattern: r'^[a-zA-Z0-9\-_]{1,64}$',
  generateIfMissing: true,
);
