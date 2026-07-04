// ============================================================================
// WhatsApp Module — OutboundMessage Repository (Task 3.1)
// ============================================================================
// CRUD for OutboundMessage entities scoped to the authenticated BusinessID.
// OutboundMessage is the durable source of truth for the message lifecycle
// (AD-3). Status transitions are lifecycle-driven — the dispatcher and webhook
// handler update state here.
//
// SK: WAOUT#{messageId}
//
// Requirements: 8.3, 9.1, 9.2, 12.1, 14.4
// ============================================================================

import { queryItems as queryItemsFn } from '../../../config/dynamodb.config';
import {
  buildOutboundMessageKeys,
  WAOUT_SK_PREFIX,
  WA_ENTITY_TYPE,
  type WaEntityKeys,
  type WaEntityType,
} from '../keys';
import { WaBaseRepository, type WaBaseItem } from './base.repository';
import type { OutboundMessage, OutboundMessageStatus } from '../schemas/entities';

/** Input for creating a new OutboundMessage (durable enqueue). */
export interface OutboundMessageCreateInput {
  eventId: string;
  recipientId: string;
  recipientNumber: string;
  templateId: string;
  templateVersion: number;
  renderedBody: string;
  mediaUrl?: string;
  branchId?: string;
  expiresAt?: string;
}

export class OutboundMessageRepository extends WaBaseRepository<OutboundMessage, OutboundMessageCreateInput> {
  protected readonly entityType: WaEntityType = WA_ENTITY_TYPE.OUTBOUND_MESSAGE;
  protected readonly skPrefix = WAOUT_SK_PREFIX;

  protected buildKeys(
    tenantId: string,
    businessId: string,
    id: string,
    extras?: Record<string, string>,
  ): WaEntityKeys {
    const isoTimestamp = extras?.isoDate ?? new Date().toISOString();
    return buildOutboundMessageKeys(tenantId, businessId, id, isoTimestamp);
  }

  protected toDomain(item: WaBaseItem & Record<string, unknown>): OutboundMessage {
    return {
      id: item.id,
      businessId: item.businessId,
      tenantId: item.tenantId as string,
      branchId: item.branchId as string | undefined,
      eventId: item.eventId as string,
      recipientId: item.recipientId as string,
      recipientNumber: item.recipientNumber as string,
      templateId: item.templateId as string,
      templateVersion: item.templateVersion as number,
      renderedBody: item.renderedBody as string,
      mediaUrl: item.mediaUrl as string | undefined,
      status: item.status as OutboundMessageStatus,
      attempts: (item.attempts as number) ?? 0,
      lastError: item.lastError as string | undefined,
      nextAttemptAt: item.nextAttemptAt as string | undefined,
      expiresAt: item.expiresAt as string | undefined,
      providerMessageId: item.providerMessageId as string | undefined,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    };
  }

  protected buildCreateItem(
    tenantId: string,
    businessId: string,
    id: string,
    keys: WaEntityKeys,
    data: OutboundMessageCreateInput,
    now: string,
  ): WaBaseItem & Record<string, unknown> {
    return {
      PK: keys.PK,
      SK: keys.SK,
      GSI1PK: keys.GSI1PK,
      GSI1SK: keys.GSI1SK,
      entityType: this.entityType,
      tenantId,
      businessId,
      id,
      branchId: data.branchId,
      eventId: data.eventId,
      recipientId: data.recipientId,
      recipientNumber: data.recipientNumber,
      templateId: data.templateId,
      templateVersion: data.templateVersion,
      renderedBody: data.renderedBody,
      mediaUrl: data.mediaUrl,
      status: 'queued' as OutboundMessageStatus,
      attempts: 0,
      expiresAt: data.expiresAt,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };
  }

  /**
   * Transition the message status. Used by the dispatcher (sent/failed/expired)
   * and by the webhook handler (delivered/read). Only valid forward transitions
   * are expected — the caller is responsible for transition validation.
   */
  async updateStatus(
    tenantId: string,
    businessId: string,
    messageId: string,
    status: OutboundMessageStatus,
    extra?: {
      attempts?: number;
      lastError?: string;
      nextAttemptAt?: string;
      providerMessageId?: string;
    },
  ): Promise<OutboundMessage | null> {
    const fields: Record<string, unknown> = { status };
    if (extra?.attempts !== undefined) fields.attempts = extra.attempts;
    if (extra?.lastError !== undefined) fields.lastError = extra.lastError;
    if (extra?.nextAttemptAt !== undefined) fields.nextAttemptAt = extra.nextAttemptAt;
    if (extra?.providerMessageId !== undefined) fields.providerMessageId = extra.providerMessageId;
    return this.update(tenantId, businessId, messageId, fields);
  }

  /**
   * Find the OutboundMessage whose `providerMessageId` matches the WhatsApp
   * message id reported by an OpenWA webhook. OpenWA's webhook payload only
   * ever carries its own message id (e.g. `true_628123456789@c.us_3EB0ABCD`)
   * and the OpenWA `sessionId` — never our internal OutboundMessage.id — so
   * webhook resolution MUST go through this lookup, not `get()`.
   */
  async findByProviderMessageId(
    tenantId: string,
    businessId: string,
    providerMessageId: string,
  ): Promise<OutboundMessage | null> {
    const keys = this.buildKeys(tenantId, businessId, 'x');
    const result = await queryItemsFn<WaBaseItem & Record<string, unknown>>(keys.PK, WAOUT_SK_PREFIX, {
      filterExpression:
        '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND providerMessageId = :pmid',
      expressionAttributeValues: { ':false': false, ':pmid': providerMessageId },
      limit: 1,
    });
    return result.items.length > 0 ? this.toDomain(result.items[0]) : null;
  }

  /**
   * List messages by status for a business. Useful for the dispatcher to find
   * retryable messages or for monitoring dashboards.
   */
  async listByStatus(
    tenantId: string,
    businessId: string,
    status: OutboundMessageStatus,
    opts?: { limit?: number },
  ): Promise<OutboundMessage[]> {
    const keys = this.buildKeys(tenantId, businessId, 'x');
    const result = await queryItemsFn<WaBaseItem & Record<string, unknown>>(keys.PK, WAOUT_SK_PREFIX, {
      filterExpression:
        '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND #status = :status',
      expressionAttributeValues: { ':false': false, ':status': status },
      expressionAttributeNames: { '#status': 'status' },
      limit: opts?.limit,
    });
    return result.items.map((item) => this.toDomain(item));
  }
}
