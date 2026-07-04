// ============================================================================
// Staff Module — Payroll & Statutory DynamoDB Key Builders (AD-1)
// ============================================================================
// Task 1.4 — Provision the payroll/statutory store on DynamoDB.
//
// ALL payroll/statutory data lives in the existing DynamoDB single-table design
// (config/dynamodb.config.ts: "Replaces PostgreSQL (RDS) with DynamoDB"). There
// is NO relational/Aurora store — money-critical ACID needs are met with native
// DynamoDB `TransactWriteCommand` (atomic run + payslips) and a conditional
// `PutItem` (attribute_not_exists) single-writer lock. See design.md AD-1.
//
// Every item is tenant + business scoped:
//     PK = TENANT#{tenantId}#BIZ#{businessId}   (via businessPK)
// SK prefixes below are owned EXCLUSIVELY by the staff manifest (../manifest.ts):
//     PAYRUN#  PAYSLIP#  SALCOMP#  STATRATE#  AUDIT#
//
// Money is ALWAYS stored as integer paise (number) — never floats/decimals.
// ============================================================================

import { businessPK, gsi1PK, gsi1SK, EntityKeys } from '../../../dynamodb/keys';

// ---- SK Prefixes (owned by the staff manifest) ----

export const PAYRUN_SK_PREFIX = 'PAYRUN#';
export const PAYSLIP_SK_PREFIX = 'PAYSLIP#';
export const SALCOMP_SK_PREFIX = 'SALCOMP#';
export const STATRATE_SK_PREFIX = 'STATRATE#';
export const SALARY_AUDIT_SK_PREFIX = 'AUDIT#';

/**
 * SECURITY: reject '#' injection in any user-derived SK segment. Mirrors the
 * partition-key invariant enforced by dynamodb/keys.ts::validateKeySegment.
 */
function validateSkSegment(value: string, name: string): void {
    if (value === undefined || value === null || `${value}`.trim() === '') {
        throw new Error(`SECURITY: ${name} is required for SK construction`);
    }
    if (`${value}`.includes('#')) {
        throw new Error(
            `SECURITY: ${name} contains illegal '#' character. Possible key injection attack.`,
        );
    }
}

// ---- Sort Key Builders ----

/** PayrollRun SK — one run per (tenant, business, period). period = YYYY-MM. */
export function payrollRunSK(period: string): string {
    validateSkSegment(period, 'period');
    return `${PAYRUN_SK_PREFIX}${period}`;
}

/** Payslip SK — one payslip per (period, employee), written atomically with its run. */
export function payslipSK(period: string, employeeId: string): string {
    validateSkSegment(period, 'period');
    validateSkSegment(employeeId, 'employeeId');
    return `${PAYSLIP_SK_PREFIX}${period}#${employeeId}`;
}

/** SalaryComponent SK — per-employee salary component. */
export function salaryComponentSK(employeeId: string, componentId: string): string {
    validateSkSegment(employeeId, 'employeeId');
    validateSkSegment(componentId, 'componentId');
    return `${SALCOMP_SK_PREFIX}${employeeId}#${componentId}`;
}

/**
 * StatutoryRate SK — effective-dated, versioned rate. kind ∈ PF|ESI|PT|TDS.
 * PT is state-specific; PF/ESI/TDS use the sentinel 'ALL'.
 */
export function statutoryRateSK(
    kind: 'PF' | 'ESI' | 'PT' | 'TDS',
    stateOrAll: string,
    version: number,
): string {
    validateSkSegment(kind, 'kind');
    validateSkSegment(stateOrAll, 'state');
    validateSkSegment(`${version}`, 'version');
    return `${STATRATE_SK_PREFIX}${kind}#${stateOrAll}#${version}`;
}

/** SalaryChangeAudit SK — append-only, keyed by ISO timestamp + event id. */
export function salaryChangeAuditSK(isoTimestamp: string, eventId: string): string {
    validateSkSegment(isoTimestamp, 'isoTimestamp');
    validateSkSegment(eventId, 'eventId');
    return `${SALARY_AUDIT_SK_PREFIX}${isoTimestamp}#${eventId}`;
}

// ---- Entity Key Builders (PK + SK [+ GSI1]) ----

/**
 * PayrollRun keys. The single-writer lock is a conditional PutItem
 * (`attribute_not_exists(SK)`) on this item — a second run for the same
 * (tenant, business, period) fails with TransactionCanceledException.
 * GSI1 lists runs by period for a business.
 */
export function buildPayrollRunKeys(
    tenantId: string,
    businessId: string,
    period: string,
): EntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: payrollRunSK(period),
        GSI1PK: gsi1PK(tenantId, businessId, 'PAYRUN'),
        GSI1SK: gsi1SK(period, period),
    };
}

/** Payslip keys. Written in the same TransactWriteCommand as its PayrollRun. */
export function buildPayslipKeys(
    tenantId: string,
    businessId: string,
    period: string,
    employeeId: string,
): EntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: payslipSK(period, employeeId),
        GSI1PK: gsi1PK(tenantId, businessId, 'PAYSLIP'),
        GSI1SK: gsi1SK(period, employeeId),
    };
}

/** SalaryComponent keys. */
export function buildSalaryComponentKeys(
    tenantId: string,
    businessId: string,
    employeeId: string,
    componentId: string,
): EntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: salaryComponentSK(employeeId, componentId),
        GSI1PK: gsi1PK(tenantId, businessId, 'SALCOMP'),
        GSI1SK: gsi1SK(employeeId, componentId),
    };
}

/**
 * StatutoryRate keys. Effective-dated items resolved at compute time.
 * GSI1 orders by kind + effectiveFrom for "latest effective rate" lookups.
 */
export function buildStatutoryRateKeys(
    tenantId: string,
    businessId: string,
    kind: 'PF' | 'ESI' | 'PT' | 'TDS',
    stateOrAll: string,
    version: number,
    effectiveFrom: string,
): EntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: statutoryRateSK(kind, stateOrAll, version),
        GSI1PK: gsi1PK(tenantId, businessId, `STATRATE#${kind}#${stateOrAll}`),
        GSI1SK: gsi1SK(effectiveFrom, `${version}`),
    };
}

/** SalaryChangeAudit keys (append-only). */
export function buildSalaryChangeAuditKeys(
    tenantId: string,
    businessId: string,
    isoTimestamp: string,
    eventId: string,
): EntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: salaryChangeAuditSK(isoTimestamp, eventId),
        GSI1PK: gsi1PK(tenantId, businessId, 'SALARYAUDIT'),
        GSI1SK: gsi1SK(isoTimestamp, eventId),
    };
}
