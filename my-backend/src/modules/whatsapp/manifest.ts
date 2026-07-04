// ============================================================================
// WHATSAPP MODULE MANIFEST — WhatsApp Automation System
// ============================================================================
// A single, configuration-driven, event-driven module that delivers automatic
// WhatsApp business communication for EVERY DukanX business type via the
// canonical OpenWA gateway (Baileys engine). There are NO per-industry code
// forks — differences are expressed through Automation_Config values only.
//
// Mirrors src/modules/staff/manifest.ts. The system consolidates all WhatsApp
// traffic onto the single canonical OpenWA_Gateway; no second gateway is
// introduced (Req 10.1, 10.2, 15.1).
//
// See ../../../.kiro/specs/openwa-whatsapp-automation/ for the full spec.
// ============================================================================

import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const whatsappManifest: ModuleManifest = {
    // ── Identity ────────────────────────────────────────────────────────────
    id: 'whatsapp',
    version: '1.0.0',
    displayName: 'WhatsApp Automation',
    status: 'beta',

    // ── Activation ──────────────────────────────────────────────────────────
    // Universal module — activates for ALL business types. Capability-level
    // gating (which automations are visible) is refined per BusinessType ×
    // SubscriptionTier through Automation_Config (AD-2: config, not forks).
    businessTypes: [
        BusinessType.GROCERY,
        BusinessType.PHARMACY,
        BusinessType.RESTAURANT,
        BusinessType.CLOTHING,
        BusinessType.ELECTRONICS,
        BusinessType.MOBILE_SHOP,
        BusinessType.COMPUTER_SHOP,
        BusinessType.HARDWARE,
        BusinessType.SERVICE,
        BusinessType.WHOLESALE,
        BusinessType.PETROL_PUMP,
        BusinessType.VEGETABLES_BROKER,
        BusinessType.CLINIC,
        BusinessType.BOOK_STORE,
        BusinessType.JEWELLERY,
        BusinessType.AUTO_PARTS,
        BusinessType.DECORATION_CATERING,
        BusinessType.SCHOOL_ERP,
        BusinessType.OTHER,
    ],
    requiredPlan: PlanTier.BASIC,   // capability-level gating refines per FeatureKey
    minRole: UserRole.MANAGER,

    // ── Feature Keys ──────────────────────────────────────────────────────────
    // WA_* capability keys registered in config/plan-feature-registry.ts.
    // Each maps to a discrete automation capability; Automation_Config refines
    // which of these are exposed per BusinessType × SubscriptionTier (AD-2).
    featureKeys: [
        FeatureKey.WA_CORE,          // customer profiles, consent, templates
        FeatureKey.WA_AUTOMATION,    // rules + engine
        FeatureKey.WA_INVOICING,     // invoice/payment automations
        FeatureKey.WA_REMINDERS,     // payment/outstanding reminders
        FeatureKey.WA_CAMPAIGNS,     // marketing/engagement campaigns
        FeatureKey.WA_ANALYTICS,     // daily summaries / analytics delivery
        FeatureKey.WA_MULTI_BRANCH,  // branch-scoped notifications
        FeatureKey.WA_AI_RESPONDER,  // OFF by default (Req 11.10, 15.2)
    ],

    // ── Infrastructure ────────────────────────────────────────────────────────
    lambdaFunctions: [
        'whatsappApi',        // config/templates/rules/customers/logs CRUD
        'whatsappEngine',     // Business_Event consumer (rule eval + enqueue)
        'whatsappDispatcher', // SQS consumer (rate-limited OpenWA dispatch)
        'whatsappWebhook',    // OpenWA status webhook receiver (HMAC verify)
        'whatsappScheduler',  // due-time sweeper for scheduled/delayed messages
    ],
    wsChannelPrefix: 'whatsapp:',
    apiPrefix: '/whatsapp',

    db: {
        // SK prefixes this module owns EXCLUSIVELY. Every WhatsApp record uses
        // PK = TENANT#{tenantId}#BIZ#{businessId} (business-scoped partition).
        // Key builders + per-entity access-pattern docs live in ./keys.ts.
        skPrefixes: [
            'WACONF#',     // Automation_Config (WACONF#{businessType}#{tier})
            'WATMPL#',     // Message_Template (current pointer)
            'WATMPLV#',    // Message_Template version history (immutable)
            'WARULE#',     // Automation_Rule
            'WACUST#',     // Customer_Profile (WhatsApp profile + consent)
            'WAOUT#',      // Outbound_Message
            'WADLOG#',     // Delivery_Log (append-only)
            'WAAUDIT#',    // Audit_Log (append-only)
            'WAPROC#',     // Idempotency processing marker (eventId#recipient)
            'WASCHED#',    // Scheduled dispatch index (due-time)
            'WALOW#',      // Low-stock alert hysteresis marker
            'WACOLL#',     // Payment-collection workflow cursor (Req 11.9)
        ],
        gsiIndexes: ['GSI1'],
        requiresWriteSharding: false,
    },

    // ── EventBridge ─────────────────────────────────────────────────────────
    eventPatterns: [
        {
            source: 'dukanx.billing',
            detailTypes: [
                'invoice.generated',
                'payment.received',
                'payment.refunded',
                'order.confirmed',
                'quotation.issued',
                'estimate.issued',
                'purchase_order.issued',
                'delivery_challan.issued',
                'receipt.generated',
                'credit_note.generated',
                'debit_note.generated',
                'payment.status_changed',
            ],
        },
        {
            source: 'dukanx.inventory',
            detailTypes: [
                'stock.below_threshold',
                'stock.replenished',
            ],
        },
        {
            source: 'dukanx.whatsapp',
            detailTypes: [
                'inbound.message.received',
                'campaign.due',
                'reminder.due',
                'quotation.abandoned_reminder_due',
            ],
        },
        {
            source: 'dukanx.crm',
            detailTypes: [
                'warranty.info_due',
                'loyalty.points_updated',
                'promotional.offer_due',
                'festival.greeting_due',
                'birthday.wish_due',
                'service.reminder_due',
                'feedback.request_due',
                'appointment.reminder_due',
            ],
        },
        {
            source: 'dukanx.operations',
            detailTypes: [
                'supplier.notification_due',
                'staff.notification_due',
                'approval.workflow_triggered',
                'analytics.daily_summary_due',
                'analytics.report_due',
            ],
        },
    ],

    // ── Rate Limiting ─────────────────────────────────────────────────────────
    // Messages per minute per tenant — enforced by the dispatcher worker.
    rateLimits: {
        [PlanTier.BASIC]: 100,
        [PlanTier.PRO]: 400,
        [PlanTier.PREMIUM]: 1200,
        [PlanTier.ENTERPRISE]: 5000,
    },

    // ── Dependencies ──────────────────────────────────────────────────────────
    dependsOn: ['billing'],

    // ── Future: AI / Marketplace ──────────────────────────────────────────────
    aiToolsEnabled: false,
    marketplaceEligible: false,
};
