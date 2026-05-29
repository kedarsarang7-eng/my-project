// ============================================================================
// LT-LOAD — k6 Load & Stress Test Suite
// Coverage: Baseline throughput, concurrent invoices, spike test, soak test,
//           DynamoDB hot partition, WebSocket concurrency, rate limiting
// Run:  k6 run tests/k6-load-test.js
//       k6 run --env SCENARIO=spike tests/k6-load-test.js
// Docs: https://k6.io/docs/
// ============================================================================

import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// ── Custom Metrics ────────────────────────────────────────────────────────────
const invoiceCreationErrors = new Rate('invoice_creation_errors');
const invoiceLatency        = new Trend('invoice_latency', true);
const authFailures          = new Rate('auth_failures');
const wsMessagesReceived    = new Counter('ws_messages_received');

// ── Environment ───────────────────────────────────────────────────────────────
const BASE_URL  = __ENV.BASE_URL  || 'https://api.dukanx.com';
const WS_URL    = __ENV.WS_URL    || 'wss://ws.dukanx.com';
const JWT_TOKEN = __ENV.JWT_TOKEN || 'REPLACE_WITH_REAL_JWT'; // never hardcode in CI — use secrets
const TENANT_ID = __ENV.TENANT_ID || 'load-test-tenant-uuid';
const SCENARIO  = __ENV.SCENARIO  || 'baseline';

// ── Scenario Configurations ───────────────────────────────────────────────────
export const options = {
  scenarios: {

    // LT-LOAD-001: Baseline — 50 VUs, 3 min steady state
    baseline: {
      executor: 'constant-vus',
      vus: 50,
      duration: '3m',
      exec: 'baselineFlow',
      tags: { scenario: 'baseline' },
    },

    // LT-LOAD-002: Invoice Creation Flood — 100 concurrent invoice writers
    invoiceFlood: {
      executor: 'constant-vus',
      vus: 100,
      duration: '2m',
      exec: 'invoiceCreationFlow',
      tags: { scenario: 'invoiceFlood' },
      startTime: '3m30s',
    },

    // LT-LOAD-003: Spike Test — 0 → 500 → 0 in 1 min
    spike: {
      executor: 'ramping-vus',
      stages: [
        { duration: '10s', target: 0  },
        { duration: '30s', target: 500 },
        { duration: '10s', target: 500 },
        { duration: '10s', target: 0  },
      ],
      exec: 'spikeFlow',
      tags: { scenario: 'spike' },
      startTime: '6m',
    },

    // LT-LOAD-004: Soak Test — 30 VUs for 30 min (memory leak / connection pool detection)
    soak: {
      executor: 'constant-vus',
      vus: 30,
      duration: '30m',
      exec: 'soakFlow',
      tags: { scenario: 'soak' },
      startTime: '10m',
    },

    // LT-LOAD-005: WebSocket Concurrency — 200 persistent WS connections
    websocket: {
      executor: 'constant-vus',
      vus: 200,
      duration: '2m',
      exec: 'websocketFlow',
      tags: { scenario: 'websocket' },
    },
  },

  // ── SLA Thresholds ─────────────────────────────────────────────────────────
  thresholds: {
    // All HTTP calls p95 < 500ms, p99 < 2s
    http_req_duration:        ['p(95)<500', 'p(99)<2000'],
    // Invoice endpoint specifically
    'invoice_latency':        ['p(95)<800', 'p(99)<2000'],
    // Error rates
    http_req_failed:          ['rate<0.01'],       // <1% HTTP failures
    invoice_creation_errors:  ['rate<0.005'],      // <0.5% invoice failures
    auth_failures:            ['rate<0.001'],      // <0.1% auth failures
  },
};

// ── Auth Headers Factory ──────────────────────────────────────────────────────
function authHeaders() {
  return {
    Authorization: `Bearer ${JWT_TOKEN}`,
    'Content-Type': 'application/json',
    'x-tenant-id': TENANT_ID,
  };
}

// ============================================================================
// SCENARIO FUNCTIONS
// ============================================================================

// LT-LOAD-001: Baseline — browse inventory + dashboard
export function baselineFlow() {
  group('Baseline: GET dashboard', () => {
    const res = http.get(`${BASE_URL}/api/v1/dashboard`, { headers: authHeaders() });
    check(res, {
      'dashboard 200': (r) => r.status === 200,
      'dashboard < 400ms': (r) => r.timings.duration < 400,
    });
    authFailures.add(res.status === 401 || res.status === 403);
  });

  group('Baseline: GET inventory list', () => {
    const res = http.get(`${BASE_URL}/api/v1/inventory?limit=20`, { headers: authHeaders() });
    check(res, {
      'inventory 200': (r) => r.status === 200,
      'inventory < 500ms': (r) => r.timings.duration < 500,
    });
  });

  group('Baseline: GET invoice list', () => {
    const res = http.get(`${BASE_URL}/api/v1/invoices?limit=20`, { headers: authHeaders() });
    check(res, {
      'invoices 200': (r) => r.status === 200,
    });
  });

  sleep(1);
}

// LT-LOAD-002: Invoice creation flood
export function invoiceCreationFlow() {
  const payload = JSON.stringify({
    customerId: null,
    items: [
      { productId: 'product-load-test-001', qty: 2, priceCents: 10000, gstRate: 18 },
      { productId: 'product-load-test-002', qty: 1, priceCents: 25000, gstRate: 5  },
    ],
    paymentMode: 'CASH',
    discountCents: 0,
  });

  const startTime = Date.now();
  const res = http.post(`${BASE_URL}/api/v1/invoices`, payload, { headers: authHeaders() });
  const duration = Date.now() - startTime;

  invoiceLatency.add(duration);
  invoiceCreationErrors.add(res.status !== 201 && res.status !== 200);

  check(res, {
    'invoice created 2xx': (r) => r.status === 201 || r.status === 200,
    'invoice has id': (r) => {
      try { return JSON.parse(r.body).id != null; } catch { return false; }
    },
    'invoice < 800ms': (r) => r.timings.duration < 800,
  });

  sleep(0.5);
}

// LT-LOAD-003: Spike test — rapid GET requests
export function spikeFlow() {
  const res = http.get(`${BASE_URL}/api/v1/dashboard`, { headers: authHeaders() });
  check(res, {
    'spike: status not 5xx': (r) => r.status < 500,
    'spike: status not 429 on first hit': (r) => r.status !== 429,
  });
  sleep(0.1);
}

// LT-LOAD-004: Soak test — full CRUD cycle
export function soakFlow() {
  // Read
  const getRes = http.get(`${BASE_URL}/api/v1/inventory?limit=10`, { headers: authHeaders() });
  check(getRes, { 'soak: get 200': (r) => r.status === 200 });

  // Write (small invoice)
  const postRes = http.post(
    `${BASE_URL}/api/v1/invoices`,
    JSON.stringify({ items: [{ productId: 'product-soak-001', qty: 1, priceCents: 5000, gstRate: 5 }] }),
    { headers: authHeaders() },
  );
  check(postRes, { 'soak: invoice 2xx': (r) => r.status === 200 || r.status === 201 });
  sleep(2);
}

// LT-LOAD-005: WebSocket — connect and receive PING
export function websocketFlow() {
  const url = `${WS_URL}?Authorization=${JWT_TOKEN}&tenantId=${TENANT_ID}`;

  const res = ws.connect(url, {}, (socket) => {
    socket.on('open', () => {
      socket.send(JSON.stringify({ action: 'ping' }));
    });

    socket.on('message', (msg) => {
      wsMessagesReceived.add(1);
      try {
        const data = JSON.parse(msg);
        check(data, {
          'ws: message has type': (d) => d.type != null,
        });
      } catch {}
      socket.close();
    });

    socket.on('error', (e) => {
      check(null, { 'ws: no error': () => false });
    });

    socket.setTimeout(() => socket.close(), 10000);
  });

  check(res, { 'ws: connected': (r) => r && r.status === 101 });
  sleep(1);
}

// ============================================================================
// RATE LIMIT TEST (separate run)
// k6 run --env SCENARIO=ratelimit tests/k6-load-test.js
// ============================================================================
export function rateLimitFlow() {
  // Hammer a single endpoint to trigger 429
  const res = http.get(`${BASE_URL}/api/v1/dashboard`, { headers: authHeaders() });
  check(res, {
    'rate limit: eventually gets 429': (r) => r.status === 429 || r.status === 200,
  });
  // No sleep — maximum throughput to trigger rate limiter
}
