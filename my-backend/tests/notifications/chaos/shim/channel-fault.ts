// ============================================================================
// chaos/shim/channel-fault.ts — local fault-injection shim for chaos tests
// ============================================================================
//
// This file mirrors the surface published at
// `my-backend/tests/notifications/load/shim/channel-fault.ts` (Task 18.2).
//
// Why duplicate vs. import?
//   - ts-jest (`tsconfig.jest.json` has `rootDir: ./src`, `include:
//     ["src/**/*.ts"]`) does not include arbitrary `tests/...` files in
//     a single TypeScript program. When the chaos suite imports across
//     two `tests/notifications/...` siblings, isolated-module
//     compilation cannot resolve the inner imports of the foreign
//     directory. Inlining the surface here keeps each test file
//     compilable as a standalone unit.
//   - The load shim's own header explicitly anticipates this: "The
//     chaos test (18.3) was authored before this file landed and
//     currently inlines a copy". Both files MUST stay byte-equivalent
//     in surface so a future tsconfig change can swap this file for a
//     re-export with no test rewrites.
//
// What it does:
//   - `slowChannel(adapter, latencyMs)` — wraps a `DispatchChannelAdapter`
//     and adds a deterministic delay (advanceable via the injected clock)
//     before the wrapped adapter runs.
//   - `failingChannel(adapter, opts)` — wraps an adapter so its first
//     `failuresBeforeRecovery` invocations throw, and subsequent calls
//     pass through. Used to exercise the consumer's retry+DLQ path.
//   - `flappingChannel(adapter, pattern)` — alternates pass/fail per the
//     supplied boolean pattern. Used by the slow-channel composition
//     scenario when we want a transient flap rather than a sustained
//     outage.
//   - `recordingChannel(sink, clock)` — pass-through adapter that
//     records every successful delivery for assertion.
//
// All shims:
//   - Take an injected `clock` so tests stay deterministic.
//   - Are pure test infrastructure; production code does NOT import this
//     module.
// ============================================================================

import type {
    DispatchChannelAdapter,
    DispatchChannelArgs,
} from '../../../../src/notifications/service/types';

// ---------------------------------------------------------------------------
// Deterministic clock contract — matches the shape used by load harness 18.2
// ---------------------------------------------------------------------------

/**
 * Minimal clock surface. `now()` returns ms epoch; `wait(ms)` resolves
 * after `ms` virtual milliseconds. The test driver supplies a manual
 * implementation that resolves immediately and is paired with explicit
 * `await flushMicrotasks()` calls.
 */
export interface ChaosClock {
    now(): number;
    wait(ms: number): Promise<void>;
}

/**
 * Real-time clock — used by the load harness when `slowChannel` should
 * actually delay each delivery in wall-clock time, and by the chaos
 * tests when a small fixed sleep is preferable to virtual-clock
 * choreography (e.g. inside a sequential dispatch loop where the
 * caller cannot interleave clock advancement).
 */
export const realtimeChaosClock: ChaosClock = {
    now: () => Date.now(),
    wait: (ms: number) =>
        new Promise<void>((resolve) => {
            setTimeout(resolve, ms).unref?.();
        }),
};

/**
 * A manual / virtual clock with millisecond-precision advancement. Pending
 * `wait(ms)` calls resolve when `advance(ms)` rolls the clock past their
 * deadline.
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
 * milliseconds before delegating to the inner adapter. The wait
 * happens BEFORE the inner call, mirroring a real provider that
 * takes `latencyMs` to acknowledge.
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
// Failing channel — first N calls throw, rest pass through
// ---------------------------------------------------------------------------

export interface FailingChannelOptions {
    /** Number of consecutive failures before the channel "recovers". */
    readonly failuresBeforeRecovery: number;
    /** Error message used by every injected failure. Defaults to a stable label. */
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
    const errorMessage = opts.errorMessage ?? 'channel-fault: simulated failure';

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
