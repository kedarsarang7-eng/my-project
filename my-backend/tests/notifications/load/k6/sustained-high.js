// ============================================================================
// k6/sustained-high.js — SCN-SUSTAINED-HIGH (phase5-load-plan.md §2.3)
// ============================================================================
//
// 30-minute hold at 3× nominal (G-T5, default 6 000 eps) with the full
// 10 000 connected in-app recipients. Replaces the steady state and runs
// AFTER the harness has been warmed by SCN-STEADY.
//
// Tied requirements: REQ 6.7, 7.8, 9.7, 13.1, 13.2, 13.3, 13.6.
//
// STATUS: STUB — wiring complete (config block + thresholds + metrics),
// scenario logic intentionally minimal so a CI run produces a clean
// "scenario configured" signal without consuming a 30-minute window.
// Filling out the scenario requires a real SUT environment per §5.2.
//
// TODO (phase5-load-plan.md §2.3 expectations to implement):
//   - Hold at SUSTAINED_HIGH_EPS for SUSTAINED_HIGH_MINUTES.
//   - Continuously sample read-side queries (unread-count, history) at
//     ~1 % of publish rate so G-L5 / G-L7 are exercised across the full
//     30-minute window.
//   - Capture `sqs_visible_messages` from CloudWatch every 30 s into the
//     `uns_sqs_visible_messages` Trend so the threshold in §6.2 fires.
//   - Capture runner & SUT memory + connection counts at 1-minute
//     granularity to surface any leak-shaped growth (qualitative review,
//     §7.1 row).
//
// Usage:
//   k6 run \
//     --env RUN_ID=2025-01-31T120000-pr-1234 \
//     --env PUBLISHER_URL=http://localhost:8787 \
//     --env SUSTAINED_HIGH_EPS=6000 \
//     --env SUSTAINED_HIGH_MINUTES=30 \
//     tests/notifications/load/k6/sustained-high.js
// ============================================================================

import http from 'k6/http';
import { check } from 'k6';
import { Trend, Counter, Rate, Gauge } from 'k6/metrics';

import { buildThresholdsFor } from './lib/thresholds.ts';
import { generatePopulation } from './lib/recipients.ts';
import { buildWorkload } from './lib/workload-mix.ts';

// ---------------------------------------------------------------------------
// Knobs
// ---------------------------------------------------------------------------

const RUN_ID = __ENV.RUN_ID || 'local-dev';
const PUBLISHER_URL = __ENV.PUBLISHER_URL || 'http://localhost:8787';
const SUSTAINED_HIGH_EPS = parseInt(__ENV.SUSTAINED_HIGH_EPS || '6000', 10);
const SUSTAINED_HIGH_MINUTES = parseInt(__ENV.SUSTAINED_HIGH_MINUTES || '30', 10);
const RECIPIENT_SCALE = parseInt(__ENV.RECIPIENT_SCALE || '10000', 10);
const SEED = parseInt(__ENV.SEED || '0', 10) || undefined;

// ---------------------------------------------------------------------------
// Custom metrics
// ---------------------------------------------------------------------------

const inAppLatency = new Trend('uns_in_app_e2e_latency_ms', true);
const unreadCountQueryLatency = new Trend('uns_unread_count_query_ms', true);
const historyQueryLatency = new Trend('uns_history_query_ms', true);
// eslint-disable-next-line no-unused-vars
const sqsVisibleMessages = new Gauge('uns_sqs_visible_messages');
const eventLoss = new Counter('uns_event_loss');
const availability = new Rate('uns_availability_pct');

// ---------------------------------------------------------------------------
// k6 options
// ---------------------------------------------------------------------------

export const options = {
    scenarios: {
        sustainedHigh: {
            executor: 'constant-arrival-rate',
            rate: SUSTAINED_HIGH_EPS,
            timeUnit: '1s',
            duration: `${SUSTAINED_HIGH_MINUTES}m`,
            preAllocatedVUs: Math.max(1000, Math.floor(SUSTAINED_HIGH_EPS / 10)),
            maxVUs: Math.max(2000, Math.floor(SUSTAINED_HIGH_EPS / 5)),
            exec: 'emit',
            tags: { scenario: 'SCN-SUSTAINED-HIGH' },
        },
    },
    thresholds: buildThresholdsFor('SCN-SUSTAINED-HIGH'),
    summaryTrendStats: ['avg', 'min', 'max', 'p(50)', 'p(95)', 'p(99)'],
};

export function setup() {
    return {
        run_id: RUN_ID,
        publisher_url: PUBLISHER_URL,
        knobs: { SUSTAINED_HIGH_EPS, SUSTAINED_HIGH_MINUTES, RECIPIENT_SCALE, SEED: SEED ?? null },
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
        seed: hash32(`${setupData.run_id}:sh:${__VU}`),
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
    if (!ok) eventLoss.add(1);
    else inAppLatency.add(Date.now() - t0);

    // TODO §2.3 — sample read-side queries here at ~1 % so G-L5/G-L7
    // are exercised across the full 30-minute window.
    void unreadCountQueryLatency;
    void historyQueryLatency;
}

function hash32(str) {
    let hash = 0x811c9dc5;
    for (let i = 0; i < str.length; i++) {
        hash ^= str.charCodeAt(i);
        hash = Math.imul(hash, 0x01000193);
    }
    return hash >>> 0;
}
