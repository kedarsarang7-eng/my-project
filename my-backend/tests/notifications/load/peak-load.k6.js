// ============================================================================
// peak-load.k6.js — Scenario 2.2: Peak Load — Burst
// ============================================================================
//
// phase5-load-plan.md §2.2
//
// Parameters:
//   - Concurrent users: 1000
//   - Burst window: 10 seconds
//   - Notifications in burst: 5000 (500 notifications/sec)
//   - Ramp profile: 0 → 1000 users in 30s, hold 10s burst, then sustain
//     at 100 notif/sec for 3 minutes
//
// Simulates a flash event (e.g., end-of-day billing batch, school exam
// results publication) where many notifications fire simultaneously.
//
// Tied requirements: REQ 9.5, 9.6, 9.7, 9.8, 13.6
//
// Usage:
//   k6 run \
//     --env RUN_ID=$(date -u +%Y%m%dT%H%M%S) \
//     --env BASE_URL=https://api.staging.uns.example.com \
//     --env WS_URL=wss://ws.staging.uns.example.com \
//     --env AUTH_TOKEN=<bearer> \
//     my-backend/tests/notifications/load/peak-load.k6.js
// ============================================================================

import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep, group } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// ---------------------------------------------------------------------------
// Custom metrics matching phase5-load-plan.md §3.1
// ---------------------------------------------------------------------------

const deliveryLatency = new Trend('delivery_latency_ms', true);
const unreadCountLatency = new Trend('unread_count_latency_ms', true);
const historyQueryLatency = new Trend('history_query_latency_ms', true);
const burstDrainTime = new Trend('burst_drain_time_ms', true);
const eventsEmitted = new Counter('events_emitted_total');
const notificationsDelivered = new Counter('notifications_delivered_total');
const notificationsFailed = new Counter('notifications_failed_total');
const eventLoss = new Counter('events_lost');
const availability = new Rate('availability_rate');

// ---------------------------------------------------------------------------
// Configuration from environment / defaults per §2.2
// ---------------------------------------------------------------------------

const RUN_ID = __ENV.RUN_ID || `local-${Date.now()}`;
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const WS_URL = __ENV.WS_URL || 'ws://localhost:3000';
const AUTH_TOKEN = __ENV.AUTH_TOKEN || 'load-test-token';
const PEAK_USERS = parseInt(__ENV.PEAK_USERS || '1000', 10);
const BURST_RATE = parseInt(__ENV.BURST_RATE || '500', 10); // 500 notif/sec during burst
const SUSTAIN_RATE = parseInt(__ENV.SUSTAIN_RATE || '100', 10); // 100 notif/sec post-burst

// ---------------------------------------------------------------------------
// k6 options — §2.2 ramp profile
//
// Profile: 0 → 1000 users in 30s, hold burst for 10s, then sustain for 3min
// ---------------------------------------------------------------------------

export const options = {
    scenarios: {
        // Phase 1: Ramp up and burst — arrival-rate executor for precise control
        burst_phase: {
            executor: 'ramping-arrival-rate',
            startRate: SUSTAIN_RATE,
            timeUnit: '1s',
            preAllocatedVUs: Math.floor(PEAK_USERS / 2),
            maxVUs: PEAK_USERS * 2,
            stages: [
                // Ramp to peak users over 30 seconds
                { duration: '30s', target: BURST_RATE },
                // Hold burst at 500 notif/sec for 10 seconds (5000 total)
                { duration: '10s', target: BURST_RATE },
                // Ramp down to sustain rate
                { duration: '10s', target: SUSTAIN_RATE },
                // Sustain at 100 notif/sec for 3 minutes
                { duration: '3m', target: SUSTAIN_RATE },
            ],
            exec: 'burstEmit',
            tags: { scenario: 'peak-load-burst' },
        },
        // Phase 2: WebSocket receivers — constant VUs monitoring delivery
        ws_receivers: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '30s', target: PEAK_USERS },
                { duration: '3m40s', target: PEAK_USERS },
                { duration: '20s', target: 0 },
            ],
            exec: 'wsReceiver',
            tags: { scenario: 'peak-load-ws' },
        },
    },
    thresholds: {
        // §5.1 — In-app delivery p95 ≤ 500 ms
        'delivery_latency_ms': [
            'p(95)<500',
            'p(99)<1000',
            'p(95)>=1', // REQ 15.3
        ],
        // §5.1 — Unread-count query p95 ≤ 50 ms
        'unread_count_latency_ms': [
            'p(95)<50',
        ],
        // §5.1 — History query p95 ≤ 200 ms
        'history_query_latency_ms': [
            'p(95)<200',
        ],
        // §5.1 — Error rate < 1%
        'http_req_failed': ['rate<0.01'],
        // §5.1 — Zero event loss
        'events_lost': ['count==0'],
        // §5.1 — Availability > 99.9%
        'availability_rate': ['rate>0.999'],
    },
    summaryTrendStats: ['avg', 'min', 'max', 'p(50)', 'p(95)', 'p(99)'],
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function authHeaders() {
    return {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${AUTH_TOKEN}`,
    };
}

function randomPriority() {
    // Event mix per §2.1: 60% normal, 25% high, 10% low, 5% critical
    const r = Math.random() * 100;
    if (r < 5) return 'critical';
    if (r < 30) return 'high';
    if (r < 90) return 'normal';
    return 'low';
}

function randomEventName() {
    const events = [
        'billing.invoice.created',
        'billing.invoice.finalized',
        'payment.invoice.received',
        'payment.gateway.success',
        'inventory.stock.changed',
        'inventory.stock.low',
        'orders.restaurant_kot.created',
        'orders.service_job.status_changed',
        'delivery.restaurant.dispatched',
        'users.school_announcement.published',
    ];
    return events[Math.floor(Math.random() * events.length)];
}

function buildBurstPayload() {
    const userId = `loadtest-${RUN_ID}-user-${Math.floor(Math.random() * PEAK_USERS)}`;
    return {
        event_name: randomEventName(),
        priority: randomPriority(),
        actor_id: `loadtest-${RUN_ID}-vu-${__VU}`,
        target_id: `loadtest-${RUN_ID}-target-${Math.floor(Math.random() * 500)}`,
        recipients: [
            { user_id: userId, role: 'customer', channels: ['in_app'] },
            { user_id: `loadtest-${RUN_ID}-user-${Math.floor(Math.random() * PEAK_USERS)}`, role: 'admin', channels: ['in_app', 'push'] },
        ],
        payload: {
            message: `Burst notification ${Date.now()}`,
            run_id: RUN_ID,
            burst: true,
        },
        source_module: 'load-test',
        source_app: 'k6-peak-load',
    };
}

// ---------------------------------------------------------------------------
// Burst emit function — fires notifications at the configured rate
// ---------------------------------------------------------------------------

export function burstEmit() {
    const payload = buildBurstPayload();
    const emitStart = Date.now();

    const res = http.post(
        `${BASE_URL}/notifications`,
        JSON.stringify(payload),
        { headers: authHeaders(), tags: { name: 'burst_create_notification' } },
    );

    const ok = check(res, {
        'burst emit: 2xx': (r) => r.status >= 200 && r.status < 300,
    });

    availability.add(ok);
    if (ok) {
        eventsEmitted.add(1);
    } else {
        // 503 during burst is acceptable (backpressure) — not counted as loss
        if (res.status !== 503) {
            eventLoss.add(1);
        }
        notificationsFailed.add(1);
    }
}

// ---------------------------------------------------------------------------
// WebSocket receiver — monitors delivery latency during burst
// ---------------------------------------------------------------------------

export function wsReceiver() {
    const userId = `loadtest-${RUN_ID}-user-${__VU}`;
    const wsUrl = `${WS_URL}/notifications/ws?user_id=${encodeURIComponent(userId)}&token=${AUTH_TOKEN}`;

    const res = ws.connect(wsUrl, {}, (socket) => {
        socket.on('open', () => {
            availability.add(true);
        });

        socket.on('message', (msg) => {
            try {
                const data = JSON.parse(msg);
                if (data.type === 'notification' && data.created_at) {
                    const latency = Date.now() - new Date(data.created_at).getTime();
                    deliveryLatency.add(latency);
                    notificationsDelivered.add(1);
                }
            } catch (_) {
                // Non-JSON message
            }
        });

        socket.on('error', () => {
            availability.add(false);
        });

        // Hold connection for 10 seconds per iteration
        socket.setTimeout(() => {
            socket.close();
        }, 10000);
    });

    if (res && res.status !== 101) {
        availability.add(false);
    }

    // Between WS cycles, sample read queries
    group('Read queries during burst', () => {
        const userId = `loadtest-${RUN_ID}-user-${__VU}`;

        const unreadRes = http.get(
            `${BASE_URL}/notifications/unread-count?user_id=${encodeURIComponent(userId)}`,
            { headers: authHeaders(), tags: { name: 'unread_count' } },
        );
        if (unreadRes.status >= 200 && unreadRes.status < 300) {
            unreadCountLatency.add(unreadRes.timings.duration);
        }

        if (__ITER % 5 === 0) {
            const historyRes = http.get(
                `${BASE_URL}/notifications?user_id=${encodeURIComponent(userId)}&limit=50`,
                { headers: authHeaders(), tags: { name: 'history_query' } },
            );
            if (historyRes.status >= 200 && historyRes.status < 300) {
                historyQueryLatency.add(historyRes.timings.duration);
            }
        }
    });

    sleep(2);
}

// ---------------------------------------------------------------------------
// Setup / Teardown
// ---------------------------------------------------------------------------

export function setup() {
    console.log(`[peak-load] RUN_ID=${RUN_ID}`);
    console.log(`[peak-load] BASE_URL=${BASE_URL}`);
    console.log(`[peak-load] PEAK_USERS=${PEAK_USERS}`);
    console.log(`[peak-load] BURST_RATE=${BURST_RATE} notif/sec`);
    console.log(`[peak-load] SUSTAIN_RATE=${SUSTAIN_RATE} notif/sec`);
    return { run_id: RUN_ID, burst_start_ms: Date.now() + 30000 };
}

export function teardown(data) {
    console.log(`[peak-load] Scenario 2.2 complete. RUN_ID=${data.run_id}`);
}
