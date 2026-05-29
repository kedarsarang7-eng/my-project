// ============================================================================
// Pharmacy FIFO Batch Consumption Tests
// ============================================================================
// Tests for server-side FIFO batch stock deduction in the pharmacy vertical.
//
// Test cases:
//   (a) Single batch full deduction
//   (b) Multi-batch partial deduction (FIFO order — oldest expiry first)
//   (c) Insufficient stock error
//   (d) Expired batch rejection (excluded from FIFO)
//   (e) Depleted batch status transition
//   (f) Integration: pharmacy invoice creates batch deduction ops
//   (g) Non-pharmacy invoice does NOT trigger FIFO
//
// Run with: npx jest src/__tests__/pharmacy-fifo-batch.test.ts --verbose
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

// ---- Mock Context / Logger / WS ----
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

// ---- Constants ----
const TENANT_ID = 'test-tenant-id';
const USER_ID = 'test-user-id';

// ---- Helpers ----

function makeMedBatch(overrides: Record<string, any> = {}) {
    return {
        PK: `TENANT#${TENANT_ID}`,
        SK: `MEDBATCH#prod-med-001#BATCH-A`,
        batchNumber: 'BATCH-A',
        productId: 'prod-med-001',
        productName: 'Amoxicillin 250mg',
        expiryDate: '2027-06-15',
        batchStock: 50,
        costPricePaise: 2500,
        status: 'active',
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-01T00:00:00Z',
        ...overrides,
    };
}

function makePharmacyProduct(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-med-001',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-med-001',
        name: 'Amoxicillin 250mg',
        salePriceCents: 7800,
        currentStock: 100,
        lowStockThreshold: 5,
        cgstRateBp: 600,
        sgstRateBp: 600,
        isDeleted: false,
        isService: false,
        unit: 'strip',
        hsnCode: '30049099',
        attributes: {},
        ...overrides,
    };
}

// Future expiry date (safe for tests)
function futureDate(daysFromNow: number): string {
    const d = new Date();
    d.setDate(d.getDate() + daysFromNow);
    return d.toISOString().split('T')[0];
}

// Past expiry date
function pastDate(daysAgo: number): string {
    const d = new Date();
    d.setDate(d.getDate() - daysAgo);
    return d.toISOString().split('T')[0];
}

// ---- Import after mocks ----
import {
    deductBatchesFIFO,
    InsufficientBatchStockError,
    medBatchSK,
} from '../services/pharmacy-batch.service';
import * as invoiceService from '../services/invoice.service';

// ============================================================================
// (a) SINGLE BATCH FULL DEDUCTION
// ============================================================================
describe('FIFO: Single Batch Full Deduction', () => {
    beforeEach(() => jest.clearAllMocks());

    test('should deduct entire quantity from a single batch', async () => {
        const batch = makeMedBatch({
            batchStock: 30,
            expiryDate: futureDate(180),
        });

        mockQueryItems.mockResolvedValueOnce({ items: [batch], lastKey: undefined });

        const result = await deductBatchesFIFO(
            TENANT_ID, 'prod-med-001', 'Amoxicillin 250mg', 10, new Date().toISOString(),
        );

        expect(result.totalDeducted).toBe(10);
        expect(result.operations).toHaveLength(1);
        expect(result.operations[0].batchNumber).toBe('BATCH-A');
        expect(result.operations[0].deductedQty).toBe(10);
        expect(result.operations[0].remainingStock).toBe(20);
        expect(result.operations[0].wasDepleted).toBe(false);
    });

    test('should mark batch as depleted when fully consumed', async () => {
        const batch = makeMedBatch({
            batchStock: 10,
            expiryDate: futureDate(180),
        });

        mockQueryItems.mockResolvedValueOnce({ items: [batch], lastKey: undefined });

        const result = await deductBatchesFIFO(
            TENANT_ID, 'prod-med-001', 'Amoxicillin 250mg', 10, new Date().toISOString(),
        );

        expect(result.operations).toHaveLength(1);
        expect(result.operations[0].remainingStock).toBe(0);
        expect(result.operations[0].wasDepleted).toBe(true);
        expect(result.batchesDepleted).toBe(1);

        // Verify the DynamoDB update expression sets status to 'depleted'
        const updateExpr = result.operations[0].transactItem.Update.UpdateExpression;
        expect(updateExpr).toContain('#batchStatus = :depleted');
    });
});

// ============================================================================
// (b) MULTI-BATCH PARTIAL DEDUCTION (FIFO ORDER)
// ============================================================================
describe('FIFO: Multi-Batch Partial Deduction', () => {
    beforeEach(() => jest.clearAllMocks());

    test('should consume oldest batch first, then move to next', async () => {
        const batchOld = makeMedBatch({
            SK: 'MEDBATCH#prod-med-001#BATCH-OLD',
            batchNumber: 'BATCH-OLD',
            batchStock: 5,
            expiryDate: futureDate(30),   // Expires soonest → consumed first
            costPricePaise: 2000,
        });
        const batchNew = makeMedBatch({
            SK: 'MEDBATCH#prod-med-001#BATCH-NEW',
            batchNumber: 'BATCH-NEW',
            batchStock: 20,
            expiryDate: futureDate(365),  // Expires latest → consumed last
            costPricePaise: 2800,
        });

        // Return in WRONG order to verify sorting works
        mockQueryItems.mockResolvedValueOnce({
            items: [batchNew, batchOld],
            lastKey: undefined,
        });

        const result = await deductBatchesFIFO(
            TENANT_ID, 'prod-med-001', 'Amoxicillin 250mg', 8, new Date().toISOString(),
        );

        expect(result.totalDeducted).toBe(8);
        expect(result.operations).toHaveLength(2);

        // First operation should be the OLD batch (FIFO: oldest expiry first)
        expect(result.operations[0].batchNumber).toBe('BATCH-OLD');
        expect(result.operations[0].deductedQty).toBe(5);  // All 5 consumed
        expect(result.operations[0].wasDepleted).toBe(true);

        // Second operation should be the NEW batch
        expect(result.operations[1].batchNumber).toBe('BATCH-NEW');
        expect(result.operations[1].deductedQty).toBe(3);  // Only 3 needed
        expect(result.operations[1].wasDepleted).toBe(false);
        expect(result.operations[1].remainingStock).toBe(17);

        // COGS: (5 × 2000) + (3 × 2800) = 10000 + 8400 = 18400
        expect(result.cogsPaise).toBe(18400);
        expect(result.batchesDepleted).toBe(1);
    });

    test('should handle three batches with ascending expiry dates', async () => {
        const batches = [
            makeMedBatch({
                SK: 'MEDBATCH#prod-med-001#B1', batchNumber: 'B1',
                batchStock: 3, expiryDate: futureDate(10), costPricePaise: 1000,
            }),
            makeMedBatch({
                SK: 'MEDBATCH#prod-med-001#B2', batchNumber: 'B2',
                batchStock: 5, expiryDate: futureDate(60), costPricePaise: 1200,
            }),
            makeMedBatch({
                SK: 'MEDBATCH#prod-med-001#B3', batchNumber: 'B3',
                batchStock: 10, expiryDate: futureDate(180), costPricePaise: 1500,
            }),
        ];

        mockQueryItems.mockResolvedValueOnce({ items: batches, lastKey: undefined });

        // Request 10: should take 3 from B1 (depleted), 5 from B2 (depleted), 2 from B3
        const result = await deductBatchesFIFO(
            TENANT_ID, 'prod-med-001', 'Test Drug', 10, new Date().toISOString(),
        );

        expect(result.operations).toHaveLength(3);
        expect(result.operations[0].batchNumber).toBe('B1');
        expect(result.operations[0].deductedQty).toBe(3);
        expect(result.operations[0].wasDepleted).toBe(true);

        expect(result.operations[1].batchNumber).toBe('B2');
        expect(result.operations[1].deductedQty).toBe(5);
        expect(result.operations[1].wasDepleted).toBe(true);

        expect(result.operations[2].batchNumber).toBe('B3');
        expect(result.operations[2].deductedQty).toBe(2);
        expect(result.operations[2].wasDepleted).toBe(false);
        expect(result.operations[2].remainingStock).toBe(8);

        expect(result.batchesDepleted).toBe(2);
        // COGS: (3×1000) + (5×1200) + (2×1500) = 3000 + 6000 + 3000 = 12000
        expect(result.cogsPaise).toBe(12000);
    });
});

// ============================================================================
// (c) INSUFFICIENT STOCK ERROR
// ============================================================================
describe('FIFO: Insufficient Batch Stock', () => {
    beforeEach(() => jest.clearAllMocks());

    test('should throw InsufficientBatchStockError when no batches exist', async () => {
        mockQueryItems.mockResolvedValueOnce({ items: [], lastKey: undefined });

        await expect(
            deductBatchesFIFO(TENANT_ID, 'prod-med-001', 'Amoxicillin 250mg', 5, new Date().toISOString()),
        ).rejects.toThrow(InsufficientBatchStockError);
    });

    test('should throw InsufficientBatchStockError when total batch stock < requested', async () => {
        const batch = makeMedBatch({
            batchStock: 3,
            expiryDate: futureDate(180),
        });

        mockQueryItems.mockResolvedValueOnce({ items: [batch], lastKey: undefined });

        try {
            await deductBatchesFIFO(
                TENANT_ID, 'prod-med-001', 'Amoxicillin 250mg', 10, new Date().toISOString(),
            );
            fail('Should have thrown InsufficientBatchStockError');
        } catch (err) {
            expect(err).toBeInstanceOf(InsufficientBatchStockError);
            const e = err as InsufficientBatchStockError;
            expect(e.productId).toBe('prod-med-001');
            expect(e.requestedQty).toBe(10);
            expect(e.availableQty).toBe(3);
            expect(e.batches).toHaveLength(1);
            expect(e.batches[0].batchNumber).toBe('BATCH-A');
        }
    });

    test('should include accurate batch detail in error', async () => {
        const batches = [
            makeMedBatch({ SK: 'MEDBATCH#p#B1', batchNumber: 'B1', batchStock: 2, expiryDate: futureDate(30) }),
            makeMedBatch({ SK: 'MEDBATCH#p#B2', batchNumber: 'B2', batchStock: 4, expiryDate: futureDate(90) }),
        ];

        mockQueryItems.mockResolvedValueOnce({ items: batches, lastKey: undefined });

        try {
            await deductBatchesFIFO(TENANT_ID, 'prod-med-001', 'Test Drug', 20, new Date().toISOString());
            fail('Should have thrown');
        } catch (err) {
            const e = err as InsufficientBatchStockError;
            expect(e.availableQty).toBe(6); // 2 + 4
            expect(e.requestedQty).toBe(20);
            expect(e.batches).toHaveLength(2);
        }
    });
});

// ============================================================================
// (d) EXPIRED BATCH REJECTION
// ============================================================================
describe('FIFO: Expired Batch Exclusion', () => {
    beforeEach(() => jest.clearAllMocks());

    test('should exclude expired batches from FIFO pool', async () => {
        const expiredBatch = makeMedBatch({
            SK: 'MEDBATCH#prod-med-001#EXPIRED',
            batchNumber: 'EXPIRED',
            batchStock: 100,
            expiryDate: pastDate(10),
            status: 'expired',
        });
        const activeBatch = makeMedBatch({
            SK: 'MEDBATCH#prod-med-001#ACTIVE',
            batchNumber: 'ACTIVE',
            batchStock: 20,
            expiryDate: futureDate(180),
            status: 'active',
        });

        // DynamoDB filter will already exclude expired, but test the query filter
        // The mock returns only what the filter would return
        mockQueryItems.mockResolvedValueOnce({
            items: [activeBatch], // expired is filtered out by DynamoDB filter expression
            lastKey: undefined,
        });

        const result = await deductBatchesFIFO(
            TENANT_ID, 'prod-med-001', 'Amoxicillin 250mg', 5, new Date().toISOString(),
        );

        expect(result.operations).toHaveLength(1);
        expect(result.operations[0].batchNumber).toBe('ACTIVE');
        expect(result.operations[0].deductedQty).toBe(5);
    });

    test('should throw insufficient stock when only expired batches exist', async () => {
        // DynamoDB filter excludes expired batches → empty result
        mockQueryItems.mockResolvedValueOnce({ items: [], lastKey: undefined });

        await expect(
            deductBatchesFIFO(TENANT_ID, 'prod-med-001', 'Amoxicillin 250mg', 5, new Date().toISOString()),
        ).rejects.toThrow(/Insufficient batch stock/);
    });

    test('should handle mix of expired and active batches', async () => {
        // Only active, non-expired batches returned by DynamoDB filter
        const activeBatches = [
            makeMedBatch({
                SK: 'MEDBATCH#p#B-NEAR', batchNumber: 'B-NEAR',
                batchStock: 5, expiryDate: futureDate(15),
            }),
            makeMedBatch({
                SK: 'MEDBATCH#p#B-FAR', batchNumber: 'B-FAR',
                batchStock: 10, expiryDate: futureDate(200),
            }),
        ];

        mockQueryItems.mockResolvedValueOnce({
            items: activeBatches,
            lastKey: undefined,
        });

        const result = await deductBatchesFIFO(
            TENANT_ID, 'prod-med-001', 'Test Drug', 7, new Date().toISOString(),
        );

        // Should consume near-expiry first (FIFO)
        expect(result.operations[0].batchNumber).toBe('B-NEAR');
        expect(result.operations[0].deductedQty).toBe(5);
        expect(result.operations[1].batchNumber).toBe('B-FAR');
        expect(result.operations[1].deductedQty).toBe(2);
    });
});

// ============================================================================
// (e) DEPLETED BATCH STATUS TRANSITION
// ============================================================================
describe('FIFO: Batch Depletion Status', () => {
    beforeEach(() => jest.clearAllMocks());

    test('depleted batch Update expression should set status="depleted"', async () => {
        const batch = makeMedBatch({
            batchStock: 5,
            expiryDate: futureDate(180),
        });

        mockQueryItems.mockResolvedValueOnce({ items: [batch], lastKey: undefined });

        const result = await deductBatchesFIFO(
            TENANT_ID, 'prod-med-001', 'Test Drug', 5, new Date().toISOString(),
        );

        const updateOp = result.operations[0].transactItem.Update;

        // Verify UpdateExpression contains status change
        expect(updateOp.UpdateExpression).toContain('#batchStatus = :depleted');

        // Verify ExpressionAttributeValues
        expect(updateOp.ExpressionAttributeValues[':depleted']).toBe('depleted');

        // Verify ConditionExpression prevents concurrent modification
        expect(updateOp.ConditionExpression).toContain('#batchStatus = :activeStatus');
        expect(updateOp.ConditionExpression).toContain('batchStock >= :minStock');
    });

    test('non-depleted batch Update expression should NOT set status', async () => {
        const batch = makeMedBatch({
            batchStock: 100,
            expiryDate: futureDate(180),
        });

        mockQueryItems.mockResolvedValueOnce({ items: [batch], lastKey: undefined });

        const result = await deductBatchesFIFO(
            TENANT_ID, 'prod-med-001', 'Test Drug', 10, new Date().toISOString(),
        );

        const updateExpr = result.operations[0].transactItem.Update.UpdateExpression;
        expect(updateExpr).not.toContain(':depleted');
    });
});

// ============================================================================
// (f) INTEGRATION: Pharmacy Invoice Creates FIFO Batch Ops
// ============================================================================
describe('Integration: Pharmacy Invoice FIFO', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 100 });
    });

    test('pharmacy invoice should trigger FIFO batch deduction', async () => {
        const product = makePharmacyProduct({ currentStock: 50 });
        mockBatchGetItems.mockResolvedValue([product]);

        // First queryItems call: MEDBATCH# query for FIFO
        const batch = makeMedBatch({
            batchStock: 50,
            expiryDate: futureDate(180),
        });
        mockQueryItems
            .mockResolvedValueOnce({ items: [batch], lastKey: undefined })  // FIFO batch query
            .mockResolvedValueOnce({ items: [], lastKey: undefined });      // duplicate Rx check

        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID,
            USER_ID,
            {
                items: [{
                    productId: 'prod-med-001',
                    quantity: 5,
                    unitPrice: 7800,
                }],
                metadata: { prescriptionId: 'RX-001' },
            },
            'owner',
            'pharmacy',  // businessType triggers FIFO
        );

        expect(result.id).toBeDefined();
        expect(result.invoiceNumber).toMatch(/^INV-/);

        // Verify transactWrite was called with batch deduction operations
        expect(mockTransactWrite).toHaveBeenCalledTimes(1);
        const txItems = mockTransactWrite.mock.calls[0][0];

        // Should include: batch update(s) + aggregate product stock update + invoice + line items
        // Find the MEDBATCH# update operation
        const batchOps = txItems.filter(
            (op: any) => op.Update?.Key?.SK?.startsWith('MEDBATCH#'),
        );
        expect(batchOps.length).toBeGreaterThanOrEqual(1);

        // Find the PRODUCT# aggregate stock update
        const productOps = txItems.filter(
            (op: any) => op.Update?.Key?.SK === 'PRODUCT#prod-med-001',
        );
        expect(productOps.length).toBe(1);
    });

    test('pharmacy invoice with insufficient batch stock should fail', async () => {
        const product = makePharmacyProduct({ currentStock: 50 });
        mockBatchGetItems.mockResolvedValue([product]);

        // Return only 3 units in batches
        const batch = makeMedBatch({ batchStock: 3, expiryDate: futureDate(180) });
        mockQueryItems.mockResolvedValueOnce({ items: [batch], lastKey: undefined });

        await expect(
            invoiceService.createInvoice(
                TENANT_ID,
                USER_ID,
                {
                    items: [{
                        productId: 'prod-med-001',
                        quantity: 10,
                        unitPrice: 7800,
                    }],
                    metadata: { prescriptionId: 'RX-002' },
                },
                'owner',
                'pharmacy',
            ),
        ).rejects.toThrow(/Insufficient batch stock/);
    });
});

// ============================================================================
// (g) NON-PHARMACY INVOICE — NO FIFO
// ============================================================================
describe('Non-Pharmacy: No FIFO Batch Deduction', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 200 });
    });

    test('grocery invoice should use simple stock decrement (no FIFO)', async () => {
        const product = makePharmacyProduct({
            id: 'prod-grocery-001',
            SK: 'PRODUCT#prod-grocery-001',
            name: 'Sugar 1kg',
        });
        mockBatchGetItems.mockResolvedValue([product]);
        mockQueryItems
            .mockResolvedValueOnce({
                items: [{
                    PK: `TENANT#${TENANT_ID}`,
                    SK: 'GROBATCH#prod-grocery-001#G-BATCH-1',
                    batchNumber: 'G-BATCH-1',
                    productId: 'prod-grocery-001',
                    productName: 'Sugar 1kg',
                    expiryDate: futureDate(120),
                    currentQty: 20,
                    status: 'active',
                    createdAt: new Date().toISOString(),
                    updatedAt: new Date().toISOString(),
                }],
                lastKey: undefined,
            })
            .mockResolvedValueOnce({ items: [], lastKey: undefined });
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID,
            USER_ID,
            {
                items: [{
                    productId: 'prod-grocery-001',
                    quantity: 2,
                    unitPrice: 5000,
                }],
            },
            'owner',
            'grocery',  // Not pharmacy — no FIFO
        );

        expect(result.id).toBeDefined();

        // Should NOT have any MEDBATCH# operations in transactWrite
        const txItems = mockTransactWrite.mock.calls[0][0];
        const batchOps = txItems.filter(
            (op: any) => op.Update?.Key?.SK?.startsWith('MEDBATCH#'),
        );
        expect(batchOps).toHaveLength(0);
    });

    test('undefined businessType should use simple stock decrement', async () => {
        const product = makePharmacyProduct({
            id: 'prod-gen-001',
            SK: 'PRODUCT#prod-gen-001',
            name: 'Generic Item',
        });
        mockBatchGetItems.mockResolvedValue([product]);
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID,
            USER_ID,
            {
                items: [{
                    productId: 'prod-gen-001',
                    quantity: 1,
                    unitPrice: 1000,
                }],
            },
            'owner',
            undefined,  // No businessType
        );

        expect(result.id).toBeDefined();

        // No MEDBATCH# ops
        const txItems = mockTransactWrite.mock.calls[0][0];
        const batchOps = txItems.filter(
            (op: any) => op.Update?.Key?.SK?.startsWith('MEDBATCH#'),
        );
        expect(batchOps).toHaveLength(0);
    });
});

// ============================================================================
// HELPER TESTS: medBatchSK key builder
// ============================================================================
describe('medBatchSK Key Builder', () => {
    test('should build correct SK format', () => {
        expect(medBatchSK('prod-001', 'BATCH-A'))
            .toBe('MEDBATCH#prod-001#BATCH-A');
    });

    test('should handle special characters in batch number', () => {
        expect(medBatchSK('prod-002', 'B2026/01-LOT123'))
            .toBe('MEDBATCH#prod-002#B2026/01-LOT123');
    });
});
