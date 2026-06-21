// @ts-nocheck
/// <reference types="jest" />
// ============================================================================
// Part 4 — Customer Mobile App Integration Tests
// ============================================================================
// Covers:
//   • CUSTOMER role gating — business roles (OWNER/STAFF) are NOT authorized
//     on the customer-app surface (dedicated Cognito group separation).
//   • Identity resolution — customerId derived from the JWT (auth.sub → phone
//     → linked customer), never from client input.
//   • Ownership isolation — getMyInvoices/getMyInvoicePdf return ONLY the
//     calling customer's records; another customer's invoice id → 404.
//   • Pre-signed URL issuance — only for owned PDFs, short TTL.
//
// Run with: npx jest src/__tests__/customer-app.test.ts
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';

// ---- Mock Auth: customer-app user (CUSTOMER role) --------------------------
const mockVerifyAuth = jest.fn();
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
const mockQueryItems = jest.fn();
const mockQueryAllItems = jest.fn();

jest.mock('../config/dynamodb.config', () => ({
    TABLE_NAME: 'test-table',
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
        customerSK: (id: string) => `CUSTOMER#${id}`,
        userSK: (id: string) => `USER#${id}`,
        invoiceSK: (id: string) => `INVOICE#${id}`,
        productSK: (id: string) => `PRODUCT#${id}`,
        invoiceLineItemPK: (id: string) => `INVOICE#${id}`,
        lineItemSK: (id: string) => `LINEITEM#${id}`,
    },
    getItem: (...args: any[]) => mockGetItem(...args),
    putItem: jest.fn(),
    queryItems: (...args: any[]) => mockQueryItems(...args),
    queryAllItems: (...args: any[]) => mockQueryAllItems(...args),
    updateItem: jest.fn(),
}));

// ---- Mock StorageService (S3 pre-signed URLs) ------------------------------
const mockGetDownloadUrl = jest.fn();
jest.mock('../services/storage.service', () => ({
    StorageService: jest.fn().mockImplementation(() => ({
        getDownloadUrl: (...args: any[]) => mockGetDownloadUrl(...args),
    })),
}));

jest.mock('../middleware/plan-guard', () => ({
    validateFeatureAccess: jest.fn().mockResolvedValue(undefined),
    enforceLimits: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../middleware/software-lock', () => ({
    checkSoftwareLock: jest.fn().mockResolvedValue({ allowed: true, lockLevel: 'none', userMessage: '', metadata: {} }),
    LockLevel: { NONE: 'none', SOFT: 'soft', HARD: 'hard' },
}));
jest.mock('../services/websocket.service', () => ({
    broadcastToStaff: jest.fn().mockResolvedValue(undefined),
    broadcastToBusiness: jest.fn().mockResolvedValue(undefined),
}));

import { getMyInvoices, getMyInvoicePdf } from '../handlers/customer-app';

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

const CUSTOMER_AUTH = {
    sub: 'cognito-cust-1',
    email: 'cust1@x.com',
    tenantId: 't-aaa',
    role: 'customer',
    businessType: 'grocery',
    planTier: 'enterprise',
};

describe('Part 4 — Customer Mobile App Integration', () => {
    beforeEach(() => {
        mockVerifyAuth.mockReset();
        mockGetItem.mockReset();
        mockQueryItems.mockReset();
        mockQueryAllItems.mockReset();
        mockGetDownloadUrl.mockReset();
    });

    // ── 1. Role gating: CUSTOMER only ─────────────────────────────────────
    describe('role gating (dedicated customer group)', () => {
        test('CUSTOMER role is authorized', async () => {
            mockVerifyAuth.mockResolvedValue(CUSTOMER_AUTH);
            // No linked customer → empty list, but must be 200 (authorized).
            mockGetItem.mockResolvedValue(null);
            const result = await getMyInvoices(makeEvent(), ctx);
            expect(result.statusCode).toBe(200);
        });

        test('business OWNER role is REJECTED on the customer-app surface', async () => {
            mockVerifyAuth.mockResolvedValue({ ...CUSTOMER_AUTH, role: 'owner' });
            const result = await getMyInvoices(makeEvent(), ctx);
            // authorizedHandler throws AuthError → wrapper maps to 403.
            expect(result.statusCode).toBe(403);
        });

        test('STAFF role is REJECTED on the customer-app surface', async () => {
            mockVerifyAuth.mockResolvedValue({ ...CUSTOMER_AUTH, role: 'staff' });
            const result = await getMyInvoicePdf(makeEvent({ pathParameters: { id: 'inv1' } }), ctx);
            expect(result.statusCode).toBe(403);
        });
    });

    // ── 2. Identity resolution from JWT ───────────────────────────────────
    describe('getMyInvoices — identity + scoping', () => {
        test('resolves customer by JWT sub → phone → linked customer, returns only own invoices', async () => {
            mockVerifyAuth.mockResolvedValue(CUSTOMER_AUTH);
            mockGetItem.mockResolvedValueOnce({ phone: '9000000001' }); // user record
            mockQueryItems.mockResolvedValueOnce({ // linked customer lookup
                items: [{ id: 'c-mine', phone: '9000000001', isDeleted: false }],
            });
            mockQueryAllItems.mockResolvedValueOnce([
                { id: 'inv-1', customerId: 'c-mine', invoiceNumber: 'INV1', status: 'paid', totalCents: 1000, paidCents: 1000, balanceCents: 0, createdAt: '2026-06-01T00:00:00.000Z' },
                { id: 'inv-2', customerId: 'c-mine', invoiceNumber: 'INV2', status: 'pending', totalCents: 2000, paidCents: 500, balanceCents: 1500, createdAt: '2026-06-02T00:00:00.000Z' },
            ]);

            const result = await getMyInvoices(makeEvent(), ctx);
            const body = parseBody(result).data;

            expect(result.statusCode).toBe(200);
            expect(body.items).toHaveLength(2);
            expect(body.summary.outstandingCents).toBe(1500);
            expect(body.summary.totalBilledCents).toBe(3000);
            // Critical: query was filtered to the resolved customerId only.
            expect(mockQueryAllItems.mock.calls[0][2].expressionAttributeValues[':cid']).toBe('c-mine');
        });

        test('no linked customer → empty result, never an error', async () => {
            mockVerifyAuth.mockResolvedValue(CUSTOMER_AUTH);
            mockGetItem.mockResolvedValueOnce({ phone: null });
            const result = await getMyInvoices(makeEvent(), ctx);
            expect(result.statusCode).toBe(200);
            expect(parseBody(result).data.items).toEqual([]);
        });
    });

    // ── 3. Ownership isolation on PDF download ────────────────────────────
    describe('getMyInvoicePdf — ownership gate', () => {
        test('returns a short-lived pre-signed URL for an OWNED invoice', async () => {
            mockVerifyAuth.mockResolvedValue(CUSTOMER_AUTH);
            mockGetItem
                .mockResolvedValueOnce({ phone: '9000000001' }) // user record (resolveLinkedCustomer)
                .mockResolvedValueOnce({                         // invoice (getMyInvoicePdf)
                    id: 'inv-1', customerId: 'c-mine', isDeleted: false,
                    pdfKey: 'tenants/t-aaa/invoices/inv-1.pdf',
                });
            mockQueryItems.mockResolvedValueOnce({ // linked customer lookup
                items: [{ id: 'c-mine', phone: '9000000001', isDeleted: false }],
            });
            mockGetDownloadUrl.mockResolvedValue('https://s3.example/signed-inv-1');

            const result = await getMyInvoicePdf(makeEvent({ pathParameters: { id: 'inv-1' } }), ctx);
            const body = parseBody(result).data;

            expect(result.statusCode).toBe(200);
            expect(body.url).toBe('https://s3.example/signed-inv-1');
            expect(body.expiresIn).toBe(300);
            expect(mockGetDownloadUrl).toHaveBeenCalledWith('tenants/t-aaa/invoices/inv-1.pdf');
        });

        test('another customer\'s invoice id → 404, NO url issued', async () => {
            mockVerifyAuth.mockResolvedValue(CUSTOMER_AUTH);
            mockGetItem.mockResolvedValueOnce({ phone: '9000000001' });
            mockQueryItems.mockResolvedValueOnce({
                items: [{ id: 'c-mine', phone: '9000000001', isDeleted: false }],
            });
            // The requested invoice belongs to a DIFFERENT customer.
            mockGetItem.mockResolvedValueOnce({
                id: 'inv-x', customerId: 'c-someone-else', isDeleted: false, pdfKey: 'secret.pdf',
            });

            const result = await getMyInvoicePdf(makeEvent({ pathParameters: { id: 'inv-x' } }), ctx);

            expect(result.statusCode).toBe(404);
            expect(mockGetDownloadUrl).not.toHaveBeenCalled();
        });

        test('owned invoice with no PDF yet → returns PDF_NOT_GENERATED, no URL', async () => {
            mockVerifyAuth.mockResolvedValue(CUSTOMER_AUTH);
            mockGetItem.mockResolvedValueOnce({ phone: '9000000001' });
            mockQueryItems.mockResolvedValueOnce({
                items: [{ id: 'c-mine', phone: '9000000001', isDeleted: false }],
            });
            mockGetItem.mockResolvedValueOnce({
                id: 'inv-1', customerId: 'c-mine', isDeleted: false, // no pdfKey
            });

            const result = await getMyInvoicePdf(makeEvent({ pathParameters: { id: 'inv-1' } }), ctx);
            const body = parseBody(result).data;

            expect(result.statusCode).toBe(200);
            expect(body.url).toBeNull();
            expect(body.reason).toBe('PDF_NOT_GENERATED');
            expect(mockGetDownloadUrl).not.toHaveBeenCalled();
        });

        test('400 when invoice id missing', async () => {
            mockVerifyAuth.mockResolvedValue(CUSTOMER_AUTH);
            const result = await getMyInvoicePdf(makeEvent({ pathParameters: {} }), ctx);
            expect(result.statusCode).toBe(400);
        });
    });
});
