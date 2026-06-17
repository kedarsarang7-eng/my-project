// ============================================================================
// Pharmacy Batch Intake Tests
// ============================================================================
// Tests for POST /pharmacy/batch-intake handler.
//
// Test cases:
//   (a) New batch creation — creates MEDBATCH# + increments currentStock
//   (b) Duplicate batch — increments batchStock on existing MEDBATCH#
//   (c) Expired expiryDate — rejected by Zod schema
//   (d) Negative/zero costPrice — rejected by Zod schema
//   (e) Product not found — returns 404
//   (f) Multiple batches — creates/updates mixed in single transaction
//   (g) Zero-length batches array — rejected by Zod
//
// Run with: npx jest src/__tests__/pharmacy-batch-intake.test.ts --verbose
// ============================================================================

// ---- Mock DynamoDB ----
const mockGetItem = jest.fn().mockImplementation((pk, sk) => { console.log('getItem called with', pk, sk); return Promise.resolve(null); });
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

// ---- Mock Context / Logger / WS / Auth ----
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
    emitEvent: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: jest.fn().mockResolvedValue({
        sub: 'test-user-id',
        email: 'pharmacist@test.com',
        tenantId: 'test-tenant-id',
        role: 'owner',
        businessType: 'pharmacy',
    }),
}));
jest.mock('../middleware/plan-guard', () => ({
    validateFeatureAccess: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../middleware/cloudwatch-logger', () => ({
    logRequest: jest.fn().mockResolvedValue(undefined),
    logAuthFailure: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../middleware/software-lock', () => ({
    checkSoftwareLock: jest.fn().mockResolvedValue({ allowed: true, lockLevel: 'none', userMessage: '' }),
    withSoftwareLock: (handler: any) => handler,
    LockLevel: {
        NONE: 'none',
        WARNING: 'warning',
        PARTIAL: 'partial',
        FULL: 'full',
    },
}));

// ---- Constants ----
const TENANT_ID = 'test-tenant-id';
const PRODUCT_ID = 'a0a0a0a0-b1b1-4c2c-8d3d-e4e4e4e4e4e4';

// ---- Helpers ----

function futureDate(daysFromNow: number): string {
    const d = new Date();
    d.setDate(d.getDate() + daysFromNow);
    return d.toISOString().split('T')[0];
}

function pastDate(daysAgo: number): string {
    const d = new Date();
    d.setDate(d.getDate() - daysAgo);
    return d.toISOString().split('T')[0];
}

function makeProduct(overrides: Record<string, any> = {}) {
    return {
        PK: `TENANT#${TENANT_ID}`,
        SK: `PRODUCT#${PRODUCT_ID}`,
        id: PRODUCT_ID,
        name: 'Amoxicillin 500mg',
        currentStock: 100,
        salePriceCents: 8500,
        isDeleted: false,
        isService: false,
        ...overrides,
    };
}

function makeMockEvent(body: any): any {
    return {
        version: '2.0',
        routeKey: 'POST /pharmacy/batch-intake',
        rawPath: '/pharmacy/batch-intake',
        rawQueryString: '',
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
                method: 'POST',
                path: '/pharmacy/batch-intake',
                protocol: 'HTTP/1.1',
                sourceIp: '127.0.0.1',
                userAgent: 'jest',
            },
            requestId: 'test-req-001',
            routeKey: 'POST /pharmacy/batch-intake',
            stage: '$default',
            time: new Date().toISOString(),
            timeEpoch: Date.now(),
        },
        body: JSON.stringify(body),
        isBase64Encoded: false,
    };
}

// ---- Import after mocks ----
// NOTE: authorizedHandler returns APIGatewayProxyResultV2 which is a union type.
// In tests we always get the structured object form. Cast to 'any' for convenience.
import { batchIntake as _batchIntake } from '../handlers/pharmacy';

// Wrap handler to cast result to any for test convenience
async function batchIntake(event: any, context: any): Promise<any> {
    return _batchIntake(event, context);
}

// ============================================================================
// (a) NEW BATCH CREATION
// ============================================================================
describe('Batch Intake: New Batch Creation', () => {
    beforeEach(() => jest.clearAllMocks());

    test('should create MEDBATCH# record and increment product stock', async () => {
        const product = makeProduct();
        mockGetItem.mockResolvedValueOnce(product).mockResolvedValueOnce(product); // product lookup
        mockQueryItems.mockResolvedValueOnce({ items: [], lastKey: undefined }); // no existing batches
        mockTransactWrite.mockResolvedValueOnce(undefined);

        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'BATCH-2026-001',
                expiryDate: futureDate(365),
                quantityReceived: 50,
                costPricePaise: 3200,
                supplierName: 'PharmaDist Ltd',
                invoiceRef: 'INV-PD-1234',
            }],
        });

        const result = await batchIntake(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(201);
        expect(body.data.batchesCreated).toBe(1);
        expect(body.data.batchesUpdated).toBe(0);
        expect(body.data.newTotalStock).toBe(150); // 100 + 50
        expect(body.data.productId).toBe(PRODUCT_ID);
        expect(body.data.productName).toBe('Amoxicillin 500mg');

        // Verify transactWrite was called
        expect(mockTransactWrite).toHaveBeenCalledTimes(1);
        const txItems = mockTransactWrite.mock.calls[0][0];

        // Should have 2 items: Put for MEDBATCH# + Update for PRODUCT# stock
        expect(txItems).toHaveLength(2);

        // First item: Put for new MEDBATCH#
        const putOp = txItems.find((op: any) => op.Put);
        expect(putOp).toBeDefined();
        expect(putOp.Put.Item.SK).toBe(`MEDBATCH#${PRODUCT_ID}#BATCH-2026-001`);
        expect(putOp.Put.Item.batchStock).toBe(50);
        expect(putOp.Put.Item.costPricePaise).toBe(3200);
        expect(putOp.Put.Item.status).toBe('active');
        expect(putOp.Put.Item.supplierName).toBe('PharmaDist Ltd');
        expect(putOp.Put.Item.invoiceRef).toBe('INV-PD-1234');

        // Second item: Update to increment product currentStock
        const updateOp = txItems.find((op: any) =>
            op.Update?.Key?.SK === `PRODUCT#${PRODUCT_ID}`,
        );
        expect(updateOp).toBeDefined();
        expect(updateOp.Update.ExpressionAttributeValues[':totalQty']).toBe(50);
    });

    test('should create multiple batches in single transaction', async () => {
        const product = makeProduct();
        mockGetItem.mockResolvedValueOnce(product).mockResolvedValueOnce(product);
        mockQueryItems.mockResolvedValueOnce({ items: [], lastKey: undefined });
        mockTransactWrite.mockResolvedValueOnce(undefined);

        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [
                {
                    batchNumber: 'B1',
                    expiryDate: futureDate(180),
                    quantityReceived: 25,
                    costPricePaise: 2800,
                },
                {
                    batchNumber: 'B2',
                    expiryDate: futureDate(365),
                    quantityReceived: 75,
                    costPricePaise: 3100,
                },
            ],
        });

        const result = await batchIntake(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(201);
        expect(body.data.batchesCreated).toBe(2);
        expect(body.data.batchesUpdated).toBe(0);
        expect(body.data.newTotalStock).toBe(200); // 100 + 25 + 75

        // 2 Put ops + 1 Update op = 3 transactItems
        const txItems = mockTransactWrite.mock.calls[0][0];
        expect(txItems).toHaveLength(3);

        const putOps = txItems.filter((op: any) => op.Put);
        expect(putOps).toHaveLength(2);

        // Total stock update should be 100 (25+75)
        const stockUpdate = txItems.find((op: any) =>
            op.Update?.Key?.SK === `PRODUCT#${PRODUCT_ID}`,
        );
        expect(stockUpdate.Update.ExpressionAttributeValues[':totalQty']).toBe(100);
    });
});

// ============================================================================
// (b) DUPLICATE BATCH — INCREMENTS STOCK
// ============================================================================
describe('Batch Intake: Duplicate Batch Increments Stock', () => {
    beforeEach(() => jest.clearAllMocks());

    test('should increment batchStock when batch already exists', async () => {
        const product = makeProduct();
        mockGetItem.mockResolvedValueOnce(product).mockResolvedValueOnce(product);

        // Pre-existing batch
        mockQueryItems.mockResolvedValueOnce({
            items: [{
                PK: `TENANT#${TENANT_ID}`,
                SK: `MEDBATCH#${PRODUCT_ID}#BATCH-EXISTING`,
                batchNumber: 'BATCH-EXISTING',
                productId: PRODUCT_ID,
                batchStock: 30,
                expiryDate: futureDate(180),
                costPricePaise: 2500,
                status: 'active',
            }],
            lastKey: undefined,
        });

        mockTransactWrite.mockResolvedValueOnce(undefined);

        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'BATCH-EXISTING',
                expiryDate: futureDate(180),
                quantityReceived: 20,
                costPricePaise: 2600,
            }],
        });

        const result = await batchIntake(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(201);
        expect(body.data.batchesCreated).toBe(0);
        expect(body.data.batchesUpdated).toBe(1);
        expect(body.data.newTotalStock).toBe(120); // 100 + 20

        // Verify Update (not Put) was used for the batch
        const txItems = mockTransactWrite.mock.calls[0][0];
        const batchUpdate = txItems.find((op: any) =>
            op.Update?.Key?.SK === `MEDBATCH#${PRODUCT_ID}#BATCH-EXISTING`,
        );
        expect(batchUpdate).toBeDefined();
        expect(batchUpdate.Update.UpdateExpression).toContain('batchStock = batchStock + :qty');
        expect(batchUpdate.Update.ExpressionAttributeValues[':qty']).toBe(20);

        // Should NOT have a Put for the same batch
        const putOps = txItems.filter((op: any) =>
            op.Put?.Item?.batchNumber === 'BATCH-EXISTING',
        );
        expect(putOps).toHaveLength(0);
    });

    test('should reactivate depleted batch when restocked', async () => {
        const product = makeProduct();
        mockGetItem.mockResolvedValueOnce(product).mockResolvedValueOnce(product);

        // Pre-existing depleted batch
        mockQueryItems.mockResolvedValueOnce({
            items: [{
                PK: `TENANT#${TENANT_ID}`,
                SK: `MEDBATCH#${PRODUCT_ID}#BATCH-DEPLETED`,
                batchNumber: 'BATCH-DEPLETED',
                productId: PRODUCT_ID,
                batchStock: 0,
                expiryDate: futureDate(120),
                costPricePaise: 2000,
                status: 'depleted',
            }],
            lastKey: undefined,
        });

        mockTransactWrite.mockResolvedValueOnce(undefined);

        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'BATCH-DEPLETED',
                expiryDate: futureDate(120),
                quantityReceived: 10,
                costPricePaise: 2100,
            }],
        });

        const result = await batchIntake(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(201);
        expect(body.data.batchesUpdated).toBe(1);

        // Should have TWO updates for the batch: stock increment + status reactivation
        const txItems = mockTransactWrite.mock.calls[0][0];
        const batchOps = txItems.filter((op: any) =>
            op.Update?.Key?.SK === `MEDBATCH#${PRODUCT_ID}#BATCH-DEPLETED`,
        );
        expect(batchOps.length).toBe(2);

        // One of them should set status to 'active'
        const statusOp = batchOps.find((op: any) =>
            op.Update?.ExpressionAttributeValues?.[':active'] === 'active',
        );
        expect(statusOp).toBeDefined();
    });

    test('should handle mix of new and existing batches', async () => {
        const product = makeProduct();
        mockGetItem.mockResolvedValueOnce(product).mockResolvedValueOnce(product);

        mockQueryItems.mockResolvedValueOnce({
            items: [{
                PK: `TENANT#${TENANT_ID}`,
                SK: `MEDBATCH#${PRODUCT_ID}#OLD-BATCH`,
                batchNumber: 'OLD-BATCH',
                productId: PRODUCT_ID,
                batchStock: 15,
                expiryDate: futureDate(90),
                status: 'active',
            }],
            lastKey: undefined,
        });

        mockTransactWrite.mockResolvedValueOnce(undefined);

        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [
                { batchNumber: 'OLD-BATCH', expiryDate: futureDate(90), quantityReceived: 10, costPricePaise: 2000 },
                { batchNumber: 'BRAND-NEW', expiryDate: futureDate(365), quantityReceived: 40, costPricePaise: 3000 },
            ],
        });

        const result = await batchIntake(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(201);
        expect(body.data.batchesCreated).toBe(1);
        expect(body.data.batchesUpdated).toBe(1);
        expect(body.data.newTotalStock).toBe(150); // 100 + 10 + 40
    });
});

// ============================================================================
// (c) EXPIRED EXPIRY DATE — REJECTED
// ============================================================================
describe('Batch Intake: Expired Date Validation', () => {
    beforeEach(() => jest.clearAllMocks());

    test('should reject batch with past expiry date', async () => {
        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'BATCH-EXPIRED',
                expiryDate: pastDate(30),
                quantityReceived: 10,
                costPricePaise: 2000,
            }],
        });

        const result = await batchIntake(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(400);
        expect(body.success).toBe(false);
        // transactWrite should NOT have been called
        expect(mockTransactWrite).not.toHaveBeenCalled();
    });

    test('should reject batch with today as expiry date', async () => {
        const today = new Date().toISOString().split('T')[0];

        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'BATCH-TODAY',
                expiryDate: today,
                quantityReceived: 10,
                costPricePaise: 2000,
            }],
        });

        const result = await batchIntake(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(400);
        expect(body.success).toBe(false);
        expect(mockTransactWrite).not.toHaveBeenCalled();
    });

    test('should reject invalid date format', async () => {
        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'BATCH-BAD',
                expiryDate: '15/06/2027', // Wrong format
                quantityReceived: 10,
                costPricePaise: 2000,
            }],
        });

        const result = await batchIntake(event, {} as any);
        expect(result.statusCode).toBe(400);
        expect(mockTransactWrite).not.toHaveBeenCalled();
    });
});

// ============================================================================
// (d) NEGATIVE/ZERO COST PRICE — REJECTED
// ============================================================================
describe('Batch Intake: Cost Price Validation', () => {
    beforeEach(() => jest.clearAllMocks());

    test('should reject negative costPricePaise', async () => {
        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'BATCH-NEG',
                expiryDate: futureDate(180),
                quantityReceived: 10,
                costPricePaise: -500,
            }],
        });

        const result = await batchIntake(event, {} as any);
        expect(result.statusCode).toBe(400);
        expect(mockTransactWrite).not.toHaveBeenCalled();
    });

    test('should reject zero costPricePaise', async () => {
        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'BATCH-ZERO',
                expiryDate: futureDate(180),
                quantityReceived: 10,
                costPricePaise: 0,
            }],
        });

        const result = await batchIntake(event, {} as any);
        expect(result.statusCode).toBe(400);
        expect(mockTransactWrite).not.toHaveBeenCalled();
    });

    test('should reject negative quantityReceived', async () => {
        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'BATCH-NEG-QTY',
                expiryDate: futureDate(180),
                quantityReceived: -5,
                costPricePaise: 2000,
            }],
        });

        const result = await batchIntake(event, {} as any);
        expect(result.statusCode).toBe(400);
        expect(mockTransactWrite).not.toHaveBeenCalled();
    });

    test('should reject zero quantityReceived', async () => {
        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'BATCH-ZERO-QTY',
                expiryDate: futureDate(180),
                quantityReceived: 0,
                costPricePaise: 2000,
            }],
        });

        const result = await batchIntake(event, {} as any);
        expect(result.statusCode).toBe(400);
        expect(mockTransactWrite).not.toHaveBeenCalled();
    });
});

// ============================================================================
// (e) PRODUCT NOT FOUND — 404
// ============================================================================
describe('Batch Intake: Product Not Found', () => {
    beforeEach(() => jest.clearAllMocks());

    test('should return 404 when product does not exist', async () => {
        mockGetItem.mockResolvedValueOnce(null); // product not found

        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'BATCH-ORPHAN',
                expiryDate: futureDate(180),
                quantityReceived: 10,
                costPricePaise: 2000,
            }],
        });

        const result = await batchIntake(event, {} as any);
        const body = JSON.parse(result.body as string);

        expect(result.statusCode).toBe(404);
        expect(body.error.code).toBe('PRODUCT_NOT_FOUND');
        expect(mockTransactWrite).not.toHaveBeenCalled();
    });

    test('should return 404 when product is soft-deleted', async () => {
        mockGetItem.mockResolvedValueOnce(makeProduct({ isDeleted: true }));

        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'BATCH-DELETED',
                expiryDate: futureDate(180),
                quantityReceived: 10,
                costPricePaise: 2000,
            }],
        });

        const result = await batchIntake(event, {} as any);
        expect(result.statusCode).toBe(404);
        expect(mockTransactWrite).not.toHaveBeenCalled();
    });
});

// ============================================================================
// (f) EMPTY BATCHES ARRAY — REJECTED
// ============================================================================
describe('Batch Intake: Input Validation', () => {
    beforeEach(() => jest.clearAllMocks());

    test('should reject empty batches array', async () => {
        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [],
        });

        const result = await batchIntake(event, {} as any);
        expect(result.statusCode).toBe(400);
        expect(mockTransactWrite).not.toHaveBeenCalled();
    });

    test('should reject missing productId', async () => {
        const event = makeMockEvent({
            batches: [{
                batchNumber: 'B1',
                expiryDate: futureDate(180),
                quantityReceived: 10,
                costPricePaise: 2000,
            }],
        });

        const result = await batchIntake(event, {} as any);
        expect(result.statusCode).toBe(400);
    });

    test('should reject batchNumber exceeding 50 chars', async () => {
        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'A'.repeat(51),
                expiryDate: futureDate(180),
                quantityReceived: 10,
                costPricePaise: 2000,
            }],
        });

        const result = await batchIntake(event, {} as any);
        expect(result.statusCode).toBe(400);
    });

    test('should accept optional purchaseDate', async () => {
        const product = makeProduct();
        mockGetItem.mockResolvedValueOnce(product).mockResolvedValueOnce(product);
        mockQueryItems.mockResolvedValueOnce({ items: [], lastKey: undefined });
        mockTransactWrite.mockResolvedValueOnce(undefined);

        const event = makeMockEvent({
            productId: PRODUCT_ID,
            batches: [{
                batchNumber: 'B-DATED',
                expiryDate: futureDate(365),
                quantityReceived: 10,
                costPricePaise: 2000,
            }],
            purchaseDate: '2026-04-10',
        });

        const result = await batchIntake(event, {} as any);
        expect(result.statusCode).toBe(201);

        // Verify purchaseDate propagated to MEDBATCH# Put item
        const txItems = mockTransactWrite.mock.calls[0][0];
        const putOp = txItems.find((op: any) => op.Put);
        expect(putOp.Put.Item.purchaseDate).toBe('2026-04-10');
    });
});




