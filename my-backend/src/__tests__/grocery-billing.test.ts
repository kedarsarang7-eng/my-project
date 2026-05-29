// ============================================================================
// Grocery Store Billing — Regression Tests
// ============================================================================
// Tests for BUG-001 (weight-based), BUG-002 (MRP), BUG-003 (timezone),
// BUG-005 (negative qty), BUG-006 (rounding drift), FEATURE-G (void states).
//
// Run with: npx jest src/__tests__/grocery-billing.test.ts
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';

// ---- Mock Auth ----
const mockVerifyAuth = jest.fn().mockResolvedValue({
    sub: 'test-user-id',
    email: 'test@grocery.com',
    tenantId: 'test-tenant-id',
    role: 'owner',
    businessType: 'grocery',
    planTier: 'professional',
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

// ---- Test Helpers ----

const TENANT_ID = 'test-tenant-id';
const USER_ID = 'test-user-id';

function makeGroceryProduct(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-rice',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-rice',
        name: 'Basmati Rice 5kg',
        salePriceCents: 39900,
        purchasePriceCents: 31000,
        mrpCents: 42500,
        currentStock: 80,
        lowStockThreshold: 10,
        cgstRateBp: 250,
        sgstRateBp: 250,
        isDeleted: false,
        isService: false,
        unit: 'pcs',
        hsnCode: '1006',
        attributes: {},
        ...overrides,
    };
}

function makeWeightProduct(overrides: Record<string, any> = {}) {
    return makeGroceryProduct({
        id: 'prod-onion',
        SK: 'PRODUCT#prod-onion',
        name: 'Onions (Loose)',
        salePriceCents: 3500,       // ₹35.00/kg
        purchasePriceCents: 2500,
        mrpCents: undefined,        // No MRP for loose goods
        cgstRateBp: 0,
        sgstRateBp: 0,
        currentStock: 150,          // 150 kg
        unit: 'kg',
        hsnCode: '0703',
        ...overrides,
    });
}

function makeZeroGstProduct(overrides: Record<string, any> = {}) {
    return makeGroceryProduct({
        id: 'prod-milk',
        SK: 'PRODUCT#prod-milk',
        name: 'Amul Toned Milk 500ml',
        salePriceCents: 2800,
        purchasePriceCents: 2400,
        mrpCents: 3000,
        cgstRateBp: 0,
        sgstRateBp: 0,
        currentStock: 200,
        unit: 'pcs',
        hsnCode: '0401',
        ...overrides,
    });
}

function makeTaxedProduct(overrides: Record<string, any> = {}) {
    return makeGroceryProduct({
        id: 'prod-biscuit',
        SK: 'PRODUCT#prod-biscuit',
        name: 'Parle-G Biscuits 800g',
        salePriceCents: 7400,
        purchasePriceCents: 5800,
        mrpCents: 8000,
        cgstRateBp: 900,         // 9% CGST
        sgstRateBp: 900,         // 9% SGST
        currentStock: 200,
        unit: 'pcs',
        hsnCode: '1905',
        ...overrides,
    });
}

// ============================================================================
// Import the service (after mocks are set up)
// ============================================================================
import * as invoiceService from '../services/invoice.service';

// ============================================================================
// BUG-001 — WEIGHT-BASED BILLING ACCURACY
// ============================================================================
describe('BUG-001: Weight-Based Billing', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 1 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should correctly calculate line total for fractional kg quantity (2.350 kg @ ₹35/kg)', async () => {
        const product = makeWeightProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-onion',
                quantity: 2.350,
                unitPrice: 3500,  // ₹35.00/kg in paise
            }],
        });

        expect(result.id).toBeDefined();
        expect(result.invoiceNumber).toMatch(/^INV-/);

        // lineGrossCents = roundTaxComponent(3500 * 2.350) = roundTaxComponent(8225) = 8225
        // Onions are 0% GST, so total = 8225 paise = ₹82.25
        expect(result.subtotalCents).toBe(8225);
        expect(result.taxCents).toBe(0);

        // Verify transactWrite was called with the correct stock deduction
        const transactCall = mockTransactWrite.mock.calls[0][0];
        const stockUpdate = transactCall.find((item: any) => item.Update?.UpdateExpression?.includes('currentStock'));
        expect(stockUpdate).toBeDefined();
        // The :qty value should be exactly 2.350 (not truncated to 2)
        expect(stockUpdate.Update.ExpressionAttributeValues[':qty']).toBe(2.350);
    });

    test('should handle very small weight quantity (0.050 kg = 50 grams)', async () => {
        const product = makeWeightProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-onion',
                quantity: 0.050,
                unitPrice: 3500,
            }],
        });

        expect(result.id).toBeDefined();
        // 3500 * 0.050 = 175 paise = ₹1.75
        expect(result.subtotalCents).toBe(175);
    });

    test('should handle exact kg quantity (10.000 kg)', async () => {
        const product = makeWeightProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-onion',
                quantity: 10.000,
                unitPrice: 3500,
            }],
        });

        // 3500 * 10 = 35000 paise = ₹350.00
        expect(result.subtotalCents).toBe(35000);
    });
});

// ============================================================================
// BUG-002 — MRP ENFORCEMENT
// ============================================================================
describe('BUG-002: MRP Enforcement', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 2 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should reject sale price above MRP', async () => {
        const product = makeGroceryProduct({ mrpCents: 42500 }); // MRP = ₹425
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{
                    productId: 'prod-rice',
                    quantity: 1,
                    unitPrice: 45000,  // ₹450 > MRP ₹425
                }],
            })
        ).rejects.toThrow(/exceeds MRP/);
    });

    test('should allow sale price equal to MRP', async () => {
        const product = makeGroceryProduct({ mrpCents: 42500 });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-rice',
                quantity: 1,
                unitPrice: 42500,  // Exactly = MRP
            }],
        });

        expect(result.id).toBeDefined();
    });

    test('should allow sale price below MRP', async () => {
        const product = makeGroceryProduct({ mrpCents: 42500 });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-rice',
                quantity: 1,
                unitPrice: 39900,  // ₹399 < MRP ₹425
            }],
        });

        expect(result.id).toBeDefined();
    });

    test('should skip MRP check for products without MRP (loose goods)', async () => {
        const product = makeWeightProduct({ mrpCents: undefined });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        // Any price should be OK
        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-onion',
                quantity: 1,
                unitPrice: 99999,
            }],
        });

        expect(result.id).toBeDefined();
    });
});

// ============================================================================
// BUG-003 — EXPIRY DATE TIMEZONE HANDLING (UTC Normalization)
// ============================================================================
describe('BUG-003: Expiry Date UTC Normalization', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 3 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should block expired batch (yesterday)', async () => {
        const product = makeZeroGstProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        const yesterday = new Date();
        yesterday.setUTCDate(yesterday.getUTCDate() - 1);
        const expiryStr = yesterday.toISOString().split('T')[0];

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{
                    productId: 'prod-milk',
                    quantity: 1,
                    unitPrice: 2800,
                    expiryDate: expiryStr,
                    batchNumber: 'MILK-EXP-001',
                }],
            })
        ).rejects.toThrow(/Cannot sell from expired batch/);
    });

    test('should NOT block batch expiring today (boundary test)', async () => {
        const product = makeZeroGstProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const today = new Date();
        const todayStr = `${today.getUTCFullYear()}-${String(today.getUTCMonth() + 1).padStart(2, '0')}-${String(today.getUTCDate()).padStart(2, '0')}`;

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-milk',
                quantity: 1,
                unitPrice: 2800,
                expiryDate: todayStr,
                batchNumber: 'MILK-TODAY',
            }],
        });

        expect(result.id).toBeDefined();
        // Should have a near-expiry warning (0 days remaining)
        const warning = result.warnings?.find(w => w.type === 'NEAR_EXPIRY');
        expect(warning).toBeDefined();
        expect(warning!.daysRemaining).toBe(0);
    });

    test('should warn for batch expiring in 3 days', async () => {
        const product = makeZeroGstProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const in3Days = new Date();
        in3Days.setUTCDate(in3Days.getUTCDate() + 3);
        const expiryStr = in3Days.toISOString().split('T')[0];

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-milk',
                quantity: 1,
                unitPrice: 2800,
                expiryDate: expiryStr,
                batchNumber: 'MILK-3DAYS',
            }],
        });

        expect(result.id).toBeDefined();
        const warning = result.warnings?.find(w => w.type === 'NEAR_EXPIRY');
        expect(warning).toBeDefined();
        expect(warning!.daysRemaining).toBe(3);
        expect(warning!.message).toContain('3 days');
    });

    test('should reject invalid expiry date format', async () => {
        const product = makeZeroGstProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{
                    productId: 'prod-milk',
                    quantity: 1,
                    unitPrice: 2800,
                    expiryDate: 'not-a-date',
                }],
            })
        ).rejects.toThrow(/Invalid expiry date format/);
    });
});

// ============================================================================
// BUG-005 — NEGATIVE / ZERO QUANTITY REJECTION
// ============================================================================
describe('BUG-005: Quantity Validation', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 4 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should reject zero quantity', async () => {
        const product = makeGroceryProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{
                    productId: 'prod-rice',
                    quantity: 0,
                    unitPrice: 39900,
                }],
            })
        ).rejects.toThrow(/invalid quantity/i);
    });

    test('should reject negative quantity (stock inflation attack)', async () => {
        const product = makeGroceryProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{
                    productId: 'prod-rice',
                    quantity: -5,
                    unitPrice: 39900,
                }],
            })
        ).rejects.toThrow(/invalid quantity/i);
    });

    test('should accept small positive quantity (0.001 kg for weight-based)', async () => {
        const product = makeWeightProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-onion',
                quantity: 0.001,
                unitPrice: 3500,
            }],
        });

        expect(result.id).toBeDefined();
        // 3500 * 0.001 = 3.5 → rounded = 4 paise
        expect(result.subtotalCents).toBeGreaterThanOrEqual(0);
    });

    test('should reject NaN quantity', async () => {
        const product = makeGroceryProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{
                    productId: 'prod-rice',
                    quantity: NaN,
                    unitPrice: 39900,
                }],
            })
        ).rejects.toThrow(/invalid quantity/i);
    });

    test('should reject non-integer unit price in paise', async () => {
        const product = makeGroceryProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{
                    productId: 'prod-rice',
                    quantity: 1,
                    unitPrice: 399.50,  // Not an integer
                }],
            })
        ).rejects.toThrow(/integer paise/i);
    });
});

// ============================================================================
// BUG-006 — GST ROUNDING CONSISTENCY
// ============================================================================
describe('BUG-006: GST Rounding Consistency', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 5 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should satisfy subtotalCents + taxCents + roundOffCents === totalCents (exact integer)', async () => {
        // Mixed tax slabs: 0%, 5%, 18%
        const products = [
            makeZeroGstProduct(),                                    // 0% GST
            makeGroceryProduct(),                                    // 5% GST
            makeTaxedProduct(),                                      // 18% GST
        ];
        mockBatchGetItems.mockResolvedValue(products);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [
                { productId: 'prod-milk', quantity: 5, unitPrice: 2800 },     // 0% × 5
                { productId: 'prod-rice', quantity: 2, unitPrice: 39900 },    // 5% × 2
                { productId: 'prod-biscuit', quantity: 3, unitPrice: 7400 },  // 18% × 3
            ],
        });

        expect(result.id).toBeDefined();

        // THE GOLDEN INVARIANT: exact integer equality
        expect(result.subtotalCents + result.taxCents + result.roundOffCents)
            .toBe(result.totalCents);
    });

    test('should handle many items at fractional prices (stress rounding)', async () => {
        // 7 items at ₹33.33 each with 5% GST
        const products = Array.from({ length: 7 }, (_, i) =>
            makeGroceryProduct({
                id: `prod-frac-${i}`,
                SK: `PRODUCT#prod-frac-${i}`,
                name: `Item ${i}`,
                salePriceCents: 3333,
                cgstRateBp: 250,
                sgstRateBp: 250,
            })
        );
        mockBatchGetItems.mockResolvedValue(products);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: products.map(p => ({
                productId: p.id,
                quantity: 1,
                unitPrice: 3333,
            })),
        });

        // THE GOLDEN INVARIANT
        expect(result.subtotalCents + result.taxCents + result.roundOffCents)
            .toBe(result.totalCents);

        // Round-off should be within ±₹2 (200 paise) for normal invoices
        expect(Math.abs(result.roundOffCents)).toBeLessThanOrEqual(200);
    });

    test('should handle all zero-GST items (no rounding needed)', async () => {
        const products = [
            makeZeroGstProduct(),
            makeZeroGstProduct({
                id: 'prod-bread', SK: 'PRODUCT#prod-bread',
                name: 'Bread', salePriceCents: 4200, mrpCents: 5000,
            }),
        ];
        mockBatchGetItems.mockResolvedValue(products);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [
                { productId: 'prod-milk', quantity: 2, unitPrice: 2800 },
                { productId: 'prod-bread', quantity: 1, unitPrice: 4200 },
            ],
        });

        expect(result.taxCents).toBe(0);
        expect(result.subtotalCents + result.taxCents + result.roundOffCents)
            .toBe(result.totalCents);
    });
});

// ============================================================================
// FEATURE-G — INVOICE STATE MACHINE
// ============================================================================
describe('FEATURE-G: Invoice State Machine', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('should reject voiding a draft invoice', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-draft',
            status: 'draft',
            paidCents: 0,
            totalCents: 10000,
            isDeleted: false,
        });

        await expect(
            invoiceService.voidInvoice(TENANT_ID, 'inv-draft', 'Changed mind')
        ).rejects.toThrow(/Cannot void a draft invoice/);
    });

    test('should allow voiding a finalized invoice with no payment', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-finalized',
            status: 'finalized',
            paidCents: 0,
            totalCents: 10000,
            isDeleted: false,
            invoiceNumber: 'INV-000001',
            notes: '',
        });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.voidInvoice(TENANT_ID, 'inv-finalized', 'Customer no-show');
        expect(result.status).toBe('voided');
    });

    test('should reject voiding a paid invoice', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-paid',
            status: 'paid',
            paidCents: 10000,
            totalCents: 10000,
            isDeleted: false,
        });

        await expect(
            invoiceService.voidInvoice(TENANT_ID, 'inv-paid', 'Error')
        ).rejects.toThrow(/has already been collected/);
    });

    test('should block returns from draft invoice', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-draft-ret',
            status: 'draft',
            isDeleted: false,
        });

        await expect(
            invoiceService.createReturn(TENANT_ID, 'inv-draft-ret', [
                { itemId: 'prod-rice', quantity: 1 },
            ], USER_ID)
        ).rejects.toThrow(/Cannot return items from a 'draft' invoice/);
    });

    test('should block returns from voided invoice', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-voided-ret',
            status: 'voided',
            isDeleted: false,
        });

        await expect(
            invoiceService.createReturn(TENANT_ID, 'inv-voided-ret', [
                { itemId: 'prod-rice', quantity: 1 },
            ], USER_ID)
        ).rejects.toThrow(/Cannot return items from a 'voided' invoice/);
    });
});

// ============================================================================
// CONCURRENT STOCK — Only one wins
// ============================================================================
describe('Concurrent Stock Deduction', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 6 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should surface 409 error when TransactionCanceledException occurs (stock conflict)', async () => {
        const product = makeGroceryProduct({ currentStock: 1 });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockRejectedValue(
            Object.assign(new Error('Transaction cancelled'), { name: 'TransactionCanceledException' })
        );

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{
                    productId: 'prod-rice',
                    quantity: 1,
                    unitPrice: 39900,
                }],
            })
        ).rejects.toThrow(/concurrent|Transaction|modification/i);
    });
});
