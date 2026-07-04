// ============================================================================
// AutomationConfigResolver — Configuration Resolution Service (Task 4.1)
// ============================================================================
// Resolves (BusinessType, SubscriptionTier) → EnabledAutomations by layering
// the business-level Automation_Config on top of the plan-feature-registry.
//
// Design contracts:
// - Layers over plan-feature-registry (never bypasses it) (Req 1.5, 1.7)
// - Zod schema validation with last-valid retention on failure (Req 1.8)
// - Missing config → all-disabled with recorded condition (Req 1.9)
// - No per-business-type code branches — config-driven only (Req 1.3, 1.4)
// - Disabled automations excluded from evaluation (Req 1.2)
//
// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.7, 1.8, 1.9
// ============================================================================

import { ZodError } from 'zod';
import {
  PlanTier,
  FeatureKey,
  getAllowedFeatures,
} from '../../../config/plan-feature-registry';
import { BusinessType } from '../../../types/tenant.types';
import {
  automationConfigSchema,
  AutomationConfig,
  SubscriptionTier,
} from '../schemas/entities';

// ── Types ───────────────────────────────────────────────────────────────────

/** A single automation's resolved state. */
export interface ResolvedAutomation {
  /** Automation key name (e.g. 'invoice_delivery', 'payment_reminders'). */
  key: string;
  /** Whether this automation is enabled for the resolved business. */
  enabled: boolean;
  /** Template ID bound to this automation (if configured). */
  templateId?: string;
  /** Rule IDs bound to this automation (if configured). */
  ruleIds?: string[];
}

/** A resolved channel availability state. */
export interface ResolvedChannel {
  key: string;
  enabled: boolean;
}

/** The full resolution result from resolveEnabledAutomations. */
export interface AutomationResolution {
  /** The resolved set of automations with their enabled/disabled state. */
  automations: ResolvedAutomation[];
  /** The resolved set of channels with their enabled/disabled state. */
  channels: ResolvedChannel[];
  /** WA_* feature keys that the plan grants for this business. */
  grantedFeatureKeys: FeatureKey[];
  /** Whether the resolution was produced from a valid config (vs fallback). */
  configValid: boolean;
  /** If resolution fell back, this describes why. */
  condition?: string;
}

/** Mapping from WA_ FeatureKey to the automation config key(s) it gates. */
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

/** The set of WA_* feature keys that the automation system recognizes. */
const WA_FEATURE_KEYS: FeatureKey[] = [
  FeatureKey.WA_CORE,
  FeatureKey.WA_AUTOMATION,
  FeatureKey.WA_INVOICING,
  FeatureKey.WA_REMINDERS,
  FeatureKey.WA_CAMPAIGNS,
  FeatureKey.WA_ANALYTICS,
  FeatureKey.WA_MULTI_BRANCH,
  FeatureKey.WA_AI_RESPONDER,
];

// ── Last-valid config cache ─────────────────────────────────────────────────
// In-memory cache keyed by `${businessId}`. In a multi-Lambda environment this
// is per-invocation; a persistent store (DynamoDB) can be layered for
// cross-invocation retention — this in-memory map provides the spec-required
// "retain last valid" semantics within a process lifetime.

const lastValidConfigCache = new Map<string, AutomationConfig>();

// ── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Maps the SubscriptionTier string from the entity schema to the PlanTier enum
 * used by plan-feature-registry.
 */
function toPlanTier(tier: SubscriptionTier): PlanTier {
  switch (tier) {
    case 'basic':
      return PlanTier.BASIC;
    case 'pro':
      return PlanTier.PRO;
    case 'premium':
      return PlanTier.PREMIUM;
    case 'enterprise':
      return PlanTier.ENTERPRISE;
  }
}

/**
 * Get the set of WA_* feature keys granted by the plan for the given
 * business type. Filters the full allowed-features list down to WA_* only.
 */
function getGrantedWAFeatures(
  businessType: BusinessType,
  planTier: PlanTier,
): FeatureKey[] {
  const allAllowed = getAllowedFeatures(planTier, businessType);
  return WA_FEATURE_KEYS.filter((key) => allAllowed.includes(key));
}

/**
 * Builds a set of automation keys that the plan allows (based on granted
 * WA_* feature keys). Any automation key not in this set is disabled
 * regardless of what the Automation_Config says.
 */
function getPlanAllowedAutomationKeys(grantedFeatures: FeatureKey[]): Set<string> {
  const allowed = new Set<string>();
  for (const feature of grantedFeatures) {
    const keys = FEATURE_KEY_TO_AUTOMATION_KEYS[feature];
    if (keys) {
      for (const k of keys) {
        allowed.add(k);
      }
    }
  }
  return allowed;
}

// ── Core Resolution Function ────────────────────────────────────────────────

/**
 * Resolves which automations are enabled for a business given its type, tier,
 * Automation_Config (may be null/undefined), and the plan feature registry.
 *
 * Resolution logic:
 * 1. Determine granted WA_* features from plan-feature-registry (Req 1.5, 1.7)
 * 2. Validate the provided config against the Zod schema (Req 1.8)
 *    - If invalid: retain last valid config (in-memory cache); record error
 *    - If missing (null/undefined): all automations disabled (Req 1.9)
 * 3. For each automation in the config:
 *    - If the automation key is NOT plan-allowed → disabled (Req 1.2, 1.5)
 *    - If the automation is marked disabled in config → disabled (Req 1.2)
 *    - Otherwise → enabled with its bound template/rules
 * 4. For each channel in the config:
 *    - Require WA_CORE at minimum; otherwise disabled
 * 5. No per-business-type code branches (Req 1.3, 1.4) — all behavior driven
 *    by the config values and plan-feature-registry lookup.
 *
 * @param businessType - The business's type (drives plan feature lookup)
 * @param tier - The business's subscription tier
 * @param config - The Automation_Config for this business (may be null/undefined)
 * @param plan - Optional override for the plan tier (defaults to tier param)
 * @returns The full resolution result
 */
export function resolveEnabledAutomations(
  businessType: BusinessType,
  tier: SubscriptionTier,
  config: unknown | null | undefined,
  plan?: PlanTier,
): AutomationResolution {
  const planTier = plan ?? toPlanTier(tier);
  const grantedFeatureKeys = getGrantedWAFeatures(businessType, planTier);
  const planAllowedKeys = getPlanAllowedAutomationKeys(grantedFeatureKeys);

  // ── Case 1: No config provided → all disabled (Req 1.9) ──────────────
  if (config === null || config === undefined) {
    return {
      automations: [],
      channels: [],
      grantedFeatureKeys,
      configValid: false,
      condition: 'missing_config: No Automation_Config exists for this BusinessType and SubscriptionTier combination. All automations are disabled.',
    };
  }

  // ── Case 2: Validate config against Zod schema (Req 1.8) ─────────────
  const parseResult = automationConfigSchema.safeParse(config);

  let validConfig: AutomationConfig;

  if (!parseResult.success) {
    // Invalid config — attempt to retain last valid config
    const cacheKey = extractCacheKey(config);
    const lastValid = cacheKey ? lastValidConfigCache.get(cacheKey) : undefined;

    if (lastValid) {
      // Use last valid config (Req 1.8: retain last valid on failure)
      return buildResolution(lastValid, grantedFeatureKeys, planAllowedKeys, {
        configValid: false,
        condition: buildValidationErrorMessage(parseResult.error, 'last_valid_retained'),
      });
    }

    // No last valid config available — treat as missing (Req 1.9 fallback)
    return {
      automations: [],
      channels: [],
      grantedFeatureKeys,
      configValid: false,
      condition: buildValidationErrorMessage(
        parseResult.error,
        'no_last_valid_available: All automations disabled.',
      ),
    };
  }

  // Valid config — cache it for future fallback
  validConfig = parseResult.data;
  const businessCacheKey = validConfig.businessId;
  lastValidConfigCache.set(businessCacheKey, validConfig);

  // ── Case 3: Normal resolution from valid config ───────────────────────
  return buildResolution(validConfig, grantedFeatureKeys, planAllowedKeys, {
    configValid: true,
  });
}

// ── Internal Resolution Builder ─────────────────────────────────────────────

function buildResolution(
  config: AutomationConfig,
  grantedFeatureKeys: FeatureKey[],
  planAllowedKeys: Set<string>,
  meta: { configValid: boolean; condition?: string },
): AutomationResolution {
  const automations: ResolvedAutomation[] = [];
  const channels: ResolvedChannel[] = [];

  // Resolve automations: intersection of plan-allowed AND config-enabled
  for (const [key, entry] of Object.entries(config.automations)) {
    const planAllows = planAllowedKeys.has(key);
    const configEnables = entry.enabled;

    // Req 1.2: disabled if plan disallows OR config disables
    // Req 1.5: hidden/disabled if tier doesn't include it
    const enabled = planAllows && configEnables;

    automations.push({
      key,
      enabled,
      ...(enabled && entry.templateId ? { templateId: entry.templateId } : {}),
      ...(enabled && entry.ruleIds?.length ? { ruleIds: entry.ruleIds } : {}),
    });
  }

  // Resolve channels: require at least WA_CORE granted
  const hasCore = grantedFeatureKeys.includes(FeatureKey.WA_CORE);
  for (const [key, entry] of Object.entries(config.channels)) {
    channels.push({
      key,
      enabled: hasCore && entry.enabled,
    });
  }

  return {
    automations,
    channels,
    grantedFeatureKeys,
    ...meta,
  };
}

// ── Utility Helpers ─────────────────────────────────────────────────────────

/**
 * Attempts to extract a cache key (businessId) from a potentially-invalid
 * config object for last-valid lookup.
 */
function extractCacheKey(config: unknown): string | undefined {
  if (typeof config === 'object' && config !== null && 'businessId' in config) {
    const raw = (config as Record<string, unknown>).businessId;
    if (typeof raw === 'string' && raw.length > 0) {
      return raw;
    }
  }
  return undefined;
}

/**
 * Builds a human-readable validation error message from a ZodError.
 */
function buildValidationErrorMessage(error: ZodError, prefix: string): string {
  const issues = error.issues
    .slice(0, 5) // limit for readability
    .map((i) => `${i.path.join('.')}: ${i.message}`)
    .join('; ');
  return `${prefix}: Schema validation failed — ${issues}`;
}

// ── Exported Utilities for Testing / Composition ────────────────────────────

/**
 * Clears the in-memory last-valid config cache.
 * Useful for testing isolation.
 */
export function clearConfigCache(): void {
  lastValidConfigCache.clear();
}

/**
 * Gets the cached last-valid config for a business (by businessId).
 * Exposed for testing and debugging.
 */
export function getCachedConfig(businessId: string): AutomationConfig | undefined {
  return lastValidConfigCache.get(businessId);
}

/**
 * Returns WA_* feature keys granted for a given business type + tier.
 * Convenience wrapper for external consumers.
 */
export function getWAFeaturesForBusiness(
  businessType: BusinessType,
  tier: SubscriptionTier,
): FeatureKey[] {
  return getGrantedWAFeatures(businessType, toPlanTier(tier));
}

/**
 * Checks if a specific automation key is allowed by the plan for a given
 * business type + tier. Does NOT check Automation_Config — only the plan gate.
 */
export function isAutomationPlanAllowed(
  automationKey: string,
  businessType: BusinessType,
  tier: SubscriptionTier,
): boolean {
  const grantedFeatures = getGrantedWAFeatures(businessType, toPlanTier(tier));
  const allowed = getPlanAllowedAutomationKeys(grantedFeatures);
  return allowed.has(automationKey);
}
