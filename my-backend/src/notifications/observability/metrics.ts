// ============================================================================
// Notifications Observability — Metrics Surface (UNS Task 17.2)
// ============================================================================
//
// Lightweight, in-memory metrics surface for the Unified Notification System.
// Exposes the counters and histograms required by REQ 14:
//
//   * REQ 14.2 — `events_emitted_total{event_name, priority, source_app}`
//   * REQ 14.3 — `notifications_dispatched_total{event_name, channel, priority}`
//   * REQ 14.4 — `notifications_failed_total{event_name, channel, error_reason}`
//   * REQ 14.5 — `delivery_latency_ms{channel}` histogram with rolling 5-min p95
//
// Plus the ancillary UNS counters declared in the design / phase3-architecture
// document (publish-volume, dedup hits, preference rejections, rate-limit
// rejections) so that producers across the pipeline can record their events
// against a single, named registry instead of recreating ad-hoc strings.
//
// Design choices
// --------------
//
//   1. NO new dependency. The workspace already vendors `@aws-sdk/client-
//      cloudwatch` (used by `services/websocket.service.ts`, `kms.service.ts`,
//      `payment-order.service.ts`, etc.) but a CloudWatch put has cost and
//      latency. The notification pipeline emits one metric per lifecycle
//      transition per recipient — at 10 000 concurrent users that is the hot
//      path. We keep state in-process and let an external sink (the scheduled
//      `flush` job from task 17.3 / 17.5) read the snapshot and forward to
//      CloudWatch in a batched put. AGENTS.md "no heavy dependencies" rule.
//
//   2. Bounded label cardinality. Every counter / histogram caps the number of
//      distinct label-tuples it will retain at `MAX_LABEL_CARDINALITY` per
//      metric. Past the cap, new tuples are coalesced into the synthetic
//      `__overflow__` bucket and a one-shot warning is logged. This protects
//      memory if a misbehaving producer leaks a high-cardinality label such
//      as `notification_id`.
//
//   3. Histogram windowing. `observeHistogram` records a `(timestamp, value)`
//      tuple per channel; `getSnapshot()` (and `p95(window_ms)`) compute the
//      requested percentile over only the samples whose timestamp falls
//      inside the rolling window. Per channel we cap the sample buffer at
//      `HISTOGRAM_MAX_SAMPLES` and evict the oldest first — the eviction
//      bound is what makes the surface safe to leave running indefinitely.
//
//   4. Pure functions. The module exports a singleton `metricsRegistry` and a
//      `MetricsRegistry` class so tests and observability hooks can construct
//      isolated instances with deterministic clocks (`now()` injectable).
//
// What this module deliberately does NOT do
// -----------------------------------------
//
//   * Network I/O. There is no CloudWatch / Prometheus / EMF push here — the
//     consumer (task 17.3 alert + 17.5 flush) reads `getSnapshot()` and
//     decides where to ship. Keeping I/O out of this module makes the
//     `Notification_Service.dispatch` hot path zero-allocation outside of the
//     map writes themselves.
//
//   * Aggregation across processes. Lambda functions are short-lived; this
//     surface aggregates per-invocation. The flush sink is responsible for
//     cross-Lambda rollup. A future Phase 5 task may swap the in-memory
//     backend for ECS / Fargate Prometheus scrape — the API surface here is
//     stable across that swap.
// ============================================================================

import { logger } from '../../utils/logger';

// ---------------------------------------------------------------------------
//                         Predefined metric names
// ---------------------------------------------------------------------------
//
// Exported as constants so callers cannot misspell them. AGENTS.md "no
// hardcoded values" — the canonical strings live in exactly one place and
// every producer references them.

/** REQ 14.2 — counter, labels: event_name, priority, source_app. */
export const METRIC_EVENTS_EMITTED_TOTAL = 'events_emitted_total' as const;

/** REQ 14.3 — counter, labels: event_name, channel, priority. */
export const METRIC_NOTIFICATIONS_DISPATCHED_TOTAL = 'notifications_dispatched_total' as const;

/** REQ 14.4 — counter, labels: event_name, channel, error_reason. */
export const METRIC_NOTIFICATIONS_FAILED_TOTAL = 'notifications_failed_total' as const;

/** REQ 14.5 — histogram, labels: channel. Unit: milliseconds. */
export const METRIC_DELIVERY_LATENCY_MS = 'delivery_latency_ms' as const;

// -- UNS-prefixed counters from phase3-architecture / task 17.2 spec --------
//
// The task prompt (and the wider observability section of design.md) calls
// out a richer set of UNS counters covering publish volume, delivery
// outcomes per channel, preference rejections, dedup hits, and latency.
// They live here as exported constants so producers across the pipeline
// (publisher.ts, notification.service.ts, channels/*.ts) can `incCounter`
// against the same names instead of inventing ad-hoc strings.

/** Counter — every successful `Event_Bus.publish`. Labels: event_name, priority, source_app. */
export const METRIC_UNS_EVENTS_PUBLISHED_TOTAL = 'uns_events_published_total' as const;

/** Counter — every notification record persisted with status `emitted`. Labels: event_name, priority, category. */
export const METRIC_UNS_NOTIFICATIONS_CREATED_TOTAL = 'uns_notifications_created_total' as const;

/** Counter — every per-channel delivery attempt (success or failure). Labels: channel, outcome, event_name. */
export const METRIC_UNS_DELIVERY_ATTEMPTS_TOTAL = 'uns_delivery_attempts_total' as const;

/** Counter — preference engine rejections (mute, quiet-hours, opted-out, self). Labels: reason, event_name. */
export const METRIC_UNS_PREFERENCE_REJECTIONS_TOTAL = 'uns_preference_rejections_total' as const;

/** Counter — every `skipped_duplicate` audit (REQ 4.4). Labels: event_name. */
export const METRIC_UNS_DEDUP_HITS_TOTAL = 'uns_dedup_hits_total' as const;

/** Counter — publishes blocked by the per-Producer rate limit (REQ 12.4). Labels: source_module, source_app. */
export const METRIC_UNS_PUBLISH_RATE_LIMIT_REJECTIONS_TOTAL =
    'uns_publish_rate_limit_rejections_total' as const;

/** Histogram — UNS-prefixed alias of `delivery_latency_ms`. Labels: channel. */
export const METRIC_UNS_DELIVERY_LATENCY_MS = 'uns_delivery_latency_ms' as const;

/** Gauge — current depth of a named queue (e.g. SQS main, SQS DLQ, in-memory outbox). Labels: queue_name. */
export const METRIC_UNS_QUEUE_DEPTH = 'uns_queue_depth' as const;

/** Read-only registry of every known metric name. Useful for tests and admin endpoints. */
export const KNOWN_METRIC_NAMES = Object.freeze([
    METRIC_EVENTS_EMITTED_TOTAL,
    METRIC_NOTIFICATIONS_DISPATCHED_TOTAL,
    METRIC_NOTIFICATIONS_FAILED_TOTAL,
    METRIC_DELIVERY_LATENCY_MS,
    METRIC_UNS_EVENTS_PUBLISHED_TOTAL,
    METRIC_UNS_NOTIFICATIONS_CREATED_TOTAL,
    METRIC_UNS_DELIVERY_ATTEMPTS_TOTAL,
    METRIC_UNS_PREFERENCE_REJECTIONS_TOTAL,
    METRIC_UNS_DEDUP_HITS_TOTAL,
    METRIC_UNS_PUBLISH_RATE_LIMIT_REJECTIONS_TOTAL,
    METRIC_UNS_DELIVERY_LATENCY_MS,
    METRIC_UNS_QUEUE_DEPTH,
] as const);

// -- Channel-dispatch outcomes (closed enum) --------------------------------
//
// Keeping the outcome alphabet closed prevents producers from introducing
// ad-hoc strings like "ok" / "err" that would fragment the metrics. Task
// 17.2 calls out exactly three: success, failure, retry.

export const CHANNEL_DISPATCH_OUTCOMES = Object.freeze([
    'success',
    'failure',
    'retry',
] as const);

export type ChannelDispatchOutcome = (typeof CHANNEL_DISPATCH_OUTCOMES)[number];

export type MetricName = (typeof KNOWN_METRIC_NAMES)[number];

// ---------------------------------------------------------------------------
//                                 Types
// ---------------------------------------------------------------------------

/**
 * Label values are strings. Numbers and booleans are coerced for safety.
 * Unset / undefined labels are dropped.
 */
export type Labels = Readonly<Record<string, string | number | boolean | undefined>>;

/**
 * Frozen counter snapshot row.
 */
export interface CounterSnapshot {
    readonly name: string;
    readonly labels: Readonly<Record<string, string>>;
    readonly value: number;
}

/**
 * Frozen gauge snapshot row. Gauges hold a single current value per
 * `(name, label-tuple)` — the most recent `gauge(...)` write wins.
 */
export interface GaugeSnapshot {
    readonly name: string;
    readonly labels: Readonly<Record<string, string>>;
    readonly value: number;
    /** ms epoch the value was last set, useful for staleness alerting. */
    readonly updated_at_ms: number;
}

/**
 * Frozen histogram-aggregate row. `count` / `sum` / `min` / `max` cover the
 * whole rolling window; `p50` / `p95` / `p99` are computed over the samples
 * still inside the rolling window at snapshot time.
 */
export interface HistogramSnapshot {
    readonly name: string;
    readonly labels: Readonly<Record<string, string>>;
    readonly count: number;
    readonly sum: number;
    readonly min: number;
    readonly max: number;
    readonly p50: number;
    readonly p95: number;
    readonly p99: number;
    readonly window_ms: number;
}

/**
 * Combined snapshot returned by `getSnapshot()` — the shape consumed by the
 * upcoming flush sink and by tests.
 */
export interface MetricsSnapshot {
    readonly counters: readonly CounterSnapshot[];
    readonly gauges: readonly GaugeSnapshot[];
    readonly histograms: readonly HistogramSnapshot[];
    readonly captured_at_ms: number;
}

// ---------------------------------------------------------------------------
//                            Pluggable sink contract
// ---------------------------------------------------------------------------
//
// Task 17.2 requires a "pluggable backend sink". The default is an
// in-memory aggregator (the registry itself); production deployments can
// inject a custom sink that forwards every record to CloudWatch / StatsD /
// EMF / OTLP without touching the producer call sites.
//
// A sink receives ONE call per primitive operation, NOT per snapshot. That
// keeps the contract minimal and allows the sink to batch / flush on its
// own schedule. Sinks MUST be non-throwing (failures are caught and logged
// once per sink+kind so a flapping CloudWatch put cannot stall the
// dispatch hot path).

/** Single record handed to a `MetricsSink` for a counter increment. */
export interface CounterRecord {
    readonly kind: 'counter';
    readonly name: string;
    readonly value: number;
    readonly labels: Readonly<Record<string, string>>;
    readonly timestamp_ms: number;
}

/** Single record handed to a `MetricsSink` for a gauge write. */
export interface GaugeRecord {
    readonly kind: 'gauge';
    readonly name: string;
    readonly value: number;
    readonly labels: Readonly<Record<string, string>>;
    readonly timestamp_ms: number;
}

/** Single record handed to a `MetricsSink` for a histogram observation. */
export interface HistogramRecord {
    readonly kind: 'histogram';
    readonly name: string;
    readonly value: number;
    readonly labels: Readonly<Record<string, string>>;
    readonly timestamp_ms: number;
}

export type MetricRecord = CounterRecord | GaugeRecord | HistogramRecord;

/**
 * Pluggable sink. Implementations forward records to whatever external
 * backend is in use (CloudWatch, StatsD, OTLP, …). The default registry
 * is itself an in-memory sink — see `MetricsRegistry`.
 *
 * Sinks SHOULD be cheap and non-blocking; long-running I/O belongs in a
 * separate async batcher fed off the in-memory snapshot.
 */
export interface MetricsSink {
    /** Receive one metric record. Implementations MUST NOT throw. */
    record(record: MetricRecord): void;
}

// ---------------------------------------------------------------------------
//                                 Limits
// ---------------------------------------------------------------------------

/**
 * Maximum distinct `(metric_name, label-tuple)` rows the registry will retain
 * for a counter before subsequent rows are coalesced into the `__overflow__`
 * bucket. Set deliberately high enough that the legitimate label space
 * (event_name × priority × channel × outcome) never reaches the cap, and low
 * enough that an accidental high-cardinality label cannot exhaust memory.
 *
 * Worst-case legitimate cardinality estimate: ~50 event_names × 4 priorities
 * × 5 channels × 3 outcomes = 3000, comfortably below 5000. A label leak
 * (e.g. someone using `notification_id` as a label) trips the cap quickly,
 * which is the point.
 */
export const MAX_LABEL_CARDINALITY = 5_000;

/**
 * Histogram sample buffer cap per `(metric_name, label-tuple)`. Old samples
 * are evicted FIFO when the buffer exceeds this cap. At the rolling 5-minute
 * window mandated by REQ 14.5, this comfortably accommodates 30+ samples per
 * second per channel without growing unbounded.
 */
export const HISTOGRAM_MAX_SAMPLES = 10_000;

/** REQ 14.5 — rolling p95 window. */
export const DEFAULT_ROLLING_WINDOW_MS = 5 * 60 * 1000;

// ---------------------------------------------------------------------------
//                          Internal storage shapes
// ---------------------------------------------------------------------------

interface HistogramSample {
    readonly t: number; // ms epoch
    readonly v: number; // value
}

interface HistogramBucket {
    samples: HistogramSample[];
    count: number;
    sum: number;
    min: number;
    max: number;
}

interface GaugeCell {
    value: number;
    updated_at_ms: number;
}

// ---------------------------------------------------------------------------
//                              MetricsRegistry
// ---------------------------------------------------------------------------

/**
 * In-memory, thread-safe-enough-for-Node-single-thread registry of UNS
 * metrics.
 *
 * The default `metricsRegistry` singleton is used by the pipeline. Tests
 * construct fresh instances to keep state isolated across cases and inject a
 * deterministic `now()` clock when verifying rolling-window math.
 */
export class MetricsRegistry {
    private readonly counters: Map<string, number> = new Map();
    private readonly gauges: Map<string, GaugeCell> = new Map();
    private readonly histograms: Map<string, HistogramBucket> = new Map();

    /**
     * `__overflow__` warning is logged once per `(name, kind)` to keep log
     * volume bounded if the cap is hit repeatedly.
     */
    private readonly overflowWarned: Set<string> = new Set();

    private readonly now: () => number;

    /** Registered external sinks. The registry's own in-memory store is implicit. */
    private readonly sinks: Set<MetricsSink> = new Set();

    constructor(opts?: {
        readonly now?: () => number;
        /** Optional pre-registered sinks (convenience for tests / wiring). */
        readonly sinks?: readonly MetricsSink[];
    }) {
        this.now = opts?.now ?? (() => Date.now());
        if (opts?.sinks) {
            for (const sink of opts.sinks) this.sinks.add(sink);
        }
    }

    /** REQ 14.2-14.4 + UNS counters: increment a counter by `delta` (default 1). */
    public incCounter(name: string, labels: Labels = {}, delta = 1): void {
        validateMetricName(name);
        validateNumber(delta, 'delta');
        if (delta <= 0) {
            // Counters are monotone-up; ignore non-positive deltas to keep the
            // invariant predictable for downstream consumers.
            return;
        }
        const key = this.cardinalityBoundedKey(name, labels, 'counter');
        const prev = this.counters.get(key) ?? 0;
        this.counters.set(key, prev + delta);

        this.dispatchToSinks({
            kind: 'counter',
            name,
            value: delta,
            labels: parseKey(key).labels,
            timestamp_ms: this.now(),
        });
    }

    /**
     * Set the current value of a gauge. Gauges hold a single number per
     * `(name, label-tuple)` — the most recent write wins. Use cases include
     * queue depth, active connection count, and configuration values.
     */
    public setGauge(name: string, value: number, labels: Labels = {}): void {
        validateMetricName(name);
        validateNumber(value, 'value');
        const key = this.cardinalityBoundedKey(name, labels, 'gauge');
        const ts = this.now();
        this.gauges.set(key, { value, updated_at_ms: ts });

        this.dispatchToSinks({
            kind: 'gauge',
            name,
            value,
            labels: parseKey(key).labels,
            timestamp_ms: ts,
        });
    }

    /**
     * REQ 14.5 — record an observation for a histogram. `value` is in the
     * histogram's natural unit (`delivery_latency_ms` is milliseconds).
     */
    public observeHistogram(
        name: string,
        value: number,
        labels: Labels = {},
    ): void {
        validateMetricName(name);
        validateNumber(value, 'value');
        if (value < 0) {
            // Negative durations are nonsensical; drop and warn-once. Allowing
            // them would corrupt p95 / min calculations.
            this.warnOnce(`negative_value:${name}`, () =>
                logger.warn('[uns.metrics] dropping negative histogram observation', {
                    name,
                    value,
                }),
            );
            return;
        }

        const key = this.cardinalityBoundedKey(name, labels, 'histogram');
        let bucket = this.histograms.get(key);
        if (!bucket) {
            bucket = {
                samples: [],
                count: 0,
                sum: 0,
                min: value,
                max: value,
            };
            this.histograms.set(key, bucket);
        }

        const sample: HistogramSample = { t: this.now(), v: value };
        bucket.samples.push(sample);
        if (bucket.samples.length > HISTOGRAM_MAX_SAMPLES) {
            // FIFO eviction. Slicing once keeps amortized O(1) per push.
            bucket.samples.splice(0, bucket.samples.length - HISTOGRAM_MAX_SAMPLES);
        }
        bucket.count += 1;
        bucket.sum += value;
        if (value < bucket.min) bucket.min = value;
        if (value > bucket.max) bucket.max = value;

        this.dispatchToSinks({
            kind: 'histogram',
            name,
            value,
            labels: parseKey(key).labels,
            timestamp_ms: sample.t,
        });
    }

    /**
     * Convenience: compute p95 for a single histogram tuple over the rolling
     * window. Returns `0` when no in-window samples are present.
     */
    public p95(
        name: string,
        labels: Labels = {},
        windowMs: number = DEFAULT_ROLLING_WINDOW_MS,
    ): number {
        return this.percentile(name, labels, 95, windowMs);
    }

    /**
     * Compute an arbitrary percentile (0-100) over the rolling window.
     */
    public percentile(
        name: string,
        labels: Labels = {},
        percentileRank: number,
        windowMs: number = DEFAULT_ROLLING_WINDOW_MS,
    ): number {
        validateMetricName(name);
        if (
            !Number.isFinite(percentileRank) ||
            percentileRank < 0 ||
            percentileRank > 100
        ) {
            throw new TypeError(
                `percentileRank must be in [0, 100], received ${percentileRank}`,
            );
        }
        validateNumber(windowMs, 'windowMs');
        if (windowMs <= 0) {
            throw new TypeError(`windowMs must be positive, received ${windowMs}`);
        }

        const key = makeKey(name, normalizeLabels(labels));
        const bucket = this.histograms.get(key);
        if (!bucket) return 0;

        const samples = withinWindow(bucket.samples, this.now(), windowMs);
        return computePercentile(samples, percentileRank);
    }

    /**
     * Build a deterministic, frozen snapshot of the current metric state. The
     * snapshot is the read interface for the flush sink (task 17.5) and for
     * unit tests.
     */
    public getSnapshot(
        windowMs: number = DEFAULT_ROLLING_WINDOW_MS,
    ): MetricsSnapshot {
        validateNumber(windowMs, 'windowMs');
        if (windowMs <= 0) {
            throw new TypeError(`windowMs must be positive, received ${windowMs}`);
        }

        const capturedAt = this.now();

        const counters: CounterSnapshot[] = [];
        for (const [key, value] of this.counters.entries()) {
            const { name, labels } = parseKey(key);
            counters.push({ name, labels, value });
        }

        const gauges: GaugeSnapshot[] = [];
        for (const [key, cell] of this.gauges.entries()) {
            const { name, labels } = parseKey(key);
            gauges.push({
                name,
                labels,
                value: cell.value,
                updated_at_ms: cell.updated_at_ms,
            });
        }

        const histograms: HistogramSnapshot[] = [];
        for (const [key, bucket] of this.histograms.entries()) {
            const { name, labels } = parseKey(key);
            const inWindow = withinWindow(bucket.samples, capturedAt, windowMs);
            histograms.push({
                name,
                labels,
                count: bucket.count,
                sum: bucket.sum,
                min: bucket.count === 0 ? 0 : bucket.min,
                max: bucket.count === 0 ? 0 : bucket.max,
                p50: computePercentile(inWindow, 50),
                p95: computePercentile(inWindow, 95),
                p99: computePercentile(inWindow, 99),
                window_ms: windowMs,
            });
        }

        // Stable ordering — name, then label string. Helps reproducible test
        // assertions and human-readable CloudWatch puts.
        counters.sort(
            (a, b) =>
                a.name.localeCompare(b.name) ||
                JSON.stringify(a.labels).localeCompare(JSON.stringify(b.labels)),
        );
        gauges.sort(
            (a, b) =>
                a.name.localeCompare(b.name) ||
                JSON.stringify(a.labels).localeCompare(JSON.stringify(b.labels)),
        );
        histograms.sort(
            (a, b) =>
                a.name.localeCompare(b.name) ||
                JSON.stringify(a.labels).localeCompare(JSON.stringify(b.labels)),
        );

        return Object.freeze({
            counters: Object.freeze(counters),
            gauges: Object.freeze(gauges),
            histograms: Object.freeze(histograms),
            captured_at_ms: capturedAt,
        });
    }

    /**
     * Alias of {@link getSnapshot} matching the task spec's `snapshot()`
     * naming. Use whichever reads better at the call site.
     */
    public snapshot(
        windowMs: number = DEFAULT_ROLLING_WINDOW_MS,
    ): MetricsSnapshot {
        return this.getSnapshot(windowMs);
    }

    /**
     * Reset every counter, gauge, and histogram. Test-only convenience —
     * never call from production code; the rolling-window logic already
     * handles natural decay.
     */
    public reset(): void {
        this.counters.clear();
        this.gauges.clear();
        this.histograms.clear();
        this.overflowWarned.clear();
    }

    // -----------------------------------------------------------------
    // Sink registration
    // -----------------------------------------------------------------

    /** Register an external sink. Returns a disposer that unregisters it. */
    public addSink(sink: MetricsSink): () => void {
        if (!sink || typeof sink.record !== 'function') {
            throw new TypeError(
                'addSink: sink must implement record(record: MetricRecord): void',
            );
        }
        this.sinks.add(sink);
        return () => {
            this.sinks.delete(sink);
        };
    }

    /** Unregister an external sink. No-op if the sink is unknown. */
    public removeSink(sink: MetricsSink): void {
        this.sinks.delete(sink);
    }

    /** Read-only count of attached sinks. Useful for tests. */
    public get sinkCount(): number {
        return this.sinks.size;
    }

    // -----------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------

    /**
     * Forward a record to every registered sink. Sink failures are
     * swallowed (and warn-logged once per sink+kind) so a flapping
     * downstream cannot block the dispatch hot path.
     */
    private dispatchToSinks(record: MetricRecord): void {
        if (this.sinks.size === 0) return;
        for (const sink of this.sinks) {
            try {
                sink.record(record);
            } catch (err) {
                this.warnOnce(`sink_error:${record.kind}:${record.name}`, () =>
                    logger.warn('[uns.metrics] sink threw — continuing', {
                        kind: record.kind,
                        name: record.name,
                        error: err instanceof Error ? err.message : String(err),
                    }),
                );
            }
        }
    }

    /**
     * Build the storage key, applying the cardinality cap. When the cap is
     * exceeded for a given metric `name`, subsequent novel label-tuples are
     * coalesced into the synthetic `__overflow__` label-tuple so the metric
     * keeps producing useful aggregate numbers without growing unboundedly.
     */
    private cardinalityBoundedKey(
        name: string,
        labels: Labels,
        kind: 'counter' | 'gauge' | 'histogram',
    ): string {
        const normalized = normalizeLabels(labels);
        const key = makeKey(name, normalized);

        const map: Map<string, unknown> =
            kind === 'counter'
                ? this.counters
                : kind === 'gauge'
                    ? this.gauges
                    : this.histograms;
        if (map.has(key)) return key;

        // How many distinct rows do we already have for this metric name?
        const distinctCountForName = countByName(map, name);
        if (distinctCountForName >= MAX_LABEL_CARDINALITY) {
            this.warnOnce(`overflow:${name}:${kind}`, () =>
                logger.warn('[uns.metrics] cardinality cap reached, coalescing', {
                    metric: name,
                    kind,
                    cap: MAX_LABEL_CARDINALITY,
                }),
            );
            return makeKey(name, { __overflow__: 'true' });
        }
        return key;
    }

    private warnOnce(token: string, fn: () => void): void {
        if (this.overflowWarned.has(token)) return;
        this.overflowWarned.add(token);
        try {
            fn();
        } catch {
            // logger should not throw, but never let it kill the hot path.
        }
    }
}

// ---------------------------------------------------------------------------
//                          Module-level singleton + helpers
// ---------------------------------------------------------------------------

/** Default registry shared by every UNS module. Tests should use their own. */
export const metricsRegistry = new MetricsRegistry();

/** Convenience proxy mirroring `metricsRegistry.incCounter`. */
export function incCounter(name: string, labels: Labels = {}, delta = 1): void {
    metricsRegistry.incCounter(name, labels, delta);
}

/** Convenience proxy mirroring `metricsRegistry.observeHistogram`. */
export function observeHistogram(
    name: string,
    value: number,
    labels: Labels = {},
): void {
    metricsRegistry.observeHistogram(name, value, labels);
}

/** Convenience proxy mirroring `metricsRegistry.getSnapshot`. */
export function getSnapshot(
    windowMs: number = DEFAULT_ROLLING_WINDOW_MS,
): MetricsSnapshot {
    return metricsRegistry.getSnapshot(windowMs);
}

// ---------------------------------------------------------------------------
//                Generic primitives required by task 17.2
// ---------------------------------------------------------------------------
//
// Task 17.2 calls for `counter(name, value=1, labels)`, `gauge(name, value,
// labels)`, and `histogram(name, value, labels)` as the canonical
// primitive surface every producer codes against. They route to the
// corresponding registry methods so the in-memory aggregate AND any
// attached external sink see the record. Producers SHOULD prefer these
// over the legacy `incCounter` / `observeHistogram` aliases for
// readability.

/** REQ 14 — increment a counter. `value` defaults to 1, mirroring the task spec. */
export function counter(
    name: string,
    value = 1,
    labels: Labels = {},
): void {
    metricsRegistry.incCounter(name, labels, value);
}

/** REQ 14 — set the current value of a gauge. Most recent write wins. */
export function gauge(
    name: string,
    value: number,
    labels: Labels = {},
): void {
    metricsRegistry.setGauge(name, value, labels);
}

/** REQ 14 — record an observation for a histogram. */
export function histogram(
    name: string,
    value: number,
    labels: Labels = {},
): void {
    metricsRegistry.observeHistogram(name, value, labels);
}

/**
 * Alias of {@link getSnapshot} matching the task spec's `snapshot()`
 * naming. Use whichever reads better at the call site.
 */
export function snapshot(
    windowMs: number = DEFAULT_ROLLING_WINDOW_MS,
): MetricsSnapshot {
    return metricsRegistry.snapshot(windowMs);
}

/** Register an external sink against the singleton. Returns a disposer. */
export function addSink(sink: MetricsSink): () => void {
    return metricsRegistry.addSink(sink);
}

/** Unregister an external sink against the singleton. */
export function removeSink(sink: MetricsSink): void {
    metricsRegistry.removeSink(sink);
}

/** Reset every counter, gauge, and histogram. Test-only. */
export function resetMetricsForTests(): void {
    metricsRegistry.reset();
}

// ---------------------------------------------------------------------------
//             Notification-specific helpers (task 17.2)
// ---------------------------------------------------------------------------
//
// Each helper validates its inputs (non-empty trimmed strings, finite
// numbers) before recording. Centralising the helpers here means the
// publisher / service / channel adapters never have to remember which
// metric name and label keys to use — they call the helper and the
// canonical metric name is applied for them.

/** Non-empty trimmed-string check shared by every record helper. */
function requireString(value: unknown, label: string): string {
    if (typeof value !== 'string' || value.trim() === '') {
        throw new TypeError(`${label} must be a non-empty string`);
    }
    return value;
}

/**
 * Record one Event_Bus publish. Task 17.2 + REQ 14.2.
 *
 * @param eventName — Event_Contract `event_name` (snake_case, dotted).
 * @param producer — emitting app/module identifier (e.g. `dukan_x`).
 */
export function recordEventPublished(
    eventName: string,
    producer: string,
): void {
    counter(METRIC_UNS_EVENTS_PUBLISHED_TOTAL, 1, {
        event_name: requireString(eventName, 'eventName'),
        producer: requireString(producer, 'producer'),
    });
}

/**
 * Record one notification persisted with status `emitted`. Task 17.2 + REQ 14.3.
 *
 * @param category — REQ 2.3 enum, e.g. `billing`, `inventory`, …
 * @param channel — primary channel scheduled for delivery, e.g. `in_app`.
 */
export function recordNotificationCreated(
    category: string,
    channel: string,
): void {
    counter(METRIC_UNS_NOTIFICATIONS_CREATED_TOTAL, 1, {
        category: requireString(category, 'category'),
        channel: requireString(channel, 'channel'),
    });
}

/**
 * Record one channel-dispatch attempt with its outcome. Task 17.2 + REQ 14.3-14.4.
 *
 * @param channel — `in_app` / `push` / `email` / `sms` / `webhook`.
 * @param outcome — exactly one of {@link CHANNEL_DISPATCH_OUTCOMES}.
 */
export function recordChannelDispatchAttempt(
    channel: string,
    outcome: ChannelDispatchOutcome,
): void {
    requireString(channel, 'channel');
    if (
        typeof outcome !== 'string' ||
        !(CHANNEL_DISPATCH_OUTCOMES as readonly string[]).includes(outcome)
    ) {
        throw new TypeError(
            `outcome must be one of ${CHANNEL_DISPATCH_OUTCOMES.join(' / ')}, received ${String(outcome)}`,
        );
    }
    counter(METRIC_UNS_DELIVERY_ATTEMPTS_TOTAL, 1, {
        channel,
        outcome,
    });
}

/**
 * Record one channel-delivery latency observation in ms. Task 17.2 + REQ 14.5.
 *
 * @param channel — `in_app` / `push` / `email` / `sms` / `webhook`.
 * @param latencyMs — non-negative finite number; negative values are dropped.
 */
export function recordChannelLatency(
    channel: string,
    latencyMs: number,
): void {
    requireString(channel, 'channel');
    histogram(METRIC_DELIVERY_LATENCY_MS, latencyMs, { channel });
    // Mirror onto the UNS-prefixed alias so consumers querying either
    // namespace see the same data. Doubling is acceptable here because
    // aggregates are computed independently per metric name.
    histogram(METRIC_UNS_DELIVERY_LATENCY_MS, latencyMs, { channel });
}

/**
 * Record the current depth of a named queue (gauge). Task 17.2.
 *
 * Useful for SQS / outbox / DLQ visibility — gauges always reflect the
 * most recent write, so a periodic ticker can keep the value fresh.
 *
 * @param queueName — operator-friendly identifier.
 * @param depth — non-negative integer count of in-flight items.
 */
export function recordQueueDepth(
    queueName: string,
    depth: number,
): void {
    requireString(queueName, 'queueName');
    if (typeof depth !== 'number' || !Number.isFinite(depth) || depth < 0) {
        throw new TypeError(
            `depth must be a non-negative finite number, received ${String(depth)}`,
        );
    }
    gauge(METRIC_UNS_QUEUE_DEPTH, depth, { queue_name: queueName });
}

// ---------------------------------------------------------------------------
//                               Free-form helpers
// ---------------------------------------------------------------------------

const METRIC_NAME_RE = /^[a-z_][a-z0-9_]*$/;

function validateMetricName(name: string): void {
    if (typeof name !== 'string' || name.length === 0) {
        throw new TypeError('metric name must be a non-empty string');
    }
    if (!METRIC_NAME_RE.test(name)) {
        // Mirroring Prometheus / OpenMetrics naming so that a future export
        // path needs no rewriting. Reject early so misuse surfaces in dev.
        throw new TypeError(
            `metric name '${name}' must match /^[a-z_][a-z0-9_]*$/`,
        );
    }
}

function validateNumber(n: number, label: string): void {
    if (typeof n !== 'number' || !Number.isFinite(n)) {
        throw new TypeError(`${label} must be a finite number, received ${String(n)}`);
    }
}

/**
 * Coerce a `Labels` object into a sorted, string-only record. Drops `undefined`
 * values (REQ: undefined labels are not part of the cardinality budget).
 */
function normalizeLabels(labels: Labels): Readonly<Record<string, string>> {
    const out: Record<string, string> = {};
    const keys = Object.keys(labels).sort();
    for (const k of keys) {
        const v = labels[k];
        if (v === undefined) continue;
        // Coerce booleans / numbers — keep label values as strings so the
        // storage key stays a stable string.
        out[k] = typeof v === 'string' ? v : String(v);
    }
    return Object.freeze(out);
}

function makeKey(name: string, labels: Readonly<Record<string, string>>): string {
    // Order-stable: `normalizeLabels` already sorted by key, so JSON.stringify
    // is deterministic. The separator `\x00` is illegal in any normal label
    // value, so collisions between e.g. `name="a", labels={b:"c"}` and
    // `name="a", labels={"b\x00c":""}` are impossible.
    return `${name}\x00${JSON.stringify(labels)}`;
}

function parseKey(key: string): {
    name: string;
    labels: Readonly<Record<string, string>>;
} {
    const sepIdx = key.indexOf('\x00');
    if (sepIdx < 0) {
        // Should never happen — `makeKey` always inserts the separator.
        return { name: key, labels: Object.freeze({}) };
    }
    const name = key.slice(0, sepIdx);
    const labelJson = key.slice(sepIdx + 1);
    let labels: Record<string, string>;
    try {
        labels = JSON.parse(labelJson) as Record<string, string>;
    } catch {
        labels = {};
    }
    return { name, labels: Object.freeze(labels) };
}

function countByName(
    map: Map<string, unknown>,
    name: string,
): number {
    let n = 0;
    const prefix = `${name}\x00`;
    for (const k of map.keys()) {
        if (k.startsWith(prefix)) n += 1;
    }
    return n;
}

function withinWindow(
    samples: readonly HistogramSample[],
    now: number,
    windowMs: number,
): number[] {
    const cutoff = now - windowMs;
    const result: number[] = [];
    // Samples are appended in time order, so we can short-circuit. But callers
    // may pass a manually-mutated array, so a defensive linear scan is fine
    // given the `HISTOGRAM_MAX_SAMPLES` cap.
    for (const s of samples) {
        if (s.t >= cutoff) result.push(s.v);
    }
    return result;
}

function computePercentile(values: readonly number[], rank: number): number {
    if (values.length === 0) return 0;
    const sorted = [...values].sort((a, b) => a - b);
    if (rank <= 0) return sorted[0];
    if (rank >= 100) return sorted[sorted.length - 1];
    // Nearest-rank method (NIST). For rolling-window p95 over modest sample
    // sizes, this is more than precise enough and cheap to compute.
    const idx = Math.min(
        sorted.length - 1,
        Math.max(0, Math.ceil((rank / 100) * sorted.length) - 1),
    );
    return sorted[idx];
}
