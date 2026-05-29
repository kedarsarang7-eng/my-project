// ============================================================================
// shim/channel-fault.ts — fault-injection shim for the load harness
// ============================================================================
//
// Reusable fault-injection surface shared by:
//   - phase5-load-plan.md §2.6 — SCN-SLOW-CHANNEL (this load harness, Task 18.2)
//   - my-backend/tests/notifications/chaos/event-bus-restart.test.ts (Task 18.3)
//
// The chaos test (18.3) was authored before this file landed and currently
// inlines a copy at `tests/notifications/chaos/shim/channel-fault.ts`.
// That copy's header documents the migration: once 18.2 ships (this file),
// the chaos copy becomes a re-export from this module. The two files MUST
// expose the same surface so the swap is mechanical:
//
//   slowChannel(adapter, opts)     — fixed virtual latency
//   failingChannel(adapter, opts)  — N transient failures, then pass
//   flappingChannel(adapter, opts) — cycling pass/fail pattern
//   recordingChannel(sink, clock)  — pass-through with delivery capture
//   slowChannelWindow(adapter, opts)  — SCN-SLOW-CHANNEL latency-spike window
//   ChaosClock / ManualChaosClock / realtimeChaosClock / flushMicrotasks
//
// Production code does NOT import this file — it is test infrastructure
// only. The shim composes around the real `DispatchChannelAdapter` shape
// from `src/notifications/service/types`, so what it tests is the
// production retry / DLQ / dispatch loop, not a parallel implementation.
//
// Validates: phase5-load-plan.md §2.6 (slow-channel scenario), §4.2
// (location), and the contract described in
// `tests/notifications/chaos/shim/channel-fault.ts`'s header.
// ============================================================================

import type {
    DispatchChannelAdapter,
    DispatchChannelArgs,
} from '../../../src/notifications/service/types';

// ---------------------------------------------------------------------------
// Deterministic clock — identical surface to the chaos shim
// ---------------------------------------------------------------------------

/**
 * Minimal clock surface. `now()` returns ms epoch; `wait(ms)` resolves
 * after `ms` virtual milliseconds. The k6 harness drives a real-time
 * clock; the chaos test drives a `ManualChaosClock` so virtual time is
 * advanceable without sleeping.
 */
export interface ChaosClock {
    now(): number;
    wait(ms: number): Promise<void>;
}

/**
 * Real-time clock — used by the load harness when `slowChannel` should
 * actually delay each delivery in wall-clock time (the SCN-SLOW-CHANNEL
 * scenario does want real latency to land on the per-channel histograms).
 */
export const realtimeChaosClock: ChaosClock = {
    now: () => Date.now(),
    wait: (ms: number) =>
        new Promise<void>((resolve) => {
            setTimeout(resolve, ms).unref?.();
        }),
};

/**
 * Manual clock with millisecond-precision advancement. Used by the
 * chaos test so virtual time can leap past slow-channel windows without
 * sleeping the test process.
 */
export class ManualChaosClock implements ChaosClock {
    private current: number;
    private readonly pending: { dueAt: number; resolve: () => void }[] = [];

    constructor(start = 1_700_000_000_000) {
        this.current = start;
    }

    public now(): number {
        return this.current;
    }

    public wait(ms: number): Promise<void> {
        const dueAt = this.current + Math.max(0, ms);
        return new Promise<void>((resolve) => {
            this.pending.push({ dueAt, resolve });
        });
    }

    /** Move the virtual clock forward by `ms` and release every due waiter. */
    public async advance(ms: number): Promise<void> {
        this.current += Math.max(0, ms);
        const stillPending: { dueAt: number; resolve: () => void }[] = [];
        for (const entry of this.pending) {
            if (entry.dueAt <= this.current) {
                entry.resolve();
            } else {
                stillPending.push(entry);
            }
        }
        this.pending.length = 0;
        this.pending.push(...stillPending);
        await flushMicrotasks();
    }
}

/**
 * Yield to the microtask queue so any awaiting `.then()` continuations
 * scheduled by `ManualChaosClock.advance()` get a chance to run.
 */
export function flushMicrotasks(): Promise<void> {
    return new Promise<void>((resolve) => setImmediate(resolve));
}

// ---------------------------------------------------------------------------
// Slow channel — fixed virtual latency before the wrapped adapter runs
// ---------------------------------------------------------------------------

export interface SlowChannelOptions {
    /** Virtual latency injected before each delivery, in ms. */
    readonly latencyMs: number;
    /** Clock source — defaults to `realtimeChaosClock`. */
    readonly clock?: ChaosClock;
}

/**
 * Wrap a real channel adapter so it waits `latencyMs` virtual
 * milliseconds before delegating to the inner adapter. The wait happens
 * BEFORE the inner call, mirroring a real provider that takes
 * `latencyMs` to acknowledge.
 */
export function slowChannel(
    inner: DispatchChannelAdapter,
    opts: SlowChannelOptions,
): DispatchChannelAdapter {
    const clock = opts.clock ?? realtimeChaosClock;
    const latencyMs = Math.max(0, opts.latencyMs);
    return async (args: DispatchChannelArgs) => {
        await clock.wait(latencyMs);
        await inner(args);
    };
}

// ---------------------------------------------------------------------------
// SCN-SLOW-CHANNEL — latency-spike window
// ---------------------------------------------------------------------------

export interface SlowChannelWindowOptions {
    /** Latency to inject INSIDE the window, in ms. */
    readonly latencyMs: number;
    /**
     * The window during which the latency is applied, expressed in ms
     * since the wrapper was constructed. Outside this window the
     * adapter behaves normally (zero injected latency).
     *
     * For SCN-SLOW-CHANNEL the load plan calls for a 120 s window
     * starting at minute 2:00 of a 5-minute scenario; pass
     * `windowStartMs: 120_000`, `windowDurationMs: 120_000`.
     */
    readonly windowStartMs: number;
    readonly windowDurationMs: number;
    /** Optional clock — defaults to `realtimeChaosClock`. */
    readonly clock?: ChaosClock;
}

/**
 * Wrap an adapter so it injects `latencyMs` only during the configured
 * window. Used by SCN-SLOW-CHANNEL (§2.6) and reused by the chaos test
 * (18.3) to compose a slow-channel fault with a bus restart.
 */
export function slowChannelWindow(
    inner: DispatchChannelAdapter,
    opts: SlowChannelWindowOptions,
): DispatchChannelAdapter {
    if (opts.windowDurationMs <= 0) {
        throw new Error('slowChannelWindow: windowDurationMs must be positive');
    }
    if (opts.windowStartMs < 0) {
        throw new Error('slowChannelWindow: windowStartMs must be ≥ 0');
    }
    const clock = opts.clock ?? realtimeChaosClock;
    const startedAt = clock.now();
    const latencyMs = Math.max(0, opts.latencyMs);
    return async (args: DispatchChannelArgs) => {
        const elapsed = clock.now() - startedAt;
        const inside =
            elapsed >= opts.windowStartMs &&
            elapsed < opts.windowStartMs + opts.windowDurationMs;
        if (inside) await clock.wait(latencyMs);
        await inner(args);
    };
}

// ---------------------------------------------------------------------------
// Failing channel — first N calls throw, rest pass through
// ---------------------------------------------------------------------------

export interface FailingChannelOptions {
    /** Number of consecutive failures before the channel "recovers". */
    readonly failuresBeforeRecovery: number;
    /** Error message used by every injected failure. */
    readonly errorMessage?: string;
    /**
     * When `true`, every call (even after the failure budget) keeps
     * throwing. Used to exhaust the retry budget and force DLQ routing.
     */
    readonly permanent?: boolean;
}

export interface FailingChannelTracker {
    readonly attempts: number;
    readonly failures: number;
    readonly successes: number;
}

/**
 * Wrap an adapter so its first `failuresBeforeRecovery` invocations
 * throw a synthetic transient error.
 */
export function failingChannel(
    inner: DispatchChannelAdapter,
    opts: FailingChannelOptions,
): {
    readonly adapter: DispatchChannelAdapter;
    readonly tracker: FailingChannelTracker;
} {
    let attempts = 0;
    let failures = 0;
    let successes = 0;
    const errorMessage =
        opts.errorMessage ?? 'channel-fault: simulated failure';

    const adapter: DispatchChannelAdapter = async (args) => {
        attempts += 1;
        const shouldFail =
            opts.permanent === true ||
            attempts <= opts.failuresBeforeRecovery;
        if (shouldFail) {
            failures += 1;
            const err = new Error(errorMessage);
            err.name = 'ChannelFaultError';
            throw err;
        }
        await inner(args);
        successes += 1;
    };

    const tracker: FailingChannelTracker = {
        get attempts() {
            return attempts;
        },
        get failures() {
            return failures;
        },
        get successes() {
            return successes;
        },
    };

    return { adapter, tracker };
}

// ---------------------------------------------------------------------------
// Flapping channel — alternates pass/fail per supplied pattern
// ---------------------------------------------------------------------------

export interface FlappingChannelOptions {
    readonly pattern: readonly boolean[];
    readonly errorMessage?: string;
}

export function flappingChannel(
    inner: DispatchChannelAdapter,
    opts: FlappingChannelOptions,
): DispatchChannelAdapter {
    if (opts.pattern.length === 0) {
        throw new Error('flappingChannel: pattern must be non-empty');
    }
    let cursor = 0;
    const errorMessage = opts.errorMessage ?? 'channel-fault: flapping';

    return async (args: DispatchChannelArgs) => {
        const ok = opts.pattern[cursor % opts.pattern.length];
        cursor += 1;
        if (!ok) {
            const err = new Error(errorMessage);
            err.name = 'ChannelFaultError';
            throw err;
        }
        await inner(args);
    };
}

// ---------------------------------------------------------------------------
// Recording channel — captures every successful delivery for assertion
// ---------------------------------------------------------------------------

export interface RecordedDelivery {
    readonly notification_id: string;
    readonly recipient_id: string;
    readonly channel: string;
    readonly at: number;
}

/**
 * A pass-through adapter that records every successful delivery's
 * `(notification_id, recipient_id, channel, virtual_now)` tuple into
 * the supplied sink.
 */
export function recordingChannel(
    sink: RecordedDelivery[],
    clock: ChaosClock = realtimeChaosClock,
): DispatchChannelAdapter {
    return async (args: DispatchChannelArgs) => {
        sink.push({
            notification_id: args.notification.notification_id,
            recipient_id: args.recipient.user_id,
            channel: args.channel,
            at: clock.now(),
        });
    };
}
