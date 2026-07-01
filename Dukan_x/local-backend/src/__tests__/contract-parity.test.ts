// ============================================================================
// Integration test — REST + Socket.io contract parity & loopback-only binding
// ============================================================================
// Spec: offline-license-activation — Task 2.4
//   "Assert REST + Socket.io contract parity skeleton against AWS shapes and
//    loopback-only binding."
//   Requirements: 3.2, 3.4, 17.6
//
// What this verifies:
//   • Req 3.2  — the Local_Backend serves the SAME ApiResponse envelope the AWS
//                backend exposes: GET /health returns the AWS-style success
//                envelope; documented REST routes exist and return the standard
//                envelope shapes (protected routes without auth → 401
//                UNAUTHORIZED; unknown route → 404 NOT_FOUND; scaffold stubs →
//                501 NOT_IMPLEMENTED). The response shape is asserted against
//                the mirrored ApiResponse contract.
//   • Req 4.3 (skeleton) — the Socket.io gateway is wired onto the same loopback
//                HTTP server and the engine.io handshake responds.
//   • Req 3.4 / 17.6 — the real server binds ONLY to the Loopback_Address
//                127.0.0.1:8765 (never 0.0.0.0 / a public interface).
//
// REST assertions run against buildApp() via supertest (no socket bound).
// The binding + Socket.io handshake assertions start the real server via
// startServer() and tear it down afterwards.
// ============================================================================

import type { AddressInfo } from 'net';
import type { Server as HttpServer } from 'http';
import { generateKeyPairSync } from 'crypto';
import request from 'supertest';
import { io as ioClient, Socket as ClientSocket } from 'socket.io-client';

import { buildApp } from '../app';
import { startServer, stopServer } from '../server';
import {
    LOOPBACK_HOST,
    LOOPBACK_PORT,
    LOOPBACK_BASE_URI,
    SOCKET_IO_PATH,
    SERVICE_NAME,
} from '../config/constants';
import { ApiResponse } from '../contracts/api.contract';
import { OfflineAuthService } from '../services/offline-auth.service';
import { setOfflineAuthService } from '../services/auth-service-registry';

// ── Real RS256 auth wiring for the integration test ─────────────────────────
// require-auth now performs REAL RS256 verification via the Offline_Auth_Service
// (Req 17.7/17.14), so reaching a route BEHIND the auth gate requires a token
// that genuinely verifies. We provision an ephemeral RSA key pair (exposed via
// the same env seam the signing-keys loader reads) and register a real
// Offline_Auth_Service, then mint a valid local-auth JWT to use as the bearer.
let BEARER = '';

beforeAll(() => {
    const { privateKey } = generateKeyPairSync('rsa', {
        modulusLength: 2048,
        publicKeyEncoding: { type: 'spki', format: 'pem' },
        privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });
    process.env.LOCAL_AUTH_PRIVATE_KEY = privateKey;

    // No session registry is wired, so verifyToken validates signature + issuer
    // + expiry only — exactly what the auth gate needs for these contract tests.
    const lookup = async () => null;
    const service = new OfflineAuthService(lookup);
    setOfflineAuthService(service);

    BEARER = `Bearer ${service.issueToken({ userId: 'u-test', tenantId: 't-test', role: 'owner' })}`;
});

afterAll(() => {
    setOfflineAuthService(null);
    delete process.env.LOCAL_AUTH_PRIVATE_KEY;
});

/**
 * Assert that an arbitrary response body conforms to the mirrored AWS
 * `ApiResponse` envelope contract (Req 3.2). Returns the typed body so callers
 * can make further field assertions.
 */
function expectApiEnvelope(body: unknown): ApiResponse {
    expect(body).toBeDefined();
    expect(typeof body).toBe('object');
    const env = body as ApiResponse;

    // Discriminant + AWS-parity fields present on EVERY response.
    expect(['success', 'error']).toContain(env.status);
    expect(typeof env.code).toBe('number');
    expect(typeof env.message).toBe('string');
    expect(typeof env.success).toBe('boolean');

    // `status`/`success` must agree.
    expect(env.success).toBe(env.status === 'success');

    // Standard meta carries a timestamp in both modes.
    expect(env.meta).toBeDefined();
    expect(typeof env.meta?.timestamp).toBe('string');

    if (env.success) {
        expect(env).toHaveProperty('data');
    } else {
        // Error envelope carries a structured { code, message } error object.
        expect(env.error).toBeDefined();
        const err = env.error as { code: string; message: string };
        expect(typeof err.code).toBe('string');
        expect(typeof err.message).toBe('string');
    }
    return env;
}

// ── Documented REST contract surface (mirrors my-backend route map) ──────────
// These are the authenticated routes scaffolded in api.routes.ts; each mirrors
// an AWS my-backend route (method + path). With a valid bearer token AND valid
// input they must resolve to a real handler returning the standard envelope
// (501 NOT_IMPLEMENTED in the scaffold), proving the contract route EXISTS.
//
// Each entry carries a VALID body/query payload so it passes the per-route
// schema validation (Req 17.8) and reaches the handler. Routes with no declared
// input leave them undefined.
interface DocumentedRoute {
    method: 'get' | 'post' | 'put' | 'delete';
    path: string;
    body?: Record<string, unknown>;
    query?: Record<string, string>;
}

const DOCUMENTED_PROTECTED_ROUTES: ReadonlyArray<DocumentedRoute> = [
    { method: 'post', path: '/license/validate', body: { licenseKey: 'DKNX-TEST-KEY' } },
    { method: 'post', path: '/license/activate', body: { licenseKey: 'DKNX-TEST-KEY', fingerprint: {} } },
    { method: 'get', path: '/license/status' },
    { method: 'get', path: '/dashboard' },
    { method: 'get', path: '/inventory' },
    { method: 'post', path: '/inventory', body: { name: 'Widget' } },
    { method: 'post', path: '/invoices', body: { items: [{ sku: 'X', qty: 1 }] } },
    { method: 'post', path: '/stock/lookup-barcode', body: { barcode: '8901234567890' } },
    { method: 'post', path: '/stock/add', body: { productId: 'p-1', quantity: 5 } },
    { method: 'get', path: '/payments' },
    { method: 'post', path: '/payments', body: { amount: 100 } },
    { method: 'get', path: '/customers' },
    { method: 'get', path: '/products' },
    { method: 'get', path: '/storage/signed-url', query: { key: 'objects/report.pdf' } },
    { method: 'post', path: '/sync/push', body: { changes: [] } },
    { method: 'post', path: '/sync/pull', body: {} },
    { method: 'get', path: '/reports/sales' },
    { method: 'get', path: '/reports/gstr1' },
];

describe('REST contract parity skeleton (Req 3.2)', () => {
    const app = buildApp();

    test('GET /health returns the AWS-style success envelope (public, no auth)', async () => {
        const res = await request(app).get('/health');

        expect(res.status).toBe(200);
        const env = expectApiEnvelope(res.body);

        // AWS-style success envelope: { success/status/code/data }.
        expect(env.status).toBe('success');
        expect(env.success).toBe(true);
        expect(env.code).toBe(200);

        // Health payload identifies this packaged backend to the supervisor.
        const data = env.data as Record<string, unknown>;
        expect(data.status).toBe('healthy');
        expect(data.service).toBe(SERVICE_NAME);
        expect(data.port).toBe(LOOPBACK_PORT);
        expect(data.mode).toBe('offline_lifetime');
    });

    test('protected routes without auth return the 401 UNAUTHORIZED envelope', async () => {
        const res = await request(app).get('/products'); // no Authorization header

        expect(res.status).toBe(401);
        const env = expectApiEnvelope(res.body);
        expect(env.status).toBe('error');
        expect(env.success).toBe(false);
        expect(env.code).toBe(401);
        expect((env.error as { code: string }).code).toBe('UNAUTHORIZED');
    });

    test('every documented protected route is gated by auth (401 without a token)', async () => {
        for (const route of DOCUMENTED_PROTECTED_ROUTES) {
            let req = request(app)[route.method](route.path);
            if (route.query) req = req.query(route.query);
            const res = route.body ? await req.send(route.body) : await req;
            expect(res.status).toBe(401);
            const env = expectApiEnvelope(res.body);
            expect((env.error as { code: string }).code).toBe('UNAUTHORIZED');
        }
    });

    test('every documented protected route EXISTS and returns the standard envelope when authed', async () => {
        for (const route of DOCUMENTED_PROTECTED_ROUTES) {
            let req = request(app)[route.method](route.path).set('Authorization', BEARER);
            if (route.query) req = req.query(route.query);
            const res = route.body ? await req.send(route.body) : await req;

            // The route is registered (not a 404) and its VALID input passes
            // schema validation (Req 17.8), so the scaffold handler returns the
            // standard NOT_IMPLEMENTED envelope. The SHAPE is the contract.
            expect(res.status).toBe(501);
            const env = expectApiEnvelope(res.body);
            expect(env.status).toBe('error');
            expect((env.error as { code: string }).code).toBe('NOT_IMPLEMENTED');
        }
    });

    test('auth credential-exchange endpoints are public and return the standard envelope', async () => {
        // /auth/* is mounted BEFORE requireAuth (pre-token); signup is a scaffold
        // stub, so it returns 501 (NOT 401) — proving it is reachable without a token.
        const res = await request(app).post('/auth/signup').send({});
        expect(res.status).toBe(501);
        const env = expectApiEnvelope(res.body);
        expect((env.error as { code: string }).code).toBe('NOT_IMPLEMENTED');
    });

    test('unknown route returns the 404 NOT_FOUND envelope', async () => {
        // A token is supplied so the request passes the auth gate and falls
        // through to the terminal 404 handler (rather than being rejected as 401).
        const res = await request(app).get('/this-route-does-not-exist').set('Authorization', BEARER);

        expect(res.status).toBe(404);
        const env = expectApiEnvelope(res.body);
        expect(env.status).toBe('error');
        expect(env.code).toBe(404);
        expect((env.error as { code: string }).code).toBe('NOT_FOUND');
    });
});

describe('Schema validation precedes processing (Req 17.8 / 17.15)', () => {
    const app = buildApp();

    test('a missing required body field is rejected with the VALIDATION_ERROR envelope', async () => {
        // /stock/add requires productId + quantity; sending neither must be
        // rejected by the validation middleware BEFORE the handler runs.
        const res = await request(app).post('/stock/add').set('Authorization', BEARER).send({});

        expect(res.status).toBe(400);
        const env = expectApiEnvelope(res.body);
        expect(env.status).toBe('error');
        const err = env.error as { code: string; details?: { errors?: string[] } };
        expect(err.code).toBe('VALIDATION_ERROR');
        // The failure indication lists the offending fields (Req 17.15).
        expect(Array.isArray(err.details?.errors)).toBe(true);
        expect((err.details?.errors ?? []).length).toBeGreaterThan(0);
    });

    test('a wrong-typed body field is rejected with VALIDATION_ERROR (no handler reached)', async () => {
        // quantity must be an integer; a string must fail validation rather than
        // fall through to the NOT_IMPLEMENTED handler — proving validation runs
        // FIRST (a schema-invalid request never reaches processing/persistence).
        const res = await request(app)
            .post('/stock/add')
            .set('Authorization', BEARER)
            .send({ productId: 'p-1', quantity: 'not-a-number' });

        expect(res.status).toBe(400);
        const env = expectApiEnvelope(res.body);
        expect((env.error as { code: string }).code).toBe('VALIDATION_ERROR');
    });

    test('a missing required query param is rejected with VALIDATION_ERROR', async () => {
        // /storage/signed-url requires a `key` query param.
        const res = await request(app).get('/storage/signed-url').set('Authorization', BEARER);

        expect(res.status).toBe(400);
        const env = expectApiEnvelope(res.body);
        expect((env.error as { code: string }).code).toBe('VALIDATION_ERROR');
    });

    test('valid input passes validation and reaches the handler (501 scaffold)', async () => {
        const res = await request(app)
            .post('/stock/add')
            .set('Authorization', BEARER)
            .send({ productId: 'p-1', quantity: 5 });

        expect(res.status).toBe(501);
        const env = expectApiEnvelope(res.body);
        expect((env.error as { code: string }).code).toBe('NOT_IMPLEMENTED');
    });

    test('validation runs AFTER auth — no token still yields 401, not 400', async () => {
        // The auth gate (Req 17.7/17.14) precedes validation: an unauthenticated
        // request with invalid input is rejected as UNAUTHORIZED, never leaking
        // that its body was also invalid.
        const res = await request(app).post('/stock/add').send({});
        expect(res.status).toBe(401);
        const env = expectApiEnvelope(res.body);
        expect((env.error as { code: string }).code).toBe('UNAUTHORIZED');
    });
});

describe('Socket.io gateway + loopback-only binding (Req 3.4 / 17.6 / 4.3)', () => {
    let server: HttpServer;

    beforeAll(async () => {
        server = await startServer();
    });

    afterAll(async () => {
        await stopServer();
    });

    test('the server binds ONLY to the Loopback_Address 127.0.0.1:8765 (never 0.0.0.0)', () => {
        const address = server.address() as AddressInfo;
        expect(address).not.toBeNull();
        expect(typeof address).toBe('object');

        // Bound host is the loopback address, not a public/wildcard interface.
        expect(address.address).toBe(LOOPBACK_HOST);
        expect(address.address).toBe('127.0.0.1');
        expect(address.address).not.toBe('0.0.0.0');
        expect(address.address).not.toBe('::');

        // Bound on the documented offline port.
        expect(address.port).toBe(LOOPBACK_PORT);
    });

    test('the Socket.io engine.io handshake responds on the same loopback server', async () => {
        // Skeleton check that the Socket.io gateway is wired onto the loopback
        // HTTP server: a client completes the engine.io handshake and connects.
        const client: ClientSocket = ioClient(LOOPBACK_BASE_URI, {
            path: SOCKET_IO_PATH,
            transports: ['websocket'],
            reconnection: false,
            timeout: 5000,
        });

        try {
            await new Promise<void>((resolve, reject) => {
                client.on('connect', () => resolve());
                client.on('connect_error', (err: Error) => reject(err));
            });

            expect(client.connected).toBe(true);
            expect(typeof client.id).toBe('string');
        } finally {
            client.disconnect();
        }
    });

    test('the loopback server still serves the REST health contract over the bound port', async () => {
        // Confirms REST + Socket.io share the SAME loopback server (Req 4.2/4.3).
        const res = await request(LOOPBACK_BASE_URI).get('/health');
        expect(res.status).toBe(200);
        const env = expectApiEnvelope(res.body);
        expect(env.status).toBe('success');
    });
});
