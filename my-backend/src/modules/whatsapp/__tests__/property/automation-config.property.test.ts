// ============================================================================
// Property-Based Test — Automation Config Resolution (Task 4.2)
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 1: Configuration resolution
//          excludes disabled and non-granted capabilities
//
// Validates: Requirements 1.2, 1.3, 1.4, 1.5, 1.9
//
// Property 1 (design.md): The resolved set of enabled automations is the
// intersection of (a) automations marked enabled in the Automation_Config AND
// (b) automations whose gating FeatureKey is granted by the plan/tier. Disabled
// automations never appear enabled. Non-granted automations never appear enabled.
// Missing config produces an all-disabled (empty) result.
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  resolveEnabledAutomations,
  clearConfigCache,
} from '../../services/automation-config.service';
import { PlanTier, FeatureKey } from '../../../../config/plan-feature-registry';
import { BusinessType } from '../../../../types/tenant.types';
import type { SubscriptionTier } from '../../schemas/entities';

// ── Constants mirroring the service's internal mapping ──────────────────────
// These map FeatureKeys → automation config keys, duplicated here for property
// assertions. If the service's mapping changes, these tests will correctly fail.

const FEATURE_KEY_TO_AUTOMATION_KEYS: Partial<Record<FeatureKey, string[]>> = {
  [FeatureKey.WA_CORE]: ['customer_profiles', 'consent', 'templates'],
  [FeatureKey.WA_AUTOMATION]: ['automation_rules', 'engine'],
  [FeatureKey.WA_INVOICING]: ['invoice_delivery', 'payment_confirmation', 'receipt_delivery'],
  [FeatureKey.WA_REMINDERS]: ['payment_reminders', 'outstanding_balance_reminders'],
  [FeatureKey.WA_CAMPAIGNS]: ['marketing_campaigns', 'promotional_offers', 'festival_greetings', 'birthday_wishes'],
  [FeatureKey.WA_ANALYTICS]: ['daily_summaries', 'analytics_delivery'],
  [FeatureKey.WA_MULTI_BRANCH]: ['multi_branch_notifications'],
  [FeatureKey.WA_AI_RESPONDER]: ['ai_responder'],
};

/** All automation keys recognized by the system. */
const ALL_AUTOMATION_KEYS = Object.values(FEATURE_KEY_TO_AUTOMATION_KEYS).flat();

/** Tier distribution of WA features. */
const TIER_WA_FEATURES: Record<PlanTier, FeatureKey[]> = {
  [PlanTier.BASIC]: [FeatureKey.WA_CORE, FeatureKey.WA_AUTOMATION],
  [PlanTier.PRO]: [FeatureKey.WA_CORE, FeatureKey.WA_AUTOMATION, FeatureKey.WA_INVOICING, FeatureKey.WA_REMINDERS],
  [PlanTier.PREMIUM]: [FeatureKey.WA_CORE, FeatureKey.WA_AUTOMATION, FeatureKey.WA_INVOICING, FeatureKey.WA_REMINDERS, FeatureKey.WA_CAMPAIGNS, FeatureKey.WA_ANALYTICS],
  [PlanTier.ENTERPRISE]: [FeatureKey.WA_CORE, FeatureKey.WA_AUTOMATION, FeatureKey.WA_INVOICING, FeatureKey.WA_REMINDERS, FeatureKey.WA_CAMPAIGNS, FeatureKey.WA_ANALYTICS, FeatureKey.WA_MULTI_BRANCH, FeatureKey.WA_AI_RESPONDER],
};

const NUM_RUNS = 150; // >= 100 per property

// ── Generators ──────────────────────────────────────────────────────────────

const businessTypeArb = fc.constantFrom(...Object.values(BusinessType));

const subscriptionTierArb: fc.Arbitrary<SubscriptionTier> = fc.constantFrom(
  'basic' as const,
  'pro' as const,
  'premium' as const,
  'enterprise' as const,
);

const planTierArb = fc.constantFrom(
  PlanTier.BASIC,
  PlanTier.PRO,
  PlanTier.PREMIUM,
  PlanTier.ENTERPRISE,
);

/** Generates an automation key from the known set or an arbitrary custom key. */
const automationKeyArb = fc.oneof(
  fc.constantFrom(...ALL_AUTOMATION_KEYS),
  fc.string({ minLength: 1, maxLength: 40 }).filter((s) => !s.includes('#') && s.trim().length > 0),
);

/** Generates a valid AutomationConfig-shaped object that passes the Zod schema. */
function validConfigArb(opts?: {
  /** Override specific automations as enabled/disabled for targeted testing. */
  forceKeys?: { key: string; enabled: boolean }[];
}) {
  return fc.record({
    id: fc.uuid().map((u) => u.replace(/-/g, '')),
    businessId: fc.uuid().map((u) => u.replace(/-/g, '')),
    tenantId: fc.uuid().map((u) => u.replace(/-/g, '')),
    businessType: fc.constantFrom('grocery', 'mobile_shop', 'clinic', 'school_erp', 'jewellery', 'petrol_pump'),
    tier: subscriptionTierArb,
    automations: fc
      .uniqueArray(automationKeyArb, { minLength: 1, maxLength: 12, comparator: 'IsStrictlyEqual' })
      .chain((keys) => {
        // Build a record of automation entries with random enabled/disabled
        const entries = keys.map((key) => {
          const forced = opts?.forceKeys?.find((f) => f.key === key);
          const enabledArb = forced ? fc.constant(forced.enabled) : fc.boolean();
          return enabledArb.map((enabled) => [key, { enabled }] as const);
        });
        return fc.tuple(...entries).map((pairs) =>
          Object.fromEntries(pairs) as Record<string, { enabled: boolean; templateId?: string; ruleIds?: string[] }>,
        );
      }),
    channels: fc.constant({ whatsapp: { enabled: true } } as Record<string, { enabled: boolean }>),
    schemaVersion: fc.integer({ min: 1, max: 100 }),
    createdAt: fc.constant('2025-01-01T00:00:00.000Z'),
    updatedAt: fc.constant('2025-06-01T00:00:00.000Z'),
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

/** Given a PlanTier, returns the set of automation keys that the plan grants. */
function getGrantedAutomationKeys(planTier: PlanTier): Set<string> {
  const grantedFeatures = TIER_WA_FEATURES[planTier];
  const keys = new Set<string>();
  for (const feature of grantedFeatures) {
    const mapped = FEATURE_KEY_TO_AUTOMATION_KEYS[feature];
    if (mapped) {
      for (const k of mapped) keys.add(k);
    }
  }
  return keys;
}

// ── Tests ───────────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 1: Configuration resolution excludes disabled and non-granted capabilities', () => {
  beforeEach(() => {
    clearConfigCache();
  });

  // ── Sub-property 1: Disabled automations are never in the resolved enabled set ──
  test('Disabled automations in config are never resolved as enabled (Req 1.2)', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        planTierArb,
        validConfigArb(),
        (businessType, planTier, config) => {
          const result = resolveEnabledAutomations(businessType, config.tier, config, planTier);

          // Find automations that are disabled in the config
          const disabledKeys = Object.entries(config.automations)
            .filter(([, entry]) => !entry.enabled)
            .map(([key]) => key);

          // None of the disabled keys should appear as enabled in the resolution
          const enabledInResult = result.automations
            .filter((a) => a.enabled)
            .map((a) => a.key);

          for (const disabledKey of disabledKeys) {
            expect(enabledInResult).not.toContain(disabledKey);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 2: Non-granted automations are never in the resolved enabled set ──
  test('Automations not granted by the plan/tier are never resolved as enabled (Req 1.5)', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        planTierArb,
        validConfigArb(),
        (businessType, planTier, config) => {
          const result = resolveEnabledAutomations(businessType, config.tier, config, planTier);

          // Determine which automation keys the plan grants
          const grantedKeys = getGrantedAutomationKeys(planTier);

          // Every enabled automation must have its key in the granted set
          const enabledInResult = result.automations.filter((a) => a.enabled);

          for (const automation of enabledInResult) {
            expect(grantedKeys.has(automation.key)).toBe(true);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 3: Only automations both enabled AND granted appear enabled ──
  test('Only automations that are both config-enabled AND plan-granted are resolved as enabled (Req 1.2, 1.3, 1.4, 1.5)', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        planTierArb,
        validConfigArb(),
        (businessType, planTier, config) => {
          const result = resolveEnabledAutomations(businessType, config.tier, config, planTier);

          const grantedKeys = getGrantedAutomationKeys(planTier);

          for (const resolved of result.automations) {
            const configEntry = config.automations[resolved.key];
            const configEnables = configEntry?.enabled ?? false;
            const planGrants = grantedKeys.has(resolved.key);

            // The resolved enabled state must equal (configEnables AND planGrants)
            expect(resolved.enabled).toBe(configEnables && planGrants);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 4: Missing config → empty/all-disabled result ──
  test('Missing config (null/undefined) results in empty automations with recorded condition (Req 1.9)', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        subscriptionTierArb,
        fc.constantFrom(null, undefined),
        (businessType, tier, nullishConfig) => {
          const result = resolveEnabledAutomations(businessType, tier, nullishConfig);

          // No automations in the result
          expect(result.automations).toHaveLength(0);

          // configValid is false
          expect(result.configValid).toBe(false);

          // A condition string is recorded explaining the absence
          expect(result.condition).toBeDefined();
          expect(typeof result.condition).toBe('string');
          expect(result.condition!.length).toBeGreaterThan(0);

          // Channels are also empty
          expect(result.channels).toHaveLength(0);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Concrete example: Basic tier cannot enable WA_CAMPAIGNS automation ──
  test('example: Basic tier config with marketing_campaigns enabled resolves it as disabled', () => {
    const config = {
      id: 'cfg001',
      businessId: 'biz001',
      tenantId: 'tenant001',
      businessType: 'grocery',
      tier: 'basic' as const,
      automations: {
        customer_profiles: { enabled: true },
        marketing_campaigns: { enabled: true }, // Not granted at BASIC
      },
      channels: { whatsapp: { enabled: true } },
      schemaVersion: 1,
      createdAt: '2025-01-01T00:00:00.000Z',
      updatedAt: '2025-01-01T00:00:00.000Z',
    };

    const result = resolveEnabledAutomations(
      BusinessType.GROCERY,
      'basic',
      config,
      PlanTier.BASIC,
    );

    // customer_profiles is WA_CORE (granted at BASIC) → enabled
    const customerProfiles = result.automations.find((a) => a.key === 'customer_profiles');
    expect(customerProfiles?.enabled).toBe(true);

    // marketing_campaigns is WA_CAMPAIGNS (requires PREMIUM+) → disabled
    const campaigns = result.automations.find((a) => a.key === 'marketing_campaigns');
    expect(campaigns?.enabled).toBe(false);
  });

  // ── Concrete example: Enterprise tier with disabled config entry ──
  test('example: Enterprise tier with config-disabled ai_responder resolves it as disabled', () => {
    const config = {
      id: 'cfg002',
      businessId: 'biz002',
      tenantId: 'tenant002',
      businessType: 'clinic',
      tier: 'enterprise' as const,
      automations: {
        ai_responder: { enabled: false }, // Granted at Enterprise but config-disabled
        invoice_delivery: { enabled: true },
      },
      channels: { whatsapp: { enabled: true } },
      schemaVersion: 1,
      createdAt: '2025-01-01T00:00:00.000Z',
      updatedAt: '2025-01-01T00:00:00.000Z',
    };

    const result = resolveEnabledAutomations(
      BusinessType.CLINIC,
      'enterprise',
      config,
      PlanTier.ENTERPRISE,
    );

    // ai_responder: plan grants it (Enterprise), but config says disabled → disabled
    const aiResp = result.automations.find((a) => a.key === 'ai_responder');
    expect(aiResp?.enabled).toBe(false);

    // invoice_delivery: plan grants it (Enterprise includes PRO), config says enabled → enabled
    const invoice = result.automations.find((a) => a.key === 'invoice_delivery');
    expect(invoice?.enabled).toBe(true);
  });
});
