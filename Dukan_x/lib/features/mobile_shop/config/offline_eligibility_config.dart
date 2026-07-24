/// Offline Eligibility Configuration (Flutter)
///
/// Defines which operations can be queued offline and which require connectivity.
///
/// Requirements: 7.2–7.3
library;

import 'package:flutter/foundation.dart';

/// Offline eligibility entry for a single operation type.
@immutable
class OfflineOperationEntry {
  /// Operation type identifier.
  final String operation;

  /// Whether this operation can be queued offline.
  final bool offlineEligible;

  /// Reason if not eligible.
  final String? reason;

  /// Additional constraints when eligible offline.
  final String? constraints;

  const OfflineOperationEntry({
    required this.operation,
    required this.offlineEligible,
    this.reason,
    this.constraints,
  });
}

/// Offline eligibility configuration.
@immutable
class OfflineEligibilityConfig {
  /// Operations and their offline eligibility.
  final List<OfflineOperationEntry> operations;

  /// Maximum offline queue depth per tenant.
  final int maxQueueDepth;

  /// Maximum age of a queued mutation before it is considered expired.
  final Duration maxQueueAge;

  const OfflineEligibilityConfig({
    required this.operations,
    required this.maxQueueDepth,
    required this.maxQueueAge,
  });

  /// Returns whether the given [operationType] is eligible for offline queuing.
  bool isOfflineEligible(String operationType) {
    final entry = operations
        .where((e) => e.operation == operationType)
        .firstOrNull;
    return entry?.offlineEligible ?? false;
  }
}

/// Default offline eligibility configuration.
const kOfflineEligibilityConfig = OfflineEligibilityConfig(
  maxQueueDepth: 100,
  maxQueueAge: Duration(days: 7),
  operations: [
    // Eligible offline
    OfflineOperationEntry(
      operation: 'DEVICE_SALE',
      offlineEligible: true,
      constraints: 'Requires locally cached IMEI state',
    ),
    OfflineOperationEntry(
      operation: 'INVOICE_CREATE',
      offlineEligible: true,
      constraints: 'Saved as local draft/pending',
    ),
    OfflineOperationEntry(
      operation: 'INVOICE_CANCEL',
      offlineEligible: true,
      constraints: 'Requires prior sale in local state',
    ),
    OfflineOperationEntry(
      operation: 'SERVICE_JOB_CREATE',
      offlineEligible: true,
      constraints: 'Unit must exist in local cache',
    ),
    OfflineOperationEntry(
      operation: 'SERVICE_JOB_STATUS_CHANGE',
      offlineEligible: true,
      constraints: 'Requires expected version from local state',
    ),
    OfflineOperationEntry(
      operation: 'DEVICE_RETURN',
      offlineEligible: true,
      constraints: 'Originating sale must be locally confirmed',
    ),
    OfflineOperationEntry(
      operation: 'SECOND_HAND_INTAKE',
      offlineEligible: true,
      constraints: 'Policy/uniqueness check deferred to backend',
    ),
    OfflineOperationEntry(
      operation: 'WARRANTY_REGISTER',
      offlineEligible: true,
      constraints: 'Associated sale must exist locally',
    ),
    OfflineOperationEntry(
      operation: 'DEMO_ASSIGN',
      offlineEligible: true,
      constraints: 'Unit must exist in local cache',
    ),
    OfflineOperationEntry(
      operation: 'RESERVATION_CREATE',
      offlineEligible: true,
      constraints: 'Claim confirmation deferred',
    ),
    // Online required
    OfflineOperationEntry(
      operation: 'EXCHANGE_ACCEPT',
      offlineEligible: false,
      reason: 'Requires real-time valuation confirmation',
    ),
    OfflineOperationEntry(
      operation: 'WARRANTY_CLAIM',
      offlineEligible: false,
      reason: 'Requires provider verification',
    ),
    OfflineOperationEntry(
      operation: 'FINANCE_PLAN_CREATE',
      offlineEligible: false,
      reason: 'Requires online authorization',
    ),
    OfflineOperationEntry(
      operation: 'SIM_RECHARGE',
      offlineEligible: false,
      reason: 'Requires real-time provider submission',
    ),
    OfflineOperationEntry(
      operation: 'PROVIDER_SUBMISSION',
      offlineEligible: false,
      reason: 'External provider requires connectivity',
    ),
    OfflineOperationEntry(
      operation: 'RECONCILIATION_RESOLVE',
      offlineEligible: false,
      reason: 'Requires authoritative backend verification',
    ),
  ],
);
