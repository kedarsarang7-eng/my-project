/**
 * Audit & Change Event Persistence — MobileShop DynamoDB
 *
 * Constructs immutable DynamoDB items for audit events and change-feed events.
 * These are always appended — no update or delete methods exist by design.
 *
 * Audit events use:
 *   PK  = TENANT#<tenantId>#AUDIT#<bucket>        (bucketed for bounded access)
 *   SK  = <occurredAt>#<eventId>                  (chronological ordering)
 *   GSI2PK = TENANT#<tenantId>#AUDIT#<entityType>#<entityId>  (entity timeline AP-11)
 *   GSI2SK = <occurredAt>#<eventId>
 *
 * Change events use:
 *   PK  = TENANT#<tenantId>#CHANGE#<bucket>       (bucketed for change feed AP-10)
 *   SK  = <sequence>#<eventId>                    (ordered consumption)
 *
 * Requirements: 3.3, 4.3, 5.2, 8.11–8.12, 8.14
 */

import type { TenantContextWire } from '../schemas/common.schema';
import type { AuditAction } from '../schemas/audit-event.schema';
import { encodePK, encodeGSI2PK, encodeGSI2SK } from './key-codec';
import { MODEL_VERSION_CONFIG } from '../config/model-version.config';
import { RETENTION_CONFIG } from '../config/retention.config';
import type { TransactPutItem } from './transaction-items';

// ─── Constants ───────────────────────────────────────────────────────────────

/** Default audit bucket for normal-volume tenants */
const DEFAULT_AUDIT_BUCKET = '0' as const;
/** Default change-feed bucket */
const DEFAULT_CHANGE_BUCKET = '0' as const;

// ─── Audit Event Item Types ──────────────────────────────────────────────────

/** Parameters to build an immutable audit event DynamoDB item */
export interface BuildAuditEventItemParams {
  readonly tenantId: string;
  readonly eventId: string;
  readonly entityType: string;
  readonly entityId: string;
  readonly action: AuditAction;
  readonly actorId: string;
  readonly actorName?: string;
  readonly correlationId: string;
  readonly operationId: string;
  readonly beforeDigest?: string;
  readonly afterDigest?: string;
  readonly evidenceRefs?: readonly string[];
  readonly correctsEventId?: string | null;
  readonly reason?: string;
  readonly occurredAt: string;
  readonly bucket?: string;
}

/** The constructed audit event DynamoDB item (ready for Put) */
export interface AuditEventItem {
  readonly PK: string;
  readonly SK: string;
  readonly GSI2PK: string;
  readonly GSI2SK: string;
  readonly tenantId: string;
  readonly eventId: string;
  readonly entityType: string;
  readonly entityId: string;
  readonly action: AuditAction;
  readonly actorId: string;
  readonly actorName?: string;
  readonly correlationId: string;
  readonly operationId: string;
  readonly beforeDigest?: string;
  readonly afterDigest?: string;
  readonly evidenceRefs?: readonly string[];
  readonly correctsEventId?: string | null;
  readonly reason?: string;
  readonly occurredAt: string;
  readonly dataModelVersion: number;
  readonly createdAt: string;
}

// ─── Change Event Item Types ─────────────────────────────────────────────────

/** Parameters to build a change-feed DynamoDB item */
export interface BuildChangeEventItemParams {
  readonly tenantId: string;
  readonly eventId: string;
  readonly entityType: string;
  readonly entityId: string;
  readonly entityVersion: number;
  readonly action: string;
  readonly pullRef?: string;
  readonly sequence: string;
  readonly bucket?: string;
}

/** The constructed change event DynamoDB item (ready for Put) */
export interface ChangeEventItem {
  readonly PK: string;
  readonly SK: string;
  readonly tenantId: string;
  readonly eventId: string;
  readonly entityType: string;
  readonly entityId: string;
  readonly entityVersion: number;
  readonly action: string;
  readonly pullRef?: string;
  readonly dataModelVersion: number;
  readonly createdAt: string;
  readonly expiresAt: number;
}

// ─── Audit Event Builder ─────────────────────────────────────────────────────

/**
 * Constructs an immutable audit event DynamoDB item.
 *
 * Key structure:
 *   PK  = TENANT#<tenantId>#AUDIT#<bucket>
 *   SK  = <occurredAt>#<eventId>
 *   GSI2PK = TENANT#<tenantId>#AUDIT#<entityType>#<entityId>
 *   GSI2SK = <occurredAt>#<eventId>
 *
 * No `updatedAt` — immutable by design.
 */
export function buildAuditEventItem(params: BuildAuditEventItemParams): AuditEventItem {
  const bucket = params.bucket ?? DEFAULT_AUDIT_BUCKET;
  const now = new Date().toISOString();

  const pk = encodePK(params.tenantId, 'AUDIT', bucket);
  const sk = `${params.occurredAt}#${params.eventId}`;

  // GSI2 for entity timeline (AP-11)
  const gsi2pk = encodeGSI2PK(params.tenantId, 'AUDIT', `${params.entityType}#${params.entityId}`);
  const gsi2sk = encodeGSI2SK(params.occurredAt, params.eventId);

  const item: AuditEventItem = {
    PK: pk,
    SK: sk,
    GSI2PK: gsi2pk,
    GSI2SK: gsi2sk,
    tenantId: params.tenantId,
    eventId: params.eventId,
    entityType: params.entityType,
    entityId: params.entityId,
    action: params.action,
    actorId: params.actorId,
    ...(params.actorName !== undefined && { actorName: params.actorName }),
    correlationId: params.correlationId,
    operationId: params.operationId,
    ...(params.beforeDigest !== undefined && { beforeDigest: params.beforeDigest }),
    ...(params.afterDigest !== undefined && { afterDigest: params.afterDigest }),
    ...(params.evidenceRefs !== undefined && params.evidenceRefs.length > 0 && {
      evidenceRefs: params.evidenceRefs,
    }),
    correctsEventId: params.correctsEventId ?? null,
    ...(params.reason !== undefined && { reason: params.reason }),
    occurredAt: params.occurredAt,
    dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
    createdAt: now,
  };

  return item;
}

// ─── Change Event Builder ────────────────────────────────────────────────────

/**
 * Constructs a change-feed DynamoDB item for tenant sync (AP-10).
 *
 * Key structure:
 *   PK = TENANT#<tenantId>#CHANGE#<bucket>
 *   SK = <sequence>#<eventId>
 *
 * Includes `expiresAt` TTL for bounded retention.
 */
export function buildChangeEventItem(params: BuildChangeEventItemParams): ChangeEventItem {
  const bucket = params.bucket ?? DEFAULT_CHANGE_BUCKET;
  const now = new Date();
  const nowIso = now.toISOString();
  const expiresAt = Math.floor(now.getTime() / 1000) + RETENTION_CONFIG.changeFeed.ttlSeconds;

  const pk = encodePK(params.tenantId, 'CHANGE', bucket);
  const sk = `${params.sequence}#${params.eventId}`;

  const item: ChangeEventItem = {
    PK: pk,
    SK: sk,
    tenantId: params.tenantId,
    eventId: params.eventId,
    entityType: params.entityType,
    entityId: params.entityId,
    entityVersion: params.entityVersion,
    action: params.action,
    ...(params.pullRef !== undefined && { pullRef: params.pullRef }),
    dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
    createdAt: nowIso,
    expiresAt,
  };

  return item;
}

// ─── TransactWriteItem Builders ──────────────────────────────────────────────

/**
 * Returns a TransactWriteItem Put for including an audit event in a domain transaction.
 * NO condition expression — audit events are always appended (immutable, never overwritten).
 */
export function buildAuditTransactItem(
  tableName: string,
  auditItem: AuditEventItem,
): TransactPutItem {
  return {
    Put: {
      TableName: tableName,
      Item: auditItem as unknown as Record<string, unknown>,
      ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
    },
  };
}

/**
 * Returns a TransactWriteItem Put for including a change event in a domain transaction.
 * NO condition expression beyond first-write safety — change events are always appended.
 */
export function buildChangeTransactItem(
  tableName: string,
  changeItem: ChangeEventItem,
): TransactPutItem {
  return {
    Put: {
      TableName: tableName,
      Item: changeItem as unknown as Record<string, unknown>,
      ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
    },
  };
}
