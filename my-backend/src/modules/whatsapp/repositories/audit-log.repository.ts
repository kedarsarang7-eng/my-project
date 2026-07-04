// ============================================================================
// WhatsApp Module — AuditLog Repository (Task 3.1) — CREATE-ONLY
// ============================================================================
// Append-only, immutable repository for AuditLogEntry items scoped to the
// authenticated BusinessID. This repository deliberately exposes NO update and
// NO delete methods.
//
// APPEND-ONLY DESIGN (Req 2.7, 7.6, 8.5, 8.7):
// Each entry captures a security- or configuration-relevant action: consent
// changes, template/rule/config modifications, and webhook rejections. Once
// written, an audit log entry is NEVER modified or removed.
//
// RETENTION: Audit_Log entries are retained for at least 365 days (Req 8.7).
// Enforced via DynamoDB TTL set to createdAt + 365 days, and the absence of any
// delete operation.
//
// SK: WAAUDIT#{isoTimestamp}#{eventId}
//
// Requirements: 2.7, 7.6, 8.5, 8.7, 12.1
// ============================================================================

import { randomUUID } from 'crypto';
import { getItem, putItem, queryItems } from '../../../config/dynamodb.config';
import { ConflictError } from '../../../utils/errors';
import {
  buildAuditLogKeys,
  WAAUDIT_SK_PREFIX,
  WA_ENTITY_TYPE,
} from '../keys';
import type { AuditLogEntry } from '../schemas/entities';

/** 365 days in milliseconds for TTL computation. */
const RETENTION_MS = 365 * 24 * 60 * 60 * 1000;

/** Stored DynamoDB item shape. Immutable once written. */
type AuditLogItem = AuditLogEntry & {
  PK: string;
  SK: string;
  GSI1PK?: string;
  GSI1SK?: string;
  entityType: string;
  ttl: number; // DynamoDB TTL epoch seconds for 365-day retention
};

function toDomain(item: AuditLogItem): AuditLogEntry {
  return {
    id: item.id,
    businessId: item.businessId,
    tenantId: item.tenantId,
    actor: item.actor,
    action: item.action,
    target: item.target,
    before: item.before,
    after: item.after,
    timestamp: item.timestamp,
  };
}

/** Input for appending a new audit log entry. */
export interface AuditLogCreateInput {
  actor: string;
  action: string;
  target: string;
  before?: unknown;
  after?: unknown;
}

export class AuditLogRepository {
  /**
   * Append a new immutable audit log entry. Uses conditional PutItem
   * (`attribute_not_exists(SK)`) so an existing entry is NEVER overwritten
   * — the timestamp+eventId SK is effectively write-once.
   *
   * The TTL attribute is set to 365 days after creation to enforce minimum
   * retention (Req 8.7). DynamoDB will not automatically delete items before
   * the TTL expires.
   *
   * @throws ConflictError if an entry with the same (timestamp, eventId) already exists.
   */
  async create(
    tenantId: string,
    businessId: string,
    data: AuditLogCreateInput,
  ): Promise<AuditLogEntry> {
    const id = randomUUID();
    const now = new Date().toISOString();
    const keys = buildAuditLogKeys(tenantId, businessId, now, id);

    // TTL: 365 days from creation in epoch seconds.
    const ttl = Math.floor((Date.now() + RETENTION_MS) / 1000);

    const item: AuditLogItem = {
      PK: keys.PK,
      SK: keys.SK,
      GSI1PK: keys.GSI1PK,
      GSI1SK: keys.GSI1SK,
      entityType: WA_ENTITY_TYPE.AUDIT_LOG,
      id,
      tenantId,
      businessId,
      actor: data.actor,
      action: data.action,
      target: data.target,
      before: data.before,
      after: data.after,
      timestamp: now,
      ttl,
    };

    try {
      // Append-only guarantee: never overwrite an existing audit entry.
      await putItem(item as unknown as Record<string, unknown>, 'attribute_not_exists(SK)');
    } catch (err) {
      if ((err as { name?: string }).name === 'ConditionalCheckFailedException') {
        throw new ConflictError(
          `Audit log entry ${id} already exists and is immutable`,
        );
      }
      throw err;
    }

    return toDomain(item);
  }

  /**
   * Fetch a single audit log entry. Returns null when absent.
   * There is no soft-delete — entries are never removed (within retention).
   */
  async get(
    tenantId: string,
    businessId: string,
    isoTimestamp: string,
    eventId: string,
  ): Promise<AuditLogEntry | null> {
    const keys = buildAuditLogKeys(tenantId, businessId, isoTimestamp, eventId);
    const item = await getItem<AuditLogItem>(keys.PK, keys.SK);
    return item ? toDomain(item) : null;
  }

  /**
   * List audit log entries for a business, optionally constrained to a
   * timestamp prefix (e.g. a date 'YYYY-MM-DD' or month 'YYYY-MM').
   * Timestamp-first SK gives natural chronological order.
   */
  async listByWindow(
    tenantId: string,
    businessId: string,
    opts?: { timestampPrefix?: string; limit?: number; scanIndexForward?: boolean },
  ): Promise<AuditLogEntry[]> {
    const keys = buildAuditLogKeys(tenantId, businessId, '1970-01-01T00:00:00.000Z', 'x');
    const skPrefix = opts?.timestampPrefix
      ? `${WAAUDIT_SK_PREFIX}${opts.timestampPrefix}`
      : WAAUDIT_SK_PREFIX;
    const result = await queryItems<AuditLogItem>(keys.PK, skPrefix, {
      limit: opts?.limit,
      scanIndexForward: opts?.scanIndexForward ?? true,
    });
    return result.items.map(toDomain);
  }

  /**
   * List audit log entries filtered by action type.
   * Useful for retrieving all consent changes, config updates, etc.
   */
  async listByAction(
    tenantId: string,
    businessId: string,
    action: string,
    opts?: { limit?: number; scanIndexForward?: boolean },
  ): Promise<AuditLogEntry[]> {
    const keys = buildAuditLogKeys(tenantId, businessId, '1970-01-01T00:00:00.000Z', 'x');
    const result = await queryItems<AuditLogItem>(keys.PK, WAAUDIT_SK_PREFIX, {
      filterExpression: '#action = :action',
      expressionAttributeValues: { ':action': action },
      expressionAttributeNames: { '#action': 'action' },
      limit: opts?.limit,
      scanIndexForward: opts?.scanIndexForward ?? true,
    });
    return result.items.map(toDomain);
  }

  /**
   * List audit log entries filtered by target entity.
   * Useful for retrieving the audit trail of a specific template, rule, or customer.
   */
  async listByTarget(
    tenantId: string,
    businessId: string,
    target: string,
    opts?: { limit?: number; scanIndexForward?: boolean },
  ): Promise<AuditLogEntry[]> {
    const keys = buildAuditLogKeys(tenantId, businessId, '1970-01-01T00:00:00.000Z', 'x');
    const result = await queryItems<AuditLogItem>(keys.PK, WAAUDIT_SK_PREFIX, {
      filterExpression: '#target = :target',
      expressionAttributeValues: { ':target': target },
      expressionAttributeNames: { '#target': 'target' },
      limit: opts?.limit,
      scanIndexForward: opts?.scanIndexForward ?? true,
    });
    return result.items.map(toDomain);
  }
}
