/**
 * Ambiguous Outcome Handler — MobileShop Application Layer
 *
 * Handles SDK timeout and unknown-response scenarios by checking the
 * idempotency record (strong read) to determine the actual operation state.
 *
 * Key invariants:
 * - NEVER claims success for an ambiguous response
 * - Uses strong-consistent reads for idempotency lookup (AP-14)
 * - Returns AMBIGUOUS_OUTCOME with retry guidance when state is unknown
 * - Returns recorded outcome on fingerprint match (safe replay)
 * - Returns FINGERPRINT_MISMATCH when operationId exists with different content
 *
 * Requirements: 6.7–6.13, 6.38, 12.4–12.5, 12.8–12.10
 */

import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire } from '../schemas/common.schema';
import { checkIdempotency, type IdempotencyCheckResult } from '../persistence/idempotency';
import { ERROR_CODES } from '../config/error-codes.config';
import type { DeterministicOutcome } from './error-mapper';

// ─── Types ───────────────────────────────────────────────────────────────────

/** Result of ambiguous outcome resolution */
export type AmbiguousResolution =
  | { readonly resolved: true; readonly outcome: ResolvedOutcome }
  | { readonly resolved: false; readonly outcome: DeterministicOutcome };

/** A resolved outcome from idempotency lookup — operation was actually completed */
export interface ResolvedOutcome {
  /** The recorded status of the operation */
  readonly status: string;
  /** Reference to the recorded response (if available) */
  readonly responseRef: string | null;
  /** The operation was previously completed — this is a replay */
  readonly isReplay: true;
}

// ─── Handler ─────────────────────────────────────────────────────────────────

/**
 * Handles an ambiguous DynamoDB outcome (timeout, unknown SDK response).
 *
 * Resolution strategy:
 * 1. Strong-read the idempotency record for the operation
 * 2. If record exists with matching fingerprint → return recorded outcome (resolved replay)
 * 3. If record doesn't exist → return AMBIGUOUS_OUTCOME with retry guidance
 * 4. If record exists with different fingerprint → return FINGERPRINT_MISMATCH
 *
 * The caller NEVER assumes success when this function returns `resolved: false`.
 *
 * @param client - DynamoDB document client
 * @param tableName - MobileShop table name
 * @param ctx - Authenticated tenant context
 * @param operationId - The Operation_Id of the ambiguous operation
 * @param fingerprint - The Mutation_Fingerprint to verify
 */
export async function handleAmbiguousOutcome(
  client: DynamoDBDocumentClient,
  tableName: string,
  ctx: TenantContextWire,
  operationId: string,
  fingerprint: string,
): Promise<AmbiguousResolution> {
  let idempotencyResult: IdempotencyCheckResult;

  try {
    idempotencyResult = await checkIdempotency(
      client,
      tableName,
      ctx,
      operationId,
      fingerprint,
    );
  } catch {
    // If the idempotency check itself fails, we cannot resolve — remain ambiguous
    return {
      resolved: false,
      outcome: buildAmbiguousOutcome(ctx.correlationId),
    };
  }

  switch (idempotencyResult.outcome) {
    case 'REPLAY':
      // Record exists with matching fingerprint — operation actually completed
      return {
        resolved: true,
        outcome: {
          status: idempotencyResult.status,
          responseRef: idempotencyResult.responseRef,
          isReplay: true,
        },
      };

    case 'NEW_OPERATION':
      // No record exists — the write may not have persisted
      // Return AMBIGUOUS_OUTCOME: caller should retry with the same Operation_Id
      return {
        resolved: false,
        outcome: buildAmbiguousOutcome(ctx.correlationId),
      };

    case 'FINGERPRINT_MISMATCH':
      // Record exists but with a different fingerprint — conflict
      return {
        resolved: false,
        outcome: buildFingerprintMismatchOutcome(ctx.correlationId),
      };

    case 'EXPIRED':
      // Record existed but is past retention — treat as ambiguous
      // Caller cannot safely retry with an expired operationId
      return {
        resolved: false,
        outcome: buildExpiredAmbiguousOutcome(ctx.correlationId),
      };

    default:
      return {
        resolved: false,
        outcome: buildAmbiguousOutcome(ctx.correlationId),
      };
  }
}

// ─── Outcome Builders ────────────────────────────────────────────────────────

/**
 * Builds an AMBIGUOUS_OUTCOME: state is unknown, retry is safe with same Operation_Id.
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

/**
 * Builds a FINGERPRINT_MISMATCH outcome: operationId reused with different content.
 */
function buildFingerprintMismatchOutcome(correlationId: string): DeterministicOutcome {
  return {
    code: ERROR_CODES.IDEMPOTENCY_MISMATCH.code,
    category: ERROR_CODES.IDEMPOTENCY_MISMATCH.category,
    retryable: ERROR_CODES.IDEMPOTENCY_MISMATCH.retryable,
    statePreserved: true,
    fields: ['operationId', 'mutationFingerprint'],
    httpStatus: ERROR_CODES.IDEMPOTENCY_MISMATCH.httpStatus,
    correlationId,
  };
}

/**
 * Builds an outcome for an expired idempotency record discovered during ambiguous resolution.
 * The caller cannot safely retry because the operationId is past retention.
 */
function buildExpiredAmbiguousOutcome(correlationId: string): DeterministicOutcome {
  return {
    code: ERROR_CODES.IDEMPOTENCY_EXPIRED.code,
    category: ERROR_CODES.IDEMPOTENCY_EXPIRED.category,
    retryable: false,
    statePreserved: true,
    fields: ['operationId'],
    httpStatus: ERROR_CODES.IDEMPOTENCY_EXPIRED.httpStatus,
    correlationId,
  };
}
