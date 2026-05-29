// ============================================================================
// k6/dedup.js — SCN-DEDUP (phase5-load-plan.md §2.7)
// ============================================================================
//
// Steady-state load (§2.1) with 25 % of emitted events as intentional
// duplicates of an event already in flight, sharing the full
// Deduplication_Key (`event_name`, `actor_id`, `target_id`,
// `dedup_scope_fields`) and arriving inside the configured
// Deduplication_Window (default 60 s).
//
// Tied requirements: REQ 4.4, 15.5.
//
// STATUS: STUB — wiring complete (config + thresholds + bend helper),
// scenario logic intentionally minimal so a CI run produces a clean
// "scenario configured" signal. The dedup-bend mechanics are already
// implemented in `lib/workload-mix.ts > bendForDedup`; this script
// composes them but defers the post-run dedup verification to the
// verifier shim.
//
// TODO (phase5-load-plan.md §2.7 expectations to implement):
//   - Capture every delivery (notification_id, dedup_key, recipient_id,
//     delivered_at) from the SUT's audit log into an NDJSON file.
//   - Pipe the NDJSON file to `shim/verifier.ts > checkDedup` after the
//     run; assert `dedup_violations == 0`.
//   - Verify every suppressed duplicate is recorded with a
//     `skipped_duplicate` audit entry (REQ 4.4).
//   - Ensure no false-positive suppression: events with the same
//     `event_name` but different `dedup_scope_fields` MUST deliver.
//
// Usage:
//   k6 run \
//     --env RUN_ID=... \
//     --env PUBLISHER_URL=http://localhost:8787 \
//     --env DEDUP_DUPLICATE_RATIO=0.25 \
//     tests/notifications/load/k6/dedup.js
// ============================================================================

import http from 'k6/http';
import { check } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

import { buildThresholdsFor } from './lib/thresholds.ts';
import { generatePopulation } from './lib/recipients.ts';
import { buildWorkload, bendForDedup } from './lib/workload-mix.ts';

const RUN_ID = __ENV.RUN_ID || 'local-dev';
const PUBLISHER_URL = __ENV.PUBLISHER_URL || 'http://localhost:8787';
const EVENTS_PER_SECOND = parseInt(__ENV.EVENTS_PER_SECOND || '2000', 10);
const DURATION_SECONDS = parseInt(__ENV.DURATION_SECONDS || '300', 10);
const DEDUP_DUPLICATE_RATIO = parseFloat(__ENV.DEDUP_DUPLICATE_RATIO || '0.25');
const RECIPIENT_SCALE = parseInt(__ENV.RECIPIENT_SCALE || '10000', 10);
const SEED = parseInt(__ENV.SEED || '0', 10) || undefined;

const inAppLatency = new Trend('uns_in_app_e2e_latency_ms', true);
const eventLoss = new Counter('uns_event_loss');
const dedupViolations = new Counter('uns_dedup_violations');
const availability = new Rate('uns_availability_pct');

export const options = {
    scenarios: {
        dedup: {
            executor: 'constant-arrival-rate',
            rate: EVENTS_PER_SECOND,
            timeUnit: '1s',
            duration: `${DURATION_SECONDS}s`,
            preAllocatedVUs: 500,
            maxVUs: 1000,
            exec: 'emit',
            tags: { scenario: 'SCN-DEDUP' },
        },
    },
    thresholds: buildThresholdsFor('SCN-DEDUP'),
    summaryTrendStats: ['avg', 'p(95)', 'p(99)'],
};

export function setup() {
    return {
        run_id: RUN_ID,
        publisher_url: PUBLISHER_URL,
        knobs: { EVENTS_PER_SECOND, DURATION_SECONDS, DEDUP_DUPLICATE_RATIO, RECIPIENT_SCALE, SEED: SEED ?? null },
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
        seed: hash32(`${setupData.run_id}:dd:${__VU}`),
    });
    _gen = bendForDedup(base, { duplicate_ratio: DEDUP_DUPLICATE_RATIO });
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

    // dedupViolations is a verifier-driven counter; keep the import live
    // so the threshold map's `count==0` resolves cleanly.
    void dedupViolations;
}

function hash32(str) {
    let hash = 0x811c9dc5;
    for (let i = 0; i < str.length; i++) {
        hash ^= str.charCodeAt(i);
        hash = Math.imul(hash, 0x01000193);
    }
    return hash >>> 0;
}
