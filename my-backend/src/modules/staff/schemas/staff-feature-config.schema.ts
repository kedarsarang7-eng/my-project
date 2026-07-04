// ============================================================================
// Staff Module — Staff_Feature_Config Item Shape + Zod Schema (Task 2.4)
// ============================================================================
// The Staff_Feature_Config is the machine-readable configuration that maps each
// BusinessType × SubscriptionTier combination to a set of enabled staff modules
// and enabled fields (Req 1.6). It is the ONLY place business-type differences
// are expressed — as CONFIG VALUES, never as `switch (businessType)` code forks
// (AD-2, Req 1.8, 13.3).
//
// DynamoDB single-table item — SK: STAFFCFG#{businessType}#{tier}
// (key builder: ../keys.ts::buildStaffFeatureConfigKeys). Every record is
// tenant + business scoped (PK = TENANT#{tenantId}#BIZ#{businessId}).
//
// Requirements: 1.6, 1.7, 1.8, 1.9, 13.1, 13.2, 13.3.
// ============================================================================

import { z } from 'zod';

// ── Staff capability areas ("modules") ───────────────────────────────────────
// Each maps 1:1 to a STAFF_* FeatureKey in config/plan-feature-registry.ts. The
// mapping (and the tier that unlocks each) lives in the resolver service so this
// schema stays free of gating logic.

export const STAFF_MODULES = [
    'core', // Employee / Department / Designation
    'attendance', // Attendance capture + shifts / rosters
    'leave', // Leave types, balances, approvals
    'tasks', // Task assignment + workflow
    'payroll', // Payroll engine + payslips
    'performance', // Performance scoring
    'commission', // Commission rules
    'reports', // Reporting / search / dashboards
] as const;

export type StaffModule = (typeof STAFF_MODULES)[number];

// ── Known fields per module ───────────────────────────────────────────────────
// Used to validate a config's `enabledFields` references real, known fields so a
// typo can never silently enable/disable nothing (Req 1.9 — pilot configs are
// validated against this schema).

export const STAFF_MODULE_FIELDS: Record<StaffModule, readonly string[]> = {
    core: [
        'fullName',
        'designationId',
        'departmentId',
        'status',
        'contact',
        'aadhaar',
        'pan',
        'passport',
        'drivingLicence',
        'bankAccount',
        'upi',
    ],
    attendance: ['method', 'geo', 'shift', 'breakRules', 'overtimeRule', 'geoFence'],
    leave: ['leaveType', 'balance', 'accrualRule', 'calendar'],
    tasks: ['priority', 'checklist', 'attachments', 'comments', 'dependencies', 'recurrence', 'escalation'],
    payroll: ['salaryComponents', 'deductions', 'earnings', 'statutory', 'payslip'],
    performance: ['factors', 'weights', 'score'],
    commission: ['kind', 'params', 'formula'],
    reports: ['dashboards', 'export', 'search', 'insights'],
} as const;

// ── Subscription tiers (mirror PlanTier values) ──────────────────────────────

export const STAFF_CONFIG_TIERS = ['basic', 'pro', 'premium', 'enterprise'] as const;
export type StaffConfigTier = (typeof STAFF_CONFIG_TIERS)[number];

// ── Item shape ────────────────────────────────────────────────────────────────

export interface StaffFeatureConfig {
    businessType: string;
    tier: StaffConfigTier;
    /** Modules this BusinessType × tier combination is configured to expose. */
    enabledModules: StaffModule[];
    /** Per-module field allow-list. Keys MUST be enabled modules. */
    enabledFields: Partial<Record<StaffModule, string[]>>;
}

// ── Zod schema (fail-closed validation) ──────────────────────────────────────

const staffModuleEnum = z.enum(STAFF_MODULES);

export const staffFeatureConfigSchema = z
    .object({
        businessType: z.string().min(1).refine((v) => !v.includes('#'), {
            message: "businessType must not contain '#'",
        }),
        tier: z.enum(STAFF_CONFIG_TIERS),
        enabledModules: z.array(staffModuleEnum).min(1, 'at least one module must be enabled'),
        // String-keyed record (partial) — the superRefine below validates that
        // every key is an enabled module and every field is known for it.
        enabledFields: z.record(z.string(), z.array(z.string().min(1))),
    })
    .superRefine((cfg, ctx) => {
        const enabled = new Set(cfg.enabledModules);

        // enabledModules must be unique
        if (enabled.size !== cfg.enabledModules.length) {
            ctx.addIssue({
                code: 'custom',
                message: 'enabledModules contains duplicates',
                path: ['enabledModules'],
            });
        }

        for (const [mod, fields] of Object.entries(cfg.enabledFields)) {
            const moduleKey = mod as StaffModule;

            // A field allow-list only makes sense for an enabled module.
            if (!enabled.has(moduleKey)) {
                ctx.addIssue({
                    code: 'custom',
                    message: `enabledFields references module "${mod}" that is not in enabledModules`,
                    path: ['enabledFields', mod],
                });
                continue;
            }

            // Every referenced field must be a known field of that module.
            const known = STAFF_MODULE_FIELDS[moduleKey];
            for (const field of fields ?? []) {
                if (!known.includes(field)) {
                    ctx.addIssue({
                        code: 'custom',
                        message: `unknown field "${field}" for module "${mod}"`,
                        path: ['enabledFields', mod],
                    });
                }
            }
        }
    });

export type StaffFeatureConfigInput = z.input<typeof staffFeatureConfigSchema>;
