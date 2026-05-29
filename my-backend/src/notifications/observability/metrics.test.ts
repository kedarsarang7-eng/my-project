// ============================================================================
// Notifications Observability — Metrics Surface tests (UNS Task 17.2)
// ============================================================================
//
// Unit tests for the in-memory metrics surface introduced by task 17.2.
//
// Coverage:
//   * incCounter increments — REQ 14.2-14.4
//   * observeHistogram records and computes p50/p95/p99 — REQ 14.5
//   * Rolling-window expiration (samples older than window are excluded)
//   * Label cardinality stays bounded (overflow bucket)
//   * Snapshot shape, ordering, and immutability
//   * Input validation (name regex, finite number, non-negative observation)
// ============================================================================

import {
    CHANNEL_DISPATCH_OUTCOMES,
    DEFAULT_ROLLING_WINDOW_MS,
    HISTOGRAM_MAX_SAMPLES,
    KNOWN_METRIC_NAMES,
    MAX_LABEL_CARDINALITY,
    MetricsRegistry,
    METRIC_DELIVERY_LATENCY_MS,
    METRIC_EVENTS_EMITTED_TOTAL,
    METRIC_NOTIFICATIONS_DISPATCHED_TOTAL,
    METRIC_NOTIFICATIONS_FAILED_TOTAL,
    METRIC_UNS_DEDUP_HITS_TOTAL,
    METRIC_UNS_DELIVERY_ATTEMPTS_TOTAL,
    METRIC_UNS_DELIVERY_LATENCY_MS,
    METRIC_UNS_EVENTS_PUBLISHED_TOTAL,
    METRIC_UNS_NOTIFICATIONS_CREATED_TOTAL,
    METRIC_UNS_PREFERENCE_REJECTIONS_TOTAL,
    METRIC_UNS_PUBLISH_RATE_LIMIT_REJECTIONS_TOTAL,
    METRIC_UNS_QUEUE_DEPTH,
    addSink,
    counter,
    gauge,
    getSnapshot,
    histogram,
    metricsRegistry,
    recordChannelDispatchAttempt,
    recordChannelLatency,
    recordEventPublished,
    recordNotificationCreated,
    recordQueueDepth,
    removeSink,
    resetMetricsForTests,
    snapshot,
} from './metrics';
import type { MetricRecord, MetricsSink } from './metrics';

// Silence the cardinality-overflow warning during tests.
jest.mock('../../utils/logger', () => ({
    logger: {
        debug: jest.fn(),
        info: jest.fn(),
        warn: jest.fn(),
        error: jest.fn(),
    },
}));

// ---------------------------------------------------------------------------
//                               Helpers
// ---------------------------------------------------------------------------

/** Mutable clock so we can advance time deterministically inside a test. */
function makeClock(start: number) {
    let t = start;
    return {
        now: () => t,
        advance(ms: number) {
            t += ms;
        },
    };
}

// ---------------------------------------------------------------------------
//                            Constant declarations
// ---------------------------------------------------------------------------

describe('UNS metrics — constants', () => {
    it('exposes every required REQ 14 metric name', () => {
        expect(METRIC_EVENTS_EMITTED_TOTAL).toBe('events_emitted_total');
        expect(METRIC_NOTIFICATIONS_DISPATCHED_TOTAL).toBe(
            'notifications_dispatched_total',
        );
        expect(METRIC_NOTIFICATIONS_FAILED_TOTAL).toBe(
            'notifications_failed_total',
        );
        expect(METRIC_DELIVERY_LATENCY_MS).toBe('delivery_latency_ms');
    });

    it('exposes the wider UNS counter set called out by the task', () => {
        expect(METRIC_UNS_EVENTS_PUBLISHED_TOTAL).toBe('uns_events_published_total');
        expect(METRIC_UNS_NOTIFICATIONS_CREATED_TOTAL).toBe(
            'uns_notifications_created_total',
        );
        expect(METRIC_UNS_DELIVERY_ATTEMPTS_TOTAL).toBe(
            'uns_delivery_attempts_total',
        );
        expect(METRIC_UNS_PREFERENCE_REJECTIONS_TOTAL).toBe(
            'uns_preference_rejections_total',
        );
        expect(METRIC_UNS_DEDUP_HITS_TOTAL).toBe('uns_dedup_hits_total');
        expect(METRIC_UNS_PUBLISH_RATE_LIMIT_REJECTIONS_TOTAL).toBe(
            'uns_publish_rate_limit_rejections_total',
        );
        expect(METRIC_UNS_DELIVERY_LATENCY_MS).toBe('uns_delivery_latency_ms');
        expect(METRIC_UNS_QUEUE_DEPTH).toBe('uns_queue_depth');
    });

    it('lists every constant in KNOWN_METRIC_NAMES', () => {
        for (const name of [
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
        ]) {
            expect(KNOWN_METRIC_NAMES).toContain(name);
        }
    });

    it('exposes the closed channel-dispatch outcome alphabet', () => {
        expect(CHANNEL_DISPATCH_OUTCOMES).toEqual(['success', 'failure', 'retry']);
    });
});

// ---------------------------------------------------------------------------
//                                Counters
// ---------------------------------------------------------------------------

describe('UNS metrics — incCounter', () => {
    it('increments a counter and aggregates per label tuple', () => {
        const reg = new MetricsRegistry();
        reg.incCounter(METRIC_EVENTS_EMITTED_TOTAL, {
            event_name: 'invoice.payment.received',
            priority: 'high',
            source_app: 'dukan_x',
        });
        reg.incCounter(METRIC_EVENTS_EMITTED_TOTAL, {
            event_name: 'invoice.payment.received',
            priority: 'high',
            source_app: 'dukan_x',
        });
        reg.incCounter(METRIC_EVENTS_EMITTED_TOTAL, {
            event_name: 'invoice.payment.received',
            priority: 'high',
            source_app: 'school_admin_app',
        });

        const snap = reg.getSnapshot();
        const rows = snap.counters.filter(
            (c) => c.name === METRIC_EVENTS_EMITTED_TOTAL,
        );
        expect(rows).toHaveLength(2);
        const dukan = rows.find((r) => r.labels.source_app === 'dukan_x');
        const school = rows.find(
            (r) => r.labels.source_app === 'school_admin_app',
        );
        expect(dukan?.value).toBe(2);
        expect(school?.value).toBe(1);
    });

    it('treats label-key order as irrelevant', () => {
        const reg = new MetricsRegistry();
        reg.incCounter(METRIC_NOTIFICATIONS_DISPATCHED_TOTAL, {
            event_name: 'a.b.c',
            channel: 'in_app',
            priority: 'normal',
        });
        reg.incCounter(METRIC_NOTIFICATIONS_DISPATCHED_TOTAL, {
            priority: 'normal',
            channel: 'in_app',
            event_name: 'a.b.c',
        });

        const snap = reg.getSnapshot();
        const rows = snap.counters.filter(
            (c) => c.name === METRIC_NOTIFICATIONS_DISPATCHED_TOTAL,
        );
        expect(rows).toHaveLength(1);
        expect(rows[0].value).toBe(2);
    });

    it('coerces non-string label values', () => {
        const reg = new MetricsRegistry();
        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, {
            event_name: 'a.b.c',
            attempt: 3,
            retried: true,
        });

        const row = reg
            .getSnapshot()
            .counters.find((c) => c.name === METRIC_UNS_DEDUP_HITS_TOTAL);
        expect(row).toBeDefined();
        expect(row!.labels).toEqual({
            event_name: 'a.b.c',
            attempt: '3',
            retried: 'true',
        });
        expect(row!.value).toBe(1);
    });

    it('drops undefined label values without polluting cardinality', () => {
        const reg = new MetricsRegistry();
        reg.incCounter(METRIC_UNS_EVENTS_PUBLISHED_TOTAL, {
            event_name: 'a.b.c',
            priority: 'low',
            source_app: undefined,
        });
        reg.incCounter(METRIC_UNS_EVENTS_PUBLISHED_TOTAL, {
            event_name: 'a.b.c',
            priority: 'low',
        });

        const rows = reg
            .getSnapshot()
            .counters.filter(
                (c) => c.name === METRIC_UNS_EVENTS_PUBLISHED_TOTAL,
            );
        expect(rows).toHaveLength(1);
        expect(rows[0].value).toBe(2);
        expect(rows[0].labels).not.toHaveProperty('source_app');
    });

    it('ignores non-positive deltas', () => {
        const reg = new MetricsRegistry();
        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'x.y.z' }, 5);
        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'x.y.z' }, 0);
        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'x.y.z' }, -3);

        const row = reg
            .getSnapshot()
            .counters.find((c) => c.name === METRIC_UNS_DEDUP_HITS_TOTAL);
        expect(row?.value).toBe(5);
    });

    it('rejects malformed metric names', () => {
        const reg = new MetricsRegistry();
        expect(() => reg.incCounter('Not-A-Valid-Name', {})).toThrow(TypeError);
        expect(() => reg.incCounter('', {})).toThrow(TypeError);
        expect(() => reg.incCounter('1leading_digit', {})).toThrow(TypeError);
    });

    it('rejects non-finite deltas', () => {
        const reg = new MetricsRegistry();
        expect(() =>
            reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, {}, NaN),
        ).toThrow(TypeError);
        expect(() =>
            reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, {}, Infinity),
        ).toThrow(TypeError);
    });
});

// ---------------------------------------------------------------------------
//                                Histograms
// ---------------------------------------------------------------------------

describe('UNS metrics — observeHistogram', () => {
    it('records a sample and exposes count / sum / min / max / percentiles', () => {
        const clock = makeClock(1_000_000);
        const reg = new MetricsRegistry({ now: clock.now });

        for (let i = 1; i <= 100; i += 1) {
            reg.observeHistogram(METRIC_DELIVERY_LATENCY_MS, i, {
                channel: 'in_app',
            });
        }

        const snap = reg.getSnapshot();
        const row = snap.histograms.find(
            (h) => h.name === METRIC_DELIVERY_LATENCY_MS,
        );
        expect(row).toBeDefined();
        expect(row!.count).toBe(100);
        expect(row!.sum).toBe((100 * 101) / 2);
        expect(row!.min).toBe(1);
        expect(row!.max).toBe(100);
        // Nearest-rank: ceil(0.5 * 100) - 1 = 49 → sorted[49] = 50.
        expect(row!.p50).toBe(50);
        // ceil(0.95 * 100) - 1 = 94 → sorted[94] = 95.
        expect(row!.p95).toBe(95);
        // ceil(0.99 * 100) - 1 = 98 → sorted[98] = 99.
        expect(row!.p99).toBe(99);
        expect(row!.window_ms).toBe(DEFAULT_ROLLING_WINDOW_MS);
    });

    it('separates samples by label tuple', () => {
        const reg = new MetricsRegistry();
        reg.observeHistogram(METRIC_DELIVERY_LATENCY_MS, 100, {
            channel: 'in_app',
        });
        reg.observeHistogram(METRIC_DELIVERY_LATENCY_MS, 1000, {
            channel: 'email',
        });

        const rows = reg
            .getSnapshot()
            .histograms.filter((h) => h.name === METRIC_DELIVERY_LATENCY_MS);
        expect(rows).toHaveLength(2);

        const inApp = rows.find((r) => r.labels.channel === 'in_app');
        const email = rows.find((r) => r.labels.channel === 'email');
        expect(inApp?.max).toBe(100);
        expect(email?.max).toBe(1000);
    });

    it('only counts in-window samples toward percentile calculations', () => {
        const clock = makeClock(0);
        const reg = new MetricsRegistry({ now: clock.now });

        // Drop a slow sample, then advance well past the window before the
        // fast samples — the slow one must NOT skew the rolling p95.
        reg.observeHistogram(METRIC_DELIVERY_LATENCY_MS, 9_999, {
            channel: 'in_app',
        });
        clock.advance(DEFAULT_ROLLING_WINDOW_MS + 1_000);
        for (let i = 0; i < 20; i += 1) {
            reg.observeHistogram(METRIC_DELIVERY_LATENCY_MS, 10, {
                channel: 'in_app',
            });
        }

        const p95InWindow = reg.p95(METRIC_DELIVERY_LATENCY_MS, {
            channel: 'in_app',
        });
        expect(p95InWindow).toBe(10);

        // Total count / sum / max are cumulative — they should still see the
        // 9_999 ms outlier — that's what makes them useful for cumulative
        // dashboards even after the rolling-percentile decays.
        const row = reg
            .getSnapshot()
            .histograms.find((h) => h.name === METRIC_DELIVERY_LATENCY_MS);
        expect(row?.count).toBe(21);
        expect(row?.max).toBe(9_999);
    });

    it('returns 0 when no samples are inside the window', () => {
        const reg = new MetricsRegistry();
        expect(
            reg.p95(METRIC_DELIVERY_LATENCY_MS, { channel: 'never_observed' }),
        ).toBe(0);
    });

    it('caps the per-tuple sample buffer at HISTOGRAM_MAX_SAMPLES', () => {
        const reg = new MetricsRegistry();
        for (let i = 0; i < HISTOGRAM_MAX_SAMPLES + 100; i += 1) {
            reg.observeHistogram(METRIC_DELIVERY_LATENCY_MS, i, {
                channel: 'in_app',
            });
        }

        const row = reg
            .getSnapshot()
            .histograms.find((h) => h.name === METRIC_DELIVERY_LATENCY_MS);
        // count / sum reflect every sample (cumulative). The internal sample
        // buffer is capped — verified indirectly by the percentile output:
        // only the most recent HISTOGRAM_MAX_SAMPLES samples count, so the
        // minimum in-window value should be at least 100 (the eviction
        // boundary).
        expect(row?.count).toBe(HISTOGRAM_MAX_SAMPLES + 100);
        expect(row!.p50).toBeGreaterThanOrEqual(100);
    });

    it('drops negative observations without throwing', () => {
        const reg = new MetricsRegistry();
        // Should not throw — we keep the hot path resilient and let the
        // logger warn-once.
        expect(() =>
            reg.observeHistogram(METRIC_DELIVERY_LATENCY_MS, -5, {
                channel: 'in_app',
            }),
        ).not.toThrow();
        const snap = reg.getSnapshot();
        const row = snap.histograms.find(
            (h) => h.name === METRIC_DELIVERY_LATENCY_MS,
        );
        expect(row).toBeUndefined();
    });

    it('rejects non-finite observations', () => {
        const reg = new MetricsRegistry();
        expect(() =>
            reg.observeHistogram(METRIC_DELIVERY_LATENCY_MS, NaN, {
                channel: 'in_app',
            }),
        ).toThrow(TypeError);
        expect(() =>
            reg.observeHistogram(METRIC_DELIVERY_LATENCY_MS, Infinity, {
                channel: 'in_app',
            }),
        ).toThrow(TypeError);
    });
});

// ---------------------------------------------------------------------------
//                          Cardinality bounding
// ---------------------------------------------------------------------------

describe('UNS metrics — label cardinality cap', () => {
    it('coalesces excess label-tuples into the __overflow__ bucket for counters', () => {
        const reg = new MetricsRegistry();
        // Push MAX_LABEL_CARDINALITY + 50 distinct tuples; the surplus must
        // collapse into a single overflow row.
        for (let i = 0; i < MAX_LABEL_CARDINALITY + 50; i += 1) {
            reg.incCounter(METRIC_NOTIFICATIONS_FAILED_TOTAL, {
                event_name: `evt.${i}.x`,
            });
        }

        const rows = reg
            .getSnapshot()
            .counters.filter(
                (c) => c.name === METRIC_NOTIFICATIONS_FAILED_TOTAL,
            );

        // We retain `MAX_LABEL_CARDINALITY` distinct rows plus exactly one
        // overflow row.
        expect(rows.length).toBe(MAX_LABEL_CARDINALITY + 1);
        const overflow = rows.find((r) => r.labels.__overflow__ === 'true');
        expect(overflow).toBeDefined();
        expect(overflow!.value).toBe(50);
    });

    it('coalesces excess label-tuples into the __overflow__ bucket for histograms', () => {
        const reg = new MetricsRegistry();
        for (let i = 0; i < MAX_LABEL_CARDINALITY + 30; i += 1) {
            reg.observeHistogram(METRIC_UNS_DELIVERY_LATENCY_MS, 1, {
                channel: `synthetic_${i}`,
            });
        }

        const rows = reg
            .getSnapshot()
            .histograms.filter(
                (h) => h.name === METRIC_UNS_DELIVERY_LATENCY_MS,
            );
        expect(rows.length).toBe(MAX_LABEL_CARDINALITY + 1);
        const overflow = rows.find((r) => r.labels.__overflow__ === 'true');
        expect(overflow).toBeDefined();
        expect(overflow!.count).toBe(30);
    });

    it('keeps cardinality budgets independent across metric names', () => {
        const reg = new MetricsRegistry();
        for (let i = 0; i < MAX_LABEL_CARDINALITY; i += 1) {
            reg.incCounter(METRIC_NOTIFICATIONS_FAILED_TOTAL, {
                event_name: `a.${i}.x`,
            });
        }
        // A different metric name should still accept fresh label tuples.
        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'fresh' });
        const rows = reg
            .getSnapshot()
            .counters.filter((c) => c.name === METRIC_UNS_DEDUP_HITS_TOTAL);
        expect(rows).toHaveLength(1);
        expect(rows[0].labels).toEqual({ event_name: 'fresh' });
    });
});

// ---------------------------------------------------------------------------
//                                Snapshot
// ---------------------------------------------------------------------------

describe('UNS metrics — getSnapshot', () => {
    it('returns frozen, deterministically ordered rows', () => {
        const reg = new MetricsRegistry();
        reg.incCounter(METRIC_NOTIFICATIONS_DISPATCHED_TOTAL, {
            event_name: 'b.b.b',
            channel: 'email',
            priority: 'high',
        });
        reg.incCounter(METRIC_NOTIFICATIONS_DISPATCHED_TOTAL, {
            event_name: 'a.a.a',
            channel: 'in_app',
            priority: 'high',
        });
        reg.incCounter(METRIC_EVENTS_EMITTED_TOTAL, {
            event_name: 'a.a.a',
            priority: 'high',
            source_app: 'dukan_x',
        });

        const snap = reg.getSnapshot();
        // Frozen guard.
        expect(Object.isFrozen(snap)).toBe(true);
        expect(Object.isFrozen(snap.counters)).toBe(true);

        // Names are in lexicographic order.
        const names = snap.counters.map((c) => c.name);
        const sorted = [...names].sort();
        expect(names).toEqual(sorted);
    });

    it('reports captured_at_ms from the injected clock', () => {
        const clock = makeClock(7_777_777);
        const reg = new MetricsRegistry({ now: clock.now });
        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'a.b.c' });
        expect(reg.getSnapshot().captured_at_ms).toBe(7_777_777);
    });

    it('rejects non-positive window sizes', () => {
        const reg = new MetricsRegistry();
        expect(() => reg.getSnapshot(0)).toThrow(TypeError);
        expect(() => reg.getSnapshot(-1)).toThrow(TypeError);
        expect(() => reg.getSnapshot(NaN)).toThrow(TypeError);
    });

    it('handles a registry that has never been written to', () => {
        const reg = new MetricsRegistry();
        const snap = reg.getSnapshot();
        expect(snap.counters).toHaveLength(0);
        expect(snap.gauges).toHaveLength(0);
        expect(snap.histograms).toHaveLength(0);
    });
});

// ---------------------------------------------------------------------------
//                                Gauges
// ---------------------------------------------------------------------------

describe('UNS metrics — gauge', () => {
    it('records a gauge value and returns it via the snapshot', () => {
        const clock = makeClock(2_000_000);
        const reg = new MetricsRegistry({ now: clock.now });

        reg.setGauge(METRIC_UNS_QUEUE_DEPTH, 42, { queue_name: 'sqs_main' });
        const snap = reg.getSnapshot();

        expect(snap.gauges).toHaveLength(1);
        expect(snap.gauges[0]).toEqual({
            name: METRIC_UNS_QUEUE_DEPTH,
            labels: { queue_name: 'sqs_main' },
            value: 42,
            updated_at_ms: 2_000_000,
        });
    });

    it('overwrites the previous value on subsequent writes', () => {
        const reg = new MetricsRegistry();
        reg.setGauge(METRIC_UNS_QUEUE_DEPTH, 10, { queue_name: 'q' });
        reg.setGauge(METRIC_UNS_QUEUE_DEPTH, 25, { queue_name: 'q' });
        reg.setGauge(METRIC_UNS_QUEUE_DEPTH, 5, { queue_name: 'q' });

        const row = reg
            .getSnapshot()
            .gauges.find((g) => g.labels.queue_name === 'q');
        expect(row?.value).toBe(5);
    });

    it('keeps gauge buckets segregated per label tuple', () => {
        const reg = new MetricsRegistry();
        reg.setGauge(METRIC_UNS_QUEUE_DEPTH, 10, { queue_name: 'sqs_main' });
        reg.setGauge(METRIC_UNS_QUEUE_DEPTH, 99, { queue_name: 'sqs_dlq' });

        const rows = reg
            .getSnapshot()
            .gauges.filter((g) => g.name === METRIC_UNS_QUEUE_DEPTH);
        expect(rows).toHaveLength(2);
        expect(rows.find((r) => r.labels.queue_name === 'sqs_main')?.value).toBe(10);
        expect(rows.find((r) => r.labels.queue_name === 'sqs_dlq')?.value).toBe(99);
    });

    it('accepts zero and negative gauge values', () => {
        const reg = new MetricsRegistry();
        reg.setGauge(METRIC_UNS_QUEUE_DEPTH, 0, { queue_name: 'idle' });
        reg.setGauge('uns_clock_skew_ms', -50, { region: 'eu' });

        const snap = reg.getSnapshot();
        expect(snap.gauges.find((g) => g.labels.queue_name === 'idle')?.value).toBe(0);
        expect(snap.gauges.find((g) => g.name === 'uns_clock_skew_ms')?.value).toBe(-50);
    });

    it('rejects malformed gauge names and non-finite values', () => {
        const reg = new MetricsRegistry();
        expect(() => reg.setGauge('Bad-Name', 1)).toThrow(TypeError);
        expect(() => reg.setGauge(METRIC_UNS_QUEUE_DEPTH, NaN)).toThrow(TypeError);
        expect(() => reg.setGauge(METRIC_UNS_QUEUE_DEPTH, Infinity)).toThrow(TypeError);
    });

    it('clears gauges via reset()', () => {
        const reg = new MetricsRegistry();
        reg.setGauge(METRIC_UNS_QUEUE_DEPTH, 3, { queue_name: 'q' });
        expect(reg.getSnapshot().gauges).toHaveLength(1);
        reg.reset();
        expect(reg.getSnapshot().gauges).toHaveLength(0);
    });
});

// ---------------------------------------------------------------------------
//                  Generic primitives (counter / gauge / histogram)
// ---------------------------------------------------------------------------

describe('UNS metrics — generic primitives', () => {
    afterEach(() => resetMetricsForTests());

    it('counter() defaults value to 1 and routes to the singleton', () => {
        counter(METRIC_UNS_DEDUP_HITS_TOTAL, undefined, {
            event_name: 'a.b.c',
        });
        counter(METRIC_UNS_DEDUP_HITS_TOTAL, 4, { event_name: 'a.b.c' });

        const row = getSnapshot().counters.find(
            (c) => c.name === METRIC_UNS_DEDUP_HITS_TOTAL,
        );
        expect(row?.value).toBe(5);
    });

    it('gauge() records on the singleton and is visible via snapshot()', () => {
        gauge(METRIC_UNS_QUEUE_DEPTH, 7, { queue_name: 'sqs_main' });
        const row = snapshot().gauges.find(
            (g) => g.name === METRIC_UNS_QUEUE_DEPTH,
        );
        expect(row?.value).toBe(7);
    });

    it('histogram() records an observation on the singleton', () => {
        for (const v of [10, 20, 30, 40, 50]) {
            histogram(METRIC_DELIVERY_LATENCY_MS, v, { channel: 'sms' });
        }
        const row = getSnapshot().histograms.find(
            (h) =>
                h.name === METRIC_DELIVERY_LATENCY_MS &&
                h.labels.channel === 'sms',
        );
        expect(row?.count).toBe(5);
        expect(row?.sum).toBe(150);
        expect(row?.min).toBe(10);
        expect(row?.max).toBe(50);
    });

    it('counter() default-1 with no value matches counter(name, 1)', () => {
        counter(METRIC_UNS_DEDUP_HITS_TOTAL, undefined, { event_name: 'x' });
        counter(METRIC_UNS_DEDUP_HITS_TOTAL, undefined, { event_name: 'x' });
        const row = getSnapshot().counters.find(
            (c) => c.labels.event_name === 'x',
        );
        expect(row?.value).toBe(2);
    });
});

// ---------------------------------------------------------------------------
//                  Notification-specific record helpers
// ---------------------------------------------------------------------------

describe('UNS metrics — record helpers', () => {
    afterEach(() => resetMetricsForTests());

    it('recordEventPublished increments the publish counter with labels', () => {
        recordEventPublished('invoice.payment.received', 'dukan_x');
        recordEventPublished('invoice.payment.received', 'dukan_x');
        recordEventPublished('invoice.payment.received', 'school_admin_app');

        const rows = getSnapshot().counters.filter(
            (c) => c.name === METRIC_UNS_EVENTS_PUBLISHED_TOTAL,
        );
        expect(rows).toHaveLength(2);
        expect(
            rows.find((r) => r.labels.producer === 'dukan_x')?.value,
        ).toBe(2);
        expect(
            rows.find((r) => r.labels.producer === 'school_admin_app')?.value,
        ).toBe(1);
    });

    it('recordNotificationCreated segregates per category and channel', () => {
        recordNotificationCreated('billing', 'in_app');
        recordNotificationCreated('billing', 'email');
        recordNotificationCreated('inventory', 'push');

        const rows = getSnapshot().counters.filter(
            (c) => c.name === METRIC_UNS_NOTIFICATIONS_CREATED_TOTAL,
        );
        expect(rows).toHaveLength(3);
        for (const r of rows) {
            expect(r.labels).toHaveProperty('category');
            expect(r.labels).toHaveProperty('channel');
            expect(r.value).toBe(1);
        }
    });

    it('recordChannelDispatchAttempt enforces the closed outcome alphabet', () => {
        recordChannelDispatchAttempt('push', 'success');
        recordChannelDispatchAttempt('push', 'failure');
        recordChannelDispatchAttempt('push', 'retry');
        recordChannelDispatchAttempt('push', 'success');

        const rows = getSnapshot().counters.filter(
            (c) => c.name === METRIC_UNS_DELIVERY_ATTEMPTS_TOTAL,
        );
        // Three distinct outcomes — `success` was incremented twice.
        expect(rows).toHaveLength(3);
        expect(
            rows.find((r) => r.labels.outcome === 'success')?.value,
        ).toBe(2);
        expect(
            rows.find((r) => r.labels.outcome === 'failure')?.value,
        ).toBe(1);
        expect(
            rows.find((r) => r.labels.outcome === 'retry')?.value,
        ).toBe(1);

        // Reject any out-of-alphabet outcome.
        expect(() =>
            recordChannelDispatchAttempt('push', 'ok' as never),
        ).toThrow(TypeError);
        expect(() =>
            recordChannelDispatchAttempt('push', '' as never),
        ).toThrow(TypeError);
    });

    it('recordChannelLatency feeds both the canonical and UNS-prefixed histograms', () => {
        for (const v of [50, 100, 150, 200]) {
            recordChannelLatency('email', v);
        }

        const canonical = getSnapshot().histograms.find(
            (h) =>
                h.name === METRIC_DELIVERY_LATENCY_MS &&
                h.labels.channel === 'email',
        );
        const uns = getSnapshot().histograms.find(
            (h) =>
                h.name === METRIC_UNS_DELIVERY_LATENCY_MS &&
                h.labels.channel === 'email',
        );
        expect(canonical?.count).toBe(4);
        expect(uns?.count).toBe(4);
        expect(canonical?.max).toBe(200);
        expect(uns?.max).toBe(200);
    });

    it('recordQueueDepth writes a gauge keyed by queue_name', () => {
        recordQueueDepth('sqs_main', 5);
        recordQueueDepth('sqs_dlq', 0);
        recordQueueDepth('sqs_main', 11); // overwrite

        const rows = getSnapshot().gauges.filter(
            (g) => g.name === METRIC_UNS_QUEUE_DEPTH,
        );
        expect(rows).toHaveLength(2);
        expect(
            rows.find((r) => r.labels.queue_name === 'sqs_main')?.value,
        ).toBe(11);
        expect(
            rows.find((r) => r.labels.queue_name === 'sqs_dlq')?.value,
        ).toBe(0);
    });

    it('record helpers reject invalid string inputs', () => {
        expect(() => recordEventPublished('', 'dukan_x')).toThrow(TypeError);
        expect(() =>
            recordEventPublished('invoice.payment.received', '   '),
        ).toThrow(TypeError);
        expect(() => recordNotificationCreated('billing', '')).toThrow(TypeError);
        expect(() => recordChannelLatency('', 100)).toThrow(TypeError);
        expect(() => recordQueueDepth('', 0)).toThrow(TypeError);
    });

    it('recordQueueDepth rejects non-finite or negative depths', () => {
        expect(() => recordQueueDepth('q', NaN)).toThrow(TypeError);
        expect(() => recordQueueDepth('q', Infinity)).toThrow(TypeError);
        expect(() => recordQueueDepth('q', -1)).toThrow(TypeError);
    });
});

// ---------------------------------------------------------------------------
//                          Pluggable sink contract
// ---------------------------------------------------------------------------

describe('UNS metrics — pluggable sink', () => {
    afterEach(() => resetMetricsForTests());

    function makeRecordingSink() {
        const records: MetricRecord[] = [];
        const sink: MetricsSink = {
            record(r) {
                records.push(r);
            },
        };
        return { sink, records };
    }

    it('forwards every counter increment to a registered sink', () => {
        const reg = new MetricsRegistry();
        const { sink, records } = makeRecordingSink();
        reg.addSink(sink);

        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'a' });
        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'a' }, 3);

        expect(records).toHaveLength(2);
        expect(records[0]).toMatchObject({
            kind: 'counter',
            name: METRIC_UNS_DEDUP_HITS_TOTAL,
            value: 1,
            labels: { event_name: 'a' },
        });
        expect(records[1]).toMatchObject({
            kind: 'counter',
            name: METRIC_UNS_DEDUP_HITS_TOTAL,
            value: 3,
            labels: { event_name: 'a' },
        });
    });

    it('forwards gauge writes to a registered sink', () => {
        const reg = new MetricsRegistry();
        const { sink, records } = makeRecordingSink();
        reg.addSink(sink);

        reg.setGauge(METRIC_UNS_QUEUE_DEPTH, 7, { queue_name: 'q' });

        expect(records).toHaveLength(1);
        expect(records[0]).toMatchObject({
            kind: 'gauge',
            name: METRIC_UNS_QUEUE_DEPTH,
            value: 7,
            labels: { queue_name: 'q' },
        });
    });

    it('forwards histogram observations to a registered sink', () => {
        const reg = new MetricsRegistry();
        const { sink, records } = makeRecordingSink();
        reg.addSink(sink);

        reg.observeHistogram(METRIC_DELIVERY_LATENCY_MS, 42, {
            channel: 'in_app',
        });

        expect(records).toHaveLength(1);
        expect(records[0]).toMatchObject({
            kind: 'histogram',
            name: METRIC_DELIVERY_LATENCY_MS,
            value: 42,
            labels: { channel: 'in_app' },
        });
    });

    it('does not forward when the value is dropped (non-positive delta / negative observation)', () => {
        const reg = new MetricsRegistry();
        const { sink, records } = makeRecordingSink();
        reg.addSink(sink);

        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, {}, 0);
        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, {}, -3);
        reg.observeHistogram(METRIC_DELIVERY_LATENCY_MS, -5, {
            channel: 'in_app',
        });

        expect(records).toHaveLength(0);
    });

    it('returns a disposer that removes the sink', () => {
        const reg = new MetricsRegistry();
        const { sink, records } = makeRecordingSink();
        const dispose = reg.addSink(sink);

        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'x' });
        expect(records).toHaveLength(1);

        dispose();
        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'x' });
        expect(records).toHaveLength(1);
    });

    it('removeSink() detaches a previously registered sink', () => {
        const reg = new MetricsRegistry();
        const { sink, records } = makeRecordingSink();
        reg.addSink(sink);
        reg.removeSink(sink);

        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'x' });
        expect(records).toHaveLength(0);
    });

    it('supports multiple sinks simultaneously', () => {
        const reg = new MetricsRegistry();
        const a = makeRecordingSink();
        const b = makeRecordingSink();
        reg.addSink(a.sink);
        reg.addSink(b.sink);

        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'x' });

        expect(a.records).toHaveLength(1);
        expect(b.records).toHaveLength(1);
    });

    it('isolates a throwing sink from the rest of the pipeline', () => {
        const reg = new MetricsRegistry();
        const throwing: MetricsSink = {
            record() {
                throw new Error('downstream offline');
            },
        };
        const { sink: good, records } = makeRecordingSink();
        reg.addSink(throwing);
        reg.addSink(good);

        // Must not propagate the throw.
        expect(() =>
            reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'x' }),
        ).not.toThrow();
        expect(records).toHaveLength(1);
    });

    it('rejects non-conforming sinks at addSink', () => {
        const reg = new MetricsRegistry();
        expect(() => reg.addSink(null as unknown as MetricsSink)).toThrow(TypeError);
        expect(() =>
            reg.addSink({} as unknown as MetricsSink),
        ).toThrow(TypeError);
    });

    it('accepts sinks pre-registered in the constructor', () => {
        const { sink, records } = makeRecordingSink();
        const reg = new MetricsRegistry({ sinks: [sink] });

        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'x' });
        expect(records).toHaveLength(1);
    });

    it('module-level addSink/removeSink wraps the singleton', () => {
        const { sink, records } = makeRecordingSink();
        const dispose = addSink(sink);

        try {
            counter(METRIC_UNS_DEDUP_HITS_TOTAL, 1, { event_name: 'x' });
            histogram(METRIC_DELIVERY_LATENCY_MS, 12, { channel: 'in_app' });
            gauge(METRIC_UNS_QUEUE_DEPTH, 4, { queue_name: 'q' });

            expect(records).toHaveLength(3);
            expect(records.map((r) => r.kind)).toEqual([
                'counter',
                'histogram',
                'gauge',
            ]);
        } finally {
            dispose();
        }

        // Confirm `removeSink` is also exported and is a no-op for unknown sinks.
        const stranger: MetricsSink = { record() { /* noop */ } };
        expect(() => removeSink(stranger)).not.toThrow();
    });
});

// ---------------------------------------------------------------------------
//                                snapshot() alias
// ---------------------------------------------------------------------------

describe('UNS metrics — snapshot() alias', () => {
    afterEach(() => resetMetricsForTests());

    it('returns the same shape as getSnapshot()', () => {
        counter(METRIC_UNS_DEDUP_HITS_TOTAL, 2, { event_name: 'x' });
        histogram(METRIC_DELIVERY_LATENCY_MS, 99, { channel: 'in_app' });
        gauge(METRIC_UNS_QUEUE_DEPTH, 3, { queue_name: 'q' });

        const a = snapshot();
        const b = getSnapshot();

        // captured_at_ms is non-deterministic across two calls; everything
        // else should match field-for-field.
        expect(a.counters).toEqual(b.counters);
        expect(a.gauges).toEqual(b.gauges);
        expect(a.histograms).toEqual(b.histograms);
    });

    it('is also exposed as a method on MetricsRegistry', () => {
        const reg = new MetricsRegistry();
        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'x' });
        expect(reg.snapshot().counters).toEqual(reg.getSnapshot().counters);
    });

    it('the singleton resetMetricsForTests clears counters, gauges and histograms', () => {
        counter(METRIC_UNS_DEDUP_HITS_TOTAL, 1, { event_name: 'x' });
        gauge(METRIC_UNS_QUEUE_DEPTH, 1, { queue_name: 'q' });
        histogram(METRIC_DELIVERY_LATENCY_MS, 1, { channel: 'in_app' });

        // Pre-condition: the singleton holds at least our writes.
        expect(metricsRegistry.snapshot().counters.length).toBeGreaterThan(0);

        resetMetricsForTests();
        const snap = metricsRegistry.snapshot();
        expect(snap.counters).toHaveLength(0);
        expect(snap.gauges).toHaveLength(0);
        expect(snap.histograms).toHaveLength(0);
    });
});

// ---------------------------------------------------------------------------
//                                Reset
// ---------------------------------------------------------------------------

describe('UNS metrics — reset', () => {
    it('clears every counter and histogram', () => {
        const reg = new MetricsRegistry();
        reg.incCounter(METRIC_UNS_DEDUP_HITS_TOTAL, { event_name: 'x.y.z' });
        reg.observeHistogram(METRIC_DELIVERY_LATENCY_MS, 50, {
            channel: 'in_app',
        });

        reg.reset();
        const snap = reg.getSnapshot();
        expect(snap.counters).toHaveLength(0);
        expect(snap.histograms).toHaveLength(0);
    });
});
