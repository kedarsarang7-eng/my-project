// ============================================================================
// WhatsApp Automation Module — Entity Interfaces & Zod Schemas (Task 2.4)
// ============================================================================
// Defines the core domain entities for the WhatsApp Automation System.
//
// DESIGN CONTRACTS:
// - Money is stored as integer paise (never floating-point)
// - Timestamps are ISO-8601 UTC strings
// - Template body: 1..4096 characters
// - Placeholders: 0..50 per template
// - Consent_State: exactly 'opted_in' | 'opted_out' | 'pending'
// - All entities are business-scoped via businessId (Req 12.1)
//
// Requirements: 1.1, 2.3, 2.4, 7.2, 8.3
// ============================================================================

import { z } from 'zod';

// ── Shared primitives ─────────────────────────────────────────────────────────

/** Non-empty trimmed string that rejects '#' to prevent DynamoDB key injection. */
const idRef = z
  .string()
  .trim()
  .min(1)
  .max(128)
  .refine((v) => !v.includes('#'), { message: "must not contain '#'" });

/** ISO-8601 UTC timestamp string. */
const isoTimestamp = z
  .string()
  .trim()
  .min(1)
  .refine(
    (v) => !isNaN(Date.parse(v)),
    { message: 'must be a valid ISO-8601 timestamp' },
  );

/** E.164 phone number: leading '+' followed by 8-15 digits (Req 2.1, 2.2). */
const e164Phone = z
  .string()
  .trim()
  .regex(/^\+\d{8,15}$/, { message: 'must be a valid E.164 phone number (+[8-15 digits])' });

/** Integer paise amount (non-negative). Never floating-point. */
const moneyPaise = z.number().int().min(0);

/** Subscription tier enum (matches plan-feature-registry PlanTier). */
const subscriptionTier = z.enum(['basic', 'pro', 'premium', 'enterprise']);

/** Consent state enum — exactly three legal values (Req 2.3, 2.4). */
const consentState = z.enum(['opted_in', 'opted_out', 'pending']);

/** Outbound message status lifecycle (Req 8.3, 8.6, 15.4). */
const outboundMessageStatus = z.enum([
  'queued',
  'sent',
  'delivered',
  'read',
  'failed',
  'expired',
]);

/** Delivery log state — extends outbound status with 'suppressed' for consent/condition blocks. */
const deliveryLogState = z.enum([
  'queued',
  'sent',
  'delivered',
  'read',
  'failed',
  'expired',
  'suppressed',
]);

/** Message category for consent classification (Req 2.5, 6.9, 13.5). */
const messageCategory = z.enum(['transactional', 'non_transactional']);

// ── AutomationConfig ──────────────────────────────────────────────────────────
// SK: WACFG#{businessType}#{tier}
// Maps BusinessType × SubscriptionTier to enabled automations and channels.
// Requirements: 1.1, 1.2, 1.5, 1.8, 1.9

const automationEntrySchema = z.object({
  enabled: z.boolean(),
  templateId: idRef.optional(),
  ruleIds: z.array(idRef).optional(),
});

const channelEntrySchema = z.object({
  enabled: z.boolean(),
});

export const automationConfigSchema = z.object({
  id: idRef,
  businessId: idRef,
  tenantId: idRef,
  businessType: z.string().trim().min(1).max(100),
  tier: subscriptionTier,
  automations: z.record(z.string(), automationEntrySchema),
  channels: z.record(z.string(), channelEntrySchema),
  schemaVersion: z.number().int().positive(),
  createdAt: isoTimestamp,
  updatedAt: isoTimestamp,
});

export type AutomationConfig = z.infer<typeof automationConfigSchema>;

// ── MessageTemplate ───────────────────────────────────────────────────────────
// SK: WATMPL#{id} (current pointer)
// Body: 1..4096 chars, placeholders: 0..50 (Req 7.2)
// Requirements: 7.1, 7.2, 7.6, 7.7

export const messageTemplateSchema = z.object({
  id: idRef,
  businessId: idRef,
  tenantId: idRef,
  name: z.string().trim().min(1).max(200),
  businessType: z.string().trim().min(1).max(100),
  locale: z.string().trim().min(2).max(10),
  body: z.string().min(1).max(4096),
  placeholders: z.array(z.string().trim().min(1).max(100)).min(0).max(50),
  currentVersion: z.number().int().positive(),
  status: z.enum(['active', 'inactive']),
  createdAt: isoTimestamp,
  updatedAt: isoTimestamp,
});

export type MessageTemplate = z.infer<typeof messageTemplateSchema>;

// ── MessageTemplateVersion ────────────────────────────────────────────────────
// SK: WATMPLV#{templateId}#{version} (immutable history, Req 7.7)
// Each version is an immutable snapshot for exact recoverability.

export const messageTemplateVersionSchema = z.object({
  id: idRef,
  templateId: idRef,
  businessId: idRef,
  tenantId: idRef,
  version: z.number().int().positive(),
  body: z.string().min(1).max(4096),
  placeholders: z.array(z.string().trim().min(1).max(100)).min(0).max(50),
  createdAt: isoTimestamp,
  createdBy: z.string().trim().min(1).max(200),
});

export type MessageTemplateVersion = z.infer<typeof messageTemplateVersionSchema>;

// ── AutomationRule ────────────────────────────────────────────────────────────
// SK: WARULE#{id}
// Admin-configurable rule binding a Business_Event to templates and recipients.
// Requirements: 3.1, 3.3, 3.8, 5.1, 5.2, 5.6, 7.5, 11.7

const ruleConditionSchema = z.object({
  field: z.string().trim().min(1).max(200),
  operator: z.enum(['eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'in', 'not_in', 'exists', 'not_exists']),
  value: z.unknown().optional(),
});

const recipientSpecSchema = z.object({
  type: z.enum(['customer', 'supplier', 'staff', 'segment']),
  id: idRef.optional(),
  segmentFilter: z.record(z.string(), z.unknown()).optional(),
});

const scheduleSchema = z.object({
  delaySeconds: z.number().int().min(1).max(31536000).optional(), // 1s..365d
  at: isoTimestamp.optional(),
});

export const automationRuleSchema = z.object({
  id: idRef,
  businessId: idRef,
  tenantId: idRef,
  branchId: idRef.optional(),
  eventType: z.string().trim().min(1).max(200),
  conditions: z.array(ruleConditionSchema).default([]),
  templateId: idRef,
  recipients: recipientSpecSchema,
  schedule: scheduleSchema.optional(),
  category: messageCategory,
  maxReminders: z.number().int().min(1).max(100).optional(),
  enabled: z.boolean(),
  createdAt: isoTimestamp,
  updatedAt: isoTimestamp,
});

export type AutomationRule = z.infer<typeof automationRuleSchema>;

// ── CustomerProfile ───────────────────────────────────────────────────────────
// SK: WACUST#{customerId}
// One-time setup with valid WhatsApp number and consent state.
// Requirements: 2.1, 2.3, 2.4, 2.8, 2.9

const messagingPreferencesSchema = z.object({
  quietHoursStart: z.string().trim().max(10).optional(), // e.g. "22:00"
  quietHoursEnd: z.string().trim().max(10).optional(),   // e.g. "08:00"
  preferredTime: z.string().trim().max(10).optional(),
}).optional();

export const customerProfileSchema = z.object({
  id: idRef,
  businessId: idRef,
  tenantId: idRef,
  whatsappNumber: e164Phone,
  consentState: consentState.default('pending'),
  locale: z.string().trim().min(2).max(10).default('en'),
  messagingPreferences: messagingPreferencesSchema,
  eligible: z.boolean(), // derived: valid E.164 && opted_in (Req 2.9)
  isDeleted: z.boolean().default(false),
  createdAt: isoTimestamp,
  updatedAt: isoTimestamp,
});

export type CustomerProfile = z.infer<typeof customerProfileSchema>;

// ── OutboundMessage ───────────────────────────────────────────────────────────
// SK: WAOUT#{id}
// Durable queue source of truth (AD-3). Status transitions are lifecycle-driven.
// Requirements: 8.1, 8.3, 8.6, 9.1, 9.2, 14.4

export const outboundMessageSchema = z.object({
  id: idRef,
  businessId: idRef,
  tenantId: idRef,
  branchId: idRef.optional(),
  eventId: idRef,
  recipientId: idRef,
  recipientNumber: e164Phone,
  templateId: idRef,
  templateVersion: z.number().int().positive(),
  renderedBody: z.string().min(1).max(4096),
  mediaUrl: z.string().url().max(2048).optional(),
  status: outboundMessageStatus,
  attempts: z.number().int().min(0).default(0),
  lastError: z.string().max(1000).optional(),
  nextAttemptAt: isoTimestamp.optional(),
  expiresAt: isoTimestamp.optional(),
  providerMessageId: z.string().max(256).optional(),
  createdAt: isoTimestamp,
  updatedAt: isoTimestamp,
});

export type OutboundMessage = z.infer<typeof outboundMessageSchema>;

// ── DeliveryLogEntry ──────────────────────────────────────────────────────────
// SK: WADLOG#{isoTimestamp}#{id}
// Append-only lifecycle state record (Req 8.3, 8.7).
// Each entry captures a single state transition for an outbound message.

export const deliveryLogEntrySchema = z.object({
  id: idRef,
  businessId: idRef,
  tenantId: idRef,
  outboundMessageId: idRef,
  state: deliveryLogState,
  reason: z.string().max(1000).optional(),
  timestamp: isoTimestamp,
});

export type DeliveryLogEntry = z.infer<typeof deliveryLogEntrySchema>;

// ── AuditLogEntry ─────────────────────────────────────────────────────────────
// SK: WAAUDIT#{isoTimestamp}#{id}
// Append-only record for security/config/consent changes (Req 2.7, 7.6, 8.5).

export const auditLogEntrySchema = z.object({
  id: idRef,
  businessId: idRef,
  tenantId: idRef,
  actor: z.string().trim().min(1).max(200),
  action: z.string().trim().min(1).max(100),
  target: z.string().trim().min(1).max(300),
  before: z.unknown().optional(),
  after: z.unknown().optional(),
  timestamp: isoTimestamp,
});

export type AuditLogEntry = z.infer<typeof auditLogEntrySchema>;

// ── ProcessingMarker ──────────────────────────────────────────────────────────
// SK: WAPROC#{eventId}#{recipientId}
// Idempotency guard — conditional PutItem with attribute_not_exists (Req 3.4, 9.3).

export const processingMarkerSchema = z.object({
  eventId: idRef,
  recipientId: idRef,
  businessId: idRef,
  tenantId: idRef,
  createdAt: isoTimestamp,
});

export type ProcessingMarker = z.infer<typeof processingMarkerSchema>;

// ── OpenWaProvisioningConfig ──────────────────────────────────────────────────
// SK: WAPROV#CONFIG (singleton per business)
// Non-secret provisioning STATUS metadata only. The actual apiKey and
// webhookSecret are NEVER stored here — they live exclusively in AWS Secrets
// Manager (see openwa-provisioning.service.ts). This record exists so the
// UI can show connection status without ever reading the secret store.

const provisioningStatus = z.enum([
  'pending_verification',
  'active',
  'failed',
  'inactive',
]);

export const openWaProvisioningConfigSchema = z.object({
  id: idRef,
  businessId: idRef,
  tenantId: idRef,
  /** OpenWA session id this business is provisioned against. */
  sessionId: idRef,
  /** Base URL of the OpenWA gateway instance (e.g. https://openwa.example.com). Non-secret. */
  baseUrl: z.string().trim().url().max(500),
  status: provisioningStatus,
  displayName: z.string().trim().max(100).optional(),
  /** Populated once the OpenWA webhook subscription has been registered. */
  webhookId: z.string().trim().max(128).optional(),
  lastError: z.string().max(1000).optional(),
  verifiedAt: isoTimestamp.optional(),
  createdAt: isoTimestamp,
  updatedAt: isoTimestamp,
});

export type OpenWaProvisioningConfig = z.infer<typeof openWaProvisioningConfigSchema>;
export type OpenWaProvisioningStatus = z.infer<typeof provisioningStatus>;

// ── Exported enums and primitives for reuse ───────────────────────────────────

export {
  consentState as consentStateSchema,
  outboundMessageStatus as outboundMessageStatusSchema,
  deliveryLogState as deliveryLogStateSchema,
  messageCategory as messageCategorySchema,
  subscriptionTier as subscriptionTierSchema,
  e164Phone as e164PhoneSchema,
  moneyPaise as moneyPaiseSchema,
  isoTimestamp as isoTimestampSchema,
  idRef as idRefSchema,
  provisioningStatus as provisioningStatusSchema,
};

// ── Consent_State type literal ────────────────────────────────────────────────
export type ConsentState = z.infer<typeof consentState>;
export type SubscriptionTier = z.infer<typeof subscriptionTier>;
export type OutboundMessageStatus = z.infer<typeof outboundMessageStatus>;
export type DeliveryLogState = z.infer<typeof deliveryLogState>;
export type MessageCategory = z.infer<typeof messageCategory>;
export type RuleCondition = z.infer<typeof ruleConditionSchema>;
export type RecipientSpec = z.infer<typeof recipientSpecSchema>;
