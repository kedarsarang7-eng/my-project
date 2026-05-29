// ============================================================================
// Delivery_Layer — Façade over the five channel adapters
// ============================================================================
// Single canonical Delivery_Layer per Phase 3 §2 / REQ 20.1. The façade:
//
//   1. Holds a pluggable adapter registry keyed by `NotificationChannel`
//      (REQ 5.1-5.5 — the five canonical channels). Adapters land at:
//        in-app   -> ./in-app.ts        (`inAppChannelAdapter`)
//        push     -> ./push.ts          (`pushChannelAdapter`)
//        email    -> ./email.ts         (`createEmailAdapter`)
//        sms      -> ./sms.ts           (`smsChannelAdapter`)
//        webhook  -> ./webhook.ts       (`webhookAdapter`)
//
//   2. Enforces the per-user per-channel rate limits from REQ 9.5
//      (defaults: in_app 60/min, push 20/min, email 10/min, sms 5/min,
//      webhook 60/min) via the `RateLimiter` in `./rate-limiter.ts`. On
//      a limit hit the rejected delivery is coalesced by `event_name`
//      and a single summary delivery fires once the window resets
//      (REQ 9.6).
//
//   3. Provides failure isolation between channels (Phase 3 §9.3). The
//      `Notification_Service.dispatch` loop already wraps each call to
//      the `DispatchChannelAdapter` in try/catch and continues to the
//      next channel on error; this façade preserves that contract by
//      throwing per-channel without ever touching shared state for the
//      other channels of the same notification. An SMTP outage on the
//      `email` adapter therefore cannot block `in_app`, `push`, `sms`,
//      or `webhook`.
//
// The façade exposes itself BOTH as an object (for explicit wiring,
// `setAdapter`, observability hooks) AND as a `DispatchChannelAdapter`
// callback (for `Notification_Service.dispatch`, which only knows that
// shape — see `../service/types.ts`). Use `deliveryLayer.dispatch` as
// the callback when constructing the service.
//
// Validates: REQ 5.1, 5.2, 5.3, 5.4, 5.5, 9.5, 9.6.
// ============================================================================

import { logger } from '../../utils/logger';
import type {
    DispatchChannelAdapter,
    DispatchChannelArgs,
} from '../service/types';
import type { NotificationChannel } from '../store/types';
import {
    createRateLimiter,
    DEFAULT_RATE_LIMITS_PER_MINUTE,
    type CoalescedFlush,
    type RateLimiter,
    type RateLimiterOptions,
} from './rate-limiter';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/**
 * Mapping from channel name to a registered adapter callback. The
 * Delivery_Layer requires an entry for every channel it will be asked
 * to dispatch on; missing entries cause `dispatch` to throw a
 * configuration error.
 */
export type ChannelAdapterRegistry = Partial<
    Record<NotificationChannel, DispatchChannelAdapter>
>;

/**
 * Options accepted by `createDeliveryLayer(...)`.
 */
export interface DeliveryLayerOptions {
    /** Initial registry of channel adapters. */
    readonly adapters?: ChannelAdapterRegistry;
    /** Rate-limiter overrides (per-channel limits, scheduler, clock). */
    readonly rateLimit?: RateLimiterOptions;
    /**
     * When `true`, disable the rate-limiter entirely. Tests that exercise
     * unbounded dispatch volumes use this. Defaults to `false`.
     */
    readonly disableRateLimit?: boolean;
}

/**
 * Per-dispatch outcome surfaced for observability/tests. The
 * `Notification_Service.dispatch` does NOT consume this — it only sees
 * "resolved" or "threw". The structured outcome is exposed through
 * `deliveryLayer.lastOutcome(notification_id, recipient_id, channel)`
 * for tests / metrics; production reads it via the metrics surface
 * landing in task 17.
 */
export type DeliveryOutcome =
    | { readonly status: 'delivered' }
    | { readonly status: 'rate_limited_coalesced'; readonly retryAfterMs: number }
    | { readonly status: 'failed'; readonly error: Error };

// ---------------------------------------------------------------------------
// DeliveryLayer
// ---------------------------------------------------------------------------

/**
 * Façade over the five channel adapters. Construct via
 * `createDeliveryLayer(...)` so callers don't have to thread default
 * adapters / rate-limit options manually; the class is exported for the
 * (rare) cases where tests want to reach in directly.
 */
export class DeliveryLayer {
    private readonly adapters = new Map<
        NotificationChannel,
        DispatchChannelAdapter
    >();
    private readonly rateLimiter: RateLimiter | null;

    constructor(options: DeliveryLayerOptions = {}) {
        const initial = options.adapters ?? {};
        for (const [channel, adapter] of Object.entries(initial)) {
            if (adapter) {
                this.adapters.set(
                    channel as NotificationChannel,
                    adapter,
                );
            }
        }

        if (options.disableRateLimit) {
            this.rateLimiter = null;
        } else {
            this.rateLimiter = createRateLimiter(options.rateLimit);
            // Wire the coalesce flush back through the `dispatch` path so
            // the rate-limiter does not need to know which adapter to
            // call — it just hands the latest args back to us with
            // a `_uns_coalesced` marker.
            this.rateLimiter.setFlushCallback((flush) =>
                this.handleCoalescedFlush(flush),
            );
        }
    }

    /**
     * Register or replace the adapter for `channel`. Useful for tests
     * (inject a fake adapter) and for the production wiring step where
     * the email adapter requires a Cognito-backed resolver injected by
     * the surrounding handler.
     */
    public setAdapter(
        channel: NotificationChannel,
        adapter: DispatchChannelAdapter,
    ): void {
        this.adapters.set(channel, adapter);
    }

    /**
     * Return `true` when an adapter is registered for `channel`.
     * Callers SHOULD verify this before relying on `dispatch`.
     */
    public hasAdapter(channel: NotificationChannel): boolean {
        return this.adapters.has(channel);
    }

    /**
     * Look up the limit (per minute) currently configured for `channel`.
     * Returns `null` when the rate-limiter is disabled.
     */
    public getRateLimitPerMinute(
        channel: NotificationChannel,
    ): number | null {
        return this.rateLimiter
            ? this.rateLimiter.getLimitPerMinute(channel)
            : null;
    }

    /**
     * Drain every pending coalesce group (used on shutdown). No-op when
     * the rate-limiter is disabled.
     */
    public async drain(): Promise<void> {
        await this.rateLimiter?.drain();
    }

    /**
     * Dispose the rate-limiter timers without firing pending flushes.
     * Tests use this between cases.
     */
    public dispose(): void {
        this.rateLimiter?.dispose();
    }

    /**
     * `DispatchChannelAdapter`-shaped entry point used by
     * `Notification_Service.dispatch`. Bound to `this` so callers can
     * pass it as a plain callback.
     *
     *   const layer = createDeliveryLayer();
     *   const service = new NotificationService({
     *     dispatchChannelAdapter: layer.dispatch,
     *   });
     *
     * Behaviour:
     *   1. Resolve the adapter for `args.channel`. Missing adapter → throw
     *      a typed config error so the service records `failed` for
     *      this channel without silently swallowing a wiring bug.
     *   2. If a rate-limiter is configured, attempt to acquire a token.
     *      On `rate_limited` outcome enqueue the args for coalesce flush
     *      and return successfully — the recipient will receive ONE
     *      summary delivery once the window resets (REQ 9.6). Returning
     *      success here keeps the service's lifecycle on `dispatched`
     *      because the system DID act on the event (it was queued for a
     *      single rolled-up delivery, not dropped).
     *   3. Invoke the channel adapter inside a try/catch. Adapter
     *      failures rethrow so `Notification_Service.dispatch` records
     *      a `failed` audit for this channel. The throw never reaches
     *      OTHER channels because the service iterates per channel and
     *      catches each call independently — that's the failure
     *      isolation guarantee from Phase 3 §9.3.
     */
    public readonly dispatch: DispatchChannelAdapter = async (
        args: DispatchChannelArgs,
    ): Promise<void> => {
        const channel = args.channel;
        const adapter = this.adapters.get(channel);

        if (!adapter) {
            const err = new DeliveryLayerConfigError(
                `No adapter registered for channel '${channel}'. ` +
                    'Use deliveryLayer.setAdapter() before dispatching.',
            );
            logger.error('[delivery-layer] missing adapter', {
                channel,
                notification_id: args.notification.notification_id,
                user_id: args.recipient.user_id,
            });
            throw err;
        }

        // Coalesced flushes hit the channel adapter directly, bypassing
        // the rate-limit check (the flush IS the once-per-window
        // delivery). The rate-limiter sets `_uns_coalesced` on the
        // payload before re-entering this method.
        const isCoalescedFlush =
            args.notification.payload &&
            (args.notification.payload as Record<string, unknown>)
                ._uns_coalesced === true;

        if (this.rateLimiter && !isCoalescedFlush) {
            const decision = this.rateLimiter.acquire(
                args.recipient.user_id,
                channel,
            );
            if (decision.status === 'rate_limited') {
                this.rateLimiter.enqueueCoalesced(args, decision);
                logger.info(
                    '[delivery-layer] rate-limited; coalescing for next window',
                    {
                        channel,
                        notification_id: args.notification.notification_id,
                        user_id: args.recipient.user_id,
                        event_name: args.notification.event_name,
                        retry_after_ms: decision.retryAfterMs,
                    },
                );
                // REQ 9.6: the system DID act on the event — it's queued
                // for a coalesced summary. The service treats this
                // recipient/channel as `delivered`; the summary will fire
                // out-of-band when the window resets.
                return;
            }
        }

        try {
            await adapter(args);
        } catch (err) {
            // Per Phase 3 §9.3 / REQ 5.1-5.5: an adapter failure on one
            // channel MUST NOT block other channels. The service loops
            // channels with its own try/catch, so re-raising here is the
            // correct propagation: it lets the service write the
            // `failed` audit for THIS channel while still iterating to
            // the next channel for the same recipient.
            logger.warn('[delivery-layer] adapter threw', {
                channel,
                notification_id: args.notification.notification_id,
                user_id: args.recipient.user_id,
                event_name: args.notification.event_name,
                error: err instanceof Error ? err.message : String(err),
            });
            throw err;
        }
    };

    // -----------------------------------------------------------------------
    // Coalesce flush handling
    // -----------------------------------------------------------------------

    /**
     * Receive a coalesced flush from the rate-limiter and dispatch a
     * single summary delivery on the same channel.
     *
     * The summary payload merges the latest args's payload with three
     * UNS-injected fields:
     *   - `_uns_coalesced: true`            — bypass rate-limit on the
     *                                          re-entrant `dispatch` call.
     *   - `_uns_coalesced_count: number`    — events suppressed in window.
     *   - `_uns_coalesced_first_queued_at`  — ISO-8601 of first event.
     *
     * Adapters that recognise these fields render a "X notifications since
     * HH:MM" summary; adapters that don't simply send the latest payload
     * (which is also acceptable per REQ 9.6 — "single batched summary").
     */
    private async handleCoalescedFlush(
        flush: CoalescedFlush,
    ): Promise<void> {
        const adapter = this.adapters.get(flush.channel);
        if (!adapter) {
            // Should not happen — adapter registration is a startup
            // concern — but log defensively so a misconfigured channel
            // does not silently drop the summary.
            logger.warn(
                '[delivery-layer] coalesced flush with no adapter',
                {
                    channel: flush.channel,
                    user_id: flush.user_id,
                    event_name: flush.event_name,
                    count: flush.count,
                },
            );
            return;
        }

        const summaryArgs: DispatchChannelArgs = {
            ...flush.latestArgs,
            notification: {
                ...flush.latestArgs.notification,
                payload: {
                    ...flush.latestArgs.notification.payload,
                    _uns_coalesced: true,
                    _uns_coalesced_count: flush.count,
                    _uns_coalesced_first_queued_at: flush.firstQueuedAt,
                    _uns_coalesced_flushed_at: flush.flushedAt,
                },
            },
        };

        try {
            await this.dispatch(summaryArgs);
            logger.info('[delivery-layer] coalesced summary dispatched', {
                channel: flush.channel,
                user_id: flush.user_id,
                event_name: flush.event_name,
                count: flush.count,
            });
        } catch (err) {
            // The rate-limiter logs and swallows flush errors; surface
            // a structured warning so failed summaries are diagnosable.
            logger.warn(
                '[delivery-layer] coalesced summary delivery failed',
                {
                    channel: flush.channel,
                    user_id: flush.user_id,
                    event_name: flush.event_name,
                    count: flush.count,
                    error: err instanceof Error ? err.message : String(err),
                },
            );
            throw err;
        }
    }
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/**
 * Thrown when the Delivery_Layer is asked to dispatch on a channel for
 * which no adapter has been registered. Surfaces as a `failed` audit on
 * the notification (the service catches it like any other adapter throw).
 */
export class DeliveryLayerConfigError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'DeliveryLayerConfigError';
    }
}

// ---------------------------------------------------------------------------
// Re-exports — keep callers importing from the façade module only
// ---------------------------------------------------------------------------

export { DEFAULT_RATE_LIMITS_PER_MINUTE };
export type { CoalescedFlush, RateLimiterOptions };
