// ============================================================================
// UNS Event_Bus — Per-Producer Publish Rate Limiter
// ============================================================================
// Implements REQ 12.4: per-Producer rate limit applied at the publish endpoint
// to prevent abusive event flooding. Default 1000 events/minute per Producer,
// configurable. Evaluated independently of, and prior to, authorization.
//
// Algorithm: token bucket per Producer.
//   - Capacity = configured limit (default 1000).
//   - Refill rate = capacity / window (default 1000 tokens per 60_000 ms,
//     i.e. ~16.67 tokens/sec).
//   - Refill is continuous: every `consume(...)` call first tops the bucket
//     up by the elapsed-time fraction since the last touch, then attempts to
//     subtract one token. This naturally handles "time-window rolls over"
//     without an explicit window-reset branch.
//   - State is per-instance, in-memory. That matches the existing
//     `websocket.service.ts` per-business rate-limiter pattern in this
//     backend. Lambdas keeping warm containers will share state across
//     invocations within the container; cold starts reset, which is the
//     conservative direction for a flood-prevention control.
//
// Producer identity: we key the buckets by the candidate event's
// `source_module` (canonical workspace path of the emitting module — see
// `EventContract.source_module`). It is the stablest per-Producer label
// the envelope provides; `source_app` is too coarse (six values total) and
// `actor_id` is per-user, not per-Producer. Malformed payloads with no
// `source_module` are bucketed under a sentinel so floods of garbage
// publishes are still throttled.
//
// Validates: REQ 12.4 (per-Producer rate limit, default 1000/min,
//            configurable, evaluated before authorization).
// ============================================================================

import { logger } from '../../utils/logger';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/** Env var: events allowed per window per Producer. Default 1000. */
const ENV_LIMIT = 'UNS_PUBLISH_RATE_LIMIT_PER_MIN';
/** Env var: rolling window in milliseconds. Default 60_000 (one minute). */
const ENV_WINDOW_MS = 'UNS_PUBLISH_RATE_WINDOW_MS';

const DEFAULT_LIMIT = 1000;
const DEFAULT_WINDOW_MS = 60_000;

/** Bucket label used when a publish attempt arrives without a source_module. */
export const UNKNOWN_PRODUCER_ID = '__unknown_producer__';

/** Public configuration shape. */
export interface RateLimiterConfig {
    /** Maximum tokens (events) per Producer per window. Must be > 0. */
    readonly limit: number;
    /** Window length in milliseconds. Must be > 0. */
    readonly windowMs: number;
}

function readPositiveInt(envName: string, fallback: number): number {
    const raw = process.env[envName];
    if (!raw || raw.trim().length === 0) return fallback;
    const parsed = Number.parseInt(raw, 10);
    if (!Number.isFinite(parsed) || parsed <= 0) {
        logger.warn('[EventBus] Invalid rate-limit env value — falling back to default', {
            envName,
            rawValue: raw,
            fallback,
        });
        return fallback;
    }
    return parsed;
}

/** Read configuration from env at instantiation time. */
export function readRateLimiterConfig(): RateLimiterConfig {
    return Object.freeze({
        limit: readPositiveInt(ENV_LIMIT, DEFAULT_LIMIT),
        windowMs: readPositiveInt(ENV_WINDOW_MS, DEFAULT_WINDOW_MS),
    });
}

// ---------------------------------------------------------------------------
// Rate-limit decision shape
// ---------------------------------------------------------------------------

export interface RateLimitDecision {
    /** True when the publish is allowed; false when the bucket is empty. */
    readonly allowed: boolean;
    /** Tokens left in the bucket after the consume attempt (>= 0). */
    readonly remaining: number;
    /** Configured limit for the producer (constant per limiter instance). */
    readonly limit: number;
    /** Window length in milliseconds. */
    readonly windowMs: number;
    /**
     * Suggested cool-off in milliseconds before another attempt would refill
     * one full token. Only meaningful when `allowed === false`.
     */
    readonly retryAfterMs: number;
    /** Producer identifier this decision applies to. */
    readonly producerId: string;
}

// ---------------------------------------------------------------------------
// ProducerRateLimiter
// ---------------------------------------------------------------------------

interface BucketState {
    /** Current tokens in the bucket (real-valued — refill is continuous). */
    tokens: number;
    /** Last time (ms since epoch) the bucket was touched. */
    lastRefillMs: number;
}

/**
 * Token-bucket rate limiter keyed by an arbitrary Producer identifier
 * (typically the event's `source_module`).
 *
 * The instance is safe to reuse across many publishes within one process.
 * Buckets that have not been touched for `2 * windowMs` are evicted on the
 * next access to keep memory bounded under churning Producer ids.
 */
export class ProducerRateLimiter {
    private readonly buckets = new Map<string, BucketState>();
    private readonly limit: number;
    private readonly windowMs: number;
    private readonly refillPerMs: number;
    private readonly clock: () => number;

    constructor(
        configOverride?: Partial<RateLimiterConfig>,
        clock: () => number = Date.now,
    ) {
        const env = readRateLimiterConfig();
        const limit = configOverride?.limit ?? env.limit;
        const windowMs = configOverride?.windowMs ?? env.windowMs;

        if (!Number.isFinite(limit) || limit <= 0) {
            throw new Error('[EventBus] ProducerRateLimiter: limit must be > 0');
        }
        if (!Number.isFinite(windowMs) || windowMs <= 0) {
            throw new Error('[EventBus] ProducerRateLimiter: windowMs must be > 0');
        }

        this.limit = limit;
        this.windowMs = windowMs;
        this.refillPerMs = limit / windowMs;
        this.clock = clock;
    }

    /** Configured capacity (tokens per window per Producer). */
    public getLimit(): number {
        return this.limit;
    }

    /** Configured window length in milliseconds. */
    public getWindowMs(): number {
        return this.windowMs;
    }

    /**
     * Attempt to charge one event against the Producer's bucket.
     * Always touches the bucket so the per-Producer accounting reflects the
     * attempt regardless of subsequent authorization outcome (REQ 12.4).
     */
    public consume(producerId: string): RateLimitDecision {
        const id = (producerId && producerId.trim().length > 0)
            ? producerId
            : UNKNOWN_PRODUCER_ID;
        const now = this.clock();

        // Lazy memory hygiene: reap stale buckets so a long-running Lambda
        // container does not accumulate one bucket per ephemeral Producer id.
        this.evictStaleBuckets(now);

        const bucket = this.buckets.get(id) ?? this.newBucket(now);
        this.refill(bucket, now);

        if (bucket.tokens >= 1) {
            bucket.tokens -= 1;
            this.buckets.set(id, bucket);
            return Object.freeze({
                allowed: true,
                remaining: Math.floor(bucket.tokens),
                limit: this.limit,
                windowMs: this.windowMs,
                retryAfterMs: 0,
                producerId: id,
            });
        }

        // Bucket empty: persist updated lastRefillMs so subsequent calls
        // continue refilling from the same baseline.
        this.buckets.set(id, bucket);
        const deficit = 1 - bucket.tokens;
        const retryAfterMs = Math.max(1, Math.ceil(deficit / this.refillPerMs));
        return Object.freeze({
            allowed: false,
            remaining: 0,
            limit: this.limit,
            windowMs: this.windowMs,
            retryAfterMs,
            producerId: id,
        });
    }

    /** Test/inspection hook: snapshot the current bucket count for a producer. */
    public peek(producerId: string): { tokens: number; lastRefillMs: number } | undefined {
        const bucket = this.buckets.get(producerId);
        if (!bucket) return undefined;
        return { tokens: bucket.tokens, lastRefillMs: bucket.lastRefillMs };
    }

    /** Test hook: clear all bucket state. */
    public reset(): void {
        this.buckets.clear();
    }

    // -- internals -----------------------------------------------------------

    private newBucket(now: number): BucketState {
        return { tokens: this.limit, lastRefillMs: now };
    }

    private refill(bucket: BucketState, now: number): void {
        if (now <= bucket.lastRefillMs) {
            // Clock skew or identical timestamp: no refill but never go backwards.
            bucket.lastRefillMs = bucket.lastRefillMs;
            return;
        }
        const elapsed = now - bucket.lastRefillMs;
        const refillAmount = elapsed * this.refillPerMs;
        // Cap at `limit` so an idle Producer cannot accumulate beyond one
        // window's worth of tokens — otherwise a Producer that goes silent
        // for an hour could burst-publish 60× the configured rate the moment
        // it returns, defeating REQ 12.4.
        bucket.tokens = Math.min(this.limit, bucket.tokens + refillAmount);
        bucket.lastRefillMs = now;
    }

    private evictStaleBuckets(now: number): void {
        // Two windows of inactivity is enough to know the bucket has refilled
        // to capacity and contributes nothing to throttling decisions.
        // Evicting earlier (one window) would risk discarding a Producer that
        // is publishing exactly at the limit and momentarily idle between
        // bursts; later (more than two) wastes memory in long-running
        // containers.
        const ttl = this.windowMs * 2;
        for (const [id, bucket] of this.buckets) {
            if (now - bucket.lastRefillMs > ttl) {
                this.buckets.delete(id);
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Shared singleton (lazy)
// ---------------------------------------------------------------------------
// The publisher consults this single instance per Lambda container. Tests can
// swap it out via `_setSharedRateLimiterForTests` to control timing precisely.

let sharedLimiter: ProducerRateLimiter | null = null;

export function getSharedRateLimiter(): ProducerRateLimiter {
    if (!sharedLimiter) {
        sharedLimiter = new ProducerRateLimiter();
    }
    return sharedLimiter;
}

/** Test-only hook — replaces the shared rate limiter for unit tests. */
export function _setSharedRateLimiterForTests(limiter: ProducerRateLimiter | null): void {
    sharedLimiter = limiter;
}
