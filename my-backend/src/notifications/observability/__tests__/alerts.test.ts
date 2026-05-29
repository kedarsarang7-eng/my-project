// ============================================================================
// Tests — Per-Channel Failure-Rate Alert (REQ 14.6 + Task 17.3)
// ============================================================================
// Covers:
//   - under threshold: no alert
//   - over threshold: fires with the correct payload
//   - "fires once per breach" — structured log emitted once per episode,
//     subsequent checkAlerts calls keep the alert in the firing list but
//     do not re-emit the structured log
//   - recovery clears the firing flag (and re-arms the structured log)
//   - separate channels evaluated independently
//   - rolling time window prunes stale samples correctly
//   - REQ 14.6: dispatched=0 → alert SHALL NOT fire
//   - subscribers receive every firing alert (and a thrown subscriber
//     does not block other subscribers)
//   - env-var configuration with safe defaults
//   - task-brief: evaluate() API, custom sink, channels-of-interest
//     filter, start/stop lifecycle, provider-driven snapshot mode
// ============================================================================

import { describe, test, expect, beforeEach, afterEach, jest } from '@jest/globals';
import {
    ALERT_EVENT_NAME,
    ALL_CHANNELS,
    DEFAULT_MIN_DISPATCHES,
    DEFAULT_MIN_SAMPLE_SIZE,
    DEFAULT_THRESHOLD,
    DEFAULT_WINDOW_MS,
    FailureRateAlertEngine,
    type ChannelDispatchCounts,
    type DispatchOutcomeProvider,
    type FailureRateAlert,
    createFailureRateAlertEngine,
} from '../alerts';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/**
 * A controllable clock so tests are deterministic. The engine's `now`
 * option calls this function — moving it forward simulates the passage
 * of real time without touching wall clocks or timer fakes.
 */
function makeClock(start = 1_700_000_000_000): {
    now: () => number;
    advance: (ms: number) => void;
    set: (t: number) => void;
} {
    let t = start;
    return {
        now: () => t,
        advance: (ms: number) => {
            t += ms;
        },
        set: (next: number) => {
            t = next;
        },
    };
}

function recordOutcomes(
    engine: FailureRateAlertEngine,
    channel: Parameters<FailureRateAlertEngine['recordDeliveryOutcome']>[0],
    successes: number,
    failures: number,
): void {
    for (let i = 0; i < successes; i += 1) {
        engine.recordDeliveryOutcome(channel, true);
    }
    for (let i = 0; i < failures; i += 1) {
        engine.recordDeliveryOutcome(channel, false);
    }
}

// Silence the structured logs the engine emits during tests so the
// jest output stays focused; we still spy on them to assert the
// "fires once per breach" behaviour.
let warnSpy: jest.SpiedFunction<typeof console.warn>;
let errorSpy: jest.SpiedFunction<typeof console.error>;
let logSpy: jest.SpiedFunction<typeof console.log>;

beforeEach(() => {
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
    errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    logSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
});

afterEach(() => {
    warnSpy.mockRestore();
    errorSpy.mockRestore();
    logSpy.mockRestore();
});

// ---------------------------------------------------------------------------
// Default configuration
// ---------------------------------------------------------------------------

describe('FailureRateAlertEngine — defaults', () => {
    test('reads safe defaults when no overrides and no env vars are set', () => {
        // Defensive: scrub any env overrides another test in the same
        // worker may have left in place.
        delete process.env.UNS_ALERT_WINDOW_MS;
        delete process.env.UNS_ALERT_FAILURE_RATIO;
        delete process.env.UNS_ALERT_MIN_DISPATCHES;

        const engine = createFailureRateAlertEngine();
        const cfg = engine.getConfig();

        expect(cfg.windowMs).toBe(DEFAULT_WINDOW_MS);
        expect(cfg.threshold).toBe(DEFAULT_THRESHOLD);
        expect(cfg.minDispatches).toBe(DEFAULT_MIN_DISPATCHES);
    });
});

// ---------------------------------------------------------------------------
// Under-threshold behaviour
// ---------------------------------------------------------------------------

describe('FailureRateAlertEngine — under threshold', () => {
    test('does not fire when failure ratio is below the threshold', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.1, // 10%
            now: clock.now,
        });

        // 100 successes, 5 failures → 4.76% failure ratio
        recordOutcomes(engine, 'email', 100, 5);

        const firing = engine.checkAlerts();
        expect(firing).toEqual([]);
    });

    test('does not fire when ratio is exactly at threshold (strict >)', () => {
        // REQ 14.6 says "exceeds" the threshold — a value equal to the
        // threshold MUST NOT trigger.
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            now: clock.now,
        });

        // 95 success, 5 fail → ratio == 0.05 exactly
        recordOutcomes(engine, 'sms', 95, 5);

        expect(engine.checkAlerts()).toEqual([]);
    });
});

// ---------------------------------------------------------------------------
// Over-threshold behaviour
// ---------------------------------------------------------------------------

describe('FailureRateAlertEngine — over threshold', () => {
    test('fires for the breaching channel with the correct payload', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            windowMs: 60_000,
            now: clock.now,
        });

        // 80 success, 20 fail → 20% failure ratio (well above 5%)
        recordOutcomes(engine, 'push', 80, 20);

        const firing = engine.checkAlerts();
        expect(firing).toHaveLength(1);
        const alert = firing[0];

        expect(alert.event_name).toBe(ALERT_EVENT_NAME);
        expect(alert.channel).toBe('push');
        expect(alert.failedCount).toBe(20);
        expect(alert.dispatchedCount).toBe(100);
        expect(alert.failureRatio).toBeCloseTo(0.2, 5);
        expect(alert.threshold).toBe(0.05);
        expect(alert.windowMs).toBe(60_000);
        // Severity escalates to 'error' when ratio is >= 2× threshold.
        expect(alert.severity).toBe('error');
        expect(alert.firedAt).toBe(new Date(clock.now()).toISOString());
        expect(alert.windowEnd).toBe(new Date(clock.now()).toISOString());
        expect(alert.windowStart).toBe(
            new Date(clock.now() - 60_000).toISOString(),
        );
    });

    test('uses warning severity when ratio is between threshold and 2× threshold', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            now: clock.now,
        });

        // 92 success, 8 fail → 8% failure ratio (between 5% and 10%)
        recordOutcomes(engine, 'webhook', 92, 8);

        const [alert] = engine.checkAlerts();
        expect(alert.severity).toBe('warning');
    });
});

// ---------------------------------------------------------------------------
// "Fires once per breach episode" behaviour
// ---------------------------------------------------------------------------

describe('FailureRateAlertEngine — fires once per breach episode', () => {
    test('emits the structured log once per episode, recovers, then re-arms', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            windowMs: 60_000,
            now: clock.now,
        });

        // ── Episode 1: breach ──────────────────────────────────────────
        recordOutcomes(engine, 'email', 50, 50); // 50% failure rate
        const firing1 = engine.checkAlerts();
        expect(firing1).toHaveLength(1);
        const warnsAfterFirst = warnSpy.mock.calls.length
            + errorSpy.mock.calls.length;
        expect(warnsAfterFirst).toBeGreaterThanOrEqual(1);

        // Subsequent checkAlerts calls keep the alert in the firing list
        // (so the operator sink can re-publish if it wants), but the
        // structured log MUST NOT re-emit while the episode persists.
        const firing2 = engine.checkAlerts();
        expect(firing2).toHaveLength(1);
        const warnsAfterSecond = warnSpy.mock.calls.length
            + errorSpy.mock.calls.length;
        expect(warnsAfterSecond).toBe(warnsAfterFirst);

        // ── Recover by aging out failures and adding successes ─────────
        clock.advance(120_000); // > windowMs → all old samples drop
        recordOutcomes(engine, 'email', 100, 0);
        const firing3 = engine.checkAlerts();
        expect(firing3).toEqual([]);

        // ── Episode 2: breach again → structured log re-emits ──────────
        recordOutcomes(engine, 'email', 0, 100);
        const warnsBeforeEp2 = warnSpy.mock.calls.length
            + errorSpy.mock.calls.length;
        const firing4 = engine.checkAlerts();
        expect(firing4).toHaveLength(1);
        const warnsAfterEp2 = warnSpy.mock.calls.length
            + errorSpy.mock.calls.length;
        expect(warnsAfterEp2).toBeGreaterThan(warnsBeforeEp2);
    });

    test('subscribers fire on every checkAlerts call while breach persists', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            now: clock.now,
        });

        const seen: string[] = [];
        const dispose = engine.subscribe((alert) => {
            seen.push(`${alert.channel}@${alert.firedAt}`);
        });

        recordOutcomes(engine, 'sms', 0, 50);
        engine.checkAlerts();
        clock.advance(1_000);
        engine.checkAlerts();

        expect(seen).toHaveLength(2);
        expect(seen.every((s) => s.startsWith('sms@'))).toBe(true);

        dispose();
        engine.checkAlerts();
        // No new entries added after the disposer ran.
        expect(seen).toHaveLength(2);
    });

    test('a throwing subscriber does not block other subscribers', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            now: clock.now,
        });

        const calls: string[] = [];
        engine.subscribe(() => {
            throw new Error('boom');
        });
        engine.subscribe(() => {
            calls.push('second');
        });

        recordOutcomes(engine, 'webhook', 0, 10);
        engine.checkAlerts();

        expect(calls).toEqual(['second']);
    });
});

// ---------------------------------------------------------------------------
// Recovery
// ---------------------------------------------------------------------------

describe('FailureRateAlertEngine — recovery', () => {
    test('ratio dropping back below threshold clears the firing state', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            windowMs: 60_000,
            now: clock.now,
        });

        // Breach
        recordOutcomes(engine, 'email', 50, 50);
        expect(engine.checkAlerts()).toHaveLength(1);

        // Inject a flood of successes well within the same window —
        // ratio drops below threshold.
        recordOutcomes(engine, 'email', 5_000, 0);
        expect(engine.checkAlerts()).toEqual([]);
    });

    test('window rolling out leaves dispatched=0 → no fire', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            windowMs: 30_000,
            now: clock.now,
        });

        recordOutcomes(engine, 'sms', 0, 10);
        expect(engine.checkAlerts()).toHaveLength(1);

        // Roll the window forward past every recorded sample.
        clock.advance(60_000);
        const firing = engine.checkAlerts();
        expect(firing).toEqual([]);
    });
});

// ---------------------------------------------------------------------------
// Per-channel independence
// ---------------------------------------------------------------------------

describe('FailureRateAlertEngine — per-channel independence', () => {
    test('one channel breaching does not affect other channels', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            now: clock.now,
        });

        recordOutcomes(engine, 'sms', 0, 100); // 100% failure
        recordOutcomes(engine, 'email', 100, 0); // 0% failure
        recordOutcomes(engine, 'push', 99, 1); // 1% failure (under)
        recordOutcomes(engine, 'webhook', 50, 50); // 50% failure (over)

        const firing = engine.checkAlerts();
        const breached = firing.map((a) => a.channel).sort();
        expect(breached).toEqual(['sms', 'webhook']);
    });

    test('every supported channel can independently reach firing state', () => {
        // Sanity check that the channel allow-list inside the engine
        // matches the spec's five channels — a typo in the channel list
        // would be caught here.
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            now: clock.now,
        });

        for (const channel of ['in_app', 'push', 'email', 'sms', 'webhook'] as const) {
            recordOutcomes(engine, channel, 0, 10);
        }

        const firing = engine.checkAlerts();
        expect(firing.map((a) => a.channel).sort()).toEqual(
            ['email', 'in_app', 'push', 'sms', 'webhook'],
        );
    });
});

// ---------------------------------------------------------------------------
// Rolling time window
// ---------------------------------------------------------------------------

describe('FailureRateAlertEngine — rolling window pruning', () => {
    test('samples older than windowMs are excluded from evaluation', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            windowMs: 10_000,
            now: clock.now,
        });

        // Stale failures (will roll out)
        recordOutcomes(engine, 'email', 0, 50);
        clock.advance(11_000);

        // Fresh successes — ratio inside the live window is 0%.
        recordOutcomes(engine, 'email', 100, 0);

        expect(engine.checkAlerts()).toEqual([]);
    });

    test('partial-window roll: only stale samples drop, fresh ones stay', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            windowMs: 10_000,
            now: clock.now,
        });

        // t=0: 30 failures (stale-to-be)
        recordOutcomes(engine, 'sms', 0, 30);
        clock.advance(11_000);

        // t=11s: 10 failures (fresh)
        recordOutcomes(engine, 'sms', 0, 10);

        const firing = engine.checkAlerts();
        // Only the 10 fresh failures should be in the window.
        expect(firing).toHaveLength(1);
        expect(firing[0].dispatchedCount).toBe(10);
        expect(firing[0].failedCount).toBe(10);
    });
});

// ---------------------------------------------------------------------------
// REQ 14.6 — denominator-zero guard
// ---------------------------------------------------------------------------

describe('FailureRateAlertEngine — REQ 14.6 denominator guard', () => {
    test('does not fire when no deliveries have been recorded', () => {
        const engine = createFailureRateAlertEngine({ threshold: 0.05 });
        expect(engine.checkAlerts()).toEqual([]);
    });

    test('does not fire when minDispatches is set above current sample count', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            minDispatches: 100,
            now: clock.now,
        });

        // 5 dispatches, all failed — ratio is 100%, but minDispatches=100
        // means the alert MUST NOT fire (REQ 14.6 denominator floor).
        recordOutcomes(engine, 'email', 0, 5);
        expect(engine.checkAlerts()).toEqual([]);
    });
});

// ---------------------------------------------------------------------------
// Env-var configuration
// ---------------------------------------------------------------------------

describe('FailureRateAlertEngine — env-var configuration', () => {
    const originalEnv = { ...process.env };

    afterEach(() => {
        // Restore env to whatever the worker started with so we don't
        // bleed into other test files.
        process.env = { ...originalEnv };
    });

    test('reads window length, threshold, and minDispatches from env', () => {
        process.env.UNS_ALERT_WINDOW_MS = '120000';
        process.env.UNS_ALERT_FAILURE_RATIO = '0.25';
        process.env.UNS_ALERT_MIN_DISPATCHES = '4';

        const engine = createFailureRateAlertEngine();
        const cfg = engine.getConfig();
        expect(cfg.windowMs).toBe(120_000);
        expect(cfg.threshold).toBe(0.25);
        expect(cfg.minDispatches).toBe(4);
    });

    test('falls back to safe defaults when env values are invalid', () => {
        process.env.UNS_ALERT_WINDOW_MS = 'not-a-number';
        process.env.UNS_ALERT_FAILURE_RATIO = '5'; // out of [0, 1]
        process.env.UNS_ALERT_MIN_DISPATCHES = '0'; // < 1

        const engine = createFailureRateAlertEngine();
        const cfg = engine.getConfig();
        expect(cfg.windowMs).toBe(DEFAULT_WINDOW_MS);
        expect(cfg.threshold).toBe(DEFAULT_THRESHOLD);
        expect(cfg.minDispatches).toBe(DEFAULT_MIN_DISPATCHES);
    });

    test('explicit options override env vars', () => {
        process.env.UNS_ALERT_WINDOW_MS = '120000';
        process.env.UNS_ALERT_FAILURE_RATIO = '0.25';

        const engine = createFailureRateAlertEngine({
            windowMs: 5_000,
            threshold: 0.5,
        });
        const cfg = engine.getConfig();
        expect(cfg.windowMs).toBe(5_000);
        expect(cfg.threshold).toBe(0.5);
    });
});

// ===========================================================================
// Task 17.3 — provider-driven `evaluate()`, sinks, lifecycle, channel filter
// ===========================================================================

describe('FailureRateAlertEngine — task 17.3 surface', () => {
    test('exposes DEFAULT_MIN_SAMPLE_SIZE and DEFAULT_MIN_DISPATCHES as aliases', () => {
        expect(DEFAULT_MIN_SAMPLE_SIZE).toBe(DEFAULT_MIN_DISPATCHES);
    });

    test('evaluate() is a synonym for checkAlerts()', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            now: clock.now,
        });
        recordOutcomes(engine, 'email', 0, 10);
        const a = engine.checkAlerts();
        const b = engine.evaluate();
        expect(a.length).toBe(1);
        expect(b.length).toBe(1);
        expect(a[0].channel).toBe(b[0].channel);
        expect(a[0].failedCount).toBe(b[0].failedCount);
    });

    test('config object accepts task-brief option names (minSampleSize, channels)', () => {
        const engine = createFailureRateAlertEngine({
            windowMs: 30_000,
            threshold: 0.2,
            minSampleSize: 5,
            channels: ['push', 'email'],
        });
        const cfg = engine.getConfig();
        expect(cfg.windowMs).toBe(30_000);
        expect(cfg.threshold).toBe(0.2);
        expect(cfg.minSampleSize).toBe(5);
        expect(cfg.minDispatches).toBe(5);
        expect([...cfg.channels].sort()).toEqual(['email', 'push']);
    });

    test('channels-of-interest filter restricts which channels are evaluated', () => {
        const clock = makeClock();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            channels: ['email'],
            now: clock.now,
        });

        // Both channels breach in absolute terms, but only `email` is
        // configured for evaluation.
        recordOutcomes(engine, 'email', 0, 10);
        recordOutcomes(engine, 'sms', 0, 10);

        const firing = engine.evaluate();
        expect(firing.map((a) => a.channel)).toEqual(['email']);
    });

    test('empty channels list disables firing entirely', () => {
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            channels: [],
        });
        recordOutcomes(engine, 'email', 0, 100);
        expect(engine.evaluate()).toEqual([]);
    });

    test('unknown channels in the channels option are silently dropped', () => {
        const engine = createFailureRateAlertEngine({
            channels: [
                'email',
                // @ts-expect-error — intentionally invalid for runtime test.
                'carrier_pigeon',
            ],
        });
        const cfg = engine.getConfig();
        expect([...cfg.channels]).toEqual(['email']);
    });

    test('ALL_CHANNELS exposes every supported channel', () => {
        expect([...ALL_CHANNELS].sort()).toEqual(
            ['email', 'in_app', 'push', 'sms', 'webhook'],
        );
    });
});

describe('FailureRateAlertEngine — custom sinks', () => {
    test('custom sink (via options) receives every firing alert', () => {
        const clock = makeClock();
        const received: FailureRateAlert[] = [];
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            sink: (alert) => received.push(alert),
            now: clock.now,
        });

        recordOutcomes(engine, 'sms', 0, 50);
        engine.evaluate();
        clock.advance(1_000);
        engine.evaluate();

        expect(received).toHaveLength(2);
        expect(received.every((a) => a.channel === 'sms')).toBe(true);
        expect(received.every((a) => a.event_name === ALERT_EVENT_NAME)).toBe(true);
    });

    test('configuring a custom sink suppresses the built-in default log emission', () => {
        const clock = makeClock();
        const received: FailureRateAlert[] = [];
        createFailureRateAlertEngine({
            threshold: 0.05,
            sink: (a) => received.push(a),
            now: clock.now,
        });

        // No traffic recorded yet — but the spies are wired.
        const baselineWarn = warnSpy.mock.calls.length;
        const baselineErr = errorSpy.mock.calls.length;

        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            sink: (a) => received.push(a),
            now: clock.now,
        });
        recordOutcomes(engine, 'webhook', 0, 100);
        engine.evaluate();

        expect(received.length).toBeGreaterThanOrEqual(1);
        // The default structured-log emission must NOT happen when a
        // sink is configured — the caller's sink is the only output.
        expect(warnSpy.mock.calls.length).toBe(baselineWarn);
        expect(errorSpy.mock.calls.length).toBe(baselineErr);
    });

    test('addSink registers an additional sink and the disposer removes it', () => {
        const clock = makeClock();
        const seen: string[] = [];
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            now: clock.now,
        });

        const dispose = engine.addSink((a) => seen.push(a.channel));

        recordOutcomes(engine, 'push', 0, 10);
        engine.evaluate();
        expect(seen).toEqual(['push']);

        dispose();
        clock.advance(1_000);
        engine.evaluate();
        // Sink has been disposed — no new entries.
        expect(seen).toEqual(['push']);
    });

    test('setSink replaces every existing sink and disables the default log', () => {
        const clock = makeClock();
        const first: FailureRateAlert[] = [];
        const second: FailureRateAlert[] = [];

        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            now: clock.now,
        });
        engine.addSink((a) => first.push(a));
        engine.setSink((a) => second.push(a));

        const baselineWarn = warnSpy.mock.calls.length;
        const baselineErr = errorSpy.mock.calls.length;

        recordOutcomes(engine, 'sms', 0, 5);
        engine.evaluate();

        expect(first).toHaveLength(0);
        expect(second).toHaveLength(1);
        expect(warnSpy.mock.calls.length).toBe(baselineWarn);
        expect(errorSpy.mock.calls.length).toBe(baselineErr);
    });

    test('an injected logger receives the default structured-log emission', () => {
        const clock = makeClock();
        const calls: { level: string; msg: string; meta: unknown }[] = [];
        const fakeLogger = {
            info: (msg: string, meta?: Record<string, unknown>) =>
                calls.push({ level: 'info', msg, meta }),
            warn: (msg: string, meta?: Record<string, unknown>) =>
                calls.push({ level: 'warn', msg, meta }),
            error: (msg: string, meta?: Record<string, unknown>) =>
                calls.push({ level: 'error', msg, meta }),
        };

        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            logger: fakeLogger,
            now: clock.now,
        });

        recordOutcomes(engine, 'email', 0, 10);
        engine.evaluate();

        const alertCalls = calls.filter((c) =>
            c.msg.includes(ALERT_EVENT_NAME),
        );
        expect(alertCalls.length).toBeGreaterThanOrEqual(1);
        // Severity is "error" because ratio (100%) >= 2× threshold (10%).
        expect(alertCalls[0].level).toBe('error');
    });
});

describe('FailureRateAlertEngine — start/stop lifecycle', () => {
    afterEach(() => {
        // Each lifecycle test starts and stops its own engine; nothing
        // to clean here, but the hook is preserved in case a future
        // case forgets to stop.
    });

    test('start() schedules periodic evaluate() calls; stop() halts them', () => {
        jest.useFakeTimers();
        try {
            const clock = makeClock();
            // Tie the engine clock to the fake-timer clock so window
            // math keeps up with the scheduled ticks.
            const tickClock = (delta: number) => {
                clock.advance(delta);
                jest.advanceTimersByTime(delta);
            };

            const received: FailureRateAlert[] = [];
            const engine = createFailureRateAlertEngine({
                threshold: 0.05,
                sink: (a) => received.push(a),
                now: clock.now,
            });

            recordOutcomes(engine, 'webhook', 0, 10);
            engine.start(1_000);
            tickClock(1_000);
            tickClock(1_000);
            tickClock(1_000);

            expect(received.length).toBe(3);
            engine.stop();

            tickClock(5_000);
            // After stop, no new alerts should arrive.
            expect(received.length).toBe(3);
        } finally {
            jest.useRealTimers();
        }
    });

    test('start() rejects non-positive intervals', () => {
        const engine = createFailureRateAlertEngine();
        expect(() => engine.start(0)).toThrow(TypeError);
        expect(() => engine.start(-1)).toThrow(TypeError);
        expect(() => engine.start(Number.NaN)).toThrow(TypeError);
        expect(() => engine.start(Number.POSITIVE_INFINITY)).toThrow(TypeError);
    });

    test('start() while running is a no-op (does not double-schedule)', () => {
        jest.useFakeTimers();
        try {
            const clock = makeClock();
            const received: FailureRateAlert[] = [];
            const engine = createFailureRateAlertEngine({
                threshold: 0.05,
                sink: (a) => received.push(a),
                now: clock.now,
            });
            recordOutcomes(engine, 'sms', 0, 5);

            engine.start(1_000);
            engine.start(500); // second call should be ignored
            clock.advance(1_000);
            jest.advanceTimersByTime(1_000);

            // Only the original 1_000ms cadence ticks — exactly one
            // evaluation in this interval.
            expect(received.length).toBe(1);
            engine.stop();
        } finally {
            jest.useRealTimers();
        }
    });

    test('stop() is idempotent', () => {
        const engine = createFailureRateAlertEngine();
        // Multiple stops without a start, and after start, must not
        // throw.
        expect(() => engine.stop()).not.toThrow();
        engine.start(1_000);
        engine.stop();
        expect(() => engine.stop()).not.toThrow();
    });

    test('an exception inside evaluate() does not break subsequent ticks', () => {
        jest.useFakeTimers();
        try {
            const clock = makeClock();
            const fakeLogger = {
                info: jest.fn(),
                warn: jest.fn(),
                error: jest.fn(),
            };
            const received: FailureRateAlert[] = [];
            // A throwing sink is the easiest way to cause evaluate()
            // to log-and-continue rather than crash the timer.
            let throws = true;
            const engine = createFailureRateAlertEngine({
                threshold: 0.05,
                logger: fakeLogger,
                now: clock.now,
                sink: (a) => {
                    if (throws) {
                        throws = false;
                        throw new Error('boom');
                    }
                    received.push(a);
                },
            });
            recordOutcomes(engine, 'email', 0, 5);

            engine.start(1_000);
            clock.advance(1_000);
            jest.advanceTimersByTime(1_000);
            clock.advance(1_000);
            jest.advanceTimersByTime(1_000);
            engine.stop();

            // The first tick threw → captured by the sink-throw
            // handler, recorded as a warn. The second tick succeeded
            // and pushed into `received`.
            expect(received.length).toBe(1);
            expect(fakeLogger.warn).toHaveBeenCalledWith(
                '[uns-alerts] sink threw',
                expect.objectContaining({ error: 'boom' }),
            );
        } finally {
            jest.useRealTimers();
        }
    });
});

describe('FailureRateAlertEngine — provider-driven mode', () => {
    /**
     * Build a controllable provider where successes / failures per
     * channel can be advanced between evaluations. The engine sees
     * cumulative counts and computes deltas itself.
     */
    function makeProvider(): {
        provider: DispatchOutcomeProvider;
        bump: (channel: 'email' | 'sms' | 'push' | 'in_app' | 'webhook',
            successes: number, failures: number) => void;
        reset: () => void;
    } {
        const counts = new Map<string, ChannelDispatchCounts>();
        return {
            provider: () => {
                const out = new Map<
                    'email' | 'sms' | 'push' | 'in_app' | 'webhook',
                    ChannelDispatchCounts
                >();
                for (const [k, v] of counts.entries()) {
                    out.set(k as never, v);
                }
                return out as never;
            },
            bump: (channel, successes, failures) => {
                const prev = counts.get(channel) ?? { successes: 0, failures: 0 };
                counts.set(channel, {
                    successes: prev.successes + successes,
                    failures: prev.failures + failures,
                });
            },
            reset: () => counts.clear(),
        };
    }

    test('reports provider mode in getConfig()', () => {
        const { provider } = makeProvider();
        const engine = createFailureRateAlertEngine({ provider });
        expect(engine.getConfig().mode).toBe('provider');
    });

    test('does not fire when below threshold (provider mode)', () => {
        const clock = makeClock();
        const { provider, bump } = makeProvider();
        const engine = createFailureRateAlertEngine({
            threshold: 0.1,
            windowMs: 60_000,
            provider,
            now: clock.now,
        });

        // Establish baseline.
        engine.evaluate();
        // Advance into the window.
        clock.advance(70_000);
        bump('email', 100, 5); // 4.76% failure rate
        const firing = engine.evaluate();
        expect(firing).toEqual([]);
    });

    test('fires when delta over the window exceeds threshold', () => {
        const clock = makeClock();
        const { provider, bump } = makeProvider();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            windowMs: 60_000,
            provider,
            now: clock.now,
        });

        engine.evaluate(); // capture baseline at t=0
        clock.advance(70_000); // walk past the window once

        bump('push', 80, 20); // 20% failure rate inside the window
        const firing = engine.evaluate();
        expect(firing).toHaveLength(1);
        const alert = firing[0];
        expect(alert.channel).toBe('push');
        expect(alert.dispatchedCount).toBe(100);
        expect(alert.failedCount).toBe(20);
        expect(alert.failureRatio).toBeCloseTo(0.2, 5);
    });

    test('does not fire when sample size is below the configured minimum', () => {
        const clock = makeClock();
        const { provider, bump } = makeProvider();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            minSampleSize: 50,
            windowMs: 60_000,
            provider,
            now: clock.now,
        });

        engine.evaluate(); // baseline
        clock.advance(70_000);

        // 5 dispatched, 100% failure → ratio above threshold but
        // dispatched < minSampleSize → MUST NOT fire.
        bump('email', 0, 5);
        expect(engine.evaluate()).toEqual([]);
    });

    test('multiple channels evaluate independently in provider mode', () => {
        const clock = makeClock();
        const { provider, bump } = makeProvider();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            windowMs: 60_000,
            provider,
            now: clock.now,
        });

        engine.evaluate(); // baseline
        clock.advance(70_000);

        bump('email', 100, 0); // healthy
        bump('sms', 0, 100); // 100% failure
        bump('webhook', 99, 1); // 1% failure (under)
        bump('push', 50, 50); // 50% failure (over)

        const firing = engine.evaluate();
        const breached = firing.map((a) => a.channel).sort();
        expect(breached).toEqual(['push', 'sms']);
    });

    test('does not double-count: ratio is computed over the rolling window only', () => {
        const clock = makeClock();
        const { provider, bump } = makeProvider();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            windowMs: 60_000,
            provider,
            now: clock.now,
        });

        // t=0: pre-existing healthy traffic (1000 successes already on
        // the wire) — captured in the baseline snapshot.
        bump('webhook', 1000, 0);
        engine.evaluate();

        // Walk past the entire window so the t=0 snapshot becomes the
        // baseline that anchors the window's start.
        clock.advance(70_000);

        // Add 50 failures and 0 successes after the window has rolled.
        // The window-delta is therefore 50 dispatched / 50 failed = 100%
        // — well above the 5% threshold.
        bump('webhook', 0, 50);
        const firing = engine.evaluate();
        expect(firing).toHaveLength(1);
        expect(firing[0].failedCount).toBe(50);
        expect(firing[0].dispatchedCount).toBe(50);
        // Pre-existing healthy successes from before the window do NOT
        // dilute the in-window failure rate.
        expect(firing[0].failureRatio).toBeCloseTo(1.0, 5);
    });

    test('partial-window: counts include traffic since the start of the window', () => {
        const clock = makeClock();
        const { provider, bump } = makeProvider();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            windowMs: 60_000,
            provider,
            now: clock.now,
        });

        // First evaluation captures the empty-baseline snapshot at t=0.
        engine.evaluate();
        // 10s into the 60s window — every sample so far is inside the
        // window, so the engine reports the deltas-since-process-start
        // (effectively the whole window's traffic).
        clock.advance(10_000);
        bump('webhook', 80, 20);
        const firing = engine.evaluate();
        expect(firing).toHaveLength(1);
        expect(firing[0].dispatchedCount).toBe(100);
        expect(firing[0].failedCount).toBe(20);
    });

    test('recordDeliveryOutcome is a no-op in provider-driven mode', () => {
        const clock = makeClock();
        const { provider } = makeProvider();
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            provider,
            now: clock.now,
        });
        // Recording outcomes should not influence provider-driven
        // evaluation — the provider is the only source of truth.
        engine.recordDeliveryOutcome('email', false);
        engine.recordDeliveryOutcome('email', false);
        expect(engine.evaluate()).toEqual([]);
    });

    test('a throwing provider does not crash the engine', () => {
        const clock = makeClock();
        const fakeLogger = {
            info: jest.fn(),
            warn: jest.fn(),
            error: jest.fn(),
        };
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            provider: () => {
                throw new Error('provider down');
            },
            logger: fakeLogger,
            now: clock.now,
        });

        // No throw, no firings.
        expect(() => engine.evaluate()).not.toThrow();
        expect(engine.evaluate()).toEqual([]);
        expect(fakeLogger.error).toHaveBeenCalledWith(
            expect.stringContaining('provider() threw'),
            expect.objectContaining({ error: 'provider down' }),
        );
    });

    test('sanitizes negative / NaN counts coming from a misbehaving provider', () => {
        const clock = makeClock();
        let payload: ReadonlyMap<string, ChannelDispatchCounts> = new Map([
            ['email', { successes: 0, failures: 0 }],
        ]);
        const engine = createFailureRateAlertEngine({
            threshold: 0.05,
            windowMs: 60_000,
            provider: () => payload as never,
            now: clock.now,
        });

        engine.evaluate(); // baseline
        clock.advance(70_000);

        // Pathological provider: negatives, NaN — engine should clamp
        // these to safe values rather than crash or report nonsense.
        payload = new Map([
            [
                'email',
                {
                    successes: Number.NaN as unknown as number,
                    failures: -10 as unknown as number,
                },
            ],
        ]);
        const firing = engine.evaluate();
        expect(firing).toEqual([]);
    });
});

