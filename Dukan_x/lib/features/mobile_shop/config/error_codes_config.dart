/// Error Codes and Deterministic Outcome Configuration (Flutter)
///
/// Every outcome the MobileShop system can produce is pre-defined here.
/// The Flutter client uses these to parse and display typed error states.
///
/// Requirements: 3.2, 6.7–6.9, 12.1–12.6
library;

import 'package:flutter/foundation.dart';

/// Outcome categories for routing error handling.
enum OutcomeCategory {
  validation,
  authorization,
  conflict,
  notFound,
  rateLimited,
  system,
  pagination,
  version,
  idempotency,
}

/// A typed error code definition.
@immutable
class ErrorCodeDef {
  /// Stable machine-readable code.
  final String code;

  /// Outcome category.
  final OutcomeCategory category;

  /// HTTP status code.
  final int httpStatus;

  /// Whether this error discloses entity existence.
  final bool disclosesExistence;

  /// Associated field names for field-level error association.
  final List<String> fields;

  /// Whether client can safely retry with the same request.
  final bool retryable;

  /// Suggested recovery action for the user.
  final String recoveryAction;

  const ErrorCodeDef({
    required this.code,
    required this.category,
    required this.httpStatus,
    required this.disclosesExistence,
    required this.fields,
    required this.retryable,
    required this.recoveryAction,
  });
}

/// Deterministic outcome envelope received from the API.
@immutable
class DeterministicOutcome {
  /// The error code from the catalog.
  final String code;

  /// Category for client-side routing.
  final OutcomeCategory category;

  /// Field-level associations (field → code).
  final Map<String, String>? fieldErrors;

  /// Correlation ID for tracing.
  final String correlationId;

  /// Whether the same request can be retried.
  final bool retryable;

  /// Client-safe recovery guidance.
  final String recoveryAction;

  /// Data model version.
  final int dataModelVersion;

  const DeterministicOutcome({
    required this.code,
    required this.category,
    this.fieldErrors,
    required this.correlationId,
    required this.retryable,
    required this.recoveryAction,
    required this.dataModelVersion,
  });

  factory DeterministicOutcome.fromJson(Map<String, dynamic> json) {
    return DeterministicOutcome(
      code: json['code'] as String,
      category: _parseCategory(json['category'] as String),
      fieldErrors: json['fieldErrors'] != null
          ? Map<String, String>.from(json['fieldErrors'] as Map)
          : null,
      correlationId: json['correlationId'] as String,
      retryable: json['retryable'] as bool,
      recoveryAction: json['recoveryAction'] as String,
      dataModelVersion: json['dataModelVersion'] as int,
    );
  }

  static OutcomeCategory _parseCategory(String value) {
    switch (value) {
      case 'validation':
        return OutcomeCategory.validation;
      case 'authorization':
        return OutcomeCategory.authorization;
      case 'conflict':
        return OutcomeCategory.conflict;
      case 'not_found':
        return OutcomeCategory.notFound;
      case 'rate_limited':
        return OutcomeCategory.rateLimited;
      case 'system':
        return OutcomeCategory.system;
      case 'pagination':
        return OutcomeCategory.pagination;
      case 'version':
        return OutcomeCategory.version;
      case 'idempotency':
        return OutcomeCategory.idempotency;
      default:
        return OutcomeCategory.system;
    }
  }
}

/// Complete error code catalog for the Flutter client.
abstract final class MobileShopErrorCodes {
  // Validation
  static const imeiRequired = ErrorCodeDef(
    code: 'IMEI_REQUIRED',
    category: OutcomeCategory.validation,
    httpStatus: 400,
    disclosesExistence: false,
    fields: ['imei'],
    retryable: false,
    recoveryAction: 'Provide a valid 15-digit IMEI number',
  );
  static const imeiFormat = ErrorCodeDef(
    code: 'IMEI_FORMAT',
    category: OutcomeCategory.validation,
    httpStatus: 400,
    disclosesExistence: false,
    fields: ['imei'],
    retryable: false,
    recoveryAction:
        'Provide only digits (separators are removed automatically)',
  );
  static const imeiLength = ErrorCodeDef(
    code: 'IMEI_LENGTH',
    category: OutcomeCategory.validation,
    httpStatus: 400,
    disclosesExistence: false,
    fields: ['imei'],
    retryable: false,
    recoveryAction: 'Provide exactly 15 digits',
  );
  static const imeiLuhn = ErrorCodeDef(
    code: 'IMEI_LUHN',
    category: OutcomeCategory.validation,
    httpStatus: 400,
    disclosesExistence: false,
    fields: ['imei'],
    retryable: false,
    recoveryAction: 'Verify the IMEI number is correct',
  );
  static const imeiDuplicate = ErrorCodeDef(
    code: 'IMEI_DUPLICATE',
    category: OutcomeCategory.conflict,
    httpStatus: 409,
    disclosesExistence: false,
    fields: ['imei'],
    retryable: false,
    recoveryAction: 'Use a different IMEI or resolve the existing claim',
  );
  static const imeiLifecycleInvalid = ErrorCodeDef(
    code: 'IMEI_LIFECYCLE_INVALID',
    category: OutcomeCategory.conflict,
    httpStatus: 409,
    disclosesExistence: false,
    fields: ['imei'],
    retryable: false,
    recoveryAction: 'Check the current device status',
  );
  static const schemaInvalid = ErrorCodeDef(
    code: 'SCHEMA_INVALID',
    category: OutcomeCategory.validation,
    httpStatus: 400,
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Correct the request payload',
  );
  static const operationIdMissing = ErrorCodeDef(
    code: 'OPERATION_ID_MISSING',
    category: OutcomeCategory.validation,
    httpStatus: 400,
    disclosesExistence: false,
    fields: ['operationId'],
    retryable: false,
    recoveryAction: 'Include a unique Operation-Id',
  );
  static const fingerprintMissing = ErrorCodeDef(
    code: 'FINGERPRINT_MISSING',
    category: OutcomeCategory.validation,
    httpStatus: 400,
    disclosesExistence: false,
    fields: ['mutationFingerprint'],
    retryable: false,
    recoveryAction: 'Include the mutation fingerprint',
  );
  static const warrantyMonthsOutOfRange = ErrorCodeDef(
    code: 'WARRANTY_MONTHS_OUT_OF_RANGE',
    category: OutcomeCategory.validation,
    httpStatus: 400,
    disclosesExistence: false,
    fields: ['warrantyMonths'],
    retryable: false,
    recoveryAction: 'Provide warranty months within allowed bounds',
  );
  static const monetaryValueInvalid = ErrorCodeDef(
    code: 'MONETARY_VALUE_INVALID',
    category: OutcomeCategory.validation,
    httpStatus: 400,
    disclosesExistence: false,
    fields: ['amount'],
    retryable: false,
    recoveryAction: 'Provide value as integer minor units (paise)',
  );

  // Authorization
  static const authRequired = ErrorCodeDef(
    code: 'AUTH_REQUIRED',
    category: OutcomeCategory.authorization,
    httpStatus: 401,
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Sign in and retry',
  );
  static const businessTypeMismatch = ErrorCodeDef(
    code: 'BUSINESS_TYPE_MISMATCH',
    category: OutcomeCategory.authorization,
    httpStatus: 403,
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Switch to a mobile shop business',
  );
  static const permissionDenied = ErrorCodeDef(
    code: 'PERMISSION_DENIED',
    category: OutcomeCategory.authorization,
    httpStatus: 403,
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Request the required permission',
  );
  static const tenantContextInvalid = ErrorCodeDef(
    code: 'TENANT_CONTEXT_INVALID',
    category: OutcomeCategory.authorization,
    httpStatus: 403,
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Sign in again',
  );
  static const crossTenantDenied = ErrorCodeDef(
    code: 'CROSS_TENANT_DENIED',
    category: OutcomeCategory.authorization,
    httpStatus: 404,
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Verify the entity belongs to your business',
  );

  // Conflict
  static const versionConflict = ErrorCodeDef(
    code: 'VERSION_CONFLICT',
    category: OutcomeCategory.conflict,
    httpStatus: 409,
    disclosesExistence: false,
    fields: ['expectedVersion'],
    retryable: true,
    recoveryAction: 'Reload current state and retry',
  );
  static const lifecycleTransitionDenied = ErrorCodeDef(
    code: 'LIFECYCLE_TRANSITION_DENIED',
    category: OutcomeCategory.conflict,
    httpStatus: 409,
    disclosesExistence: false,
    fields: ['lifecycleState'],
    retryable: false,
    recoveryAction: 'Check device lifecycle state first',
  );
  static const concurrentClaim = ErrorCodeDef(
    code: 'CONCURRENT_CLAIM',
    category: OutcomeCategory.conflict,
    httpStatus: 409,
    disclosesExistence: false,
    fields: [],
    retryable: true,
    recoveryAction: 'Reload and retry',
  );
  static const reservationConflict = ErrorCodeDef(
    code: 'RESERVATION_CONFLICT',
    category: OutcomeCategory.conflict,
    httpStatus: 409,
    disclosesExistence: false,
    fields: ['unitId'],
    retryable: false,
    recoveryAction: 'Release the existing reservation first',
  );

  // Idempotency
  static const idempotencyReplay = ErrorCodeDef(
    code: 'IDEMPOTENCY_REPLAY',
    category: OutcomeCategory.idempotency,
    httpStatus: 200,
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Use the returned result',
  );
  static const idempotencyMismatch = ErrorCodeDef(
    code: 'IDEMPOTENCY_MISMATCH',
    category: OutcomeCategory.idempotency,
    httpStatus: 409,
    disclosesExistence: false,
    fields: ['operationId', 'mutationFingerprint'],
    retryable: false,
    recoveryAction: 'Generate a new Operation ID',
  );
  static const idempotencyExpired = ErrorCodeDef(
    code: 'IDEMPOTENCY_EXPIRED',
    category: OutcomeCategory.idempotency,
    httpStatus: 409,
    disclosesExistence: false,
    fields: ['operationId'],
    retryable: false,
    recoveryAction: 'Generate a new Operation ID and resubmit',
  );

  // Not found
  static const entityNotFound = ErrorCodeDef(
    code: 'ENTITY_NOT_FOUND',
    category: OutcomeCategory.notFound,
    httpStatus: 404,
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Verify the entity ID',
  );

  // Pagination
  static const paginationTokenInvalid = ErrorCodeDef(
    code: 'PAGINATION_TOKEN_INVALID',
    category: OutcomeCategory.pagination,
    httpStatus: 400,
    disclosesExistence: false,
    fields: ['continuationToken'],
    retryable: false,
    recoveryAction: 'Start a new query from the beginning',
  );
  static const unsupportedQuery = ErrorCodeDef(
    code: 'UNSUPPORTED_QUERY',
    category: OutcomeCategory.pagination,
    httpStatus: 400,
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Use a supported filter/sort combination',
  );

  // Rate limiting
  static const rateLimited = ErrorCodeDef(
    code: 'RATE_LIMITED',
    category: OutcomeCategory.rateLimited,
    httpStatus: 429,
    disclosesExistence: false,
    fields: [],
    retryable: true,
    recoveryAction: 'Wait and retry after the indicated delay',
  );
  static const pendingReconciliation = ErrorCodeDef(
    code: 'PENDING_RECONCILIATION',
    category: OutcomeCategory.rateLimited,
    httpStatus: 202,
    disclosesExistence: false,
    fields: [],
    retryable: true,
    recoveryAction: 'Poll for completion or wait for notification',
  );

  // Version
  static const modelVersionUnsupported = ErrorCodeDef(
    code: 'MODEL_VERSION_UNSUPPORTED',
    category: OutcomeCategory.version,
    httpStatus: 400,
    disclosesExistence: false,
    fields: ['dataModelVersion'],
    retryable: false,
    recoveryAction: 'Update the client to a supported version',
  );
  static const apiVersionUnsupported = ErrorCodeDef(
    code: 'API_VERSION_UNSUPPORTED',
    category: OutcomeCategory.version,
    httpStatus: 426,
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Update the application',
  );

  // System
  static const internalError = ErrorCodeDef(
    code: 'INTERNAL_ERROR',
    category: OutcomeCategory.system,
    httpStatus: 500,
    disclosesExistence: false,
    fields: [],
    retryable: true,
    recoveryAction: 'Retry after a brief delay',
  );
  static const serviceUnavailable = ErrorCodeDef(
    code: 'SERVICE_UNAVAILABLE',
    category: OutcomeCategory.system,
    httpStatus: 503,
    disclosesExistence: false,
    fields: [],
    retryable: true,
    recoveryAction: 'Retry after a brief delay',
  );

  /// Lookup an error code definition by its code string.
  static ErrorCodeDef? fromCode(String code) {
    return _codeMap[code];
  }

  static const _codeMap = <String, ErrorCodeDef>{
    'IMEI_REQUIRED': imeiRequired,
    'IMEI_FORMAT': imeiFormat,
    'IMEI_LENGTH': imeiLength,
    'IMEI_LUHN': imeiLuhn,
    'IMEI_DUPLICATE': imeiDuplicate,
    'IMEI_LIFECYCLE_INVALID': imeiLifecycleInvalid,
    'SCHEMA_INVALID': schemaInvalid,
    'OPERATION_ID_MISSING': operationIdMissing,
    'FINGERPRINT_MISSING': fingerprintMissing,
    'WARRANTY_MONTHS_OUT_OF_RANGE': warrantyMonthsOutOfRange,
    'MONETARY_VALUE_INVALID': monetaryValueInvalid,
    'AUTH_REQUIRED': authRequired,
    'BUSINESS_TYPE_MISMATCH': businessTypeMismatch,
    'PERMISSION_DENIED': permissionDenied,
    'TENANT_CONTEXT_INVALID': tenantContextInvalid,
    'CROSS_TENANT_DENIED': crossTenantDenied,
    'VERSION_CONFLICT': versionConflict,
    'LIFECYCLE_TRANSITION_DENIED': lifecycleTransitionDenied,
    'CONCURRENT_CLAIM': concurrentClaim,
    'RESERVATION_CONFLICT': reservationConflict,
    'IDEMPOTENCY_REPLAY': idempotencyReplay,
    'IDEMPOTENCY_MISMATCH': idempotencyMismatch,
    'IDEMPOTENCY_EXPIRED': idempotencyExpired,
    'ENTITY_NOT_FOUND': entityNotFound,
    'PAGINATION_TOKEN_INVALID': paginationTokenInvalid,
    'UNSUPPORTED_QUERY': unsupportedQuery,
    'RATE_LIMITED': rateLimited,
    'PENDING_RECONCILIATION': pendingReconciliation,
    'MODEL_VERSION_UNSUPPORTED': modelVersionUnsupported,
    'API_VERSION_UNSUPPORTED': apiVersionUnsupported,
    'INTERNAL_ERROR': internalError,
    'SERVICE_UNAVAILABLE': serviceUnavailable,
  };
}
