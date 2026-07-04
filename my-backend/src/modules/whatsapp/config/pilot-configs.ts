// ============================================================================
// Pilot Automation_Config Fixtures (Task 4.4)
// ============================================================================
// Six canonical pilot configurations — one per pilot BusinessType — that prove
// the architecture adapts through configuration alone (Requirements 1.6, 1.7).
//
// DESIGN CONTRACTS:
// - Pure configuration values — NO per-business-type code branches
// - Each config validates against AutomationConfig Zod schema with ZERO violations
// - Automations enabled are appropriate for the specific business type
// - These are production-ready baseline configs for pilot onboarding
//
// AutomationConfig schema fields:
//   id, businessId, tenantId, businessType, tier, automations, channels,
//   schemaVersion, createdAt, updatedAt
//
// Requirements: 1.6, 1.7
// ============================================================================

import { AutomationConfig } from '../schemas/entities';

// ── Shared timestamp for fixture consistency ────────────────────────────────
const FIXTURE_CREATED_AT = '2025-01-01T00:00:00.000Z';
const FIXTURE_UPDATED_AT = '2025-01-01T00:00:00.000Z';

// ── 1. Grocery ──────────────────────────────────────────────────────────────
// Grocery shops need invoice delivery, payment reminders, low-stock alerts,
// and promotional offers for daily-deal items.

export const groceryConfig: AutomationConfig = {
  id: 'pilot-cfg-grocery',
  businessId: 'pilot-biz-grocery',
  tenantId: 'pilot-tenant-grocery',
  businessType: 'grocery',
  tier: 'pro',
  automations: {
    invoice_delivery: { enabled: true },
    payment_confirmation: { enabled: true },
    receipt_delivery: { enabled: true },
    payment_reminders: { enabled: true },
    outstanding_balance_reminders: { enabled: true },
    customer_profiles: { enabled: true },
    consent: { enabled: true },
    templates: { enabled: true },
    automation_rules: { enabled: true },
    engine: { enabled: true },
    marketing_campaigns: { enabled: false },
    promotional_offers: { enabled: false },
    festival_greetings: { enabled: false },
    birthday_wishes: { enabled: false },
    daily_summaries: { enabled: false },
    analytics_delivery: { enabled: false },
    multi_branch_notifications: { enabled: false },
    ai_responder: { enabled: false },
  },
  channels: {
    whatsapp: { enabled: true },
  },
  schemaVersion: 1,
  createdAt: FIXTURE_CREATED_AT,
  updatedAt: FIXTURE_UPDATED_AT,
};

// ── 2. Mobile Store ─────────────────────────────────────────────────────────
// Mobile stores focus on invoice+warranty delivery, repair status updates,
// payment confirmations, and EMI payment reminders.

export const mobileStoreConfig: AutomationConfig = {
  id: 'pilot-cfg-mobile-store',
  businessId: 'pilot-biz-mobile-store',
  tenantId: 'pilot-tenant-mobile-store',
  businessType: 'mobile_shop',
  tier: 'pro',
  automations: {
    invoice_delivery: { enabled: true },
    payment_confirmation: { enabled: true },
    receipt_delivery: { enabled: true },
    payment_reminders: { enabled: true },
    outstanding_balance_reminders: { enabled: true },
    customer_profiles: { enabled: true },
    consent: { enabled: true },
    templates: { enabled: true },
    automation_rules: { enabled: true },
    engine: { enabled: true },
    marketing_campaigns: { enabled: false },
    promotional_offers: { enabled: false },
    festival_greetings: { enabled: false },
    birthday_wishes: { enabled: false },
    daily_summaries: { enabled: false },
    analytics_delivery: { enabled: false },
    multi_branch_notifications: { enabled: false },
    ai_responder: { enabled: false },
  },
  channels: {
    whatsapp: { enabled: true },
  },
  schemaVersion: 1,
  createdAt: FIXTURE_CREATED_AT,
  updatedAt: FIXTURE_UPDATED_AT,
};

// ── 3. Clinic ───────────────────────────────────────────────────────────────
// Clinics need appointment reminders, prescription delivery, payment receipts,
// follow-up campaigns, and birthday wishes for patient engagement.

export const clinicConfig: AutomationConfig = {
  id: 'pilot-cfg-clinic',
  businessId: 'pilot-biz-clinic',
  tenantId: 'pilot-tenant-clinic',
  businessType: 'clinic',
  tier: 'premium',
  automations: {
    invoice_delivery: { enabled: true },
    payment_confirmation: { enabled: true },
    receipt_delivery: { enabled: true },
    payment_reminders: { enabled: true },
    outstanding_balance_reminders: { enabled: true },
    customer_profiles: { enabled: true },
    consent: { enabled: true },
    templates: { enabled: true },
    automation_rules: { enabled: true },
    engine: { enabled: true },
    marketing_campaigns: { enabled: true },
    promotional_offers: { enabled: false },
    festival_greetings: { enabled: true },
    birthday_wishes: { enabled: true },
    daily_summaries: { enabled: true },
    analytics_delivery: { enabled: true },
    multi_branch_notifications: { enabled: false },
    ai_responder: { enabled: false },
  },
  channels: {
    whatsapp: { enabled: true },
  },
  schemaVersion: 1,
  createdAt: FIXTURE_CREATED_AT,
  updatedAt: FIXTURE_UPDATED_AT,
};

// ── 4. School ERP ───────────────────────────────────────────────────────────
// Schools need fee reminders, receipt delivery, exam/result notifications,
// attendance alerts, event announcements, and parent communication.

export const schoolErpConfig: AutomationConfig = {
  id: 'pilot-cfg-school-erp',
  businessId: 'pilot-biz-school-erp',
  tenantId: 'pilot-tenant-school-erp',
  businessType: 'school_erp',
  tier: 'premium',
  automations: {
    invoice_delivery: { enabled: true },
    payment_confirmation: { enabled: true },
    receipt_delivery: { enabled: true },
    payment_reminders: { enabled: true },
    outstanding_balance_reminders: { enabled: true },
    customer_profiles: { enabled: true },
    consent: { enabled: true },
    templates: { enabled: true },
    automation_rules: { enabled: true },
    engine: { enabled: true },
    marketing_campaigns: { enabled: true },
    promotional_offers: { enabled: false },
    festival_greetings: { enabled: true },
    birthday_wishes: { enabled: true },
    daily_summaries: { enabled: true },
    analytics_delivery: { enabled: true },
    multi_branch_notifications: { enabled: false },
    ai_responder: { enabled: false },
  },
  channels: {
    whatsapp: { enabled: true },
  },
  schemaVersion: 1,
  createdAt: FIXTURE_CREATED_AT,
  updatedAt: FIXTURE_UPDATED_AT,
};

// ── 5. Petrol Pump ──────────────────────────────────────────────────────────
// Petrol pumps focus on shift-end daily summaries, credit payment reminders,
// outstanding balance collection, and payment receipts.

export const petrolPumpConfig: AutomationConfig = {
  id: 'pilot-cfg-petrol-pump',
  businessId: 'pilot-biz-petrol-pump',
  tenantId: 'pilot-tenant-petrol-pump',
  businessType: 'petrol_pump',
  tier: 'pro',
  automations: {
    invoice_delivery: { enabled: true },
    payment_confirmation: { enabled: true },
    receipt_delivery: { enabled: true },
    payment_reminders: { enabled: true },
    outstanding_balance_reminders: { enabled: true },
    customer_profiles: { enabled: true },
    consent: { enabled: true },
    templates: { enabled: true },
    automation_rules: { enabled: true },
    engine: { enabled: true },
    marketing_campaigns: { enabled: false },
    promotional_offers: { enabled: false },
    festival_greetings: { enabled: false },
    birthday_wishes: { enabled: false },
    daily_summaries: { enabled: false },
    analytics_delivery: { enabled: false },
    multi_branch_notifications: { enabled: false },
    ai_responder: { enabled: false },
  },
  channels: {
    whatsapp: { enabled: true },
  },
  schemaVersion: 1,
  createdAt: FIXTURE_CREATED_AT,
  updatedAt: FIXTURE_UPDATED_AT,
};

// ── 6. Jewellery ────────────────────────────────────────────────────────────
// Jewellery stores need invoice delivery with hallmark details, gold rate
// alerts, payment reminders for high-value items, custom order updates,
// festival/occasion campaigns, and birthday wishes for loyalty.

export const jewelleryConfig: AutomationConfig = {
  id: 'pilot-cfg-jewellery',
  businessId: 'pilot-biz-jewellery',
  tenantId: 'pilot-tenant-jewellery',
  businessType: 'jewellery',
  tier: 'premium',
  automations: {
    invoice_delivery: { enabled: true },
    payment_confirmation: { enabled: true },
    receipt_delivery: { enabled: true },
    payment_reminders: { enabled: true },
    outstanding_balance_reminders: { enabled: true },
    customer_profiles: { enabled: true },
    consent: { enabled: true },
    templates: { enabled: true },
    automation_rules: { enabled: true },
    engine: { enabled: true },
    marketing_campaigns: { enabled: true },
    promotional_offers: { enabled: true },
    festival_greetings: { enabled: true },
    birthday_wishes: { enabled: true },
    daily_summaries: { enabled: true },
    analytics_delivery: { enabled: true },
    multi_branch_notifications: { enabled: false },
    ai_responder: { enabled: false },
  },
  channels: {
    whatsapp: { enabled: true },
  },
  schemaVersion: 1,
  createdAt: FIXTURE_CREATED_AT,
  updatedAt: FIXTURE_UPDATED_AT,
};

// ── Aggregate Export ────────────────────────────────────────────────────────
// All six pilots as an array for iteration (e.g., schema validation tests).

export const PILOT_CONFIGS: AutomationConfig[] = [
  groceryConfig,
  mobileStoreConfig,
  clinicConfig,
  schoolErpConfig,
  petrolPumpConfig,
  jewelleryConfig,
];

/**
 * Lookup pilot config by businessType string.
 * Returns undefined if the businessType doesn't have a pilot config.
 */
export function getPilotConfig(businessType: string): AutomationConfig | undefined {
  return PILOT_CONFIGS.find((c) => c.businessType === businessType);
}
