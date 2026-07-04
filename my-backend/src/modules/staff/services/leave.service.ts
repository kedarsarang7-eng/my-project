// ============================================================================
// Staff Module — Leave Validation & Accrual Service (Task 6.1)
// ============================================================================
// Pure, deterministic leave logic used by the leave handlers. Kept side-effect
// free so the acceptance rule (Property 12) and accrual maths can be reasoned
// about and tested in isolation from DynamoDB.
//
// PROPERTY 12 (design.md) — the single most important behaviour here:
//   "For any leave request, it is accepted IF AND ONLY IF it satisfies the
//    applicable LeaveType rules and the requested duration does not exceed the
//    available LeaveBalance; otherwise it is rejected and balances are unchanged."
//
// `validateLeaveRequest` is a PURE function: it inspects the leave type, the
// current balance and the request and returns an accept/reject decision plus the
// computed duration. It NEVER mutates the balance — so "balances unchanged"
// holds for both outcomes by construction. Balance deduction on approval is
// task 6.2 (Property 15).
//
// Requirements: 4.1 (accrual rules + balance tracking), 4.2 (validate against
// LeaveType rules AND available LeaveBalance).
// ============================================================================

import {
    AccrualRule,
    LeaveBalance,
    LeaveRequest,
    LeaveType,
} from '../schemas/leave.schema';

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** Parse a YYYY-MM-DD date to a UTC epoch (ms), or null when not parseable. */
function parseDateUtc(date: string): number | null {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return null;
    const ms = Date.parse(`${date}T00:00:00.000Z`);
    return Number.isNaN(ms) ? null : ms;
}

/**
 * Inclusive whole-day duration between two YYYY-MM-DD dates.
 * A single-day request (from === to) is 1 day. Returns null when either date is
 * invalid or `from` is after `to`.
 */
export function computeLeaveDurationDays(from: string, to: string): number | null {
    const fromMs = parseDateUtc(from);
    const toMs = parseDateUtc(to);
    if (fromMs === null || toMs === null) return null;
    if (fromMs > toMs) return null;
    return Math.round((toMs - fromMs) / MS_PER_DAY) + 1;
}

/** Whole days of notice between `now` and the request start date (can be negative). */
function computeNoticeDays(from: string, now: Date): number | null {
    const fromMs = parseDateUtc(from);
    if (fromMs === null) return null;
    // Normalise `now` to the start of its UTC day so notice is measured in whole days.
    const todayMs = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
    return Math.floor((fromMs - todayMs) / MS_PER_DAY);
}

// ── Validation result ─────────────────────────────────────────────────────────

/** Machine-readable rejection reasons (stable codes for clients/tests). */
export type LeaveRejectionCode =
    | 'LEAVE_TYPE_INACTIVE'
    | 'INVALID_DATE_RANGE'
    | 'BELOW_MIN_DURATION'
    | 'EXCEEDS_MAX_CONSECUTIVE'
    | 'INSUFFICIENT_NOTICE'
    | 'INSUFFICIENT_BALANCE';

export interface LeaveValidationResult {
    accepted: boolean;
    /** Inclusive duration in days (0 when the date range is invalid). */
    durationDays: number;
    /** Stable rejection code (only present when accepted === false). */
    code?: LeaveRejectionCode;
    /** Human-readable rejection reason (only present when accepted === false). */
    reason?: string;
}

export interface ValidateLeaveOptions {
    /** Injectable clock for deterministic notice checks (defaults to now). */
    now?: Date;
}

/**
 * Decide whether a leave request is acceptable (Property 12).
 *
 * Accepted IFF ALL hold:
 *   1. the leave type is active,
 *   2. the date range is valid (from <= to, both parseable),
 *   3. duration >= rules.minDurationDays          (when configured),
 *   4. duration <= rules.maxConsecutiveDays        (when configured),
 *   5. notice   >= rules.minNoticeDays             (when configured),
 *   6. duration <= availableBalance.
 * Otherwise the request is rejected with a specific code. This function is pure
 * and never changes the balance.
 *
 * @param leaveType        the applicable LeaveType (rules + status)
 * @param availableBalance the employee's current balance for this leave type (days)
 * @param request          the requested date range (from/to inclusive)
 */
export function validateLeaveRequest(
    leaveType: Pick<LeaveType, 'status' | 'rules'>,
    availableBalance: number,
    request: Pick<LeaveRequest, 'from' | 'to'>,
    options: ValidateLeaveOptions = {},
): LeaveValidationResult {
    // 1. Leave type must be active.
    if (leaveType.status !== 'active') {
        return {
            accepted: false,
            durationDays: 0,
            code: 'LEAVE_TYPE_INACTIVE',
            reason: 'The selected leave type is not active',
        };
    }

    // 2. Date range must be valid.
    const durationDays = computeLeaveDurationDays(request.from, request.to);
    if (durationDays === null || durationDays <= 0) {
        return {
            accepted: false,
            durationDays: 0,
            code: 'INVALID_DATE_RANGE',
            reason: '`from`/`to` must be valid dates with `from` on or before `to`',
        };
    }

    const rules = leaveType.rules ?? {};

    // 3. Minimum duration.
    if (rules.minDurationDays !== undefined && durationDays < rules.minDurationDays) {
        return {
            accepted: false,
            durationDays,
            code: 'BELOW_MIN_DURATION',
            reason: `Leave must be at least ${rules.minDurationDays} day(s)`,
        };
    }

    // 4. Maximum consecutive duration.
    if (rules.maxConsecutiveDays !== undefined && durationDays > rules.maxConsecutiveDays) {
        return {
            accepted: false,
            durationDays,
            code: 'EXCEEDS_MAX_CONSECUTIVE',
            reason: `Leave must not exceed ${rules.maxConsecutiveDays} consecutive day(s)`,
        };
    }

    // 5. Minimum notice.
    if (rules.minNoticeDays !== undefined) {
        const noticeDays = computeNoticeDays(request.from, options.now ?? new Date());
        if (noticeDays === null || noticeDays < rules.minNoticeDays) {
            return {
                accepted: false,
                durationDays,
                code: 'INSUFFICIENT_NOTICE',
                reason: `Leave requires at least ${rules.minNoticeDays} day(s) of notice`,
            };
        }
    }

    // 6. Available balance.
    if (durationDays > availableBalance) {
        return {
            accepted: false,
            durationDays,
            code: 'INSUFFICIENT_BALANCE',
            reason: `Requested ${durationDays} day(s) exceeds available balance of ${availableBalance} day(s)`,
        };
    }

    return { accepted: true, durationDays };
}

// ── Accrual (Req 4.1) ─────────────────────────────────────────────────────────

/**
 * Compute the balance after applying `periods` accrual periods to `currentBalance`.
 * Pure and deterministic:
 *   - frequency 'none'         → balance unchanged (manual balances).
 *   - amountPerPeriod * periods is added, then capped at `maxBalance` if set.
 * Negative `periods` is treated as zero (accrual never removes balance here).
 *
 * @param currentBalance the balance before this accrual run (days)
 * @param rule           the leave type's accrual rule
 * @param periods        how many whole accrual periods elapsed since last accrual
 */
export function applyAccrual(
    currentBalance: number,
    rule: AccrualRule,
    periods: number,
): number {
    if (rule.frequency === 'none') {
        return capBalance(currentBalance, rule.maxBalance);
    }
    const effectivePeriods = Math.max(0, Math.floor(periods));
    const accrued = currentBalance + rule.amountPerPeriod * effectivePeriods;
    return capBalance(accrued, rule.maxBalance);
}

/** Clamp a balance to the accrual rule's maxBalance cap when present. */
function capBalance(balance: number, maxBalance?: number): number {
    if (maxBalance !== undefined && balance > maxBalance) {
        return maxBalance;
    }
    return balance;
}

// ── Balance helpers ─────────────────────────────────────────────────────────

/** Safely read the numeric balance from a (possibly missing) LeaveBalance. */
export function readBalance(balance: LeaveBalance | null | undefined): number {
    return balance && typeof balance.balance === 'number' ? balance.balance : 0;
}
