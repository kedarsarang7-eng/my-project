// ============================================================================
// Integration Tests — All Lambda Handlers
// ============================================================================
// Tests verify handler input validation, response shape, and error handling.
// Run with: npx jest src/__tests__/handlers.test.ts
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';

// ---- Test Helpers ----

function makeEvent(overrides: Partial<APIGatewayProxyEventV2> = {}): APIGatewayProxyEventV2 {
    return {
        version: '2.0',
        routeKey: '$default',
        rawPath: '/',
        rawQueryString: '',
        headers: {
            authorization: 'Bearer test-token',
        },
        requestContext: {
            accountId: '123',
            apiId: 'test',
            domainName: 'test.execute-api.us-east-1.amazonaws.com',
            domainPrefix: 'test',
            http: { method: 'GET', path: '/', protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'test' },
            requestId: 'test-req-id',
            routeKey: '$default',
            stage: '$default',
            time: new Date().toISOString(),
            timeEpoch: Date.now(),
        },
        isBase64Encoded: false,
        ...overrides,
    } as APIGatewayProxyEventV2;
}

const mockContext: Context = {
    callbackWaitsForEmptyEventLoop: false,
    functionName: 'test',
    functionVersion: '1',
    invokedFunctionArn: 'arn:aws:lambda:us-east-1:123:function:test',
    memoryLimitInMB: '128',
    awsRequestId: 'test-req',
    logGroupName: '/aws/lambda/test',
    logStreamName: 'test-stream',
    getRemainingTimeInMillis: () => 30000,
    done: () => {},
    fail: () => {},
    succeed: () => {},
};

function parseBody(result: any): any {
    return JSON.parse(result.body || '{}');
}

// ---- Mock Auth ----
// We mock the auth middleware to bypass JWT verification in tests.
jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: jest.fn().mockResolvedValue({
        sub: 'test-user-id',
        email: 'test@example.com',
        tenantId: 'test-tenant-id',
        role: 'owner',
        businessType: 'grocery',
    }),
    requireRole: jest.fn(),
    AuthError: class AuthError extends Error {
        statusCode: number;
        constructor(msg: string, code = 401) { super(msg); this.statusCode = code; this.name = 'AuthError'; }
    },
}));

// Mock DB to avoid real connections
jest.mock('../config/db.config', () => {
    const mockQuery = jest.fn().mockResolvedValue({ rows: [], rowCount: 0 });
    return {
        getPool: () => ({ query: mockQuery, connect: jest.fn() }),
        executeWithTenant: jest.fn((_id: string, fn: any) => fn({ query: mockQuery })),
        withTransaction: jest.fn((_id: string, fn: any) => fn({ query: mockQuery })),
    };
});

// Mock context
jest.mock('../utils/context', () => ({
    getTenantId: () => 'test-tenant-id',
    runWithContext: (_ctx: any, fn: any) => fn(),
    contextStorage: { run: (_ctx: any, fn: any) => fn() },
}));

// ============================================================================
// LINKING HANDLER TESTS
// ============================================================================
describe('Linking Handler', () => {
    let linking: any;

    beforeAll(() => {
        linking = require('../handlers/linking');
    });

    test('POST /linking/generate-token — returns 201 with token', async () => {
        const { getPool } = require('../config/db.config');
        getPool().query.mockResolvedValueOnce({ rows: [], rowCount: 1 }); // INSERT into linking_tokens

        const event = makeEvent({ body: JSON.stringify({ maxUses: 5, expiryHours: 48 }) });
        const result = await linking.generateToken(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(201);
        expect(body.success).toBe(true);
        expect(body.data.token).toBeDefined();
        expect(body.data.expiresAt).toBeDefined();
    });

    test('POST /linking/link — returns 400 when token missing', async () => {
        const event = makeEvent({ body: JSON.stringify({}) });
        const result = await linking.link(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(400);
        expect(body.success).toBe(false);
    });

    test('GET /linking/my-vendors — returns empty array', async () => {
        const { getPool } = require('../config/db.config');
        getPool().query.mockResolvedValueOnce({ rows: [] });

        const result = await linking.myVendors(makeEvent(), mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(Array.isArray(body.data)).toBe(true);
    });
});

// ============================================================================
// INVOICES HANDLER TESTS
// ============================================================================
describe('Invoices Handler', () => {
    let invoices: any;

    beforeAll(() => {
        invoices = require('../handlers/invoices');
    });

    test('POST /invoices — returns 400 when items missing', async () => {
        const event = makeEvent({ body: JSON.stringify({}) });
        const result = await invoices.createInvoice(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(400);
        expect(body.success).toBe(false);
    });

    test('POST /invoices/{id}/finalize — returns 400 when id missing', async () => {
        const event = makeEvent({ pathParameters: {} } as any);
        const result = await invoices.finalizeInvoice(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(400);
    });

    test('POST /invoices/{id}/void — returns 400 when id missing', async () => {
        const event = makeEvent({ pathParameters: {} } as any);
        const result = await invoices.voidInvoice(event, mockContext);
        expect(parseBody(result).success).toBe(false);
    });
});

// ============================================================================
// STOCK HANDLER TESTS
// ============================================================================
describe('Stock Handler', () => {
    let stock: any;

    beforeAll(() => {
        stock = require('../handlers/stock');
    });

    test('POST /stock/lookup-barcode — returns 400 when barcode missing', async () => {
        const event = makeEvent({ body: JSON.stringify({}) });
        const result = await stock.lookupBarcode(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(400);
        expect(body.success).toBe(false);
    });

    test('POST /stock/add — returns 400 when item_data missing', async () => {
        const event = makeEvent({ body: JSON.stringify({}) });
        const result = await stock.addStock(event, mockContext);
        expect(parseBody(result).success).toBe(false);
    });
});

// ============================================================================
// PAYMENTS HANDLER TESTS
// ============================================================================
describe('Payments Handler', () => {
    let payments: any;

    beforeAll(() => {
        payments = require('../handlers/payments');
    });

    test('GET /payments — returns paginated list', async () => {
        const { getPool } = require('../config/db.config');
        getPool().query
            .mockResolvedValueOnce({ rows: [{ total: 0 }] })   // COUNT
            .mockResolvedValueOnce({ rows: [] });               // SELECT

        const result = await payments.listPayments(makeEvent(), mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
    });

    test('POST /payments — returns 400 when required fields missing', async () => {
        const event = makeEvent({ body: JSON.stringify({}) });
        const result = await payments.recordPayment(event, mockContext);
        expect(parseBody(result).success).toBe(false);
    });
});

// ============================================================================
// CUSTOMERS HANDLER TESTS
// ============================================================================
describe('Customers Handler', () => {
    let customers: any;

    beforeAll(() => {
        customers = require('../handlers/customers');
    });

    test('GET /customers — returns paginated list', async () => {
        const { getPool } = require('../config/db.config');
        getPool().query
            .mockResolvedValueOnce({ rows: [{ total: 0 }] })
            .mockResolvedValueOnce({ rows: [] });

        const result = await customers.listCustomers(makeEvent(), mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
    });

    test('GET /customers/{id}/ledger — returns 400 when id missing', async () => {
        const event = makeEvent({ pathParameters: {} } as any);
        const result = await customers.getCustomerLedger(event, mockContext);
        expect(parseBody(result).success).toBe(false);
    });
});

// ============================================================================
// REPORTS HANDLER TESTS
// ============================================================================
describe('Reports Handler', () => {
    let reports: any;

    beforeAll(() => {
        reports = require('../handlers/reports');
    });

    test('GET /reports/sales — returns report structure', async () => {
        const { getPool } = require('../config/db.config');
        getPool().query
            .mockResolvedValueOnce({ rows: [] })           // timeseries
            .mockResolvedValueOnce({ rows: [{}] })          // summary
            .mockResolvedValueOnce({ rows: [] })            // top products
            .mockResolvedValueOnce({ rows: [] });           // payment modes

        const result = await reports.salesReport(makeEvent(), mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.data.summary).toBeDefined();
        expect(body.data.timeseries).toBeDefined();
    });

    test('GET /reports/gstr1 — returns B2B/B2C/HSN structure', async () => {
        const { getPool } = require('../config/db.config');
        getPool().query
            .mockResolvedValueOnce({ rows: [] })            // b2b
            .mockResolvedValueOnce({ rows: [{}] })          // b2c
            .mockResolvedValueOnce({ rows: [] });           // hsn

        const result = await reports.gstr1Report(makeEvent(), mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.data.b2b).toBeDefined();
        expect(body.data.b2c_summary).toBeDefined();
        expect(body.data.hsn_summary).toBeDefined();
    });
});

// ============================================================================
// ADMIN HANDLER TESTS
// ============================================================================
describe('Admin Handler', () => {
    let admin: any;

    beforeAll(() => {
        admin = require('../handlers/admin');
    });

    test('POST /admin/kill-switch — returns 400 on invalid action', async () => {
        const event = makeEvent({ body: JSON.stringify({ action: 'invalid' }) });
        const result = await admin.killSwitch(event, mockContext);
        expect(parseBody(result).success).toBe(false);
    });

    test('GET /admin/status — returns system status', async () => {
        const { getPool } = require('../config/db.config');
        getPool().query
            .mockResolvedValueOnce({ rows: [{ id: 'test', name: 'Test', business_type: 'grocery', subscription_plan: 'free', is_active: true, created_at: new Date(), user_count: 1, product_count: 5, transaction_count: 10 }] })
            .mockResolvedValueOnce({ rows: [{ bills_today: 0, revenue_today_cents: 0 }] })
            .mockResolvedValueOnce({ rows: [{ transactions_size: '8 kB', inventory_size: '16 kB' }] });

        const result = await admin.systemStatus(makeEvent(), mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.data.system.status).toBe('healthy');
        expect(body.data.tenant).toBeDefined();
        expect(body.data.counts).toBeDefined();
    });
});

// ============================================================================
// SYNC HANDLER TESTS
// ============================================================================
describe('Sync Handler', () => {
    let sync: any;

    beforeAll(() => {
        sync = require('../handlers/sync');
    });

    test('POST /sync/push — returns 400 when changes missing', async () => {
        const event = makeEvent({ body: JSON.stringify({}) });
        const result = await sync.pushChanges(event, mockContext);
        expect(parseBody(result).success).toBe(false);
    });

    test('POST /sync/pull — returns 400 when lastSyncedAt missing', async () => {
        const event = makeEvent({ body: JSON.stringify({}) });
        const result = await sync.pullChanges(event, mockContext);
        expect(parseBody(result).success).toBe(false);
    });
});

// ============================================================================
// INSIGHTS HANDLER TESTS
// ============================================================================
describe('Insights Handler', () => {
    let insights: any;

    beforeAll(() => {
        insights = require('../handlers/insights');
    });

    test('POST /insights/ai-insight — returns insight text', async () => {
        const { getPool } = require('../config/db.config');
        getPool().query
            .mockResolvedValueOnce({ rows: [{ bill_count: 5, total_cents: 50000, avg_bill_cents: 10000 }] })
            .mockResolvedValueOnce({ rows: [{ low_count: 2 }] })
            .mockResolvedValueOnce({ rows: [{ total_cents: 40000 }] });

        const result = await insights.aiInsight(makeEvent(), mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.data.ai_insight).toBeDefined();
        expect(typeof body.data.ai_insight).toBe('string');
    });
});
