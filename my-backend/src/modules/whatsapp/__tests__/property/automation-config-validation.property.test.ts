// ============================================================================
// Feature: openwa-whatsapp-automation, Property 2: Invalid configuration is
//          rejected and the last valid config is retained
// ----------------------------------------------------------------------------
// Validates: Requirements 1.8
//
// Property 2 (design.md):
//   "If an Automation_Config fails schema validation when it is loaded or
//    updated, the system SHALL reject the invalid configuration, retain the
//    last valid configuration for the affected Business, and record an error
//    indicating the validation failure."
//
// This property test verifies:
// 1. Any config that violates the Zod schema is rejected (configValid: false)
// 2. After rejection, the previous valid config remains available via fallback
// 3. Valid configs are accepted normally (configValid: true)
// ============================================================================

import fc from 'fast-check';
import {
  resolveEnabledAutomations,
  clearConfigCache,
  getCachedConfig,
} from '../../services/automation-config.service';
import { PlanTier } from '../../../../config/plan-feature-registry';
import { BusinessType } from '../../../../types/tenant.types';
import { AutomationConfig } from '../../schemas/entities';

// ── Generators ──────────────────────────────────────────────────────────────

const businessTypes = Object.values(BusinessType);
const tiers = ['basic', 'pro', 'premium', 'enterprise'] as const;

const businessTypeArb = fc.constantFrom(...businessTypes);
const tierArb = fc.constantFrom(...tiers);

/** Generate a valid ISO-8601 UTC timestamp. */
const isoTimestampArb = fc.date({
  min: new Date('2020-01-01T00:00:00.000Z'),
  max: new Date('2030-12-31T23:59:59.999Z'),
}).map((d) => d.toISOString());

/** Generate a valid idRef (non-empty, no '#', max 128 chars). */
const idRefArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789_-'.split('')),
  { minLength: 1, maxLength: 32 },
);

/** Generate a valid automation entry. */
const automationEntryArb = fc.record({
  enabled: fc.boolean(),
  templateId: fc.option(idRefArb, { nil: undefined }),
  ruleIds: fc.option(fc.array(idRefArb, { maxLength: 5 }), { nil: undefined }),
});

/** Generate a valid channel entry. */
const channelEntryArb = fc.record({
  enabled: fc.boolean(),
});

/** Build a fully valid AutomationConfig object. */
const validConfigArb = fc.record({
  id: idRefArb,
  businessId: idRefArb,
  tenantId: idRefArb,
  businessType: fc.constantFrom('grocery', 'pharmacy', 'restaurant', 'clinic', 'hardware', 'mobile_shop'),
  tier: tierArb,
  automations: fc.dictionary(
    fc.constantFrom('invoice_delivery', 'payment_reminders', 'marketing_campaigns', 'ai_responder', 'daily_summaries'),
    automationEntryArb,
    { minKeys: 1, maxKeys: 5 },
  ),
  channels: fc.dictionary(
    fc.constantFrom('whatsapp', 'sms', 'email'),
    channelEntryArb,
    { minKeys: 1, maxKeys: 3 },
  ),
  schemaVersion: fc.integer({ min: 1, max: 100 }),
  createdAt: isoTimestampArb,
  updatedAt: isoTimestampArb,
});

/**
 * Generate an invalid config by introducing one or more schema violations.
 * Strategies that are INDEPENDENT of the businessId field so overriding
 * businessId for fallback testing doesn't accidentally fix the config.
 */
const invalidConfigArb = fc.oneof(
  // Strategy 1: Missing required fields (no 'id' or 'businessId')
  fc.record({
    tenantId: idRefArb,
    businessType: fc.string({ minLength: 1, maxLength: 10 }),
    tier: tierArb,
    automations: fc.dictionary(fc.string({ minLength: 1, maxLength: 10 }), automationEntryArb, { minKeys: 0, maxKeys: 2 }),
    channels: fc.dictionary(fc.string({ minLength: 1, maxLength: 10 }), channelEntryArb, { minKeys: 0, maxKeys: 2 }),
    schemaVersion: fc.integer({ min: 1, max: 10 }),
    createdAt: isoTimestampArb,
    updatedAt: isoTimestampArb,
  }),
  // Strategy 2: Invalid tier value
  validConfigArb.map((cfg) => ({
    ...cfg,
    tier: 'invalid_tier_value' as any,
  })),
  // Strategy 3: schemaVersion is not a positive integer
  validConfigArb.map((cfg) => ({
    ...cfg,
    schemaVersion: -1,
  })),
  // Strategy 4: automations has invalid entry (enabled is not boolean)
  validConfigArb.map((cfg) => ({
    ...cfg,
    automations: { invoice_delivery: { enabled: 'yes' as any } },
  })),
  // Strategy 5: Empty string for id (fails min length)
  validConfigArb.map((cfg) => ({
    ...cfg,
    id: '',
  })),
  // Strategy 6: Invalid timestamp format
  validConfigArb.map((cfg) => ({
    ...cfg,
    createdAt: 'not-a-date',
  })),
  // Strategy 7: businessType empty (fails min length)
  validConfigArb.map((cfg) => ({
    ...cfg,
    businessType: '',
  })),
  // Strategy 8: schemaVersion is zero (must be positive)
  validConfigArb.map((cfg) => ({
    ...cfg,
    schemaVersion: 0,
  })),
);

/**
 * Generate an invalid config specifically for the fallback test.
 * These are guaranteed to remain invalid even when businessId is overridden.
 */
const invalidConfigForFallbackArb = fc.oneof(
  // Invalid tier — not fixable by changing businessId
  validConfigArb.map((cfg) => ({
    ...cfg,
    tier: 'invalid_tier_value' as any,
  })),
  // Invalid schemaVersion — negative
  validConfigArb.map((cfg) => ({
    ...cfg,
    schemaVersion: -1,
  })),
  // Invalid automation entry (enabled is not boolean)
  validConfigArb.map((cfg) => ({
    ...cfg,
    automations: { invoice_delivery: { enabled: 'yes' as any } },
  })),
  // Empty id
  validConfigArb.map((cfg) => ({
    ...cfg,
    id: '',
  })),
  // Invalid timestamp
  validConfigArb.map((cfg) => ({
    ...cfg,
    createdAt: 'not-a-date',
  })),
  // Empty businessType
  validConfigArb.map((cfg) => ({
    ...cfg,
    businessType: '',
  })),
);

// ============================================================================
// Property 2 Tests
// ============================================================================

describe('Feature: openwa-whatsapp-automation, Property 2: Invalid configuration is rejected and the last valid config is retained', () => {
  beforeEach(() => {
    clearConfigCache();
  });

  test('Any config that violates the schema is rejected (configValid: false) [Validates: Requirements 1.8]', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        tierArb,
        invalidConfigArb,
        (businessType, tier, invalidConfig) => {
          clearConfigCache();

          const result = resolveEnabledAutomations(businessType, tier, invalidConfig);

          // Invalid configs must always be rejected
          expect(result.configValid).toBe(false);
          // Must record an error condition
          expect(result.condition).toBeDefined();
          expect(result.condition!.length).toBeGreaterThan(0);
        },
      ),
      { numRuns: 100 },
    );
  });

  test('After rejection, the previous valid config remains available via fallback [Validates: Requirements 1.8]', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        tierArb,
        validConfigArb,
        invalidConfigForFallbackArb,
        (businessType, tier, validConfig, invalidConfig) => {
          clearConfigCache();

          // Step 1: Load a valid config to prime the cache
          const validResult = resolveEnabledAutomations(businessType, tier, validConfig);
          expect(validResult.configValid).toBe(true);

          // Step 2: Attempt to load an invalid config with the same businessId
          // so the cache lookup finds the previously-cached valid config
          const invalidWithSameBusinessId = {
            ...invalidConfig,
            businessId: validConfig.businessId,
          };
          const invalidResult = resolveEnabledAutomations(
            businessType,
            tier,
            invalidWithSameBusinessId,
          );

          // The invalid config must be rejected
          expect(invalidResult.configValid).toBe(false);
          expect(invalidResult.condition).toBeDefined();

          // The last valid config must still be in the cache
          const cached = getCachedConfig(validConfig.businessId);
          expect(cached).toBeDefined();
          expect(cached!.businessId).toBe(validConfig.businessId);

          // The resolution should still produce automations from the last valid
          // config (not empty, as would happen with no fallback)
          if (Object.keys(validConfig.automations).length > 0) {
            expect(invalidResult.automations.length).toBeGreaterThan(0);
          }
        },
      ),
      { numRuns: 100 },
    );
  });

  test('Valid configs are accepted normally (configValid: true) [Validates: Requirements 1.8]', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        tierArb,
        validConfigArb,
        (businessType, tier, validConfig) => {
          clearConfigCache();

          const result = resolveEnabledAutomations(businessType, tier, validConfig);

          // Valid configs must be accepted
          expect(result.configValid).toBe(true);
          // No error condition should be recorded
          expect(result.condition).toBeUndefined();
          // The config should be cached for future fallback
          const cached = getCachedConfig(validConfig.businessId);
          expect(cached).toBeDefined();
          expect(cached!.id).toBe(validConfig.id);
          expect(cached!.businessId).toBe(validConfig.businessId);
        },
      ),
      { numRuns: 100 },
    );
  });
});
