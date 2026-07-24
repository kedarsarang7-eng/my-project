/**
 * Error Codes and Deterministic Outcome Configuration
 *
 * Every outcome the MobileShop system can produce is pre-defined here with
 * a stable code, HTTP status, category, field associations, and safe recovery
 * guidance. No ad-hoc error strings are thrown in production paths.
 *
 * Requirements: 3.2, 6.7–6.9, 12.1–12.6
 */

/** Outcome categories */
export type OutcomeCategory =
  | 'validation'
  | 'authorization'
  | 'conflict'
  | 'not_found'
  | 'rate_limited'
  | 'system'
  | 'pagination'
  | 'version'
  | 'idempotency';

/** A typed error code entry */
export interface ErrorCode {
  /** Stable machine-readable code */
  readonly code: string;
  /** Outcome category */
  readonly category: OutcomeCategory;
  /** HTTP status code to return */
  readonly httpStatus: number;
  /** Human-readable description (not leaked to client when non-disclosing) */
  readonly description: string;
  /** Whether this error discloses entity existence (false = non-disclosing) */
  readonly disclosesExistence: boolean;
  /** Associated field names for field-level error association (empty = global) */
  readonly fields: readonly string[];
  /** Whether client can safely retry with the same request */
  readonly retryable: boolean;
  /** Suggested recovery action for the client */
  readonly recoveryAction: string;
}

/** Deterministic outcome envelope returned by the API */
export interface DeterministicOutcome {
  /** The error code from this catalog */
  readonly code: string;
  /** Category for client-side routing */
  readonly category: OutcomeCategory;
  /** Field-level associations (field → code) */
  readonly fieldErrors?: Readonly<Record<string, string>>;
  /** Correlation ID for tracing */
  readonly correlationId: string;
  /** Whether the same request can be retried */
  readonly retryable: boolean;
  /** Client-safe recovery guidance */
  readonly recoveryAction: string;
  /** Data model version */
  readonly dataModelVersion: number;
}

/** Complete error code catalog */
export const ERROR_CODES: Readonly<Record<string, ErrorCode>> = {
  // === Validation errors (400) ===
  IMEI_REQUIRED: {
    code: 'IMEI_REQUIRED',
    category: 'validation',
    httpStatus: 400,
    description: 'IMEI field is required',
    disclosesExistence: false,
    fields: ['imei'],
    retryable: false,
    recoveryAction: 'Provide a valid 15-digit IMEI number',
  },
  IMEI_FORMAT: {
    code: 'IMEI_FORMAT',
    category: 'validation',
    httpStatus: 400,
    description: 'IMEI contains invalid characters after normalization',
    disclosesExistence: false,
    fields: ['imei'],
    retryable: false,
    recoveryAction: 'Provide only ASCII digits (separators are removed automatically)',
  },
  IMEI_LENGTH: {
    code: 'IMEI_LENGTH',
    category: 'validation',
    httpStatus: 400,
    description: 'IMEI must be exactly 15 digits after normalization',
    disclosesExistence: false,
    fields: ['imei'],
    retryable: false,
    recoveryAction: 'Provide exactly 15 digits',
  },
  IMEI_LUHN: {
    code: 'IMEI_LUHN',
    category: 'validation',
    httpStatus: 400,
    description: 'IMEI fails Luhn checksum validation',
    disclosesExistence: false,
    fields: ['imei'],
    retryable: false,
    recoveryAction: 'Verify the IMEI number is correct',
  },
  IMEI_DUPLICATE: {
    code: 'IMEI_DUPLICATE',
    category: 'conflict',
    httpStatus: 409,
    description: 'IMEI already claimed within tenant scope',
    disclosesExistence: false,
    fields: ['imei'],
    retryable: false,
    recoveryAction: 'Use a different IMEI or resolve the existing claim',
  },
  IMEI_LIFECYCLE_INVALID: {
    code: 'IMEI_LIFECYCLE_INVALID',
    category: 'conflict',
    httpStatus: 409,
    description: 'IMEI is not in a saleable or allowed lifecycle state',
    disclosesExistence: false,
    fields: ['imei'],
    retryable: false,
    recoveryAction: 'Check the current device status before proceeding',
  },
  SCHEMA_INVALID: {
    code: 'SCHEMA_INVALID',
    category: 'validation',
    httpStatus: 400,
    description: 'Request body fails schema validation',
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Correct the request payload per API documentation',
  },
  OPERATION_ID_MISSING: {
    code: 'OPERATION_ID_MISSING',
    category: 'validation',
    httpStatus: 400,
    description: 'Operation ID header/field is required',
    disclosesExistence: false,
    fields: ['operationId'],
    retryable: false,
    recoveryAction: 'Include a unique Operation-Id with the request',
  },
  FINGERPRINT_MISSING: {
    code: 'FINGERPRINT_MISSING',
    category: 'validation',
    httpStatus: 400,
    description: 'Mutation fingerprint is required',
    disclosesExistence: false,
    fields: ['mutationFingerprint'],
    retryable: false,
    recoveryAction: 'Compute and include the mutation fingerprint',
  },
  WARRANTY_MONTHS_OUT_OF_RANGE: {
    code: 'WARRANTY_MONTHS_OUT_OF_RANGE',
    category: 'validation',
    httpStatus: 400,
    description: 'Warranty months outside configured range',
    disclosesExistence: false,
    fields: ['warrantyMonths'],
    retryable: false,
    recoveryAction: 'Provide warranty months within allowed bounds',
  },
  MONETARY_VALUE_INVALID: {
    code: 'MONETARY_VALUE_INVALID',
    category: 'validation',
    httpStatus: 400,
    description: 'Monetary value out of bounds or not an integer minor unit',
    disclosesExistence: false,
    fields: ['amount'],
    retryable: false,
    recoveryAction: 'Provide the value as an integer in minor units (paise)',
  },

  // === Authorization errors (401/403) ===
  AUTH_REQUIRED: {
    code: 'AUTH_REQUIRED',
    category: 'authorization',
    httpStatus: 401,
    description: 'Authentication is required',
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Sign in and retry the request',
  },
  BUSINESS_TYPE_MISMATCH: {
    code: 'BUSINESS_TYPE_MISMATCH',
    category: 'authorization',
    httpStatus: 403,
    description: 'Business type is not mobile_shop',
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Switch to a mobile shop business to access this feature',
  },
  PERMISSION_DENIED: {
    code: 'PERMISSION_DENIED',
    category: 'authorization',
    httpStatus: 403,
    description: 'Caller lacks required permission',
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Request the required permission from an administrator',
  },
  TENANT_CONTEXT_INVALID: {
    code: 'TENANT_CONTEXT_INVALID',
    category: 'authorization',
    httpStatus: 403,
    description: 'Tenant context cannot be resolved',
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Sign in again or contact support',
  },
  CROSS_TENANT_DENIED: {
    code: 'CROSS_TENANT_DENIED',
    category: 'authorization',
    httpStatus: 404,
    description: 'Entity not found (non-disclosing cross-tenant)',
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Verify the entity belongs to your business',
  },

  // === Conflict errors (409) ===
  VERSION_CONFLICT: {
    code: 'VERSION_CONFLICT',
    category: 'conflict',
    httpStatus: 409,
    description: 'Entity version does not match expected version',
    disclosesExistence: false,
    fields: ['expectedVersion'],
    retryable: true,
    recoveryAction: 'Reload current state and retry with updated version',
  },
  LIFECYCLE_TRANSITION_DENIED: {
    code: 'LIFECYCLE_TRANSITION_DENIED',
    category: 'conflict',
    httpStatus: 409,
    description: 'Lifecycle transition is not allowed from current state',
    disclosesExistence: false,
    fields: ['lifecycleState'],
    retryable: false,
    recoveryAction: 'Check the device lifecycle state before attempting this transition',
  },
  CONCURRENT_CLAIM: {
    code: 'CONCURRENT_CLAIM',
    category: 'conflict',
    httpStatus: 409,
    description: 'Another request claimed this resource concurrently',
    disclosesExistence: false,
    fields: [],
    retryable: true,
    recoveryAction: 'Reload and retry if the resource is still available',
  },
  RESERVATION_CONFLICT: {
    code: 'RESERVATION_CONFLICT',
    category: 'conflict',
    httpStatus: 409,
    description: 'Device is already reserved or claimed by another operation',
    disclosesExistence: false,
    fields: ['unitId'],
    retryable: false,
    recoveryAction: 'Release the existing reservation first',
  },

  // === Idempotency errors (409/200) ===
  IDEMPOTENCY_REPLAY: {
    code: 'IDEMPOTENCY_REPLAY',
    category: 'idempotency',
    httpStatus: 200,
    description: 'Operation already completed — returning recorded outcome',
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Use the returned result; no further action needed',
  },
  IDEMPOTENCY_MISMATCH: {
    code: 'IDEMPOTENCY_MISMATCH',
    category: 'idempotency',
    httpStatus: 409,
    description: 'Operation ID reused with a different mutation fingerprint',
    disclosesExistence: false,
    fields: ['operationId', 'mutationFingerprint'],
    retryable: false,
    recoveryAction: 'Generate a new Operation ID for a different operation',
  },
  IDEMPOTENCY_EXPIRED: {
    code: 'IDEMPOTENCY_EXPIRED',
    category: 'idempotency',
    httpStatus: 409,
    description: 'Operation ID is beyond the configured retention window',
    disclosesExistence: false,
    fields: ['operationId'],
    retryable: false,
    recoveryAction: 'Generate a new Operation ID and resubmit',
  },

  // === Not found (404) ===
  ENTITY_NOT_FOUND: {
    code: 'ENTITY_NOT_FOUND',
    category: 'not_found',
    httpStatus: 404,
    description: 'Requested entity does not exist within tenant scope',
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Verify the entity ID and tenant scope',
  },

  // === Pagination errors (400) ===
  PAGINATION_TOKEN_INVALID: {
    code: 'PAGINATION_TOKEN_INVALID',
    category: 'pagination',
    httpStatus: 400,
    description: 'Continuation token is invalid, altered, expired, or for a different query/tenant',
    disclosesExistence: false,
    fields: ['continuationToken'],
    retryable: false,
    recoveryAction: 'Start a new query from the beginning',
  },
  UNSUPPORTED_QUERY: {
    code: 'UNSUPPORTED_QUERY',
    category: 'pagination',
    httpStatus: 400,
    description: 'Query shape is not supported by any cataloged access pattern',
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Use one of the supported filter/sort combinations',
  },

  // === Rate limiting (429) ===
  RATE_LIMITED: {
    code: 'RATE_LIMITED',
    category: 'rate_limited',
    httpStatus: 429,
    description: 'Request throttled after retry budget exhaustion',
    disclosesExistence: false,
    fields: [],
    retryable: true,
    recoveryAction: 'Wait and retry after the indicated delay',
  },
  PENDING_RECONCILIATION: {
    code: 'PENDING_RECONCILIATION',
    category: 'rate_limited',
    httpStatus: 202,
    description: 'Operation accepted but completion is pending reconciliation',
    disclosesExistence: false,
    fields: [],
    retryable: true,
    recoveryAction: 'Poll for reconciliation completion or wait for notification',
  },

  // === Version errors (400/426) ===
  MODEL_VERSION_UNSUPPORTED: {
    code: 'MODEL_VERSION_UNSUPPORTED',
    category: 'version',
    httpStatus: 400,
    description: 'Data model version is outside the supported window',
    disclosesExistence: false,
    fields: ['dataModelVersion'],
    retryable: false,
    recoveryAction: 'Update the client to a supported version',
  },
  API_VERSION_UNSUPPORTED: {
    code: 'API_VERSION_UNSUPPORTED',
    category: 'version',
    httpStatus: 426,
    description: 'Client API version is no longer supported',
    disclosesExistence: false,
    fields: [],
    retryable: false,
    recoveryAction: 'Update the application to the latest version',
  },

  // === System errors (500/503) ===
  INTERNAL_ERROR: {
    code: 'INTERNAL_ERROR',
    category: 'system',
    httpStatus: 500,
    description: 'Unexpected internal error',
    disclosesExistence: false,
    fields: [],
    retryable: true,
    recoveryAction: 'Retry after a brief delay; contact support if persistent',
  },
  SERVICE_UNAVAILABLE: {
    code: 'SERVICE_UNAVAILABLE',
    category: 'system',
    httpStatus: 503,
    description: 'Service temporarily unavailable',
    disclosesExistence: false,
    fields: [],
    retryable: true,
    recoveryAction: 'Retry after a brief delay',
  },
} as const;
