// ============================================================================
// WhatsApp Module — DeliveryLog Repository (Task 3.1) — CREATE-ONLY
// ============================================================================
// Append-only, immutable repository for DeliveryLogEntry items scoped to the
// authenticated BusinessID. This repository deliberately exposes NO update and
// NO delete methods.
//
// APPEND-ONLY DESIGN (Req 8.3, 8.7):
// Each entry captures a single state transition for an outbound message.
// Once written, a delivery log entry is NEVER modified or removed. Corrections
// or new state transitions produce new entries (timestamp-first SK ordering).
//
// RETENTION: Delivery_Log entries are retained for at least 365 days (Req 8.7).
// This is enforced via DynamoDB TTL set to createdAt + 365 days, and by the
// absence of any delete operation.
//
// SK: WADLOG#{isoTimestamp}#{logId}
//
// Requirements: 8.3, 8.7, 12.1
// ============================================================================

import { randomUUID } from 'crypto';
import { getItem, putItem, queryItems } from '../../../config/dynamodb.config';
import { ConflictError } from '../../../utils/errors';
import {
  buildDeliveryLogKeys,
  deliveryLogSK,
  WADLOG_SK_PREFIX,
  WA_ENTITY_TYPE,
} from '../keys';
import type { DeliveryLogEntry, DeliveryLogState } from '../schemas/entities';

/** 365 days in milliseconds for TTL computation. */
const RETENTION_MS = 365 * 24 * 60 * 60 * 1000;

/** Stored DynamoDB item shape. Immutable once written. */
type DeliveryLogItem = DeliveryLogEntry & {
  PK: string;
  SK: string;
  GSI1PK?: string;
  GSI1SK?: string;
  entityType: string;
  ttl: number; // DynamoDB TTL epoch seconds for 365-day retention
};

function toDomain(item: DeliveryLogItem): DeliveryLogEntry {
  return {
    id: item.id,
    businessId: item.businessId,
    tenantId: item.tenantId,
    outboundMessageId: item.outboundMessageId,
    state: item.state,
    reason: item.reason,
    timestamp: item.timestamp,
  };
}

/** Input for appending a new delivery log entry. */
export interface DeliveryLogCreateInput {
  outboundMessageId: string;
  state: DeliveryLogState;
  reason?: string;
}

export class DeliveryLogRepository {
  /**
   * Append a new immutable delivery log entry. Uses conditional PutItem
   * (`attribute_not_exists(SK)`) so an existing entry is NEVER overwritten
   * — the timestamp+logId SK is effectively write-once.
   *
   * The TTL attribute is set to 365 days after creation to enforce minimum
   * retention (Req 8.7). DynamoDB will not automatically delete items before
   * the TTL expires.
   *
   * @throws ConflictError if an entry with the same (timestamp, logId) already exists.
   */
  async create(
    tenantId: string,
    businessId: string,
    data: DeliveryLogCreateInput,
  ): Promise<DeliveryLogEntry> {
    const id = randomUUID();
    const now = new Date().toISOString();
    const keys = buildDeliveryLogKeys(tenantId, businessId, now, id);

    // TTL: 365 days from creation in epoch seconds.
    const ttl = Math.floor((Date.now() + RETENTION_MS) / 1000);

    const item: DeliveryLogItem = {
      PK: keys.PK,
      SK: keys.SK,
      GSI1PK: keys.GSI1PK,
      GSI1SK: keys.GSI1SK,
      entityType: WA_ENTITY_TYPE.DELIVERY_LOG,
      id,
      tenantId,
      businessId,
      outboundMessageId: data.outboundMessageId,
      state: data.state,
      reason: data.reason,
      timestamp: now,
      ttl,
    };

    try {
      // Append-only guarantee: never overwrite an existing log entry.
      await putItem(item as unknown as Record<string, unknown>, 'attribute_not_exists(SK)');
    } catch (err) {
      if ((err as { name?: string }).name === 'ConditionalCheckFailedException') {
        throw new ConflictError(
          `Delivery log entry ${id} already exists and is immutable`,
        );
      }
      throw err;
    }

    return toDomain(item);
  }

  /**
   * Fetch a single delivery log entry. Returns null when absent.
   * There is no soft-delete — entries are never removed (within retention).
   */
  async get(
    tenantId: string,
    businessId: string,
    isoTimestamp: string,
    logId: string,
  ): Promise<DeliveryLogEntry | null> {
    const keys = buildDeliveryLogKeys(tenantId, businessId, isoTimestamp, logId);
    const item = await getItem<DeliveryLogItem>(keys.PK, keys.SK);
    return item ? toDomain(item) : null;
  }

  /**
   * List delivery log entries for a business, optionally constrained to a
   * timestamp prefix (e.g. a date 'YYYY-MM-DD' or month 'YYYY-MM').
   * Timestamp-first SK gives natural chronological order.
   */
  async listByWindow(
    tenantId: string,
    businessId: string,
    opts?: { timestampPrefix?: string; limit?: number; scanIndexForward?: boolean },
  ): Promise<DeliveryLogEntry[]> {
    const keys = buildDeliveryLogKeys(tenantId, businessId, '1970-01-01T00:00:00.000Z', 'x');
    const skPrefix = opts?.timestampPrefix
      ? `${WADLOG_SK_PREFIX}${opts.timestampPrefix}`
      : WADLOG_SK_PREFIX;
    const result = await queryItems<DeliveryLogItem>(keys.PK, skPrefix, {
      limit: opts?.limit,
      scanIndexForward: opts?.scanIndexForward ?? true,
    });
    return result.items.map(toDomain);
  }

  /**
   * List all delivery log entries for a specific outbound message.
   * Uses a filter expression on the outboundMessageId.
   */
  async listByMessageId(
    tenantId: string,
    businessId: string,
    outboundMessageId: string,
    opts?: { limit?: number },
  ): Promise<DeliveryLogEntry[]> {
    const keys = buildDeliveryLogKeys(tenantId, businessId, '1970-01-01T00:00:00.000Z', 'x');
    const result = await queryItems<DeliveryLogItem>(keys.PK, WADLOG_SK_PREFIX, {
      filterExpression: 'outboundMessageId = :msgId',
      expressionAttributeValues: { ':msgId': outboundMessageId },
      limit: opts?.limit,
    });
    return result.items.map(toDomain);
  }
}
