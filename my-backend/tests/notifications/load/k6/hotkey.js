// ============================================================================
// k6/hotkey.js — SCN-HOTKEY (phase5-load-plan.md §2.4)
// ============================================================================
//
// Steady-state baseline (§2.1) bent so that ONE tenant receives 40 % of
// dispatched notifications and ONE event_name (`inventory.stock.changed`)
// makes up 35 % of the publish stream. The rest follows the §3 mix.
//
// Tied requirements: REQ 4.4, 6.4, 6.5, 6.6, 9.5, 13.3, 15.5.
//
// STATUS: STUB — wiring complete (config + thresholds + bend helpers),
// scenario logic intentionally minimal so a CI run produces a clean
// "scenario configured" signal. The hotkey-bend mechanics are already
// implemented in `lib/workload-mix.ts` (`bendForHotkey`); this script
// composes them but leaves cross-tenant deviation tracking for the
// follow-up.
//
// TODO (phase5-load-plan.md §2.4 expectations to implement):
//   - Tag every emit with `tenant_class:hot|cold` so the per-tag
//     thresholds in `lib/thresholds.ts > hotkeyThresholds` actually fire.
//   - Capture per-tenant p95 over the scenario window and compare the
//     non-hot tenants' p95 against the prior SCN-STEADY p95 (must stay
//     within ±10 % per §7.1).
//   - Assert dedup correctness G-C3 holds even with the high duplicate
//     density (forward to verifier).
//
// Usage:
//   k6 run \
//     --env RUN_ID=... \
//     --env PUBLISHER_URL=http://localhost:8787 \
//     --env HOTKEY_TENANT_SHARE=0.4 \
//     --env HOTKEY_EVENT_SHARE=0.35 \
//     tests/notifications/load/k6/hotkey.js
// ============================================================================

import http from 'k6/http';
import { check } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

import { buildThresholdsFor } from './lib/thresholds.ts';
import { generatePopulation, isHotTenant } from './lib/recipients.ts';
import { buildWorkload, bendForHotkey } from './lib/workload-mix.ts';

const RUN_ID = __ENV.RUN_ID || 'local-dev';
const PUBLISHER_URL = __ENV.PUBLISHER_URL || 'http://localhost:8787';
const EVENTS_PER_SECOND = parseInt(__ENV.EVENTS_PER_SECOND || '2000', 10);
const DURATION_SECONDS = parseInt(__ENV.DURATION_SECONDS || '300', 10);
const HOTKEY_TENANT_SHARE = parseFloat(__ENV.HOTKEY_TENANT_SHARE || '0.4');
const HOTKEY_EVENT_SHARE = parseFloat(__ENV.HOTKEY_EVENT_SHARE || '0.35');
const HOT_EVENT_NAME = __ENV.HOT_EVENT_NAME || 'inventory.stock.changed';
const RECIPIENT_SCALE = parseInt(__ENV.RECIPIENT_SCALE || '10000', 10);
const SEED = parseInt(__ENV.SEED || '0', 10) || undefined;

const inAppLatency = new Trend('uns_in_app_e2e_latency_ms', true);
const eventLoss = new Counter('uns_event_loss');
const dedupViolations = new Counter('uns_dedup_violations');
const availability = new Rate('uns_availability_pct');

export const options = {
    scenarios: {
        hotkey: {
            executor: 'constant-arrival-rate',
            rate: EVENTS_PER_SECOND,
            timeUnit: '1s',
            duration: `${DURATION_SECONDS}s`,
            preAllocatedVUs: 500,
            maxVUs: 1000,
            exec: 'emit',
            tags: { scenario: 'SCN-HOTKEY' },
        },
    },
    thresholds: buildThresholdsFor('SCN-HOTKEY'),
    summaryTrendStats: ['avg', 'p(50)', 'p(95)', 'p(99)'],
};

export function setup() {
    return {
        run_id: RUN_ID,
        publisher_url: PUBLISHER_URL,
        knobs: { EVENTS_PER_SECOND, DURATION_SECONDS, HOTKEY_TENANT_SHARE, HOTKEY_EVENT_SHARE, HOT_EVENT_NAME, SEED: SEED ?? null },
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
        seed: hash32(`${setupData.run_id}:hk:${__VU}`),
    });
    _gen = bendForHotkey(base, {
        tenant_share: HOTKEY_TENANT_SHARE,
        event_share: HOTKEY_EVENT_SHARE,
        hot_event_name: HOT_EVENT_NAME,
    });
    return _gen;
}

export function emit(setupData) {
    const event = vuGenerator(setupData).next();
    // Tag with tenant_class so per-tag thresholds in lib/thresholds.ts fire.
    const tenantClass = event.recipients?.some((r) =>
        // Reach-around: detect hot recipients by tenant id prefix
        // (hot tenant is loadtest-<run_id>-tenant-000 per recipients.ts).
        /tenant-000/.test(r.user_id),
    )
        ? 'hot'
        : 'cold';

    const t0 = Date.now();
    const res = http.post(
        `${setupData.publisher_url}/publish`,
        JSON.stringify(event),
        {
            headers: { 'content-type': 'application/json' },
            tags: { tenant_class: tenantClass, event_name: event.event_name },
        },
    );
    const ok = check(res, { 'publish: 2xx': (r) => r.status >= 200 && r.status < 300 });
    availability.add(ok);
    if (!ok) eventLoss.add(1);
    else inAppLatency.add(Date.now() - t0, { tenant_class: tenantClass });

    void dedupViolations;
    void isHotTenant;
}

function hash32(str) {
    let hash = 0x811c9dc5;
    for (let i = 0; i < str.length; i++) {
        hash ^= str.charCodeAt(i);
        hash = Math.imul(hash, 0x01000193);
    }
    return hash >>> 0;
}
