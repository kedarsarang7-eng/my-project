// ============================================================================
// Staff Module — Leave Management Item Shapes + Zod Schemas (Task 6.1)
// ============================================================================
// DynamoDB single-table item shapes and fail-closed Zod validation for the
// three leave entities defined in design.md → "Data Models":
//
//   LeaveType    — SK: LVTYPE#{id}                    (accrual rules + request rules)
//   LeaveRequest — SK: LVREQ#{id}                     (has `version` for optimistic concurrency)
//   LeaveBalance — SK: LVBAL#{employeeId}#{leaveTypeId} (available balance per employee/type)
//
// Every record is tenant + business scoped (PK = TENANT#{tenantId}#BIZ#{businessId})
// via ../keys.ts. This task provisions the SHAPES + validation and the request
// validation rule set. The approval workflow + leave calendar are task 6.2.
//
// Requirements: 4.1 (LeaveType definitions, accrual rules, balance tracking per
// Business), 4.2 (validate a request against LeaveType rules AND available
// LeaveBalance — Property 12).
// ============================================================================

import { z } from 'zod';

// ── Shared validators ─────────────────────────────────────────────────────────

/** SK segments must never contain '#' (key-injection guard, mirrors keys.ts). */
const skSafe = z
    .string()
    .min(1)
    .refine((v) => !v.includes('#'), { message: "value must not contain '#'" });

/** A calendar date: YYYY-MM-DD (leave is tracked in whole days). */
const dateOnly = z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD')
    .refine((v) => !Number.isNaN(Date.parse(`${v}T00:00:00.000Z`)), {
        message: 'date is not a valid calendar date',
    });

/** ISO-8601 timestamp string. */
const isoTimestamp = z.string().datetime({ offset: true });

const nonEmpty = z.string().min(1);

// ── Accrual rule (Req 4.1) ────────────────────────────────────────────────────
// How a leave type accrues balance over time. `none` means the balance is set
// manually (no automatic accrual). Amounts are in whole/half days.

export const ACCRUAL_FREQUENCIES = ['none', 'monthly', 'yearly'] as const;
export type AccrualFrequency = (typeof ACCRUAL_FREQUENCIES)[number];

export interface AccrualRule {
    frequency: AccrualFrequency;
    /** Days credited each accrual period (>= 0). Ignored when frequency = 'none'. */
    amountPerPeriod: number;
    /** Optional hard cap the balance can accrue to. */
    maxBalance?: number;
}

export const accrualRuleSchema = z
    .object({
        frequency: z.enum(ACCRUAL_FREQUENCIES),
        amountPerPeriod: z.number().nonnegative(),
        maxBalance: z.number().nonnegative().optional(),
    })
    .strict();

// ── Leave-type request rules (Req 4.2) ──────────────────────────────────────
// The constraints a LeaveRequest must satisfy to be accepted. All are optional;
// an absent rule is not enforced. `maxBalance` on the accrual rule governs
// accrual only — the balance check in the validator uses the LeaveBalance item.

export interface LeaveTypeRules {
    /** Request duration must be >= this many days. */
    minDurationDays?: number;
    /** Request duration must be <= this many consecutive days. */
    maxConsecutiveDays?: number;
    /** The start date must be at least this many days in the future. */
    minNoticeDays?: number;
}

export const leaveTypeRulesSchema = z
    .object({
        minDurationDays: z.number().positive().optional(),
        maxConsecutiveDays: z.number().positive().optional(),
        minNoticeDays: z.number().int().nonnegative().optional(),
    })
    .strict()
    .refine(
        (r) =>
            r.minDurationDays === undefined ||
            r.maxConsecutiveDays === undefined ||
            r.minDurationDays <= r.maxConsecutiveDays,
        {
            message: 'minDurationDays must not exceed maxConsecutiveDays',
            path: ['minDurationDays'],
        },
    );

// ── LeaveType — SK: LVTYPE#{id} ──────────────────────────────────────────────

export const LEAVE_STATUSES = ['active', 'inactive'] as const;
export type LeaveTypeStatus = (typeof LEAVE_STATUSES)[number];

export interface LeaveType {
    id: string;
    businessId: string;
    name: string;
    accrualRule: AccrualRule;
    rules: LeaveTypeRules;
    status: LeaveTypeStatus;
}

/** Input accepted when creating/updating a leave type (id/businessId are scoped by the handler). */
export const leaveTypeInputSchema = z
    .object({
        name: nonEmpty,
        accrualRule: accrualRuleSchema,
        // Rules default to an empty (unconstrained) set so a minimal leave type is valid.
        rules: leaveTypeRulesSchema.default({}),
        status: z.enum(LEAVE_STATUSES).default('active'),
    })
    .strict();

export type LeaveTypeInput = z.input<typeof leaveTypeInputSchema>;

// ── LeaveRequest — SK: LVREQ#{id} ────────────────────────────────────────────

export const LEAVE_REQUEST_STATUSES = ['pending', 'approved', 'rejected'] as const;
export type LeaveRequestStatus = (typeof LEAVE_REQUEST_STATUSES)[number];

export interface LeaveRequest {
    id: string;
    businessId: string;
    employeeId: string;
    leaveTypeId: string;
    from: string; // YYYY-MM-DD (inclusive)
    to: string; // YYYY-MM-DD (inclusive)
    status: LeaveRequestStatus;
    /** Optimistic-concurrency version (design.md). Reconciliation uses this on sync. */
    version: number;
}

/** Input accepted when an employee submits a leave request. */
export const leaveRequestInputSchema = z
    .object({
        employeeId: skSafe,
        leaveTypeId: skSafe,
        from: dateOnly,
        to: dateOnly,
    })
    .strict()
    .refine((r) => Date.parse(`${r.from}T00:00:00.000Z`) <= Date.parse(`${r.to}T00:00:00.000Z`), {
        message: '`from` date must be on or before `to` date',
        path: ['from'],
    });

export type LeaveRequestInput = z.input<typeof leaveRequestInputSchema>;

// ── LeaveBalance — SK: LVBAL#{employeeId}#{leaveTypeId} ───────────────────────

export interface LeaveBalance {
    id: string;
    businessId: string;
    employeeId: string;
    leaveTypeId: string;
    /** Available balance in days (may be fractional for half-day leave types). */
    balance: number;
}

/** Input accepted when setting/adjusting a balance directly. */
export const leaveBalanceInputSchema = z
    .object({
        employeeId: skSafe,
        leaveTypeId: skSafe,
        balance: z.number().nonnegative(),
    })
    .strict();

export type LeaveBalanceInput = z.input<typeof leaveBalanceInputSchema>;

// ── Leave Approval Input (Task 6.2) ───────────────────────────────────────────

/** Input for approve/reject operations on a leave request. */
export const leaveApprovalInputSchema = z
    .object({
        /** The `from` date of the request (needed to locate the item by SK). */
        from: dateOnly,
        /** Expected version for optimistic concurrency (design.md). */
        expectedVersion: z.number().int().nonnegative(),
    })
    .strict();

export type LeaveApprovalInput = z.input<typeof leaveApprovalInputSchema>;

// ── Leave Calendar Query (Task 6.2) ──────────────────────────────────────────

/** Query parameters for the leave calendar endpoint. */
export const leaveCalendarQuerySchema = z.object({
    from: dateOnly,
    to: dateOnly,
});

export type LeaveCalendarQuery = z.input<typeof leaveCalendarQuerySchema>;

// Re-export the timestamp validator so repositories can reuse it if needed.
export { isoTimestamp as leaveIsoTimestamp };
