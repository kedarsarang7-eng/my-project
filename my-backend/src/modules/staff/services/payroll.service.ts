// ============================================================================
// Staff Module — Payroll Service (Tasks 9.2 + 9.3)
// ============================================================================
// Online-only payroll engine. Responsibilities:
//
//   1. Single-writer lock acquisition (Task 9.3, Req 6.5, 6.6):
//      A PayrollRun is created via a conditional PutItem with
//      `attribute_not_exists(SK)` on the run item keyed by
//      (tenant, business, period). If the item already exists a second
//      writer is attempting the same run — we throw PAYROLL_LOCKED (409).
//
//   2. Payslip computation (Task 9.2, Req 6.1):
//      Pure `computePayslip` function supporting all component types:
//      monthly/hourly/daily/weekly/commission/bonus/incentive/loan/advance.
//
//   3. Atomic payroll transaction (Task 9.2, Req 1.4):
//      The PayrollRun + all generated Payslips are persisted atomically
//      via a single `TransactWriteCommand`. If any write fails the entire
//      transaction rolls back — no partial payslips.
//
//   4. Online-only guard (Task 9.3, Req 6.5):
//      This service runs in a Lambda context which implies connectivity.
//      The handler explicitly documents that payroll processing requires
//      an active network connection. Offline payslip viewing (Req 6.7) is
//      a frontend/sync concern — the backend does NOT lock or process
//      while offline.
//
// Requirements: 1.4, 6.1, 6.5, 6.6, 6.7
// ============================================================================

import { randomUUID } from 'crypto';
import {
    putItem,
    getItem,
    transactWrite,
    TABLE_NAME,
} from '../../../config/dynamodb.config';
import { AppError } from '../../../utils/errors';
import { logger } from '../../../utils/logger';
import {
    buildPayrollRunKeys,
    buildPayslipKeys,
    payrollRunSK,
} from '../repositories/payroll.keys';
import { businessPK } from '../../../dynamodb/keys';
import type {
    PayrollRun,
    PayrollRunStatus,
    Payslip,
    SalaryComponent,
    StatutoryRate,
} from '../schemas/payroll.schema';

// ── Error codes ─────────────────────────────────────────────────────────────

/** Thrown when a second concurrent payroll run is attempted for the same scope. */
export const PAYROLL_LOCKED_CODE = 'PAYROLL_LOCKED';

/** Thrown when payroll processing is attempted without online connectivity. */
export const PAYROLL_OFFLINE_CODE = 'PAYROLL_OFFLINE';

// ── Types ───────────────────────────────────────────────────────────────────

/** Input for computing a single payslip (Task 9.2). */
export interface ComputePayslipInput {
    employeeId: string;
    period: string;
    components: SalaryComponent[];
    /** Applicable statutory rates resolved from the Statutory_Rate_Table. */
    statutoryRates: {
        pf?: StatutoryRate;
        esi?: StatutoryRate;
        pt?: StatutoryRate;
        tds?: StatutoryRate;
    };
}

/** The result of a payslip computation (pure, no side effects). */
export interface ComputedPayslip {
    employeeId: string;
    period: string;
    grossPaise: number;
    netPaise: number;
    earnings: Record<string, number>;
    deductions: Record<string, number>;
}

/** Input for processing an entire payroll run. */
export interface ProcessPayrollInput {
    tenantId: string;
    businessId: string;
    period: string;
    lockOwner: string;
    employees: ComputePayslipInput[];
}

/** Result of a payroll run processing. */
export interface PayrollRunResult {
    payrollRun: PayrollRun;
    payslips: Payslip[];
}

// ── Pure computation (Task 9.2) ─────────────────────────────────────────────

/**
 * Compute a single payslip from salary components and statutory rates.
 *
 * This is a **pure function** — no I/O, no side effects, fully deterministic.
 * Supports: monthly, hourly, daily, weekly, commission, bonus, incentive, loan, advance.
 * Money is always integer paise.
 *
 * Loan and advance are treated as deductions (reduce net pay).
 */
export function computePayslip(input: ComputePayslipInput): ComputedPayslip {
    const earnings: Record<string, number> = {};
    const deductions: Record<string, number> = {};
    let grossPaise = 0;

    // Compute earnings from salary components
    for (const comp of input.components) {
        const amount = Math.round(comp.amountPaise);
        if (comp.type === 'loan' || comp.type === 'advance') {
            // Loans and advances reduce net pay (they are deductions)
            deductions[`${comp.type}_${comp.id}`] = amount;
        } else {
            // All other types are earnings
            earnings[`${comp.type}_${comp.id}`] = amount;
            grossPaise += amount;
        }
    }

    // Compute statutory deductions from the Statutory_Rate_Table (Req 6.2–6.4)
    const { pf, esi, pt, tds } = input.statutoryRates;

    if (pf) {
        const pfAmount = Math.round(grossPaise * pf.rate);
        deductions['PF'] = pfAmount;
    }

    if (esi) {
        const esiAmount = Math.round(grossPaise * esi.rate);
        deductions['ESI'] = esiAmount;
    }

    if (pt) {
        // PT is a flat rate (state-specific) — stored as paise amount in rate field
        const ptAmount = Math.round(pt.rate);
        deductions['PT'] = ptAmount;
    }

    if (tds) {
        const tdsAmount = Math.round(grossPaise * tds.rate);
        deductions['TDS'] = tdsAmount;
    }

    // Total deductions
    const totalDeductions = Object.values(deductions).reduce((sum, d) => sum + d, 0);
    const netPaise = Math.max(0, grossPaise - totalDeductions);

    return {
        employeeId: input.employeeId,
        period: input.period,
        grossPaise,
        netPaise,
        earnings,
        deductions,
    };
}

// ── Single-writer lock (Task 9.3) ──────────────────────────────────────────

/**
 * Acquire the single-writer payroll lock for the given scope.
 *
 * The lock is implemented as a conditional PutItem with
 * `attribute_not_exists(SK)` on the PayrollRun item. If the item already
 * exists (i.e., another run is in progress or has completed), the
 * ConditionalCheckFailedException is caught and re-thrown as PAYROLL_LOCKED.
 *
 * Online-only: This function runs in a Lambda invocation which guarantees
 * network connectivity. Offline devices cannot invoke this code path.
 *
 * @throws AppError with code PAYROLL_LOCKED (409) if the lock is already held.
 */
export async function acquirePayrollLock(
    tenantId: string,
    businessId: string,
    period: string,
    lockOwner: string,
): Promise<PayrollRun> {
    const id = randomUUID();
    const now = new Date().toISOString();
    const keys = buildPayrollRunKeys(tenantId, businessId, period);

    const payrollRun: PayrollRun = {
        id,
        tenantId,
        businessId,
        period,
        status: 'locked',
        lockOwner,
        lockedAt: now,
        createdAt: now,
        updatedAt: now,
    };

    const item: Record<string, unknown> = {
        PK: keys.PK,
        SK: keys.SK,
        GSI1PK: keys.GSI1PK,
        GSI1SK: keys.GSI1SK,
        entityType: 'STAFF_PAYRUN',
        ...payrollRun,
        isDeleted: false,
    };

    try {
        // Conditional write: fails if the SK already exists (single-writer lock).
        await putItem(item, 'attribute_not_exists(SK)');

        logger.info('Payroll lock acquired', {
            tenantId,
            businessId,
            period,
            lockOwner,
            payrollRunId: id,
        });

        return payrollRun;
    } catch (err: any) {
        if (err.name === 'ConditionalCheckFailedException') {
            logger.warn('Payroll lock rejected — concurrent run exists', {
                tenantId,
                businessId,
                period,
                lockOwner,
            });
            throw new AppError(
                `A payroll run for period ${period} is already in progress or completed for this business. Only one run per scope is permitted.`,
                409,
                PAYROLL_LOCKED_CODE,
            );
        }
        throw err;
    }
}

/**
 * Check if a payroll run already exists for the given scope.
 * Used by handlers to provide early feedback before starting computation.
 */
export async function getExistingPayrollRun(
    tenantId: string,
    businessId: string,
    period: string,
): Promise<PayrollRun | null> {
    const pk = businessPK(tenantId, businessId);
    const sk = payrollRunSK(period);
    const item = await getItem<Record<string, unknown>>(pk, sk);
    if (!item || (item as any).isDeleted) return null;
    return item as unknown as PayrollRun;
}

// ── Atomic payroll transaction (Tasks 9.2 + 9.3) ───────────────────────────

/**
 * Process a full payroll run: acquire lock, compute payslips, persist atomically.
 *
 * Flow:
 *  1. Acquire the single-writer lock (conditional PutItem — Req 6.5, 6.6).
 *  2. Compute all payslips (pure function — Req 6.1).
 *  3. Persist the run status update + all payslips in one TransactWriteCommand
 *     (ACID atomicity — Req 1.4). If any item fails, the ENTIRE transaction
 *     is rolled back — no partial payslips.
 *
 * Online-only: This MUST be invoked from an online Lambda. The handler layer
 * documents this constraint (Req 6.5). Offline payslip viewing (Req 6.7) is
 * served from the frontend's last synced cache and does NOT invoke this path.
 *
 * @throws AppError PAYROLL_LOCKED (409) if another run is active for the scope.
 * @throws Error on transaction failure (entire batch rolls back).
 */
export async function processPayrollRun(
    input: ProcessPayrollInput,
): Promise<PayrollRunResult> {
    const { tenantId, businessId, period, lockOwner, employees } = input;

    // Step 1: Acquire the single-writer lock
    const payrollRun = await acquirePayrollLock(tenantId, businessId, period, lockOwner);

    // Step 2: Compute all payslips (pure, deterministic)
    const computedPayslips = employees.map((emp) => computePayslip(emp));

    // Step 3: Build the atomic TransactWriteCommand
    const now = new Date().toISOString();
    const payslips: Payslip[] = [];
    const transactItems: any[] = [];

    // Update the payroll run status to 'processed'
    const runKeys = buildPayrollRunKeys(tenantId, businessId, period);
    transactItems.push({
        Update: {
            TableName: TABLE_NAME,
            Key: { PK: runKeys.PK, SK: runKeys.SK },
            UpdateExpression: 'SET #status = :processed, updatedAt = :now',
            ExpressionAttributeNames: { '#status': 'status' },
            ExpressionAttributeValues: {
                ':processed': 'processed',
                ':now': now,
                ':locked': 'locked',
            },
            ConditionExpression: 'attribute_exists(SK) AND #status = :locked',
        },
    });

    // Create each payslip item in the same transaction
    for (const computed of computedPayslips) {
        const payslipId = randomUUID();
        const payslipKeys = buildPayslipKeys(
            tenantId,
            businessId,
            period,
            computed.employeeId,
        );

        const payslip: Payslip = {
            id: payslipId,
            businessId,
            payrollRunId: payrollRun.id,
            employeeId: computed.employeeId,
            period,
            grossPaise: computed.grossPaise,
            netPaise: computed.netPaise,
            deductions: computed.deductions,
            earnings: computed.earnings,
            createdAt: now,
        };

        payslips.push(payslip);

        transactItems.push({
            Put: {
                TableName: TABLE_NAME,
                Item: {
                    PK: payslipKeys.PK,
                    SK: payslipKeys.SK,
                    GSI1PK: payslipKeys.GSI1PK,
                    GSI1SK: payslipKeys.GSI1SK,
                    entityType: 'STAFF_PAYSLIP',
                    tenantId,
                    ...payslip,
                    isDeleted: false,
                    updatedAt: now,
                },
            },
        });
    }

    try {
        await transactWrite(transactItems);

        // Update the in-memory run status
        payrollRun.status = 'processed';
        payrollRun.updatedAt = now;

        logger.info('Payroll run processed successfully', {
            tenantId,
            businessId,
            period,
            payrollRunId: payrollRun.id,
            payslipCount: payslips.length,
        });

        return { payrollRun, payslips };
    } catch (err: any) {
        // On transaction failure, mark the run as failed
        logger.error('Payroll transaction failed — atomic rollback', {
            tenantId,
            businessId,
            period,
            payrollRunId: payrollRun.id,
            error: err.message,
        });

        // Attempt to mark the run as failed (best-effort)
        try {
            const failedRunKeys = buildPayrollRunKeys(tenantId, businessId, period);
            // Overwrite the locked run item with a 'failed' status
            await putItem({
                PK: failedRunKeys.PK,
                SK: failedRunKeys.SK,
                GSI1PK: failedRunKeys.GSI1PK,
                GSI1SK: failedRunKeys.GSI1SK,
                entityType: 'STAFF_PAYRUN',
                id: payrollRun.id,
                tenantId,
                businessId,
                period,
                status: 'failed' as PayrollRunStatus,
                lockOwner,
                lockedAt: payrollRun.lockedAt,
                createdAt: payrollRun.createdAt,
                updatedAt: new Date().toISOString(),
                isDeleted: false,
            });
        } catch (markErr) {
            logger.error('Failed to mark payroll run as failed', {
                payrollRunId: payrollRun.id,
                error: (markErr as Error).message,
            });
        }

        throw err;
    }
}
