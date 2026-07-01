// ============================================================================
// Login_Throttle — per-account failed-login rate limiting and lockout
// ============================================================================
// Implements the offline login gate (Req 9.7 / 9.8) that the
// Offline_Auth_Service consults BEFORE authenticating, and updates AFTER a
// failed attempt:
//
//   • Req 9.7 — once an account accumulates 5 failed attempts within a trailing
//     15-minute window, every further attempt for that account is rejected for
//     60 seconds with a "temporarily rate limited" indication.
//   • Req 9.8 — once an account accumulates 10 failed attempts within a trailing
//     30-minute window, the account is locked for 30 minutes; every attempt
//     during the lock is rejected with an "account is locked" indication, and
//     attempts are permitted again after the 30-minute window elapses.
//
// Design notes:
//   • In-memory state is acceptable for the loopback single-process backend.
//     The store is a plain Map keyed by the normalised login identifier.
//   • The component is a PURE data structure with respect to time: every method
//     takes the current time (`nowMs`) as an argument rather than reading the
//     clock itself, so the 15-min / 60-sec / 30-min windows are deterministic
//     and fully testable. The Offline_Auth_Service owns the injectable clock
//     and feeds it in.
//   • A successful login is expected to call `reset(account)` so the failure
//     history and any cooldown/lock are cleared.
// ============================================================================

// -- Policy constants (Req 9.7 / 9.8) ----------------------------------------

/** Failures within RATE_LIMIT_WINDOW that trigger the 60-second cooldown (Req 9.7). */
export const RATE_LIMIT_THRESHOLD = 5;
/** Trailing window over which rate-limit failures are counted: 15 minutes (Req 9.7). */
export const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
/** Duration further attempts are rejected once rate-limited: 60 seconds (Req 9.7). */
export const RATE_LIMIT_COOLDOWN_MS = 60 * 1000;

/** Failures within LOCK_WINDOW that lock the account (Req 9.8). */
export const LOCK_THRESHOLD = 10;
/** Trailing window over which lockout failures are counted: 30 minutes (Req 9.8). */
export const LOCK_WINDOW_MS = 30 * 60 * 1000;
/** Duration an account stays locked once triggered: 30 minutes (Req 9.8). */
export const LOCK_DURATION_MS = 30 * 60 * 1000;

/** The longest window we must retain failure timestamps for. */
const MAX_RETAINED_WINDOW_MS = Math.max(RATE_LIMIT_WINDOW_MS, LOCK_WINDOW_MS);

// -- Public result types -----------------------------------------------------

/** The gate decision returned by {@link LoginThrottle.check}. */
export type ThrottleDecision =
    | { state: 'allowed' }
    | { state: 'rate_limited'; retryAfterSeconds: number }
    | { state: 'locked'; retryAfterSeconds: number };

// -- Internal per-account state ----------------------------------------------

interface AccountState {
    /** Timestamps (ms since epoch) of failed attempts within the retained window. */
    failures: number[];
    /** Epoch-ms until which the account is rate limited (Req 9.7); 0 when none. */
    rateLimitedUntil: number;
    /** Epoch-ms until which the account is locked (Req 9.8); 0 when none. */
    lockedUntil: number;
}

// -- Service -----------------------------------------------------------------

/**
 * Tracks failed-login history per account and decides whether a login attempt
 * is currently allowed, rate limited, or locked. All time is supplied by the
 * caller so the component is deterministic and testable.
 */
export class LoginThrottle {
    private readonly accounts = new Map<string, AccountState>();

    /**
     * Decide whether an attempt for `account` is allowed right now.
     *
     * Lock (Req 9.8) takes precedence over rate limiting (Req 9.7): if both are
     * active the caller is told the account is locked. When neither is active
     * the attempt is allowed.
     */
    check(account: string, nowMs: number): ThrottleDecision {
        const entry = this.accounts.get(account);
        if (!entry) return { state: 'allowed' };

        this.prune(entry, nowMs);

        if (nowMs < entry.lockedUntil) {
            return { state: 'locked', retryAfterSeconds: msToCeilSeconds(entry.lockedUntil - nowMs) };
        }
        if (nowMs < entry.rateLimitedUntil) {
            return {
                state: 'rate_limited',
                retryAfterSeconds: msToCeilSeconds(entry.rateLimitedUntil - nowMs),
            };
        }

        // Nothing active and no retained failures → drop the entry to bound memory.
        if (entry.failures.length === 0) {
            this.accounts.delete(account);
        }
        return { state: 'allowed' };
    }

    /**
     * Record a failed login attempt for `account` at `nowMs`, then re-evaluate
     * the thresholds. Crossing the lock threshold (Req 9.8) starts/extends a
     * 30-minute lock; crossing the rate-limit threshold (Req 9.7) starts/extends
     * a 60-second cooldown.
     */
    recordFailure(account: string, nowMs: number): void {
        const entry = this.accounts.get(account) ?? {
            failures: [],
            rateLimitedUntil: 0,
            lockedUntil: 0,
        };

        entry.failures.push(nowMs);
        this.prune(entry, nowMs);

        const failuresInLockWindow = entry.failures.filter((t) => t > nowMs - LOCK_WINDOW_MS).length;
        if (failuresInLockWindow >= LOCK_THRESHOLD) {
            entry.lockedUntil = Math.max(entry.lockedUntil, nowMs + LOCK_DURATION_MS);
        }

        const failuresInRateWindow = entry.failures.filter((t) => t > nowMs - RATE_LIMIT_WINDOW_MS).length;
        if (failuresInRateWindow >= RATE_LIMIT_THRESHOLD) {
            entry.rateLimitedUntil = Math.max(entry.rateLimitedUntil, nowMs + RATE_LIMIT_COOLDOWN_MS);
        }

        this.accounts.set(account, entry);
    }

    /**
     * Clear all failure history and any active cooldown/lock for `account`.
     * Called after a successful authentication so a good login resets the gate.
     */
    reset(account: string): void {
        this.accounts.delete(account);
    }

    /**
     * Drop failure timestamps older than the longest tracked window. Active
     * `rateLimitedUntil` / `lockedUntil` deadlines are NOT cleared here — they
     * persist until they elapse even after their originating failures age out,
     * which is what keeps an account locked for the full 30 minutes (Req 9.8).
     */
    private prune(entry: AccountState, nowMs: number): void {
        const cutoff = nowMs - MAX_RETAINED_WINDOW_MS;
        if (entry.failures.length > 0 && entry.failures[0] <= cutoff) {
            entry.failures = entry.failures.filter((t) => t > cutoff);
        }
    }
}

/** Convert a positive millisecond duration to whole seconds, rounding up. */
function msToCeilSeconds(ms: number): number {
    return Math.max(1, Math.ceil(ms / 1000));
}
