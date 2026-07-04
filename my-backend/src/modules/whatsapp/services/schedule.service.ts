// ============================================================================
// WhatsApp Automation — Schedule Service (Task 10.4)
// ============================================================================
// Pure computation of scheduled/delayed dispatch times and WASCHED# index
// management for the WhatsApp Automation module.
//
// DESIGN CONTRACTS:
// - Dispatch time = event time + delay (delaySeconds) OR absolute time (at).
// - Delay range: 1 second to 365 days (31,536,000 seconds).
// - The computed due time is stored as a WASCHED# index entry in DynamoDB.
// - The whatsappScheduler sweeper queries for due entries and enqueues them.
// - Dispatch must occur within 60 seconds of the configured time (Req 3.3).
// - Each scheduled item tracks which customer/invoice it belongs to — no mixing.
//
// Requirements: 3.3, 11.2
// ============================================================================

import { putItem, queryItems, deleteItem } from '../../../config/dynamodb.config';
import {
  buildScheduledDispatchKeys,
  WASCHED_SK_PREFIX,
  WA_ENTITY_TYPE,
} from '../keys';
import { businessPK } from '../../../dynamodb/keys';

// ── Constants ─────────────────────────────────────────────────────────────────

/** Minimum delay in seconds (1 second). */
export const MIN_DELAY_SECONDS = 1;

/** Maximum delay in seconds (365 days). */
export const MAX_DELAY_SECONDS = 31_536_000; // 365 * 24 * 60 * 60

// ── Types ─────────────────────────────────────────────────────────────────────

/**
 * Schedule configuration from an AutomationRule.
 * Either delaySeconds (relative to event time) or at (absolute ISO timestamp).
 */
export interface ScheduleConfig {
  /** Relative delay from event time in seconds (1..31,536,000). */
  delaySeconds?: number;
  /** Absolute dispatch time as ISO-8601 UTC string. */
  at?: string;
}

/**
 * Input for creating a scheduled dispatch entry.
 */
export interface ScheduledDispatchInput {
  /** The tenant owning this scheduled message. */
  tenantId: string;
  /** The business owning this scheduled message. */
  businessId: string;
  /** Unique outbound message ID this schedule is for. */
  messageId: string;
  /** The event that triggered this schedule. */
  eventId: string;
  /** The recipient customer ID — ensures no mixing. */
  recipientId: string;
  /** The rule that generated this schedule. */
  ruleId: string;
  /** The time the triggering event occurred (ISO-8601 UTC). */
  eventTime: string;
  /** Schedule configuration from the rule. */
  schedule: ScheduleConfig;
}

/**
 * A scheduled dispatch record stored in DynamoDB.
 */
export interface ScheduledDispatchRecord {
  tenantId: string;
  businessId: string;
  messageId: string;
  eventId: string;
  recipientId: string;
  ruleId: string;
  dueTime: string;
  createdAt: string;
}

/**
 * Result of computing a dispatch time.
 */
export interface DispatchTimeResult {
  /** Whether the computation succeeded. */
  valid: boolean;
  /** The computed due time (ISO-8601 UTC). Undefined if invalid. */
  dueTime?: string;
  /** Error reason if invalid. */
  reason?: string;
}

// ── Pure Computation ──────────────────────────────────────────────────────────

/**
 * Computes the dispatch time from an event time and schedule configuration.
 *
 * Algorithm:
 * - If `schedule.at` is provided: use the absolute time directly (must be in the future).
 * - If `schedule.delaySeconds` is provided: add delay to event time.
 * - Delay must be within [1, 31,536,000] seconds (1s to 365 days).
 * - If neither is provided, returns invalid.
 *
 * This function is PURE — no side effects, deterministic.
 *
 * @param eventTime - The time the triggering Business_Event occurred (ISO-8601 UTC)
 * @param schedule - The schedule configuration from the AutomationRule
 * @returns DispatchTimeResult with the computed due time or an error reason
 */
export function computeDispatchTime(
  eventTime: string,
  schedule: ScheduleConfig,
): DispatchTimeResult {
  // Validate eventTime is a parseable ISO timestamp
  const eventMs = Date.parse(eventTime);
  if (isNaN(eventMs)) {
    return { valid: false, reason: 'Invalid eventTime: not a valid ISO-8601 timestamp' };
  }

  // Case 1: Absolute time
  if (schedule.at) {
    const atMs = Date.parse(schedule.at);
    if (isNaN(atMs)) {
      return { valid: false, reason: 'Invalid schedule.at: not a valid ISO-8601 timestamp' };
    }
    // The absolute time must be at or after the event time
    if (atMs < eventMs) {
      return { valid: false, reason: 'schedule.at is before the event time' };
    }
    return { valid: true, dueTime: new Date(atMs).toISOString() };
  }

  // Case 2: Relative delay
  if (schedule.delaySeconds !== undefined) {
    if (!Number.isInteger(schedule.delaySeconds)) {
      return { valid: false, reason: 'delaySeconds must be an integer' };
    }
    if (schedule.delaySeconds < MIN_DELAY_SECONDS || schedule.delaySeconds > MAX_DELAY_SECONDS) {
      return {
        valid: false,
        reason: `delaySeconds must be between ${MIN_DELAY_SECONDS} and ${MAX_DELAY_SECONDS} (1s to 365 days)`,
      };
    }
    const dueMs = eventMs + schedule.delaySeconds * 1000;
    return { valid: true, dueTime: new Date(dueMs).toISOString() };
  }

  // Neither at nor delaySeconds provided
  return { valid: false, reason: 'Schedule must specify either delaySeconds or at' };
}

// ── Persistence: Write WASCHED# Index Entry ───────────────────────────────────

/**
 * Writes a WASCHED# due-time index item to DynamoDB for a scheduled message.
 * The sweeper Lambda will later query for items whose due time has passed
 * and enqueue them into the dispatch queue.
 *
 * @param input - All data needed to create the scheduled dispatch record
 * @returns The computed due time (ISO-8601)
 * @throws If the dispatch time cannot be computed (invalid schedule config)
 */
export async function writeScheduledDispatch(
  input: ScheduledDispatchInput,
): Promise<string> {
  const { tenantId, businessId, messageId, eventId, recipientId, ruleId, eventTime, schedule } = input;

  // Compute the due time
  const result = computeDispatchTime(eventTime, schedule);
  if (!result.valid || !result.dueTime) {
    throw new Error(`Cannot compute dispatch time: ${result.reason}`);
  }

  const dueTime = result.dueTime;
  const keys = buildScheduledDispatchKeys(tenantId, businessId, dueTime, messageId);
  const now = new Date().toISOString();

  const item: Record<string, unknown> = {
    PK: keys.PK,
    SK: keys.SK,
    GSI1PK: keys.GSI1PK,
    GSI1SK: keys.GSI1SK,
    entityType: keys.entityType,
    tenantId,
    businessId,
    messageId,
    eventId,
    recipientId,
    ruleId,
    dueTime,
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  };

  await putItem(item);
  return dueTime;
}

/**
 * Removes a scheduled dispatch entry (e.g., when an invoice is paid and
 * pending reminders should be cancelled, or after the sweeper dispatches it).
 *
 * @param tenantId - The tenant identifier
 * @param businessId - The business identifier
 * @param dueTime - The due time of the scheduled entry (ISO-8601)
 * @param messageId - The outbound message ID
 */
export async function removeScheduledDispatch(
  tenantId: string,
  businessId: string,
  dueTime: string,
  messageId: string,
): Promise<void> {
  const keys = buildScheduledDispatchKeys(tenantId, businessId, dueTime, messageId);
  await deleteItem(keys.PK, keys.SK);
}

// ── Query: Find Due Scheduled Entries ─────────────────────────────────────────

/**
 * Queries for all WASCHED# items in a business partition whose due time
 * has passed (SK <= now). These are the items ready to be dispatched.
 *
 * The WASCHED# SK structure is: WASCHED#{dueIsoTimestamp}#{messageId}
 * Since ISO-8601 timestamps sort lexicographically, a begins_with('WASCHED#')
 * query with SK <= 'WASCHED#{nowTimestamp}~' captures all due entries.
 *
 * @param tenantId - The tenant identifier
 * @param businessId - The business identifier
 * @param now - The current time (ISO-8601 UTC) — entries with dueTime <= now are due
 * @param limit - Maximum entries to return per sweep (default 25)
 * @returns Array of scheduled dispatch records ready for dispatch
 */
export async function queryDueScheduledDispatches(
  tenantId: string,
  businessId: string,
  now: string,
  limit = 25,
): Promise<ScheduledDispatchRecord[]> {
  const pk = businessPK(tenantId, businessId);

  // Query all WASCHED# items in this business partition.
  // SK format: WASCHED#{dueIsoTimestamp}#{messageId}
  // Since ISO timestamps are lexicographically sortable, all items with
  // SK <= 'WASCHED#{now}~' are due (the ~ character is after all ISO chars).
  const result = await queryItems<Record<string, unknown>>(pk, WASCHED_SK_PREFIX, {
    limit,
    scanIndexForward: true, // oldest first
    filterExpression: 'dueTime <= :now AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
    expressionAttributeValues: { ':now': now, ':false': false },
  });

  return result.items.map((item) => ({
    tenantId: item.tenantId as string,
    businessId: item.businessId as string,
    messageId: item.messageId as string,
    eventId: item.eventId as string,
    recipientId: item.recipientId as string,
    ruleId: item.ruleId as string,
    dueTime: item.dueTime as string,
    createdAt: item.createdAt as string,
  }));
}
