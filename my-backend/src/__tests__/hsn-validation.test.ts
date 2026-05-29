// ============================================================================
// HSN → GST Slab Validation Tests
// ============================================================================
// Tests for the HSN/GST rate validation layer:
//   (a) Correct rate passes validation
//   (b) Wrong rate returns 422 with expected rates
//   (c) Unknown HSN passes with warning
//   (d) Exempted HSN with non-zero rate rejected
//   (e) Hierarchical fallback (8-digit → 4-digit)
//   (f) Inventory create integration returns 422 on mismatch
//
// Run with: npx jest src/__tests__/hsn-validation.test.ts --verbose
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';

// ---- Mock Auth ----
const mockVerifyAuth = jest.fn().mockResolvedValue({
    sub: 'test-user-id',
    email: 'test@example.com',
    tenantId: 'test-tenant-id',
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
        hsnMasterPK: () => 'HSNMASTER',
        hsnMasterSK: (code: string) => `HSN#${code}`,
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

// ---- Mock Context / CloudWatch / WebSocket ----
jest.mock('../utils/context', () => ({
    getTenantId: () => 'test-tenant-id',
    getCorrelationId: () => 'test-corr-id',
    getUserId: () => 'test-user-id',
    runWithContext: (_ctx: any, fn: any) => fn(),
    contextStorage: { run: (_ctx: any, fn: any) => fn() },
}));

const mockCloudWatchSend = jest.fn().mockResolvedValue({});
jest.mock('@aws-sdk/client-cloudwatch', () => ({
    CloudWatchClient: jest.fn().mockImplementation(() => ({
        send: mockCloudWatchSend,
    })),
    PutMetricDataCommand: jest.fn().mockImplementation((params: any) => params),
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

// ---- Test Constants ----
const TENANT_ID = 'test-tenant-id';

// ---- HSN Master Records ----
function makeHsnMasterRecord(overrides: Record<string, any> = {}) {
    return {
        PK: 'HSNMASTER',
        SK: `HSN#${overrides.hsnCode || '8517'}`,
        entityType: 'HSN_MASTER',
        hsnCode: '8517',
        description: 'Telephone sets incl. smartphones, mobile phones',
        cgstRateBp: 600,
        sgstRateBp: 600,
        igstRateBp: 1200,
        exempted: false,
        effectiveFrom: '2020-04-01',
        createdAt: '2026-01-01T00:00:00.000Z',
        updatedAt: '2026-01-01T00:00:00.000Z',
        ...overrides,
    };
}

function makeExemptedHsnRecord(overrides: Record<string, any> = {}) {
    return makeHsnMasterRecord({
        hsnCode: '4901',
        SK: 'HSN#4901',
        description: 'Printed books, brochures, leaflets',
        cgstRateBp: 0,
        sgstRateBp: 0,
        igstRateBp: 0,
        exempted: true,
        effectiveFrom: '2017-07-01',
        ...overrides,
    });
}

// ============================================================================
// Import the service (after mocks are set up)
// ============================================================================

import { validateHsnGstRate } from '../services/hsn.validator';

// ============================================================================
// TEST SUITE: HSN → GST RATE VALIDATION
// ============================================================================

describe('HSN → GST Rate Validation Service', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    // ================================================================
    // (a) Correct rate passes validation
    // ================================================================
    describe('Correct GST Rate Validation', () => {
        test('should return valid when CGST/SGST rates match HSN master (mobile phone 12%)', async () => {
            const hsnRecord = makeHsnMasterRecord();
            // Mock: exact getItem call returns the HSN master record
            mockGetItem.mockResolvedValueOnce(hsnRecord);

            const result = await validateHsnGstRate('8517', 600, 600);

            expect(result.valid).toBe(true);
            expect(result.found).toBe(true);
            expect(result.hsnCode).toBe('8517');
            expect(result.expected?.cgstRateBp).toBe(600);
            expect(result.expected?.sgstRateBp).toBe(600);
        });

        test('should return valid for 0% rate on exempted item (books)', async () => {
            const hsnRecord = makeExemptedHsnRecord();
            mockGetItem.mockResolvedValueOnce(hsnRecord);

            const result = await validateHsnGstRate('4901', 0, 0);

            expect(result.valid).toBe(true);
            expect(result.found).toBe(true);
            expect(result.exempted).toBe(true);
        });

        test('should return valid for pharma product with correct 12% rate', async () => {
            const hsnRecord = makeHsnMasterRecord({
                hsnCode: '3004',
                SK: 'HSN#3004',
                description: 'Medicaments – mixed, in measured doses or for retail',
                cgstRateBp: 600,
                sgstRateBp: 600,
                igstRateBp: 1200,
            });
            mockGetItem.mockResolvedValueOnce(hsnRecord);

            const result = await validateHsnGstRate('3004', 600, 600);

            expect(result.valid).toBe(true);
            expect(result.found).toBe(true);
        });
    });

    // ================================================================
    // (b) Wrong rate returns validation failure with expected rates
    // ================================================================
    describe('Rate Mismatch Detection', () => {
        test('should return invalid when CGST rate does not match (18% submitted for 12% item)', async () => {
            const hsnRecord = makeHsnMasterRecord(); // 8517 = 12% (600bp + 600bp)
            mockGetItem.mockResolvedValueOnce(hsnRecord);

            const result = await validateHsnGstRate('8517', 900, 900);

            expect(result.valid).toBe(false);
            expect(result.found).toBe(true);
            expect(result.hsnCode).toBe('8517');
            expect(result.expected?.cgstRateBp).toBe(600);
            expect(result.expected?.sgstRateBp).toBe(600);
            expect(result.submitted?.cgstRateBp).toBe(900);
            expect(result.submitted?.sgstRateBp).toBe(900);
            expect(result.message).toContain('mismatch');
        });

        test('should return invalid when only SGST rate mismatches', async () => {
            const hsnRecord = makeHsnMasterRecord();
            mockGetItem.mockResolvedValueOnce(hsnRecord);

            const result = await validateHsnGstRate('8517', 600, 900); // correct CGST, wrong SGST

            expect(result.valid).toBe(false);
            expect(result.expected?.cgstRateBp).toBe(600);
            expect(result.expected?.sgstRateBp).toBe(600);
            expect(result.submitted?.sgstRateBp).toBe(900);
        });

        test('should return invalid when computer rated at 5% instead of 18%', async () => {
            const hsnRecord = makeHsnMasterRecord({
                hsnCode: '8471',
                SK: 'HSN#8471',
                description: 'Automatic data processing machines (computers, laptops)',
                cgstRateBp: 900,
                sgstRateBp: 900,
                igstRateBp: 1800,
            });
            mockGetItem.mockResolvedValueOnce(hsnRecord);

            const result = await validateHsnGstRate('8471', 250, 250); // 5% submitted for 18% item

            expect(result.valid).toBe(false);
            expect(result.expected?.cgstRateBp).toBe(900);
            expect(result.submitted?.cgstRateBp).toBe(250);
        });
    });

    // ================================================================
    // (c) Unknown HSN passes with warning + CloudWatch metric
    // ================================================================
    describe('Unknown HSN Handling', () => {
        test('should allow unknown HSN code with found=false', async () => {
            // All getItem calls return null (HSN not found at any level)
            mockGetItem.mockResolvedValue(null);

            const result = await validateHsnGstRate('9999', 900, 900);

            expect(result.valid).toBe(true);
            expect(result.found).toBe(false);
            expect(result.hsnCode).toBe('9999');
            expect(result.message).toContain('not found in master table');
        });

        test('should emit CloudWatch UnknownHSN metric for unknown codes', async () => {
            mockGetItem.mockResolvedValue(null);

            await validateHsnGstRate('7777', 500, 500);

            // Wait for the fire-and-forget metric emission
            await new Promise(resolve => setTimeout(resolve, 50));

            expect(mockCloudWatchSend).toHaveBeenCalled();
        });

        test('should skip validation and return valid when no HSN code provided', async () => {
            const result = await validateHsnGstRate('', 900, 900);

            expect(result.valid).toBe(true);
            expect(result.found).toBe(false);
            expect(mockGetItem).not.toHaveBeenCalled();
        });
    });

    // ================================================================
    // (d) Exempted HSN with non-zero rate rejected
    // ================================================================
    describe('Exempted HSN Enforcement', () => {
        test('should reject non-zero CGST/SGST rates for exempted HSN (books)', async () => {
            const hsnRecord = makeExemptedHsnRecord();
            mockGetItem.mockResolvedValueOnce(hsnRecord);

            const result = await validateHsnGstRate('4901', 250, 250); // 5% on exempt item

            expect(result.valid).toBe(false);
            expect(result.exempted).toBe(true);
            expect(result.expected?.cgstRateBp).toBe(0);
            expect(result.expected?.sgstRateBp).toBe(0);
            expect(result.submitted?.cgstRateBp).toBe(250);
            expect(result.message).toContain('GST-exempt');
        });

        test('should reject when only CGST is non-zero on exempted item', async () => {
            const hsnRecord = makeExemptedHsnRecord();
            mockGetItem.mockResolvedValueOnce(hsnRecord);

            const result = await validateHsnGstRate('4901', 100, 0);

            expect(result.valid).toBe(false);
            expect(result.exempted).toBe(true);
        });

        test('should accept 0% rates on exempted HSN (cereals)', async () => {
            const hsnRecord = makeHsnMasterRecord({
                hsnCode: '1001',
                SK: 'HSN#1001',
                description: 'Wheat and meslin',
                cgstRateBp: 0,
                sgstRateBp: 0,
                igstRateBp: 0,
                exempted: true,
            });
            mockGetItem.mockResolvedValueOnce(hsnRecord);

            const result = await validateHsnGstRate('1001', 0, 0);

            expect(result.valid).toBe(true);
            expect(result.exempted).toBe(true);
        });
    });

    // ================================================================
    // (e) Hierarchical fallback: 8-digit → 6-digit → 4-digit
    // ================================================================
    describe('Hierarchical HSN Fallback', () => {
        test('should fall back from 8-digit to 4-digit HSN when exact match not found', async () => {
            // First call (exact 8-digit): not found
            mockGetItem.mockResolvedValueOnce(null);
            // Second call (6-digit): not found
            mockGetItem.mockResolvedValueOnce(null);
            // Third call (4-digit): found!
            mockGetItem.mockResolvedValueOnce(makeHsnMasterRecord({
                hsnCode: '8517',
                description: 'Telephone sets incl. smartphones',
                cgstRateBp: 600,
                sgstRateBp: 600,
            }));

            const result = await validateHsnGstRate('85171200', 600, 600);

            expect(result.valid).toBe(true);
            expect(result.found).toBe(true);
            // Verify the hierarchical fallback was attempted
            expect(mockGetItem).toHaveBeenCalledTimes(3);
            // First call: exact 8-digit
            expect(mockGetItem).toHaveBeenNthCalledWith(1, 'HSNMASTER', 'HSN#85171200');
            // Second call: 6-digit prefix
            expect(mockGetItem).toHaveBeenNthCalledWith(2, 'HSNMASTER', 'HSN#851712');
            // Third call: 4-digit prefix
            expect(mockGetItem).toHaveBeenNthCalledWith(3, 'HSNMASTER', 'HSN#8517');
        });

        test('should match at 6-digit level when 8-digit not found', async () => {
            // Exact 8-digit: not found
            mockGetItem.mockResolvedValueOnce(null);
            // 6-digit prefix: found!
            mockGetItem.mockResolvedValueOnce(makeHsnMasterRecord({
                hsnCode: '300490',
                description: 'Other medicaments – OTC drugs, tablets, syrups',
                cgstRateBp: 600,
                sgstRateBp: 600,
            }));

            const result = await validateHsnGstRate('30049099', 600, 600);

            expect(result.valid).toBe(true);
            expect(result.found).toBe(true);
            expect(mockGetItem).toHaveBeenCalledTimes(2);
        });

        test('should not attempt fallback for 4-digit codes (no shorter prefix)', async () => {
            mockGetItem.mockResolvedValueOnce(null); // Exact 4-digit: not found

            const result = await validateHsnGstRate('9999', 500, 500);

            expect(result.valid).toBe(true);
            expect(result.found).toBe(false);
            // Only one call — no fallback for 4-digit codes
            expect(mockGetItem).toHaveBeenCalledTimes(1);
        });
    });
});

// ============================================================================
// TEST SUITE: INVENTORY HANDLER INTEGRATION
// ============================================================================

describe('Inventory Handler — HSN/GST Validation Integration', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({});
    });

    // Import handler after mocks
    const { createItem } = require('../handlers/inventory');

    function makeApiEvent(body: Record<string, any>): APIGatewayProxyEventV2 {
        return {
            version: '2.0',
            routeKey: 'POST /inventory',
            rawPath: '/inventory',
            rawQueryString: '',
            headers: {
                'content-type': 'application/json',
                authorization: 'Bearer test-token',
            },
            requestContext: {
                accountId: '123456789',
                apiId: 'test-api',
                domainName: 'test.execute-api.ap-south-1.amazonaws.com',
                domainPrefix: 'test',
                http: {
                    method: 'POST',
                    path: '/inventory',
                    protocol: 'HTTP/1.1',
                    sourceIp: '127.0.0.1',
                    userAgent: 'test',
                },
                requestId: 'test-req-id',
                routeKey: 'POST /inventory',
                stage: '$default',
                time: '2026-04-11T00:00:00Z',
                timeEpoch: Date.now(),
            },
            body: JSON.stringify(body),
            isBase64Encoded: false,
        } as unknown as APIGatewayProxyEventV2;
    }

    const mockContext: Context = {
        callbackWaitsForEmptyEventLoop: false,
        functionName: 'test',
        functionVersion: '1',
        invokedFunctionArn: 'arn:aws:lambda:test',
        memoryLimitInMB: '256',
        awsRequestId: 'test-req-id',
        logGroupName: 'test',
        logStreamName: 'test',
        getRemainingTimeInMillis: () => 10000,
        done: () => {},
        fail: () => {},
        succeed: () => {},
    };

    test('should return 422 when creating inventory with mismatched HSN/GST rate', async () => {
        // Mock HSN master lookup: 8517 → 12% (600bp + 600bp)
        mockGetItem.mockResolvedValueOnce(makeHsnMasterRecord());

        const event = makeApiEvent({
            name: 'Samsung Galaxy S25',
            hsnCode: '8517',
            salePriceCents: 7999900,
            cgstRateBp: 900,  // Wrong! Should be 600 (12%, not 18%)
            sgstRateBp: 900,
        });

        const result = await createItem(event, mockContext);
        const body = JSON.parse(result.body);

        expect(result.statusCode).toBe(422);
        expect(body.error.code).toBe('HSN_GST_MISMATCH');
        expect(body.error.details.expectedCgstRateBp).toBe(600);
        expect(body.error.details.submittedCgstRateBp).toBe(900);
    });

    test('should allow inventory creation when HSN/GST rates match', async () => {
        // Mock HSN master lookup: 8517 → 12% (600bp + 600bp)
        mockGetItem.mockResolvedValueOnce(makeHsnMasterRecord());
        // Mock: barcode uniqueness check (no match)
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
        // Mock: putItem success
        mockPutItem.mockResolvedValue(undefined);

        const event = makeApiEvent({
            name: 'iPhone 16 Pro',
            hsnCode: '8517',
            salePriceCents: 13499900,
            cgstRateBp: 600,  // Correct!
            sgstRateBp: 600,
        });

        const result = await createItem(event, mockContext);
        const body = JSON.parse(result.body);

        expect(result.statusCode).toBe(201);
        expect(body.data.name).toBe('iPhone 16 Pro');
    });

    test('should allow inventory creation without HSN code (no validation)', async () => {
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
        mockPutItem.mockResolvedValue(undefined);

        const event = makeApiEvent({
            name: 'Generic Widget',
            salePriceCents: 5000,
            cgstRateBp: 900,
            sgstRateBp: 900,
            // No hsnCode — validation skipped
        });

        const result = await createItem(event, mockContext);

        expect(result.statusCode).toBe(201);
        // getItem should NOT be called for HSN lookup since no HSN code
        expect(mockGetItem).not.toHaveBeenCalledWith('HSNMASTER', expect.any(String));
    });
});
