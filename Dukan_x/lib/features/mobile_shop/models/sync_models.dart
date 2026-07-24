/// Synchronization Models (Dart)
///
/// Sync push/pull DTOs, change events, and continuation tokens.
///
/// Requirements: 7.2–7.9; GR-2
library;

import 'package:flutter/foundation.dart';
import 'confirmation_models.dart';

// ─── Push (Client → Server) ─────────────────────────────────────────────────

/// A single queued mutation in the push batch.
@immutable
class PushMutation {
  final String operationId;
  final String mutationFingerprint;
  final int dataModelVersion;
  final String entityType;
  final String payload;
  final Map<String, int> expectedVersions;
  final List<String>? dependsOn;
  final String queuedAt;

  const PushMutation({
    required this.operationId,
    required this.mutationFingerprint,
    required this.dataModelVersion,
    required this.entityType,
    required this.payload,
    required this.expectedVersions,
    this.dependsOn,
    required this.queuedAt,
  });

  factory PushMutation.fromJson(Map<String, dynamic> json) => PushMutation(
    operationId: json['operationId'] as String,
    mutationFingerprint: json['mutationFingerprint'] as String,
    dataModelVersion: json['dataModelVersion'] as int,
    entityType: json['entityType'] as String,
    payload: json['payload'] as String,
    expectedVersions: (json['expectedVersions'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as int),
    ),
    dependsOn: (json['dependsOn'] as List<dynamic>?)?.cast<String>(),
    queuedAt: json['queuedAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'mutationFingerprint': mutationFingerprint,
    'dataModelVersion': dataModelVersion,
    'entityType': entityType,
    'payload': payload,
    'expectedVersions': expectedVersions,
    if (dependsOn != null) 'dependsOn': dependsOn,
    'queuedAt': queuedAt,
  };
}

/// Push batch request.
@immutable
class PushBatchRequest {
  final String tenantId;
  final int dataModelVersion;
  final List<PushMutation> mutations;

  const PushBatchRequest({
    required this.tenantId,
    required this.dataModelVersion,
    required this.mutations,
  });

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'dataModelVersion': dataModelVersion,
    'mutations': mutations.map((m) => m.toJson()).toList(),
  };
}

/// Per-mutation result status.
enum PushMutationResultStatus {
  committed,
  acceptedPending,
  conflict,
  rejected,
  alreadyApplied;

  static PushMutationResultStatus fromWire(String value) {
    switch (value) {
      case 'COMMITTED':
        return PushMutationResultStatus.committed;
      case 'ACCEPTED_PENDING':
        return PushMutationResultStatus.acceptedPending;
      case 'CONFLICT':
        return PushMutationResultStatus.conflict;
      case 'REJECTED':
        return PushMutationResultStatus.rejected;
      case 'ALREADY_APPLIED':
        return PushMutationResultStatus.alreadyApplied;
      default:
        throw ArgumentError('Unknown PushMutationResultStatus: $value');
    }
  }
}

/// Per-mutation result.
@immutable
class PushMutationResult {
  final String operationId;
  final PushMutationResultStatus status;
  final AuthoritativeConfirmation? confirmation;
  final String? errorCode;
  final String? errorMessage;

  const PushMutationResult({
    required this.operationId,
    required this.status,
    this.confirmation,
    this.errorCode,
    this.errorMessage,
  });

  factory PushMutationResult.fromJson(Map<String, dynamic> json) =>
      PushMutationResult(
        operationId: json['operationId'] as String,
        status: PushMutationResultStatus.fromWire(json['status'] as String),
        confirmation: json['confirmation'] != null
            ? AuthoritativeConfirmation.fromJson(
                json['confirmation'] as Map<String, dynamic>,
              )
            : null,
        errorCode: json['errorCode'] as String?,
        errorMessage: json['errorMessage'] as String?,
      );
}

/// Push batch response.
@immutable
class PushBatchResponse {
  final int dataModelVersion;
  final List<PushMutationResult> results;

  const PushBatchResponse({
    required this.dataModelVersion,
    required this.results,
  });

  factory PushBatchResponse.fromJson(Map<String, dynamic> json) =>
      PushBatchResponse(
        dataModelVersion: json['dataModelVersion'] as int,
        results: (json['results'] as List<dynamic>)
            .map((r) => PushMutationResult.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

// ─── Pull (Server → Client) ─────────────────────────────────────────────────

/// Pull request.
@immutable
class PullRequest {
  final String tenantId;
  final int dataModelVersion;
  final String? continuationToken;
  final int limit;

  const PullRequest({
    required this.tenantId,
    required this.dataModelVersion,
    this.continuationToken,
    required this.limit,
  });

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'dataModelVersion': dataModelVersion,
    if (continuationToken != null) 'continuationToken': continuationToken,
    'limit': limit,
  };
}

/// A change event in the pull response.
@immutable
class ChangeEvent {
  final String eventId;
  final String tenantId;
  final int dataModelVersion;
  final String entityType;
  final String entityId;
  final int entityVersion;
  final String action;
  final String? snapshot;
  final bool? deleted;
  final String occurredAt;
  final int sequence;

  const ChangeEvent({
    required this.eventId,
    required this.tenantId,
    required this.dataModelVersion,
    required this.entityType,
    required this.entityId,
    required this.entityVersion,
    required this.action,
    this.snapshot,
    this.deleted,
    required this.occurredAt,
    required this.sequence,
  });

  factory ChangeEvent.fromJson(Map<String, dynamic> json) => ChangeEvent(
    eventId: json['eventId'] as String,
    tenantId: json['tenantId'] as String,
    dataModelVersion: json['dataModelVersion'] as int,
    entityType: json['entityType'] as String,
    entityId: json['entityId'] as String,
    entityVersion: json['entityVersion'] as int,
    action: json['action'] as String,
    snapshot: json['snapshot'] as String?,
    deleted: json['deleted'] as bool?,
    occurredAt: json['occurredAt'] as String,
    sequence: json['sequence'] as int,
  );

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'tenantId': tenantId,
    'dataModelVersion': dataModelVersion,
    'entityType': entityType,
    'entityId': entityId,
    'entityVersion': entityVersion,
    'action': action,
    if (snapshot != null) 'snapshot': snapshot,
    if (deleted != null) 'deleted': deleted,
    'occurredAt': occurredAt,
    'sequence': sequence,
  };
}

/// Pull response.
@immutable
class PullResponse {
  final int dataModelVersion;
  final List<ChangeEvent> changes;
  final String? continuationToken;
  final bool hasMore;

  const PullResponse({
    required this.dataModelVersion,
    required this.changes,
    this.continuationToken,
    required this.hasMore,
  });

  factory PullResponse.fromJson(Map<String, dynamic> json) => PullResponse(
    dataModelVersion: json['dataModelVersion'] as int,
    changes: (json['changes'] as List<dynamic>)
        .map((c) => ChangeEvent.fromJson(c as Map<String, dynamic>))
        .toList(),
    continuationToken: json['continuationToken'] as String?,
    hasMore: json['hasMore'] as bool,
  );
}

// ─── WebSocket Hint ──────────────────────────────────────────────────────────

/// Minimal server hint — triggers bounded pull.
@immutable
class ServerHint {
  final String tenantId;
  final String eventId;
  final String entityType;
  final String entityId;
  final int entityVersion;
  final String hint;
  final String occurredAt;

  const ServerHint({
    required this.tenantId,
    required this.eventId,
    required this.entityType,
    required this.entityId,
    required this.entityVersion,
    required this.hint,
    required this.occurredAt,
  });

  factory ServerHint.fromJson(Map<String, dynamic> json) => ServerHint(
    tenantId: json['tenantId'] as String,
    eventId: json['eventId'] as String,
    entityType: json['entityType'] as String,
    entityId: json['entityId'] as String,
    entityVersion: json['entityVersion'] as int,
    hint: json['hint'] as String,
    occurredAt: json['occurredAt'] as String,
  );
}
