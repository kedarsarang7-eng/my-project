/**
 * Response Mapper — MobileShop Transport Layer
 *
 * Maps SaleOutcome discriminated union to HTTP responses.
 * Critical rule: `confirmation` field is included ONLY when
 * AuthoritativeConfirmation exists (DynamoDB proved the state).
 *
 * Mapping:
 *   committed       → 200, state: 'COMMITTED', confirmation, data
 *   acceptedPending → 202, state: 'ACCEPTED_PENDING', confirmation, reconciliationId
 *   conflict        → 409, DeterministicOutcome body
 *   rejected        → 400/422, DeterministicOutcome body
 *   replay          → 200, state: 'CURRENT' (recorded outcome)
 *
 * Requirements: 3.3–3.11, 6.3–6.13, 6.42, 12.7–12.10
 */

import type { APIGatewayProxyResultV2 } from 'aws-lambda';
import type {
  SaleOutcome,
  SaleCommitted,
  SaleAcceptedPending,
  SaleConflict,
  SaleRejected,
  SaleReplay,
} from '../application/sale-outcome';
import type { DeterministicOutcome } from '../application/error-mapper';
import { CORRELATION_HEADER } from '../middleware/correlation';

// ─── Public API ──────────────────────────────────────────────────────────────

/**
 * Maps a SaleOutcome to the appropriate HTTP response.
 *
 * @param outcome - The SaleOutcome from the application layer
 * @param correlationId - Request correlation ID for response headers
 * @returns APIGatewayProxyResultV2 ready to return from the Lambda handler
 */
export function mapSaleOutcomeToResponse(
  outcome: SaleOutcome,
  correlationId: string,
): APIGatewayProxyResultV2 {
  switch (outcome.type) {
    case 'committed':
      return mapCommitted(outcome, correlationId);
    case 'acceptedPending':
      return mapAcceptedPending(outcome, correlationId);
    case 'conflict':
      return mapConflict(outcome, correlationId);
    case 'rejected':
      return mapRejected(outcome, correlationId);
    case 'replay':
      return mapReplay(outcome, correlationId);
  }
}

/**
 * Maps a DeterministicOutcome directly to an HTTP error response.
 * Used by handlers that detect errors before reaching the application layer.
 *
 * @param outcome - The DeterministicOutcome describing the error
 * @param correlationId - Request correlation ID
 * @returns APIGatewayProxyResultV2 error response
 */
export function mapDeterministicOutcomeToResponse(
  outcome: DeterministicOutcome,
  correlationId: string,
): APIGatewayProxyResultV2 {
  return {
    statusCode: outcome.httpStatus,
    headers: buildHeaders(correlationId),
    body: JSON.stringify({
      error: outcome.code,
      category: outcome.category,
      retryable: outcome.retryable,
      statePreserved: outcome.statePreserved,
      fields: outcome.fields,
      correlationId: outcome.correlationId,
      ...(outcome.details ? { details: outcome.details } : {}),
    }),
  };
}

// ─── Private Mappers ─────────────────────────────────────────────────────────

function mapCommitted(
  outcome: SaleCommitted,
  correlationId: string,
): APIGatewayProxyResultV2 {
  return {
    statusCode: 200,
    headers: buildHeaders(correlationId),
    body: JSON.stringify({
      state: 'COMMITTED',
      data: {
        invoiceId: outcome.invoiceId,
      },
      // CRITICAL: confirmation included ONLY because AuthoritativeConfirmation exists
      confirmation: outcome.confirmation,
    }),
  };
}

function mapAcceptedPending(
  outcome: SaleAcceptedPending,
  correlationId: string,
): APIGatewayProxyResultV2 {
  return {
    statusCode: 202,
    headers: buildHeaders(correlationId),
    body: JSON.stringify({
      state: 'ACCEPTED_PENDING',
      reconciliationId: outcome.reconciliationId,
      data: {
        invoiceId: outcome.invoiceId,
      },
      // CRITICAL: confirmation included ONLY because AuthoritativeConfirmation exists
      confirmation: outcome.confirmation,
    }),
  };
}

function mapConflict(
  outcome: SaleConflict,
  correlationId: string,
): APIGatewayProxyResultV2 {
  return {
    statusCode: 409,
    headers: buildHeaders(correlationId),
    body: JSON.stringify({
      error: outcome.outcome.code,
      category: outcome.outcome.category,
      retryable: outcome.outcome.retryable,
      statePreserved: outcome.outcome.statePreserved,
      fields: outcome.outcome.fields,
      correlationId: outcome.outcome.correlationId,
      ...(outcome.outcome.details ? { details: outcome.outcome.details } : {}),
    }),
  };
}

function mapRejected(
  outcome: SaleRejected,
  correlationId: string,
): APIGatewayProxyResultV2 {
  const status = resolveRejectedStatus(outcome.outcome);
  return {
    statusCode: status,
    headers: buildHeaders(correlationId),
    body: JSON.stringify({
      error: outcome.outcome.code,
      category: outcome.outcome.category,
      retryable: outcome.outcome.retryable,
      statePreserved: outcome.outcome.statePreserved,
      fields: outcome.outcome.fields,
      correlationId: outcome.outcome.correlationId,
      ...(outcome.outcome.details ? { details: outcome.outcome.details } : {}),
    }),
  };
}

function mapReplay(
  outcome: SaleReplay,
  correlationId: string,
): APIGatewayProxyResultV2 {
  // Replay returns the recorded outcome without AuthoritativeConfirmation
  // because the replay itself is not a new DynamoDB write — it's reading
  // the existing recorded state. State is 'CURRENT' to indicate
  // this is the current known outcome.
  return {
    statusCode: 200,
    headers: buildHeaders(correlationId),
    body: JSON.stringify({
      state: 'CURRENT',
      operationId: outcome.operationId,
      status: outcome.status,
      responseRef: outcome.responseRef,
    }),
  };
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Resolves the HTTP status for rejected outcomes.
 * - validation category → 400
 * - system/rate-limit → 503
 * - default → use the httpStatus from the DeterministicOutcome
 */
function resolveRejectedStatus(outcome: DeterministicOutcome): number {
  // Use the httpStatus from the outcome itself — it's set by the error mapper
  return outcome.httpStatus;
}

/**
 * Builds standard response headers with correlation ID.
 */
function buildHeaders(correlationId: string): Record<string, string> {
  return {
    'Content-Type': 'application/json',
    [CORRELATION_HEADER]: correlationId,
  };
}
