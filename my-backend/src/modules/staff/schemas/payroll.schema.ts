// ============================================================================
// Staff Module — Payroll & Statutory Item Shapes + Zod Schemas (AD-1)
// ============================================================================
// Task 1.4 — Provision the payroll/statutory store on DynamoDB.
//
// These are the DynamoDB single-table item shapes for money-critical payroll
// and statutory records. They match design.md → "Payroll & statutory (DynamoDB
// single-table, ACID via transactions)" exactly.
//
//   - Money is ALWAYS an integer number of paise (never floats/decimals).
//   - Every item is tenant + business scoped (PK = TENANT#{tenantId}#BIZ#{businessId}).
//   - This task provisions the SHAPES + key builders only. The payroll
//     computation, single-writer lock, and TransactWriteCommand orchestration
//     are implemented in tasks 9.1–9.4 (payroll.service.ts / statutory.service.ts).
//
// Requirements: 1.4 (money-critical records in an ACID-transactional DynamoDB
// store), 6.2 (PF/ESI/PT/TDS from a versioned, effective-dated rate table).
// ============================================================================

import { z } from 'zod';

// ── Shared validators ───────────────────────────────────────────────────────

/** Money as a non-negative integer count of paise (100 paise = ₹1). */
const paise = z.number().int().nonnegative();

/** Signed money in paise — used for salary before/after audit deltas. */
const signedPaise = z.number().int();

/** Period is a calendar month: YYYY-MM (e.g. "2026-05"). */
const period = z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/, 'period must be YYYY-MM');

/** ISO-8601 timestamp string. */
const isoTimestamp = z.string().datetime({ offset: true });

const nonEmpty = z.string().min(1);

/** SK segments must never contain '#' (key-injection guard). */
const skSafe = nonEmpty.refine((v) => !v.includes('#'), {
    message: "value must not contain '#'",
});

// ── Salary component types (Req 6.1) ─────────────────────────────────────────

export const SALARY_COMPONENT_TYPES = [
    'monthly',
    'hourly',
    'daily',
    'weekly',
    'commission',
    'bonus',
    'incentive',
    'loan',
    'advance',
] as const;
export type SalaryComponentType = (typeof SALARY_COMPONENT_TYPES)[number];

export const STATUTORY_KINDS = ['PF', 'ESI', 'PT', 'TDS'] as const;
export type StatutoryKind = (typeof STATUTORY_KINDS)[number];

/** Sentinel used by non-state-specific statutory rates (PF/ESI/TDS). */
export const STATUTORY_STATE_ALL = 'ALL';

export const PAYROLL_RUN_STATUSES = ['draft', 'locked', 'processed', 'failed'] as const;
export type PayrollRunStatus = (typeof PAYROLL_RUN_STATUSES)[number];

// ── PayrollRun — SK: PAYRUN#{period} (single-writer lock item) ───────────────

/**
 * One run per (tenant, business, period). The single-writer lock is a
 * conditional PutItem (`attribute_not_exists(SK)`) on this item (task 9.3).
 */
export interface PayrollRun {
    id: string;
    tenantId: string;
    businessId: string;
    period: string; // YYYY-MM
    status: PayrollRunStatus;
    lockOwner?: string;
    lockedAt?: string;
    createdAt: string;
    updatedAt: string;
}

export const payrollRunSchema = z.object({
    id: nonEmpty,
    tenantId: skSafe,
    businessId: skSafe,
    period,
    status: z.enum(PAYROLL_RUN_STATUSES),
    lockOwner: nonEmpty.optional(),
    lockedAt: isoTimestamp.optional(),
    createdAt: isoTimestamp,
    updatedAt: isoTimestamp,
});

// ── Payslip — SK: PAYSLIP#{period}#{employeeId} ──────────────────────────────

/** Written atomically with its PayrollRun via TransactWriteCommand (task 9.2). */
export interface Payslip {
    id: string;
    businessId: string;
    payrollRunId: string;
    employeeId: string;
    period: string; // YYYY-MM
    grossPaise: number;
    netPaise: number;
    deductions: Record<string, number>; // { PF, ESI, PT, TDS, ... } in paise
    earnings: Record<string, number>; // component breakdown in paise
    createdAt: string;
}

export const payslipSchema = z.object({
    id: nonEmpty,
    businessId: skSafe,
    payrollRunId: nonEmpty,
    employeeId: skSafe,
    period,
    grossPaise: paise,
    netPaise: paise,
    deductions: z.record(z.string(), paise),
    earnings: z.record(z.string(), paise),
    createdAt: isoTimestamp,
});

// ── SalaryComponent — SK: SALCOMP#{employeeId}#{componentId} ──────────────────

export interface SalaryComponent {
    id: string;
    businessId: string;
    employeeId: string;
    type: SalaryComponentType;
    amountPaise: number;
    meta?: Record<string, unknown>;
}

export const salaryComponentSchema = z.object({
    id: skSafe,
    businessId: skSafe,
    employeeId: skSafe,
    type: z.enum(SALARY_COMPONENT_TYPES),
    amountPaise: paise,
    meta: z.record(z.string(), z.unknown()).optional(),
});

// ── StatutoryRate — SK: STATRATE#{kind}#{state|ALL}#{version} ─────────────────

/**
 * Effective-dated, versioned statutory rate. PT is state-specific; PF/ESI/TDS
 * use STATUTORY_STATE_ALL ('ALL'). Resolved at compute time (Req 6.2–6.4).
 */
export interface StatutoryRate {
    id: string;
    businessId: string;
    kind: StatutoryKind;
    state?: string; // required for PT; 'ALL' otherwise
    rate: number;
    params?: Record<string, unknown>;
    effectiveFrom: string;
    effectiveTo?: string;
    version: number;
}

export const statutoryRateSchema = z
    .object({
        id: nonEmpty,
        businessId: skSafe,
        kind: z.enum(STATUTORY_KINDS),
        state: skSafe.optional(),
        rate: z.number().nonnegative(),
        params: z.record(z.string(), z.unknown()).optional(),
        effectiveFrom: isoTimestamp,
        effectiveTo: isoTimestamp.optional(),
        version: z.number().int().nonnegative(),
    })
    .refine((r) => r.kind !== 'PT' || (!!r.state && r.state !== STATUTORY_STATE_ALL), {
        message: "PT (Professional Tax) rate must specify an employee state, not 'ALL'",
        path: ['state'],
    });

// ── SalaryChangeAudit — SK: AUDIT#{isoTimestamp}#{eventId} (append-only) ──────

/** Recorded BEFORE a salary change takes effect (Req 6.8; full audit in task 9.4). */
export interface SalaryChangeAudit {
    eventId: string;
    businessId: string;
    employeeId: string;
    beforePaise?: number;
    afterPaise?: number;
    approverId: string;
    at: string;
}

export const salaryChangeAuditSchema = z.object({
    eventId: skSafe,
    businessId: skSafe,
    employeeId: skSafe,
    beforePaise: signedPaise.optional(),
    afterPaise: signedPaise.optional(),
    approverId: nonEmpty,
    at: isoTimestamp,
});
