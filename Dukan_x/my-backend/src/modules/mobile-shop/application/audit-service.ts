/**
 * Audit Event Service — MobileShop Application Layer
 *
 * Creates immutable audit events and correction events for inclusion
 * in domain transactions. Deliberately exposes NO update or delete methods —
 * immutability is enforced by design, with the IAM audit-access-guard (task 3.4)
 * providing runtime enforcement.
 *
 * A correction is represented by a new linked event with `correctsEventId`
 * pointing to the original — the original is never modified.
 *
 * Requirements: 3.3, 4.3, 5.2, 8.11–8.12, 8.14
 */

import { createHash } from 'crypto';
import { randomUUID } from 'crypto';
import type { TenantContextWire } from '../schemas/common.schema';
import type { AuditAction } from '../schemas/audit-event.schema';
import {
  buildAuditEventItem,
  buildAuditTransactItem,
  buildChangeEventItem,
  buildChangeTransactItem,
  type AuditEventItem,
  type ChangeEventItem,
  type BuildAuditEventItemParams,
  type BuildChangeEventItemParams,
} from '../persistence/audit-events';
import type { TransactPutItem } from '../persistence/transaction-items';

// ─── Types ───────────────────────────────────────────────────────────────────

/** Context for creating an audit event within a domain operation */
export interface CreateAuditEventParams {
  readonly entityType: string;
  readonly entityId: string;
  readonly action: AuditAction;
  readonly operationId: string;
  readonly beforeState?: unknown;
  readonly afterState?: unknown;
  readonly evidenceRefs?: readonly string[];
  readonly reason?: string;
  readonly bucket?: string;
}

/** Context for creating a correction event */
export interface CreateCorrectionEventParams {
  readonly entityType: string;
  readonly entityId: string;
  readonly operationId: string;
  readonly originalEventId: string;
  readonly beforeState?: unknown;
  readonly afterState?: unknown;
  readonly evidenceRefs?: readonly string[];
  readonly reason?: string;
  readonly bucket?: string;
}

/** Result of creating an audit event — includes item and transact-write entry */
export interface AuditEventResult {
  readonly auditItem: AuditEventItem;
  readonly transactItem: TransactPutItem;
}

/** Result of creating a change event — includes item and transact-write entry */
export interface ChangeEventResult {
  readonly changeItem: ChangeEventItem;
  readonly transactItem: TransactPutItem;
}

// ─── Service ─────────────────────────────────────────────────────────────────

/**
 * Immutable audit event service.
 *
 * Design constraints:
 * - NO `updateAuditEvent` method — immutability enforced by design
 * - NO `deleteAuditEvent` method — immutability enforced by design
 * - Corrections are new events linked via `correctsEventId`
 */
export class AuditEventService {
  private readonly tableName: string;

  constructor(tableName: string) {
    this.tableName = tableName;
  }

  /**
   * Creates an immutable audit event item and returns it with a TransactWriteItem
   * for inclusion in the source domain transaction.
   *
   * The caller includes the returned `transactItem` in a TransactWriteItems request.
   * This ensures audit evidence is written atomically with the domain mutation.
   */
  createAuditEvent(
    ctx: TenantContextWire,
    params: CreateAuditEventParams,
  ): AuditEventResult {
    const eventId = randomUUID();
    const occurredAt = new Date().toISOString();

    const beforeDigest = params.beforeState !== undefined
      ? AuditEventService.computeDigest(params.beforeState)
      : undefined;
    const afterDigest = params.afterState !== undefined
      ? AuditEventService.computeDigest(params.afterState)
      : undefined;

    const itemParams: BuildAuditEventItemParams = {
      tenantId: ctx.tenantId,
      eventId,
      entityType: params.entityType,
      entityId: params.entityId,
      action: params.action,
      actorId: ctx.subjectId,
      correlationId: ctx.correlationId,
      operationId: params.operationId,
      beforeDigest,
      afterDigest,
      evidenceRefs: params.evidenceRefs,
      correctsEventId: null,
      reason: params.reason,
      occurredAt,
      bucket: params.bucket,
    };

    const auditItem = buildAuditEventItem(itemParams);
    const transactItem = buildAuditTransactItem(this.tableName, auditItem);

    return { auditItem, transactItem };
  }

  /**
   * Creates a correction event linked to an original event.
   *
   * A correction is a NEW immutable event with `correctsEventId` pointing to the
   * original — the original is never modified. This is the only way to amend
   * audit history.
   */
  createCorrectionEvent(
    ctx: TenantContextWire,
    params: CreateCorrectionEventParams,
  ): AuditEventResult {
    const eventId = randomUUID();
    const occurredAt = new Date().toISOString();

    const beforeDigest = params.beforeState !== undefined
      ? AuditEventService.computeDigest(params.beforeState)
      : undefined;
    const afterDigest = params.afterState !== undefined
      ? AuditEventService.computeDigest(params.afterState)
      : undefined;

    const itemParams: BuildAuditEventItemParams = {
      tenantId: ctx.tenantId,
      eventId,
      entityType: params.entityType,
      entityId: params.entityId,
      action: 'CORRECTION',
      actorId: ctx.subjectId,
      correlationId: ctx.correlationId,
      operationId: params.operationId,
      beforeDigest,
      afterDigest,
      evidenceRefs: params.evidenceRefs,
      correctsEventId: params.originalEventId,
      reason: params.reason,
      occurredAt,
      bucket: params.bucket,
    };

    const auditItem = buildAuditEventItem(itemParams);
    const transactItem = buildAuditTransactItem(this.tableName, auditItem);

    return { auditItem, transactItem };
  }

  /**
   * Creates a change-feed event item and returns it with a TransactWriteItem
   * for inclusion in the source domain transaction.
   *
   * Change events drive tenant sync pulls (AP-10) and have bounded retention.
   */
  createChangeEvent(
    ctx: TenantContextWire,
    params: {
      readonly entityType: string;
      readonly entityId: string;
      readonly entityVersion: number;
      readonly action: string;
      readonly pullRef?: string;
      readonly sequence: string;
      readonly bucket?: string;
    },
  ): ChangeEventResult {
    const eventId = randomUUID();

    const itemParams: BuildChangeEventItemParams = {
      tenantId: ctx.tenantId,
      eventId,
      entityType: params.entityType,
      entityId: params.entityId,
      entityVersion: params.entityVersion,
      action: params.action,
      pullRef: params.pullRef,
      sequence: params.sequence,
      bucket: params.bucket,
    };

    const changeItem = buildChangeEventItem(itemParams);
    const transactItem = buildChangeTransactItem(this.tableName, changeItem);

    return { changeItem, transactItem };
  }

  /**
   * Computes a SHA-256 hex digest of JSON-serialized state.
   * Used for before/after state comparison in audit trail.
   *
   * Keys are sorted for deterministic output regardless of property order.
   */
  static computeDigest(state: unknown): string {
    const serialized = JSON.stringify(state, Object.keys(state as object).sort());
    return createHash('sha256').update(serialized).digest('hex');
  }

  /**
   * Computes before and after digests for an entity state change.
   * Returns undefined digests for undefined states.
   */
  static computeBeforeAfterDigest(
    before: unknown | undefined,
    after: unknown | undefined,
  ): { beforeDigest?: string; afterDigest?: string } {
    return {
      beforeDigest: before !== undefined ? AuditEventService.computeDigest(before) : undefined,
      afterDigest: after !== undefined ? AuditEventService.computeDigest(after) : undefined,
    };
  }
}
