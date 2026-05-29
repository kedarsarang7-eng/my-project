// ============================================================================
// Narcotic Drug Register Tests
// ============================================================================
// Tests for:
//   POST /pharmacy/narcotic-register
//   GET  /pharmacy/narcotic-register
//   Invoice integration (Schedule X → NARCOTICLOG# in transactWrite)
//
// Test cases:
//   (a) POST: missing patient fields rejected
//   (b) POST: non-pharmacist role rejected (cashier/viewer blocked)
//   (c) GET: restricted to owner/manager only
//   (d) GET: date range filtering works correctly
//   (e) POST: invalid doctorRegNo format rejected
//   (f) POST: successful entry with all fields
//   (g) Integration: buildNarcoticLogTransactItem returns null on missing fields
//   (h) Integration: buildNarcoticLogTransactItem builds correct Put
//
// Run with: npx jest src/__tests__/narcotic-register.test.ts --verbose
// ============================================================================

// ---- Mock DynamoDB ----
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

// ---- Mock CloudWatch ----
jest.mock('@aws-sdk/client-cloudwatch', () => ({
    CloudWatchClient: jest.fn().mockImplementation(() => ({
        send: jest.fn().mockResolvedValue({}),
    })),
    PutMetricDataCommand: jest.fn(),
}));

// ---- Mock Context / Logger / WS / Auth ----
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

// Configurable auth mock — default to owner/pharmacy
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

// ---- Constants ----
const TENANT_ID = 'test-tenant-id';
const USER_ID = 'user-pharmacist-001';
const INVOICE_ID = 'inv-sched-x-001';

// ---- Auth Presets ----
function setAuth(role: string) {
    mockVerifyAuth.mockResolvedValue({
        sub: USER_ID,
        email: 'pharmacist@test.com',
        tenantId: TENANT_ID,
        role,
        businessType: 'pharmacy',
    });
}

// ---- Event Factories ----

function makePostEvent(body: any): any {
    return {
        version: '2.0',
        routeKey: 'POST /pharmacy/narcotic-register',
        rawPath: '/pharmacy/narcotic-register',
        rawQueryString: '',
        headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer mock-token',
        },
        requestContext: {
            accountId: 'local', apiId: 'local', domainName: 'localhost', domainPrefix: '',
            http: { method: 'POST', path: '/pharmacy/narcotic-register', protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'jest' },
            requestId: 'test-req-001', routeKey: 'POST /pharmacy/narcotic-register', stage: '$default',
            time: new Date().toISOString(), timeEpoch: Date.now(),
        },
        body: JSON.stringify(body),
        isBase64Encoded: false,
    };
}

function makeGetEvent(queryParams: Record<string, string> = {}): any {
    return {
        version: '2.0',
        routeKey: 'GET /pharmacy/narcotic-register',
        rawPath: '/pharmacy/narcotic-register',
        rawQueryString: new URLSearchParams(queryParams).toString(),
        headers: {
            'authorization': 'Bearer mock-token',
        },
        queryStringParameters: queryParams,
        requestContext: {
            accountId: 'local', apiId: 'local', domainName: 'localhost', domainPrefix: '',
            http: { method: 'GET', path: '/pharmacy/narcotic-register', protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'jest' },
            requestId: 'test-req-002', routeKey: 'GET /pharmacy/narcotic-register', stage: '$default',
            time: new Date().toISOString(), timeEpoch: Date.now(),
        },
        isBase64Encoded: false,
    };
}

function validNarcoticBody(overrides: Record<string, any> = {}) {
    return {
        patientName: 'Rajesh Kumar',
        patientAddress: '42 MG Road, Pune 411001',
        prescribingDoctorName: 'Dr. Sharma',
        doctorRegNo: 'MCI-12345',
        prescriptionId: 'RX-2026-04-001',
        drugName: 'Morphine Sulphate 10mg',
        quantitySold: 5,
        batchNumber: 'MORPH-B001',
        expiryDate: '2027-06-15',
        invoiceId: INVOICE_ID,
        ...overrides,
    };
}

// ---- Import after mocks ----
import { createNarcoticEntry as _createNarcoticEntry, getNarcoticRegister as _getNarcoticRegister, buildNarcoticLogTransactItem } from '../handlers/pharmacy';

async function createNarcoticEntry(event: any, context: any): Promise<any> {
    return _createNarcoticEntry(event, context);
}
async function getNarcoticRegister(event: any, context: any): Promise<any> {
    return _getNarcoticRegister(event, context);
}

// ============================================================================
// (a) POST — MISSING PATIENT FIELDS REJECTED
// ============================================================================
describe('Narcotic Register POST: Missing Fields', () => {
    beforeEach(() => { jest.clearAllMocks(); setAuth('owner'); });

    test('should reject missing patientName', async () => {
        const { patientName, ...body } = validNarcoticBody();

        const result = await createNarcoticEntry(makePostEvent(body), {} as any);
        expect(result.statusCode).toBe(400);
        expect(mockPutItem).not.toHaveBeenCalled();
    });

    test('should reject missing patientAddress', async () => {
        const { patientAddress, ...body } = validNarcoticBody();

        const result = await createNarcoticEntry(makePostEvent(body), {} as any);
        expect(result.statusCode).toBe(400);
        expect(mockPutItem).not.toHaveBeenCalled();
    });

    test('should reject missing prescribingDoctorName', async () => {
        const { prescribingDoctorName, ...body } = validNarcoticBody();

        const result = await createNarcoticEntry(makePostEvent(body), {} as any);
        expect(result.statusCode).toBe(400);
    });

    test('should reject missing doctorRegNo', async () => {
        const { doctorRegNo, ...body } = validNarcoticBody();

        const result = await createNarcoticEntry(makePostEvent(body), {} as any);
        expect(result.statusCode).toBe(400);
    });

    test('should reject missing prescriptionId', async () => {
        const { prescriptionId, ...body } = validNarcoticBody();

        const result = await createNarcoticEntry(makePostEvent(body), {} as any);
        expect(result.statusCode).toBe(400);
    });

    test('should reject missing drugName', async () => {
        const { drugName, ...body } = validNarcoticBody();

        const result = await createNarcoticEntry(makePostEvent(body), {} as any);
        expect(result.statusCode).toBe(400);
    });

    test('should reject missing batchNumber', async () => {
        const { batchNumber, ...body } = validNarcoticBody();

        const result = await createNarcoticEntry(makePostEvent(body), {} as any);
        expect(result.statusCode).toBe(400);
    });

    test('should reject missing invoiceId', async () => {
        const { invoiceId, ...body } = validNarcoticBody();

        const result = await createNarcoticEntry(makePostEvent(body), {} as any);
        expect(result.statusCode).toBe(400);
    });
});

// ============================================================================
// (b) POST — NON-PHARMACIST ROLE REJECTED
// ============================================================================
describe('Narcotic Register POST: Role Guard', () => {
    beforeEach(() => jest.clearAllMocks());

    test('should reject cashier role', async () => {
        setAuth('cashier');
        const result = await createNarcoticEntry(makePostEvent(validNarcoticBody()), {} as any);
        expect(result.statusCode).toBe(403);
        expect(mockPutItem).not.toHaveBeenCalled();
    });

    test('should reject viewer role', async () => {
        setAuth('viewer');
        const result = await createNarcoticEntry(makePostEvent(validNarcoticBody()), {} as any);
        expect(result.statusCode).toBe(403);
    });

    test('should reject accountant role', async () => {
        setAuth('accountant');
        const result = await createNarcoticEntry(makePostEvent(validNarcoticBody()), {} as any);
        expect(result.statusCode).toBe(403);
    });

    test('should allow owner role', async () => {
        setAuth('owner');
        const result = await createNarcoticEntry(makePostEvent(validNarcoticBody()), {} as any);
        expect(result.statusCode).toBe(201);
    });

    test('should allow manager role', async () => {
        setAuth('manager');
        const result = await createNarcoticEntry(makePostEvent(validNarcoticBody()), {} as any);
        expect(result.statusCode).toBe(201);
    });

    test('should allow staff (pharmacist) role', async () => {
        setAuth('staff');
        const result = await createNarcoticEntry(makePostEvent(validNarcoticBody()), {} as any);
        expect(result.statusCode).toBe(201);
    });
});

// ============================================================================
// (c) GET — RESTRICTED TO OWNER/MANAGER
// ============================================================================
describe('Narcotic Register GET: Role Guard', () => {
    beforeEach(() => jest.clearAllMocks());

    test('should reject staff role on GET', async () => {
        setAuth('staff');
        const result = await getNarcoticRegister(makeGetEvent(), {} as any);
        expect(result.statusCode).toBe(403);
    });

    test('should reject cashier role on GET', async () => {
        setAuth('cashier');
        const result = await getNarcoticRegister(makeGetEvent(), {} as any);
        expect(result.statusCode).toBe(403);
    });

    test('should reject viewer role on GET', async () => {
        setAuth('viewer');
        const result = await getNarcoticRegister(makeGetEvent(), {} as any);
        expect(result.statusCode).toBe(403);
    });

    test('should allow owner role on GET', async () => {
        setAuth('owner');
        mockQueryItems.mockResolvedValueOnce({ items: [], lastKey: undefined });

        const result = await getNarcoticRegister(makeGetEvent(), {} as any);
        expect(result.statusCode).toBe(200);
    });

    test('should allow manager role on GET', async () => {
        setAuth('manager');
        mockQueryItems.mockResolvedValueOnce({ items: [], lastKey: undefined });

        const result = await getNarcoticRegister(makeGetEvent(), {} as any);
        expect(result.statusCode).toBe(200);
    });
});

// ============================================================================
// (d) GET — DATE RANGE FILTERING
// ============================================================================
describe('Narcotic Register GET: Date Range Filter', () => {
    beforeEach(() => { jest.clearAllMocks(); setAuth('owner'); });

    test('should return entries within date range', async () => {
        mockQueryItems.mockResolvedValueOnce({
            items: [
                {
                    SK: `NARCOTICLOG#inv-1#2026-04-05T10:00:00.000Z`,
                    patientName: 'Patient A',
                    patientAddress: 'Addr A',
                    prescribingDoctorName: 'Dr A',
                    doctorRegNo: 'MCI-11111',
                    prescriptionId: 'RX-001',
                    drugName: 'Morphine',
                    scheduleType: 'X',
                    quantitySold: 3,
                    batchNumber: 'B1',
                    expiryDate: '2027-01-01',
                    dispensedBy: 'user-1',
                    dispensedAt: '2026-04-05T10:00:00.000Z',
                    invoiceId: 'inv-1',
                },
                {
                    SK: `NARCOTICLOG#inv-2#2026-04-10T14:00:00.000Z`,
                    patientName: 'Patient B',
                    patientAddress: 'Addr B',
                    prescribingDoctorName: 'Dr B',
                    doctorRegNo: 'MCI-22222',
                    prescriptionId: 'RX-002',
                    drugName: 'Codeine',
                    scheduleType: 'X',
                    quantitySold: 10,
                    batchNumber: 'B2',
                    expiryDate: '2027-06-15',
                    dispensedBy: 'user-1',
                    dispensedAt: '2026-04-10T14:00:00.000Z',
                    invoiceId: 'inv-2',
                },
            ],
            lastKey: undefined,
        });

        const result = await getNarcoticRegister(makeGetEvent({
            startDate: '2026-04-01',
            endDate: '2026-04-30',
        }), {} as any);

        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(200);
        expect(body.data).toHaveLength(2);
        // Should be sorted descending by dispensedAt
        expect(body.data[0].drugName).toBe('Codeine');
        expect(body.data[1].drugName).toBe('Morphine');
    });

    test('should return empty for no-match date range', async () => {
        mockQueryItems.mockResolvedValueOnce({ items: [], lastKey: undefined });

        const result = await getNarcoticRegister(makeGetEvent({
            startDate: '2020-01-01',
            endDate: '2020-12-31',
        }), {} as any);

        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(200);
        expect(body.data).toHaveLength(0);
        expect(body.meta.total).toBe(0);
    });

    test('should paginate results correctly', async () => {
        // Create 5 entries
        const entries = Array.from({ length: 5 }, (_, i) => ({
            SK: `NARCOTICLOG#inv-${i}#2026-04-${String(i + 1).padStart(2, '0')}T10:00:00.000Z`,
            patientName: `Patient ${i}`,
            patientAddress: `Address ${i}`,
            prescribingDoctorName: `Dr ${i}`,
            doctorRegNo: `MCI-${String(i + 10000)}`,
            prescriptionId: `RX-${i}`,
            drugName: `Drug ${i}`,
            scheduleType: 'X',
            quantitySold: i + 1,
            batchNumber: `B${i}`,
            expiryDate: '2027-01-01',
            dispensedBy: 'user-1',
            dispensedAt: `2026-04-${String(i + 1).padStart(2, '0')}T10:00:00.000Z`,
            invoiceId: `inv-${i}`,
        }));

        mockQueryItems.mockResolvedValueOnce({ items: entries, lastKey: undefined });

        const result = await getNarcoticRegister(makeGetEvent({
            page: '2',
            pageSize: '2',
        }), {} as any);

        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(200);
        expect(body.data).toHaveLength(2);
        expect(body.meta.total).toBe(5);
        expect(body.meta.page).toBe(2);
    });
});

// ============================================================================
// (e) POST — INVALID DOCTOR REG NO REJECTED
// ============================================================================
describe('Narcotic Register POST: Validation', () => {
    beforeEach(() => { jest.clearAllMocks(); setAuth('owner'); });

    test('should reject invalid doctorRegNo format', async () => {
        const result = await createNarcoticEntry(
            makePostEvent(validNarcoticBody({ doctorRegNo: 'abc123' })),
            {} as any,
        );
        expect(result.statusCode).toBe(400);
        expect(mockPutItem).not.toHaveBeenCalled();
    });

    test('should reject zero quantitySold', async () => {
        const result = await createNarcoticEntry(
            makePostEvent(validNarcoticBody({ quantitySold: 0 })),
            {} as any,
        );
        expect(result.statusCode).toBe(400);
    });

    test('should reject negative quantitySold', async () => {
        const result = await createNarcoticEntry(
            makePostEvent(validNarcoticBody({ quantitySold: -5 })),
            {} as any,
        );
        expect(result.statusCode).toBe(400);
    });

    test('should reject invalid expiryDate format', async () => {
        const result = await createNarcoticEntry(
            makePostEvent(validNarcoticBody({ expiryDate: '15/06/2027' })),
            {} as any,
        );
        expect(result.statusCode).toBe(400);
    });
});

// ============================================================================
// (f) POST — SUCCESSFUL ENTRY
// ============================================================================
describe('Narcotic Register POST: Successful Entry', () => {
    beforeEach(() => { jest.clearAllMocks(); setAuth('owner'); });

    test('should create NARCOTICLOG# record with all fields', async () => {
        const result = await createNarcoticEntry(
            makePostEvent(validNarcoticBody()),
            {} as any,
        );

        const body = JSON.parse(result.body);
        expect(result.statusCode).toBe(201);
        expect(body.data.drugName).toBe('Morphine Sulphate 10mg');
        expect(body.data.quantitySold).toBe(5);
        expect(body.data.patientName).toBe('Rajesh Kumar');
        expect(body.data.invoiceId).toBe(INVOICE_ID);

        // Verify putItem was called with correct NARCOTICLOG# record
        // (putItem may also be called by logAudit, so check >= 1)
        expect(mockPutItem).toHaveBeenCalled();
        const narcoticPutCall = mockPutItem.mock.calls.find(
            (call: any[]) => call[0]?.SK?.startsWith('NARCOTICLOG#'),
        );
        expect(narcoticPutCall).toBeDefined();
        const putCall = narcoticPutCall![0];
        expect(putCall.PK).toBe(`TENANT#${TENANT_ID}`);
        expect(putCall.SK).toMatch(/^NARCOTICLOG#inv-sched-x-001#/);
        expect(putCall.entityType).toBe('NARCOTIC_LOG');
        expect(putCall.patientName).toBe('Rajesh Kumar');
        expect(putCall.patientAddress).toBe('42 MG Road, Pune 411001');
        expect(putCall.prescribingDoctorName).toBe('Dr. Sharma');
        expect(putCall.doctorRegNo).toBe('MCI-12345');
        expect(putCall.prescriptionId).toBe('RX-2026-04-001');
        expect(putCall.scheduleType).toBe('X');
        expect(putCall.quantitySold).toBe(5);
        expect(putCall.batchNumber).toBe('MORPH-B001');
        expect(putCall.dispensedBy).toBe(USER_ID);
        expect(putCall.dispensedAt).toBeDefined();
    });
});

// ============================================================================
// (g) INTEGRATION — buildNarcoticLogTransactItem: missing fields → null
// ============================================================================
describe('buildNarcoticLogTransactItem', () => {
    test('should return null when patientName is missing', () => {
        const result = buildNarcoticLogTransactItem({
            tenantId: TENANT_ID,
            invoiceId: 'inv-001',
            productName: 'Morphine',
            quantitySold: 5,
            batchNumber: 'B1',
            expiryDate: '2027-01-01',
            dispensedBy: 'user-1',
            metadata: {
                // patientName missing
                patientAddress: '42 MG Road',
                doctorName: 'Dr. Sharma',
                doctorRegNo: 'MCI-12345',
                prescriptionId: 'RX-001',
            },
        });
        expect(result).toBeNull();
    });

    test('should return null when patientAddress is missing', () => {
        const result = buildNarcoticLogTransactItem({
            tenantId: TENANT_ID,
            invoiceId: 'inv-001',
            productName: 'Morphine',
            quantitySold: 5,
            batchNumber: 'B1',
            expiryDate: '2027-01-01',
            dispensedBy: 'user-1',
            metadata: {
                patientName: 'Rajesh',
                // patientAddress missing
                doctorName: 'Dr. Sharma',
                doctorRegNo: 'MCI-12345',
                prescriptionId: 'RX-001',
            },
        });
        expect(result).toBeNull();
    });

    test('should return null when doctorRegNo is missing', () => {
        const result = buildNarcoticLogTransactItem({
            tenantId: TENANT_ID,
            invoiceId: 'inv-001',
            productName: 'Morphine',
            quantitySold: 5,
            batchNumber: 'B1',
            expiryDate: '2027-01-01',
            dispensedBy: 'user-1',
            metadata: {
                patientName: 'Rajesh',
                patientAddress: '42 MG Road',
                doctorName: 'Dr. Sharma',
                // doctorRegNo missing
                prescriptionId: 'RX-001',
            },
        });
        expect(result).toBeNull();
    });

    // (h) Successful build
    test('should build correct Put transactItem with all fields', () => {
        const result = buildNarcoticLogTransactItem({
            tenantId: TENANT_ID,
            invoiceId: 'inv-001',
            productName: 'Morphine Sulphate 10mg',
            quantitySold: 5,
            batchNumber: 'MORPH-B001',
            expiryDate: '2027-06-15',
            dispensedBy: 'user-pharmacist-001',
            metadata: {
                patientName: 'Rajesh Kumar',
                patientAddress: '42 MG Road, Pune 411001',
                doctorName: 'Dr. Sharma',
                doctorRegNo: 'MCI-12345',
                prescriptionId: 'RX-2026-04-001',
            },
        });

        expect(result).not.toBeNull();
        expect(result!.Put).toBeDefined();

        const item = result!.Put.Item;
        expect(item.PK).toBe(`TENANT#${TENANT_ID}`);
        expect(item.SK).toMatch(/^NARCOTICLOG#inv-001#/);
        expect(item.entityType).toBe('NARCOTIC_LOG');
        expect(item.patientName).toBe('Rajesh Kumar');
        expect(item.patientAddress).toBe('42 MG Road, Pune 411001');
        expect(item.prescribingDoctorName).toBe('Dr. Sharma');
        expect(item.doctorRegNo).toBe('MCI-12345');
        expect(item.prescriptionId).toBe('RX-2026-04-001');
        expect(item.drugName).toBe('Morphine Sulphate 10mg');
        expect(item.scheduleType).toBe('X');
        expect(item.quantitySold).toBe(5);
        expect(item.batchNumber).toBe('MORPH-B001');
        expect(item.expiryDate).toBe('2027-06-15');
        expect(item.dispensedBy).toBe('user-pharmacist-001');
        expect(item.invoiceId).toBe('inv-001');
        expect(item.dispensedAt).toBeDefined();
    });

    test('should accept doctorName OR prescribingDoctorName', () => {
        const result = buildNarcoticLogTransactItem({
            tenantId: TENANT_ID,
            invoiceId: 'inv-001',
            productName: 'Codeine',
            quantitySold: 10,
            batchNumber: 'B1',
            expiryDate: '2027-01-01',
            dispensedBy: 'user-1',
            metadata: {
                patientName: 'Test',
                patientAddress: 'Test Address',
                prescribingDoctorName: 'Dr. Verma', // using prescribingDoctorName instead of doctorName
                doctorRegNo: 'DMC-56789',
                prescriptionId: 'RX-002',
            },
        });

        expect(result).not.toBeNull();
        expect(result!.Put.Item.prescribingDoctorName).toBe('Dr. Verma');
    });

    test('should default batchNumber to N/A when null', () => {
        const result = buildNarcoticLogTransactItem({
            tenantId: TENANT_ID,
            invoiceId: 'inv-001',
            productName: 'Drug',
            quantitySold: 1,
            batchNumber: null,
            expiryDate: null,
            dispensedBy: 'user-1',
            metadata: {
                patientName: 'Test',
                patientAddress: 'Addr',
                doctorName: 'Dr. X',
                doctorRegNo: 'MCI-99999',
                prescriptionId: 'RX-003',
            },
        });

        expect(result!.Put.Item.batchNumber).toBe('N/A');
        expect(result!.Put.Item.expiryDate).toBe('N/A');
    });
});
