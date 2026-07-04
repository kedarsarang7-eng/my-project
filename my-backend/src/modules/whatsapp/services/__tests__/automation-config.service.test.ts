// ============================================================================
// Unit Tests — AutomationConfigResolver (Task 4.1)
// ============================================================================
// Verifies the core resolution logic:
// - Plan-feature-registry integration (Req 1.5, 1.7)
// - Config-driven resolution without per-business-type code branches (Req 1.3, 1.4)
// - Zod validation with last-valid retention (Req 1.8)
// - Missing config → all disabled (Req 1.9)
// - Disabled/non-granted automations excluded (Req 1.2)
// ============================================================================

import { BusinessType } from '../../../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../../../config/plan-feature-registry';
import {
  resolveEnabledAutomations,
  clearConfigCache,
  getCachedConfig,
  getWAFeaturesForBusiness,
  isAutomationPlanAllowed,
} from '../automation-config.service';
import { AutomationConfig } from '../../schemas/entities';

// ── Test Helpers ────────────────────────────────────────────────────────────

function makeValidConfig(overrides: Partial<AutomationConfig> = {}): AutomationConfig {
  const now = new Date().toISOString();
  return {
    id: 'cfg-001',
    businessId: 'biz-001',
    tenantId: 'tenant-001',
    businessType: 'grocery',
    tier: 'pro',
    automations: {
      invoice_delivery: { enabled: true, templateId: 'tmpl-001' },
      payment_reminders: { enabled: true, templateId: 'tmpl-002', ruleIds: ['rule-001'] },
      marketing_campaigns: { enabled: true },
      ai_responder: { enabled: true },
    },
    channels: {
      whatsapp: { enabled: true },
    },
    schemaVersion: 1,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

// ── Tests ───────────────────────────────────────────────────────────────────

describe('AutomationConfigResolver', () => {
  beforeEach(() => {
    clearConfigCache();
  });

  // ── Missing config (Req 1.9) ──────────────────────────────────────────────

  describe('missing config → all disabled (Req 1.9)', () => {
    it('returns empty automations and channels when config is null', () => {
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', null);

      expect(result.automations).toEqual([]);
      expect(result.channels).toEqual([]);
      expect(result.configValid).toBe(false);
      expect(result.condition).toContain('missing_config');
    });

    it('returns empty automations and channels when config is undefined', () => {
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', undefined);

      expect(result.automations).toEqual([]);
      expect(result.channels).toEqual([]);
      expect(result.configValid).toBe(false);
      expect(result.condition).toContain('missing_config');
    });

    it('still provides granted feature keys even with no config', () => {
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', null);

      // PRO tier grants WA_CORE, WA_AUTOMATION, WA_INVOICING, WA_REMINDERS
      expect(result.grantedFeatureKeys).toContain(FeatureKey.WA_CORE);
      expect(result.grantedFeatureKeys).toContain(FeatureKey.WA_AUTOMATION);
      expect(result.grantedFeatureKeys).toContain(FeatureKey.WA_INVOICING);
      expect(result.grantedFeatureKeys).toContain(FeatureKey.WA_REMINDERS);
    });
  });

  // ── Valid config resolution (Req 1.1, 1.2, 1.5) ──────────────────────────

  describe('valid config resolution', () => {
    it('enables automations that are both plan-allowed AND config-enabled', () => {
      const config = makeValidConfig();
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', config);

      expect(result.configValid).toBe(true);
      const invoiceAuto = result.automations.find((a) => a.key === 'invoice_delivery');
      expect(invoiceAuto?.enabled).toBe(true);
      expect(invoiceAuto?.templateId).toBe('tmpl-001');
    });

    it('disables automations that the plan does not grant (Req 1.2, 1.5)', () => {
      // PRO tier does NOT grant WA_CAMPAIGNS or WA_AI_RESPONDER
      const config = makeValidConfig();
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', config);

      const campaigns = result.automations.find((a) => a.key === 'marketing_campaigns');
      expect(campaigns?.enabled).toBe(false);

      const aiResp = result.automations.find((a) => a.key === 'ai_responder');
      expect(aiResp?.enabled).toBe(false);
    });

    it('disables automations that config marks as disabled', () => {
      const config = makeValidConfig({
        automations: {
          invoice_delivery: { enabled: false },
          payment_reminders: { enabled: true },
        },
      });
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', config);

      const invoice = result.automations.find((a) => a.key === 'invoice_delivery');
      expect(invoice?.enabled).toBe(false);

      const reminders = result.automations.find((a) => a.key === 'payment_reminders');
      expect(reminders?.enabled).toBe(true);
    });

    it('includes templateId and ruleIds only for enabled automations', () => {
      const config = makeValidConfig({
        automations: {
          invoice_delivery: { enabled: false, templateId: 'tmpl-001' },
          payment_reminders: { enabled: true, templateId: 'tmpl-002', ruleIds: ['rule-001'] },
        },
      });
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', config);

      const invoice = result.automations.find((a) => a.key === 'invoice_delivery');
      expect(invoice?.templateId).toBeUndefined();

      const reminders = result.automations.find((a) => a.key === 'payment_reminders');
      expect(reminders?.templateId).toBe('tmpl-002');
      expect(reminders?.ruleIds).toEqual(['rule-001']);
    });

    it('caches the valid config for future fallback', () => {
      const config = makeValidConfig({ businessId: 'biz-cache-test' });
      resolveEnabledAutomations(BusinessType.GROCERY, 'pro', config);

      const cached = getCachedConfig('biz-cache-test');
      expect(cached).toBeDefined();
      expect(cached?.businessId).toBe('biz-cache-test');
    });
  });

  // ── Invalid config with last-valid retention (Req 1.8) ────────────────────

  describe('invalid config with last-valid retention (Req 1.8)', () => {
    it('uses last valid config when current config fails validation', () => {
      const validConfig = makeValidConfig({ businessId: 'biz-lvr' });
      resolveEnabledAutomations(BusinessType.GROCERY, 'pro', validConfig);

      // Now pass an invalid config (missing required fields)
      const invalidConfig = { businessId: 'biz-lvr', tier: 'pro' };
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', invalidConfig);

      // Should fall back to last valid config
      expect(result.configValid).toBe(false);
      expect(result.condition).toContain('last_valid_retained');
      // Automations from the cached valid config should be resolved
      expect(result.automations.length).toBeGreaterThan(0);
    });

    it('returns all-disabled when invalid config has no cached fallback', () => {
      const invalidConfig = { businessId: 'biz-no-cache', broken: true };
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', invalidConfig);

      expect(result.configValid).toBe(false);
      expect(result.condition).toContain('no_last_valid_available');
      expect(result.automations).toEqual([]);
      expect(result.channels).toEqual([]);
    });

    it('records the validation error in the condition field', () => {
      const invalidConfig = { businessId: 'biz-err', schemaVersion: -1 };
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', invalidConfig);

      expect(result.condition).toContain('Schema validation failed');
    });
  });

  // ── Plan tier gating (Req 1.5, 1.7) ──────────────────────────────────────

  describe('plan tier gating', () => {
    it('BASIC tier grants WA_CORE and WA_AUTOMATION only', () => {
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'basic', null);

      expect(result.grantedFeatureKeys).toContain(FeatureKey.WA_CORE);
      expect(result.grantedFeatureKeys).toContain(FeatureKey.WA_AUTOMATION);
      expect(result.grantedFeatureKeys).not.toContain(FeatureKey.WA_INVOICING);
      expect(result.grantedFeatureKeys).not.toContain(FeatureKey.WA_CAMPAIGNS);
    });

    it('PRO tier adds WA_INVOICING and WA_REMINDERS', () => {
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', null);

      expect(result.grantedFeatureKeys).toContain(FeatureKey.WA_INVOICING);
      expect(result.grantedFeatureKeys).toContain(FeatureKey.WA_REMINDERS);
      expect(result.grantedFeatureKeys).not.toContain(FeatureKey.WA_CAMPAIGNS);
    });

    it('PREMIUM tier adds WA_CAMPAIGNS and WA_ANALYTICS', () => {
      const result = resolveEnabledAutomations(BusinessType.CLINIC, 'premium', null);

      expect(result.grantedFeatureKeys).toContain(FeatureKey.WA_CAMPAIGNS);
      expect(result.grantedFeatureKeys).toContain(FeatureKey.WA_ANALYTICS);
      expect(result.grantedFeatureKeys).not.toContain(FeatureKey.WA_MULTI_BRANCH);
    });

    it('ENTERPRISE tier adds WA_MULTI_BRANCH and WA_AI_RESPONDER', () => {
      const result = resolveEnabledAutomations(BusinessType.JEWELLERY, 'enterprise', null);

      expect(result.grantedFeatureKeys).toContain(FeatureKey.WA_MULTI_BRANCH);
      expect(result.grantedFeatureKeys).toContain(FeatureKey.WA_AI_RESPONDER);
    });
  });

  // ── No per-business-type code branches (Req 1.3, 1.4) ────────────────────

  describe('config-driven (no per-business-type forks)', () => {
    it('different business types resolve through the same logic path', () => {
      const groceryConfig = makeValidConfig({ businessType: 'grocery' });
      const clinicConfig = makeValidConfig({
        businessType: 'clinic',
        businessId: 'biz-clinic',
      });

      const groceryResult = resolveEnabledAutomations(
        BusinessType.GROCERY, 'pro', groceryConfig,
      );
      const clinicResult = resolveEnabledAutomations(
        BusinessType.CLINIC, 'pro', clinicConfig,
      );

      // Both should be valid and have the same structure
      expect(groceryResult.configValid).toBe(true);
      expect(clinicResult.configValid).toBe(true);
      // Same automations enabled because same config structure + same plan
      expect(groceryResult.automations.length).toBe(clinicResult.automations.length);
    });
  });

  // ── Channel resolution ────────────────────────────────────────────────────

  describe('channel resolution', () => {
    it('enables channels when WA_CORE is granted and config enables them', () => {
      const config = makeValidConfig();
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', config);

      const waChannel = result.channels.find((c) => c.key === 'whatsapp');
      expect(waChannel?.enabled).toBe(true);
    });

    it('disables channels when config disables them', () => {
      const config = makeValidConfig({
        channels: { whatsapp: { enabled: false } },
      });
      const result = resolveEnabledAutomations(BusinessType.GROCERY, 'pro', config);

      const waChannel = result.channels.find((c) => c.key === 'whatsapp');
      expect(waChannel?.enabled).toBe(false);
    });
  });

  // ── Utility exports ───────────────────────────────────────────────────────

  describe('utility exports', () => {
    it('getWAFeaturesForBusiness returns correct features for a tier', () => {
      const features = getWAFeaturesForBusiness(BusinessType.GROCERY, 'enterprise');
      expect(features).toContain(FeatureKey.WA_AI_RESPONDER);
      expect(features).toContain(FeatureKey.WA_MULTI_BRANCH);
    });

    it('isAutomationPlanAllowed checks plan gate correctly', () => {
      // PRO has WA_INVOICING → invoice_delivery should be allowed
      expect(isAutomationPlanAllowed('invoice_delivery', BusinessType.GROCERY, 'pro')).toBe(true);
      // BASIC does NOT have WA_INVOICING → invoice_delivery should not be allowed
      expect(isAutomationPlanAllowed('invoice_delivery', BusinessType.GROCERY, 'basic')).toBe(false);
    });

    it('clearConfigCache removes all cached configs', () => {
      const config = makeValidConfig({ businessId: 'biz-clear' });
      resolveEnabledAutomations(BusinessType.GROCERY, 'pro', config);
      expect(getCachedConfig('biz-clear')).toBeDefined();

      clearConfigCache();
      expect(getCachedConfig('biz-clear')).toBeUndefined();
    });
  });
});
