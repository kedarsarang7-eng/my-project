// ============================================================================
// Staff Module — Pilot Config Validation + Route Reachability Unit Tests (Task 2.6)
// ============================================================================
// Two concerns, both derived from the config + resolver produced in task 2.4:
//
//   Req 1.9  — The four pilot configurations (Petrol Pump, School ERP, Clinic,
//              Jewellery) MUST validate against the Staff_Feature_Config schema.
//
//   Req 13.4 — No orphan routes: every module a pilot config exposes MUST be
//              reachable through a REGISTERED, FEATURE-GATED capability. A staff
//              module is "a route"; it is reachable iff (a) it maps to a STAFF_*
//              FeatureKey, (b) that key is a registered FeatureKey, (c) that key
//              has a permission-matrix rule (fail-closed gate), and (d) the
//              pilot's tier actually grants that gated capability (so the
//              resolver surfaces the module instead of silently dropping it).
//
// These are example-based Jest unit tests (task 2.6 is an OPTIONAL unit-test
// task, complementary to the property tests elsewhere in the plan).
// ============================================================================

import {
    STAFF_PILOT_CONFIGS,
    STAFF_MODULE_FEATURE_KEY,
    validateConfig,
    validatePilotConfigs,
    allPilotConfigsValid,
    resolveEnabledCapabilities,
} from '../staff-feature-config.service';
import { StaffModule } from '../../schemas/staff-feature-config.schema';
import {
    BusinessType,
    normalizeBusinessType,
} from '../../../../types/tenant.types';
import {
    FeatureKey,
    PlanTier,
    mapToPlanTier,
    isFeatureAllowed,
} from '../../../../config/plan-feature-registry';
import { PERMISSION_MATRIX } from '../../../../config/permission-matrix';

// The four pilots named in Req 1.9.
const EXPECTED_PILOTS: ReadonlyArray<BusinessType> = [
    BusinessType.PETROL_PUMP,
    BusinessType.SCHOOL_ERP,
    BusinessType.CLINIC,
    BusinessType.JEWELLERY,
];

// Every registered FeatureKey value (used to prove a mapping isn't orphaned).
const REGISTERED_FEATURE_KEYS = new Set<string>(Object.values(FeatureKey));

/** All modules a pilot config touches: enabledModules ∪ keys(enabledFields). */
function referencedModules(businessType: BusinessType): StaffModule[] {
    const cfg = STAFF_PILOT_CONFIGS[businessType];
    return Array.from(
        new Set<StaffModule>([
            ...cfg.enabledModules,
            ...(Object.keys(cfg.enabledFields) as StaffModule[]),
        ]),
    );
}

describe('Staff pilot configs — schema validation (Req 1.9)', () => {
    it('registers exactly the four named pilot business types', () => {
        expect(Object.keys(STAFF_PILOT_CONFIGS).sort()).toEqual(
            [...EXPECTED_PILOTS].sort(),
        );
    });

    it.each(EXPECTED_PILOTS)('validates the %s pilot config against the schema', (bt) => {
        const result = validateConfig(STAFF_PILOT_CONFIGS[bt]);
        // Surface the actual errors if this ever regresses.
        expect(result.errors).toEqual([]);
        expect(result.valid).toBe(true);
        expect(result.businessType).toBe(bt);
    });

    it('reports every pilot as valid via validatePilotConfigs()', () => {
        const results = validatePilotConfigs();
        expect(results).toHaveLength(EXPECTED_PILOTS.length);
        expect(results.every((r) => r.valid)).toBe(true);
    });

    it('passes the allPilotConfigsValid() startup guard', () => {
        expect(allPilotConfigsValid()).toBe(true);
    });

    it('declares each pilot at the tier it is defined for (self-consistent record)', () => {
        for (const bt of EXPECTED_PILOTS) {
            const cfg = STAFF_PILOT_CONFIGS[bt];
            expect(cfg.businessType).toBe(bt);
            expect(cfg.enabledModules.length).toBeGreaterThan(0);
        }
    });
});

describe('Staff pilot configs — route reachability (Req 13.4, no orphan routes)', () => {
    it('maps every referenced module to a STAFF_* FeatureKey', () => {
        for (const bt of EXPECTED_PILOTS) {
            for (const mod of referencedModules(bt)) {
                const key = STAFF_MODULE_FEATURE_KEY[mod];
                expect(key).toBeDefined();
                expect(String(key).startsWith('staff_')).toBe(true);
            }
        }
    });

    it('maps every referenced module to a REGISTERED FeatureKey (gated capability exists)', () => {
        for (const bt of EXPECTED_PILOTS) {
            for (const mod of referencedModules(bt)) {
                const key = STAFF_MODULE_FEATURE_KEY[mod];
                expect(REGISTERED_FEATURE_KEYS.has(String(key))).toBe(true);
            }
        }
    });

    it('gates every referenced module behind a permission-matrix rule (fail-closed reachability)', () => {
        for (const bt of EXPECTED_PILOTS) {
            for (const mod of referencedModules(bt)) {
                const key = STAFF_MODULE_FEATURE_KEY[mod];
                expect(PERMISSION_MATRIX[key]).toBeDefined();
            }
        }
    });

    it('grants every enabled module at the pilot tier (module is actually reachable, not silently dropped)', () => {
        for (const bt of EXPECTED_PILOTS) {
            const cfg = STAFF_PILOT_CONFIGS[bt];
            const plan = mapToPlanTier(cfg.tier);
            for (const mod of cfg.enabledModules) {
                const key = STAFF_MODULE_FEATURE_KEY[mod];
                expect(
                    isFeatureAllowed(plan, normalizeBusinessType(bt), key),
                ).toBe(true);
            }
        }
    });

    it('resolves the enabled modules exactly (no unreachable route survives resolution)', () => {
        for (const bt of EXPECTED_PILOTS) {
            const cfg = STAFF_PILOT_CONFIGS[bt];
            const resolved = resolveEnabledCapabilities(
                mapToPlanTier(cfg.tier),
                normalizeBusinessType(bt),
                cfg,
            );
            // Every module the config enables comes back enabled — proving each
            // is reachable via its registered gated capability at this tier.
            expect(resolved.enabledModules.sort()).toEqual(
                [...cfg.enabledModules].sort(),
            );
            // Field allow-lists only survive for enabled modules.
            for (const mod of Object.keys(resolved.enabledFields) as StaffModule[]) {
                expect(resolved.enabledModules).toContain(mod);
            }
        }
    });

    it('keeps every module → FeatureKey mapping itself registered and gated (no orphan mappings)', () => {
        for (const [, key] of Object.entries(STAFF_MODULE_FEATURE_KEY)) {
            expect(REGISTERED_FEATURE_KEYS.has(String(key))).toBe(true);
            expect(PERMISSION_MATRIX[key]).toBeDefined();
        }
    });

    it('rejects a config that enables a module missing from its tier (negative reachability)', () => {
        // A Basic-tier config trying to expose payroll (a Premium gated capability)
        // must NOT resolve payroll as enabled — the route stays unreachable.
        const cfg = {
            businessType: BusinessType.CLINIC,
            tier: 'basic' as const,
            enabledModules: ['core', 'payroll'] as StaffModule[],
            enabledFields: {},
        };
        const resolved = resolveEnabledCapabilities(
            PlanTier.BASIC,
            BusinessType.CLINIC,
            cfg,
        );
        expect(resolved.enabledModules).toContain('core');
        expect(resolved.enabledModules).not.toContain('payroll');
    });
});
