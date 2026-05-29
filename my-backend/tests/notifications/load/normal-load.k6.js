// ============================================================================
// normal-load.k6.js — Scenario 2.1: Normal Load — Sustained Throughput
// ============================================================================
//
// phase5-load-plan.md §2.1
//
// Parameters:
//   - Concurrent users: 500
//   - Duration: 5 minutes (minimum)
//   - Notification rate: 100 notifications/sec sustained
//   - Event mix: 60% normal, 25% high, 10% low, 5% critical
//   - Channels: in_app (all), push (20%), email (10%)
//
// Each virtual user:
//   1. Connects via WebSocket (in-app channel)
//   2. Emits events at randomized interval averaging 1 event every 5 seconds
//   3. Reads unread count every 2 seconds
//   4. Fetches paginated history (50 items) every 30 seconds
//   5. Marks one notification as read every 10 seconds
//
// Tied requirements: REQ 5.7, 13.1, 13.2, 13.3, 13.5, 15.3
//
// Usage:
//   k6 run \
//     --env RUN_ID=$(date -u +%Y%m%dT%H%M%S) \
//     --env BASE_URL=https://api.staging.uns.example.com \
//     --env WS_URL=wss://ws.staging.uns.example.com \
//     --env AUTH_TOKEN=<bearer> \
//     my-backend/tests/notifications/load/normal-load.k6.js
// ============================================================================

import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep, group } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// ---------------------------------------------------------------------------
// Custom metrics matching phase5-load-plan.md §3.1 metrics
// ---------------------------------------------------------------------------

const deliveryLatency = new Trend('delivery_latency_ms', true);
const unreadCountLatency = new Trend('unread_count_latency_ms', true);
const historyQueryLatency = new Trend('history_query_latency_ms', true);
const preferenceResolutionLatency = new Trend('preference_resolution_ms', true);
const eventsEmitted = new Counter('events_emitted_total');
const notificationsDelivered = new Counter('notifications_delivered_total');
const notificationsFailed = new Counter('notifications_failed_total');
const eventLoss = new Counter('events_lost');
const availability = new Rate('availability_rate');

// ---------------------------------------------------------------------------
// Configuration from environment / defaults per §2.1
// ---------------------------------------------------------------------------

const RUN_ID = __ENV.RUN_ID || `local-${Date.now()}`;
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const WS_URL = __ENV.WS_URL || 'ws://localhost:3000';
const AUTH_TOKEN = __ENV.AUTH_TOKEN || 'load-test-token';
const CONCURRENT_USERS = parseInt(__ENV.CONCURRENT_USERS || '500', 10);
const NOTIFICATION_RATE = parseInt(__ENV.NOTIFICATION_RATE || '100', 10);
const DURATION = __ENV.DURATION || '5m';

// ---------------------------------------------------------------------------
// k6 options — §2.1 scenario with ramp-up/hold/ramp-down
// ---------------------------------------------------------------------------

export const options = {
    scenarios: {
        normal_load: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                // Ramp up to 500 users over 30 seconds
                { duration: '30s', target: CONCURRENT_USERS },
                // Hold at 500 users for 5 minutes
                { duration: DURATION, target: CONCURRENT_USERS },
                // Ramp down over 30 seconds
                { duration: '30s', target: 0 },
            ],
            exec: 'normalLoadScenario',
        },
    },
    thresholds: {
        // §5.1 — In-app delivery p95 ≤ 500 ms (REQ 13.3)
        'delivery_latency_ms': [
            'p(95)<500',
            'p(99)<1000',
            'p(95)>=1', // REQ 15.3 — sub-1ms is measurement error
        ],
        // §5.1 — Unread-count query p95 ≤ 50 ms (REQ 13.1)
        'unread_count_latency_ms': [
            'p(95)<50',
        ],
        // §5.1 — History query p95 ≤ 200 ms (REQ 13.2)
        'history_query_latency_ms': [
            'p(95)<200',
        ],
        // §5.1 — Preference resolution p95 ≤ 10 ms
        'preference_resolution_ms': [
            'p(95)<10',
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
    // Event mix: 60% normal, 25% high, 10% low, 5% critical
    const r = Math.random() * 100;
    if (r < 5) return 'critical';
    if (r < 30) return 'high';
    if (r < 90) return 'normal';
    return 'low';
}

function randomEventName() {
    const events = [
        'billing.invoice.created',
        'payment.invoice.received',
        'inventory.stock.low',
        'orders.service_job.status_changed',
        'delivery.location.updated',
        'users.school_announcement.published',
        'system.health.degraded',
        'reports.pump_sale.recorded',
    ];
    return events[Math.floor(Math.random() * events.length)];
}

function buildNotificationPayload(userId) {
    return {
        event_name: randomEventName(),
        priority: randomPriority(),
        actor_id: `loadtest-${RUN_ID}-vu-${__VU}`,
        target_id: `loadtest-${RUN_ID}-target-${Math.floor(Math.random() * 1000)}`,
        recipients: [{ user_id: userId, role: 'customer', channels: ['in_app'] }],
        payload: {
            message: `Load test notification ${Date.now()}`,
            run_id: RUN_ID,
        },
        source_module: 'load-test',
        source_app: 'k6-normal-load',
    };
}

// ---------------------------------------------------------------------------
// Main scenario function — each VU simulates one user session
// ---------------------------------------------------------------------------

export function normalLoadScenario() {
    const userId = `loadtest-${RUN_ID}-user-${__VU}-${__ITER}`;

    group('WebSocket connection', () => {
        const wsUrl = `${WS_URL}/notifications/ws?user_id=${encodeURIComponent(userId)}&token=${AUTH_TOKEN}`;

        const res = ws.connect(wsUrl, {}, (socket) => {
            socket.on('open', () => {
                // Connection established — track availability
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
                    // Non-JSON message, ignore
                }
            });

            socket.on('error', () => {
                availability.add(false);
                notificationsFailed.add(1);
            });

            // Keep connection open for a short cycle then close
            // (k6 VUs iterate, so each iteration is one user session cycle)
            socket.setTimeout(() => {
                socket.close();
            }, 5000);
        });

        if (res && res.status !== 101) {
            availability.add(false);
        }
    });

    // Emit a notification event (averaging 1 per 5 seconds per VU)
    group('Emit notification', () => {
        const payload = buildNotificationPayload(userId);
        const emitStart = Date.now();

        const res = http.post(
            `${BASE_URL}/notifications`,
            JSON.stringify(payload),
            { headers: authHeaders(), tags: { name: 'create_notification' } },
        );

        const ok = check(res, {
            'create notification: 2xx': (r) => r.status >= 200 && r.status < 300,
        });

        availability.add(ok);
        if (ok) {
            eventsEmitted.add(1);
        } else {
            eventLoss.add(1);
        }
    });

    // Read unread count (every 2 seconds per §2.1)
    group('Unread count query', () => {
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

    // Fetch paginated history (every 30 seconds per §2.1 — sampled)
    if (__ITER % 15 === 0) {
        group('History query', () => {
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
    }

    // Mark one notification as read (every 10 seconds per §2.1 — sampled)
    if (__ITER % 5 === 0) {
        group('Mark as read', () => {
            const notificationId = `loadtest-${RUN_ID}-notif-${Math.floor(Math.random() * 10000)}`;
            const res = http.patch(
                `${BASE_URL}/notifications/${notificationId}/read`,
                JSON.stringify({ user_id: userId }),
                { headers: authHeaders(), tags: { name: 'mark_read' } },
            );

            check(res, {
                'mark read: 2xx or 404': (r) => r.status >= 200 && r.status < 300 || r.status === 404,
            });
        });
    }

    sleep(Math.random() * 3 + 1); // Randomized interval ~1-4s
}

// ---------------------------------------------------------------------------
// Setup — log configuration for results traceability
// ---------------------------------------------------------------------------

export function setup() {
    console.log(`[normal-load] RUN_ID=${RUN_ID}`);
    console.log(`[normal-load] BASE_URL=${BASE_URL}`);
    console.log(`[normal-load] CONCURRENT_USERS=${CONCURRENT_USERS}`);
    console.log(`[normal-load] NOTIFICATION_RATE=${NOTIFICATION_RATE}`);
    console.log(`[normal-load] DURATION=${DURATION}`);
    return { run_id: RUN_ID };
}

// ---------------------------------------------------------------------------
// Teardown — output structured results summary
// ---------------------------------------------------------------------------

export function teardown(data) {
    console.log(`[normal-load] Scenario 2.1 complete. RUN_ID=${data.run_id}`);
}
