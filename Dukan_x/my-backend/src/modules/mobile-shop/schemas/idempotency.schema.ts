/**
 * Idempotency Schema
 *
 * Operation_Id, Mutation_Fingerprint, and idempotency record.
 * Used to ensure exactly-once semantics for domain mutations.
 *
 * Requirements: 6.10–6.13, 6.27; GR-2
 */

import type { Versioned } from './common.schema';

/** Status of an idempotency record */
export type IdempotencyStatus =
  | 'PENDING'
  | 'COMMITTED'
  | 'ACCEPTED_PENDING'
  | 'FAILED'
  | 'EXPIRED';

/**
 * A tenant-scoped idempotency record.
 *
 * Key: PK=TENANT#t#IDEMPOTENCY, SK=OP#operationId
 *
 * Business retry policy rejects keys outside configured retention
 * even if DynamoDB TTL physical deletion is delayed.
 */
export interface IdempotencyRecord extends Versioned {
  readonly tenantId: string;
  /** Unique operation identifier (generated once per logical mutation) */
  readonly operationId: string;
  /**
   * Deterministic digest of operation type + normalized immutable request fields.
   * A retry with the same operationId but different fingerprint = conflict.
   */
  readonly mutationFingerprint: string;
  /** Current status */
  readonly status: IdempotencyStatus;
  /** Reference to the stored response (entity type + id, or inline for small payloads) */
  readonly responseReference?: string;
  /** Bounded response snapshot for replay (when small enough) */
  readonly responseSnapshot?: string;

  /** ISO 8601 when the record was created */
  readonly createdAt: string;
  /** ISO 8601 when last updated */
  readonly updatedAt: string;
  /** TTL epoch seconds for DynamoDB cleanup */
  readonly expiresAt: number;

  /** Entity type associated with this operation */
  readonly entityType?: string;
  /** Entity ID produced or affected */
  readonly entityId?: string;
}

/**
 * Mutation envelope wrapping any domain command with idempotency metadata.
 * Used by transport/handler layers to enforce Operation_Id semantics.
 */
export interface MutationEnvelope<T = unknown> extends Versioned {
  readonly tenantId: string;
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly expectedVersions: Readonly<Record<string, number>>;
  readonly command: T;
}
