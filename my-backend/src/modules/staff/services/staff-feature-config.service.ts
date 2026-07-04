// ============================================================================
// Staff Module — Staff_Feature_Config Resolver Service (Task 2.4)
// ============================================================================
// Resolves the set of enabled staff modules and fields for a given
// BusinessType × SubscriptionTier, layered on top of the existing feature
// gating mechanism (config/plan-feature-registry.ts + config/permission-matrix.ts).
//
// AD-2 — CONFIGURATION OVER FORKS
// -------------------------------
// Business-type differences are expressed ENTIRELY through Staff_Feature_Config
// VALUES. There is deliberately NO `switch (businessType)` anywhere in this file
// (or the module). Adding a new business type is a config change, not a code
// change. Resolution is a pure intersection of two data sources:
//   1. What the tier grants   → isFeatureAllowed(plan, businessType, featureKey)
//   2. What the config enables → StaffFeatureConfig.enabledModules / enabledFields
// A capability the tier does not include is therefore hidden/disabled with no
// code branch on business type required (Req 1.7, 1.8, 13.2, 13.3).
//
// Requirements: 1.6, 1.7, 1.8, 1.9, 13.1, 13.2, 13.3.
// ============================================================================

import { BusinessType, normalizeBusinessType } from '../../../types/tenant.types';
import {
    FeatureKey,
    PlanTier,
    isFeatureAllowed,
    mapToPlanTier,
} from '../../../config/plan-feature-registry';
import {
    STAFF_MODULES,
    StaffModule,
    StaffConfigTier,
    StaffFeatureConfig,
    staffFeatureConfigSchema,
} from '../schemas/staff-feature-config.schema';

// ── Module → FeatureKey mapping (single source of truth for gating) ──────────
// Each staff module is gated by its STAFF_* FeatureKey registered in
// config/plan-feature-registry.ts. This is the ONLY link between a module name
// and the plan/tier that unlocks it — no per-business-type logic.

export const STAFF_MODULE_FEATURE_KEY: Record<StaffModule, FeatureKey> = {
    core: FeatureKey.STAFF_CORE,
    attendance: FeatureKey.STAFF_ATTENDANCE,
    leave: FeatureKey.STAFF_LEAVE,
    tasks: FeatureKey.STAFF_TASKS,
    payroll: FeatureKey.STAFF_PAYROLL,
    performance: FeatureKey.STAFF_PERFORMANCE,
    commission: FeatureKey.STAFF_COMMISSION,
    reports: FeatureKey.STAFF_REPORTS,
};

// ── Resolution result ─────────────────────────────────────────────────────────

export interface ResolvedStaffCapabilities {
    businessType: string;
    tier: StaffConfigTier;
    /** Modules enabled by config AND granted by the tier. */
    enabledModules: StaffModule[];
    /** Field allow-lists for enabled modules only. */
    enabledFields: Partial<Record<StaffModule, string[]>>;
}

/**
 * Resolve the effective enabled modules/fields for a business.
 *
 * A module is enabled iff:
 *   (a) the config lists it in `enabledModules`, AND
 *   (b) the plan/tier grants its FeatureKey (via plan-feature-registry).
 * Field allow-lists are kept only for modules that survive (a) + (b).
 *
 * @param plan          resolved PlanTier for the business
 * @param businessType  the business type (used by isFeatureAllowed; never branched on)
 * @param config        the Staff_Feature_Config record for this BusinessType × tier
 */
export function resolveEnabledCapabilities(
    plan: PlanTier,
    businessType: BusinessType,
    config: StaffFeatureConfig,
): ResolvedStaffCapabilities {
    const enabledModules = config.enabledModules.filter((mod) =>
        isFeatureAllowed(plan, businessType, STAFF_MODULE_FEATURE_KEY[mod]),
    );

    const enabledSet = new Set<StaffModule>(enabledModules);
    const enabledFields: Partial<Record<StaffModule, string[]>> = {};
    for (const [mod, fields] of Object.entries(config.enabledFields)) {
        const moduleKey = mod as StaffModule;
        if (enabledSet.has(moduleKey) && fields) {
            enabledFields[moduleKey] = [...fields];
        }
    }

    return {
        businessType: config.businessType,
        tier: config.tier,
        enabledModules,
        enabledFields,
    };
}

/**
 * Convenience overload that accepts the raw values usually available on the
 * auth context (string plan + raw business type) and normalizes them before
 * resolving. Business-type normalization is data-driven (see tenant.types).
 */
export function resolveFromContext(
    rawPlan: string,
    rawBusinessType: string,
    config: StaffFeatureConfig,
): ResolvedStaffCapabilities {
    return resolveEnabledCapabilities(
        mapToPlanTier(rawPlan),
        normalizeBusinessType(rawBusinessType),
        config,
    );
}

// ── Validation ────────────────────────────────────────────────────────────────

export interface ConfigValidationResult {
    businessType: string;
    tier: string;
    valid: boolean;
    /** Human-readable validation errors (empty when valid). */
    errors: string[];
}

/**
 * Validate a single config against the Staff_Feature_Config schema (Req 1.9).
 * Returns a structured result rather than throwing so callers (and the pilot
 * validation below) can report every failure at once.
 */
export function validateConfig(config: unknown): ConfigValidationResult {
    const parsed = staffFeatureConfigSchema.safeParse(config);
    if (parsed.success) {
        return {
            businessType: parsed.data.businessType,
            tier: parsed.data.tier,
            valid: true,
            errors: [],
        };
    }

    const c = config as Partial<StaffFeatureConfig> | null;
    return {
        businessType: (c && typeof c === 'object' && c.businessType) || 'unknown',
        tier: (c && typeof c === 'object' && (c.tier as string)) || 'unknown',
        valid: false,
        errors: parsed.error.issues.map(
            (i) => `${i.path.join('.') || '(root)'}: ${i.message}`,
        ),
    };
}

// ── Pilot configurations (Req 1.9) ───────────────────────────────────────────
// Four pilot BusinessType × tier configs. They differ ONLY in data — proving a
// business type can be onboarded without any code fork (AD-2). Each is validated
// against the schema by `validatePilotConfigs()`.

export const STAFF_PILOT_CONFIGS: Readonly<Record<string, StaffFeatureConfig>> = {
    // Petrol Pump (Premium): shift-heavy workforce with commissioned pump staff.
    [BusinessType.PETROL_PUMP]: {
        businessType: BusinessType.PETROL_PUMP,
        tier: 'premium',
        enabledModules: ['core', 'attendance', 'tasks', 'payroll', 'performance', 'commission', 'reports'],
        enabledFields: {
            core: ['fullName', 'designationId', 'departmentId', 'status', 'contact', 'aadhaar', 'bankAccount'],
            attendance: ['method', 'geo', 'shift', 'overtimeRule'],
            payroll: ['salaryComponents', 'deductions', 'earnings', 'statutory', 'payslip'],
            commission: ['kind', 'params'],
        },
    },

    // School ERP (Premium): salaried teaching/non-teaching staff with leave.
    [BusinessType.SCHOOL_ERP]: {
        businessType: BusinessType.SCHOOL_ERP,
        tier: 'premium',
        enabledModules: ['core', 'attendance', 'leave', 'tasks', 'payroll', 'reports'],
        enabledFields: {
            core: ['fullName', 'designationId', 'departmentId', 'status', 'contact', 'pan', 'bankAccount'],
            attendance: ['method', 'shift'],
            leave: ['leaveType', 'balance', 'accrualRule', 'calendar'],
            payroll: ['salaryComponents', 'deductions', 'earnings', 'statutory', 'payslip'],
        },
    },

    // Clinic (Pro): small team — attendance, leave, tasks and reporting only.
    [BusinessType.CLINIC]: {
        businessType: BusinessType.CLINIC,
        tier: 'pro',
        enabledModules: ['core', 'attendance', 'leave', 'tasks', 'reports'],
        enabledFields: {
            core: ['fullName', 'designationId', 'status', 'contact'],
            attendance: ['method', 'shift'],
            leave: ['leaveType', 'balance', 'calendar'],
        },
    },

    // Jewellery (Premium): sales staff on commission + performance incentives.
    [BusinessType.JEWELLERY]: {
        businessType: BusinessType.JEWELLERY,
        tier: 'premium',
        enabledModules: ['core', 'attendance', 'leave', 'tasks', 'payroll', 'performance', 'commission', 'reports'],
        enabledFields: {
            core: ['fullName', 'designationId', 'status', 'contact', 'aadhaar', 'pan', 'bankAccount', 'upi'],
            commission: ['kind', 'params', 'formula'],
            performance: ['factors', 'weights', 'score'],
        },
    },
};

/**
 * Validate all four pilot configs against the schema (Req 1.9).
 * Returns one result per pilot; `valid` is false for any that fails.
 */
export function validatePilotConfigs(): ConfigValidationResult[] {
    return Object.values(STAFF_PILOT_CONFIGS).map((cfg) => validateConfig(cfg));
}

/** True iff every pilot config validates. Used by startup/tests as a guard. */
export function allPilotConfigsValid(): boolean {
    return validatePilotConfigs().every((r) => r.valid);
}

// Re-export the module list so callers don't reach into the schema module.
export { STAFF_MODULES };
