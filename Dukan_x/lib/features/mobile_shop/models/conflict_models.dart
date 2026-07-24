/// Conflict Models (Dart)
///
/// Conflict record with local/server versions, reason, and resolution state.
///
/// Requirements: 7.8–7.9; GR-2
library;

import 'package:flutter/foundation.dart';

/// Conflict reason categories.
enum ConflictReason {
  versionMismatch,
  uniquenessViolation,
  lifecyclePrecondition,
  idempotencyMismatch,
  concurrentClaim,
  staleMutation,
  schemaIncompatible;

  String toWireValue() {
    switch (this) {
      case ConflictReason.versionMismatch:
        return 'VERSION_MISMATCH';
      case ConflictReason.uniquenessViolation:
        return 'UNIQUENESS_VIOLATION';
      case ConflictReason.lifecyclePrecondition:
        return 'LIFECYCLE_PRECONDITION';
      case ConflictReason.idempotencyMismatch:
        return 'IDEMPOTENCY_MISMATCH';
      case ConflictReason.concurrentClaim:
        return 'CONCURRENT_CLAIM';
      case ConflictReason.staleMutation:
        return 'STALE_MUTATION';
      case ConflictReason.schemaIncompatible:
        return 'SCHEMA_INCOMPATIBLE';
    }
  }

  static ConflictReason fromWire(String value) {
    switch (value) {
      case 'VERSION_MISMATCH':
        return ConflictReason.versionMismatch;
      case 'UNIQUENESS_VIOLATION':
        return ConflictReason.uniquenessViolation;
      case 'LIFECYCLE_PRECONDITION':
        return ConflictReason.lifecyclePrecondition;
      case 'IDEMPOTENCY_MISMATCH':
        return ConflictReason.idempotencyMismatch;
      case 'CONCURRENT_CLAIM':
        return ConflictReason.concurrentClaim;
      case 'STALE_MUTATION':
        return ConflictReason.staleMutation;
      case 'SCHEMA_INCOMPATIBLE':
        return ConflictReason.schemaIncompatible;
      default:
        throw ArgumentError('Unknown ConflictReason: $value');
    }
  }
}

/// Resolution state.
enum ConflictResolutionState {
  unresolved,
  localWins,
  serverWins,
  merged,
  discarded;

  String toWireValue() {
    switch (this) {
      case ConflictResolutionState.unresolved:
        return 'UNRESOLVED';
      case ConflictResolutionState.localWins:
        return 'LOCAL_WINS';
      case ConflictResolutionState.serverWins:
        return 'SERVER_WINS';
      case ConflictResolutionState.merged:
        return 'MERGED';
      case ConflictResolutionState.discarded:
        return 'DISCARDED';
    }
  }

  static ConflictResolutionState fromWire(String value) {
    switch (value) {
      case 'UNRESOLVED':
        return ConflictResolutionState.unresolved;
      case 'LOCAL_WINS':
        return ConflictResolutionState.localWins;
      case 'SERVER_WINS':
        return ConflictResolutionState.serverWins;
      case 'MERGED':
        return ConflictResolutionState.merged;
      case 'DISCARDED':
        return ConflictResolutionState.discarded;
      default:
        throw ArgumentError('Unknown ConflictResolutionState: $value');
    }
  }
}

/// A conflict record persisted locally for user resolution.
@immutable
class ConflictRecord {
  final String tenantId;
  final String conflictId;
  final int dataModelVersion;
  final String operationId;
  final String entityType;
  final String entityId;
  final ConflictReason reason;
  final int localVersion;
  final int serverVersion;
  final String? localSnapshot;
  final String? serverSnapshot;
  final ConflictResolutionState resolutionState;
  final String? resolutionNotes;
  final String? resolvedAt;
  final String? resolvedBy;
  final String? errorCode;
  final String? errorMessage;
  final String detectedAt;
  final String createdAt;

  const ConflictRecord({
    required this.tenantId,
    required this.conflictId,
    required this.dataModelVersion,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.reason,
    required this.localVersion,
    required this.serverVersion,
    this.localSnapshot,
    this.serverSnapshot,
    required this.resolutionState,
    this.resolutionNotes,
    this.resolvedAt,
    this.resolvedBy,
    this.errorCode,
    this.errorMessage,
    required this.detectedAt,
    required this.createdAt,
  });

  factory ConflictRecord.fromJson(Map<String, dynamic> json) => ConflictRecord(
    tenantId: json['tenantId'] as String,
    conflictId: json['conflictId'] as String,
    dataModelVersion: json['dataModelVersion'] as int,
    operationId: json['operationId'] as String,
    entityType: json['entityType'] as String,
    entityId: json['entityId'] as String,
    reason: ConflictReason.fromWire(json['reason'] as String),
    localVersion: json['localVersion'] as int,
    serverVersion: json['serverVersion'] as int,
    localSnapshot: json['localSnapshot'] as String?,
    serverSnapshot: json['serverSnapshot'] as String?,
    resolutionState: ConflictResolutionState.fromWire(
      json['resolutionState'] as String,
    ),
    resolutionNotes: json['resolutionNotes'] as String?,
    resolvedAt: json['resolvedAt'] as String?,
    resolvedBy: json['resolvedBy'] as String?,
    errorCode: json['errorCode'] as String?,
    errorMessage: json['errorMessage'] as String?,
    detectedAt: json['detectedAt'] as String,
    createdAt: json['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'conflictId': conflictId,
    'dataModelVersion': dataModelVersion,
    'operationId': operationId,
    'entityType': entityType,
    'entityId': entityId,
    'reason': reason.toWireValue(),
    'localVersion': localVersion,
    'serverVersion': serverVersion,
    if (localSnapshot != null) 'localSnapshot': localSnapshot,
    if (serverSnapshot != null) 'serverSnapshot': serverSnapshot,
    'resolutionState': resolutionState.toWireValue(),
    if (resolutionNotes != null) 'resolutionNotes': resolutionNotes,
    if (resolvedAt != null) 'resolvedAt': resolvedAt,
    if (resolvedBy != null) 'resolvedBy': resolvedBy,
    if (errorCode != null) 'errorCode': errorCode,
    if (errorMessage != null) 'errorMessage': errorMessage,
    'detectedAt': detectedAt,
    'createdAt': createdAt,
  };
}
