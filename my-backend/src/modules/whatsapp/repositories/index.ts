// ============================================================================
// WhatsApp Module — Repository Barrel Exports (Task 3.1)
// ============================================================================

export { WaBaseRepository, type WaBaseItem, NOT_DELETED_FILTER } from './base.repository';
export { AutomationConfigRepository } from './automation-config.repository';
export {
  MessageTemplateRepository,
  type MessageTemplateCreateInput,
  type MessageTemplateUpdateInput,
} from './message-template.repository';
export {
  AutomationRuleRepository,
  type AutomationRuleCreateInput,
} from './automation-rule.repository';
export {
  CustomerProfileRepository,
  type CustomerProfileCreateInput,
} from './customer-profile.repository';
export {
  OutboundMessageRepository,
  type OutboundMessageCreateInput,
} from './outbound-message.repository';
export {
  DeliveryLogRepository,
  type DeliveryLogCreateInput,
} from './delivery-log.repository';
export {
  AuditLogRepository,
  type AuditLogCreateInput,
} from './audit-log.repository';
