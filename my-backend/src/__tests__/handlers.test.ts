// @ts-nocheck
/// <reference types="jest" />
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
    done: () => { },
    fail: () => { },
    succeed: () => { },
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
        planTier: 'enterprise', // Needed for plan-guard
    }),
    requireRole: jest.fn(),
    AuthError: class AuthError extends Error {
        statusCode: number;
        constructor(msg: string, code = 401) { super(msg); this.statusCode = code; this.name = 'AuthError'; }
    },
}));

// License endpoints call requireSuperAdmin inside handler — bypass in tests.
jest.mock('../middleware/plan-guard', () => ({ validateFeatureAccess: jest.fn().mockResolvedValue(undefined), enforceLimits: jest.fn().mockResolvedValue(undefined) }));
jest.mock('../middleware/super-admin-guard', () => ({
    requireSuperAdmin: jest.fn(),
}));

// Mock DynamoDB to avoid real connections
const mockGetItem = jest.fn().mockResolvedValue(null);
const mockPutItem = jest.fn().mockResolvedValue(undefined);
const mockQueryItems = jest.fn().mockResolvedValue({ items: [], lastKey: undefined });
const mockQueryAllItems = jest.fn().mockResolvedValue([]);
const mockUpdateItem = jest.fn().mockResolvedValue({});
const mockBatchWrite = jest.fn().mockResolvedValue(undefined);
const mockBatchGetItems = jest.fn().mockResolvedValue([]);
const mockTransactWrite = jest.fn().mockResolvedValue(undefined);
const mockScanTable = jest.fn().mockResolvedValue([]);
const mockRecordRevision = jest.fn().mockResolvedValue(undefined);

jest.mock('../config/dynamodb.config', () => ({
    TABLE_NAME: 'test-table',
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
        tenantProfileSK: () => 'PROFILE',
        tenantSettingsSK: () => 'SETTINGS',
        tenantLicenseSK: () => 'LICENSE',
        productSK: (id: string) => `PRODUCT#${id}`,
        invoiceSK: (id: string) => `INVOICE#${id}`,
        invoiceLineItemPK: (id: string) => `INVOICE#${id}`,
        lineItemSK: (id: string) => `LINEITEM#${id}`,
        customerSK: (id: string) => `CUSTOMER#${id}`,
        barcodeGSI3PK: (id: string) => `TENANT#${id}`,
        barcodeGSI3SK: (b: string) => `BARCODE#${b}`,
        skuGSI1SK: (s: string) => `SKU#${s}`,
        idempotencyPK: (k: string) => `IDEMPOTENCY#${k}`,
        idempotencyMetaSK: () => 'META',
        entityGSI1PK: (e: string) => `ENTITY#${e}`,
        licensePK: (k: string) => `LICENSE#${k}`,
        licenseMetaSK: () => 'META',
        userSK: (id: string) => `USER#${id}`,
        emailGSI1PK: (e: string) => `EMAIL#${e}`,
        cognitoSubGSI2PK: (s: string) => `COGNITOSUB#${s}`,
        staffSK: (id: string) => `STAFF#${id}`,
        businessSK: (id: string) => `BUSINESS#${id}`,
        paymentSK: (id: string) => `PAYMENT#${id}`,
        phoneGSI1SK: (p: string) => `PHONE#${p}`,
        invoiceNumGSI1SK: (n: string) => `INVNUM#${n}`,
        transactionSK: (id: string) => `TXN#${id}`,
        syncDeviceSK: (id: string) => `SYNC#DEVICE#${id}`,
        expenseSK: (id: string) => `EXPENSE#${id}`,
        vendorSK: (id: string) => `VENDOR#${id}`,
        licenseActivationSK: (t: string) => `ACTIVATION#${t}`,
        licenseEntityGSI1PK: () => 'ENTITY#LICENSE',
        
        recoveryVisitSK: (id: string) => `RECOVERYVISIT#${id}`,
    },
    getItem: mockGetItem,
    putItem: mockPutItem,
    queryItems: mockQueryItems,
    queryAllItems: mockQueryAllItems,
    updateItem: mockUpdateItem,
    batchWrite: mockBatchWrite,
    batchGetItems: mockBatchGetItems,
    transactWrite: mockTransactWrite,
    scanTable: mockScanTable,
    docClient: {},
    dynamoClient: {},
}));

// Mock context
jest.mock('../utils/context', () => ({
    getTenantId: () => 'test-tenant-id',
    getCorrelationId: () => 'test-corr-id',
    getUserId: () => 'test-user-id',
    runWithContext: (_ctx: any, fn: any) => fn(),
    contextStorage: { run: (_ctx: any, fn: any) => fn() },
}));


// Mock AWS CloudWatch SDK to prevent async metrics emission after tests complete
jest.mock('@aws-sdk/client-cloudwatch', () => ({
    CloudWatchClient: jest.fn().mockImplementation(() => ({
        send: jest.fn().mockResolvedValue({}),
    })),
    PutMetricDataCommand: jest.fn(),
}));

// Mock WebSocket service to prevent real DynamoDB/API Gateway calls
jest.mock('../services/websocket.service', () => ({
    broadcastToBusiness: jest.fn().mockResolvedValue(undefined),
    broadcastToStaff: jest.fn().mockResolvedValue(undefined),
    broadcastToCustomer: jest.fn().mockResolvedValue(undefined),
    broadcastToClientType: jest.fn().mockResolvedValue(undefined),
    broadcastToDevice: jest.fn().mockResolvedValue(undefined),
    broadcastToAll: jest.fn().mockResolvedValue(undefined),
    broadcastToOwner: jest.fn().mockResolvedValue(undefined),
    emitEvent: jest.fn().mockResolvedValue(undefined),
    saveConnection: jest.fn().mockResolvedValue(undefined),
    removeConnection: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../services/revision-history.service', () => ({
    recordRevision: mockRecordRevision,
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
        const result = await linking.myVendors(makeEvent(), mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(Array.isArray(body.data)).toBe(true);
    });
});

// ============================================================================
// PHARMACY REVISION HOOK TESTS
// ============================================================================
describe('Pharmacy revision hooks', () => {
    let pharmacy: any;

    beforeAll(() => {
        pharmacy = require('../handlers/pharmacy');
    });

    beforeEach(() => {
        jest.clearAllMocks();
        const { verifyAuth } = require('../middleware/cognito-auth');
        verifyAuth.mockResolvedValue({
            sub: 'test-user-id',
            email: 'test@example.com',
            tenantId: 'test-tenant-id',
            role: 'owner',
            businessType: 'pharmacy',
            planTier: 'enterprise',
        });
    });

    test('POST /pharmacy/prescriptions/refills writes revision create hook', async () => {
        const event = makeEvent({
            body: JSON.stringify({
                prescriptionId: 'rx-1',
                productId: 'prod-1',
                patientName: 'Alice',
                patientPhone: '9876543210',
                drugName: 'Drug A',
                requestedQty: 2,
                prescribedQty: 2,
            }),
        });

        const result = await pharmacy.createRefillRequest(event, mockContext);
        expect(result.statusCode).toBe(201);
        expect(mockRecordRevision).toHaveBeenCalledWith(
            'test-tenant-id',
            'pharmacy_refills',
            expect.any(String),
            'create',
            'test-user-id',
            null,
            expect.objectContaining({
                status: 'requested',
                prescriptionId: 'rx-1',
            }),
            expect.objectContaining({ source: 'pharmacy.createRefillRequest' }),
        );
    });

    test('POST /pharmacy/prescriptions/refills/{id}/status writes status_change revision', async () => { console.log('Setting mockResolvedValueOnce');
        mockGetItem.mockResolvedValue({
            id: 'ref-1',
            status: 'requested',
            prescriptionId: 'rx-1',
            requestedQty: 2,
            prescribedQty: 2,
            invoiceId: null,
        });
        mockUpdateItem.mockResolvedValueOnce({
            id: 'ref-1',
            status: 'approved',
            invoiceId: null,
            dispensedQty: null,
        });

        const event = makeEvent({
            pathParameters: { id: 'ref-1' },
            body: JSON.stringify({ status: 'approved', reason: 'ok' }),
        } as any);
        const result = await pharmacy.updateRefillStatus(event, mockContext);
        expect(result.statusCode).toBe(200);
        expect(mockRecordRevision).toHaveBeenCalledWith(
            'test-tenant-id',
            'pharmacy_refills',
            'ref-1',
            'status_change',
            'test-user-id',
            expect.objectContaining({ status: 'requested' }),
            expect.objectContaining({ status: 'approved' }),
            expect.objectContaining({ source: 'pharmacy.updateRefillStatus' }),
        );
    });

    test('POST /pharmacy/prescriptions/refills/backfill/bulk writes bulk revision summary', async () => {
        mockGetItem.mockResolvedValue({
            id: 'ref-1',
            status: 'requested',
        });

        const event = makeEvent({
            body: JSON.stringify({
                preview: true,
                items: [{ refillId: 'ref-1', productId: 'prod-1', prescribedQty: 1 }],
            }),
        });
        const result = await pharmacy.bulkBackfillRefillTrace(event, mockContext);
        expect(result.statusCode).toBe(200);
        expect(mockRecordRevision).toHaveBeenCalledWith(
            'test-tenant-id',
            'pharmacy_refill_bulk',
            expect.stringMatching(/^bulk-/),
            'update',
            'test-user-id',
            null,
            expect.objectContaining({
                preview: true,
                total: 1,
                successCount: 1,
            }),
            expect.objectContaining({ source: 'pharmacy.bulkBackfillRefillTrace' }),
        );
    });

    test('POST /pharmacy/batch-intake writes batch revision summary', async () => {
        mockGetItem.mockResolvedValue({
            id: '11111111-1111-4111-8111-111111111111',
            name: 'Diesel Additive',
            currentStock: 10,
            isDeleted: false,
        });
        mockQueryItems.mockResolvedValueOnce({ items: [], lastKey: undefined });

        const event = makeEvent({
            body: JSON.stringify({
                productId: '11111111-1111-4111-8111-111111111111',
                batches: [
                    {
                        batchNumber: 'B-001',
                        expiryDate: '2099-12-31',
                        quantityReceived: 5,
                        costPricePaise: 1200,
                    },
                ],
                purchaseDate: '2026-04-01',
            }),
        });

        const result = await pharmacy.batchIntake(event, mockContext);
        expect(result.statusCode).toBe(201);
        expect(mockRecordRevision).toHaveBeenCalledWith(
            'test-tenant-id',
            'pharmacy_batches',
            '11111111-1111-4111-8111-111111111111',
            'update',
            'test-user-id',
            expect.objectContaining({ currentStock: 10 }),
            expect.objectContaining({
                currentStock: 15,
                batchesCreated: 1,
                totalQtyReceived: 5,
            }),
            expect.objectContaining({ source: 'pharmacy.batchIntake' }),
        );
    });

    test('POST /pharmacy/narcotic-register writes narcotic revision hook', async () => {
        const event = makeEvent({
            body: JSON.stringify({
                patientName: 'Alice',
                patientAddress: 'Addr lane 1',
                prescribingDoctorName: 'Dr Who',
                doctorRegNo: 'MCI-12345',
                prescriptionId: 'rx-1',
                drugName: 'Drug X',
                quantitySold: 1,
                batchNumber: 'B-001',
                expiryDate: '2099-12-31',
                invoiceId: 'inv-1',
            }),
        });

        const result = await pharmacy.createNarcoticEntry(event, mockContext);
        expect(result.statusCode).toBe(201);
        expect(mockRecordRevision).toHaveBeenCalledWith(
            'test-tenant-id',
            'pharmacy_narcotic_log',
            expect.stringMatching(/^inv-1#/),
            'create',
            'test-user-id',
            null,
            expect.objectContaining({
                invoiceId: 'inv-1',
                prescriptionId: 'rx-1',
                drugName: 'Drug X',
            }),
            expect.objectContaining({ source: 'pharmacy.createNarcoticEntry' }),
        );
    });

    test('POST /pharmacy/prescriptions/partial-fills writes partial-fill revision hook', async () => {
        const event = makeEvent({
            body: JSON.stringify({
                prescriptionId: 'rx-1',
                invoiceId: 'inv-1',
                productId: 'prod-1',
                productName: 'Drug A',
                prescribedQty: 10,
                dispensedQty: 4,
                reason: 'stock short',
            }),
        });

        const result = await pharmacy.recordPartialFill(event, mockContext);
        expect(result.statusCode).toBe(201);
        expect(mockRecordRevision).toHaveBeenCalledWith(
            'test-tenant-id',
            'pharmacy_partial_fills',
            expect.any(String),
            'create',
            'test-user-id',
            null,
            expect.objectContaining({
                prescriptionId: 'rx-1',
                invoiceId: 'inv-1',
                completionStatus: 'partial',
                remainingQty: 6,
            }),
            expect.objectContaining({ source: 'pharmacy.recordPartialFill' }),
        );
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

    test('GET /customers/credit/reminder-candidates returns aged udhar rows', async () => {
        const cid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
        const oldDay = '2026-01-01T10:00:00.000Z';
        mockQueryAllItems.mockResolvedValueOnce([
            {
                id: 'inv-old',
                customerId: cid,
                paymentMode: 'udhar',
                balanceCents: 5000,
                status: 'partially_paid',
                createdAt: oldDay,
                saleDate: '2026-01-01',
                invoiceNumber: 'U-1',
                isDeleted: false,
            },
            {
                id: 'inv-new',
                customerId: cid,
                paymentMode: 'udhar',
                balanceCents: 100,
                status: 'partially_paid',
                createdAt: new Date(Date.now() - 5 * 86_400_000).toISOString(),
                isDeleted: false,
            },
        ]);
        mockGetItem.mockResolvedValue({
            id: cid,
            name: 'Udhar Party',
            phone: '+919999999999',
        });

        const event = makeEvent({
            rawQueryString: 'minAgeDays=15&minBalanceCents=100',
            queryStringParameters: { minAgeDays: '15', minBalanceCents: '100' },
        });
        const result = await customers.getCreditReminderCandidates(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.totals.partyCount).toBe(1);
        expect(body.data.items[0].outstandingCents).toBe(5000);
        expect(body.data.items[0].invoices.length).toBe(1);
        expect(body.data.items[0].invoices[0].id).toBe('inv-old');
    });
});

// ============================================================================
// CUSTOMER APP (MOBILE) TESTS
// ============================================================================
describe('Customer app handler', () => {
    let customerApp: any;

    beforeAll(() => {
        customerApp = require('../handlers/customer-app');
    });

    test('GET /customer/fuel-fills — returns volume rows for linked customer', async () => {
        mockGetItem.mockResolvedValue({ phone: '+919999999999' });
        mockQueryItems.mockResolvedValueOnce({
            items: [{ id: 'cust-1', phone: '+919999999999' }],
            lastKey: undefined,
        });
        mockQueryAllItems.mockResolvedValueOnce([
            {
                id: 'inv-1',
                type: 'sale',
                customerId: 'cust-1',
                invoiceNumber: 'INV-1',
                saleDate: '2026-04-21',
                fuelType: 'diesel',
                volumeLiters: 25.5,
                vehicleNumber: 'MH12AB1234',
                totalCents: 5000,
                paymentMode: 'cash',
                isDeleted: false,
            },
        ]);

        const result = await customerApp.getMyFillHistory(makeEvent(), mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.total).toBe(1);
        expect(body.data.items).toHaveLength(1);
        expect(body.data.items[0].volumeLiters).toBe(25.5);
        expect(body.data.items[0].fuelType).toBe('diesel');
    });
});

// ============================================================================
// FINANCIAL REPORTS (p12/p13)
// ============================================================================
describe('Financial reports handler', () => {
    let financial: any;

    beforeAll(() => {
        financial = require('../handlers/financial-reports');
    });

    beforeEach(() => {
        jest.clearAllMocks();
        const { verifyAuth } = require('../middleware/cognito-auth');
        verifyAuth.mockResolvedValue({
            sub: 'test-user-id',
            email: 'test@example.com',
            tenantId: 'test-tenant-id',
            role: 'owner',
            businessType: 'grocery',
            planTier: 'enterprise',
        });
    });

    test('GET /reports/balance-sheet aggregates assets', async () => {
        mockQueryAllItems
            .mockResolvedValueOnce([
                { id: 'i1', createdAt: '2026-04-01T10:00:00.000Z', balanceCents: 500, status: 'partially_paid', isDeleted: false },
            ])
            .mockResolvedValueOnce([
                { amountCents: 10_000, createdAt: '2026-04-02T12:00:00.000Z', isDeleted: false },
            ])
            .mockResolvedValueOnce([
                { id: 'p1', currentStock: 10, purchasePriceCents: 100, isDeleted: false },
            ]);

        const event = makeEvent({
            rawQueryString: 'asOf=2026-04-15',
            queryStringParameters: { asOf: '2026-04-15' },
        });
        const result = await financial.balanceSheetReport(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.assets.collectionsRegisteredCents).toBe(10_000);
        expect(body.data.assets.accountsReceivableCents).toBe(500);
        expect(body.data.assets.inventoryBookValueCents).toBe(1000);
    });

    test('GET /reports/cash-flow nets payments minus expenses', async () => {
        mockQueryAllItems
            .mockResolvedValueOnce([
                { amountCents: 5000, createdAt: '2026-04-10T10:00:00.000Z', paymentMode: 'cash', isDeleted: false },
            ])
            .mockResolvedValueOnce([
                { amountCents: 2000, expenseDate: '2026-04-11', category: 'fuel', isDeleted: false },
            ]);

        const event = makeEvent({
            rawQueryString: 'from=2026-04-01&to=2026-04-30',
            queryStringParameters: { from: '2026-04-01', to: '2026-04-30' },
        });
        const result = await financial.cashFlowReport(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.data.operating.inflowsCents).toBe(5000);
        expect(body.data.operating.outflowsCents).toBe(2000);
        expect(body.data.operating.netOperatingCashCents).toBe(3000);
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
        const result = await reports.salesReport(makeEvent(), mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.data.summary).toBeDefined();
        expect(body.data.timeseries).toBeDefined();
    });

    test('GET /reports/gstr1 — returns B2B/B2C/HSN structure', async () => {
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
        mockGetItem.mockResolvedValue({
            id: 'test-tenant-id',
            name: 'Test',
            businessType: 'grocery',
            subscriptionPlan: 'free',
            isActive: true,
            createdAt: new Date().toISOString(),
        });
        mockQueryItems
            .mockResolvedValueOnce({ items: [], lastKey: undefined })
            .mockResolvedValueOnce({ items: [], lastKey: undefined })
            .mockResolvedValueOnce({ items: [], lastKey: undefined });

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
        const result = await insights.aiInsight(makeEvent(), mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.data.ai_insight).toBeDefined();
        expect(typeof body.data.ai_insight).toBe('string');
    });

    test('POST /insights/ai-feedback — returns 200 on valid feedback', async () => {
        const event = makeEvent({
            body: JSON.stringify({
                predictionContext: 'Buy 100 rice',
                feedbackScore: 1
            })
        });
        const result = await insights.aiFeedback(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.message).toBe('Feedback recorded successfully');
    });
});

// ============================================================================
// LICENSE HANDLER TESTS
// ============================================================================
describe('License Handler', () => {
    let license: any;

    beforeAll(() => {
        license = require('../handlers/license');
    });

    test('POST /license/generate — returns 400 when plan missing', async () => {
        const { verifyAuth } = require('../middleware/cognito-auth');
        verifyAuth.mockResolvedValueOnce({ sub: 'test', email: 'test', tenantId: 'test-tenant-id', role: 'super_admin', businessType: 'grocery', planTier: 'enterprise' });
        const event = makeEvent({ body: JSON.stringify({}) });
        const result = await license.generate(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(400);
        expect(body.success).toBe(false);
        expect(body.error.code).toBe('MISSING_FIELDS');
    });

    test('POST /license/generate — returns 400 on invalid plan', async () => {
        const { verifyAuth } = require('../middleware/cognito-auth');
        verifyAuth.mockResolvedValueOnce({ sub: 'test', email: 'test', tenantId: 'test-tenant-id', role: 'super_admin', businessType: 'grocery', planTier: 'enterprise' });
        const event = makeEvent({ body: JSON.stringify({ plan: 'MEGA_ULTRA' }) });
        const result = await license.generate(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(400);
        expect(body.success).toBe(false);
        expect(body.error.code).toBe('INVALID_PLAN');
    });

    test('POST /license/generate — returns 201 with valid plan', async () => {
        const { verifyAuth } = require('../middleware/cognito-auth');
        verifyAuth.mockResolvedValueOnce({ sub: 'test', email: 'test', tenantId: 'test-tenant-id', role: 'super_admin', businessType: 'grocery', planTier: 'enterprise' });
        const event = makeEvent({
            body: JSON.stringify({ plan: 'premium', duration: '12 months' }),
        });
        const result = await license.generate(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(201);
        expect(body.success).toBe(true);
        expect(body.data.license_key).toBeDefined();
        // Prefix may be DKX or DKNX depending on generator version
        expect(body.data.license_key).toMatch(/^DK[A-Z0-9]X-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/);
        expect(body.data.tenant_id).toBeDefined();
        // Tenant id format may be TENANT-xxxxxxxx or compact TNX-xxxxxxxx
        expect(body.data.tenant_id).toMatch(/^(TENANT-[A-F0-9]{8}|T[A-Z]{2}-[A-F0-9]{8})$/);
        expect(body.data.plan).toBe('premium');
        expect(body.data.expiry_date).toBeDefined();
    });

    test('POST /license/activate — returns 400 when licenseKey missing', async () => {
        const event = makeEvent({ body: JSON.stringify({}) });
        const result = await license.activate(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(400);
        expect(body.success).toBe(false);
        expect(body.error.code).toBe('MISSING_LICENSE_KEY');
    });

    test('POST /license/manage — returns 400 on invalid action', async () => {
        const { verifyAuth } = require('../middleware/cognito-auth');
        verifyAuth.mockResolvedValueOnce({ sub: 'test', email: 'test', tenantId: 'test-tenant-id', role: 'super_admin', businessType: 'grocery', planTier: 'enterprise' });
        const event = makeEvent({
            body: JSON.stringify({ tenantId: 'test-tenant-id', action: 'delete' }),
        });
        const result = await license.manage(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(400);
        expect(body.success).toBe(false);
        expect(body.error.code).toBe('INVALID_ACTION');
    });

    afterAll(() => {
        const { verifyAuth } = require('../middleware/cognito-auth');
        verifyAuth.mockResolvedValue({
            sub: 'test-user-id',
            email: 'test@example.com',
            tenantId: 'test-tenant-id',
            role: 'owner',
            businessType: 'grocery',
            planTier: 'enterprise',
        });
    });
});

// ============================================================================
// E-INVOICE / E-WAY BILL HANDLER TESTS
// ============================================================================
describe('EInvoice Handler', () => {
    let einvoice: any;
    let einvoiceService: any;

    beforeAll(() => {
        einvoice = require('../handlers/einvoice');
        einvoiceService = require('../services/einvoice.service');
    });

    afterEach(() => {
        jest.restoreAllMocks();
    });

    test('POST /invoices/{id}/ewaybill — returns 400 when id missing', async () => {
        const event = makeEvent({
            pathParameters: {},
            body: JSON.stringify({
                fromPlace: 'Mumbai',
                toPlace: 'Pune',
                distanceKm: 120,
            }),
        } as any);

        const result = await einvoice.generateEWayBill(event, mockContext);
        expect(result.statusCode).toBe(400);
        expect(parseBody(result).success).toBe(false);
    });

    test('POST /invoices/{id}/ewaybill — returns 400 on invalid payload', async () => {
        const event = makeEvent({
            pathParameters: { id: 'inv-1' },
            body: JSON.stringify({
                fromPlace: '',
                toPlace: 'Pune',
                distanceKm: -1,
            }),
        } as any);

        const result = await einvoice.generateEWayBill(event, mockContext);
        expect(result.statusCode).toBe(400);
        expect(parseBody(result).success).toBe(false);
    });

    test('POST /invoices/{id}/ewaybill — maps service EWAY_BILL_ERROR', async () => {
        jest.spyOn(einvoiceService, 'generateEWayBill')
            .mockRejectedValueOnce(new einvoiceService.EInvoiceError('NIC fail', 502));

        const event = makeEvent({
            pathParameters: { id: 'inv-1' },
            body: JSON.stringify({
                fromPlace: 'Mumbai',
                toPlace: 'Pune',
                distanceKm: 120,
            }),
        } as any);

        const result = await einvoice.generateEWayBill(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(502);
        expect(body.error.code).toBe('EWAY_BILL_ERROR');
    });

    test('POST /invoices/{id}/ewaybill — returns 201 on success', async () => {
        jest.spyOn(einvoiceService, 'generateEWayBill')
            .mockResolvedValueOnce({
                ewbNo: '123456789012',
                ewbDate: '2026-04-26T00:00:00.000Z',
                validUntil: '2026-04-27T00:00:00.000Z',
                status: 'success',
            });

        const event = makeEvent({
            pathParameters: { id: 'inv-1' },
            body: JSON.stringify({
                fromPlace: 'Mumbai',
                toPlace: 'Pune',
                distanceKm: 120,
                vehicleNumber: 'MH12AB1234',
            }),
        } as any);

        const result = await einvoice.generateEWayBill(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(201);
        expect(body.success).toBe(true);
        expect(body.data.ewbNo).toBe('123456789012');
    });

    test('GET /settings/einvoice — returns settings payload', async () => {
        jest.spyOn(einvoiceService, 'getEInvoiceSettings')
            .mockResolvedValueOnce({
                isEnabled: true,
                environment: 'sandbox',
                username: 'nic-user',
                hasClientId: true,
                hasClientSecret: true,
                ewayBillPath: '/eicore/v1.03/ewaybill',
            });

        const result = await einvoice.getEInvoiceSettings(makeEvent(), mockContext);
        const body = parseBody(result);
        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.ewayBillPath).toBe('/eicore/v1.03/ewaybill');
    });

    test('PUT /settings/einvoice — validates payload and returns success', async () => {
        jest.spyOn(einvoiceService, 'upsertEInvoiceSettings')
            .mockResolvedValueOnce({ updated: true });

        const event = makeEvent({
            body: JSON.stringify({
                isEnabled: true,
                environment: 'sandbox',
                ewayBillPath: '/eicore/v1.03/ewaybill',
            }),
        } as any);
        const result = await einvoice.upsertEInvoiceSettings(event, mockContext);
        const body = parseBody(result);
        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.updated).toBe(true);
    });
});

// ============================================================================
// CREDIT / PAYMENT / SHIFT CLOSE REGRESSION TESTS (P0 HARDENING)
// ============================================================================
describe('Critical Fix Hardening', () => {
    const invoiceId = '11111111-1111-4111-8111-111111111111';
    const customerId = '22222222-2222-4222-8222-222222222222';
    const shiftId = '33333333-3333-4333-8333-333333333333';
    const nozzleId = '44444444-4444-4444-8444-444444444444';

    beforeEach(() => {
        jest.clearAllMocks();
        mockGetItem.mockReset();
        mockQueryAllItems.mockReset();
        mockUpdateItem.mockReset();
        mockTransactWrite.mockReset();
        mockRecordRevision.mockReset();
        mockUpdateItem.mockResolvedValue({});
        mockTransactWrite.mockResolvedValue(undefined);
        mockRecordRevision.mockResolvedValue(undefined);
    });

    test('credit policy blocks when open invoice count reaches configured max', async () => {
        const { enforceUdharCreditLimit } = require('../utils/credit-check.util');

        mockGetItem.mockResolvedValue({
            id: customerId,
            creditLimitCents: 100_000,
            creditMaxOpenBills: 2,
            creditMaxAgeDays: 0,
            outstandingCents: 10_000,
            isDeleted: false,
        });
        mockQueryAllItems
            .mockResolvedValueOnce([]) // UDHARTXN ledger
            .mockResolvedValueOnce([   // INVOICE rows
                { id: 'inv-1', balanceCents: 2500 },
                { id: 'inv-2', balanceCents: 1500 },
            ]);

        await expect(
            enforceUdharCreditLimit('test-tenant-id', customerId, 1_000)
        ).rejects.toMatchObject({ code: 'CREDIT_LIMIT_EXCEEDED' });
    });

    test('recordPayment writes invoice/payment/ledger/customer updates in one transaction', async () => {
        const payments = require('../handlers/payments');

        mockGetItem.mockResolvedValue({
            id: invoiceId,
            invoiceNumber: 'INV-001',
            totalCents: 10_000,
            paidCents: 2_000,
            balanceCents: 8_000,
            status: 'partially_paid',
            customerId,
            isDeleted: false,
        });

        const event = makeEvent({
            body: JSON.stringify({
                invoiceId,
                amountCents: 3_000,
                paymentMode: 'cash',
                notes: 'partial collection',
            }),
        });

        const result = await payments.recordPayment(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.paidCents).toBe(5_000);
        expect(mockTransactWrite).toHaveBeenCalledTimes(1);

        const txItems = mockTransactWrite.mock.calls[0][0] as Array<Record<string, any>>;
        expect(txItems).toEqual(
            expect.arrayContaining([
                expect.objectContaining({ Update: expect.objectContaining({ Key: { PK: 'TENANT#test-tenant-id', SK: `INVOICE#${invoiceId}` } }) }),
                expect.objectContaining({ Put: expect.objectContaining({ Item: expect.objectContaining({ entityType: 'PAYMENT', invoiceId, amountCents: 3_000 }) }) }),
                expect.objectContaining({ Put: expect.objectContaining({ Item: expect.objectContaining({ SK: expect.stringMatching(/^UDHARTXN#/) }) }) }),
                expect.objectContaining({ Update: expect.objectContaining({ Key: { PK: 'TENANT#test-tenant-id', SK: `CUSTOMER#${customerId}` } }) }),
            ])
        );
    });

    test('closeShift aggregates both staff sales and pump invoices', async () => {
        const pump = require('../handlers/pump');
        const { verifyAuth } = require('../middleware/cognito-auth');

        verifyAuth.mockResolvedValueOnce({
            sub: 'test-user-id',
            email: 'test@example.com',
            tenantId: 'test-tenant-id',
            role: 'owner',
            businessType: 'petrol_pump',
            planTier: 'enterprise',
        });

        mockGetItem.mockResolvedValue({
            id: shiftId,
            shiftStatus: 'open',
            staffId: 'test-user-id',
            shiftDate: '2026-04-27',
            nozzleSnapshots: [
                {
                    nozzleId,
                    nozzleName: 'N1',
                    fuelType: 'petrol',
                    openingReading: 100,
                },
            ],
            isDeleted: false,
        });

        mockQueryAllItems
            .mockResolvedValueOnce([
                {
                    nozzleId,
                    productType: 'petrol',
                    paymentMode: 'cash',
                    volumeLiters: 1,
                    amountCents: 1_000,
                },
            ])
            .mockResolvedValueOnce([
                {
                    nozzleId,
                    productType: 'petrol',
                    paymentMode: 'upi',
                    volumeLiters: 2,
                    totalCents: 2_000,
                    type: 'sale',
                    createdBy: 'test-user-id',
                    shiftId,
                },
            ]);

        const event = makeEvent({
            body: JSON.stringify({
                shiftId,
                nozzleReadings: [
                    {
                        nozzleId,
                        closingReading: 103,
                        testingAmount: 0,
                    },
                ],
            }),
        });

        const result = await pump.closeShift(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.summary.totalSalesCents).toBe(3_000);
        expect(body.data.summary.totalVolumeLiters).toBe(3);
        expect(body.data.summary.saleCount).toBe(2);
        expect(body.data.summary.totalCashCents).toBe(1_000);
        expect(body.data.summary.totalUpiCents).toBe(2_000);
        expect(mockRecordRevision).toHaveBeenCalledWith(
            'test-tenant-id',
            'shifts',
            shiftId,
            'status_change',
            'test-user-id',
            expect.objectContaining({ shiftStatus: 'open' }),
            expect.objectContaining({ shiftStatus: 'closed', totalSalesCents: 3_000 }),
            expect.objectContaining({ source: 'pump.closeShift' }),
        );
    });

    test('credit policy blocks udhar when open invoice older than creditMaxAgeDays', async () => {
        jest.useFakeTimers();
        jest.setSystemTime(new Date('2026-04-27T12:00:00.000Z'));

        const { enforceUdharCreditLimit } = require('../utils/credit-check.util');

        mockGetItem.mockResolvedValue({
            id: customerId,
            creditLimitCents: 500_000,
            creditMaxOpenBills: 0,
            creditMaxAgeDays: 30,
            outstandingCents: 0,
            isDeleted: false,
        });
        mockQueryAllItems
            .mockResolvedValueOnce([])
            .mockResolvedValueOnce([
                {
                    id: 'inv-old',
                    invoiceNumber: 'INV-OLD',
                    balanceCents: 5_000,
                    createdAt: '2026-03-01T10:00:00.000Z',
                },
            ]);

        await expect(
            enforceUdharCreditLimit('test-tenant-id', customerId, 100)
        ).rejects.toMatchObject({ code: 'CREDIT_LIMIT_EXCEEDED' });

        jest.useRealTimers();
    });

    test('recordPayment returns 409 when transactWrite loses optimistic concurrency', async () => {
        const payments = require('../handlers/payments');

        const staleInvoice = {
            id: invoiceId,
            invoiceNumber: 'INV-CONC',
            totalCents: 10_000,
            paidCents: 2_000,
            balanceCents: 8_000,
            status: 'partially_paid',
            customerId,
            isDeleted: false,
        };
        mockGetItem.mockResolvedValue(staleInvoice);

        mockTransactWrite
            .mockResolvedValueOnce(undefined)
            .mockRejectedValueOnce(Object.assign(new Error('ConditionalCheckFailed'), { name: 'TransactionCanceledException' }));

        const payload = {
            invoiceId,
            amountCents: 3_000,
            paymentMode: 'cash',
            notes: 'race',
        };

        const r1 = await payments.recordPayment(makeEvent({ body: JSON.stringify(payload) }), mockContext);
        expect(r1.statusCode).toBe(200);

        const r2 = await payments.recordPayment(makeEvent({ body: JSON.stringify(payload) }), mockContext);
        expect(r2.statusCode).toBe(409);
        const b2 = parseBody(r2);
        expect(b2.success).toBe(false);
        expect(b2.error?.code).toBe('CONCURRENT_MODIFICATION');
    });

    test('cashierCollectionReport sums same shift totals closeShift would persist', async () => {
        const pumpReports = require('../handlers/pump-reports');
        const { verifyAuth } = require('../middleware/cognito-auth');

        verifyAuth.mockResolvedValueOnce({
            sub: 'test-user-id',
            email: 'test@example.com',
            tenantId: 'test-tenant-id',
            role: 'owner',
            businessType: 'petrol_pump',
            planTier: 'enterprise',
        });

        mockQueryAllItems.mockResolvedValueOnce([
            {
                id: shiftId,
                shiftDate: '2026-04-27',
                staffId: 'test-user-id',
                staffName: 'Closer',
                totalSalesCents: 3_000,
                totalCashCents: 1_000,
                totalUpiCents: 2_000,
                totalUdharCents: 0,
                totalCardCents: 0,
                totalChequeCents: 0,
                totalNeftCents: 0,
                totalFleetCardCents: 0,
                saleCount: 2,
                totalVolumeLiters: 3,
                shiftStatus: 'closed',
                isDeleted: false,
                nozzleReconciliation: [{ varianceLiters: 0 }],
            },
        ]);

        const event = makeEvent({
            rawQueryString: 'from=2026-04-27&to=2026-04-27',
            queryStringParameters: { from: '2026-04-27', to: '2026-04-27' },
        });

        const result = await pumpReports.cashierCollectionReport(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.items).toHaveLength(1);
        const row = body.data.items[0];
        expect(row.totalSalesCents).toBe(3_000);
        expect(row.totalCashCents).toBe(1_000);
        expect(row.totalUpiCents).toBe(2_000);
        expect(row.totalVolumeLiters).toBe(3);
        expect(row.shiftCount).toBe(1);
    });

    test('vehicleLedgerReport returns per-invoice rows + outstanding summary', async () => {
        const pumpReports = require('../handlers/pump-reports');
        const { verifyAuth } = require('../middleware/cognito-auth');

        verifyAuth.mockResolvedValueOnce({
            sub: 'test-user-id',
            email: 'test@example.com',
            tenantId: 'test-tenant-id',
            role: 'owner',
            businessType: 'petrol_pump',
            planTier: 'enterprise',
        });

        mockQueryAllItems.mockResolvedValueOnce([
            {
                id: 'inv-a',
                type: 'sale',
                invoiceNumber: 'INV-1',
                vehicleNumber: 'MH12AB1234',
                saleDate: '2026-04-26',
                createdAt: '2026-04-26T10:00:00.000Z',
                fuelType: 'petrol',
                volumeLiters: 5,
                totalCents: 1_000,
                paidCents: 1_000,
                balanceCents: 0,
                paymentMode: 'cash',
                metadata: { source: 'pump_sale' },
            },
            {
                id: 'inv-b',
                type: 'sale',
                invoiceNumber: 'INV-2',
                vehicleNumber: 'MH12AB1234',
                saleDate: '2026-04-27',
                createdAt: '2026-04-27T11:00:00.000Z',
                fuelType: 'petrol',
                volumeLiters: 10,
                totalCents: 2_000,
                paidCents: 0,
                balanceCents: 2_000,
                paymentMode: 'udhar',
                customerId,
                metadata: { source: 'staff_sale' },
            },
        ]);

        const event = makeEvent({
            rawQueryString: 'vehicleNumber=mh-12-ab-1234',
            queryStringParameters: { vehicleNumber: 'mh-12-ab-1234' },
        });

        const result = await pumpReports.vehicleLedgerReport(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.vehicleNumber).toBe('MH12AB1234');
        expect(body.data.summary.transactionCount).toBe(2);
        expect(body.data.summary.totalSalesCents).toBe(3_000);
        expect(body.data.summary.totalOutstandingCents).toBe(2_000);
        expect(body.data.items[1].source).toBe('staff_sale');
    });

    test('recordPumpSale writes transaction revision entry', async () => {
        const pump = require('../handlers/pump');
        const { verifyAuth } = require('../middleware/cognito-auth');

        verifyAuth.mockResolvedValueOnce({
            sub: 'test-user-id',
            email: 'test@example.com',
            tenantId: 'test-tenant-id',
            role: 'owner',
            businessType: 'petrol_pump',
            planTier: 'enterprise',
        });

        mockQueryItems.mockResolvedValueOnce({
            items: [{ id: 'prod-1', salePriceCents: 10000, productType: 'petrol', isDeleted: false }],
        });
        mockTransactWrite.mockResolvedValueOnce(undefined);

        const event = makeEvent({
            body: JSON.stringify({
                nozzleId,
                fuelType: 'petrol',
                volumeLiters: 2,
                pricePerLiterCents: 10000,
                totalAmountCents: 20000,
                paymentMode: 'cash',
                shiftId,
                vehicleNumber: 'mh12ab1234',
            }),
        });
        const result = await pump.recordPumpSale(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(201);
        expect(body.success).toBe(true);
        expect(mockRecordRevision).toHaveBeenCalledWith(
            'test-tenant-id',
            'transactions',
            expect.any(String),
            'create',
            'test-user-id',
            null,
            expect.objectContaining({
                type: 'sale',
                fuelType: 'petrol',
                totalCents: 20000,
            }),
            expect.objectContaining({ source: 'pump.recordPumpSale' }),
        );
    });

    test('recordCashDrop writes cash settlement revision entry', async () => {
        const pump = require('../handlers/pump');
        const { verifyAuth } = require('../middleware/cognito-auth');

        verifyAuth.mockResolvedValueOnce({
            sub: 'test-user-id',
            email: 'test@example.com',
            tenantId: 'test-tenant-id',
            role: 'owner',
            businessType: 'petrol_pump',
            planTier: 'enterprise',
        });

        mockQueryAllItems
            .mockResolvedValueOnce([{ amountCents: 1000, paymentMode: 'cash', shiftId, isDeleted: false }])
            .mockResolvedValueOnce([{ totalCents: 500, paymentMode: 'cash', shiftId, metadata: { source: 'pump_sale' }, isDeleted: false }]);

        const event = makeEvent({
            body: JSON.stringify({
                shiftId,
                amountCents: 1600,
                denominations: { '500': 3, '100': 1 },
                notes: 'end shift',
            }),
        });
        const result = await pump.recordCashDrop(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(201);
        expect(body.success).toBe(true);
        expect(mockRecordRevision).toHaveBeenCalledWith(
            'test-tenant-id',
            'cash_settlements',
            expect.any(String),
            'create',
            'test-user-id',
            null,
            expect.objectContaining({
                shiftId,
                expectedAmountCents: 1500,
                actualAmountCents: 1600,
                differenceAmountCents: 100,
            }),
            expect.objectContaining({ source: 'pump.recordCashDrop' }),
        );
    });

    test('recordReadings writes nozzle reading revision entry', async () => {
        const pump = require('../handlers/pump');
        const { verifyAuth } = require('../middleware/cognito-auth');

        verifyAuth.mockResolvedValueOnce({
            sub: 'test-user-id',
            email: 'test@example.com',
            tenantId: 'test-tenant-id',
            role: 'owner',
            businessType: 'petrol_pump',
            planTier: 'enterprise',
        });

        const event = makeEvent({
            body: JSON.stringify({
                shiftId,
                readings: [
                    {
                        nozzleId,
                        dispenserId: '55555555-5555-4555-8555-555555555555',
                        tankId: '66666666-6666-4666-8666-666666666666',
                        readingType: 'opening',
                        readingValue: 1234.5,
                    },
                ],
            }),
        });
        const result = await pump.recordReadings(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(201);
        expect(body.success).toBe(true);
        expect(mockRecordRevision).toHaveBeenCalledWith(
            'test-tenant-id',
            'nozzle_readings',
            expect.any(String),
            'create',
            'test-user-id',
            null,
            expect.objectContaining({
                nozzleId,
                readingType: 'opening',
                readingValue: 1234.5,
                shiftId,
            }),
            expect.objectContaining({ source: 'pump.recordReadings' }),
        );
    });
});

describe('Recovery visits (p21)', () => {
    const recoveryCustomerId = '22222222-2222-4222-8222-222222222222';

    beforeEach(() => {
        jest.clearAllMocks();
        mockGetItem.mockReset();
        mockPutItem.mockReset();
        mockQueryAllItems.mockReset();
        mockPutItem.mockResolvedValue(undefined);
    });

    test('POST /customers/recovery-visits — creates RECOVERYVISIT row', async () => {
        const recovery = require('../handlers/recovery-visits');

        mockGetItem.mockResolvedValue({
            id: recoveryCustomerId,
            name: 'Udhar Party',
            phone: '9876500000',
            isDeleted: false,
        });

        const event = makeEvent({
            body: JSON.stringify({
                customerId: recoveryCustomerId,
                outcome: 'promised_payment',
                outstandingSnapshotCents: 5000,
                promiseDate: '2026-05-01',
                notes: 'Pay next week',
            }),
        });

        const result = await recovery.recordRecoveryVisit(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(201);
        expect(body.success).toBe(true);
        expect(body.data.outcome).toBe('promised_payment');
        expect(mockPutItem).toHaveBeenCalled();
        const recoveryPut = mockPutItem.mock.calls
            .map(c => c[0])
            .find((x: Record<string, any>) => x.entityType === 'RECOVERY_VISIT');
        expect(recoveryPut).toMatchObject({
            entityType: 'RECOVERY_VISIT',
            outcome: 'promised_payment',
            customerId: recoveryCustomerId,
        });
    });

    test('GET /customers/recovery-visits — register filters by visit date range', async () => {
        const recovery = require('../handlers/recovery-visits');

        mockQueryAllItems.mockResolvedValueOnce([
            {
                id: 'visit-a',
                customerId: recoveryCustomerId,
                customerName: 'Udhar Party',
                customerPhone: '9876500000',
                outcome: 'contacted',
                promiseDate: '2020-01-01',
                outstandingSnapshotCents: 3000,
                visitedAt: '2026-04-26T10:00:00.000Z',
                createdAt: '2026-04-26T10:00:00.000Z',
                createdBy: 'test-user-id',
                isDeleted: false,
            },
            {
                id: 'visit-b',
                customerId: recoveryCustomerId,
                customerName: 'Udhar Party',
                outcome: 'promised_payment',
                visitedAt: '2026-05-01T09:00:00.000Z',
                createdAt: '2026-05-01T09:00:00.000Z',
                createdBy: 'test-user-id',
                isDeleted: false,
            },
        ]);

        const event = makeEvent({
            rawQueryString: 'from=2026-04-01&to=2026-04-30',
            queryStringParameters: { from: '2026-04-01', to: '2026-04-30' },
        });

        const result = await recovery.listRecoveryRegister(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.summary.visitCount).toBe(1);
        expect(body.data.summary.uniqueParties).toBe(1);
        expect(body.data.summary.promiseOverdueCount).toBe(1);
        expect(body.data.summary.outstandingSnapshotSumCents).toBe(3000);
        expect(body.data.items[0].id).toBe('visit-a');
        expect(body.data.items[0].promiseOverdue).toBe(true);
        expect(body.data.summary.byOutcome.contacted).toBe(1);
    });

    test('GET /customers/recovery-visits — promiseOverdueOnly + customerSearch', async () => {
        const recovery = require('../handlers/recovery-visits');

        mockQueryAllItems.mockResolvedValueOnce([
            {
                id: 'v1',
                customerId: recoveryCustomerId,
                customerName: 'Udhar Party',
                customerPhone: '9876500000',
                outcome: 'promised_payment',
                promiseDate: '2020-01-01',
                visitedAt: '2026-04-26T10:00:00.000Z',
                isDeleted: false,
            },
            {
                id: 'v2',
                customerId: recoveryCustomerId,
                customerName: 'Udhar Party',
                outcome: 'contacted',
                promiseDate: '2099-12-31',
                visitedAt: '2026-04-26T11:00:00.000Z',
                isDeleted: false,
            },
        ]);

        const event = makeEvent({
            rawQueryString: 'from=2026-04-01&to=2026-04-30&promiseOverdueOnly=true&customerSearch=Udhar',
            queryStringParameters: {
                from: '2026-04-01',
                to: '2026-04-30',
                promiseOverdueOnly: 'true',
                customerSearch: 'Udhar',
            },
        });

        const result = await recovery.listRecoveryRegister(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.data.items).toHaveLength(1);
        expect(body.data.items[0].id).toBe('v1');
        expect(body.data.filter.promiseOverdueOnly).toBe(true);
    });
});

describe('Inventory p14/p8 (dip chart + tank stock)', () => {
    const tankId = '55555555-5555-4555-8555-555555555555';

    beforeEach(() => {
        jest.clearAllMocks();
        const { verifyAuth } = require('../middleware/cognito-auth');
        verifyAuth.mockResolvedValue({
            sub: 'test-user-id',
            email: 'test@example.com',
            tenantId: 'test-tenant-id',
            role: 'owner',
            businessType: 'petrol_pump',
            planTier: 'enterprise',
        });
        mockQueryAllItems.mockReset();
        mockPutItem.mockReset();
        mockPutItem.mockResolvedValue(undefined);
    });

    test('POST /pump/dip-chart/upload stores normalized chart points', async () => {
        const integrations = require('../handlers/pump-integrations');

        const event = makeEvent({
            body: JSON.stringify({
                tankId,
                effectiveFrom: '2026-04-01',
                points: [
                    { mm: 200, liters: 1500 },
                    { mm: 100, liters: 700 },
                    { mm: 200, liters: 1490 }, // duplicate mm, keep last
                ],
            }),
        });
        const result = await integrations.uploadDipChart(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(201);
        expect(body.success).toBe(true);
        expect(mockPutItem).toHaveBeenCalled();
        const dipChartPut = mockPutItem.mock.calls
            .map(c => c[0])
            .find((x: Record<string, any>) => x.entityType === 'TANK_DIP_CHART');
        expect(dipChartPut).toMatchObject({
            entityType: 'TANK_DIP_CHART',
            tankId,
            effectiveFrom: '2026-04-01',
            pointCount: 2,
        });
    });

    test('GET /pump/dip-chart/convert interpolates liters from chart', async () => {
        const integrations = require('../handlers/pump-integrations');

        mockQueryAllItems.mockResolvedValueOnce([
            {
                id: 'chart-1',
                tankId,
                effectiveFrom: '2026-04-01',
                points: [{ mm: 100, liters: 700 }, { mm: 200, liters: 1500 }],
                isDeleted: false,
            },
        ]);

        const event = makeEvent({
            rawQueryString: `tankId=${tankId}&dipLevelMm=150&atDate=2026-04-15`,
            queryStringParameters: { tankId, dipLevelMm: '150', atDate: '2026-04-15' },
        } as any);
        const result = await integrations.convertDipToVolume(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.volumeLiters).toBe(1100);
    });

    test('GET /pump/reports/tank-stock returns canonical latest volume per tank', async () => {
        const reports = require('../handlers/pump-reports');

        mockQueryAllItems
            .mockResolvedValueOnce([
                {
                    tankId,
                    dipLevelMm: 300,
                    observedVolumeLiters: 2200,
                    recordedAt: '2026-04-20T10:00:00.000Z',
                    isDeleted: false,
                },
            ])
            .mockResolvedValueOnce([
                {
                    tankId,
                    measuredVolumeLiters: 2100,
                    measuredAt: '2026-04-21T10:00:00.000Z',
                },
            ]);

        const event = makeEvent({
            rawQueryString: 'from=2026-04-01&to=2026-04-30',
            queryStringParameters: { from: '2026-04-01', to: '2026-04-30' },
        });
        const result = await reports.tankStockReport(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.totals.tankCount).toBe(1);
        expect(body.data.items[0].canonicalVolumeLiters).toBe(2100);
        expect(body.data.items[0].source).toBe('mixed');
    });

    test('GET /pump/reports/dip-variance aggregates variance and exceptions', async () => {
        const reports = require('../handlers/pump-reports');

        mockQueryAllItems.mockResolvedValueOnce([
            {
                shiftDate: '2026-04-20',
                isDeleted: false,
                nozzleReconciliation: [
                    {
                        tankId,
                        tankName: 'T1',
                        nozzleId: 'n1',
                        fuelType: 'petrol',
                        varianceLiters: -3,
                        status: 'VARIANCE',
                    },
                ],
            },
            {
                shiftDate: '2026-04-21',
                isDeleted: false,
                nozzleReconciliation: [
                    {
                        tankId,
                        tankName: 'T1',
                        nozzleId: 'n1',
                        fuelType: 'petrol',
                        varianceLiters: 1,
                        status: 'OK',
                    },
                ],
            },
        ]);

        const event = makeEvent({
            rawQueryString: 'from=2026-04-01&to=2026-04-30',
            queryStringParameters: { from: '2026-04-01', to: '2026-04-30' },
        });
        const result = await reports.dipVarianceReport(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.totals.tankCount).toBe(1);
        expect(body.data.totals.totalVarianceLiters).toBe(-2);
        expect(body.data.items[0].exceptionsCount).toBe(1);
        expect(body.data.items[0].avgVarianceLiters).toBe(-1);
    });

    test('POST /pump/tanker-receipts flags dip-short when shortage crosses threshold', async () => {
        const integrations = require('../handlers/pump-integrations');

        const event = makeEvent({
            body: JSON.stringify({
                tankId,
                fuelType: 'diesel',
                tankerNumber: 'MH12TRK9999',
                expectedQtyLiters: 12000,
                receivedQtyLiters: 11960,
                thresholdLiters: 20,
            }),
        });
        const result = await integrations.recordTankerReceipt(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(201);
        expect(body.success).toBe(true);
        expect(body.data.isDipShort).toBe(true);
        expect(body.data.shortageLiters).toBe(40);
        expect(mockPutItem).toHaveBeenCalled();
        const tankerPut = mockPutItem.mock.calls
            .map(c => c[0])
            .find((x: Record<string, any>) => x.entityType === 'TANKER_RECEIPT');
        expect(tankerPut).toMatchObject({
            entityType: 'TANKER_RECEIPT',
            status: 'dip_short',
            expectedQtyLiters: 12000,
            receivedQtyLiters: 11960,
        });
    });

    test('POST /pump/ppm-reading stores density payload with temp and dip context', async () => {
        const integrations = require('../handlers/pump-integrations');

        const event = makeEvent({
            body: JSON.stringify({
                tankId,
                ppmValue: 1200,
                measuredAt: '2026-04-24T06:30:00.000Z',
                temperatureCelsius: 29.4,
                dipLevelMm: 1900,
                observedVolumeLiters: 8350.5,
                notes: 'Morning sample',
            }),
        });
        const result = await integrations.recordPpmReading(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(201);
        expect(body.success).toBe(true);
        expect(body.data.ppmValue).toBe(1200);
        expect(body.data.temperatureCelsius).toBe(29.4);
        expect(body.data.dipLevelMm).toBe(1900);
        expect(body.data.observedVolumeLiters).toBe(8350.5);
        const densityPut = mockPutItem.mock.calls
            .map(c => c[0])
            .find((x: Record<string, any>) => x.entityType === 'DENSITY_RECORD');
        expect(densityPut).toMatchObject({
            entityType: 'DENSITY_RECORD',
            tankId,
            ppmValue: 1200,
            temperatureCelsius: 29.4,
            dipLevelMm: 1900,
            observedVolumeLiters: 8350.5,
            notes: 'Morning sample',
        });
    });

    test('GET /pump/reports/tanker-receipts returns totals and dip-short count', async () => {
        const reports = require('../handlers/pump-reports');

        mockQueryAllItems.mockResolvedValueOnce([
            {
                id: 'r1',
                receivedAt: '2026-04-20T10:00:00.000Z',
                createdAt: '2026-04-20T10:00:01.000Z',
                tankId,
                fuelType: 'diesel',
                tankerNumber: 'MH12TRK9999',
                supplierName: 'HPCL Depot',
                notes: 'Night unload',
                recordedBy: 'staff-1',
                dipBeforeMm: 1200,
                dipAfterMm: 4500,
                expectedQtyLiters: 12000,
                receivedQtyLiters: 11960,
                shortageLiters: 40,
                excessLiters: 0,
                deltaLiters: -40,
                thresholdLiters: 20,
                isDipShort: true,
                status: 'dip_short',
                isDeleted: false,
            },
        ]);

        const event = makeEvent({
            rawQueryString: 'from=2026-04-01&to=2026-04-30',
            queryStringParameters: { from: '2026-04-01', to: '2026-04-30' },
        });
        const result = await reports.tankerReceiptReport(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.totals.receiptCount).toBe(1);
        expect(body.data.totals.dipShortCount).toBe(1);
        expect(body.data.totals.shortageLiters).toBe(40);
        expect(body.data.totals.excessLiters).toBe(0);
        expect(body.data.breakdown.byTanker).toHaveLength(1);
        expect(body.data.breakdown.byTanker[0].tankerNumber).toBe('MH12TRK9999');
        expect(body.data.breakdown.bySupplier[0].supplierName).toBe('HPCL Depot');
        expect(body.data.items[0].notes).toBe('Night unload');
        expect(body.data.items[0].dipBeforeMm).toBe(1200);
    });

    test('GET /pump/reports/atg-readings returns rows and alert counts', async () => {
        const reports = require('../handlers/pump-reports');

        mockQueryAllItems.mockResolvedValueOnce([
            {
                id: 'atg-1',
                tankId,
                fuelType: 'diesel',
                measuredVolumeLiters: 5000,
                measuredAt: '2026-04-21T08:00:00.000Z',
                waterLevelMm: 12,
                temperatureCelsius: 28,
                leakDetected: true,
                highWaterAlarm: false,
                source: 'atg',
                isDeleted: false,
            },
            {
                id: 'atg-2',
                tankId,
                measuredVolumeLiters: 4990,
                measuredAt: '2026-04-22T08:00:00.000Z',
                leakDetected: false,
                highWaterAlarm: false,
                isDeleted: false,
            },
        ]);

        const event = makeEvent({
            rawQueryString: 'from=2026-04-01&to=2026-04-30',
            queryStringParameters: { from: '2026-04-01', to: '2026-04-30' },
        });
        const result = await reports.atgReadingsReport(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.totals.readingCount).toBe(2);
        expect(body.data.totals.leakAlarmCount).toBe(1);
        const withLeak = body.data.items.find((x: { id: string }) => x.id === 'atg-1');
        expect(withLeak.leakDetected).toBe(true);
        expect(withLeak.waterLevelMm).toBe(12);
    });

    test('GET /pump/reports/rate-variation returns deltas and impact', async () => {
        const reports = require('../handlers/pump-reports');

        mockQueryAllItems
            .mockResolvedValueOnce([
                {
                    id: 'chg-1',
                    fuelType: 'diesel',
                    effectiveFrom: '2026-04-20T00:00:00.000Z',
                    previousPriceCents: 9000,
                    newPriceCents: 9200,
                    reason: 'OMC revision',
                    changedBy: 'test-user-id',
                },
            ])
            .mockResolvedValueOnce([
                {
                    id: 'sale-1',
                    type: 'sale',
                    fuelType: 'diesel',
                    volumeLiters: 10,
                    saleDate: '2026-04-21',
                    isDeleted: false,
                },
            ])
            .mockResolvedValueOnce([])
            .mockResolvedValueOnce([]);

        const event = makeEvent({
            rawQueryString: 'from=2026-04-01&to=2026-04-30&fuelType=diesel',
            queryStringParameters: { from: '2026-04-01', to: '2026-04-30', fuelType: 'diesel' },
        });
        const result = await reports.rateVariationReport(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.totals.changeCount).toBe(1);
        expect(body.data.items[0].deltaCents).toBe(200);
        expect(body.data.items[0].impactedVolumeLiters).toBe(10);
        expect(body.data.items[0].estimatedValueImpactCents).toBe(2000);
        expect(body.data.items[0].stockHoldLiters).toBe(0);
        expect(body.data.items[0].stockHoldInventoryImpactCents).toBe(0);
        expect(body.data.totals.totalStockHoldInventoryImpactCents).toBe(0);
    });

    test('GET /pump/reports/stock-valuation returns valuation by method', async () => {
        const reports = require('../handlers/pump-reports');

        mockQueryAllItems
            .mockResolvedValueOnce([
                {
                    tankId,
                    fuelType: 'diesel',
                    observedVolumeLiters: 100,
                    recordedAt: '2026-04-22T10:00:00.000Z',
                    isDeleted: false,
                },
            ])
            .mockResolvedValueOnce([])
            .mockResolvedValueOnce([
                {
                    id: 'p1',
                    productType: 'diesel',
                    salePriceCents: 9200,
                    purchasePriceCents: 8500,
                    isDeleted: false,
                },
            ])
            .mockResolvedValueOnce([
                {
                    fuelType: 'diesel',
                    receivedAt: '2026-04-20T09:00:00.000Z',
                    receivedQtyLiters: 10000,
                    unitCostCents: 8000,
                    isDeleted: false,
                },
            ])
            .mockResolvedValueOnce([]);

        const event = makeEvent({
            rawQueryString: 'from=2026-04-01&to=2026-04-30&fuelType=diesel&method=fifo',
            queryStringParameters: { from: '2026-04-01', to: '2026-04-30', fuelType: 'diesel', method: 'fifo' },
        });
        const result = await reports.stockValuationReport(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.totals.tankCount).toBe(1);
        expect(body.data.items[0].unitRateCents).toBe(8000);
        expect(body.data.items[0].valuationCents).toBe(800000);
    });

    test('GET /pump/reports/stock-valuation density_adjusted uses DENSITY# PPM multiplier', async () => {
        const reports = require('../handlers/pump-reports');

        mockQueryAllItems
            .mockResolvedValueOnce([
                {
                    tankId,
                    fuelType: 'diesel',
                    observedVolumeLiters: 100,
                    recordedAt: '2026-04-22T10:00:00.000Z',
                    isDeleted: false,
                },
            ])
            .mockResolvedValueOnce([])
            .mockResolvedValueOnce([
                {
                    id: 'p1',
                    productType: 'diesel',
                    salePriceCents: 9200,
                    purchasePriceCents: 8500,
                    isDeleted: false,
                },
            ])
            .mockResolvedValueOnce([
                {
                    fuelType: 'diesel',
                    receivedAt: '2026-04-20T09:00:00.000Z',
                    receivedQtyLiters: 10000,
                    unitCostCents: 8000,
                    isDeleted: false,
                },
            ])
            .mockResolvedValueOnce([
                {
                    tankId,
                    ppmValue: 5000,
                    measuredAt: '2026-04-21T12:00:00.000Z',
                    isDeleted: false,
                },
            ]);

        const event = makeEvent({
            rawQueryString: 'from=2026-04-01&to=2026-04-30&fuelType=diesel&method=density_adjusted&densityFactor=1&ppmScale=50000&ppmFloor=0.85',
            queryStringParameters: {
                from: '2026-04-01',
                to: '2026-04-30',
                fuelType: 'diesel',
                method: 'density_adjusted',
                densityFactor: '1',
                ppmScale: '50000',
                ppmFloor: '0.85',
            },
        });
        const result = await reports.stockValuationReport(event, mockContext);
        const body = parseBody(result);

        expect(result.statusCode).toBe(200);
        expect(body.data.items[0].ppm.ppmMultiplier).toBe(0.9);
        expect(body.data.items[0].unitRateCents).toBe(7200);
        expect(body.data.items[0].valuationCents).toBe(720000);
    });
});















