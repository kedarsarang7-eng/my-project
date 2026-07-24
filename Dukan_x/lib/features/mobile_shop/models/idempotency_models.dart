/// Idempotency Models (Dart)
///
/// Operation_Id, Mutation_Fingerprint, and idempotency record.
///
/// Requirements: 6.10–6.13, 6.27; GR-2
library;

import 'package:flutter/foundation.dart';

/// Status of an idempotency record.
enum IdempotencyStatus {
  pending,
  committed,
  acceptedPending,
  failed,
  expired;

  String toWireValue() {
    switch (this) {
      case IdempotencyStatus.pending:
        return 'PENDING';
      case IdempotencyStatus.committed:
        return 'COMMITTED';
      case IdempotencyStatus.acceptedPending:
        return 'ACCEPTED_PENDING';
      case IdempotencyStatus.failed:
        return 'FAILED';
      case IdempotencyStatus.expired:
        return 'EXPIRED';
    }
  }

  static IdempotencyStatus fromWire(String value) {
    switch (value) {
      case 'PENDING':
        return IdempotencyStatus.pending;
      case 'COMMITTED':
        return IdempotencyStatus.committed;
      case 'ACCEPTED_PENDING':
        return IdempotencyStatus.acceptedPending;
      case 'FAILED':
        return IdempotencyStatus.failed;
      case 'EXPIRED':
        return IdempotencyStatus.expired;
      default:
        throw ArgumentError('Unknown IdempotencyStatus: $value');
    }
  }
}

/// A tenant-scoped idempotency record (read-only DTO for client).
@immutable
class IdempotencyRecord {
  final String tenantId;
  final String operationId;
  final String mutationFingerprint;
  final int dataModelVersion;
  final IdempotencyStatus status;
  final String? responseReference;
  final String createdAt;
  final String updatedAt;

  const IdempotencyRecord({
    required this.tenantId,
    required this.operationId,
    required this.mutationFingerprint,
    required this.dataModelVersion,
    required this.status,
    this.responseReference,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IdempotencyRecord.fromJson(Map<String, dynamic> json) =>
      IdempotencyRecord(
        tenantId: json['tenantId'] as String,
        operationId: json['operationId'] as String,
        mutationFingerprint: json['mutationFingerprint'] as String,
        dataModelVersion: json['dataModelVersion'] as int,
        status: IdempotencyStatus.fromWire(json['status'] as String),
        responseReference: json['responseReference'] as String?,
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'operationId': operationId,
    'mutationFingerprint': mutationFingerprint,
    'dataModelVersion': dataModelVersion,
    'status': status.toWireValue(),
    if (responseReference != null) 'responseReference': responseReference,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

/// Mutation envelope wrapping any domain command with idempotency metadata.
@immutable
class MutationEnvelope<T> {
  final String tenantId;
  final String operationId;
  final String mutationFingerprint;
  final int dataModelVersion;
  final Map<String, int> expectedVersions;
  final T command;

  const MutationEnvelope({
    required this.tenantId,
    required this.operationId,
    required this.mutationFingerprint,
    required this.dataModelVersion,
    required this.expectedVersions,
    required this.command,
  });
}
