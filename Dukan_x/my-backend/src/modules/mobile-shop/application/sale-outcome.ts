/**
 * Sale Outcome Types — MobileShop Application Layer
 *
 * Discriminated union of all possible sale outcomes returned by the
 * AtomicSaleHandler and AcceptedPendingHandler. Separated into a
 * dedicated module for reuse across handlers, transport, and tests.
 *
 * Requirements: 3.1–3.4, 3.7–3.9, 6.9–6.13, 6.31, 6.42
 */

import type { DeterministicOutcome } from './error-mapper';

// ─── Authoritative Confirmation ──────────────────────────────────────────────

/**
 * Authoritative confirmation issued ONLY after DynamoDB confirms the write.
 * This is the sole evidence the system uses to label an outcome as committed,
 * accepted-pending, or current.
 */
export interface AuthoritativeConfirmation {
  /** Always AWS_DYNAMODB — the single canonical datastore */
  readonly authority: 'AWS_DYNAMODB';
  /** Confirmed state of the operation */
  readonly state: 'COMMITTED' | 'ACCEPTED_PENDING' | 'CURRENT';
  /** The Operation_Id for this mutation */
  readonly operationId: string;
  /** ISO 8601 timestamp when DynamoDB confirmed the write */
  readonly confirmedAt: string;
  /** Data model version of the persisted records */
  readonly dataModelVersion: number;
  /** Map of entity identifiers to their new version numbers */
  readonly entityVersions: Readonly<Record<string, number>>;
  /** Present when the operation requires reconciliation */
  readonly reconciliationId?: string;
}

// ─── Sale Outcome Union ──────────────────────────────────────────────────────

/**
 * Typed discriminated union of all possible sale outcomes.
 *
 * - COMMITTED: All effects persisted atomically in one transaction
 * - ACCEPTED_PENDING: Oversized write; accepted state + reconciliation record durable
 * - CONFLICT: Conditional-write or idempotency-mismatch failure
 * - REJECTED: Validation, system, or rate-limit failure
 * - REPLAY: Idempotent retry — recorded outcome returned without mutation
 */
export type SaleOutcome =
  | SaleCommitted
  | SaleAcceptedPending
  | SaleConflict
  | SaleRejected
  | SaleReplay;

/** All effects committed atomically */
export interface SaleCommitted {
  readonly type: 'committed';
  readonly invoiceId: string;
  readonly confirmation: AuthoritativeConfirmation;
}

/** Accepted-pending: oversized operation delegated to reconciliation */
export interface SaleAcceptedPending {
  readonly type: 'acceptedPending';
  readonly invoiceId: string;
  readonly reconciliationId: string;
  readonly confirmation: AuthoritativeConfirmation;
}

/** Conflict: conditional-write or idempotency-mismatch failure */
export interface SaleConflict {
  readonly type: 'conflict';
  readonly outcome: DeterministicOutcome;
}

/** Rejected: validation, system, or rate-limit failure */
export interface SaleRejected {
  readonly type: 'rejected';
  readonly outcome: DeterministicOutcome;
}

/** Replay: idempotent retry returns recorded outcome without mutation */
export interface SaleReplay {
  readonly type: 'replay';
  readonly operationId: string;
  readonly status: string;
  readonly responseRef: string | null;
}

// ─── Accepted-Pending Handler Interface ──────────────────────────────────────

/**
 * Interface for the accepted-pending handler (task 6.2).
 * Injected as a dependency to allow the atomic handler to delegate
 * when a transaction exceeds configured limits.
 */
export interface AcceptedPendingHandler {
  handleOversizedSale(
    client: import('@aws-sdk/lib-dynamodb').DynamoDBDocumentClient,
    ctx: import('../schemas/common.schema').TenantContextWire,
    command: import('./transaction-planner').MobileSaleCommand,
    plan: import('./transaction-planner').TransactionPlan,
  ): Promise<SaleAcceptedPending>;
}
