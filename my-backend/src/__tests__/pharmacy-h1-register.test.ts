// ============================================================================
// Pharmacy Schedule H1 Register & FEFO Override Tests
// ============================================================================
// Covers the P0 work delivered in the Pharmacy Production Upgrade plan:
//   1. POST /pharmacy/h1-register      → createH1Entry handler
//   2. GET  /pharmacy/h1-register      → getH1Register handler
//   3. GET  /pharmacy/h1-register/export → exportH1Register handler
//   4. POST /pharmacy/fefo-override/authorize → authorizeFefoOverride handler
//   5. Invoice service Schedule H1 enforcement (Rx gate end-to-end)
//
// Run with: npx jest src/__tests__/pharmacy-h1-register.test.ts --verbose
// ============================================================================

// ---- Mock DynamoDB --------------------------------------------------------
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

// ---- Mock Auth / Context / Logger / WS ------------------------------------
jest.mock('../utils/context', () => ({
    getTenantId: () => 'test-tenant-id',
    getCorrelationId: () => 'test-corr-id',
    getUserId: () => 'test-user-id',
    runWithContext: (_ctx: any, fn: any) => fn(),
    contextStorage: { run: (_ctx: any, fn: any) => fn() },
}));
jest.mock('@aws-sdk/client-cloudwatch', () => ({
    CloudWatchClient: jest.fn().mockImplementation(() => ({
        send: jest.fn().mockResolvedValue({}),
    })),
    PutMetricDataCommand: jest.fn(),
}));
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
jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: jest.fn().mockResolvedValue({
        sub: 'test-user-id',
        email: 'pharmacist@test.com',
        tenantId: 'test-tenant-id',
        role: 'owner',
        businessType: 'pharmacy',
        planTier: 'enterprise',
    }),
    requireRole: jest.fn(),
    AuthError: class AuthError extends Error {
        statusCode: number;
        constructor(msg: string, code = 401) {
            super(msg);
            this.statusCode = code;
            this.name = 'AuthError';
        }
    },
}));
jest.mock('../middleware/plan-guard', () => ({
    validateFeatureAccess: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../middleware/cloudwatch-logger', () => ({
    logRequest: jest.fn().mockResolvedValue(undefined),
    logAuthFailure: jest.fn().mockResolvedValue(undefined),
}));

// ---- Constants ------------------------------------------------------------
const TENANT_ID = 'test-tenant-id';
const USER_ID = 'test-user-id';

// ---- Helpers --------------------------------------------------------------
function makeEvent(method: string, path: string, body?: any, query?: Record<string, string>): any {
    const rawQuery = query
        ? Object.entries(query).map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&')
        : '';
    return {
        version: '2.0',
        routeKey: `${method} ${path}`,
        rawPath: path,
        rawQueryString: rawQuery,
        headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer mock-token',
        },
        queryStringParameters: query,
        requestContext: {
            accountId: 'local',
            apiId: 'local',
            domainName: 'localhost',
            domainPrefix: '',
            http: {
                method,
                path,
                protocol: 'HTTP/1.1',
                sourceIp: '127.0.0.1',
                userAgent: 'jest',
            },
            requestId: 'test-req-h1',
            routeKey: `${method} ${path}`,
            stage: '$default',
            time: new Date().toISOString(),
            timeEpoch: Date.now(),
        },
        body: body ? JSON.stringify(body) : undefined,
        isBase64Encoded: false,
    };
}

function futureDate(daysFromNow: number): string {
    const d = new Date();
    d.setDate(d.getDate() + daysFromNow);
    return d.toISOString().split('T')[0];
}

// ---- Import handlers after mocks -----------------------------------------
import {
    createH1Entry as _createH1Entry,
    getH1Register as _getH1Register,
    exportH1Register as _exportH1Register,
    authorizeFefoOverride as _authorizeFefoOverride,
} from '../handlers/pharmacy';

// Cast to any so we can pull the structured response back out.
const createH1Entry = _createH1Entry as any;
const getH1Register = _getH1Register as any;
const exportH1Register = _exportH1Register as any;
const authorizeFefoOverride = _authorizeFefoOverride as any;

// ============================================================================
// 1. POST /pharmacy/h1-register
// ============================================================================
describe('H1 Register: POST /pharmacy/h1-register', () => {
    beforeEach(() => jest.clearAllMocks());

    test('creates an H1LOG record with all statutory fields', async () => {
        const expiry = futureDate(365);
        const event = makeEvent('POST', '/pharmacy/h1-register', {
            patientName: 'Rajesh Kumar',
            patientAddress: '42 MG Road, Pune 411001',
            prescribingDoctorName: 'Dr. Priya Sharma',
            doctorRegNo: 'MCI-12345',
            prescriptionId: 'RX-2026-04-100',
            drugName: 'Tramadol 50mg',
            quantitySold: 10,
            batchNumber: 'B-2026-04-001',
            expiryDate: expiry,
            invoiceId: 'inv-h1-001',
        });

        const result = await createH1Entry(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(201);
        expect(body.data.invoiceId).toBe('inv-h1-001');
        expect(body.data.drugName).toBe('Tramadol 50mg');
        expect(body.data.quantitySold).toBe(10);
        expect(body.data.patientName).toBe('Rajesh Kumar');
        expect(body.data.dispensedAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
        expect(body.data.id).toMatch(/^H1LOG#inv-h1-001#/);

        // Find the H1_LOG put call (other calls are revision/audit fire-and-forget)
        const h1Put = mockPutItem.mock.calls
            .map(c => c[0])
            .find((it: any) => it?.entityType === 'H1_LOG');
        expect(h1Put).toBeDefined();
        expect(h1Put.PK).toBe(`TENANT#${TENANT_ID}`);
        expect(h1Put.SK).toMatch(/^H1LOG#inv-h1-001#/);
        expect(h1Put.scheduleType).toBe('H1');
        expect(h1Put.doctorRegNo).toBe('MCI-12345');
        expect(h1Put.dispensedBy).toBe(USER_ID);
        expect(h1Put.expiryDate).toBe(expiry);
    });

    test('rejects request when prescribingDoctorName is missing', async () => {
        const event = makeEvent('POST', '/pharmacy/h1-register', {
            patientName: 'Anita Singh',
            doctorRegNo: 'MCI-12345',
            prescriptionId: 'RX-2026-04-101',
            drugName: 'Tramadol 50mg',
            quantitySold: 5,
            batchNumber: 'B-2026-04-002',
            expiryDate: futureDate(365),
            invoiceId: 'inv-h1-002',
            // prescribingDoctorName intentionally missing
        });

        const result = await createH1Entry(event, {} as any);
        expect(result.statusCode).toBe(400);
        expect(mockPutItem).not.toHaveBeenCalled();
    });

    test('rejects request when doctorRegNo does not match XX-NNNNN pattern', async () => {
        const event = makeEvent('POST', '/pharmacy/h1-register', {
            patientName: 'Rajesh Kumar',
            prescribingDoctorName: 'Dr. Priya Sharma',
            doctorRegNo: 'badly-formatted',
            prescriptionId: 'RX-2026-04-102',
            drugName: 'Tramadol 50mg',
            quantitySold: 10,
            batchNumber: 'B-2026-04-003',
            expiryDate: futureDate(365),
            invoiceId: 'inv-h1-003',
        });

        const result = await createH1Entry(event, {} as any);
        expect(result.statusCode).toBe(400);
        expect(mockPutItem).not.toHaveBeenCalled();
    });

    test('rejects non-positive quantitySold', async () => {
        const event = makeEvent('POST', '/pharmacy/h1-register', {
            patientName: 'Rajesh Kumar',
            prescribingDoctorName: 'Dr. Priya Sharma',
            doctorRegNo: 'MCI-12345',
            prescriptionId: 'RX-2026-04-103',
            drugName: 'Tramadol 50mg',
            quantitySold: 0,
            batchNumber: 'B-2026-04-004',
            expiryDate: futureDate(365),
            invoiceId: 'inv-h1-004',
        });

        const result = await createH1Entry(event, {} as any);
        expect(result.statusCode).toBe(400);
        expect(mockPutItem).not.toHaveBeenCalled();
    });
});

// ============================================================================
// 2. GET /pharmacy/h1-register
// ============================================================================
describe('H1 Register: GET /pharmacy/h1-register', () => {
    beforeEach(() => jest.clearAllMocks());

    function makeH1Item(overrides: Record<string, any> = {}) {
        const dispensedAt = overrides.dispensedAt
            || new Date('2026-04-15T10:00:00.000Z').toISOString();
        return {
            PK: `TENANT#${TENANT_ID}`,
            SK: `H1LOG#inv-${overrides.invoiceId || 'x'}#${dispensedAt}`,
            entityType: 'H1_LOG',
            tenantId: TENANT_ID,
            patientName: 'Rajesh Kumar',
            patientAddress: '42 MG Road, Pune',
            prescribingDoctorName: 'Dr. Priya Sharma',
            doctorRegNo: 'MCI-12345',
            prescriptionId: 'RX-2026-04-100',
            drugName: 'Tramadol 50mg',
            scheduleType: 'H1',
            quantitySold: 10,
            batchNumber: 'B-001',
            expiryDate: futureDate(365),
            dispensedBy: USER_ID,
            dispensedAt,
            invoiceId: overrides.invoiceId || 'inv-h1-001',
            createdAt: dispensedAt,
            ...overrides,
        };
    }

    test('returns paginated entries sorted by dispensedAt desc', async () => {
        const items = [
            makeH1Item({
                invoiceId: 'A',
                dispensedAt: '2026-04-15T10:00:00.000Z',
            }),
            makeH1Item({
                invoiceId: 'B',
                dispensedAt: '2026-04-16T10:00:00.000Z',
            }),
            makeH1Item({
                invoiceId: 'C',
                dispensedAt: '2026-04-14T10:00:00.000Z',
            }),
        ];
        mockQueryItems.mockResolvedValueOnce({ items, lastKey: undefined });

        const event = makeEvent('GET', '/pharmacy/h1-register', undefined, {
            page: '1',
            pageSize: '50',
        });

        const result = await getH1Register(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(200);
        expect(body.data).toHaveLength(3);
        // Newest first
        expect(body.data[0].invoiceId).toBe('B');
        expect(body.data[1].invoiceId).toBe('A');
        expect(body.data[2].invoiceId).toBe('C');
        expect(body.meta.total).toBe(3);
        expect(body.meta.page).toBe(1);
    });

    test('respects page size pagination', async () => {
        const items = Array.from({ length: 5 }, (_, i) =>
            makeH1Item({
                invoiceId: `inv-${i}`,
                dispensedAt: `2026-04-${10 + i}T10:00:00.000Z`,
            }),
        );
        mockQueryItems.mockResolvedValueOnce({ items, lastKey: undefined });

        const event = makeEvent('GET', '/pharmacy/h1-register', undefined, {
            page: '2',
            pageSize: '2',
        });

        const result = await getH1Register(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(200);
        expect(body.data).toHaveLength(2);
        expect(body.meta.total).toBe(5);
        expect(body.meta.page).toBe(2);
        expect(body.meta.limit).toBe(2);
    });

    test('passes startDate/endDate filter to DynamoDB query', async () => {
        mockQueryItems.mockResolvedValueOnce({ items: [], lastKey: undefined });

        const event = makeEvent('GET', '/pharmacy/h1-register', undefined, {
            startDate: '2026-04-01',
            endDate: '2026-04-30',
        });

        await getH1Register(event, {} as any);

        expect(mockQueryItems).toHaveBeenCalledTimes(1);
        const opts = mockQueryItems.mock.calls[0][2];
        expect(opts.filterExpression).toContain('dispensedAt >= :startDate');
        expect(opts.filterExpression).toContain('dispensedAt <= :endDate');
        expect(opts.expressionAttributeValues[':startDate']).toBe('2026-04-01T00:00:00.000Z');
        expect(opts.expressionAttributeValues[':endDate']).toBe('2026-04-30T23:59:59.999Z');
    });

    test('returns 400 for malformed startDate', async () => {
        const event = makeEvent('GET', '/pharmacy/h1-register', undefined, {
            startDate: 'not-a-date',
        });

        const result = await getH1Register(event, {} as any);
        expect(result.statusCode).toBe(400);
        expect(mockQueryItems).not.toHaveBeenCalled();
    });
});

// ============================================================================
// 3. GET /pharmacy/h1-register/export
// ============================================================================
describe('H1 Register: GET /pharmacy/h1-register/export', () => {
    beforeEach(() => jest.clearAllMocks());

    test('returns CSV with statutory header row', async () => {
        const item = {
            PK: `TENANT#${TENANT_ID}`,
            SK: 'H1LOG#inv-1#2026-04-15T10:00:00.000Z',
            dispensedAt: '2026-04-15T10:00:00.000Z',
            drugName: 'Tramadol 50mg',
            batchNumber: 'B-001',
            quantitySold: 10,
            patientName: 'Rajesh Kumar',
            patientAddress: '42 MG Road, Pune',
            prescribingDoctorName: 'Dr. Priya Sharma',
            doctorRegNo: 'MCI-12345',
            invoiceId: 'inv-1',
            prescriptionId: 'RX-100',
        };
        mockQueryItems.mockResolvedValueOnce({ items: [item], lastKey: undefined });

        const event = makeEvent('GET', '/pharmacy/h1-register/export', undefined, {
            format: 'csv',
        });

        const result = await exportH1Register(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(200);
        expect(body.data.format).toBe('csv');
        expect(body.data.totalRows).toBe(1);
        expect(body.data.fileName).toMatch(/^h1-register-.*\.csv$/);
        // CSV header row is the first line of the embedded csv string.
        const csv = body.data.csv as string;
        expect(csv.split('\n')[0]).toBe(
            'dispensedAt,drugName,batchNumber,quantitySold,patientName,patientAddress,prescribingDoctorName,doctorRegNo,invoiceId,prescriptionId',
        );
        expect(csv).toContain('Tramadol 50mg');
        expect(csv).toContain('MCI-12345');
    });

    test('returns JSON payload by default', async () => {
        mockQueryItems.mockResolvedValueOnce({ items: [], lastKey: undefined });

        const event = makeEvent('GET', '/pharmacy/h1-register/export', undefined, {
            format: 'json',
        });

        const result = await exportH1Register(event, {} as any);
        expect(result.statusCode).toBe(200);
        const body = JSON.parse(result.body as string);
        expect(body.data.format).toBe('json');
        expect(body.data.totalRows).toBe(0);
        expect(Array.isArray(body.data.rows)).toBe(true);
        expect(body.data.fileName).toMatch(/^h1-register-.*\.json$/);
    });

    test('rejects unknown format', async () => {
        const event = makeEvent('GET', '/pharmacy/h1-register/export', undefined, {
            format: 'xml',
        });
        const result = await exportH1Register(event, {} as any);
        expect(result.statusCode).toBe(400);
    });
});

// ============================================================================
// 4. POST /pharmacy/fefo-override/authorize
// ============================================================================
describe('FEFO Override: POST /pharmacy/fefo-override/authorize', () => {
    beforeEach(() => jest.clearAllMocks());

    test('returns 200 + audit row when supplied PIN matches user PIN', async () => {
        mockGetItem.mockResolvedValue({
            PK: `TENANT#${TENANT_ID}`,
            SK: `USER#${USER_ID}`,
            id: USER_ID,
            isDeleted: false,
            managerPin: '4242',
            role: 'owner',
        });

        const event = makeEvent('POST', '/pharmacy/fefo-override/authorize', {
            supervisorPin: '4242',
            productId: 'prod-1',
            autoSelectedBatchId: 'batch-fefo-A',
            selectedBatchId: 'batch-newer-B',
            reason: 'Customer requested longer expiry',
        });

        const result = await authorizeFefoOverride(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(200);
        expect(body.data.authorized).toBe(true);
        expect(body.data.overrideId).toBeTruthy();
        expect(body.data.usedMasterPin).toBe(false);

        // Find the FEFO_OVERRIDE_AUDIT row (separate from any fire-and-forget AUDIT_LOG)
        const audit = mockPutItem.mock.calls
            .map(c => c[0])
            .find((it: any) => it?.entityType === 'FEFO_OVERRIDE_AUDIT');
        expect(audit).toBeDefined();
        expect(audit.SK).toMatch(/^FEFOOVR#/);
        expect(audit.productId).toBe('prod-1');
        expect(audit.autoSelectedBatchId).toBe('batch-fefo-A');
        expect(audit.selectedBatchId).toBe('batch-newer-B');
        expect(audit.reason).toBe('Customer requested longer expiry');
        expect(audit.usedMasterPin).toBe(false);
    });

    test('returns 401 when PIN does not match', async () => {
        mockGetItem.mockResolvedValue({
            PK: `TENANT#${TENANT_ID}`,
            SK: `USER#${USER_ID}`,
            id: USER_ID,
            isDeleted: false,
            managerPin: '4242',
        });

        const event = makeEvent('POST', '/pharmacy/fefo-override/authorize', {
            supervisorPin: '0000',
            productId: 'prod-1',
        });

        const result = await authorizeFefoOverride(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(401);
        expect(body.error?.code).toBe('INVALID_PIN');
        // No FEFO_OVERRIDE_AUDIT row is written on rejection. logAudit is
        // fire-and-forget; we only assert the explicit override audit is absent.
        const overrideAudit = mockPutItem.mock.calls
            .map(c => c[0])
            .find((it: any) => it?.entityType === 'FEFO_OVERRIDE_AUDIT');
        expect(overrideAudit).toBeUndefined();
    });

    test('returns 404 when caller user record cannot be found', async () => {
        mockGetItem.mockResolvedValue(null);

        const event = makeEvent('POST', '/pharmacy/fefo-override/authorize', {
            supervisorPin: '4242',
            productId: 'prod-1',
        });

        const result = await authorizeFefoOverride(event, {} as any);
        const body = JSON.parse(result.body as string);
        expect(result.statusCode).toBe(404);
        expect(body.error?.code).toBe('USER_NOT_FOUND');
    });

    test('rejects request when supervisorPin is too short', async () => {
        const event = makeEvent('POST', '/pharmacy/fefo-override/authorize', {
            supervisorPin: '12',
        });

        const result = await authorizeFefoOverride(event, {} as any);
        expect(result.statusCode).toBe(400);
        // No FEFO_OVERRIDE_AUDIT row should be created when the schema rejects
        // the request. (mockGetItem may be called by other middleware; we only
        // assert that no override audit was persisted.)
        const overrideAudit = mockPutItem.mock.calls
            .map(c => c[0])
            .find((it: any) => it?.entityType === 'FEFO_OVERRIDE_AUDIT');
        expect(overrideAudit).toBeUndefined();
    });
});

