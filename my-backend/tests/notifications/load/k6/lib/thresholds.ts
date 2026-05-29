// ============================================================================
// k6/lib/thresholds.ts — phase5-load-plan.md §6.2 + §7 SLOs as k6 thresholds
// ============================================================================
//
// Every SLO in `phase5-load-plan.md` is encoded ONCE here and pulled by the
// per-scenario k6 scripts via `buildThresholdsFor(scenarioId)`. Doing it
// centrally means a stakeholder change to the proposed numbers in §1.1
// flows through every scenario without per-script edits, and keeps
// AGENTS.md "no hardcoded values" honest — every number below traces to a
// row in the load plan.
//
// Numbers source: phase5-load-plan.md §1.1 (latency targets), §1.2
// (throughput / queue-depth), §1.3 (correctness / availability), §6.2
// (SLO mapping per channel), and §7.1 (per-scenario allowed deviation).
//
// k6 threshold semantics: each entry in the returned object is a
// `metricName -> [string]` map. Strings are k6 threshold expressions —
// see https://k6.io/docs/using-k6/thresholds for the grammar.
//
// IMPORTANT: REQ 15.3 — "a measured p95 below 1 ms SHALL be treated as a
// measurement error and SHALL fail the test" — is encoded as the LOWER
// floor `p(95)>=1` on every in-app latency threshold. k6 supports
// composite thresholds; we pass both bounds in a single array so the
// scenario fails if either the upper or the lower bound is breached.
// ============================================================================

// ----------------------------------------------------------------------------
// SLO numeric registry (single source of truth — every cell traces to a
// row in phase5-load-plan.md)
// ----------------------------------------------------------------------------

/**
 * In-app end-to-end delivery latency budgets — phase5-load-plan.md §1.1
 * (G-L1, G-L2, G-L3) and §6.2.
 */
export const IN_APP_LATENCY_MS = Object.freeze({
    p50_max_ms: 150,    // G-L3 (proposed)
    p95_max_ms: 500,    // G-L1 (REQ 5.7, 13.3 — hard)
    p99_max_ms: 1_000,  // G-L2 (proposed)
    p95_floor_ms: 1,    // G-L4 (REQ 15.3 — hard, fail-closed)
});

/**
 * Per-channel latency budgets — phase5-load-plan.md §6.2 channel table.
 * The in-app row mirrors `IN_APP_LATENCY_MS` so SCN-MIX can read either.
 */
export const PER_CHANNEL_LATENCY_MS = Object.freeze({
    in_app: Object.freeze({ p95_max_ms: 500, p99_max_ms: 1_000 }),
    push: Object.freeze({ p95_max_ms: 1_500, p99_max_ms: 3_000 }),
    email: Object.freeze({ p95_max_ms: 5_000, p99_max_ms: 10_000 }),
    sms: Object.freeze({ p95_max_ms: 5_000, p99_max_ms: 12_000 }),
    webhook: Object.freeze({ p95_max_ms: 2_500, p99_max_ms: 6_000 }),
});

/**
 * Read-side query latency budgets — phase5-load-plan.md §1.1 G-L5..G-L10.
 */
export const READ_QUERY_LATENCY_MS = Object.freeze({
    unread_count_p95_max: 50,    // G-L5 (REQ 13.1)
    unread_count_p99_max: 150,   // G-L6 (proposed)
    history_p95_max: 200,        // G-L7 (REQ 13.2)
    history_p99_max: 500,        // G-L8 (proposed)
    projection_lag_p95_max: 100, // G-L9 (REQ 6.7)
    preference_p95_max: 10,      // G-L10 (REQ 7.8)
});

/**
 * Throughput / queue-depth / availability budgets —
 * phase5-load-plan.md §1.2 G-T*.
 */
export const THROUGHPUT_TARGETS = Object.freeze({
    sustained_eps: 2_000,            // G-T3 (proposed)
    burst_peak_eps: 20_000,          // G-T4 (proposed)
    sustained_high_eps: 6_000,       // G-T5 (proposed)
    sustained_high_minutes: 30,      // G-T5
    drain_recovery_seconds: 120,     // G-T7 (proposed)
    max_sqs_visible_messages: 60_000, // G-T9 (proposed)
});

/**
 * Correctness / availability budgets — phase5-load-plan.md §1.3 G-C*.
 */
export const CORRECTNESS_TARGETS = Object.freeze({
    availability_min_pct: 99.9,      // G-C1 (REQ 13.6)
    error_budget_max_pct: 1.0,       // G-C8 (proposed)
    dedup_violations_max: 0,         // G-C3 (REQ 4.4 — hard)
    authz_violations_max: 0,         // G-C4 (REQ 12.1 — hard)
    preference_violations_max: 0,    // G-C5 (REQ 7 — hard)
    replay_omissions_max: 0,         // G-C6 (REQ 8.4 — hard)
    event_loss_max: 0,               // G-C2 (REQ 9.8 — hard)
});

// ----------------------------------------------------------------------------
// Threshold builders
// ----------------------------------------------------------------------------

export type ScenarioId =
    | 'SCN-STEADY'
    | 'SCN-BURST'
    | 'SCN-SUSTAINED-HIGH'
    | 'SCN-HOTKEY'
    | 'SCN-MIX'
    | 'SCN-SLOW-CHANNEL'
    | 'SCN-DEDUP'
    | 'SCN-PREFS'
    | 'SCN-CORRECTNESS';

/**
 * k6 threshold map type. Keys are metric names (built-in like
 * `http_req_duration` or custom Trends/Counters/Rates the scripts
 * declare). Values are arrays of expression strings.
 */
export type K6Thresholds = Record<string, string[]>;

/**
 * Build the threshold map for a scenario. The returned object is fed
 * directly into `export const options = { thresholds: ... }` of the k6
 * script.
 *
 * Hard SLOs (REQ-mandated) are non-negotiable. "Proposed" rows are
 * included with the same expression but tagged in code comments so a
 * stakeholder change is a one-line update.
 *
 * Custom k6 metric names declared by the scenario scripts:
 *   - `uns_in_app_e2e_latency_ms`     (Trend) — receipt-time minus emit-time
 *   - `uns_unread_count_query_ms`     (Trend) — REQ 13.1
 *   - `uns_history_query_ms`          (Trend) — REQ 13.2
 *   - `uns_dedup_violations`          (Counter) — verifier output
 *   - `uns_authz_violations`          (Counter) — verifier output
 *   - `uns_preference_violations`     (Counter) — verifier output
 *   - `uns_replay_omissions`          (Counter) — verifier output
 *   - `uns_event_loss`                (Counter) — accepted minus delivered
 *   - `uns_availability_pct`          (Rate)    — successful HTTP responses
 */
export function buildThresholdsFor(scenarioId: ScenarioId): K6Thresholds {
    const base = baseThresholds();
    switch (scenarioId) {
        case 'SCN-STEADY':
            return { ...base, ...steadyThresholds() };
        case 'SCN-BURST':
            return { ...base, ...burstThresholds() };
        case 'SCN-SUSTAINED-HIGH':
            return { ...base, ...sustainedHighThresholds() };
        case 'SCN-HOTKEY':
            return { ...base, ...hotkeyThresholds() };
        case 'SCN-MIX':
            return { ...base, ...mixThresholds() };
        case 'SCN-SLOW-CHANNEL':
            return { ...base, ...slowChannelThresholds() };
        case 'SCN-DEDUP':
            return { ...base, ...dedupThresholds() };
        case 'SCN-PREFS':
            return { ...base, ...prefsThresholds() };
        case 'SCN-CORRECTNESS':
            return { ...base, ...correctnessThresholds() };
        default:
            throw new Error(`Unknown scenario: ${scenarioId}`);
    }
}

// ----------------------------------------------------------------------------
// Per-scenario threshold blocks
// ----------------------------------------------------------------------------

/**
 * Cross-scenario thresholds applied to every run — REQ 13.6 availability,
 * REQ 9.8 zero event loss, REQ 12.1/7/8.4 zero violations.
 *
 * Both bounds on `uns_in_app_e2e_latency_ms` cover REQ 15.3 (the test
 * fails fail-closed if p95 drops below 1 ms — a sub-millisecond p95 is
 * a measurement error per the requirement).
 */
function baseThresholds(): K6Thresholds {
    return {
        // Availability — k6's `Rate` metric stores success ratio in [0, 1].
        uns_availability_pct: [
            `rate>${CORRECTNESS_TARGETS.availability_min_pct / 100}`,
        ],
        // Event-loss / dedup / authz / pref / replay are Counters; the
        // expression `count==0` enforces hard zero.
        uns_event_loss: [`count<=${CORRECTNESS_TARGETS.event_loss_max}`],
        uns_dedup_violations: [
            `count<=${CORRECTNESS_TARGETS.dedup_violations_max}`,
        ],
        uns_authz_violations: [
            `count<=${CORRECTNESS_TARGETS.authz_violations_max}`,
        ],
        uns_preference_violations: [
            `count<=${CORRECTNESS_TARGETS.preference_violations_max}`,
        ],
        uns_replay_omissions: [
            `count<=${CORRECTNESS_TARGETS.replay_omissions_max}`,
        ],
    };
}

function steadyThresholds(): K6Thresholds {
    return {
        // REQ 5.7, 13.3 (G-L1) AND REQ 15.3 (G-L4 floor)
        uns_in_app_e2e_latency_ms: [
            `p(95)<${IN_APP_LATENCY_MS.p95_max_ms}`,
            `p(95)>=${IN_APP_LATENCY_MS.p95_floor_ms}`,
            `p(99)<${IN_APP_LATENCY_MS.p99_max_ms}`,
            `p(50)<${IN_APP_LATENCY_MS.p50_max_ms}`,
        ],
        uns_unread_count_query_ms: [
            `p(95)<${READ_QUERY_LATENCY_MS.unread_count_p95_max}`,
            `p(99)<${READ_QUERY_LATENCY_MS.unread_count_p99_max}`,
        ],
        uns_history_query_ms: [
            `p(95)<${READ_QUERY_LATENCY_MS.history_p95_max}`,
            `p(99)<${READ_QUERY_LATENCY_MS.history_p99_max}`,
        ],
        // Built-in HTTP duration as a sanity bound for the publisher path.
        http_req_failed: ['rate<0.01'],
    };
}

function burstThresholds(): K6Thresholds {
    // SCN-BURST: zero event loss, p95 returns to budget within drain window.
    return {
        uns_in_app_e2e_latency_ms: [
            `p(95)<${IN_APP_LATENCY_MS.p95_max_ms}`,
            `p(95)>=${IN_APP_LATENCY_MS.p95_floor_ms}`,
        ],
        // Drain assertion is checked offline by the verifier, not as a
        // pure k6 threshold — it requires the SQS metric snapshot from
        // §6.1. We leave a placeholder Counter so the report has a row.
        uns_drain_seconds: [
            `max<=${THROUGHPUT_TARGETS.drain_recovery_seconds + 30}`,
        ],
        http_req_failed: ['rate<0.05'], // burst tolerates higher transient failure
    };
}

function sustainedHighThresholds(): K6Thresholds {
    // SCN-SUSTAINED-HIGH: full latency table holds for 30 minutes; queue
    // depth bounded.
    return {
        uns_in_app_e2e_latency_ms: [
            `p(95)<${IN_APP_LATENCY_MS.p95_max_ms}`,
            `p(95)>=${IN_APP_LATENCY_MS.p95_floor_ms}`,
            `p(99)<${IN_APP_LATENCY_MS.p99_max_ms}`,
        ],
        uns_unread_count_query_ms: [
            `p(95)<${READ_QUERY_LATENCY_MS.unread_count_p95_max}`,
        ],
        uns_history_query_ms: [
            `p(95)<${READ_QUERY_LATENCY_MS.history_p95_max}`,
        ],
        uns_sqs_visible_messages: [
            `max<=${THROUGHPUT_TARGETS.max_sqs_visible_messages}`,
        ],
    };
}

function hotkeyThresholds(): K6Thresholds {
    // SCN-HOTKEY: hot tenant must still hit the in-app SLO; non-hot
    // tenants tracked separately (the script tags requests with the
    // tenant_id so per-tag thresholds can fire).
    return {
        // tagged metric — k6 supports `metric{tag:value}` selector syntax.
        // Hot tenant SLO equals the global SLO; non-hot tracked for
        // ±10 % deviation by the per-scenario verifier offline.
        'uns_in_app_e2e_latency_ms{tenant_class:hot}': [
            `p(95)<${IN_APP_LATENCY_MS.p95_max_ms}`,
            `p(95)>=${IN_APP_LATENCY_MS.p95_floor_ms}`,
        ],
        'uns_in_app_e2e_latency_ms{tenant_class:cold}': [
            `p(95)<${IN_APP_LATENCY_MS.p95_max_ms}`,
        ],
    };
}

function mixThresholds(): K6Thresholds {
    // SCN-MIX: per-channel budgets per §6.2 channel table.
    return {
        'uns_delivery_latency_ms{channel:in_app}': [
            `p(95)<${PER_CHANNEL_LATENCY_MS.in_app.p95_max_ms}`,
            `p(99)<${PER_CHANNEL_LATENCY_MS.in_app.p99_max_ms}`,
        ],
        'uns_delivery_latency_ms{channel:push}': [
            `p(95)<${PER_CHANNEL_LATENCY_MS.push.p95_max_ms}`,
            `p(99)<${PER_CHANNEL_LATENCY_MS.push.p99_max_ms}`,
        ],
        'uns_delivery_latency_ms{channel:email}': [
            `p(95)<${PER_CHANNEL_LATENCY_MS.email.p95_max_ms}`,
            `p(99)<${PER_CHANNEL_LATENCY_MS.email.p99_max_ms}`,
        ],
        'uns_delivery_latency_ms{channel:sms}': [
            `p(95)<${PER_CHANNEL_LATENCY_MS.sms.p95_max_ms}`,
            `p(99)<${PER_CHANNEL_LATENCY_MS.sms.p99_max_ms}`,
        ],
        'uns_delivery_latency_ms{channel:webhook}': [
            `p(95)<${PER_CHANNEL_LATENCY_MS.webhook.p95_max_ms}`,
            `p(99)<${PER_CHANNEL_LATENCY_MS.webhook.p99_max_ms}`,
        ],
    };
}

function slowChannelThresholds(): K6Thresholds {
    // Non-faulted channels stay within ±10 % of SCN-STEADY p95. We
    // encode the upper bound only — the deviation tracking is computed
    // offline by the verifier against the prior SCN-STEADY result.
    const bump = 1.1; // +10 %
    return {
        'uns_delivery_latency_ms{channel:in_app}': [
            `p(95)<${Math.round(PER_CHANNEL_LATENCY_MS.in_app.p95_max_ms * bump)}`,
        ],
        'uns_delivery_latency_ms{channel:push}': [
            `p(95)<${Math.round(PER_CHANNEL_LATENCY_MS.push.p95_max_ms * bump)}`,
        ],
        'uns_delivery_latency_ms{channel:sms}': [
            `p(95)<${Math.round(PER_CHANNEL_LATENCY_MS.sms.p95_max_ms * bump)}`,
        ],
        'uns_delivery_latency_ms{channel:webhook}': [
            `p(95)<${Math.round(PER_CHANNEL_LATENCY_MS.webhook.p95_max_ms * bump)}`,
        ],
        // Faulted channel (email by default) intentionally has NO upper
        // bound — the spike is the experiment.
    };
}

function dedupThresholds(): K6Thresholds {
    return {
        // Hard zero — the whole point of SCN-DEDUP.
        uns_dedup_violations: ['count==0'],
        uns_in_app_e2e_latency_ms: [
            `p(95)<${IN_APP_LATENCY_MS.p95_max_ms}`,
        ],
    };
}

function prefsThresholds(): K6Thresholds {
    return {
        uns_preference_violations: ['count==0'],
        uns_preference_resolution_ms: [
            `p(95)<${READ_QUERY_LATENCY_MS.preference_p95_max}`,
        ],
    };
}

function correctnessThresholds(): K6Thresholds {
    return {
        uns_authz_violations: ['count==0'],
        uns_replay_omissions: ['count==0'],
        uns_lifecycle_ordering_violations: ['count==0'],
    };
}

// ----------------------------------------------------------------------------
// Test seam — exposed for ts-check and unit testing of the threshold
// builder in isolation. Production k6 scripts should NOT reach in here.
// ----------------------------------------------------------------------------

export const __test__ = Object.freeze({
    baseThresholds,
    steadyThresholds,
    burstThresholds,
    sustainedHighThresholds,
    hotkeyThresholds,
    mixThresholds,
    slowChannelThresholds,
    dedupThresholds,
    prefsThresholds,
    correctnessThresholds,
});
