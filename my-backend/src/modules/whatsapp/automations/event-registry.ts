// ============================================================================
// WhatsApp Automation Module — Event Registry (Task 14.1)
// ============================================================================
// The COMPLETE wiring layer that maps all DukanX Business_Events to automation
// types processed by the rule-engine + whatsappEngine pipeline.
//
// Each entry in the registry defines:
// - The event type key (matches Automation_Rule.eventType and EventBridge detailType)
// - The EventBridge source and detailType for pattern matching
// - The automation category (transactional vs non_transactional) for consent gating
// - Whether it is a Document_Automation (requires recipient-verification)
// - The recipient resolution strategy (customer, supplier, staff, segment)
// - The required FeatureKey for plan/tier gating
// - Whether it carries branchId for multi-branch scoping
//
// DESIGN CONTRACTS:
// - Every event type registered here is routed through `rule-engine.service.ts`
//   evaluateRules() for condition evaluation + consent gating.
// - Document_Automations (isDocumentAutomation: true) MUST pass through
//   `recipient-verification.service.ts` before enqueue (Req 16.1–16.6).
// - Multi-branch events carry branchId so the rule engine applies branch scoping
//   (Req 11.7).
// - No per-business-type code forks — all automation differences are expressed
//   through Automation_Config values (AD-2).
//
// Requirements: 6.1–6.9, 11.1–11.3, 11.5–11.9
// ============================================================================

import { FeatureKey } from '../../../config/plan-feature-registry';
import type { MessageCategory } from '../schemas/entities';

// ── Types ─────────────────────────────────────────────────────────────────────

/** Recipient resolution strategy for an automation type. */
export type RecipientStrategy =
  | 'customer'    // Resolve by customerId from event payload
  | 'supplier'    // Resolve by supplierId from event payload
  | 'staff'       // Resolve by staffId or configured staff recipients
  | 'segment';    // Resolve by segment filter (campaigns, bulk)

/** EventBridge source domains used by DukanX. */
export type EventSource =
  | 'dukanx.billing'
  | 'dukanx.inventory'
  | 'dukanx.whatsapp'
  | 'dukanx.crm'
  | 'dukanx.operations'
  | 'dukanx.hr';

/**
 * A single entry in the event registry. Defines how one Business_Event type
 * is wired through the automation pipeline.
 */
export interface EventRegistryEntry {
  /** The event type key — matches AutomationRule.eventType and EB detailType. */
  readonly eventType: string;
  /** EventBridge source for pattern matching. */
  readonly source: EventSource;
  /** Human-readable display name for admin UI. */
  readonly displayName: string;
  /** Automation category for consent classification (Req 2.5, 6.9, 13.5). */
  readonly defaultCategory: MessageCategory;
  /**
   * Whether this is a Document_Automation requiring recipient-verification
   * before enqueue (Req 16.1–16.6). When true, the engine MUST call
   * verifyRecipient() and fail closed with an Operator_Alert on mismatch.
   */
  readonly isDocumentAutomation: boolean;
  /** Primary recipient resolution strategy. */
  readonly recipientStrategy: RecipientStrategy;
  /** Required FeatureKey for plan-tier gating. */
  readonly requiredFeatureKey: FeatureKey;
  /** Whether this event type supports/carries branchId (Req 11.7). */
  readonly supportsBranchScope: boolean;
  /** Brief description for documentation / admin rule builder. */
  readonly description: string;
  /**
   * The payload field that carries the unique customer identifier for
   * recipient resolution. Used by recipient-verification for Document_Automations.
   */
  readonly customerIdField: string;
  /**
   * Optional payload field carrying the customer phone number for
   * cross-check during recipient verification (Req 16.3).
   */
  readonly customerNumberField?: string;
}

// ── Automation Type Keys (canonical constants) ────────────────────────────────

/**
 * Canonical automation type keys used as AutomationRule.eventType values.
 * These match the EventBridge detailType values exactly.
 */
export const AutomationType = {
  // ── Transactional Document Automations (Req 6.1–6.5) ───────────────
  ORDER_CONFIRMED: 'order.confirmed',
  QUOTATION_ISSUED: 'quotation.issued',
  ESTIMATE_ISSUED: 'estimate.issued',
  PURCHASE_ORDER_ISSUED: 'purchase_order.issued',
  DELIVERY_CHALLAN_ISSUED: 'delivery_challan.issued',
  RECEIPT_GENERATED: 'receipt.generated',
  CREDIT_NOTE_GENERATED: 'credit_note.generated',
  DEBIT_NOTE_GENERATED: 'debit_note.generated',
  INVOICE_GENERATED: 'invoice.generated',
  PAYMENT_RECEIVED: 'payment.received',
  PAYMENT_REFUNDED: 'payment.refunded',

  // ── Relationship & Engagement Automations (Req 6.6) ────────────────
  WARRANTY_INFO: 'warranty.info_due',
  LOYALTY_UPDATE: 'loyalty.points_updated',
  PROMOTIONAL_OFFER: 'promotional.offer_due',
  FESTIVAL_GREETING: 'festival.greeting_due',
  BIRTHDAY_WISH: 'birthday.wish_due',
  SERVICE_REMINDER: 'service.reminder_due',

  // ── Campaigns & Follow-up (Req 11.1, 11.2) ────────────────────────
  CAMPAIGN_DUE: 'campaign.due',
  ABANDONED_QUOTATION_REMINDER: 'quotation.abandoned_reminder_due',

  // ── Inventory & Stock (Req 11.3) ───────────────────────────────────
  STOCK_BELOW_THRESHOLD: 'stock.below_threshold',
  STOCK_REPLENISHED: 'stock.replenished',

  // ── Supplier & Staff & Approval Notifications (Req 11.5, 11.6) ────
  SUPPLIER_NOTIFICATION: 'supplier.notification_due',
  STAFF_NOTIFICATION: 'staff.notification_due',
  APPROVAL_WORKFLOW: 'approval.workflow_triggered',

  // ── Daily Summaries & Analytics (Req 11.6) ─────────────────────────
  DAILY_SUMMARY_DUE: 'analytics.daily_summary_due',
  ANALYTICS_REPORT_DUE: 'analytics.report_due',

  // ── Feedback & Appointments (Req 11.8) ─────────────────────────────
  FEEDBACK_REQUEST: 'feedback.request_due',
  APPOINTMENT_REMINDER: 'appointment.reminder_due',

  // ── Payment Collection Workflows (Req 11.9) ────────────────────────
  PAYMENT_STATUS_CHANGED: 'payment.status_changed',

  // ── Reminders (scheduled, Req 5.1–5.8) ─────────────────────────────
  REMINDER_DUE: 'reminder.due',

  // ── Inbound (for opt-out / AI responder routing) ───────────────────
  INBOUND_MESSAGE_RECEIVED: 'inbound.message.received',
} as const;

export type AutomationTypeKey = typeof AutomationType[keyof typeof AutomationType];


// ── Complete Event Registry ───────────────────────────────────────────────────

/**
 * The COMPLETE event registry mapping all DukanX Business_Events to automation
 * types. This is the single source of truth for which events the whatsappEngine
 * Lambda processes and how it routes them through the rule engine.
 *
 * Adding a new automation type is purely additive: add an entry here plus the
 * matching Automation_Config values and templates — no code forks (AD-2).
 */
export const EVENT_REGISTRY: readonly EventRegistryEntry[] = [
  // ══════════════════════════════════════════════════════════════════════════
  // TRANSACTIONAL DOCUMENT AUTOMATIONS (Req 6.1–6.5)
  // All require recipient-verification (Req 16.1–16.6)
  // ══════════════════════════════════════════════════════════════════════════

  {
    eventType: AutomationType.ORDER_CONFIRMED,
    source: 'dukanx.billing',
    displayName: 'Order Confirmation',
    defaultCategory: 'transactional',
    isDocumentAutomation: true,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Sends order confirmation when an order is confirmed (Req 6.1)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  {
    eventType: AutomationType.QUOTATION_ISSUED,
    source: 'dukanx.billing',
    displayName: 'Quotation / Estimate Notification',
    defaultCategory: 'transactional',
    isDocumentAutomation: true,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Sends quotation details when a quotation is issued (Req 6.2)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  {
    eventType: AutomationType.ESTIMATE_ISSUED,
    source: 'dukanx.billing',
    displayName: 'Estimate Notification',
    defaultCategory: 'transactional',
    isDocumentAutomation: true,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Sends estimate details when an estimate is issued (Req 6.2)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  {
    eventType: AutomationType.PURCHASE_ORDER_ISSUED,
    source: 'dukanx.billing',
    displayName: 'Purchase Order Notification',
    defaultCategory: 'transactional',
    isDocumentAutomation: false, // Targets supplier, not customer document
    recipientStrategy: 'supplier',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Notifies supplier when a purchase order is issued (Req 6.3, 11.5)',
    customerIdField: 'supplierId',
    customerNumberField: 'supplierNumber',
  },

  {
    eventType: AutomationType.DELIVERY_CHALLAN_ISSUED,
    source: 'dukanx.billing',
    displayName: 'Delivery Challan Notification',
    defaultCategory: 'transactional',
    isDocumentAutomation: true,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Sends delivery challan when issued (Req 6.3)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  {
    eventType: AutomationType.RECEIPT_GENERATED,
    source: 'dukanx.billing',
    displayName: 'Receipt Notification',
    defaultCategory: 'transactional',
    isDocumentAutomation: true,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Sends receipt details when a receipt is generated (Req 6.4)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  {
    eventType: AutomationType.CREDIT_NOTE_GENERATED,
    source: 'dukanx.billing',
    displayName: 'Credit Note Notification',
    defaultCategory: 'transactional',
    isDocumentAutomation: true,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Sends credit note details when generated (Req 6.4)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  {
    eventType: AutomationType.DEBIT_NOTE_GENERATED,
    source: 'dukanx.billing',
    displayName: 'Debit Note Notification',
    defaultCategory: 'transactional',
    isDocumentAutomation: true,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Sends debit note details when generated (Req 6.4)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  {
    eventType: AutomationType.INVOICE_GENERATED,
    source: 'dukanx.billing',
    displayName: 'Invoice Delivery',
    defaultCategory: 'transactional',
    isDocumentAutomation: true,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_INVOICING,
    supportsBranchScope: true,
    description: 'Sends invoice + payment info + thank-you on generation (Req 4.1)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  {
    eventType: AutomationType.PAYMENT_RECEIVED,
    source: 'dukanx.billing',
    displayName: 'Payment Confirmation',
    defaultCategory: 'transactional',
    isDocumentAutomation: true,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_INVOICING,
    supportsBranchScope: true,
    description: 'Confirms payment receipt to the customer (Req 6.5)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  {
    eventType: AutomationType.PAYMENT_REFUNDED,
    source: 'dukanx.billing',
    displayName: 'Refund Confirmation',
    defaultCategory: 'transactional',
    isDocumentAutomation: true,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_INVOICING,
    supportsBranchScope: true,
    description: 'Confirms refund processed to the customer (Req 6.5)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  // ══════════════════════════════════════════════════════════════════════════
  // RELATIONSHIP & ENGAGEMENT AUTOMATIONS (Req 6.6)
  // Non-transactional — consent-gated (opted_out/pending → suppressed)
  // ══════════════════════════════════════════════════════════════════════════

  {
    eventType: AutomationType.WARRANTY_INFO,
    source: 'dukanx.crm',
    displayName: 'Warranty Information',
    defaultCategory: 'non_transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Sends warranty info when due (Req 6.6)',
    customerIdField: 'customerId',
  },

  {
    eventType: AutomationType.LOYALTY_UPDATE,
    source: 'dukanx.crm',
    displayName: 'Loyalty Points Update',
    defaultCategory: 'non_transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: false,
    description: 'Notifies customer of loyalty points update (Req 6.6)',
    customerIdField: 'customerId',
  },

  {
    eventType: AutomationType.PROMOTIONAL_OFFER,
    source: 'dukanx.crm',
    displayName: 'Promotional Offer',
    defaultCategory: 'non_transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'segment',
    requiredFeatureKey: FeatureKey.WA_CAMPAIGNS,
    supportsBranchScope: true,
    description: 'Sends promotional offers to eligible customer segment (Req 6.6)',
    customerIdField: 'customerId',
  },

  {
    eventType: AutomationType.FESTIVAL_GREETING,
    source: 'dukanx.crm',
    displayName: 'Festival Greeting',
    defaultCategory: 'non_transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'segment',
    requiredFeatureKey: FeatureKey.WA_CAMPAIGNS,
    supportsBranchScope: false,
    description: 'Sends festival greetings to eligible customers (Req 6.6)',
    customerIdField: 'customerId',
  },

  {
    eventType: AutomationType.BIRTHDAY_WISH,
    source: 'dukanx.crm',
    displayName: 'Birthday Wish',
    defaultCategory: 'non_transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_CAMPAIGNS,
    supportsBranchScope: false,
    description: 'Sends birthday wishes on the customer birthday (Req 6.6)',
    customerIdField: 'customerId',
  },

  {
    eventType: AutomationType.SERVICE_REMINDER,
    source: 'dukanx.crm',
    displayName: 'Service Reminder',
    defaultCategory: 'non_transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Sends service/maintenance reminders (Req 6.6)',
    customerIdField: 'customerId',
  },

  // ══════════════════════════════════════════════════════════════════════════
  // CAMPAIGNS & FOLLOW-UP (Req 11.1, 11.2)
  // ══════════════════════════════════════════════════════════════════════════

  {
    eventType: AutomationType.CAMPAIGN_DUE,
    source: 'dukanx.whatsapp',
    displayName: 'Marketing Campaign',
    defaultCategory: 'non_transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'segment',
    requiredFeatureKey: FeatureKey.WA_CAMPAIGNS,
    supportsBranchScope: true,
    description: 'Enqueues campaign messages per eligible recipient in segment (Req 11.1)',
    customerIdField: 'customerId',
  },

  {
    eventType: AutomationType.ABANDONED_QUOTATION_REMINDER,
    source: 'dukanx.whatsapp',
    displayName: 'Abandoned Quotation Reminder',
    defaultCategory: 'non_transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Reminds customer of unaccepted quotation after threshold period (Req 11.2)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  // ══════════════════════════════════════════════════════════════════════════
  // INVENTORY & STOCK ALERTS (Req 11.3)
  // ══════════════════════════════════════════════════════════════════════════

  {
    eventType: AutomationType.STOCK_BELOW_THRESHOLD,
    source: 'dukanx.inventory',
    displayName: 'Low-Stock Alert',
    defaultCategory: 'transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'staff',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Alerts staff/owner when product drops below threshold with hysteresis (Req 11.3)',
    customerIdField: 'staffId',
  },

  {
    eventType: AutomationType.STOCK_REPLENISHED,
    source: 'dukanx.inventory',
    displayName: 'Stock Replenished Notice',
    defaultCategory: 'transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'staff',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Clears low-stock hysteresis marker on replenishment (Req 11.3)',
    customerIdField: 'staffId',
  },

  // ══════════════════════════════════════════════════════════════════════════
  // SUPPLIER, STAFF & APPROVAL NOTIFICATIONS (Req 11.5, 11.6)
  // ══════════════════════════════════════════════════════════════════════════

  {
    eventType: AutomationType.SUPPLIER_NOTIFICATION,
    source: 'dukanx.operations',
    displayName: 'Supplier Notification',
    defaultCategory: 'transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'supplier',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Notifies supplier on configured business events (Req 11.5)',
    customerIdField: 'supplierId',
    customerNumberField: 'supplierNumber',
  },

  {
    eventType: AutomationType.STAFF_NOTIFICATION,
    source: 'dukanx.operations',
    displayName: 'Staff Notification',
    defaultCategory: 'transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'staff',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Notifies staff on configured business events (Req 11.5)',
    customerIdField: 'staffId',
  },

  {
    eventType: AutomationType.APPROVAL_WORKFLOW,
    source: 'dukanx.operations',
    displayName: 'Approval Workflow Notification',
    defaultCategory: 'transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'staff',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Notifies approvers when approval workflow is triggered (Req 11.5)',
    customerIdField: 'staffId',
  },

  // ══════════════════════════════════════════════════════════════════════════
  // DAILY SUMMARIES & ANALYTICS (Req 11.6)
  // ══════════════════════════════════════════════════════════════════════════

  {
    eventType: AutomationType.DAILY_SUMMARY_DUE,
    source: 'dukanx.operations',
    displayName: 'Daily Sales Summary',
    defaultCategory: 'transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'staff',
    requiredFeatureKey: FeatureKey.WA_ANALYTICS,
    supportsBranchScope: true,
    description: 'Delivers daily sales summary to configured recipients (Req 11.6)',
    customerIdField: 'staffId',
  },

  {
    eventType: AutomationType.ANALYTICS_REPORT_DUE,
    source: 'dukanx.operations',
    displayName: 'Analytics Report Delivery',
    defaultCategory: 'transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'staff',
    requiredFeatureKey: FeatureKey.WA_ANALYTICS,
    supportsBranchScope: true,
    description: 'Delivers WhatsApp analytics report to configured recipients (Req 11.6)',
    customerIdField: 'staffId',
  },

  // ══════════════════════════════════════════════════════════════════════════
  // FEEDBACK & APPOINTMENT REMINDERS (Req 11.8)
  // ══════════════════════════════════════════════════════════════════════════

  {
    eventType: AutomationType.FEEDBACK_REQUEST,
    source: 'dukanx.crm',
    displayName: 'Customer Feedback Request',
    defaultCategory: 'non_transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Requests feedback from customer after transaction (Req 11.8)',
    customerIdField: 'customerId',
  },

  {
    eventType: AutomationType.APPOINTMENT_REMINDER,
    source: 'dukanx.crm',
    displayName: 'Appointment Reminder',
    defaultCategory: 'transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_AUTOMATION,
    supportsBranchScope: true,
    description: 'Reminds customer of upcoming appointment (Req 11.8)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  // ══════════════════════════════════════════════════════════════════════════
  // PAYMENT COLLECTION WORKFLOWS (Req 11.9)
  // ══════════════════════════════════════════════════════════════════════════

  {
    eventType: AutomationType.PAYMENT_STATUS_CHANGED,
    source: 'dukanx.billing',
    displayName: 'Payment Collection Workflow Step',
    defaultCategory: 'transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_REMINDERS,
    supportsBranchScope: true,
    description: 'Advances collection workflow one step per status change (Req 11.9)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  // ══════════════════════════════════════════════════════════════════════════
  // PAYMENT REMINDERS (Req 5.1–5.8, scheduled)
  // ══════════════════════════════════════════════════════════════════════════

  {
    eventType: AutomationType.REMINDER_DUE,
    source: 'dukanx.whatsapp',
    displayName: 'Payment / Outstanding Balance Reminder',
    defaultCategory: 'transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_REMINDERS,
    supportsBranchScope: true,
    description: 'Scheduled payment reminder with outstanding amount + due date (Req 5.1–5.8)',
    customerIdField: 'customerId',
    customerNumberField: 'customerNumber',
  },

  // ══════════════════════════════════════════════════════════════════════════
  // INBOUND (opt-out routing + AI responder)
  // ══════════════════════════════════════════════════════════════════════════

  {
    eventType: AutomationType.INBOUND_MESSAGE_RECEIVED,
    source: 'dukanx.whatsapp',
    displayName: 'Inbound Message Processing',
    defaultCategory: 'transactional',
    isDocumentAutomation: false,
    recipientStrategy: 'customer',
    requiredFeatureKey: FeatureKey.WA_CORE,
    supportsBranchScope: false,
    description: 'Routes inbound messages for opt-out keywords + AI responder (Req 2.6, 11.10)',
    customerIdField: 'senderId',
  },
];


// ── Lookup Utilities ──────────────────────────────────────────────────────────

/** Index for O(1) lookup by event type. */
const registryByEventType = new Map<string, EventRegistryEntry>(
  EVENT_REGISTRY.map((entry) => [entry.eventType, entry]),
);

/**
 * Looks up an event registry entry by its event type key.
 * Returns undefined if the event type is not registered.
 */
export function getRegistryEntry(eventType: string): EventRegistryEntry | undefined {
  return registryByEventType.get(eventType);
}

/**
 * Returns all event types that are Document_Automations (requiring
 * recipient-verification before enqueue).
 */
export function getDocumentAutomationTypes(): string[] {
  return EVENT_REGISTRY
    .filter((entry) => entry.isDocumentAutomation)
    .map((entry) => entry.eventType);
}

/**
 * Returns all registered event types grouped by their EventBridge source.
 * Useful for building/validating the manifest eventPatterns.
 */
export function getEventTypesBySource(): Map<EventSource, string[]> {
  const bySource = new Map<EventSource, string[]>();
  for (const entry of EVENT_REGISTRY) {
    const existing = bySource.get(entry.source) ?? [];
    existing.push(entry.eventType);
    bySource.set(entry.source, existing);
  }
  return bySource;
}

/**
 * Checks if a given event type is a Document_Automation requiring
 * recipient verification (Req 16.1–16.6).
 */
export function isDocumentAutomationType(eventType: string): boolean {
  const entry = registryByEventType.get(eventType);
  return entry?.isDocumentAutomation ?? false;
}


/**
 * Checks if a given event type supports multi-branch scoping (Req 11.7).
 * When true, events carrying branchId are scoped to only that branch's recipients.
 */
export function supportsBranchScoping(eventType: string): boolean {
  const entry = registryByEventType.get(eventType);
  return entry?.supportsBranchScope ?? false;
}

/**
 * Returns the required FeatureKey for an event type.
 * Used by the engine to verify the automation is plan-gated correctly.
 */
export function getRequiredFeatureKey(eventType: string): FeatureKey | undefined {
  const entry = registryByEventType.get(eventType);
  return entry?.requiredFeatureKey;
}

/**
 * Returns the customer identifier field name from the event payload
 * for a given event type. Used by recipient-verification to extract
 * the unique customer ID from the Business_Event.
 */
export function getCustomerIdField(eventType: string): string | undefined {
  const entry = registryByEventType.get(eventType);
  return entry?.customerIdField;
}

/**
 * Returns the customer number field name (if defined) from the event payload.
 * Used for cross-checking during recipient verification (Req 16.3).
 */
export function getCustomerNumberField(eventType: string): string | undefined {
  const entry = registryByEventType.get(eventType);
  return entry?.customerNumberField;
}


// ── Default Automation Rule Templates ─────────────────────────────────────────

/**
 * Default automation rule templates for each event type. These are used to
 * seed a new business's Automation_Rules when onboarding. Each template
 * provides sensible defaults that can be customized per business.
 *
 * Note: templateId is left as a placeholder — actual template IDs are
 * resolved during business setup from the business's Message_Templates.
 */
export interface DefaultRuleTemplate {
  readonly eventType: string;
  readonly displayName: string;
  readonly category: MessageCategory;
  readonly recipientType: RecipientStrategy;
  readonly conditions: Array<{
    field: string;
    operator: string;
    value?: unknown;
  }>;
  readonly schedule?: { delaySeconds?: number };
  readonly supportsBranchScope: boolean;
}

export const DEFAULT_RULE_TEMPLATES: readonly DefaultRuleTemplate[] = [
  // Transactional documents — immediate, no conditions beyond eligibility
  {
    eventType: AutomationType.ORDER_CONFIRMED,
    displayName: 'Order Confirmation',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.QUOTATION_ISSUED,
    displayName: 'Quotation Notification',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.ESTIMATE_ISSUED,
    displayName: 'Estimate Notification',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.PURCHASE_ORDER_ISSUED,
    displayName: 'Purchase Order to Supplier',
    category: 'transactional',
    recipientType: 'supplier',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.DELIVERY_CHALLAN_ISSUED,
    displayName: 'Delivery Challan Notification',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.RECEIPT_GENERATED,
    displayName: 'Receipt Notification',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.CREDIT_NOTE_GENERATED,
    displayName: 'Credit Note Notification',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.DEBIT_NOTE_GENERATED,
    displayName: 'Debit Note Notification',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.INVOICE_GENERATED,
    displayName: 'Invoice Delivery',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.PAYMENT_RECEIVED,
    displayName: 'Payment Confirmation',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.PAYMENT_REFUNDED,
    displayName: 'Refund Confirmation',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },

  // Relationship & engagement — non-transactional, consent-gated
  {
    eventType: AutomationType.WARRANTY_INFO,
    displayName: 'Warranty Information',
    category: 'non_transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.LOYALTY_UPDATE,
    displayName: 'Loyalty Points Update',
    category: 'non_transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: false,
  },
  {
    eventType: AutomationType.PROMOTIONAL_OFFER,
    displayName: 'Promotional Offer',
    category: 'non_transactional',
    recipientType: 'segment',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.FESTIVAL_GREETING,
    displayName: 'Festival Greeting',
    category: 'non_transactional',
    recipientType: 'segment',
    conditions: [],
    supportsBranchScope: false,
  },
  {
    eventType: AutomationType.BIRTHDAY_WISH,
    displayName: 'Birthday Wish',
    category: 'non_transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: false,
  },
  {
    eventType: AutomationType.SERVICE_REMINDER,
    displayName: 'Service Reminder',
    category: 'non_transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },

  // Campaigns & follow-up
  {
    eventType: AutomationType.CAMPAIGN_DUE,
    displayName: 'Marketing Campaign',
    category: 'non_transactional',
    recipientType: 'segment',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.ABANDONED_QUOTATION_REMINDER,
    displayName: 'Abandoned Quotation Reminder',
    category: 'non_transactional',
    recipientType: 'customer',
    conditions: [
      { field: 'daysUnaccepted', operator: 'gte', value: 1 },
    ],
    schedule: { delaySeconds: 86400 }, // 1 day default
    supportsBranchScope: true,
  },

  // Inventory & stock alerts
  {
    eventType: AutomationType.STOCK_BELOW_THRESHOLD,
    displayName: 'Low-Stock Alert',
    category: 'transactional',
    recipientType: 'staff',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.STOCK_REPLENISHED,
    displayName: 'Stock Replenished Notice',
    category: 'transactional',
    recipientType: 'staff',
    conditions: [],
    supportsBranchScope: true,
  },

  // Supplier, staff & approval notifications
  {
    eventType: AutomationType.SUPPLIER_NOTIFICATION,
    displayName: 'Supplier Notification',
    category: 'transactional',
    recipientType: 'supplier',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.STAFF_NOTIFICATION,
    displayName: 'Staff Notification',
    category: 'transactional',
    recipientType: 'staff',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.APPROVAL_WORKFLOW,
    displayName: 'Approval Workflow Notification',
    category: 'transactional',
    recipientType: 'staff',
    conditions: [],
    supportsBranchScope: true,
  },

  // Daily summaries & analytics
  {
    eventType: AutomationType.DAILY_SUMMARY_DUE,
    displayName: 'Daily Sales Summary',
    category: 'transactional',
    recipientType: 'staff',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.ANALYTICS_REPORT_DUE,
    displayName: 'Analytics Report Delivery',
    category: 'transactional',
    recipientType: 'staff',
    conditions: [],
    supportsBranchScope: true,
  },

  // Feedback & appointment reminders
  {
    eventType: AutomationType.FEEDBACK_REQUEST,
    displayName: 'Customer Feedback Request',
    category: 'non_transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },
  {
    eventType: AutomationType.APPOINTMENT_REMINDER,
    displayName: 'Appointment Reminder',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [],
    schedule: { delaySeconds: 3600 }, // 1 hour before (default)
    supportsBranchScope: true,
  },

  // Payment collection workflows
  {
    eventType: AutomationType.PAYMENT_STATUS_CHANGED,
    displayName: 'Payment Collection Workflow Step',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [],
    supportsBranchScope: true,
  },

  // Payment reminders (scheduled)
  {
    eventType: AutomationType.REMINDER_DUE,
    displayName: 'Payment / Outstanding Balance Reminder',
    category: 'transactional',
    recipientType: 'customer',
    conditions: [
      { field: 'outstandingAmountPaise', operator: 'gt', value: 0 },
    ],
    supportsBranchScope: true,
  },
];


// ── Manifest Event-Pattern Validation ─────────────────────────────────────────

/**
 * Returns the complete set of EventBridge sources + detailTypes that must
 * appear in the module manifest's eventPatterns for full coverage.
 *
 * This can be used during build/test to validate the manifest stays in sync
 * with the registry.
 */
export function getRequiredEventPatterns(): Array<{ source: EventSource; detailTypes: string[] }> {
  const bySource = getEventTypesBySource();
  const patterns: Array<{ source: EventSource; detailTypes: string[] }> = [];
  for (const [source, types] of bySource.entries()) {
    patterns.push({ source, detailTypes: types.sort() });
  }
  return patterns;
}

/**
 * Returns a flat list of all registered event type keys.
 * Useful for validation and testing.
 */
export function getAllEventTypes(): string[] {
  return EVENT_REGISTRY.map((entry) => entry.eventType);
}

/**
 * Returns all event types that require a specific FeatureKey.
 * Useful for building admin UI groupings.
 */
export function getEventTypesByFeatureKey(featureKey: FeatureKey): string[] {
  return EVENT_REGISTRY
    .filter((entry) => entry.requiredFeatureKey === featureKey)
    .map((entry) => entry.eventType);
}
