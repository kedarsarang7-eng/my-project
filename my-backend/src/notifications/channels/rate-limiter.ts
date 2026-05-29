// ============================================================================
// Delivery_Layer — Per-User Per-Channel Rate Limiter with Coalescing
// ============================================================================
// Implements the per-user per-channel rate limit (REQ 9.5) and the
// "coalesce subsequent same-`event_name` notifications into a single
// batched summary delivered after the limit window resets" behaviour
// (REQ 9.6) used by the Delivery_Layer façade.
//
// Algorithm
// ---------
// 1. **Token bucket** — for each `(user_id, channel)` pair we maintain
//    an in-memory bucket sized at the configured limit per minute. Each
//    successful `acquire()` consumes one token; tokens refill linearly at
//    `limit_per_min / 60_000` tokens per millisecond, capped at the
//    bucket size. This gives the same "N per rolling minute" semantics
//    REQ 9.5 calls for without storing every individual delivery
//    timestamp (which would be O(N) memory per user).
//
// 2. **Coalesce-on-limit-hit** — when `acquire()` finds zero tokens, the
//    caller hands the rejected delivery to `enqueueCoalesced(...)`. The
//    rate-limiter groups by `(user_id, channel, event_name)` and
//    schedules a one-shot flush at the next window reset (the moment a
//    fresh token will be available). When the flush fires it invokes the
//    `flush` callback exactly once per group with:
//      - `count`            — number of suppressed deliveries in the window
//      - `latestArgs`       — the most recent `DispatchChannelArgs` in the
//                             group (so the summary uses the freshest payload)
//      - `firstQueuedAt`    — ISO-8601 timestamp of the FIRST suppressed
//                             delivery (useful for "X events since HH:MM"
//                             rendering)
//    The callback is responsible for the actual transport-level summary
//    delivery; this module only handles the timing and grouping.
//
// 3. **Token recovery during a queue-up window** — once the flush fires
//    and the summary is dispatched, the bucket has at least one freshly
//    refilled token. Any further deliveries in the same group during the
//    SAME minute window will queue up again exactly as before; this is
//    the steady-state "noisy producer" behaviour that REQ 9.6 wants —
//    one summary per window, not one per individual event.
//
// Footprint
// ---------
// Backed by an in-process `Map`. The Notification_System runs as a fleet
// of Lambdas, so a single bucket lives only for the lifetime of one
// container. That is acceptable for Phase 4 because:
//   - Per-channel limits are coarse (60/min for the highest), so per-
//     instance counters tracking only the tail of activity hit by THIS
//     container lose at most one window of a noisy producer when the
//     container scales up. The user has not seen those events yet —
//     they're queued in the Delivery_Layer; the next container instance
//     will see fresh deliveries with a fresh bucket and behave the same.
//   - REQ 9.5 is a noise-control policy, not a correctness invariant.
//     Notifications themselves remain durable in the Notification_Store.
// Multi-instance enforcement (DynamoDB / ElastiCache backed bucket) is
// owed by a follow-up task; the current public surface is built so the
// implementation can be swapped without changing callers.
//
// Validates: REQ 5.1-5.5 (channels), REQ 9.5 (per-channel rate limits),
//            REQ 9.6 (coalesce-on-limit-hit summary).
// ============================================================================

import { logger } from '../../utils/logger';
import type { NotificationChannel } from '../store/types';
import type { DispatchChannelArgs } from '../service/types';

// ---------------------------------------------------------------------------
// Default limits (REQ 9.5)
// ---------------------------------------------------------------------------

/**
 * Default per-user per-channel rate limits in deliveries per minute.
 * Source: REQ 9.5 / Phase 3 §9.1 channel matrix.
 */
export const DEFAULT_RATE_LIMITS_PER_MINUTE: Record<
    NotificationChannel,
    number
> = {
    in_app: 60,
    push: 20,
    email: 10,
    sms: 5,
    webhook: 60,
};

/** One-minute window size in milliseconds (REQ 9.5). */
export const RATE_LIMIT_WINDOW_MS = 60_000;

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/**
 * Outcome returned by `acquire()`.
 *
 * - `allowed`       — a token was consumed; caller dispatches normally.
 * - `rate_limited`  — no token available; caller MUST hand the args to
 *                     `enqueueCoalesced(...)` so the next-window flush
 *                     emits one summary delivery.
 */
export type RateLimitDecision =
    | {
          readonly status: 'allowed';
          readonly tokensRemaining: number;
      }
    | {
          readonly status: 'rate_limited';
          /** ISO-8601 timestamp at which the next token will be available. */
          readonly nextAvailableAt: string;
          /** Milliseconds until the next-window flush should run. */
          readonly retryAfterMs: number;
      };

/**
 * Summary handed to the flush callback after a coalesce window expires.
 */
export interface CoalescedFlush {
    readonly user_id: string;
    readonly channel: NotificationChannel;
    readonly event_name: string;
    /** Number of suppressed deliveries in the window (>= 1). */
    readonly count: number;
    /**
     * The most recent `DispatchChannelArgs` from the group. Adapters use
     * its `.notification.payload` to render a summary referring to the
     * freshest details (e.g. latest stock level on `inventory.stock.low`).
     */
    readonly latestArgs: DispatchChannelArgs;
    /** ISO-8601 timestamp of the FIRST queued delivery in the window. */
    readonly firstQueuedAt: string;
    /** ISO-8601 timestamp at which the flush actually fired. */
    readonly flushedAt: string;
}

/**
 * Callback invoked once per coalesce group when the rate-limit window
 * resets. Should perform the summary-style delivery for the channel.
 *
 * Errors thrown from the callback are logged and swallowed by the
 * scheduler — a flush failure on one group MUST NOT block other flushes.
 */
export type FlushCallback = (flush: CoalescedFlush) => Promise<void>;

/**
 * Options accepted by `createRateLimiter()`. All fields optional; unset
 * values fall back to the defaults above.
 */
export interface RateLimiterOptions {
    /**
     * Per-channel limit overrides. Any channel not present uses the
     * default from {@link DEFAULT_RATE_LIMITS_PER_MINUTE}.
     */
    readonly limitsPerMinute?: Partial<Record<NotificationChannel, number>>;
    /** Window size override (default 60_000 ms). */
    readonly windowMs?: number;
    /**
     * Time source — overridable for tests so retry scheduling is
     * deterministic. Defaults to `Date.now`.
     */
    readonly now?: () => number;
    /**
     * Schedule a function to run after `delayMs`. Returns an opaque
     * cancel handle. Defaults to a `setTimeout`-based scheduler.
     * Tests inject a virtual scheduler so flushes fire on demand.
     */
    readonly scheduler?: TimerScheduler;
}

/**
 * Minimal scheduler abstraction so unit tests can drive the flush timing
 * without real wall-clock waits.
 */
export interface TimerScheduler {
    schedule(fn: () => void, delayMs: number): TimerHandle;
}

export interface TimerHandle {
    cancel(): void;
}

// ---------------------------------------------------------------------------
// Default scheduler (real clock)
// ---------------------------------------------------------------------------

const defaultScheduler: TimerScheduler = {
    schedule(fn, delayMs) {
        const handle = setTimeout(() => {
            try {
                fn();
            } catch (err) {
                logger.warn(
                    '[rate-limiter] scheduler callback threw',
                    {
                        error: err instanceof Error ? err.message : String(err),
                    },
                );
            }
        }, Math.max(0, delayMs));
        // Don't keep the Lambda runtime alive just to flush a coalesced
        // summary — if the container is recycled the next container
        // starts with a fresh bucket, which is the expected behaviour.
        if (typeof handle === 'object' && handle !== null && 'unref' in handle) {
            try {
                (handle as { unref: () => void }).unref();
            } catch {
                /* noop */
            }
        }
        return {
            cancel(): void {
                clearTimeout(handle);
            },
        };
    },
};

// ---------------------------------------------------------------------------
// Internal state shapes
// ---------------------------------------------------------------------------

interface BucketState {
    /** Current token count (fractional, refills linearly). */
    tokens: number;
    /** Timestamp (ms) of the last token-count update. */
    lastRefillAt: number;
    /** Maximum tokens this bucket holds. */
    capacity: number;
}

interface CoalesceGroupState {
    readonly user_id: string;
    readonly channel: NotificationChannel;
    readonly event_name: string;
    count: number;
    /** ISO-8601 timestamp of the first queued delivery in the window. */
    firstQueuedAt: string;
    /** Most recent `DispatchChannelArgs` in this group. */
    latestArgs: DispatchChannelArgs;
    /** Cancel handle for the scheduled flush. */
    timer: TimerHandle | null;
    /** Wall-clock ms at which the timer is set to fire. */
    scheduledFlushAt: number;
}

// ---------------------------------------------------------------------------
// Public RateLimiter
// ---------------------------------------------------------------------------

/**
 * Per-user per-channel token-bucket rate limiter with same-`event_name`
 * coalescing on limit hit. See file-level comment for the algorithm and
 * trade-offs.
 *
 * Lifecycle: construct one instance per `DeliveryLayer`. Call `acquire()`
 * before invoking the channel adapter; on `rate_limited` outcome call
 * `enqueueCoalesced(...)` with the rejected args. Register a flush
 * callback up-front via `setFlushCallback(...)`.
 */
export class RateLimiter {
    private readonly limitsPerMinute: Record<NotificationChannel, number>;
    private readonly windowMs: number;
    private readonly now: () => number;
    private readonly scheduler: TimerScheduler;

    private readonly buckets = new Map<string, BucketState>();
    private readonly coalesceGroups = new Map<string, CoalesceGroupState>();

    private flushCallback: FlushCallback | null = null;

    constructor(options: RateLimiterOptions = {}) {
        this.limitsPerMinute = {
            ...DEFAULT_RATE_LIMITS_PER_MINUTE,
            ...(options.limitsPerMinute ?? {}),
        };
        this.windowMs = options.windowMs ?? RATE_LIMIT_WINDOW_MS;
        this.now = options.now ?? Date.now;
        this.scheduler = options.scheduler ?? defaultScheduler;
    }

    /**
     * Register the per-channel summary-delivery callback. Required before
     * any `enqueueCoalesced(...)` call can produce a summary delivery.
     */
    public setFlushCallback(cb: FlushCallback): void {
        this.flushCallback = cb;
    }

    /**
     * Resolve the configured limit for `channel` (one minute window).
     * Public so callers (tests, observability) can introspect the budget.
     */
    public getLimitPerMinute(channel: NotificationChannel): number {
        return this.limitsPerMinute[channel];
    }

    /**
     * Attempt to consume one token for `(user_id, channel)`. Returns
     * `allowed` when a token was consumed and `rate_limited` otherwise.
     *
     * The decision is final at the moment of the call — callers MUST NOT
     * retry the same `acquire()` for the same delivery; instead they
     * route the rejected args to `enqueueCoalesced(...)`.
     */
    public acquire(
        user_id: string,
        channel: NotificationChannel,
    ): RateLimitDecision {
        const bucket = this.getOrCreateBucket(user_id, channel);
        const now = this.now();

        this.refill(bucket, now);

        if (bucket.tokens >= 1) {
            bucket.tokens -= 1;
            return {
                status: 'allowed',
                tokensRemaining: Math.floor(bucket.tokens),
            };
        }

        const msUntilOneToken = this.msUntilOneToken(bucket);
        return {
            status: 'rate_limited',
            nextAvailableAt: new Date(now + msUntilOneToken).toISOString(),
            retryAfterMs: msUntilOneToken,
        };
    }

    /**
     * Queue a rejected delivery for coalesced summary at the next window
     * reset. The first call for a `(user_id, channel, event_name)` group
     * schedules the flush; subsequent calls in the SAME window only
     * update the `count` and `latestArgs`.
     *
     * REQ 9.6: "coalesce subsequent notifications of the same `event_name`
     * for that Recipient into a single batched summary delivered after
     * the limit window resets."
     */
    public enqueueCoalesced(
        args: DispatchChannelArgs,
        decision: Extract<RateLimitDecision, { status: 'rate_limited' }>,
    ): void {
        const event_name = args.notification.event_name;
        const user_id = args.recipient.user_id;
        const channel = args.channel;
        const key = this.coalesceKey(user_id, channel, event_name);

        const existing = this.coalesceGroups.get(key);
        const now = this.now();

        if (existing) {
            existing.count += 1;
            existing.latestArgs = args;
            return;
        }

        const group: CoalesceGroupState = {
            user_id,
            channel,
            event_name,
            count: 1,
            firstQueuedAt: new Date(now).toISOString(),
            latestArgs: args,
            timer: null,
            scheduledFlushAt: now + decision.retryAfterMs,
        };

        const timer = this.scheduler.schedule(() => {
            this.coalesceGroups.delete(key);
            this.fireFlush(group);
        }, decision.retryAfterMs);

        group.timer = timer;
        this.coalesceGroups.set(key, group);
    }

    /**
     * Flush every queued coalesce group immediately. Used on shutdown so
     * a Lambda recycle does not strand pending summaries.
     */
    public async drain(): Promise<void> {
        const groups = Array.from(this.coalesceGroups.values());
        this.coalesceGroups.clear();
        for (const g of groups) {
            try {
                g.timer?.cancel();
            } catch {
                /* noop */
            }
            await this.fireFlushAsync(g);
        }
    }

    /**
     * Cancel every pending coalesce flush without firing them. Used by
     * tests that want to reset state between cases.
     */
    public dispose(): void {
        for (const g of this.coalesceGroups.values()) {
            try {
                g.timer?.cancel();
            } catch {
                /* noop */
            }
        }
        this.coalesceGroups.clear();
        this.buckets.clear();
    }

    // -----------------------------------------------------------------------
    // Internals
    // -----------------------------------------------------------------------

    private getOrCreateBucket(
        user_id: string,
        channel: NotificationChannel,
    ): BucketState {
        const key = this.bucketKey(user_id, channel);
        let bucket = this.buckets.get(key);
        if (!bucket) {
            const capacity = this.getLimitPerMinute(channel);
            bucket = {
                tokens: capacity,
                lastRefillAt: this.now(),
                capacity,
            };
            this.buckets.set(key, bucket);
        }
        return bucket;
    }

    private refill(bucket: BucketState, now: number): void {
        if (bucket.capacity <= 0) return;
        const elapsed = now - bucket.lastRefillAt;
        if (elapsed <= 0) return;
        const refillRatePerMs = bucket.capacity / this.windowMs;
        const refillAmount = elapsed * refillRatePerMs;
        bucket.tokens = Math.min(
            bucket.capacity,
            bucket.tokens + refillAmount,
        );
        bucket.lastRefillAt = now;
    }

    /**
     * Compute milliseconds until the bucket holds at least 1 full token.
     * Linear refill, capped at the window size so a fully drained bucket
     * never quotes a wait longer than one window.
     */
    private msUntilOneToken(bucket: BucketState): number {
        if (bucket.capacity <= 0) return this.windowMs;
        if (bucket.tokens >= 1) return 0;
        const refillRatePerMs = bucket.capacity / this.windowMs;
        if (refillRatePerMs <= 0) return this.windowMs;
        const ms = Math.ceil((1 - bucket.tokens) / refillRatePerMs);
        return Math.min(this.windowMs, Math.max(0, ms));
    }

    private fireFlush(group: CoalesceGroupState): void {
        // Fire-and-forget so the scheduler callback returns promptly.
        void this.fireFlushAsync(group);
    }

    private async fireFlushAsync(group: CoalesceGroupState): Promise<void> {
        if (!this.flushCallback) {
            logger.warn(
                '[rate-limiter] coalesce flush fired without a flush callback',
                {
                    user_id: group.user_id,
                    channel: group.channel,
                    event_name: group.event_name,
                    count: group.count,
                },
            );
            return;
        }

        const flush: CoalescedFlush = {
            user_id: group.user_id,
            channel: group.channel,
            event_name: group.event_name,
            count: group.count,
            latestArgs: group.latestArgs,
            firstQueuedAt: group.firstQueuedAt,
            flushedAt: new Date(this.now()).toISOString(),
        };

        try {
            await this.flushCallback(flush);
        } catch (err) {
            // A flush failure must NOT block other groups; record and
            // continue. The Notification record itself remains durable
            // (the persistence path runs ahead of the channel adapter).
            logger.warn('[rate-limiter] flush callback threw', {
                user_id: group.user_id,
                channel: group.channel,
                event_name: group.event_name,
                count: group.count,
                error: err instanceof Error ? err.message : String(err),
            });
        }
    }

    private bucketKey(user_id: string, channel: NotificationChannel): string {
        return `${user_id}\u0001${channel}`;
    }

    private coalesceKey(
        user_id: string,
        channel: NotificationChannel,
        event_name: string,
    ): string {
        return `${user_id}\u0001${channel}\u0001${event_name}`;
    }
}

// ---------------------------------------------------------------------------
// Convenience factory
// ---------------------------------------------------------------------------

/**
 * Build a `RateLimiter` with the provided options, applying REQ 9.5
 * defaults for any channel not overridden by the caller.
 */
export function createRateLimiter(
    options: RateLimiterOptions = {},
): RateLimiter {
    return new RateLimiter(options);
}
