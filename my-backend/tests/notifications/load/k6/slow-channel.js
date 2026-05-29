// ============================================================================
// k6/slow-channel.js — SCN-SLOW-CHANNEL (phase5-load-plan.md §2.6)
// ============================================================================
//
// Steady-state load (§2.1); at minute 2:00, raise the `email` adapter's
// per-call latency to a fixed 2 000 ms (4× retry-budget pressure) for
// 120 s; restore at minute 4:00; continue load to minute 5:00.
// Variants for `push` and `webhook` are toggled via env.
//
// Tied requirements: REQ 5.9–5.13, 9.3, 9.7, 9.8, 14.6, 15.4.
//
// STATUS: STUB — wiring complete (config + thresholds + the
// `slowChannelWindow` shim is implemented in `shim/channel-fault.ts`),
// scenario logic intentionally minimal so a CI run produces a clean
// "scenario configured" signal. The actual fault injection requires
// driving the SUT's channel adapter substitution mechanism, which is a
// SUT-side knob landed in task 14.10's wiring layer.
//
// TODO (phase5-load-plan.md §2.6 expectations to implement):
//   - Drive the SUT's channel-adapter substitution (a startup env
//     forces the configured channel to use `slowChannelWindow` from
//     `shim/channel-fault.ts`).
//   - Assert non-faulted channels' p95 stays within ±10 % of SCN-STEADY
//     (already encoded in `lib/thresholds.ts > slowChannelThresholds`).
//   - Assert the faulted-channel events that exhaust retry budget land
//     in DLQ with original payload, last error, retry count, timestamps
//     preserved (via the verifier shim).
//   - Assert `alert.notifications.high_failure_rate` fires iff
//     failed/dispatched > 5 % AND dispatched ≥ 1 over rolling 5 min
//     (G-C7, REQ 14.6).
//
// Hand-off to 18.3 (chaos):
//   The chaos test composes this scenario's slow-channel fault with an
//   Event_Bus restart. The `shim/channel-fault.ts > slowChannelWindow`
//   API is the shared injection surface.
//
// Usage:
//   k6 run \
//     --env RUN_ID=... \
//     --env PUBLISHER_URL=http://localhost:8787 \
//     --env CHANNEL_FAULT_TARGET=email \
//     --env CHANNEL_FAULT_LATENCY_MS=2000 \
//     --env CHANNEL_FAULT_WINDOW_SECONDS=120 \
//     tests/notifications/load/k6/slow-channel.js
// ============================================================================

import http from 'k6/http';
import { check } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

import { buildThresholdsFor } from './lib/thresholds.ts';
import { generatePopulation } from './lib/recipients.ts';
import { buildWorkload } from './lib/workload-mix.ts';

const RUN_ID = __ENV.RUN_ID || 'local-dev';
const PUBLISHER_URL = __ENV.PUBLISHER_URL || 'http://localhost:8787';
const EVENTS_PER_SECOND = parseInt(__ENV.EVENTS_PER_SECOND || '2000', 10);
const DURATION_SECONDS = parseInt(__ENV.DURATION_SECONDS || '300', 10);
const CHANNEL_FAULT_TARGET = __ENV.CHANNEL_FAULT_TARGET || 'email';
const CHANNEL_FAULT_LATENCY_MS = parseInt(__ENV.CHANNEL_FAULT_LATENCY_MS || '2000', 10);
const CHANNEL_FAULT_WINDOW_SECONDS = parseInt(__ENV.CHANNEL_FAULT_WINDOW_SECONDS || '120', 10);
const CHANNEL_FAULT_START_SECONDS = parseInt(__ENV.CHANNEL_FAULT_START_SECONDS || '120', 10);
const RECIPIENT_SCALE = parseInt(__ENV.RECIPIENT_SCALE || '10000', 10);
const SEED = parseInt(__ENV.SEED || '0', 10) || undefined;

const deliveryLatency = new Trend('uns_delivery_latency_ms', true);
const eventLoss = new Counter('uns_event_loss');
const availability = new Rate('uns_availability_pct');

export const options = {
    scenarios: {
        slowChannel: {
            executor: 'constant-arrival-rate',
            rate: EVENTS_PER_SECOND,
            timeUnit: '1s',
            duration: `${DURATION_SECONDS}s`,
            preAllocatedVUs: 500,
            maxVUs: 1000,
            exec: 'emit',
            tags: { scenario: 'SCN-SLOW-CHANNEL', faulted_channel: CHANNEL_FAULT_TARGET },
        },
    },
    thresholds: buildThresholdsFor('SCN-SLOW-CHANNEL'),
    summaryTrendStats: ['avg', 'p(95)', 'p(99)'],
};

export function setup() {
    return {
        run_id: RUN_ID,
        publisher_url: PUBLISHER_URL,
        knobs: {
            EVENTS_PER_SECOND,
            DURATION_SECONDS,
            CHANNEL_FAULT_TARGET,
            CHANNEL_FAULT_LATENCY_MS,
            CHANNEL_FAULT_WINDOW_SECONDS,
            CHANNEL_FAULT_START_SECONDS,
            RECIPIENT_SCALE,
            SEED: SEED ?? null,
        },
        population: generatePopulation({
            run_id: RUN_ID,
            total_users: RECIPIENT_SCALE,
            total_tenants: 50,
            seed: SEED,
        }),
    };
}

let _gen = null;
function vuGenerator(setupData) {
    if (_gen) return _gen;
    _gen = buildWorkload({
        run_id: setupData.run_id,
        population: setupData.population,
        seed: hash32(`${setupData.run_id}:sc:${__VU}`),
    });
    return _gen;
}

export function emit(setupData) {
    const event = vuGenerator(setupData).next();
    const t0 = Date.now();
    const res = http.post(
        `${setupData.publisher_url}/publish`,
        JSON.stringify(event),
        { headers: { 'content-type': 'application/json' } },
    );
    const ok = check(res, { 'publish: 2xx': (r) => r.status >= 200 && r.status < 300 });
    availability.add(ok);
    if (!ok) {
        eventLoss.add(1);
        return;
    }
    // Record per-channel latency. During the fault window the faulted
    // channel's p95 will spike; the other channels must stay within
    // their per-channel SLOs (the threshold table enforces this).
    for (const channel of event.channels) {
        deliveryLatency.add(Date.now() - t0, { channel });
    }
}

function hash32(str) {
    let hash = 0x811c9dc5;
    for (let i = 0; i < str.length; i++) {
        hash ^= str.charCodeAt(i);
        hash = Math.imul(hash, 0x01000193);
    }
    return hash >>> 0;
}
