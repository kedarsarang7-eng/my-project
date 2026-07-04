// ============================================================================
// Feature: universal-staff-management, Property 7: Disabled capabilities are excluded by configuration
// ----------------------------------------------------------------------------
// Validates: Requirements 1.7, 13.2
//
// Property 7 (design.md):
//   "For any Staff_Feature_Config and any BusinessType × SubscriptionTier
//    combination, the resolved set of enabled modules and fields excludes
//    exactly those marked disabled (or not granted by the tier), and a
//    capability the tier does not include is hidden/disabled — with no code
//    branch on business type required."
//
// How this test proves the property:
//   The resolver (resolveEnabledCapabilities / resolveFromContext) is a pure
//   INTERSECTION of two data sources:
//     (a) what the config lists   → config.enabledModules / enabledFields
//     (b) what the tier grants    → isFeatureAllowed(plan, bt, STAFF_MODULE_FEATURE_KEY[m])
//   A module is enabled IFF (a) AND (b). We assert this exact bi-conditional for
//   every module across arbitrary businessType × tier × config combinations, so
//   any module that is unlisted OR not granted by the tier is provably excluded
//   (hidden/disabled). We also assert business-type independence: for the same
//   plan + config, the resolved modules are identical across every BusinessType,
//   which is exactly the "no code branch on business type" guarantee (AD-2).
// ============================================================================

import fc from 'fast-check';

import {
    resolveEnabledCapabilities,
    resolveFromContext,
    STAFF_MODULE_FEATURE_KEY,
} from '../staff-feature-config.service';
import {
    STAFF_MODULES,
    STAFF_MODULE_FIELDS,
    STAFF_CONFIG_TIERS,
    StaffModule,
    StaffConfigTier,
    StaffFeatureConfig,
} from '../../schemas/staff-feature-config.schema';
import {
    PlanTier,
    isFeatureAllowed,
    mapToPlanTier,
} from '../../../../config/plan-feature-registry';
import { BusinessType } from '../../../../types/tenant.types';

// Minimum fast-check iterations mandated by the spec for property tests.
const RUNS = 200;

// ── Generators ────────────────────────────────────────────────────────────────
// Constrain intelligently to the real input space: every BusinessType, every
// tier, and any non-empty subset of the known staff modules with per-module
// field allow-lists drawn only from that module's known fields.

const businessTypeArb = fc.constantFrom(...Object.values(BusinessType));

const tierArb = fc.constantFrom<StaffConfigTier>(...STAFF_CONFIG_TIERS);

const planArb = fc.constantFrom<PlanTier>(
    PlanTier.BASIC,
    PlanTier.PRO,
    PlanTier.PREMIUM,
    PlanTier.ENTERPRISE,
);

/** A non-empty, duplicate-free subset of the staff modules. */
const enabledModulesArb: fc.Arbitrary<StaffModule[]> = fc.subarray(
    [...STAFF_MODULES],
    { minLength: 1 },
);

/**
 * Build a well-formed config for a chosen module set: enabledFields keys are a
 * subset of the enabled modules and every field is a known field of its module
 * (mirrors the schema's constraints so the config is realistic).
 */
function configArb(
    businessType: string,
    tier: StaffConfigTier,
): fc.Arbitrary<StaffFeatureConfig> {
    return enabledModulesArb.chain((enabledModules) => {
        const fieldEntryArbs = enabledModules.map((mod) =>
            fc
                .subarray([...STAFF_MODULE_FIELDS[mod]])
                .map((fields) => [mod, fields] as const),
        );
        return fc.tuple(...fieldEntryArbs).map((entries) => {
            const enabledFields: Partial<Record<StaffModule, string[]>> = {};
            for (const [mod, fields] of entries) {
                // Only keep non-empty allow-lists (an empty list is meaningless).
                if (fields.length > 0) enabledFields[mod] = fields;
            }
            return { businessType, tier, enabledModules, enabledFields };
        });
    });
}

const scenarioArb = fc
    .record({
        businessType: businessTypeArb,
        tier: tierArb,
        plan: planArb,
    })
    .chain(({ businessType, tier, plan }) =>
        configArb(businessType, tier).map((config) => ({
            businessType,
            tier,
            plan,
            config,
        })),
    );

describe('Property 7: Disabled capabilities are excluded by configuration', () => {
    it('enables a module IFF the config lists it AND the tier grants its FeatureKey', () => {
        fc.assert(
            fc.property(scenarioArb, ({ businessType, plan, config }) => {
                const resolved = resolveEnabledCapabilities(
                    plan,
                    businessType as BusinessType,
                    config,
                );

                const listed = new Set(config.enabledModules);
                const resolvedSet = new Set(resolved.enabledModules);

                // The exact bi-conditional, asserted for EVERY known module.
                for (const mod of STAFF_MODULES) {
                    const isEnabled = resolvedSet.has(mod);
                    const grantedByTier = isFeatureAllowed(
                        plan,
                        businessType as BusinessType,
                        STAFF_MODULE_FEATURE_KEY[mod],
                    );
                    const expected = listed.has(mod) && grantedByTier;
                    expect(isEnabled).toBe(expected);
                }

                // No fabricated modules: every resolved module was listed in config.
                for (const mod of resolved.enabledModules) {
                    expect(listed.has(mod)).toBe(true);
                }
            }),
            { numRuns: RUNS },
        );
    });

    it('excludes exactly the fields whose owning module is not enabled', () => {
        fc.assert(
            fc.property(scenarioArb, ({ businessType, plan, config }) => {
                const resolved = resolveEnabledCapabilities(
                    plan,
                    businessType as BusinessType,
                    config,
                );
                const enabledSet = new Set(resolved.enabledModules);

                // (1) Every field key that survives belongs to an enabled module.
                for (const mod of Object.keys(resolved.enabledFields) as StaffModule[]) {
                    expect(enabledSet.has(mod)).toBe(true);
                }

                // (2) For each module: fields are preserved iff the module is enabled.
                for (const mod of STAFF_MODULES) {
                    const configured = config.enabledFields[mod];
                    if (enabledSet.has(mod) && configured) {
                        // Enabled + configured → fields carried through unchanged.
                        expect(resolved.enabledFields[mod]).toEqual(configured);
                    } else {
                        // Disabled (or no config) → no fields exposed.
                        expect(resolved.enabledFields[mod]).toBeUndefined();
                    }
                }
            }),
            { numRuns: RUNS },
        );
    });

    it('resolves identically across every business type (no code branch on business type)', () => {
        fc.assert(
            fc.property(
                planArb,
                tierArb,
                businessTypeArb,
                businessTypeArb,
                enabledModulesArb,
                (plan, tier, btA, btB, enabledModules) => {
                    // Same plan + same config, two arbitrary business types.
                    const config: StaffFeatureConfig = {
                        businessType: 'ignored',
                        tier,
                        enabledModules,
                        enabledFields: {},
                    };

                    const a = resolveEnabledCapabilities(plan, btA as BusinessType, {
                        ...config,
                        businessType: btA,
                    });
                    const b = resolveEnabledCapabilities(plan, btB as BusinessType, {
                        ...config,
                        businessType: btB,
                    });

                    // The staff capability keys are plan-tier core features, so the
                    // enabled module set depends only on plan + config — never on the
                    // business type. Identical output proves there is no fork.
                    expect(a.enabledModules).toEqual(b.enabledModules);
                },
            ),
            { numRuns: RUNS },
        );
    });

    it('resolveFromContext matches resolveEnabledCapabilities under plan mapping', () => {
        const rawPlanArb = fc.constantFrom(
            'free',
            'starter',
            'basic',
            'pro',
            'professional',
            'premium',
            'enterprise',
        );
        fc.assert(
            fc.property(rawPlanArb, scenarioArb, (rawPlan, { businessType, config }) => {
                const viaContext = resolveFromContext(rawPlan, businessType, config);
                const direct = resolveEnabledCapabilities(
                    mapToPlanTier(rawPlan),
                    businessType as BusinessType,
                    config,
                );
                expect(viaContext.enabledModules).toEqual(direct.enabledModules);
                expect(viaContext.enabledFields).toEqual(direct.enabledFields);
            }),
            { numRuns: RUNS },
        );
    });
});
