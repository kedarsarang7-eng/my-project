// ============================================================================
// Staff Module — Shift & Roster Item Shapes + Zod Schemas (Task 5.3)
// ============================================================================
// DynamoDB single-table item shapes and fail-closed Zod validation for:
//
//   Shift  — SK: SHIFT#{id}   (shift definitions with break/late/overtime/
//                               geo-fence/approval rules per Business)
//   Roster — SK: ROSTER#{id}  (date-specific shift assignments)
//
// Every record is tenant + business scoped (PK = TENANT#{tenantId}#BIZ#{businessId})
// via ../keys.ts. This task provisions the shapes, validation, and the pure
// roster-builder shift-rule enforcement logic.
//
// SHIFT RULES — configurable per Business (Req 3.3):
//   breakRules       — define expected breaks (duration, earliest/latest start)
//   lateThresholdMin — minutes after shift start before a check-in is "late"
//   overtimeRule     — how overtime is calculated (after N minutes / approval-based)
//   geoFence         — lat/lng center + radiusMeters; employees must be within
//   approvalRule     — whether assignments need manager approval
//
// ROSTER ASSIGNMENT ENFORCEMENT (Req 3.7, Property 11):
// The pure function `validateRosterAssignment` checks each proposed assignment
// against the shift's configured rules. An assignment that violates any rule is
// REJECTED rather than persisted. The enforcement logic is kept as a pure,
// testable function so Property 11 can verify it with fast-check.
//
// Requirements: 3.3, 3.7.
// ============================================================================

import { z } from 'zod';

// ── Shared validators ─────────────────────────────────────────────────────────

const nonEmpty = z.string().min(1);

/** SK segments must never contain '#' (key-injection guard). */
const skSafe = nonEmpty.refine((v) => !v.includes('#'), {
    message: "value must not contain '#'",
});

/** HH:MM time-of-day string (24-hour). */
const timeOfDay = z
    .string()
    .regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'time must be HH:MM (24h)');

// ── Break Rules ─────────────────────────────────────────────────────────────

/**
 * A single break rule within a shift. Defines the break duration and optionally
 * restricts when it may start (earliest/latest relative to shift start).
 */
export interface BreakRule {
    /** Duration of the break in minutes (positive). */
    durationMin: number;
    /** Earliest minutes from shift start when break may begin. */
    earliestStartMin?: number;
    /** Latest minutes from shift start when break must begin. */
    latestStartMin?: number;
}

export const breakRuleSchema = z
    .object({
        durationMin: z.number().int().positive(),
        earliestStartMin: z.number().int().nonnegative().optional(),
        latestStartMin: z.number().int().nonnegative().optional(),
    })
    .strict()
    .refine(
        (r) =>
            r.earliestStartMin === undefined ||
            r.latestStartMin === undefined ||
            r.earliestStartMin <= r.latestStartMin,
        {
            message: 'earliestStartMin must not exceed latestStartMin',
            path: ['earliestStartMin'],
        },
    );

// ── Overtime Rule ────────────────────────────────────────────────────────────

export const OVERTIME_MODES = ['after_minutes', 'approval_required'] as const;
export type OvertimeMode = (typeof OVERTIME_MODES)[number];

/**
 * Overtime policy for a shift.
 *  - `after_minutes`: overtime starts after `thresholdMin` beyond shift end.
 *  - `approval_required`: overtime must be pre-approved by a manager.
 */
export interface OvertimeRule {
    mode: OvertimeMode;
    /** Minutes beyond shift end before overtime kicks in (for after_minutes mode). */
    thresholdMin?: number;
}

export const overtimeRuleSchema = z
    .object({
        mode: z.enum(OVERTIME_MODES),
        thresholdMin: z.number().int().nonnegative().optional(),
    })
    .strict()
    .refine(
        (r) => r.mode !== 'after_minutes' || (r.thresholdMin !== undefined && r.thresholdMin >= 0),
        {
            message: 'thresholdMin is required when mode is after_minutes',
            path: ['thresholdMin'],
        },
    );

// ── Geo-Fence ────────────────────────────────────────────────────────────────

/**
 * Geo-fence boundary for a shift. Employees assigned to this shift must check
 * in within `radiusMeters` of the centre point (lat/lng).
 */
export interface GeoFence {
    lat: number;
    lng: number;
    radiusMeters: number;
}

export const geoFenceSchema = z
    .object({
        lat: z.number().min(-90).max(90),
        lng: z.number().min(-180).max(180),
        radiusMeters: z.number().positive(),
    })
    .strict();

// ── Approval Rule ────────────────────────────────────────────────────────────

export const APPROVAL_MODES = ['auto', 'manager_required'] as const;
export type ApprovalMode = (typeof APPROVAL_MODES)[number];

/**
 * Whether assignments to this shift require explicit manager approval.
 *  - `auto`: assignments are immediately effective.
 *  - `manager_required`: assignments pend until a manager approves.
 */
export interface ApprovalRule {
    mode: ApprovalMode;
}

export const approvalRuleSchema = z
    .object({
        mode: z.enum(APPROVAL_MODES),
    })
    .strict();

// ── Shift — SK: SHIFT#{id} ───────────────────────────────────────────────────

export interface Shift {
    id: string;
    businessId: string;
    name: string;
    /** Shift start time HH:MM (24h). */
    start: string;
    /** Shift end time HH:MM (24h). */
    end: string;
    breakRules?: BreakRule[];
    lateThresholdMin?: number;
    overtimeRule?: OvertimeRule;
    geoFence?: GeoFence;
    approvalRule?: ApprovalRule;
    status: 'active' | 'inactive';
}

export const shiftCreateSchema = z
    .object({
        name: nonEmpty.max(200),
        start: timeOfDay,
        end: timeOfDay,
        breakRules: z.array(breakRuleSchema).max(10).optional(),
        lateThresholdMin: z.number().int().nonnegative().optional(),
        overtimeRule: overtimeRuleSchema.optional(),
        geoFence: geoFenceSchema.optional(),
        approvalRule: approvalRuleSchema.optional(),
        status: z.enum(['active', 'inactive']).default('active'),
    })
    .strict();

export const shiftUpdateSchema = z
    .object({
        name: nonEmpty.max(200).optional(),
        start: timeOfDay.optional(),
        end: timeOfDay.optional(),
        breakRules: z.array(breakRuleSchema).max(10).optional(),
        lateThresholdMin: z.number().int().nonnegative().optional(),
        overtimeRule: overtimeRuleSchema.optional(),
        geoFence: geoFenceSchema.optional(),
        approvalRule: approvalRuleSchema.optional(),
        status: z.enum(['active', 'inactive']).optional(),
    })
    .strict()
    .refine((obj) => Object.keys(obj).length > 0, {
        message: 'at least one field is required to update',
    });

export type ShiftCreateInput = z.infer<typeof shiftCreateSchema>;
export type ShiftUpdateInput = z.infer<typeof shiftUpdateSchema>;

// ── Roster Assignment ────────────────────────────────────────────────────────

/** A single employee–shift assignment within a roster. */
export interface RosterAssignment {
    employeeId: string;
    shiftId: string;
}

export const rosterAssignmentSchema = z
    .object({
        employeeId: skSafe,
        shiftId: skSafe,
    })
    .strict();

// ── Roster — SK: ROSTER#{id} ─────────────────────────────────────────────────

export interface Roster {
    id: string;
    businessId: string;
    /** The date this roster covers (YYYY-MM-DD). */
    date: string;
    /** Assignments that passed shift-rule enforcement. */
    assignments: RosterAssignment[];
    status: 'active' | 'inactive';
}

/** Calendar date YYYY-MM-DD. */
const dateOnly = z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD')
    .refine((v) => !Number.isNaN(Date.parse(`${v}T00:00:00.000Z`)), {
        message: 'date is not a valid calendar date',
    });

export const rosterCreateSchema = z
    .object({
        date: dateOnly,
        assignments: z.array(rosterAssignmentSchema).max(500),
    })
    .strict();

export const rosterUpdateSchema = z
    .object({
        date: dateOnly.optional(),
        assignments: z.array(rosterAssignmentSchema).max(500).optional(),
        status: z.enum(['active', 'inactive']).optional(),
    })
    .strict()
    .refine((obj) => Object.keys(obj).length > 0, {
        message: 'at least one field is required to update',
    });

export type RosterCreateInput = z.infer<typeof rosterCreateSchema>;
export type RosterUpdateInput = z.infer<typeof rosterUpdateSchema>;
