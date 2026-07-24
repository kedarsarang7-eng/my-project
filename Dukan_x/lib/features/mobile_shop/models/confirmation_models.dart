/// AuthoritativeConfirmation Models (Dart)
///
/// Proof that the Canonical_Backend has durably committed or accepted
/// a domain state through DynamoDB.
///
/// Requirements: 6.42, 3.3–3.6; GR-2
library;

import 'package:flutter/foundation.dart';

/// The single authoritative data source.
enum ConfirmationAuthority { awsDynamoDb }

/// Confirmation states that only the backend may assert.
enum ConfirmationState { committed, acceptedPending, current }

/// Evidence returned only after DynamoDB confirms the operation.
@immutable
class AuthoritativeConfirmation {
  final ConfirmationAuthority authority;
  final ConfirmationState state;
  final String? operationId;
  final String confirmedAt;
  final int dataModelVersion;
  final Map<String, int> entityVersions;
  final String? reconciliationId;

  const AuthoritativeConfirmation({
    required this.authority,
    required this.state,
    this.operationId,
    required this.confirmedAt,
    required this.dataModelVersion,
    required this.entityVersions,
    this.reconciliationId,
  });

  factory AuthoritativeConfirmation.fromJson(Map<String, dynamic> json) =>
      AuthoritativeConfirmation(
        authority: ConfirmationAuthority.awsDynamoDb,
        state: _parseConfirmationState(json['state'] as String),
        operationId: json['operationId'] as String?,
        confirmedAt: json['confirmedAt'] as String,
        dataModelVersion: json['dataModelVersion'] as int,
        entityVersions: (json['entityVersions'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v as int),
        ),
        reconciliationId: json['reconciliationId'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'authority': 'AWS_DYNAMODB',
    'state': state.toWireValue(),
    if (operationId != null) 'operationId': operationId,
    'confirmedAt': confirmedAt,
    'dataModelVersion': dataModelVersion,
    'entityVersions': entityVersions,
    if (reconciliationId != null) 'reconciliationId': reconciliationId,
  };
}

/// Mutation outcome states.
enum MutationOutcomeState { committed, acceptedPending, conflict, rejected }

/// Mutation outcome envelope returned by authoritative endpoints.
@immutable
class MutationOutcome<T> {
  final MutationOutcomeState state;
  final AuthoritativeConfirmation? confirmation;
  final T? data;
  final MutationError? error;
  final int dataModelVersion;

  const MutationOutcome({
    required this.state,
    this.confirmation,
    this.data,
    this.error,
    required this.dataModelVersion,
  });
}

/// Mutation error detail.
@immutable
class MutationError {
  final String code;
  final String message;
  final Map<String, String>? fields;
  final bool retryable;

  const MutationError({
    required this.code,
    required this.message,
    this.fields,
    required this.retryable,
  });

  factory MutationError.fromJson(Map<String, dynamic> json) => MutationError(
    code: json['code'] as String,
    message: json['message'] as String,
    fields: (json['fields'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, v as String),
    ),
    retryable: json['retryable'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (fields != null) 'fields': fields,
    'retryable': retryable,
  };
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

ConfirmationState _parseConfirmationState(String value) {
  switch (value) {
    case 'COMMITTED':
      return ConfirmationState.committed;
    case 'ACCEPTED_PENDING':
      return ConfirmationState.acceptedPending;
    case 'CURRENT':
      return ConfirmationState.current;
    default:
      throw ArgumentError('Unknown ConfirmationState: $value');
  }
}

extension ConfirmationStateWire on ConfirmationState {
  String toWireValue() {
    switch (this) {
      case ConfirmationState.committed:
        return 'COMMITTED';
      case ConfirmationState.acceptedPending:
        return 'ACCEPTED_PENDING';
      case ConfirmationState.current:
        return 'CURRENT';
    }
  }
}
