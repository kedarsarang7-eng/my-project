// @ts-nocheck
/// <reference types="jest" />
// ============================================================================
// Part 3 — Strict Customer Data Isolation Tests
// ============================================================================
// Proves a tenant/customer can NEVER read or mutate another tenant's customer
// data. Covers four isolation guarantees:
//
//   1. CROSS-TENANT FETCH → 404: PK built from auth.tenantId means a request
//      for tenant B's customer by a tenant A user yields no item.
//   2. DEFENSE-IN-DEPTH: even if an item were reachable, the tenantId
//      attribute guard rejects it (404, never leaking existence).
//   3. LIST SCOPING: listCustomers only returns the caller's tenant items.
//   4. SERVER-GENERATED ID: createCustomer never trusts a client customerId.
//
// Run with: npx jest src/__tests__/customer-isolation.test.ts
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';

// ---- Mock Auth: tenant A user ----------------------------------------------
const mockVerifyAuth = jest.fn().mockResolvedValue({
    sub: 'user-A',
    email: 'owner@a.com',
    tenantId: 'tenant-A',
    role: 'owner',
    businessType: 'grocery',
    planTier: 'enterprise',
});
jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: (...args: any[]) => mockVerifyAuth(...args),
    requireRole: jest.fn(),
    AuthError: class AuthError extends Error {
        statusCode: number;
        constructor(msg: string, code = 401) { super(msg); this.statusCode = code; this.name = 'AuthError'; }
    },
}));

// ---- Mock DynamoDB ---------------------------------------------------------
const mockGetItem = jest.fn();
const mockPutItem = jest.fn().mockResolvedValue(undefined);
const mockQueryItems = jest.fn();
const mockQueryAllItems = jest.fn();
const mockUpdateItem = jest.fn();

jest.mock('../config/dynamodb.config', () => ({
    TABLE_NAME: 'test-table',
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
        customerSK: (id: string) => `CUSTOMER#${id}`,
        customerBalanceSK: (id: string) => `CUSTOMER#${id}#BALANCE`,
        invoiceSK: (id: string) => `INVOICE#${id}`,
        paymentSK: (id: string) => `PAYMENT#${id}`,
        phoneGSI1SK: (p: string) => `PHONE#${p}`,
    },
    getItem: (...args: any[]) => mockGetItem(...args),
    putItem: (...args: any[]) => mockPutItem(...args),
    queryItems: (...args: any[]) => mockQueryItems(...args),
    queryAllItems: (...args: any[]) => mockQueryAllItems(...args),
    updateItem: (...args: any[]) => mockUpdateItem(...args),
}));

jest.mock('../middleware/plan-guard', () => ({
    validateFeatureAccess: jest.fn().mockResolvedValue(undefined),
    enforceLimits: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../middleware/software-lock', () => ({
    checkSoftwareLock: jest.fn().mockResolvedValue({ allowed: true, lockLevel: 'none', userMessage: '', metadata: {} }),
    LockLevel: { NONE: 'none', SOFT: 'soft', HARD: 'hard' },
}));
jest.mock('../services/revision-history.service', () => ({ recordRevision: jest.fn().mockResolvedValue(undefined) }));

import {
    getCustomer,
    getCustomerProfile,
    createCustomer,
    listCustomers,
    deleteCustomer,
} from '../handlers/customers';

// ---- Helpers ---------------------------------------------------------------
function makeEvent(overrides: Partial<APIGatewayProxyEventV2> = {}): APIGatewayProxyEventV2 {
    return {
        version: '2.0', routeKey: '$default', rawPath: '/', rawQueryString: '',
        headers: { authorization: 'Bearer test-token' },
        requestContext: {
            accountId: '123', apiId: 'test', domainName: 'test', domainPrefix: 'test',
            http: { method: 'GET', path: '/', protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'test' },
            requestId: 'r', routeKey: '$default', stage: '$default',
            time: new Date().toISOString(), timeEpoch: Date.now(),
        },
        isBase64Encoded: false,
        ...overrides,
    } as any;
}

const ctx: Context = {
    callbackWaitsForEmptyEventLoop: false, functionName: 't', functionVersion: '1',
    invokedFunctionArn: 'arn:aws:lambda:us-east-1:123:function:t', memoryLimitInMB: '128',
    awsRequestId: 'r', logGroupName: 'g', logStreamName: 's',
    getRemainingTimeInMillis: () => 30000, done: () => {}, fail: () => {}, succeed: () => {},
};

function parseBody(r: any) { return JSON.parse(r.body || '{}'); }

// A customer that belongs to tenant-B (a DIFFERENT tenant than the caller).
const TENANT_B_CUSTOMER = {
    PK: 'TENANT#tenant-B',
    SK: 'CUSTOMER#c-b',
    entityType: 'CUSTOMER',
    id: 'c-b',
    tenantId: 'tenant-B',
    name: 'Competitor Shop Customer',
    phone: '5550000',
    isDeleted: false,
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
};

describe('Part 3 — Strict Customer Data Isolation', () => {
    beforeEach(() => {
        mockGetItem.mockReset();
        mockPutItem.mockReset();
        mockQueryItems.mockReset();
        mockQueryAllItems.mockReset();
        mockUpdateItem.mockReset();
    });

    // ── 1. Cross-tenant fetch yields 404 (PK miss) ───────────────────────
    describe('cross-tenant fetch → 404', () => {
        test('getCustomer: PK scoped to auth.tenantId, tenant-B customer not found', async () => {
            // getItem is called with PK=TENANT#tenant-A (caller's tenant).
            // Tenant-B's customer lives at PK=TENANT#tenant-B, so the lookup
            // returns null here — the record is unreachable by construction.
            mockGetItem.mockResolvedValue(null);

            const result = await getCustomer(makeEvent({ pathParameters: { id: 'c-b' } }), ctx);

            expect(result.statusCode).toBe(404);
            // Critical: PK must be the CALLER's tenant, never a client-supplied one.
            expect(mockGetItem.mock.calls[0][0]).toBe('TENANT#tenant-A');
            expect(mockGetItem.mock.calls[0][1]).toBe('CUSTOMER#c-b');
        });

        test('getCustomerProfile: same PK scoping, tenant-B unreachable', async () => {
            mockGetItem.mockResolvedValue(null); // customer not found in tenant-A

            const result = await getCustomerProfile(makeEvent({ pathParameters: { id: 'c-b' } }), ctx);

            expect(result.statusCode).toBe(404);
            expect(mockGetItem.mock.calls[0][0]).toBe('TENANT#tenant-A');
        });

        test('deleteCustomer: tenant-B customer not deletable from tenant-A (404)', async () => {
            mockGetItem.mockResolvedValue(null);

            const result = await deleteCustomer(makeEvent({ pathParameters: { id: 'c-b' } }), ctx);

            expect(result.statusCode).toBe(404);
            expect(mockUpdateItem).not.toHaveBeenCalled();
        });
    });

    // ── 2. Defense-in-depth: tenantId attribute guard ─────────────────────
    describe('defense-in-depth tenantId attribute guard', () => {
        test('getCustomer: an item with a mismatched tenantId attribute is rejected (404)', async () => {
            // Simulate a (hypothetical) regression where an item bearing tenant-B's
            // tenantId somehow became reachable under tenant-A's PK. The guard must
            // still refuse to serve it — and must NOT leak that it exists.
            mockGetItem.mockResolvedValue({ ...TENANT_B_CUSTOMER, PK: 'TENANT#tenant-A' });

            const result = await getCustomer(makeEvent({ pathParameters: { id: 'c-b' } }), ctx);

            expect(result.statusCode).toBe(404);
            const body = parseBody(result);
            expect(JSON.stringify(body)).not.toContain('Competitor Shop Customer');
        });

        test('getCustomerProfile: mismatched tenantId attribute → 404, no balance leaked', async () => {
            mockGetItem.mockResolvedValue({ ...TENANT_B_CUSTOMER, PK: 'TENANT#tenant-A' });

            const result = await getCustomerProfile(makeEvent({ pathParameters: { id: 'c-b' } }), ctx);

            expect(result.statusCode).toBe(404);
            // Balance recompute must not run for a customer we don't own.
            expect(mockQueryAllItems).not.toHaveBeenCalled();
        });

        test('getCustomer: legacy item with no tenantId attribute is allowed (backward compat)', async () => {
            mockGetItem.mockResolvedValue({
                PK: 'TENANT#tenant-A',
                SK: 'CUSTOMER#c-a',
                id: 'c-a',
                name: 'Legacy Customer',
                isDeleted: false,
                // tenantId attribute intentionally absent
            });

            const result = await getCustomer(makeEvent({ pathParameters: { id: 'c-a' } }), ctx);
            expect(result.statusCode).toBe(200);
            expect(parseBody(result).data.name).toBe('Legacy Customer');
        });
    });

    // ── 3. List scoping ───────────────────────────────────────────────────
    describe('listCustomers tenant scoping', () => {
        test('only queries the caller tenant partition and returns only its customers', async () => {
            // queryAllItems is called with PK=TENANT#tenant-A.
            mockQueryAllItems.mockResolvedValue([
                { id: 'c-a1', name: 'A Customer 1', tenantId: 'tenant-A', isDeleted: false, createdAt: '2026-01-01T00:00:00.000Z' },
                { id: 'c-a2', name: 'A Customer 2', tenantId: 'tenant-A', isDeleted: false, createdAt: '2026-01-02T00:00:00.000Z' },
            ]);

            const result = await listCustomers(makeEvent({}), ctx);
            const body = parseBody(result);

            expect(result.statusCode).toBe(200);
            // paginated() returns the array directly in `data`.
            expect(body.data).toHaveLength(2);
            expect(body.data.every((c: any) => c.id.startsWith('c-a'))).toBe(true);
            // Critical: query ran against the CALLER's partition only.
            expect(mockQueryAllItems.mock.calls[0][0]).toBe('TENANT#tenant-A');
            expect(mockQueryAllItems.mock.calls[0][1]).toBe('CUSTOMER#');
        });
    });

    // ── 4. Server-generated customerId (no client trust) ──────────────────
    describe('createCustomer server-side id generation', () => {
        test('generated id is a UUID and ignores any client-supplied id', async () => {
            const newCustomerBody = {
                name: 'New Customer',
                phone: '9000000000',
                // A malicious client tries to forge an id + a foreign tenantId.
                id: 'attacker-forged-id',
                tenantId: 'tenant-B',
            };

            const result = await createCustomer(makeEvent({
                httpMethod: 'POST' as any,
                body: JSON.stringify(newCustomerBody),
                requestContext: { http: { method: 'POST', path: '/customers', protocol: 'HTTP/1.1', sourceIp: '1.1.1.1', userAgent: 't' } } as any,
            }), ctx);

            // The wrapper blocks the cross-tenant body injection first (401/403).
            // If it didn't, the handler must still stamp auth.tenantId + a fresh uuid.
            if (result.statusCode === 201) {
                const putArg = mockPutItem.mock.calls[0][0];
                // UUID v4 format
                expect(putArg.id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);
                expect(putArg.id).not.toBe('attacker-forged-id');
                expect(putArg.tenantId).toBe('tenant-A');
                expect(putArg.PK).toBe('TENANT#tenant-A');
            } else {
                // Acceptable outcome: cross-tenant body injection blocked by wrapper.
                expect([401, 403]).toContain(result.statusCode);
            }
        });
    });
});
