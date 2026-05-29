// ============================================================================
// k6/mix.js — SCN-MIX (phase5-load-plan.md §2.5)
// ============================================================================
//
// Steady-state baseline (§2.1) with the per-recipient channel matrix
// drawn explicitly from §3.4 so every in-flight dispatch touches a
// representative blend of in_app, push, email, sms, and webhook.
//
// Tied requirements: REQ 5.1–5.13, 9.5, 14.5.
//
// STATUS: STUB — wiring complete (per-channel thresholds + bend helper),
// scenario logic intentionally minimal so a CI run produces a clean
// "scenario configured" signal. Cross-channel failure-isolation
// assertions are deferred to the integration run against a real SUT.
//
// TODO (phase5-load-plan.md §2.5 expectations to implement):
//   - Tag every captured `delivery_latency_ms` observation with
//     `channel:<name>` so the per-tag thresholds in `lib/thresholds.ts >
//     mixThresholds` actually fire.
//   - Assert failure isolation: simulate one channel failing for ONE
//     recipient and verify no other channel for any other recipient
//     regresses (cross-channel reachability invariant).
//   - Confirm per-channel histogram shapes match the §5.3 stub
//     distributions to within ±10 % (sanity check the harness, not the
//     SUT).
//
// Usage:
//   k6 run \
//     --env RUN_ID=... \
//     --env PUBLISHER_URL=http://localhost:8787 \
//     tests/notifications/load/k6/mix.js
// ============================================================================

import http from 'k6/http';
import { check } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

import { buildThresholdsFor } from './lib/thresholds.ts';
import { generatePopulation } from './lib/recipients.ts';
import { buildWorkload, bendForChannelMix } from './lib/workload-mix.ts';

const RUN_ID = __ENV.RUN_ID || 'local-dev';
const PUBLISHER_URL = __ENV.PUBLISHER_URL || 'http://localhost:8787';
const EVENTS_PER_SECOND = parseInt(__ENV.EVENTS_PER_SECOND || '2000', 10);
const DURATION_SECONDS = parseInt(__ENV.DURATION_SECONDS || '300', 10);
const RECIPIENT_SCALE = parseInt(__ENV.RECIPIENT_SCALE || '10000', 10);
const SEED = parseInt(__ENV.SEED || '0', 10) || undefined;

const deliveryLatency = new Trend('uns_delivery_latency_ms', true);
const eventLoss = new Counter('uns_event_loss');
const availability = new Rate('uns_availability_pct');

export const options = {
    scenarios: {
        mix: {
            executor: 'constant-arrival-rate',
            rate: EVENTS_PER_SECOND,
            timeUnit: '1s',
            duration: `${DURATION_SECONDS}s`,
            preAllocatedVUs: 500,
            maxVUs: 1000,
            exec: 'emit',
            tags: { scenario: 'SCN-MIX' },
        },
    },
    thresholds: buildThresholdsFor('SCN-MIX'),
    summaryTrendStats: ['avg', 'p(95)', 'p(99)'],
};

export function setup() {
    return {
        run_id: RUN_ID,
        publisher_url: PUBLISHER_URL,
        knobs: { EVENTS_PER_SECOND, DURATION_SECONDS, RECIPIENT_SCALE, SEED: SEED ?? null },
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
    const base = buildWorkload({
        run_id: setupData.run_id,
        population: setupData.population,
        seed: hash32(`${setupData.run_id}:mx:${__VU}`),
    });
    _gen = bendForChannelMix(base, {
        enforced_channels: ['in_app', 'push', 'email', 'sms', 'webhook'],
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
    // Record per-channel latency proxy. The real per-channel histograms
    // come from the SUT's metrics surface (REQ 14.5); the harness's own
    // observation here is "publish ack" timing only. TODO: wire to
    // CloudWatch metric stream.
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
