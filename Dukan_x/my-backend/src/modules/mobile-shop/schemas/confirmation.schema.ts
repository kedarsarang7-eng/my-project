/**
 * AuthoritativeConfirmation Schema
 *
 * Proof that the Canonical_Backend has durably committed or accepted
 * a domain state through DynamoDB. No Lambda timeout, WebSocket notification,
 * or local Drift commit can produce this confirmation.
 *
 * Requirements: 6.42, 3.3–3.6; GR-2
 */

import type { Versioned } from './common.schema';

/** The single authoritative data source */
export type ConfirmationAuthority = 'AWS_DYNAMODB';

/** Confirmation states that only the backend may assert */
export type ConfirmationState =
  | 'COMMITTED'
  | 'ACCEPTED_PENDING'
  | 'CURRENT';

/**
 * Evidence returned only after DynamoDB confirms either:
 * - A successful transaction (COMMITTED)
 * - Durable accepted state + reconciliation record (ACCEPTED_PENDING)
 * - A read of current authoritative state (CURRENT)
 */
export interface AuthoritativeConfirmation extends Versioned {
  readonly authority: ConfirmationAuthority;
  readonly state: ConfirmationState;
  /** Operation_Id that produced this confirmation (mutations only) */
  readonly operationId?: string;
  /** ISO 8601 timestamp of confirmation */
  readonly confirmedAt: string;
  /** Entity IDs to their confirmed version numbers */
  readonly entityVersions: Readonly<Record<string, number>>;
  /** Reconciliation record ID if state is ACCEPTED_PENDING */
  readonly reconciliationId?: string;
}

/** Mutation outcome envelope returned by authoritative endpoints */
export type MutationOutcomeState =
  | 'COMMITTED'
  | 'ACCEPTED_PENDING'
  | 'CONFLICT'
  | 'REJECTED';

export interface MutationOutcome<T = unknown> extends Versioned {
  readonly state: MutationOutcomeState;
  readonly confirmation?: AuthoritativeConfirmation;
  readonly data?: T;
  readonly error?: MutationError;
}

export interface MutationError {
  readonly code: string;
  readonly message: string;
  readonly fields?: Readonly<Record<string, string>>;
  readonly retryable: boolean;
}
