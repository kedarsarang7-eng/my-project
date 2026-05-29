// ============================================================================
// Pharmacy Refill Contract Tests
// ============================================================================
// Covers endpoint contracts:
//   GET  /pharmacy/prescriptions/refills/incomplete
//   POST /pharmacy/prescriptions/refills/backfill
//   POST /pharmacy/prescriptions/refills/backfill/bulk
//   POST /pharmacy/prescriptions/refills/{id}/status
// ============================================================================

const mockGetItem = jest.fn().mockResolvedValue(null);
const mockPutItem = jest.fn().mockResolvedValue(undefined);
const mockQueryItems = jest.fn().mockResolvedValue({ items: [], lastKey: undefined });
const mockQueryAllItems = jest.fn().mockResolvedValue([]);
const mockUpdateItem = jest.fn().mockResolvedValue({});
const mockBatchWrite = jest.fn().mockResolvedValue(undefined);
const mockBatchGetItems = jest.fn().mockResolvedValue([]);
const mockTransactWrite = jest.fn().mockResolvedValue(undefined);
const mockScanTable = jest.fn().mockResolvedValue([]);

jest.mock('../config/dynamodb.config', () => ({
    TABLE_NAME: 'test-table',
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
        productSK: (id: string) => `PRODUCT#${id}`,
    },
    getItem: (...args: any[]) => mockGetItem(...args),
    putItem: (...args: any[]) => mockPutItem(...args),
    queryItems: (...args: any[]) => mockQueryItems(...args),
    queryAllItems: (...args: any[]) => mockQueryAllItems(...args),
    updateItem: (...args: any[]) => mockUpdateItem(...args),
    batchWrite: (...args: any[]) => mockBatchWrite(...args),
    batchGetItems: (...args: any[]) => mockBatchGetItems(...args),
    transactWrite: (...args: any[]) => mockTransactWrite(...args),
    scanTable: (...args: any[]) => mockScanTable(...args),
    docClient: {},
    dynamoClient: {},
}));

jest.mock('@aws-sdk/client-cloudwatch', () => ({
    CloudWatchClient: jest.fn().mockImplementation(() => ({
        send: jest.fn().mockResolvedValue({}),
    })),
    PutMetricDataCommand: jest.fn(),
}));

jest.mock('../utils/context', () => ({
    getTenantId: () => 'test-tenant-id',
    getCorrelationId: () => 'test-corr-id',
    getUserId: () => 'test-user-id',
    runWithContext: (_ctx: any, fn: any) => fn(),
    contextStorage: { run: (_ctx: any, fn: any) => fn() },
}));
jest.mock('../services/websocket.service', () => ({
    broadcastToBusiness: jest.fn().mockResolvedValue(undefined),
    broadcastToStaff: jest.fn().mockResolvedValue(undefined),
    emitEvent: jest.fn().mockResolvedValue(undefined),
}));

const mockVerifyAuth = jest.fn();
jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: (...args: any[]) => mockVerifyAuth(...args),
}));
jest.mock('../middleware/plan-guard', () => ({
    validateFeatureAccess: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../middleware/cloudwatch-logger', () => ({
    logRequest: jest.fn().mockResolvedValue(undefined),
    logAuthFailure: jest.fn().mockResolvedValue(undefined),
}));

function setAuth(role: string) {
    mockVerifyAuth.mockResolvedValue({
        sub: 'user-001',
        email: 'owner@test.com',
        tenantId: 'test-tenant-id',
        role,
        businessType: 'pharmacy',
    });
}

function makeEvent(opts: {
    method: 'GET' | 'POST',
    path: string,
    body?: Record<string, any>,
    query?: Record<string, string>,
    pathParams?: Record<string, string>,
}) {
    const query = opts.query || {};
    return {
        version: '2.0',
        routeKey: `${opts.method} ${opts.path}`,
        rawPath: opts.path,
        rawQueryString: new URLSearchParams(query).toString(),
        pathParameters: opts.pathParams,
        queryStringParameters: query,
        headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer mock-token',
        },
        requestContext: {
            accountId: 'local',
            apiId: 'local',
            domainName: 'localhost',
            domainPrefix: '',
            http: {
                method: opts.method,
                path: opts.path,
                protocol: 'HTTP/1.1',
                sourceIp: '127.0.0.1',
                userAgent: 'jest',
            },
            requestId: 'test-req',
            routeKey: `${opts.method} ${opts.path}`,
            stage: '\$default',
            time: new Date().toISOString(),
            timeEpoch: Date.now(),
        },
        body: opts.body ? JSON.stringify(opts.body) : undefined,
        isBase64Encoded: false,
    };
}

import {
    listIncompleteRefills as _listIncompleteRefills,
    backfillRefillTrace as _backfillRefillTrace,
    bulkBackfillRefillTrace as _bulkBackfillRefillTrace,
    updateRefillStatus as _updateRefillStatus,
} from '../handlers/pharmacy';

describe('Refill API contracts', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        setAuth('owner');
    });

    test('GET incomplete returns contract with cursor metadata', async () => {
        mockQueryItems.mockResolvedValueOnce({
            items: [{
                id: 'r1',
                status: 'requested',
                prescriptionId: 'rx-1',
                patientName: 'P',
                drugName: 'D',
                requestedQty: 2,
                productId: null,
                prescribedQty: null,
                requestedAt: new Date().toISOString(),
            }],
            lastKey: { PK: 'TENANT#test-tenant-id', SK: 'RXREFILL#r1' },
        });

        const result: any = await _listIncompleteRefills(
            makeEvent({ method: 'GET', path: '/pharmacy/prescriptions/refills/incomplete', query: { pageSize: '1' } }) as any,
            {} as any,
        );
        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(200);
        expect(Array.isArray(body.data)).toBe(true);
        expect(body.data[0]).toMatchObject({
            id: 'r1',
            status: 'requested',
            prescriptionId: 'rx-1',
        });
        expect(body.meta.hasMore).toBe(true);
        expect(typeof body.meta.nextCursor).toBe('string');
    });

    test('POST backfill updates refill trace fields', async () => {
        mockGetItem.mockResolvedValueOnce({
            id: 'r2',
            productId: null,
            prescribedQty: null,
        });
        mockUpdateItem.mockResolvedValueOnce({
            id: 'r2',
            productId: 'prod-1',
            prescribedQty: 5,
        });

        const result: any = await _backfillRefillTrace(
            makeEvent({
                method: 'POST',
                path: '/pharmacy/prescriptions/refills/backfill',
                body: { refillId: 'r2', productId: 'prod-1', prescribedQty: 5 },
            }) as any,
            {} as any,
        );
        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(200);
        expect(body.data).toMatchObject({
            id: 'r2',
            productId: 'prod-1',
            prescribedQty: 5,
        });
        expect(mockUpdateItem).toHaveBeenCalled();
    });

    test('POST bulk backfill preview returns per-row status without writes', async () => {
        mockGetItem
            .mockResolvedValueOnce({ id: 'ok-1' })
            .mockResolvedValueOnce(null);

        const result: any = await _bulkBackfillRefillTrace(
            makeEvent({
                method: 'POST',
                path: '/pharmacy/prescriptions/refills/backfill/bulk',
                body: {
                    preview: true,
                    items: [
                        { refillId: 'ok-1', productId: 'prod-1', prescribedQty: 2 },
                        { refillId: 'missing-1', productId: 'prod-2', prescribedQty: 3 },
                    ],
                },
            }) as any,
            {} as any,
        );
        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(200);
        expect(body.data.preview).toBe(true);
        expect(body.data.successCount).toBe(1);
        expect(body.data.failedCount).toBe(1);
        expect(body.data.results[1]).toMatchObject({
            refillId: 'missing-1',
            ok: false,
            code: 'NOT_FOUND',
        });
        expect(mockUpdateItem).not.toHaveBeenCalled();
    });

    test('POST bulk backfill apply returns VALIDATION_ERROR for bad row', async () => {
        const result: any = await _bulkBackfillRefillTrace(
            makeEvent({
                method: 'POST',
                path: '/pharmacy/prescriptions/refills/backfill/bulk',
                body: {
                    preview: false,
                    items: [
                        { refillId: 'bad-1', productId: '   ', prescribedQty: 2 },
                    ],
                },
            }) as any,
            {} as any,
        );
        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(200);
        expect(body.data.preview).toBe(false);
        expect(body.data.failedCount).toBe(1);
        expect(body.data.results[0]).toMatchObject({
            refillId: 'bad-1',
            ok: false,
            code: 'VALIDATION_ERROR',
        });
        expect(mockUpdateItem).not.toHaveBeenCalled();
    });

    test('POST bulk backfill apply returns UPDATE_FAILED when write throws', async () => {
        mockGetItem.mockResolvedValueOnce({ id: 'ok-2' });
        mockUpdateItem.mockRejectedValueOnce(new Error('ConditionalCheckFailed'));

        const result: any = await _bulkBackfillRefillTrace(
            makeEvent({
                method: 'POST',
                path: '/pharmacy/prescriptions/refills/backfill/bulk',
                body: {
                    preview: false,
                    items: [
                        { refillId: 'ok-2', productId: 'prod-1', prescribedQty: 2 },
                    ],
                },
            }) as any,
            {} as any,
        );
        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(200);
        expect(body.data.preview).toBe(false);
        expect(body.data.failedCount).toBe(1);
        expect(body.data.results[0]).toMatchObject({
            refillId: 'ok-2',
            ok: false,
            code: 'UPDATE_FAILED',
        });
        expect(String(body.data.results[0].error)).toContain('ConditionalCheckFailed');
    });

    test('POST refill status rejects dispense qty greater than prescribed', async () => {
        mockGetItem.mockResolvedValueOnce({
            id: 'r3',
            status: 'approved',
            requestedQty: 2,
            prescribedQty: 2,
            invoiceId: null,
            productId: 'prod-1',
        });

        const result: any = await _updateRefillStatus(
            makeEvent({
                method: 'POST',
                path: '/pharmacy/prescriptions/refills/{id}/status',
                pathParams: { id: 'r3' },
                body: { status: 'dispensed', invoiceId: 'inv-1', dispensedQty: 3 },
            }) as any,
            {} as any,
        );
        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(400);
        expect(body.error.code).toBe('DISPENSE_QTY_EXCEEDS_PRESCRIBED');
        expect(mockUpdateItem).not.toHaveBeenCalled();
    });

    test('POST refill status rejects dispense when prescribed qty missing', async () => {
        mockGetItem.mockResolvedValueOnce({
            id: 'r4',
            status: 'approved',
            requestedQty: 0,
            prescribedQty: null,
            invoiceId: null,
            productId: 'prod-1',
        });

        const result: any = await _updateRefillStatus(
            makeEvent({
                method: 'POST',
                path: '/pharmacy/prescriptions/refills/{id}/status',
                pathParams: { id: 'r4' },
                body: { status: 'dispensed', invoiceId: 'inv-2', dispensedQty: 1 },
            }) as any,
            {} as any,
        );
        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(400);
        expect(body.error.code).toBe('PRESCRIBED_QTY_REQUIRED');
        expect(mockUpdateItem).not.toHaveBeenCalled();
    });

    test('POST refill status rejects partial dispense when productId missing', async () => {
        mockGetItem.mockResolvedValueOnce({
            id: 'r5',
            status: 'approved',
            requestedQty: 5,
            prescribedQty: 5,
            invoiceId: null,
            productId: '',
        });

        const result: any = await _updateRefillStatus(
            makeEvent({
                method: 'POST',
                path: '/pharmacy/prescriptions/refills/{id}/status',
                pathParams: { id: 'r5' },
                body: { status: 'dispensed', invoiceId: 'inv-3', dispensedQty: 3 },
            }) as any,
            {} as any,
        );
        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(400);
        expect(body.error.code).toBe('PRODUCT_ID_REQUIRED_FOR_PARTIAL');
        expect(mockUpdateItem).not.toHaveBeenCalled();
    });

    test('POST refill status rejects invalid transition requested -> dispensed', async () => {
        mockGetItem.mockResolvedValueOnce({
            id: 'r6',
            status: 'requested',
            requestedQty: 2,
            prescribedQty: 2,
            invoiceId: null,
            productId: 'prod-2',
        });

        const result: any = await _updateRefillStatus(
            makeEvent({
                method: 'POST',
                path: '/pharmacy/prescriptions/refills/{id}/status',
                pathParams: { id: 'r6' },
                body: { status: 'dispensed', invoiceId: 'inv-4', dispensedQty: 2 },
            }) as any,
            {} as any,
        );
        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(409);
        expect(body.error.code).toBe('INVALID_REFILL_TRANSITION');
        expect(mockUpdateItem).not.toHaveBeenCalled();
    });

    test('POST refill status allows requested -> approved', async () => {
        mockGetItem.mockResolvedValueOnce({
            id: 'r7',
            status: 'requested',
            requestedQty: 2,
            prescribedQty: 2,
            invoiceId: null,
            productId: 'prod-2',
            prescriptionId: 'rx-7',
            patientName: 'P7',
            drugName: 'D7',
        });
        mockUpdateItem.mockResolvedValueOnce({
            id: 'r7',
            status: 'approved',
            invoiceId: null,
        });

        const result: any = await _updateRefillStatus(
            makeEvent({
                method: 'POST',
                path: '/pharmacy/prescriptions/refills/{id}/status',
                pathParams: { id: 'r7' },
                body: { status: 'approved', reason: 'Checked by pharmacist' },
            }) as any,
            {} as any,
        );
        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(200);
        expect(body.data).toMatchObject({
            id: 'r7',
            previousStatus: 'requested',
            status: 'approved',
        });
        expect(mockUpdateItem).toHaveBeenCalled();
    });

    test('POST refill status allows approved -> dispensed with dispensedQty persisted', async () => {
        mockGetItem.mockResolvedValueOnce({
            id: 'r8',
            status: 'approved',
            requestedQty: 5,
            prescribedQty: 5,
            invoiceId: null,
            productId: 'prod-8',
            prescriptionId: 'rx-8',
            patientName: 'P8',
            drugName: 'D8',
        });
        mockUpdateItem.mockResolvedValueOnce({
            id: 'r8',
            status: 'dispensed',
            invoiceId: 'inv-8',
            dispensedQty: 4,
        });

        const result: any = await _updateRefillStatus(
            makeEvent({
                method: 'POST',
                path: '/pharmacy/prescriptions/refills/{id}/status',
                pathParams: { id: 'r8' },
                body: { status: 'dispensed', invoiceId: 'inv-8', dispensedQty: 4 },
            }) as any,
            {} as any,
        );
        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(200);
        expect(body.data).toMatchObject({
            id: 'r8',
            previousStatus: 'approved',
            status: 'dispensed',
            invoiceId: 'inv-8',
        });
        expect(mockUpdateItem).toHaveBeenCalledWith(
            'TENANT#test-tenant-id',
            'RXREFILL#r8',
            expect.objectContaining({
                expressionAttributeValues: expect.objectContaining({
                    ':dispensedQty': 4,
                    ':status': 'dispensed',
                }),
            }),
        );
    });
});

