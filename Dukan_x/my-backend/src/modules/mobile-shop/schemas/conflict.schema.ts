/**
 * Conflict Schema
 *
 * Conflict record with local/server versions, reason, and resolution state.
 * Used when push/sync detects version mismatch or competing claims.
 *
 * Requirements: 7.8–7.9; GR-2
 */

import type { Versioned } from './common.schema';

/** Conflict reason categories */
export type ConflictReason =
  | 'VERSION_MISMATCH'
  | 'UNIQUENESS_VIOLATION'
  | 'LIFECYCLE_PRECONDITION'
  | 'IDEMPOTENCY_MISMATCH'
  | 'CONCURRENT_CLAIM'
  | 'STALE_MUTATION'
  | 'SCHEMA_INCOMPATIBLE';

/** Resolution state */
export type ConflictResolutionState =
  | 'UNRESOLVED'
  | 'LOCAL_WINS'
  | 'SERVER_WINS'
  | 'MERGED'
  | 'DISCARDED';

/** A conflict record persisted locally for user resolution */
export interface ConflictRecord extends Versioned {
  readonly tenantId: string;
  /** Unique conflict identifier */
  readonly conflictId: string;

  /** The operation that produced the conflict */
  readonly operationId: string;

  /** Entity in conflict */
  readonly entityType: string;
  readonly entityId: string;

  /** Why the conflict occurred */
  readonly reason: ConflictReason;

  /** Local version at time of mutation */
  readonly localVersion: number;
  /** Server version that rejected the mutation */
  readonly serverVersion: number;

  /** Serialized local state at time of conflict */
  readonly localSnapshot?: string;
  /** Serialized server state */
  readonly serverSnapshot?: string;

  /** Current resolution state */
  readonly resolutionState: ConflictResolutionState;
  /** How it was resolved */
  readonly resolutionNotes?: string;
  /** ISO 8601 when resolved */
  readonly resolvedAt?: string;
  /** Actor who resolved */
  readonly resolvedBy?: string;

  /** Error code from the server rejection */
  readonly errorCode?: string;
  /** Error message from the server */
  readonly errorMessage?: string;

  /** ISO 8601 when the conflict was detected */
  readonly detectedAt: string;
  /** ISO 8601 when record was created locally */
  readonly createdAt: string;
}
