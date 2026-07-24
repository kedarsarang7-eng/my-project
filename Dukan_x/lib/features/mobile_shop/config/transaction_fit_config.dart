/// Transaction Fit Configuration (Flutter)
///
/// Client-side awareness of DynamoDB transaction limits for pre-flight
/// planning and UX feedback (e.g., warning when a sale aggregate is large).
///
/// Requirements: 6.31–6.32
library;

import 'package:flutter/foundation.dart';

/// Transaction fit configuration (client-side awareness).
@immutable
class TransactionFitConfig {
  /// Maximum items the backend will attempt in one atomic transaction.
  final int configuredMaxItems;

  /// Maximum aggregate size (bytes) the backend allows.
  final int configuredMaxBytes;

  /// Typical item count for a device sale (for UI estimation).
  final int typicalSaleItemEstimate;

  const TransactionFitConfig({
    required this.configuredMaxItems,
    required this.configuredMaxBytes,
    required this.typicalSaleItemEstimate,
  });

  /// Estimates whether a sale with [deviceLineCount] devices will fit
  /// in a single atomic transaction. This is approximate — the backend
  /// performs the authoritative check.
  bool estimateFits(int deviceLineCount) {
    // Each device line adds ~4 items: line, IMEI update, claim, audit
    final estimatedItems = typicalSaleItemEstimate + (deviceLineCount * 4);
    return estimatedItems <= configuredMaxItems;
  }
}

/// Default transaction fit configuration.
const kTransactionFitConfig = TransactionFitConfig(
  configuredMaxItems: 80,
  configuredMaxBytes: 3 * 1024 * 1024, // 3 MB
  typicalSaleItemEstimate: 12,
);
