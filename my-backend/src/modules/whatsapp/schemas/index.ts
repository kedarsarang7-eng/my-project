// ============================================================================
// WhatsApp Automation Module — Schema Exports
// ============================================================================

export {
  // Entity schemas (Zod validators)
  automationConfigSchema,
  messageTemplateSchema,
  messageTemplateVersionSchema,
  automationRuleSchema,
  customerProfileSchema,
  outboundMessageSchema,
  deliveryLogEntrySchema,
  auditLogEntrySchema,
  processingMarkerSchema,

  // Entity types (TypeScript interfaces)
  type AutomationConfig,
  type MessageTemplate,
  type MessageTemplateVersion,
  type AutomationRule,
  type CustomerProfile,
  type OutboundMessage,
  type DeliveryLogEntry,
  type AuditLogEntry,
  type ProcessingMarker,

  // Enum schemas
  consentStateSchema,
  outboundMessageStatusSchema,
  deliveryLogStateSchema,
  messageCategorySchema,
  subscriptionTierSchema,
  e164PhoneSchema,
  moneyPaiseSchema,
  isoTimestampSchema,
  idRefSchema,

  // Enum types
  type ConsentState,
  type SubscriptionTier,
  type OutboundMessageStatus,
  type DeliveryLogState,
  type MessageCategory,
  type RuleCondition,
  type RecipientSpec,
} from './entities';
