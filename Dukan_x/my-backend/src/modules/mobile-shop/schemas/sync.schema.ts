/**
 * Synchronization Schema
 *
 * Sync push/pull DTOs, change events, and continuation tokens
 * for the MobileSyncCoordinator.
 *
 * Requirements: 7.2–7.9; GR-2
 */

import type { Versioned } from './common.schema';
import type { AuthoritativeConfirmation } from './confirmation.schema';

// ─── Push (Client → Server) ─────────────────────────────────────────────────

/** A single queued mutation in the push batch */
export interface PushMutation extends Versioned {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  /** Entity type being mutated */
  readonly entityType: string;
  /** Serialized command payload */
  readonly payload: string;
  /** Base entity versions at time of offline creation */
  readonly expectedVersions: Readonly<Record<string, number>>;
  /** Dependency operation IDs that must succeed first */
  readonly dependsOn?: readonly string[];
  /** ISO 8601 when the mutation was queued locally */
  readonly queuedAt: string;
}

/** Push batch request */
export interface PushBatchRequest extends Versioned {
  readonly tenantId: string;
  readonly mutations: readonly PushMutation[];
}

/** Per-mutation result in push response */
export type PushMutationResultStatus =
  | 'COMMITTED'
  | 'ACCEPTED_PENDING'
  | 'CONFLICT'
  | 'REJECTED'
  | 'ALREADY_APPLIED';

export interface PushMutationResult {
  readonly operationId: string;
  readonly status: PushMutationResultStatus;
  readonly confirmation?: AuthoritativeConfirmation;
  readonly errorCode?: string;
  readonly errorMessage?: string;
}

/** Push batch response */
export interface PushBatchResponse extends Versioned {
  readonly results: readonly PushMutationResult[];
}

// ─── Pull (Server → Client) ─────────────────────────────────────────────────

/** Pull request from client */
export interface PullRequest extends Versioned {
  readonly tenantId: string;
  /** Opaque continuation token from last pull (undefined = start from beginning) */
  readonly continuationToken?: string;
  /** Maximum items to return in this page */
  readonly limit: number;
}

/** A change event in the pull response */
export interface ChangeEvent extends Versioned {
  readonly eventId: string;
  readonly tenantId: string;
  /** Entity type that changed */
  readonly entityType: string;
  readonly entityId: string;
  /** New version of the entity */
  readonly entityVersion: number;
  /** Action that produced the change */
  readonly action: string;
  /** Serialized entity snapshot (for creates/updates) */
  readonly snapshot?: string;
  /** Whether entity was deleted/retired */
  readonly deleted?: boolean;
  /** ISO 8601 when the change occurred */
  readonly occurredAt: string;
  /** Sequence number for ordering within a bucket */
  readonly sequence: number;
}

/** Pull response */
export interface PullResponse extends Versioned {
  readonly changes: readonly ChangeEvent[];
  /** Opaque token for next page (undefined = caught up) */
  readonly continuationToken?: string;
  readonly hasMore: boolean;
}

// ─── WebSocket Hint (Server → Client) ───────────────────────────────────────

/**
 * Minimal hint delivered via WebSocket. Contains no authoritative payload —
 * only identity and version information to trigger a bounded pull.
 */
export interface ServerHint {
  readonly tenantId: string;
  readonly eventId: string;
  readonly entityType: string;
  readonly entityId: string;
  readonly entityVersion: number;
  /** Hint type */
  readonly hint: 'CHANGE' | 'INVALIDATION';
  /** ISO 8601 */
  readonly occurredAt: string;
}
