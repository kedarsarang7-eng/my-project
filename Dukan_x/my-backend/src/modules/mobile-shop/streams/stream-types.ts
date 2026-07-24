/**
 * MobileShop Streams — Shared Types
 *
 * Types for DynamoDB stream processing, WebSocket pull hints,
 * and partial-batch failure responses.
 *
 * Requirements: 7.4, 7.10–7.15, 8.4
 */

// ─── DynamoDB Stream Record ──────────────────────────────────────────────────

/** Decoded DynamoDB stream record with tenant and versioning metadata */
export interface StreamRecord {
  /** Unique event identity for deduplication */
  readonly eventId: string;
  /** Tenant ID extracted from the partition key */
  readonly tenantId: string;
  /** Entity type (e.g., UNIT, INVOICE, SERVICE_JOB, etc.) */
  readonly entityType: string;
  /** Entity ID */
  readonly entityId: string;
  /** Current entity version after the change */
  readonly version: number;
  /** Data model version for compatibility checks */
  readonly dataModelVersion: number;
  /** Action that produced this record */
  readonly action: StreamAction;
  /** Whether this is a reconciliation/control item */
  readonly isReconciliation: boolean;
  /** Raw DynamoDB event name */
  readonly eventName: 'INSERT' | 'MODIFY' | 'REMOVE';
  /** Approximate creation timestamp from DynamoDB Streams */
  readonly approximateCreationDateTime: number;
  /** Sequence number from the stream shard */
  readonly sequenceNumber: string;
}

/** Actions that can produce a stream record */
export type StreamAction =
  | 'CREATE'
  | 'UPDATE'
  | 'DELETE'
  | 'LIFECYCLE_TRANSITION'
  | 'RECONCILIATION_STEP'
  | 'RECONCILIATION_COMPLETE'
  | 'CLAIM_CREATE'
  | 'CLAIM_RELEASE';

// ─── Pull Hint (WebSocket Notification) ──────────────────────────────────────

/**
 * Minimal WebSocket pull hint payload.
 *
 * Contains NO authoritative payload — pull remains the authority.
 * Clients use this to know what changed and trigger a bounded pull.
 */
export interface PullHint {
  /** Event identity for client-side deduplication */
  readonly eventId: string;
  /** Entity type that changed */
  readonly entityType: string;
  /** Entity ID that changed */
  readonly entityId: string;
  /** New entity version (client compares to detect gaps) */
  readonly version: number;
  /** What happened — client uses this for optimistic UI hints only */
  readonly action: StreamAction;
}

// ─── Partial Batch Failure Response ──────────────────────────────────────────

/** Individual failed item in a batch */
export interface BatchItemFailure {
  /** The sequence number of the failed record (itemIdentifier) */
  readonly itemIdentifier: string;
}

/** Response returned by the stream Lambda for partial-batch failure handling */
export interface StreamConsumerResult {
  /** Only the failed records — EventBridge Pipes retries these */
  readonly batchItemFailures: BatchItemFailure[];
}

// ─── Internal Processing Types ───────────────────────────────────────────────

/** Result of processing a single stream record */
export interface RecordProcessingResult {
  readonly sequenceNumber: string;
  readonly success: boolean;
  readonly error?: string;
}

/** Routing classification for a decoded stream record */
export type RecordRoute = 'reconciliation' | 'notification' | 'skip';

// ─── WebSocket Connection Types ──────────────────────────────────────────────

/** WebSocket connection record from ConnectionsTable */
export interface WebSocketConnection {
  /** WebSocket connection ID */
  readonly connectionId: string;
  /** Tenant ID this connection is bound to */
  readonly tenantId: string;
  /** Subject (user) ID that established the connection */
  readonly subjectId: string;
  /** When the connection was established (ISO) */
  readonly connectedAt: string;
  /** TTL epoch seconds for connection expiry */
  readonly ttl: number;
}

/** Result of sending a pull hint to a WebSocket connection */
export interface WebSocketSendResult {
  readonly connectionId: string;
  readonly success: boolean;
  /** Whether the connection was stale and removed */
  readonly removed: boolean;
  readonly error?: string;
}
