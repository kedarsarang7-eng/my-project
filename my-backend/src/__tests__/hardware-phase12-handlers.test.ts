/// <reference types="jest" />
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';

const mockGetItem = jest.fn();
const mockPutItem = jest.fn();
const mockQueryAllItems = jest.fn();
const mockQueryItems = jest.fn();
const mockUpdateItem = jest.fn();

jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: jest.fn().mockResolvedValue({
        sub: 'user-1',
        email: 'owner@test.com',
        tenantId: 'tenant-1',
        role: 'owner',
        businessType: 'hardware',
        planTier: 'enterprise',
    }),
    requireRole: jest.fn(),
    AuthError: class AuthError extends Error {
        statusCode: number;
        constructor(msg: string, code = 401) { super(msg); this.statusCode = code; }
    },
}));

jest.mock('../config/dynamodb.config', () => ({
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
        purchaseOrderSK: (id: string) => `PO#${id}`,
        grnSK: (id: string) => `GRN#${id}`,
        purchaseBillSK: (id: string) => `PBILL#${id}`,
        partySK: (id: string) => `PARTY#${id}`,
        partyLedgerSK: (id: string) => `PLEDGER#${id}`,
    },
    getItem: mockGetItem,
    putItem: mockPutItem,
    queryAllItems: mockQueryAllItems,
    queryItems: mockQueryItems,
    updateItem: mockUpdateItem,
}));

jest.mock('../utils/context', () => ({
    getTenantId: () => 'tenant-1',
    getCorrelationId: () => 'corr-1',
    getUserId: () => 'user-1',
    runWithContext: (_ctx: any, fn: any) => fn(),
    contextStorage: { run: (_ctx: any, fn: any) => fn() },
}));

const ctx: Context = {
    callbackWaitsForEmptyEventLoop: false,
    functionName: 'test',
    functionVersion: '1',
    invokedFunctionArn: 'arn:test',
    memoryLimitInMB: '128',
    awsRequestId: 'req-1',
    logGroupName: 'lg',
    logStreamName: 'ls',
    getRemainingTimeInMillis: () => 30000,
    done: () => { },
    fail: () => { },
    succeed: () => { },
};

function event(overrides: Partial<APIGatewayProxyEventV2> = {}): APIGatewayProxyEventV2 {
    return {
        version: '2.0',
        routeKey: '$default',
        rawPath: '/',
        rawQueryString: '',
        headers: { authorization: 'Bearer x' },
        requestContext: {
            accountId: '1',
            apiId: 'a',
            domainName: 'd',
            domainPrefix: 'p',
            http: { method: 'GET', path: '/', protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'jest' },
            requestId: 'rid',
            routeKey: '$default',
            stage: '$default',
            time: new Date().toISOString(),
            timeEpoch: Date.now(),
        },
        isBase64Encoded: false,
        ...overrides,
    } as APIGatewayProxyEventV2;
}

function parseBody(res: any) {
    return JSON.parse(res.body || '{}');
}

describe('hardware phase12 handlers', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
        mockQueryAllItems.mockResolvedValue([]);
        mockUpdateItem.mockResolvedValue({ status: 'sent' });
    });

    test('create purchase order returns 201', async () => {
        const h = await import('../handlers/hardware-phase12');
        const res: any = await h.createPurchaseOrder(event({
            body: JSON.stringify({
                supplierId: '11111111-1111-4111-8111-111111111111',
                items: [{
                    productId: '22222222-2222-4222-8222-222222222222',
                    name: 'GI Pipe 1in',
                    quantity: 10,
                    unit: 'pcs',
                    rateCents: 12000,
                }],
            }),
        }), ctx);
        expect(res.statusCode).toBe(201);
        const body = parseBody(res);
        expect(body.success).toBe(true);
        expect(mockPutItem).toHaveBeenCalled();
    });

    test('update purchase order status returns 200', async () => {
        const h = await import('../handlers/hardware-phase12');
        const res: any = await h.updatePurchaseOrderStatus(event({
            pathParameters: { id: 'po-1' },
            body: JSON.stringify({ status: 'sent' }),
        }), ctx);
        expect(res.statusCode).toBe(200);
        expect(mockUpdateItem).toHaveBeenCalled();
    });

    test('post party ledger returns 201', async () => {
        mockGetItem.mockResolvedValue({ id: 'party-1', runningBalanceCents: 50000, isDeleted: false });
        const h = await import('../handlers/hardware-phase12');
        const res: any = await h.postPartyLedger(event({
            pathParameters: { id: 'party-1' },
            body: JSON.stringify({
                transactionType: 'payment',
                debitCents: 0,
                creditCents: 10000,
                narration: 'Part payment',
            }),
        }), ctx);
        expect(res.statusCode).toBe(201);
        expect(mockPutItem).toHaveBeenCalled();
        expect(mockUpdateItem).toHaveBeenCalled();
    });
});
