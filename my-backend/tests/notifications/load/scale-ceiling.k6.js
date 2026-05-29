// ============================================================================
// scale-ceiling.k6.js — Scenario 2.3: Scale Ceiling — 10,000 Concurrent Users
// ============================================================================
//
// phase5-load-plan.md §2.3
//
// Parameters:
//   - Concurrent users: 10,000
//   - Duration: 5 minutes
//   - Notification rate: 200 notifications/sec sustained
//   - Event mix: Same as §2.1 (60% normal, 25% high, 10% low, 5% critical)
//
// Purpose: Verify that the system maintains availability > 99.9% and zero
// event loss at the maximum documented capacity (REQ 13.6).
//
// Tied requirements: REQ 5.7, 13.1, 13.2, 13.5, 13.6
//
// Usage:
//   k6 run \
//     --env RUN_ID=$(date -u +%Y%m%dT%H%M%S) \
//     --env BASE_URL=https://api.staging.uns.example.com \
//     --env WS_URL=wss://ws.staging.uns.example.com \
//     --env AUTH_TOKEN=<bearer> \
//     my-backend/tests/notifications/load/scale-ceiling.k6.js
//
// NOTE: This scenario requires significant load-generator resources.
// Recommended: c5.2xlarge EC2 instance or equivalent (§6.2 in load plan).
// ============================================================================

import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep, group } from 'k6';
import { Trend, Counter, Rate, Gauge } from 'k6/metrics';

// ---------------------------------------------------------------------------
// Custom metrics matching phase5-load-plan.md §3.1
// ---------------------------------------------------------------------------

const deliveryLatency = new Trend('delivery_latency_ms', true);
const unreadCountLatency = new Trend('unread_count_latency_ms', true);
const historyQueryLatency = new Trend('history_query_latency_ms', true);
const wsConnectionCount = new Gauge('websocket_connection_count');
const eventsEmitted = new Counter('events_emitted_total');
const notificationsDelivered = new Counter('notifications_delivered_total');
const notificationsFailed = new Counter('notifications_failed_total');
const eventLoss = new Counter('events_lost');
const availability = new Rate('availability_rate');

// ---------------------------------------------------------------------------
// Configuration from environment / defaults per §2.3
// ---------------------------------------------------------------------------

const RUN_ID = __ENV.RUN_ID || `local-${Date.now()}`;
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const WS_URL = __ENV.WS_URL || 'ws://localhost:3000';
const AUTH_TOKEN = __ENV.AUTH_TOKEN || 'load-test-token';
const CONCURRENT_USERS = parseInt(__ENV.CONCURRENT_USERS || '10000', 10);
const NOTIFICATION_RATE = parseInt(__ENV.NOTIFICATION_RATE || '200', 10);
const DURATION = __ENV.DURATION || '5m';

// ---------------------------------------------------------------------------
// k6 options — §2.3 scenario with ramp-up/hold/ramp-down
//
// Two parallel scenarios:
//   1. ws_connections: Ramp 10,000 WebSocket connections (VU-based)
//   2. notification_emitter: Sustain 200 notif/sec (arrival-rate based)
// ---------------------------------------------------------------------------

export const options = {
    scenarios: {
        // WebSocket connections — each VU holds one persistent connection
        ws_connections: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                // Ramp up to 10,000 over 2 minutes (gradual to avoid thundering herd)
                { duration: '2m', target: CONCURRENT_USERS },
                // Hold at 10,000 for 5 minutes
                { duration: DURATION, target: CONCURRENT_USERS },
                // Ramp down over 1 minute
                { duration: '1m', target: 0 },
            ],
            exec: 'wsConnection',
            tags: { scenario: 'scale-ceiling-ws' },
        },
        // Notification emitter — constant arrival rate at 200/sec
        notification_emitter: {
            executor: 'constant-arrival-rate',
            rate: NOTIFICATION_RATE,
            timeUnit: '1s',
            duration: DURATION,
            preAllocatedVUs: 100,
            maxVUs: 500,
            exec: 'emitNotification',
            startTime: '2m', // Start after WS connections are ramped up
            tags: { scenario: 'scale-ceiling-emit' },
        },
        // Read-side queries — constant VUs sampling unread-count and history
        read_queries: {
            executor: 'constant-vus',
            vus: 50,
            duration: DURATION,
            exec: 'readQueries',
            startTime: '2m', // Start after WS connections are ramped up
            tags: { scenario: 'scale-ceiling-read' },
        },
    },
    thresholds: {
        // §5.1 — In-app delivery p95 ≤ 500 ms (REQ 5.7 at 10k connections)
        'delivery_latency_ms': [
            'p(95)<500',
            'p(99)<1000',
            'p(95)>=1', // REQ 15.3
        ],
        // §5.1 — Unread-count query p95 ≤ 50 ms (REQ 13.1)
        'unread_count_latency_ms': [
            'p(95)<50',
        ],
        // §5.1 — History query p95 ≤ 200 ms (REQ 13.2)
        'history_query_latency_ms': [
            'p(95)<200',
        ],
        // §5.1 — Error rate < 1%
        'http_req_failed': ['rate<0.01'],
        // §5.1 — Zero event loss (REQ 13.6)
        'events_lost': ['count==0'],
        // §5.1 — Availability > 99.9% (REQ 13.6)
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
    // Event mix same as §2.1: 60% normal, 25% high, 10% low, 5% critical
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
        'billing.invoice.updated',
        'billing.school_fee.assigned',
        'payment.invoice.received',
        'payment.gateway.success',
        'payment.refund.processed',
        'inventory.stock.changed',
        'inventory.stock.low',
        'orders.restaurant_kot.created',
        'orders.service_job.status_changed',
        'delivery.location.updated',
        'delivery.restaurant.dispatched',
        'users.school_announcement.published',
        'users.school_attendance.marked',
        'system.health.degraded',
    ];
    return events[Math.floor(Math.random() * events.length)];
}

// ---------------------------------------------------------------------------
// WebSocket connection scenario — each VU holds one persistent connection
// ---------------------------------------------------------------------------

export function wsConnection() {
    const userId = `loadtest-${RUN_ID}-user-${String(__VU).padStart(5, '0')}`;
    const wsUrl = `${WS_URL}/notifications/ws?user_id=${encodeURIComponent(userId)}&token=${AUTH_TOKEN}`;

    const res = ws.connect(wsUrl, {}, (socket) => {
        let connected = false;

        socket.on('open', () => {
            connected = true;
            availability.add(true);
            wsConnectionCount.add(1);
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
                // Non-JSON or ping/pong
            }
        });

        socket.on('error', () => {
            availability.add(false);
            notificationsFailed.add(1);
        });

        socket.on('close', () => {
            if (connected) {
                wsConnectionCount.add(-1);
            }
        });

        // Hold connection for 30 seconds per iteration (VU will reconnect)
        socket.setTimeout(() => {
            socket.close();
        }, 30000);
    });

    if (res && res.status !== 101) {
        availability.add(false);
    }

    sleep(1); // Brief pause before reconnecting
}

// ---------------------------------------------------------------------------
// Notification emitter — fires at constant 200/sec arrival rate
// ---------------------------------------------------------------------------

export function emitNotification() {
    const targetUser = `loadtest-${RUN_ID}-user-${String(Math.floor(Math.random() * CONCURRENT_USERS)).padStart(5, '0')}`;

    const payload = {
        event_name: randomEventName(),
        priority: randomPriority(),
        actor_id: `loadtest-${RUN_ID}-emitter-${__VU}`,
        target_id: `loadtest-${RUN_ID}-target-${Math.floor(Math.random() * 1000)}`,
        recipients: [
            { user_id: targetUser, role: 'customer', channels: ['in_app'] },
        ],
        payload: {
            message: `Scale ceiling notification ${Date.now()}`,
            run_id: RUN_ID,
            scale_test: true,
        },
        source_module: 'load-test',
        source_app: 'k6-scale-ceiling',
    };

    const res = http.post(
        `${BASE_URL}/notifications`,
        JSON.stringify(payload),
        { headers: authHeaders(), tags: { name: 'scale_create_notification' } },
    );

    const ok = check(res, {
        'scale emit: 2xx': (r) => r.status >= 200 && r.status < 300,
    });

    availability.add(ok);
    if (ok) {
        eventsEmitted.add(1);
    } else {
        eventLoss.add(1);
    }
}

// ---------------------------------------------------------------------------
// Read queries — constant VUs sampling unread-count and history endpoints
// ---------------------------------------------------------------------------

export function readQueries() {
    const userId = `loadtest-${RUN_ID}-user-${String(Math.floor(Math.random() * CONCURRENT_USERS)).padStart(5, '0')}`;

    // Unread count query
    group('Unread count at scale', () => {
        const res = http.get(
            `${BASE_URL}/notifications/unread-count?user_id=${encodeURIComponent(userId)}`,
            { headers: authHeaders(), tags: { name: 'unread_count' } },
        );

        const ok = check(res, {
            'unread count: 2xx': (r) => r.status >= 200 && r.status < 300,
        });

        if (ok) {
            unreadCountLatency.add(res.timings.duration);
        }
        availability.add(ok);
    });

    sleep(2);

    // History query (paginated, 50 items)
    group('History query at scale', () => {
        const res = http.get(
            `${BASE_URL}/notifications?user_id=${encodeURIComponent(userId)}&limit=50`,
            { headers: authHeaders(), tags: { name: 'history_query' } },
        );

        const ok = check(res, {
            'history query: 2xx': (r) => r.status >= 200 && r.status < 300,
        });

        if (ok) {
            historyQueryLatency.add(res.timings.duration);
        }
        availability.add(ok);
    });

    sleep(3);

    // Mark as read (sample)
    if (__ITER % 3 === 0) {
        group('Mark read at scale', () => {
            const notificationId = `loadtest-${RUN_ID}-notif-${Math.floor(Math.random() * 100000)}`;
            http.patch(
                `${BASE_URL}/notifications/${notificationId}/read`,
                JSON.stringify({ user_id: userId }),
                { headers: authHeaders(), tags: { name: 'mark_read' } },
            );
        });
    }

    sleep(2);
}

// ---------------------------------------------------------------------------
// Setup / Teardown
// ---------------------------------------------------------------------------

export function setup() {
    console.log(`[scale-ceiling] RUN_ID=${RUN_ID}`);
    console.log(`[scale-ceiling] BASE_URL=${BASE_URL}`);
    console.log(`[scale-ceiling] CONCURRENT_USERS=${CONCURRENT_USERS}`);
    console.log(`[scale-ceiling] NOTIFICATION_RATE=${NOTIFICATION_RATE}/sec`);
    console.log(`[scale-ceiling] DURATION=${DURATION}`);
    console.log(`[scale-ceiling] NOTE: Requires c5.2xlarge or equivalent load generator`);
    return { run_id: RUN_ID };
}

export function teardown(data) {
    console.log(`[scale-ceiling] Scenario 2.3 complete. RUN_ID=${data.run_id}`);
    console.log(`[scale-ceiling] Check availability_rate threshold for > 99.9% (REQ 13.6)`);
    console.log(`[scale-ceiling] Check events_lost counter for zero event loss (REQ 13.6)`);
}
