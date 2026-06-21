// @ts-nocheck
/// <reference types="jest" />
// ============================================================================
// Handler Tests — GET /customers/{id}/profile (Part 2)
// ============================================================================
// Covers:
//   • Consolidated identity + balance response from cached BALANCE item
//   • Stale/missing cache → on-demand recompute
//   • 404 for missing/deleted customer
//   • Tenant scoping (PK built from auth.tenantId, never client input)
//   • Recompute failure → graceful fallback (no 500)
//
// Run with: npx jest src/__tests__/customer-profile.test.ts
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';

// ---- Mock Auth ----
const mockVerifyAuth = jest.fn().mockResolvedValue({
    sub: 'test-user-id',
    email: 'owner@shop.com',
    tenantId: 't-aaa',
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

// ---- Mock DynamoDB ----
const mockGetItem = jest.fn();
const mockPutItem = jest.fn().mockResolvedValue(undefined);
const mockQueryAllItems = jest.fn().mockResolvedValue([]);

jest.mock('../config/dynamodb.config', () => ({
    TABLE_NAME: 'test-table',
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
        customerSK: (id: string) => `CUSTOMER#${id}`,
        customerBalanceSK: (id: string) => `CUSTOMER#${id}#BALANCE`,
        invoiceSK: (id: string) => `INVOICE#${id}`,
        paymentSK: (id: string) => `PAYMENT#${id}`,
    },
    getItem: (...args: any[]) => mockGetItem(...args),
    putItem: (...args: any[]) => mockPutItem(...args),
    queryItems: jest.fn(),
    queryAllItems: (...args: any[]) => mockQueryAllItems(...args),
    updateItem: jest.fn(),
}));

jest.mock('../middleware/plan-guard', () => ({
    validateFeatureAccess: jest.fn().mockResolvedValue(undefined),
    enforceLimits: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../services/revision-history.service', () => ({ recordRevision: jest.fn().mockResolvedValue(undefined) }));

import { getCustomerProfile } from '../handlers/customers';

// ---- Helpers ----
function makeEvent(pathId: string): APIGatewayProxyEventV2 {
    return {
        version: '2.0',
        routeKey: '$default',
        rawPath: `/customers/${pathId}/profile`,
        rawQueryString: '',
        headers: { authorization: 'Bearer test-token' },
        requestContext: {
            accountId: '123', apiId: 'test', domainName: 'test', domainPrefix: 'test',
            http: { method: 'GET', path: '/', protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'test' },
            requestId: 'r', routeKey: '$default', stage: '$default',
            time: new Date().toISOString(), timeEpoch: Date.now(),
        },
        pathParameters: { id: pathId },
        isBase64Encoded: false,
    } as any;
}

const ctx: Context = {
    callbackWaitsForEmptyEventLoop: false, functionName: 't', functionVersion: '1',
    invokedFunctionArn: 'arn:aws:lambda:us-east-1:123:function:t', memoryLimitInMB: '128',
    awsRequestId: 'r', logGroupName: 'g', logStreamName: 's',
    getRemainingTimeInMillis: () => 30000, done: () => {}, fail: () => {}, succeed: () => {},
};

function parseBody(r: any) { return JSON.parse(r.body || '{}'); }

const CUSTOMER_ITEM = {
    PK: 'TENANT#t-aaa',
    SK: 'CUSTOMER#c1',
    entityType: 'CUSTOMER',
    id: 'c1',
    tenantId: 't-aaa',
    name: 'Acme Retail',
    phone: '9876543210',
    email: 'acme@x.com',
    gstin: 'GSTIN123',
    address: '1 Main St',
    city: 'Pune', state: 'MH', pincode: '411001',
    creditLimitCents: 500000,
    customerType: 'credit',
    isBlocked: false,
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-06-01T00:00:00.000Z',
    isDeleted: false,
};

describe('GET /customers/{id}/profile', () => {
    beforeEach(() => {
        mockGetItem.mockReset();
        mockPutItem.mockReset();
        mockQueryAllItems.mockReset();
        mockQueryAllItems.mockResolvedValue([]);
    });

    test('returns consolidated identity + balance from fresh cache', async () => {
        const fresh = new Date().toISOString();
        mockGetItem
            .mockResolvedValueOnce(CUSTOMER_ITEM)            // customer
            .mockResolvedValueOnce({                          // balance cache (fresh)
                outstandingCents: 120000,
                totalBilledCents: 500000,
                totalPaidCents: 380000,
                invoiceCount: 5,
                paymentCount: 3,
                lastInvoiceAt: '2026-06-01T00:00:00.000Z',
                lastPaymentAt: '2026-05-30T00:00:00.000Z',
                updatedAt: fresh,
            });

        const result = await getCustomerProfile(makeEvent('c1'), ctx);
        expect(result.statusCode).toBe(200);
        const body = parseBody(result).data;

        expect(body.id).toBe('c1');
        expect(body.name).toBe('Acme Retail');
        expect(body.gstin).toBe('GSTIN123');
        expect(body.creditLimitCents).toBe(500000);
        expect(body.balance.totalBilledCents).toBe(500000);
        expect(body.balance.totalPaidCents).toBe(380000);
        expect(body.balance.outstandingCents).toBe(120000);
        expect(body.balance.invoiceCount).toBe(5);
        expect(body.availableCreditCents).toBe(380000); // 500000 - 120000
        // Fresh cache → no recompute.
        expect(mockQueryAllItems).not.toHaveBeenCalled();
    });

    test('recomputes on read when BALANCE cache is missing', async () => {
        mockGetItem
            .mockResolvedValueOnce(CUSTOMER_ITEM) // customer
            .mockResolvedValueOnce(null);          // no balance cache
        mockQueryAllItems
            .mockResolvedValueOnce([{ totalCents: 100000, paidCents: 40000, balanceCents: 60000, createdAt: '2026-06-01T00:00:00.000Z' }])
            .mockResolvedValueOnce([{ amountCents: 40000, createdAt: '2026-06-01T00:00:00.000Z' }]);

        const result = await getCustomerProfile(makeEvent('c1'), ctx);
        expect(result.statusCode).toBe(200);
        const body = parseBody(result).data;

        expect(mockQueryAllItems).toHaveBeenCalledTimes(2); // invoices + payments
        expect(mockPutItem).toHaveBeenCalledTimes(1);        // wrote fresh cache
        expect(body.balance.totalBilledCents).toBe(100000);
        expect(body.balance.outstandingCents).toBe(60000);
    });

    test('recomputes on read when BALANCE cache is stale (>24h)', async () => {
        const stale = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();
        mockGetItem
            .mockResolvedValueOnce(CUSTOMER_ITEM)
            .mockResolvedValueOnce({ outstandingCents: 999, totalBilledCents: 999, totalPaidCents: 0, updatedAt: stale });
        mockQueryAllItems
            .mockResolvedValueOnce([{ totalCents: 50000, paidCents: 50000, balanceCents: 0, createdAt: '2026-06-01T00:00:00.000Z' }])
            .mockResolvedValueOnce([]);

        const result = await getCustomerProfile(makeEvent('c1'), ctx);
        const body = parseBody(result).data;

        expect(mockQueryAllItems).toHaveBeenCalled();
        expect(body.balance.totalBilledCents).toBe(50000);
        expect(body.balance.outstandingCents).toBe(0);
    });

    test('returns 404 when customer does not exist', async () => {
        mockGetItem.mockResolvedValueOnce(null);
        const result = await getCustomerProfile(makeEvent('ghost'), ctx);
        expect(result.statusCode).toBe(404);
    });

    test('returns 404 when customer is soft-deleted', async () => {
        mockGetItem.mockResolvedValueOnce({ ...CUSTOMER_ITEM, isDeleted: true });
        const result = await getCustomerProfile(makeEvent('c1'), ctx);
        expect(result.statusCode).toBe(404);
    });

    test('tenant scoping: getItem called with PK derived from auth.tenantId only', async () => {
        mockGetItem.mockResolvedValueOnce(CUSTOMER_ITEM).mockResolvedValueOnce(null);
        await getCustomerProfile(makeEvent('c1'), ctx);

        // First getItem is the customer read. PK must be the auth tenant, never
        // a tenant the client could inject via the path id.
        const customerCall = mockGetItem.mock.calls[0];
        expect(customerCall[0]).toBe('TENANT#t-aaa');
        expect(customerCall[1]).toBe('CUSTOMER#c1');
    });

    test('graceful fallback (no 500) when recompute throws', async () => {
        mockGetItem
            .mockResolvedValueOnce(CUSTOMER_ITEM)
            .mockResolvedValueOnce(null); // missing → triggers recompute
        mockQueryAllItems.mockRejectedValue(new Error('dynamo throttled'));

        const result = await getCustomerProfile(makeEvent('c1'), ctx);
        // Should NOT be a 500 — serve zeros from cache fallback.
        expect(result.statusCode).toBe(200);
        const body = parseBody(result).data;
        expect(body.balance.totalBilledCents).toBe(0);
        expect(body.balance.outstandingCents).toBe(0);
    });

    test('returns 400 when path id is missing', async () => {
        const result = await getCustomerProfile({ ...makeEvent('x'), pathParameters: {} } as any, ctx);
        expect(result.statusCode).toBe(400);
    });
});
