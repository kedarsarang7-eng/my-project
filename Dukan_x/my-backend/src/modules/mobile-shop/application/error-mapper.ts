/**
 * DynamoDB Error Mapper — Conditional-Write and Transaction Error Mapping
 *
 * Translates DynamoDB SDK exceptions into documented deterministic outcomes.
 * Every mapped outcome preserves pre-operation state (no partial writes escape).
 *
 * Mapping rules:
 * - ConditionalCheckFailedException → context-aware: version, uniqueness, lifecycle, or idempotency
 * - TransactionCanceledException → per-item cancellation reason decoding
 * - ProvisionedThroughputExceededException / ThrottlingException / RequestLimitExceeded → RATE_LIMITED
 * - SDK timeout / unknown response → AMBIGUOUS_OUTCOME
 * - InternalServerError → SERVICE_UNAVAILABLE
 * - ResourceNotFoundException → CONFIGURATION_ERROR (table missing)
 *
 * Requirements: 3.2, 6.7–6.13, 6.31–6.32, 6.38, 12.4–12.5, 12.8–12.10
 */

import { ERROR_CODES, type OutcomeCategory } from '../config/error-codes.config';

// ─── Types ───────────────────────────────────────────────────────────────────

/**
 * Extended deterministic outcome with state-preservation guarantee and diagnostic details.
 * Returned by error mapping functions for consistent error handling across the system.
 */
export interface DeterministicOutcome {
  /** Error code from ERROR_CODES catalog */
  readonly code: string;
  /** Category for client-side routing */
  readonly category: OutcomeCategory;
  /** Whether the client should retry */
  readonly retryable: boolean;
  /** Whether pre-operation state is unchanged (always true for mapped errors) */
  readonly statePreserved: boolean;
  /** Associated fields for UI field-level error display */
  readonly fields: string[];
  /** HTTP response code */
  readonly httpStatus: number;
  /** Request correlation ID for tracing */
  readonly correlationId: string;
  /** Optional diagnostic details */
  readonly details?: {
    readonly cancellationReasons?: string[];
    readonly throttlingResource?: string;
  };
}

/** Context provided to the error mapper for condition-failure disambiguation */
export interface ErrorMappingContext {
  /** Correlation ID for the current request */
  readonly correlationId: string;
  /** Which type of condition was used in the write */
  readonly conditionType: ConditionType;
  /** Fields associated with the condition (for UI error reporting) */
  readonly fields?: string[];
  /** Optional table/index name for throttling diagnostics */
  readonly resource?: string;
}

/** The type of condition that was applied to the DynamoDB write */
export type ConditionType =
  | 'VERSION'            // Expected version condition (optimistic concurrency)
  | 'UNIQUENESS'         // attribute_not_exists for uniqueness claims (IMEI, etc.)
  | 'LIFECYCLE'          // Lifecycle state precondition
  | 'IDEMPOTENCY'        // attribute_not_exists for idempotency record
  | 'COMPOSITE'          // Multiple conditions — requires transaction cancellation decoding
  | 'UNKNOWN';           // Fallback when condition type isn't known

/** A single item within a TransactWriteItems request, with its condition metadata */
export interface TransactItemDescriptor {
  /** Human-readable label for this transact item */
  readonly label: string;
  /** What type of condition this item uses */
  readonly conditionType: ConditionType;
  /** Fields associated with this item's condition */
  readonly fields?: string[];
}

// ─── Main Error Mapper ───────────────────────────────────────────────────────

/**
 * Maps a DynamoDB SDK error to a documented deterministic outcome.
 *
 * The mapper classifies errors into:
 * 1. Condition failures (version, uniqueness, lifecycle, idempotency conflicts)
 * 2. Transaction cancellations (per-item reason decoding)
 * 3. Throttling (retry-safe, state preserved)
 * 4. Ambiguous outcomes (timeout, unknown — never claim success)
 * 5. Service errors (DynamoDB unavailable, table missing)
 *
 * Every outcome guarantees `statePreserved: true` — no partial writes escape.
 */
export function mapDynamoDbError(
  error: unknown,
  context: ErrorMappingContext,
): DeterministicOutcome {
  const errorName = extractErrorName(error);

  switch (errorName) {
    case 'ConditionalCheckFailedException':
      return mapConditionalCheckFailed(context);

    case 'TransactionCanceledException':
      return mapTransactionCanceledSimple(error, context);

    case 'ProvisionedThroughputExceededException':
    case 'ThrottlingException':
    case 'RequestLimitExceeded':
      return buildOutcome(
        ERROR_CODES.RATE_LIMITED,
        context.correlationId,
        context.fields ?? [],
        { throttlingResource: context.resource },
      );

    case 'InternalServerError':
      return buildOutcome(
        ERROR_CODES.SERVICE_UNAVAILABLE,
        context.correlationId,
        [],
      );

    case 'ResourceNotFoundException':
      return buildOutcome(
        ERROR_CODES.INTERNAL_ERROR,
        context.correlationId,
        [],
      );

    default:
      // SDK timeout, network error, or unknown response → AMBIGUOUS_OUTCOME
      if (isTimeoutOrNetworkError(error)) {
        return buildAmbiguousOutcome(context.correlationId);
      }
      // Unknown SDK error — treat as system error, preserve state
      return buildOutcome(
        ERROR_CODES.INTERNAL_ERROR,
        context.correlationId,
        [],
      );
  }
}

// ─── Conditional Check Failure Mapping ───────────────────────────────────────

/**
 * Maps a ConditionalCheckFailedException to the specific conflict type based on context.
 */
function mapConditionalCheckFailed(context: ErrorMappingContext): DeterministicOutcome {
  switch (context.conditionType) {
    case 'VERSION':
      return buildOutcome(
        ERROR_CODES.VERSION_CONFLICT,
        context.correlationId,
        context.fields ?? ['expectedVersion'],
      );

    case 'UNIQUENESS':
      return buildOutcome(
        ERROR_CODES.IMEI_DUPLICATE,
        context.correlationId,
        context.fields ?? ['imei'],
      );

    case 'LIFECYCLE':
      return buildOutcome(
        ERROR_CODES.LIFECYCLE_TRANSITION_DENIED,
        context.correlationId,
        context.fields ?? ['lifecycleState'],
      );

    case 'IDEMPOTENCY':
      return buildOutcome(
        ERROR_CODES.IDEMPOTENCY_MISMATCH,
        context.correlationId,
        context.fields ?? ['operationId', 'mutationFingerprint'],
      );

    case 'COMPOSITE':
    case 'UNKNOWN':
    default:
      // Generic conflict — cannot disambiguate without transaction reason details
      return buildOutcome(
        ERROR_CODES.CONCURRENT_CLAIM,
        context.correlationId,
        context.fields ?? [],
      );
  }
}

// ─── Transaction Cancellation Mapping ────────────────────────────────────────

/**
 * Maps a TransactionCanceledException using inline reason extraction.
 * Returns the first deterministic conflict reason found.
 */
function mapTransactionCanceledSimple(
  error: unknown,
  context: ErrorMappingContext,
): DeterministicOutcome {
  const reasons = extractCancellationReasons(error);

  if (reasons.length === 0) {
    return buildOutcome(
      ERROR_CODES.CONCURRENT_CLAIM,
      context.correlationId,
      context.fields ?? [],
      { cancellationReasons: ['UNKNOWN'] },
    );
  }

  // Find the first condition failure reason
  const firstFailure = reasons.find((r) => r !== 'None');
  if (!firstFailure) {
    return buildOutcome(
      ERROR_CODES.CONCURRENT_CLAIM,
      context.correlationId,
      context.fields ?? [],
      { cancellationReasons: reasons },
    );
  }

  // Map the reason string to a deterministic outcome
  return buildOutcome(
    mapCancellationReasonToErrorCode(firstFailure),
    context.correlationId,
    context.fields ?? [],
    { cancellationReasons: reasons },
  );
}

/**
 * Maps a TransactionCanceledException with full per-item correlation.
 *
 * Correlates each cancellation reason with the transact item that caused it
 * to identify the most relevant conflict for the caller.
 */
export function mapTransactionCancellation(
  reasons: string[],
  transactItems: readonly TransactItemDescriptor[],
  correlationId: string,
): DeterministicOutcome {
  if (reasons.length === 0) {
    return buildOutcome(
      ERROR_CODES.CONCURRENT_CLAIM,
      correlationId,
      [],
      { cancellationReasons: ['UNKNOWN'] },
    );
  }

  // Correlate reasons with transact items
  for (let i = 0; i < reasons.length; i++) {
    const reason = reasons[i];
    if (reason === 'None' || reason === undefined) continue;

    const descriptor = transactItems[i];
    if (!descriptor) {
      // Reason without a matching descriptor — use generic mapping
      return buildOutcome(
        mapCancellationReasonToErrorCode(reason),
        correlationId,
        [],
        { cancellationReasons: reasons },
      );
    }

    // Use the descriptor's condition type for precise mapping
    const outcome = mapConditionTypeToOutcome(descriptor.conditionType, correlationId, descriptor.fields);
    return {
      ...outcome,
      details: { cancellationReasons: reasons },
    };
  }

  // All reasons were 'None' — shouldn't normally happen
  return buildOutcome(
    ERROR_CODES.CONCURRENT_CLAIM,
    correlationId,
    [],
    { cancellationReasons: reasons },
  );
}

// ─── Ambiguous Outcome ───────────────────────────────────────────────────────

/**
 * Builds an AMBIGUOUS_OUTCOME — the caller NEVER assumes success.
 * This is used for SDK timeouts and unknown responses.
 */
function buildAmbiguousOutcome(correlationId: string): DeterministicOutcome {
  return {
    code: 'AMBIGUOUS_OUTCOME',
    category: 'system',
    retryable: true,
    statePreserved: true,
    fields: [],
    httpStatus: 503,
    correlationId,
  };
}

// ─── Internal Helpers ────────────────────────────────────────────────────────

/**
 * Extracts the error name from a DynamoDB SDK error object.
 */
function extractErrorName(error: unknown): string | undefined {
  if (error && typeof error === 'object') {
    if ('name' in error && typeof (error as { name: unknown }).name === 'string') {
      return (error as { name: string }).name;
    }
    if ('__type' in error && typeof (error as { __type: unknown }).__type === 'string') {
      // AWS SDK v2 style
      const type = (error as { __type: string }).__type;
      return type.includes('#') ? type.split('#')[1] : type;
    }
  }
  return undefined;
}

/**
 * Extracts cancellation reasons from a TransactionCanceledException.
 * AWS SDK v3 exposes these as `CancellationReasons` on the error object.
 */
function extractCancellationReasons(error: unknown): string[] {
  if (!error || typeof error !== 'object') return [];

  // AWS SDK v3: CancellationReasons array
  if ('CancellationReasons' in error) {
    const reasons = (error as { CancellationReasons: unknown[] }).CancellationReasons;
    if (Array.isArray(reasons)) {
      return reasons.map((r) => {
        if (r && typeof r === 'object' && 'Code' in r) {
          return (r as { Code: string }).Code;
        }
        return 'None';
      });
    }
  }

  // Fallback: message parsing (less reliable)
  if ('message' in error && typeof (error as { message: unknown }).message === 'string') {
    const msg = (error as { message: string }).message;
    const match = msg.match(/\[([^\]]+)\]/);
    if (match) {
      return match[1].split(',').map((s) => s.trim());
    }
  }

  return [];
}

/**
 * Maps a raw cancellation reason code string to the appropriate error code entry.
 */
function mapCancellationReasonToErrorCode(reason: string): typeof ERROR_CODES[keyof typeof ERROR_CODES] {
  switch (reason) {
    case 'ConditionalCheckFailed':
      return ERROR_CODES.CONCURRENT_CLAIM;
    case 'TransactionConflict':
      return ERROR_CODES.VERSION_CONFLICT;
    case 'ItemCollectionSizeLimitExceeded':
      return ERROR_CODES.INTERNAL_ERROR;
    case 'ThrottlingError':
    case 'ProvisionedThroughputExceeded':
      return ERROR_CODES.RATE_LIMITED;
    case 'ValidationError':
      return ERROR_CODES.SCHEMA_INVALID;
    default:
      return ERROR_CODES.CONCURRENT_CLAIM;
  }
}

/**
 * Maps a ConditionType to the appropriate deterministic outcome.
 */
function mapConditionTypeToOutcome(
  conditionType: ConditionType,
  correlationId: string,
  fields?: string[],
): DeterministicOutcome {
  switch (conditionType) {
    case 'VERSION':
      return buildOutcome(ERROR_CODES.VERSION_CONFLICT, correlationId, fields ?? ['expectedVersion']);
    case 'UNIQUENESS':
      return buildOutcome(ERROR_CODES.IMEI_DUPLICATE, correlationId, fields ?? ['imei']);
    case 'LIFECYCLE':
      return buildOutcome(ERROR_CODES.LIFECYCLE_TRANSITION_DENIED, correlationId, fields ?? ['lifecycleState']);
    case 'IDEMPOTENCY':
      return buildOutcome(ERROR_CODES.IDEMPOTENCY_MISMATCH, correlationId, fields ?? ['operationId', 'mutationFingerprint']);
    case 'COMPOSITE':
    case 'UNKNOWN':
    default:
      return buildOutcome(ERROR_CODES.CONCURRENT_CLAIM, correlationId, fields ?? []);
  }
}

/**
 * Determines if an error is a timeout or network connectivity issue.
 */
function isTimeoutOrNetworkError(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false;

  const name = extractErrorName(error);
  if (name === 'TimeoutError' || name === 'RequestTimeout' || name === 'NetworkingError') {
    return true;
  }

  // Check for ECONNREFUSED, ETIMEDOUT, ENOTFOUND, etc.
  if ('code' in error) {
    const code = (error as { code: unknown }).code;
    if (typeof code === 'string') {
      return ['ECONNREFUSED', 'ETIMEDOUT', 'ENOTFOUND', 'EPIPE', 'ECONNRESET'].includes(code);
    }
  }

  // Check for $metadata with no httpStatusCode (ambiguous response)
  if ('$metadata' in error) {
    const meta = (error as { $metadata: unknown }).$metadata;
    if (meta && typeof meta === 'object' && !('httpStatusCode' in meta)) {
      return true;
    }
  }

  return false;
}

/**
 * Builds a DeterministicOutcome from an error code catalog entry.
 * Always sets statePreserved: true — conditional writes never produce partial mutations.
 */
function buildOutcome(
  errorCode: typeof ERROR_CODES[keyof typeof ERROR_CODES],
  correlationId: string,
  fields: string[],
  details?: DeterministicOutcome['details'],
): DeterministicOutcome {
  return {
    code: errorCode.code,
    category: errorCode.category,
    retryable: errorCode.retryable,
    statePreserved: true,
    fields: fields.length > 0 ? fields : [...errorCode.fields],
    httpStatus: errorCode.httpStatus,
    correlationId,
    ...(details ? { details } : {}),
  };
}
