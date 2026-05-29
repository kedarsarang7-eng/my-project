// ============================================================================
// Observability — Per-Channel Failure-Rate Alert (UNS Task 17.3)
// ============================================================================
// Evaluates the rolling-window delivery-failure rate per channel and fires
// `alert.notifications.high_failure_rate` whenever a channel breaches the
// configured threshold AND has enough samples in the window to be worth
// alerting on. Sample input is decoupled from the evaluator so the same
// engine works in two modes:
//
//   1. Provider-driven (preferred for production). The caller injects a
//      `provider` that returns the current cumulative `(dispatched,
//      failed)` counts per channel — typically a closure over the
//      `getSnapshot()` API in `metrics.ts`. The engine keeps a small ring
//      of timestamped snapshots so it can compute deltas across the
//      rolling window without owning sample storage itself. This is the
//      mode the task brief calls for.
//
//   2. Self-collecting (used by adapters that call `recordDeliveryOutcome`
//      directly and by older tests). In this mode the engine maintains
//      its own per-channel sample ring, just like the previous
//      implementation, so existing callsites keep working without
//      changes.
//
// REQ 14.6 (canonical):
//   WHEN the rolling 5-minute failure rate
//     notifications_failed_total / notifications_dispatched_total
//   exceeds 5%, AND notifications_dispatched_total over the same rolling
//   window is at least 1, THE Notification_System SHALL fire an
//   `alert.notifications.high_failure_rate` alert. When the dispatched
//   count is 0, the alert SHALL NOT fire.
//
// Task 17.3 adds:
//   * configurable window, threshold, minimum sample size, and channels-
//     of-interest list (no hardcoded values; sensible defaults applied);
//   * pluggable sink (default: structured log via the project logger; a
//     console-based logger can be injected for tests);
//   * `evaluate()` for one-shot evaluation;
//   * `start(intervalMs)` / `stop()` for periodic evaluation.
//
// The engine is purely in-process state with a deterministic clock hook so
// every code path is unit-testable without timer fakes.
// ============================================================================

import { logger as defaultLogger } from '../../utils/logger';
import type { NotificationChannel } from '../store/types';
import {
    METRIC_NOTIFICATIONS_DISPATCHED_TOTAL,
    METRIC_NOTIFICATIONS_FAILED_TOTAL,
    METRIC_UNS_DELIVERY_ATTEMPTS_TOTAL,
    getSnapshot as getMetricsSnapshot,
    type MetricsSnapshot,
} from './metrics';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/** The canonical alert event name (REQ 14.6). */
export const ALERT_EVENT_NAME = 'alert.notifications.high_failure_rate' as const;

/**
 * Channels evaluated by default. Mirrors {@link NotificationChannel} from
 * the notification store. Callers can narrow this via the
 * `channels` option to focus on specific transports.
 */
export const ALL_CHANNELS: readonly NotificationChannel[] = [
    'in_app',
    'push',
    'email',
    'sms',
    'webhook',
] as const;

/**
 * Per-channel cumulative counts returned by a {@link DispatchOutcomeProvider}.
 * Counters are expected to be monotonic (increasing only); the engine
 * computes deltas internally to derive the window's failure rate.
 */
export interface ChannelDispatchCounts {
    /** Cumulative successful dispatch attempts since process start. */
    readonly successes: number;
    /** Cumulative failed dispatch attempts since process start. */
    readonly failures: number;
}

/**
 * Source of dispatch-outcome counts. Returns a map keyed by channel.
 * Channels missing from the map are treated as "no samples this evaluation".
 */
export type DispatchOutcomeProvider = () =>
    | ReadonlyMap<NotificationChannel, ChannelDispatchCounts>
    | Readonly<Partial<Record<NotificationChannel, ChannelDispatchCounts>>>;

/**
 * One firing alert returned by {@link FailureRateAlertEngine.evaluate} and
 * dispatched to every registered sink / subscriber.
 */
export interface FailureRateAlert {
    /** Stable event name — REQ 14.6. */
    readonly event_name: typeof ALERT_EVENT_NAME;
    /** Severity hint for downstream sinks. */
    readonly severity: 'warning' | 'error';
    /** Channel that breached the threshold. */
    readonly channel: NotificationChannel;
    /** Failed count observed inside the rolling window. */
    readonly failedCount: number;
    /** Dispatched count observed inside the rolling window. */
    readonly dispatchedCount: number;
    /** failed / dispatched ratio in [0, 1]. */
    readonly failureRatio: number;
    /** Threshold the ratio crossed. */
    readonly threshold: number;
    /** Rolling window length in milliseconds. */
    readonly windowMs: number;
    /** ISO-8601 timestamp of the window's start. */
    readonly windowStart: string;
    /** ISO-8601 timestamp of the window's end (the moment of evaluation). */
    readonly windowEnd: string;
    /** ISO-8601 timestamp the alert was fired. */
    readonly firedAt: string;
}

/** Pluggable sink invoked for every firing alert. */
export type AlertSink = (alert: FailureRateAlert) => void;

/**
 * Subscriber alias kept for backward compatibility with the previous
 * `subscribe(...)` API.
 */
export type AlertSubscriber = AlertSink;

/**
 * Minimal logger shape accepted by {@link FailureRateAlertEngine}. Compatible
 * with the project-wide structured logger and with `console`.
 */
export interface AlertLogger {
    info(msg: string, meta?: Record<string, unknown>): void;
    warn(msg: string, meta?: Record<string, unknown>): void;
    error(msg: string, meta?: Record<string, unknown>): void;
}

/**
 * Options for {@link createFailureRateAlertEngine}. All fields optional —
 * unset values fall back to env config or built-in defaults.
 */
export interface FailureRateAlertOptions {
    /** Rolling window length in ms. Defaults to {@link DEFAULT_WINDOW_MS}. */
    readonly windowMs?: number;
    /** Failure ratio threshold in [0, 1]. Defaults to {@link DEFAULT_THRESHOLD}. */
    readonly threshold?: number;
    /**
     * Minimum dispatched count in the window before the alert can fire.
     * Defaults to {@link DEFAULT_MIN_SAMPLE_SIZE}. REQ 14.6 mandates >= 1.
     */
    readonly minSampleSize?: number;
    /** Backward-compat alias for {@link minSampleSize}. */
    readonly minDispatches?: number;
    /**
     * Subset of channels to evaluate. When undefined, every channel in
     * {@link ALL_CHANNELS} is evaluated.
     */
    readonly channels?: readonly NotificationChannel[];
    /**
     * Source of dispatch-outcome counts. When provided, the engine
     * operates in provider-driven mode and uses snapshot diffs to derive
     * window deltas. When omitted, the engine uses its own internal
     * sample ring fed by {@link FailureRateAlertEngine.recordDeliveryOutcome}.
     */
    readonly provider?: DispatchOutcomeProvider;
    /**
     * Default sink invoked for every firing alert. When omitted, alerts
     * are emitted as a structured log entry via {@link logger}.
     */
    readonly sink?: AlertSink;
    /** Logger used for the structured-log default sink. */
    readonly logger?: AlertLogger;
    /** Time source — overridable for tests. Defaults to `Date.now`. */
    readonly now?: () => number;
}

// ---------------------------------------------------------------------------
// Defaults & env-config helpers
// ---------------------------------------------------------------------------

/** Default rolling-window length: 5 minutes (REQ 14.6). */
export const DEFAULT_WINDOW_MS = 5 * 60 * 1000;
/** Default failure-ratio threshold: 5% (REQ 14.6). */
export const DEFAULT_THRESHOLD = 0.05;
/** Default minimum sample size: 1 (REQ 14.6 — denominator must be ≥ 1). */
export const DEFAULT_MIN_SAMPLE_SIZE = 1;
/** Backward-compat alias retained for existing imports. */
export const DEFAULT_MIN_DISPATCHES = DEFAULT_MIN_SAMPLE_SIZE;
/**
 * Number of historical snapshots retained in provider-driven mode. Sized
 * so a ~5-minute window with 30s evaluation cadence has comfortable
 * headroom; the ring trims itself to whatever covers the window plus one
 * buffer slot.
 */
const SNAPSHOT_RING_HARD_CAP = 64;

function readNumberEnv(
    name: string,
    fallback: number,
    validate: (n: number) => boolean,
    log: AlertLogger,
): number {
    const raw = process.env[name];
    if (raw === undefined || raw === null || raw === '') return fallback;
    const parsed = Number(raw);
    if (!Number.isFinite(parsed) || !validate(parsed)) {
        log.warn('[uns-alerts] invalid env override; using safe default', {
            env: name,
            value: raw,
            fallback,
        });
        return fallback;
    }
    return parsed;
}

function resolveWindowMs(override: number | undefined, log: AlertLogger): number {
    if (override !== undefined) {
        return override > 0 ? override : DEFAULT_WINDOW_MS;
    }
    return readNumberEnv('UNS_ALERT_WINDOW_MS', DEFAULT_WINDOW_MS, (n) => n > 0, log);
}

function resolveThreshold(override: number | undefined, log: AlertLogger): number {
    if (override !== undefined) {
        return override >= 0 && override <= 1 ? override : DEFAULT_THRESHOLD;
    }
    return readNumberEnv(
        'UNS_ALERT_FAILURE_RATIO',
        DEFAULT_THRESHOLD,
        (n) => n >= 0 && n <= 1,
        log,
    );
}

function resolveMinSampleSize(
    override: number | undefined,
    log: AlertLogger,
): number {
    if (override !== undefined) {
        return override >= 1 ? Math.floor(override) : DEFAULT_MIN_SAMPLE_SIZE;
    }
    return Math.floor(
        readNumberEnv(
            'UNS_ALERT_MIN_DISPATCHES',
            DEFAULT_MIN_SAMPLE_SIZE,
            (n) => n >= 1,
            log,
        ),
    );
}

function resolveChannels(
    override: readonly NotificationChannel[] | undefined,
): readonly NotificationChannel[] {
    if (override === undefined) return ALL_CHANNELS;
    if (!Array.isArray(override)) return ALL_CHANNELS;
    // Validate each entry is a known channel; silently drop unknowns so
    // a typo cannot crash the evaluator. Empty list means "evaluate
    // nothing" — perfectly valid for callers that only want manual
    // evaluation control.
    const known = new Set<NotificationChannel>(ALL_CHANNELS);
    const filtered = override.filter((c): c is NotificationChannel => known.has(c));
    return Object.freeze([...new Set(filtered)]);
}

// ---------------------------------------------------------------------------
// Internal sample storage (self-collecting mode)
// ---------------------------------------------------------------------------

/**
 * One delivery outcome captured at a moment in time. Used only when the
 * engine runs in self-collecting mode (no provider injected).
 */
interface Sample {
    readonly t: number; // ms epoch
    readonly success: boolean;
}

/**
 * One historical reading of the {@link DispatchOutcomeProvider}. The
 * engine retains a small ring of these so it can compute deltas across
 * the rolling window in provider-driven mode.
 */
interface SnapshotEntry {
    readonly t: number;
    readonly counts: Map<NotificationChannel, ChannelDispatchCounts>;
}

// ---------------------------------------------------------------------------
// The default snapshot provider built on top of metrics.ts
// ---------------------------------------------------------------------------

/**
 * Build a {@link DispatchOutcomeProvider} that derives per-channel
 * `(successes, failures)` counts from the canonical metrics surface
 * (`metrics.ts`). Public so tests and integrators can plug it into
 * custom engines without re-deriving the labels themselves.
 *
 * The function reads three counters in order of preference:
 *   - `notifications_dispatched_total{event_name, channel, priority}`
 *   - `notifications_failed_total{event_name, channel, error_reason}`
 *   - `uns_delivery_attempts_total{channel, outcome, ...}` — used as a
 *     fallback when only the UNS-prefixed counter is populated.
 *
 * Successes are derived as `dispatched - failed` per channel, clamped to
 * zero. The metrics surface guarantees both counters are monotonic, so
 * the delta over any window is non-negative.
 */
export function createMetricsBackedProvider(
    snapshotFn: () => MetricsSnapshot = getMetricsSnapshot,
): DispatchOutcomeProvider {
    return () => {
        const snap = snapshotFn();
        const dispatched = new Map<NotificationChannel, number>();
        const failed = new Map<NotificationChannel, number>();
        const attemptSuccess = new Map<NotificationChannel, number>();
        const attemptFailure = new Map<NotificationChannel, number>();

        const knownChannels = new Set<string>(ALL_CHANNELS);

        for (const row of snap.counters) {
            const labelChannel = row.labels.channel;
            if (typeof labelChannel !== 'string' || !knownChannels.has(labelChannel)) {
                continue;
            }
            const channel = labelChannel as NotificationChannel;

            switch (row.name) {
                case METRIC_NOTIFICATIONS_DISPATCHED_TOTAL: {
                    dispatched.set(
                        channel,
                        (dispatched.get(channel) ?? 0) + row.value,
                    );
                    break;
                }
                case METRIC_NOTIFICATIONS_FAILED_TOTAL: {
                    failed.set(channel, (failed.get(channel) ?? 0) + row.value);
                    break;
                }
                case METRIC_UNS_DELIVERY_ATTEMPTS_TOTAL: {
                    const outcome = row.labels.outcome;
                    if (outcome === 'success') {
                        attemptSuccess.set(
                            channel,
                            (attemptSuccess.get(channel) ?? 0) + row.value,
                        );
                    } else if (outcome === 'failure' || outcome === 'failed') {
                        attemptFailure.set(
                            channel,
                            (attemptFailure.get(channel) ?? 0) + row.value,
                        );
                    }
                    break;
                }
                default:
                    break;
            }
        }

        const out = new Map<NotificationChannel, ChannelDispatchCounts>();
        const allChannelsSeen = new Set<NotificationChannel>([
            ...dispatched.keys(),
            ...failed.keys(),
            ...attemptSuccess.keys(),
            ...attemptFailure.keys(),
        ]);

        for (const channel of allChannelsSeen) {
            const dispatchedTotal = dispatched.get(channel);
            const failedTotal = failed.get(channel);
            if (dispatchedTotal !== undefined) {
                const f = failedTotal ?? 0;
                const s = Math.max(0, dispatchedTotal - f);
                out.set(channel, { successes: s, failures: f });
                continue;
            }
            // Fallback: only the UNS-prefixed `delivery_attempts` counter
            // was populated.
            out.set(channel, {
                successes: attemptSuccess.get(channel) ?? 0,
                failures: attemptFailure.get(channel) ?? 0,
            });
        }

        return out;
    };
}

// ---------------------------------------------------------------------------
// Engine class
// ---------------------------------------------------------------------------

/**
 * Per-channel rolling-window failure-rate evaluator.
 *
 * Two operating modes:
 *
 *   * Provider-driven — supply `provider` in the options. The engine
 *     calls `provider()` on every {@link evaluate} and computes the
 *     window delta against the oldest retained snapshot still inside
 *     the window. This is the mode the task brief calls for and the
 *     mode `metrics.ts`-backed deployments use.
 *
 *   * Self-collecting — omit `provider`. Adapters call
 *     {@link recordDeliveryOutcome} after every delivery attempt and the
 *     engine maintains its own per-channel sample ring, evaluating
 *     directly off the timestamped samples. This mode is preserved for
 *     backward compatibility with the previous alert engine surface.
 */
export class FailureRateAlertEngine {
    private readonly windowMs: number;
    private readonly threshold: number;
    private readonly minSampleSize: number;
    private readonly channels: readonly NotificationChannel[];
    private readonly provider: DispatchOutcomeProvider | undefined;
    private readonly logger: AlertLogger;
    private readonly now: () => number;

    /** Per-channel ring of samples (self-collecting mode). */
    private readonly samples: Map<NotificationChannel, Sample[]> = new Map();
    /** Snapshot ring (provider-driven mode). */
    private readonly snapshots: SnapshotEntry[] = [];
    /** Channels currently in a breach episode. */
    private readonly firing: Set<NotificationChannel> = new Set();
    /** External sinks invoked on every firing evaluation. */
    private readonly sinks: Set<AlertSink> = new Set();
    /** Timer handle when {@link start} is active. */
    private intervalHandle: ReturnType<typeof setInterval> | null = null;
    /**
     * Default log sink — edge-triggered: fires exactly once per breach
     * episode. Replaced wholesale when a caller supplies their own
     * `sink` option or invokes {@link setSink}.
     */
    private defaultEdgeSink: AlertSink | null;
    /**
     * Whether to emit the built-in structured log on episode-start.
     * Goes false when a custom sink is configured via the `sink`
     * option / {@link setSink} so the caller's sink is the only output.
     */
    private emitDefaultLog: boolean;

    constructor(options: FailureRateAlertOptions = {}) {
        this.logger = options.logger ?? defaultLogger;
        this.windowMs = resolveWindowMs(options.windowMs, this.logger);
        this.threshold = resolveThreshold(options.threshold, this.logger);
        // Accept both `minSampleSize` (task-brief name) and `minDispatches`
        // (legacy name). The task-brief name wins when both are supplied.
        const minOverride =
            options.minSampleSize !== undefined
                ? options.minSampleSize
                : options.minDispatches;
        this.minSampleSize = resolveMinSampleSize(minOverride, this.logger);
        this.channels = resolveChannels(options.channels);
        this.provider = options.provider;
        this.now = options.now ?? Date.now;

        this.defaultEdgeSink = (alert) => this.emitStructuredLog(alert);
        if (options.sink) {
            // Caller wants alerts routed exclusively to their sink.
            this.sinks.add(options.sink);
            this.emitDefaultLog = false;
        } else {
            this.emitDefaultLog = true;
        }

        for (const channel of ALL_CHANNELS) {
            this.samples.set(channel, []);
        }
    }

    /** Inspect resolved configuration (handy for tests / observability). */
    public getConfig(): {
        readonly windowMs: number;
        readonly threshold: number;
        readonly minSampleSize: number;
        readonly minDispatches: number;
        readonly channels: readonly NotificationChannel[];
        readonly mode: 'provider' | 'self-collecting';
    } {
        return {
            windowMs: this.windowMs,
            threshold: this.threshold,
            minSampleSize: this.minSampleSize,
            minDispatches: this.minSampleSize,
            channels: this.channels,
            mode: this.provider ? 'provider' : 'self-collecting',
        };
    }

    /**
     * Record a single delivery outcome on a channel (self-collecting
     * mode). Cheap: O(1) append plus an O(k) prune of stale samples
     * where k is bounded by the window length.
     *
     * Calls in provider-driven mode are accepted but ignored — the
     * engine derives its data from the provider in that mode.
     */
    public recordDeliveryOutcome(
        channel: NotificationChannel,
        success: boolean,
    ): void {
        if (this.provider) {
            // Provider-driven mode: defer to the metrics surface.
            return;
        }
        const ring = this.samples.get(channel);
        if (!ring) {
            this.samples.set(channel, [{ t: this.now(), success }]);
            return;
        }
        ring.push({ t: this.now(), success });
        this.prune(channel);
    }

    /**
     * Evaluate every channel-of-interest and return the list of alerts
     * currently firing. Pure read with respect to the caller's intent
     * (no double-counting of samples). Side effects:
     *   - emits ONE structured warn / error log per channel that has
     *     just transitioned from healthy → breaching this evaluation
     *     (the default sink performs this; replacing the sink replaces
     *     this side effect);
     *   - invokes every registered sink for every firing alert.
     *
     * A channel that recovers (ratio drops back below threshold or
     * dispatched-in-window falls below {@link minSampleSize}) clears its
     * firing flag, so the next breach fires the structured log again.
     *
     * REQ 14.6 — When dispatched in window is 0 (or below the minimum
     * sample size), the alert SHALL NOT fire.
     */
    public evaluate(): readonly FailureRateAlert[] {
        const now = this.now();
        const firing: FailureRateAlert[] = [];

        if (this.provider) {
            this.captureSnapshot(now);
        }

        for (const channel of this.channels) {
            const counts = this.computeWindowCounts(channel, now);
            const dispatched = counts.dispatched;
            const failed = counts.failed;

            if (dispatched < this.minSampleSize) {
                if (this.firing.has(channel)) {
                    this.firing.delete(channel);
                }
                continue;
            }

            const ratio = dispatched === 0 ? 0 : failed / dispatched;
            if (ratio <= this.threshold) {
                if (this.firing.has(channel)) {
                    this.firing.delete(channel);
                    this.logger.info('[uns-alerts] channel recovered', {
                        channel,
                        failed,
                        dispatched,
                        ratio,
                        threshold: this.threshold,
                        windowMs: this.windowMs,
                    });
                }
                continue;
            }

            const alert: FailureRateAlert = {
                event_name: ALERT_EVENT_NAME,
                severity: ratio >= this.threshold * 2 ? 'error' : 'warning',
                channel,
                failedCount: failed,
                dispatchedCount: dispatched,
                failureRatio: ratio,
                threshold: this.threshold,
                windowMs: this.windowMs,
                windowStart: new Date(now - this.windowMs).toISOString(),
                windowEnd: new Date(now).toISOString(),
                firedAt: new Date(now).toISOString(),
            };

            const isNewEpisode = !this.firing.has(channel);
            if (isNewEpisode) {
                this.firing.add(channel);
                if (this.emitDefaultLog && this.defaultEdgeSink) {
                    try {
                        this.defaultEdgeSink(alert);
                    } catch (err) {
                        // Default sink should never throw, but be defensive.
                        this.logger.warn('[uns-alerts] default sink threw', {
                            error: err instanceof Error ? err.message : String(err),
                        });
                    }
                }
            }

            this.dispatchToSinks(alert);
            firing.push(alert);
        }

        return firing;
    }

    /**
     * Backward-compat alias for {@link evaluate}.
     */
    public checkAlerts(): readonly FailureRateAlert[] {
        return this.evaluate();
    }

    /**
     * Begin periodic evaluation. The engine calls {@link evaluate} every
     * `intervalMs` milliseconds. Calling `start` while already running
     * is a no-op (the original interval keeps ticking) — call
     * {@link stop} first to change the cadence.
     */
    public start(intervalMs: number): void {
        if (
            !Number.isFinite(intervalMs) ||
            intervalMs <= 0
        ) {
            throw new TypeError(
                `intervalMs must be a positive finite number, received ${String(
                    intervalMs,
                )}`,
            );
        }
        if (this.intervalHandle !== null) {
            this.logger.warn('[uns-alerts] start() called while already running', {
                intervalMs,
            });
            return;
        }
        this.intervalHandle = setInterval(() => {
            try {
                this.evaluate();
            } catch (err) {
                // A throw here would crash the timer in some runtimes;
                // catch and log instead so the next tick still runs.
                this.logger.error(
                    '[uns-alerts] evaluate() threw inside interval — continuing',
                    { error: err instanceof Error ? err.message : String(err) },
                );
            }
        }, intervalMs);
        // Allow the process to exit naturally even with the timer pending.
        // `unref` is only present on Node timers.
        if (
            this.intervalHandle &&
            typeof (this.intervalHandle as { unref?: () => void }).unref ===
                'function'
        ) {
            (this.intervalHandle as { unref: () => void }).unref();
        }
    }

    /**
     * Stop periodic evaluation. Idempotent — calling stop when not
     * running is a no-op.
     */
    public stop(): void {
        if (this.intervalHandle === null) return;
        clearInterval(this.intervalHandle);
        this.intervalHandle = null;
    }

    /**
     * Register an additional sink invoked for every firing alert. Returns
     * a disposer.
     */
    public addSink(fn: AlertSink): () => void {
        this.sinks.add(fn);
        return () => {
            this.sinks.delete(fn);
        };
    }

    /**
     * Backward-compat alias for {@link addSink}.
     */
    public subscribe(fn: AlertSubscriber): () => void {
        return this.addSink(fn);
    }

    /**
     * Replace every registered sink with a single new one and disable
     * the built-in default structured-log emission. Useful when a caller
     * wants alerts to flow exclusively to their own pipeline (e.g. SNS
     * topic, PagerDuty webhook).
     */
    public setSink(fn: AlertSink): void {
        this.sinks.clear();
        this.sinks.add(fn);
        this.emitDefaultLog = false;
    }

    /**
     * Reset all in-memory state. Tests use this between cases; runtime
     * code should not need it (the rolling window prunes itself).
     */
    public reset(): void {
        for (const channel of ALL_CHANNELS) {
            this.samples.set(channel, []);
        }
        this.snapshots.length = 0;
        this.firing.clear();
    }

    // -----------------------------------------------------------------------
    // Internals
    // -----------------------------------------------------------------------

    private prune(channel: NotificationChannel, nowOverride?: number): void {
        const ring = this.samples.get(channel);
        if (!ring || ring.length === 0) return;
        const now = nowOverride ?? this.now();
        const cutoff = now - this.windowMs;
        let firstFresh = 0;
        while (firstFresh < ring.length && ring[firstFresh].t < cutoff) {
            firstFresh += 1;
        }
        if (firstFresh > 0) {
            ring.splice(0, firstFresh);
        }
    }

    private captureSnapshot(now: number): void {
        if (!this.provider) return;
        let raw: ReturnType<DispatchOutcomeProvider>;
        try {
            raw = this.provider();
        } catch (err) {
            this.logger.error('[uns-alerts] provider() threw — skipping snapshot', {
                error: err instanceof Error ? err.message : String(err),
            });
            return;
        }
        const counts = normalizeProviderResult(raw);
        this.snapshots.push({ t: now, counts });

        // Prune snapshots: keep one snapshot strictly older than `now -
        // windowMs` (so we have a baseline at the start of the window),
        // and drop everything older than that.
        const cutoff = now - this.windowMs;
        // Find the index of the youngest entry that is still <= cutoff;
        // we keep that one and discard everything before it.
        let keepFrom = 0;
        for (let i = this.snapshots.length - 1; i >= 0; i -= 1) {
            if (this.snapshots[i].t <= cutoff) {
                keepFrom = i;
                break;
            }
        }
        if (keepFrom > 0) {
            this.snapshots.splice(0, keepFrom);
        }
        // Hard cap to defend against pathological clock skews.
        if (this.snapshots.length > SNAPSHOT_RING_HARD_CAP) {
            this.snapshots.splice(
                0,
                this.snapshots.length - SNAPSHOT_RING_HARD_CAP,
            );
        }
    }

    private computeWindowCounts(
        channel: NotificationChannel,
        now: number,
    ): { dispatched: number; failed: number } {
        if (this.provider) {
            return this.computeWindowCountsFromSnapshots(channel, now);
        }

        // Self-collecting mode — count samples inside the window.
        this.prune(channel, now);
        const ring = this.samples.get(channel) ?? [];
        let dispatched = 0;
        let failed = 0;
        for (const s of ring) {
            dispatched += 1;
            if (!s.success) failed += 1;
        }
        return { dispatched, failed };
    }

    private computeWindowCountsFromSnapshots(
        channel: NotificationChannel,
        now: number,
    ): { dispatched: number; failed: number } {
        if (this.snapshots.length === 0) return { dispatched: 0, failed: 0 };
        const cutoff = now - this.windowMs;
        const latest = this.snapshots[this.snapshots.length - 1];
        // Pick the baseline snapshot: youngest one whose timestamp is
        // <= cutoff. If none exists (the engine hasn't been running for a
        // full window yet), use a synthetic zero baseline so the visible
        // delta is "everything since process start" — the safe default
        // before the window has filled.
        let baseline: SnapshotEntry | null = null;
        for (let i = this.snapshots.length - 1; i >= 0; i -= 1) {
            if (this.snapshots[i].t <= cutoff) {
                baseline = this.snapshots[i];
                break;
            }
        }
        const latestCounts =
            latest.counts.get(channel) ?? { successes: 0, failures: 0 };
        const baselineCounts = baseline
            ? baseline.counts.get(channel) ?? { successes: 0, failures: 0 }
            : { successes: 0, failures: 0 };

        // Counters are monotonic; clamp deltas to zero defensively in
        // case of out-of-order snapshots.
        const successes = Math.max(
            0,
            latestCounts.successes - baselineCounts.successes,
        );
        const failures = Math.max(
            0,
            latestCounts.failures - baselineCounts.failures,
        );
        return { dispatched: successes + failures, failed: failures };
    }

    private emitStructuredLog(alert: FailureRateAlert): void {
        const meta = {
            event_name: alert.event_name,
            channel: alert.channel,
            failed: alert.failedCount,
            dispatched: alert.dispatchedCount,
            ratio: alert.failureRatio,
            threshold: alert.threshold,
            windowMs: alert.windowMs,
            windowStart: alert.windowStart,
            windowEnd: alert.windowEnd,
        };
        if (alert.severity === 'error') {
            this.logger.error(`[uns-alerts] ${ALERT_EVENT_NAME}`, meta);
        } else {
            this.logger.warn(`[uns-alerts] ${ALERT_EVENT_NAME}`, meta);
        }
    }

    private dispatchToSinks(alert: FailureRateAlert): void {
        for (const sink of this.sinks) {
            try {
                sink(alert);
            } catch (err) {
                // A bad sink must not block other sinks or future
                // evaluations — log and continue.
                this.logger.warn('[uns-alerts] sink threw', {
                    error: err instanceof Error ? err.message : String(err),
                });
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function normalizeProviderResult(
    raw: ReturnType<DispatchOutcomeProvider>,
): Map<NotificationChannel, ChannelDispatchCounts> {
    const out = new Map<NotificationChannel, ChannelDispatchCounts>();
    if (!raw) return out;
    if (raw instanceof Map) {
        for (const [k, v] of raw.entries()) {
            const sanitized = sanitizeCounts(v);
            if (sanitized) out.set(k, sanitized);
        }
        return out;
    }
    // Plain object form.
    for (const k of Object.keys(raw)) {
        const channel = k as NotificationChannel;
        const sanitized = sanitizeCounts(
            (raw as Partial<Record<NotificationChannel, ChannelDispatchCounts>>)[
                channel
            ],
        );
        if (sanitized) out.set(channel, sanitized);
    }
    return out;
}

function sanitizeCounts(
    raw: ChannelDispatchCounts | undefined,
): ChannelDispatchCounts | null {
    if (!raw) return null;
    const successes =
        Number.isFinite(raw.successes) && raw.successes >= 0
            ? Math.floor(raw.successes)
            : 0;
    const failures =
        Number.isFinite(raw.failures) && raw.failures >= 0
            ? Math.floor(raw.failures)
            : 0;
    return { successes, failures };
}

// ---------------------------------------------------------------------------
// Module-level singleton & convenience exports
// ---------------------------------------------------------------------------

/**
 * Process-wide singleton used by the convenience exports below. Runtime
 * code can call `recordDeliveryOutcome(...)` / `evaluate()` rather than
 * touching this directly. Tests construct their own engine via
 * {@link createFailureRateAlertEngine} for full isolation.
 */
let defaultEngine: FailureRateAlertEngine | null = null;

function getDefaultEngine(): FailureRateAlertEngine {
    if (!defaultEngine) {
        defaultEngine = new FailureRateAlertEngine();
    }
    return defaultEngine;
}

/**
 * Construct an isolated engine with the supplied options. Used by tests
 * and by callers that want a non-singleton evaluator (e.g. one per
 * tenant). Most runtime callers should use the convenience functions.
 */
export function createFailureRateAlertEngine(
    options: FailureRateAlertOptions = {},
): FailureRateAlertEngine {
    return new FailureRateAlertEngine(options);
}

/**
 * Record one delivery outcome on the process-wide singleton. Channel
 * adapters call this after every delivery attempt when running in
 * self-collecting mode.
 */
export function recordDeliveryOutcome(
    channel: NotificationChannel,
    success: boolean,
): void {
    getDefaultEngine().recordDeliveryOutcome(channel, success);
}

/**
 * Evaluate every channel against the configured threshold and return the
 * currently-firing alerts. A scheduled lambda (or in-process tick) calls
 * this and forwards the result to the configured operator sink.
 */
export function evaluate(): readonly FailureRateAlert[] {
    return getDefaultEngine().evaluate();
}

/**
 * Backward-compat alias for {@link evaluate}.
 */
export function checkAlerts(): readonly FailureRateAlert[] {
    return getDefaultEngine().evaluate();
}

/**
 * Subscribe to firing alerts on the process-wide singleton. Returns a
 * disposer.
 */
export function onAlertFired(fn: AlertSubscriber): () => void {
    return getDefaultEngine().subscribe(fn);
}

/**
 * Reset the process-wide singleton. Tests may call this; runtime code
 * should not need to.
 */
export function resetDefaultEngineForTests(): void {
    if (defaultEngine) {
        defaultEngine.stop();
        defaultEngine.reset();
        defaultEngine = null;
    }
}
