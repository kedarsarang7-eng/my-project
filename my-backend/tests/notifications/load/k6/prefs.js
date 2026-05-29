// ============================================================================
// k6/prefs.js — SCN-PREFS (phase5-load-plan.md §2.8)
// ============================================================================
//
// Steady-state load (§2.1) with the §3.4 preference shape, plus 5 000
// recipients carrying explicit Quiet_Hours overlapping the run window
// and 5 000 recipients with at least one `mute_target`.
//
// Tied requirements: REQ 7, 15.12.
//
// STATUS: STUB — wiring complete (config + thresholds + bend helper),
// scenario logic intentionally minimal so a CI run produces a clean
// "scenario configured" signal. The preference-respect verification
// runs offline through `shim/verifier.ts > checkPreferences`, which
// reuses the production `resolveAllowedChannels` so the verifier and
// the SUT share a single decision surface.
//
// TODO (phase5-load-plan.md §2.8 expectations to implement):
//   - Capture every delivery (notification_id, recipient_id, channel,
//     delivered_at, recipient_preferences) from the SUT's audit log
//     into an NDJSON file.
//   - Pipe the NDJSON file to `shim/verifier.ts > checkPreferences`
//     after the run; assert `preference_violations == 0`.
//   - Verify `critical` events bypass Quiet_Hours; `actor == recipient`
//     self-suppression holds; mute on `target_id` holds except for
//     un-mutable critical events.
//   - Capture `preference_resolution_latency_ms` p95 from the SUT's
//     metrics surface and assert ≤ 10 ms (G-L10).
//
// Usage:
//   k6 run \
//     --env RUN_ID=... \
//     --env PUBLISHER_URL=http://localhost:8787 \
//     --env PREFERENCE_SHAPE=heavy_quiet_hours \
//     tests/notifications/load/k6/prefs.js
// ============================================================================

import http from 'k6/http';
import { check } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

import { buildThresholdsFor } from './lib/thresholds.ts';
import { generatePopulation } from './lib/recipients.ts';
import { buildWorkload, bendForPreferenceShape } from './lib/workload-mix.ts';

const RUN_ID = __ENV.RUN_ID || 'local-dev';
const PUBLISHER_URL = __ENV.PUBLISHER_URL || 'http://localhost:8787';
const EVENTS_PER_SECOND = parseInt(__ENV.EVENTS_PER_SECOND || '2000', 10);
const DURATION_SECONDS = parseInt(__ENV.DURATION_SECONDS || '300', 10);
const PREFERENCE_SHAPE = __ENV.PREFERENCE_SHAPE || 'default';
const HEAVY_QUIET_HOURS_RATIO = parseFloat(
    __ENV.HEAVY_QUIET_HOURS_RATIO || '0.5',
);
const RECIPIENT_SCALE = parseInt(__ENV.RECIPIENT_SCALE || '10000', 10);
const SEED = parseInt(__ENV.SEED || '0', 10) || undefined;

const inAppLatency = new Trend('uns_in_app_e2e_latency_ms', true);
const preferenceResolutionLatency = new Trend('uns_preference_resolution_ms', true);
const preferenceViolations = new Counter('uns_preference_violations');
const eventLoss = new Counter('uns_event_loss');
const availability = new Rate('uns_availability_pct');

export const options = {
    scenarios: {
        prefs: {
            executor: 'constant-arrival-rate',
            rate: EVENTS_PER_SECOND,
            timeUnit: '1s',
            duration: `${DURATION_SECONDS}s`,
            preAllocatedVUs: 500,
            maxVUs: 1000,
            exec: 'emit',
            tags: { scenario: 'SCN-PREFS', preference_shape: PREFERENCE_SHAPE },
        },
    },
    thresholds: buildThresholdsFor('SCN-PREFS'),
    summaryTrendStats: ['avg', 'p(95)', 'p(99)'],
};

export function setup() {
    return {
        run_id: RUN_ID,
        publisher_url: PUBLISHER_URL,
        knobs: {
            EVENTS_PER_SECOND,
            DURATION_SECONDS,
            PREFERENCE_SHAPE,
            HEAVY_QUIET_HOURS_RATIO,
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
    const base = buildWorkload({
        run_id: setupData.run_id,
        population: setupData.population,
        seed: hash32(`${setupData.run_id}:pf:${__VU}`),
    });
    _gen = bendForPreferenceShape(base, {
        heavy_quiet_hours_ratio: HEAVY_QUIET_HOURS_RATIO,
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

    void preferenceResolutionLatency;
    void preferenceViolations;
}

function hash32(str) {
    let hash = 0x811c9dc5;
    for (let i = 0; i < str.length; i++) {
        hash ^= str.charCodeAt(i);
        hash = Math.imul(hash, 0x01000193);
    }
    return hash >>> 0;
}
