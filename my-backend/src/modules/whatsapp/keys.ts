// ============================================================================
// WHATSAPP MODULE — DynamoDB Key Builders (Task 2.2)
// ============================================================================
// Access-pattern-first key design for the WhatsApp Automation module.
//
// SECURITY / ISOLATION INVARIANT
// ------------------------------
// EVERY WhatsApp entity is stored under the business-scoped partition:
//     PK = TENANT#{tenantId}#BIZ#{businessId}
// built ONLY via the shared `businessPK()` builder from `dynamodb/keys.ts`,
// which validates each segment and REJECTS the '#' character to prevent key
// injection. BusinessID is derived exclusively from the authenticated session
// (Req 12.4) — the key builders only accept server-validated IDs.
//
// We deliberately REUSE the platform primitives (`businessPK`, `gsi1PK`,
// `gsi1SK`, `EntityKeys`) rather than re-declaring PK logic here — this keeps a
// single source of truth for tenant scoping while letting the WhatsApp module
// own its SK prefixes (declared in `manifest.ts`).
//
// SCOPE OF THIS FILE: all WhatsApp module entities — AutomationConfig,
// MessageTemplate, MessageTemplateVersion, AutomationRule, CustomerProfile,
// OutboundMessage, DeliveryLog, AuditLog, ProcessingMarker, ScheduledDispatch,
// LowStockMarker, and CollectionWorkflowCursor.
//
// Requirements: 12.1 (business-scoped records), 12.4 (session-authoritative ID)
// ============================================================================

import {
  businessPK,
  gsi1PK,
  gsi1SK,
  type EntityKeys,
} from '../../dynamodb/keys';

// ── SK Prefix Constants (owned by the WhatsApp manifest) ────────────────────

export const WACFG_SK_PREFIX = 'WACFG#';
export const WATMPL_SK_PREFIX = 'WATMPL#';
export const WATMPLV_SK_PREFIX = 'WATMPLV#';
export const WARULE_SK_PREFIX = 'WARULE#';
export const WACUST_SK_PREFIX = 'WACUST#';
export const WAOUT_SK_PREFIX = 'WAOUT#';
export const WADLOG_SK_PREFIX = 'WADLOG#';
export const WAAUDIT_SK_PREFIX = 'WAAUDIT#';
export const WAPROC_SK_PREFIX = 'WAPROC#';
export const WASCHED_SK_PREFIX = 'WASCHED#';
export const WALOW_SK_PREFIX = 'WALOW#';
export const WACOLL_SK_PREFIX = 'WACOLL#';
export const WAPROV_SK_PREFIX = 'WAPROV#';

// ── GSI1 entity-type namespace ──────────────────────────────────────────────
// Used as the `entity_type` item attribute (base-table disambiguation) and as
// the GSI1 entity-type segment (GSI1PK = TENANT#{t}#BIZ#{b}#{entityType}).
// The `WA_` prefix guarantees WhatsApp records never collide with other modules
// on GSI1.

export const WA_ENTITY_TYPE = {
  CONFIG: 'WA_CFG',
  TEMPLATE: 'WA_TMPL',
  TEMPLATE_VERSION: 'WA_TMPLV',
  RULE: 'WA_RULE',
  CUSTOMER: 'WA_CUST',
  OUTBOUND_MESSAGE: 'WA_OUT',
  DELIVERY_LOG: 'WA_DLOG',
  AUDIT_LOG: 'WA_AUDIT',
  PROCESSING_MARKER: 'WA_PROC',
  SCHEDULED_DISPATCH: 'WA_SCHED',
  LOW_STOCK_MARKER: 'WA_LOW',
  COLLECTION_WORKFLOW: 'WA_COLL',
  PROVISIONING: 'WA_PROV',
} as const;

export type WaEntityType =
  (typeof WA_ENTITY_TYPE)[keyof typeof WA_ENTITY_TYPE];

// ── SK Builders ─────────────────────────────────────────────────────────────

export function automationConfigSK(businessType: string, tier: string): string {
  return `${WACFG_SK_PREFIX}${businessType}#${tier}`;
}

export function messageTemplateSK(templateId: string): string {
  return `${WATMPL_SK_PREFIX}${templateId}`;
}

export function messageTemplateVersionSK(templateId: string, version: number): string {
  return `${WATMPLV_SK_PREFIX}${templateId}#${version}`;
}

export function automationRuleSK(ruleId: string): string {
  return `${WARULE_SK_PREFIX}${ruleId}`;
}

export function customerProfileSK(customerId: string): string {
  return `${WACUST_SK_PREFIX}${customerId}`;
}

export function outboundMessageSK(messageId: string): string {
  return `${WAOUT_SK_PREFIX}${messageId}`;
}

/** Append-only, immutable. Timestamp-first SK gives natural chronological order. */
export function deliveryLogSK(isoTimestamp: string, logId: string): string {
  return `${WADLOG_SK_PREFIX}${isoTimestamp}#${logId}`;
}

/** Append-only, immutable. Timestamp-first for chronological audit trails. */
export function auditLogSK(isoTimestamp: string, eventId: string): string {
  return `${WAAUDIT_SK_PREFIX}${isoTimestamp}#${eventId}`;
}

/** Idempotency processing marker keyed by (eventId, recipientId). */
export function processingMarkerSK(eventId: string, recipientId: string): string {
  return `${WAPROC_SK_PREFIX}${eventId}#${recipientId}`;
}

/** Scheduled dispatch index keyed by due time and message ID. */
export function scheduledDispatchSK(dueIsoTimestamp: string, messageId: string): string {
  return `${WASCHED_SK_PREFIX}${dueIsoTimestamp}#${messageId}`;
}

/** Low-stock hysteresis marker keyed by product ID. */
export function lowStockMarkerSK(productId: string): string {
  return `${WALOW_SK_PREFIX}${productId}`;
}

/** Payment-collection workflow cursor keyed by invoice/customer. */
export function collectionWorkflowSK(invoiceId: string, customerId: string): string {
  return `${WACOLL_SK_PREFIX}${invoiceId}#${customerId}`;
}

/**
 * OpenWA provisioning status record — one per business (singleton within
 * the business partition). Holds ONLY non-secret metadata (status,
 * sessionId, baseUrl, timestamps); the actual apiKey/webhookSecret live in
 * AWS Secrets Manager, never in DynamoDB.
 */
export function openWaProvisioningSK(): string {
  return `${WAPROV_SK_PREFIX}CONFIG`;
}

// ── Entity Key Builders ───────────────────────────────────────────────────
// Each returns { PK, SK, GSI1PK?, GSI1SK? } using the shared businessPK builder
// (which rejects '#' injection in tenantId and businessId).
// The `entityType` field is the value callers MUST persist in the item's
// `entity_type` attribute (base-table disambiguation).

export interface WaEntityKeys extends EntityKeys {
  /** Value to store in the item's `entity_type` attribute. */
  entityType: WaEntityType;
}

/**
 * AutomationConfig — SK: WACFG#{businessType}#{tier}
 *
 * Access patterns:
 *  - Resolve config for a business: GetItem(PK, WACFG#{businessType}#{tier})
 *  - List all configs in business:  Query(PK, begins_with(SK, 'WACFG#'))
 * Writes: upsert per (businessType, tier) with schema validation.
 */
export function buildAutomationConfigKeys(
  tenantId: string,
  businessId: string,
  businessType: string,
  tier: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: automationConfigSK(businessType, tier),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.CONFIG),
    GSI1SK: `${businessType}#${tier}`,
    entityType: WA_ENTITY_TYPE.CONFIG,
  };
}

/**
 * MessageTemplate (current pointer) — SK: WATMPL#{id}
 *
 * Access patterns:
 *  - Get one template:             GetItem(PK, WATMPL#{id})
 *  - List templates in business:   Query(PK, begins_with(SK, 'WATMPL#'))
 *  - List by date (recent-first):  Query GSI1(GSI1PK=…#WA_TMPL, GSI1SK={date}#{id})
 * Writes: create, update, deactivate (soft delete via status).
 */
export function buildMessageTemplateKeys(
  tenantId: string,
  businessId: string,
  templateId: string,
  isoDate: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: messageTemplateSK(templateId),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.TEMPLATE),
    GSI1SK: gsi1SK(isoDate, templateId),
    entityType: WA_ENTITY_TYPE.TEMPLATE,
  };
}

/**
 * MessageTemplateVersion (immutable history) — SK: WATMPLV#{templateId}#{version}
 *
 * Access patterns:
 *  - Get exact version:              GetItem(PK, WATMPLV#{templateId}#{version})
 *  - List version history:           Query(PK, begins_with(SK, 'WATMPLV#{templateId}#'))
 * Writes: create only (immutable — version history is never updated or deleted).
 */
export function buildMessageTemplateVersionKeys(
  tenantId: string,
  businessId: string,
  templateId: string,
  version: number,
  isoDate: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: messageTemplateVersionSK(templateId, version),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.TEMPLATE_VERSION),
    GSI1SK: gsi1SK(isoDate, `${templateId}#${version}`),
    entityType: WA_ENTITY_TYPE.TEMPLATE_VERSION,
  };
}

/**
 * AutomationRule — SK: WARULE#{id}
 *
 * Access patterns:
 *  - Get one rule:              GetItem(PK, WARULE#{id})
 *  - List rules in business:    Query(PK, begins_with(SK, 'WARULE#'))
 *  - List by creation date:     Query GSI1(GSI1PK=…#WA_RULE, GSI1SK={date}#{id})
 * Writes: create, update, enable/disable.
 */
export function buildAutomationRuleKeys(
  tenantId: string,
  businessId: string,
  ruleId: string,
  isoDate: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: automationRuleSK(ruleId),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.RULE),
    GSI1SK: gsi1SK(isoDate, ruleId),
    entityType: WA_ENTITY_TYPE.RULE,
  };
}

/**
 * CustomerProfile (WhatsApp profile + consent) — SK: WACUST#{customerId}
 *
 * Access patterns:
 *  - Get one customer:            GetItem(PK, WACUST#{customerId})
 *  - List customers in business:  Query(PK, begins_with(SK, 'WACUST#'))
 *  - List by date:                Query GSI1(GSI1PK=…#WA_CUST, GSI1SK={date}#{id})
 * Writes: create, update (consent, locale, preferences).
 */
export function buildCustomerProfileKeys(
  tenantId: string,
  businessId: string,
  customerId: string,
  isoDate: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: customerProfileSK(customerId),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.CUSTOMER),
    GSI1SK: gsi1SK(isoDate, customerId),
    entityType: WA_ENTITY_TYPE.CUSTOMER,
  };
}

/**
 * OutboundMessage — SK: WAOUT#{messageId}
 *
 * Access patterns:
 *  - Get one message:             GetItem(PK, WAOUT#{messageId})
 *  - List messages by enqueue:    Query GSI1(GSI1PK=…#WA_OUT, GSI1SK={ts}#{id})
 * Writes: create (durable enqueue), update (lifecycle state transitions).
 */
export function buildOutboundMessageKeys(
  tenantId: string,
  businessId: string,
  messageId: string,
  isoTimestamp: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: outboundMessageSK(messageId),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.OUTBOUND_MESSAGE),
    GSI1SK: gsi1SK(isoTimestamp, messageId),
    entityType: WA_ENTITY_TYPE.OUTBOUND_MESSAGE,
  };
}

/**
 * DeliveryLog (append-only) — SK: WADLOG#{isoTimestamp}#{logId}
 *
 * Access patterns:
 *  - List logs in time window:    Query(PK, begins_with(SK, 'WADLOG#{datePrefix}'))
 *  - By message (recent-first):   Query GSI1(GSI1PK=…#WA_DLOG, GSI1SK={ts}#{logId})
 * Writes: create only (immutable append-only log — never updated or deleted).
 */
export function buildDeliveryLogKeys(
  tenantId: string,
  businessId: string,
  isoTimestamp: string,
  logId: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: deliveryLogSK(isoTimestamp, logId),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.DELIVERY_LOG),
    GSI1SK: gsi1SK(isoTimestamp, logId),
    entityType: WA_ENTITY_TYPE.DELIVERY_LOG,
  };
}

/**
 * AuditLog (append-only) — SK: WAAUDIT#{isoTimestamp}#{eventId}
 *
 * Access patterns:
 *  - List audit in time window:   Query(PK, begins_with(SK, 'WAAUDIT#{datePrefix}'))
 *  - By actor/target (recent):    Query GSI1(GSI1PK=…#WA_AUDIT, GSI1SK={ts}#{id})
 * Writes: create only (immutable append-only trail — never updated or deleted).
 */
export function buildAuditLogKeys(
  tenantId: string,
  businessId: string,
  isoTimestamp: string,
  eventId: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: auditLogSK(isoTimestamp, eventId),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.AUDIT_LOG),
    GSI1SK: gsi1SK(isoTimestamp, eventId),
    entityType: WA_ENTITY_TYPE.AUDIT_LOG,
  };
}

/**
 * ProcessingMarker (idempotency) — SK: WAPROC#{eventId}#{recipientId}
 *
 * Access patterns:
 *  - Check idempotency:  GetItem(PK, WAPROC#{eventId}#{recipientId})
 *    with `attribute_not_exists(PK)` condition on PutItem to guarantee exactly-once.
 * Writes: conditional create only (PutItem with attribute_not_exists).
 */
export function buildProcessingMarkerKeys(
  tenantId: string,
  businessId: string,
  eventId: string,
  recipientId: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: processingMarkerSK(eventId, recipientId),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.PROCESSING_MARKER),
    GSI1SK: `${eventId}#${recipientId}`,
    entityType: WA_ENTITY_TYPE.PROCESSING_MARKER,
  };
}

/**
 * ScheduledDispatch — SK: WASCHED#{dueIsoTimestamp}#{messageId}
 *
 * Access patterns:
 *  - Sweep due items:    Query(PK, begins_with(SK, 'WASCHED#')) with SK <= now
 *  - List scheduled:     Query GSI1(GSI1PK=…#WA_SCHED, GSI1SK={dueTs}#{msgId})
 * Writes: create (on delay/schedule), delete (on dispatch or cancellation).
 */
export function buildScheduledDispatchKeys(
  tenantId: string,
  businessId: string,
  dueIsoTimestamp: string,
  messageId: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: scheduledDispatchSK(dueIsoTimestamp, messageId),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.SCHEDULED_DISPATCH),
    GSI1SK: gsi1SK(dueIsoTimestamp, messageId),
    entityType: WA_ENTITY_TYPE.SCHEDULED_DISPATCH,
  };
}

/**
 * LowStockMarker (hysteresis) — SK: WALOW#{productId}
 *
 * Access patterns:
 *  - Check hysteresis:  GetItem(PK, WALOW#{productId})
 *    Marker exists = below threshold (alert already sent); absent = above threshold.
 * Writes: create (on below-threshold), delete (on replenish above threshold).
 */
export function buildLowStockMarkerKeys(
  tenantId: string,
  businessId: string,
  productId: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: lowStockMarkerSK(productId),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.LOW_STOCK_MARKER),
    GSI1SK: productId,
    entityType: WA_ENTITY_TYPE.LOW_STOCK_MARKER,
  };
}

/**
 * CollectionWorkflowCursor — SK: WACOLL#{invoiceId}#{customerId}
 *
 * Access patterns:
 *  - Get workflow state:    GetItem(PK, WACOLL#{invoiceId}#{customerId})
 *  - List active workflows: Query(PK, begins_with(SK, 'WACOLL#'))
 * Writes: create (on first step), update (advance step), delete (on completion).
 */
export function buildCollectionWorkflowKeys(
  tenantId: string,
  businessId: string,
  invoiceId: string,
  customerId: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: collectionWorkflowSK(invoiceId, customerId),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.COLLECTION_WORKFLOW),
    GSI1SK: `${invoiceId}#${customerId}`,
    entityType: WA_ENTITY_TYPE.COLLECTION_WORKFLOW,
  };
}

/**
 * OpenWaProvisioning (status metadata only — secrets live in Secrets Manager)
 * — SK: WAPROV#CONFIG (singleton per business)
 *
 * Access patterns:
 *  - Get provisioning status:  GetItem(PK, WAPROV#CONFIG)
 * Writes: create (on first save), update (verify/activate, deactivate).
 */
export function buildOpenWaProvisioningKeys(
  tenantId: string,
  businessId: string,
): WaEntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: openWaProvisioningSK(),
    GSI1PK: gsi1PK(tenantId, businessId, WA_ENTITY_TYPE.PROVISIONING),
    GSI1SK: openWaProvisioningSK(),
    entityType: WA_ENTITY_TYPE.PROVISIONING,
  };
}
