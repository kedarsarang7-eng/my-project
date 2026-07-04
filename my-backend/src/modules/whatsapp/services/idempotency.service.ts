// ============================================================================
// WhatsApp Automation — Idempotency Service (Task 9.1)
// ============================================================================
// Prevents duplicate Outbound_Messages for the same (eventId, recipientId) pair.
//
// MECHANISM:
//   Uses a DynamoDB conditional PutItem with `attribute_not_exists(PK)` on a
//   ProcessingMarker item keyed by (eventId, recipientId) within the business
//   partition. If the marker already exists, the conditional write fails with
//   `ConditionalCheckFailedException` — indicating the event was already
//   processed for this recipient and no duplicate message should be enqueued.
//
// KEY STRUCTURE:
//   PK = TENANT#{tenantId}#BIZ#{businessId}
//   SK = WAPROC#{eventId}#{recipientId}
//
// This ensures per-event-per-recipient deduplication scoped to a business,
// which is critical for preventing duplicate invoice deliveries.
//
// Requirements: 3.4, 9.3
// Design: AD-4 (Idempotency at two layers)
// ============================================================================

import { putItem } from '../../../config/dynamodb.config';
import { buildProcessingMarkerKeys } from '../keys';

/**
 * Result of an idempotency check.
 * - `firstTime`: This is the first processing of this (eventId, recipient) pair.
 * - `duplicate`: This (eventId, recipient) pair was already processed — skip.
 */
export type IdempotencyResult =
  | { status: 'firstTime' }
  | { status: 'duplicate' };

/**
 * Atomically marks an (eventId, recipientId) pair as "processing" for a given
 * business. Uses DynamoDB conditional write (`attribute_not_exists`) to guarantee
 * exactly-once semantics even under concurrent Lambda invocations.
 *
 * @param tenantId    - Authenticated tenant identifier (session-derived)
 * @param businessId  - Authenticated business identifier (session-derived)
 * @param eventId     - Unique identifier of the Business_Event being processed
 * @param recipientId - Unique identifier of the target recipient (customerId)
 *
 * @returns `{ status: 'firstTime' }` if the marker was created (proceed with enqueue)
 *          `{ status: 'duplicate' }` if the marker already existed (skip — already processed)
 */
export async function checkAndMarkProcessed(
  tenantId: string,
  businessId: string,
  eventId: string,
  recipientId: string,
): Promise<IdempotencyResult> {
  const keys = buildProcessingMarkerKeys(tenantId, businessId, eventId, recipientId);
  const now = new Date().toISOString();

  const item: Record<string, unknown> = {
    PK: keys.PK,
    SK: keys.SK,
    GSI1PK: keys.GSI1PK,
    GSI1SK: keys.GSI1SK,
    entityType: keys.entityType,
    tenantId,
    businessId,
    eventId,
    recipientId,
    createdAt: now,
  };

  try {
    // Conditional PutItem: only succeeds if no item with this PK+SK exists.
    // If the item already exists, DynamoDB throws ConditionalCheckFailedException.
    await putItem(item, 'attribute_not_exists(PK)');
    return { status: 'firstTime' };
  } catch (err: unknown) {
    if (
      err instanceof Error &&
      err.name === 'ConditionalCheckFailedException'
    ) {
      // Marker already exists — this (eventId, recipientId) was already processed.
      return { status: 'duplicate' };
    }
    // Unexpected error — propagate so the caller can retry or DLQ the event.
    throw err;
  }
}

/**
 * Checks whether an (eventId, recipientId) pair has already been processed,
 * WITHOUT marking it. Useful for read-only idempotency checks (e.g., in status queries).
 *
 * @returns true if the marker exists (already processed), false otherwise.
 */
export async function isAlreadyProcessed(
  tenantId: string,
  businessId: string,
  eventId: string,
  recipientId: string,
): Promise<boolean> {
  // We import getItem here to avoid unnecessary dependencies in the hot path.
  const { getItem } = await import('../../../config/dynamodb.config');
  const keys = buildProcessingMarkerKeys(tenantId, businessId, eventId, recipientId);
  const existing = await getItem(keys.PK, keys.SK);
  return existing !== null;
}
