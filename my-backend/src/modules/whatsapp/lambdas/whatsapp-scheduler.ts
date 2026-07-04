// ============================================================================
// WhatsApp Automation — Scheduler Lambda (Task 10.4)
// ============================================================================
// EventBridge Scheduler-triggered sweeper that queries for WASCHED# items
// whose due time has passed and enqueues them into the SQS dispatch queue.
//
// TRIGGER: EventBridge Scheduler (e.g., every 30 seconds)
//
// DESIGN CONTRACTS:
// - Queries ALL businesses for due WASCHED# entries (since this is a global
//   sweeper, it scans the GSI1 for WA_SCHED entity type).
// - For each due entry, sends an SQS FIFO message to the dispatch queue with
//   MessageGroupId = businessId#recipientId (preserves per-recipient order).
// - Deletes the WASCHED# entry after successful SQS enqueue (exactly-once
//   semantics via the idempotency layer at the engine level).
// - Must dispatch within 60 seconds of the configured time (Req 3.3).
// - Correctly tracks which customer/invoice each scheduled message belongs to.
//
// ARCHITECTURE:
// - The scheduler does NOT dispatch messages directly. It moves due scheduled
//   items into the SQS Message_Queue where the whatsappDispatcher picks them up.
// - This separation ensures rate limiting, retry policy, and ordering are all
//   handled uniformly by the dispatcher.
//
// Requirements: 3.3, 11.2
// ============================================================================

import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';
import { queryItems, deleteItem } from '../../../config/dynamodb.config';
import { businessPK } from '../../../dynamodb/keys';
import {
  WASCHED_SK_PREFIX,
  WA_ENTITY_TYPE,
} from '../keys';

// ── Environment ───────────────────────────────────────────────────────────────

const DISPATCH_QUEUE_URL = process.env.WA_DISPATCH_QUEUE_URL || '';
const AWS_REGION = process.env.AWS_REGION || 'ap-south-1';

// ── SQS Client ────────────────────────────────────────────────────────────────

const sqsClient = new SQSClient({ region: AWS_REGION });

// ── Types ─────────────────────────────────────────────────────────────────────

interface ScheduledItem {
  PK: string;
  SK: string;
  tenantId: string;
  businessId: string;
  messageId: string;
  eventId: string;
  recipientId: string;
  ruleId: string;
  dueTime: string;
  createdAt: string;
}

interface SchedulerResult {
  /** Total number of due items found across all businesses. */
  totalDue: number;
  /** Number of items successfully enqueued. */
  enqueued: number;
  /** Number of items that failed to enqueue (will be retried next tick). */
  failed: number;
  /** Errors encountered during processing. */
  errors: string[];
}

// ── Sweeper Logic ─────────────────────────────────────────────────────────────

/**
 * Queries for scheduled dispatch items whose due time has passed for a
 * specific business partition.
 *
 * Uses the base-table SK prefix query: begins_with(SK, 'WASCHED#') with a
 * filter for dueTime <= now. Since ISO timestamps sort lexicographically,
 * the natural SK ordering gives us oldest-due-first.
 */
async function queryDueItemsForBusiness(
  tenantId: string,
  businessId: string,
  now: string,
  limit = 50,
): Promise<ScheduledItem[]> {
  const pk = businessPK(tenantId, businessId);

  const result = await queryItems<ScheduledItem>(pk, WASCHED_SK_PREFIX, {
    limit,
    scanIndexForward: true, // oldest first — dispatch in due-time order
    filterExpression: 'dueTime <= :now AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
    expressionAttributeValues: { ':now': now, ':false': false },
  });

  return result.items;
}

/**
 * Queries all scheduled dispatch items across all businesses using GSI1.
 * GSI1PK for scheduled items follows: TENANT#{t}#BIZ#{b}#WA_SCHED
 *
 * Since we can't easily scan all businesses, we use a GSI1 scan approach
 * with a filter on dueTime. For production at scale, this would be
 * replaced with a DynamoDB Stream + Lambda or a dedicated scheduling table.
 *
 * For the current design, the scheduler is invoked with a list of known
 * active business partitions (passed via the event or maintained in config).
 * If no business list is provided, it uses a GSI1 scan filtered by entity type.
 */
async function queryAllDueItems(
  now: string,
  businessPartitions?: Array<{ tenantId: string; businessId: string }>,
  limit = 100,
): Promise<ScheduledItem[]> {
  // If explicit business partitions are provided, query each one
  if (businessPartitions && businessPartitions.length > 0) {
    const allItems: ScheduledItem[] = [];
    for (const { tenantId, businessId } of businessPartitions) {
      const items = await queryDueItemsForBusiness(tenantId, businessId, now, limit);
      allItems.push(...items);
      // Safety cap to prevent runaway in a single invocation
      if (allItems.length >= limit) break;
    }
    return allItems.slice(0, limit);
  }

  // Fallback: scan GSI1 for WA_SCHED entities with dueTime <= now
  // This is less efficient but works for bootstrapping / low volume.
  const { scanTable } = await import('../../../config/dynamodb.config');
  const items = await scanTable<ScheduledItem>(
    'entityType = :entityType AND dueTime <= :now AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
    { ':entityType': WA_ENTITY_TYPE.SCHEDULED_DISPATCH, ':now': now, ':false': false },
    undefined,
    limit,
  );

  return items;
}

/**
 * Enqueues a single scheduled message into the SQS dispatch queue.
 * Uses MessageGroupId = businessId#recipientId for FIFO ordering.
 * Uses messageId as the deduplication ID to prevent double-enqueue.
 */
async function enqueueToDispatchQueue(item: ScheduledItem): Promise<void> {
  if (!DISPATCH_QUEUE_URL) {
    throw new Error('WA_DISPATCH_QUEUE_URL environment variable not set');
  }

  const messageBody = JSON.stringify({
    action: 'dispatch_scheduled',
    tenantId: item.tenantId,
    businessId: item.businessId,
    messageId: item.messageId,
    eventId: item.eventId,
    recipientId: item.recipientId,
    ruleId: item.ruleId,
    scheduledDueTime: item.dueTime,
    enqueuedAt: new Date().toISOString(),
  });

  await sqsClient.send(
    new SendMessageCommand({
      QueueUrl: DISPATCH_QUEUE_URL,
      MessageBody: messageBody,
      // FIFO ordering: same business + recipient preserves delivery order
      MessageGroupId: `${item.businessId}#${item.recipientId}`,
      // Dedup: prevent double-enqueue of the same scheduled message
      MessageDeduplicationId: `sched-${item.messageId}`,
    }),
  );
}

/**
 * Removes the WASCHED# entry from DynamoDB after successful enqueue.
 * This prevents re-processing on the next scheduler tick.
 */
async function removeScheduledEntry(item: ScheduledItem): Promise<void> {
  await deleteItem(item.PK, item.SK);
}

// ── Lambda Handler ────────────────────────────────────────────────────────────

/**
 * EventBridge Scheduler event payload.
 * May optionally contain a list of business partitions to sweep.
 */
interface SchedulerEvent {
  /** Optional: explicit business partitions to sweep. */
  businessPartitions?: Array<{ tenantId: string; businessId: string }>;
  /** Optional: override the "now" time (useful for testing). */
  now?: string;
  /** Optional: max items to process per invocation. */
  limit?: number;
}

/**
 * Main Lambda handler for the whatsappScheduler.
 *
 * Triggered by EventBridge Scheduler at a regular interval (e.g., every 30s).
 * Sweeps all due WASCHED# entries and enqueues them into the dispatch queue.
 *
 * The 60-second dispatch guarantee (Req 3.3) is met by:
 * 1. EventBridge Scheduler runs every 30 seconds (configurable).
 * 2. Each invocation processes due items immediately.
 * 3. Worst case: item becomes due just after a tick → next tick (30s) picks it up
 *    + processing time (~5s) = ~35s total latency, well within 60s.
 */
export async function handler(
  event: SchedulerEvent = {},
): Promise<SchedulerResult> {
  const now = event.now || new Date().toISOString();
  const limit = event.limit || 100;

  const result: SchedulerResult = {
    totalDue: 0,
    enqueued: 0,
    failed: 0,
    errors: [],
  };

  try {
    // Query for all due scheduled items
    const dueItems = await queryAllDueItems(now, event.businessPartitions, limit);
    result.totalDue = dueItems.length;

    if (dueItems.length === 0) {
      return result;
    }

    // Process each due item: enqueue to SQS, then delete the schedule entry
    for (const item of dueItems) {
      try {
        // Step 1: Enqueue the message into the dispatch queue
        await enqueueToDispatchQueue(item);

        // Step 2: Remove the WASCHED# entry (prevents re-processing)
        await removeScheduledEntry(item);

        result.enqueued++;
      } catch (err: unknown) {
        // Individual item failure — log and continue with remaining items.
        // The failed entry stays in WASCHED# and will be retried next tick.
        result.failed++;
        const errorMsg = err instanceof Error ? err.message : String(err);
        result.errors.push(
          `Failed to enqueue messageId=${item.messageId} for business=${item.businessId}: ${errorMsg}`,
        );
        console.error(
          `[whatsappScheduler] Failed to process scheduled item`,
          { messageId: item.messageId, businessId: item.businessId, error: errorMsg },
        );
      }
    }

    console.info(
      `[whatsappScheduler] Sweep complete`,
      { totalDue: result.totalDue, enqueued: result.enqueued, failed: result.failed },
    );
  } catch (err: unknown) {
    // Top-level failure — the entire sweep failed. Items remain in WASCHED#
    // and will be retried on the next EventBridge tick.
    const errorMsg = err instanceof Error ? err.message : String(err);
    result.errors.push(`Sweep failed: ${errorMsg}`);
    console.error(`[whatsappScheduler] Sweep failed`, { error: errorMsg });
  }

  return result;
}
