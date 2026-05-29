// ============================================================================
// Hardware Shop Billing — Comprehensive Regression Tests
// ============================================================================
// Tests for hardware-specific scenarios: UOM variations (per piece/kg/foot),
// custom measurements, contractor credit limits, mixed GST slabs,
// bulk billing, zero-stock edge cases, and discount boundaries.
//
// Run with: npx jest src/__tests__/hardware-billing.test.ts
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';

// ---- Mock Auth ----
const mockVerifyAuth = jest.fn().mockResolvedValue({
    sub: 'test-user-id',
    email: 'owner@hardwareshop.com',
    tenantId: 'hw-tenant-id',
    role: 'owner',
    businessType: 'hardware',
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
    getTenantId: () => 'hw-tenant-id',
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

// ---- Test Constants ----
const TENANT_ID = 'hw-tenant-id';
const USER_ID = 'test-user-id';

// ============================================================================
// PRODUCT CATALOGUE — Realistic Hardware Shop Items
// ============================================================================

/** PVC Pipe — sold per foot, 18% GST */
function makePvcPipe(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-pvc-1inch',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-pvc-1inch',
        name: 'PVC Pipe 1 inch',
        salePriceCents: 4500,       // ₹45.00/foot
        purchasePriceCents: 3200,
        mrpCents: 5000,
        currentStock: 500,          // 500 feet
        lowStockThreshold: 50,
        cgstRateBp: 900,            // 9% CGST
        sgstRateBp: 900,            // 9% SGST
        isDeleted: false,
        isService: false,
        unit: 'ft',
        hsnCode: '3917',
        attributes: {},
        ...overrides,
    };
}

/** Cement Bag — sold per piece (50kg bag), 28% GST */
function makeCementBag(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-cement-50kg',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-cement-50kg',
        name: 'Cement Bag 50kg (UltraTech)',
        salePriceCents: 38000,      // ₹380.00/bag
        purchasePriceCents: 34000,
        mrpCents: 40000,
        currentStock: 200,
        lowStockThreshold: 20,
        cgstRateBp: 1400,           // 14% CGST
        sgstRateBp: 1400,           // 14% SGST (total 28%)
        isDeleted: false,
        isService: false,
        unit: 'bag',
        hsnCode: '2523',
        attributes: {},
        ...overrides,
    };
}

/** Paint Brush Set — sold per set, 18% GST */
function makePaintBrushSet(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-brush-set',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-brush-set',
        name: 'Paint Brush Set (5pc)',
        salePriceCents: 25000,      // ₹250.00/set
        purchasePriceCents: 18000,
        mrpCents: 29900,
        currentStock: 75,
        lowStockThreshold: 10,
        cgstRateBp: 900,
        sgstRateBp: 900,
        isDeleted: false,
        isService: false,
        unit: 'set',
        hsnCode: '9603',
        attributes: {},
        ...overrides,
    };
}

/** Copper Wire 2.5mm — sold per metre, 18% GST */
function makeWire(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-wire-2.5mm',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-wire-2.5mm',
        name: 'Wire 2.5mm (Havells)',
        salePriceCents: 1800,       // ₹18.00/metre
        purchasePriceCents: 1400,
        mrpCents: 2000,
        currentStock: 2000,         // 2000 metres
        lowStockThreshold: 100,
        cgstRateBp: 900,
        sgstRateBp: 900,
        isDeleted: false,
        isService: false,
        unit: 'mtr',
        hsnCode: '8544',
        attributes: {},
        ...overrides,
    };
}

/** Wall Putty — sold per kg, 18% GST */
function makeWallPutty(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-wall-putty',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-wall-putty',
        name: 'Wall Putty (Birla White)',
        salePriceCents: 2500,       // ₹25.00/kg
        purchasePriceCents: 1800,
        mrpCents: 2800,
        currentStock: 1000,         // 1000 kg
        lowStockThreshold: 50,
        cgstRateBp: 900,
        sgstRateBp: 900,
        isDeleted: false,
        isService: false,
        unit: 'kg',
        hsnCode: '3214',
        attributes: {},
        ...overrides,
    };
}

/** TMT Steel Bar — sold per kg, 18% GST */
function makeSteelBar(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-tmt-bar',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-tmt-bar',
        name: 'TMT Steel Bar 12mm (TATA Tiscon)',
        salePriceCents: 6500,       // ₹65.00/kg
        purchasePriceCents: 5800,
        mrpCents: undefined,        // No MRP for steel (based on market rate)
        currentStock: 5000,         // 5000 kg
        lowStockThreshold: 200,
        cgstRateBp: 900,
        sgstRateBp: 900,
        isDeleted: false,
        isService: false,
        unit: 'kg',
        hsnCode: '7214',
        attributes: {},
        ...overrides,
    };
}

/** Sand — sold per cubic foot, 5% GST */
function makeSand(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-sand',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-sand',
        name: 'River Sand (M-Sand)',
        salePriceCents: 5500,       // ₹55.00/cft
        purchasePriceCents: 4000,
        mrpCents: undefined,
        currentStock: 10000,        // 10000 cft
        lowStockThreshold: 500,
        cgstRateBp: 250,
        sgstRateBp: 250,
        isDeleted: false,
        isService: false,
        unit: 'cft',
        hsnCode: '2505',
        attributes: {},
        ...overrides,
    };
}

/** GI Pipe — sold per piece, 18% GST */
function makeGiPipe(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-gi-pipe',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-gi-pipe',
        name: 'GI Pipe 1 inch (6ft)',
        salePriceCents: 55000,      // ₹550.00/piece
        purchasePriceCents: 45000,
        mrpCents: 60000,
        currentStock: 100,
        lowStockThreshold: 10,
        cgstRateBp: 900,
        sgstRateBp: 900,
        isDeleted: false,
        isService: false,
        unit: 'pcs',
        hsnCode: '7306',
        attributes: {},
        ...overrides,
    };
}

// ============================================================================
// Import the service (after mocks are set up)
// ============================================================================
import * as invoiceService from '../services/invoice.service';

// ============================================================================
// 1. SALES & INVOICING — Multi-UOM Billing
// ============================================================================
describe('HW-1: Sales & Invoicing — Unit of Measure Variations', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 1 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should bill PVC pipe per foot with fractional quantity (12.5 ft @ ₹45/ft)', async () => {
        const product = makePvcPipe();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-pvc-1inch', quantity: 12.5, unitPrice: 4500 }],
        });

        expect(result.id).toBeDefined();
        // lineGross = 4500 * 12.5 = 56250 paise = ₹562.50
        // 18% GST on ₹562.50 → CGST ₹50.63, SGST ₹50.63
        expect(result.subtotalCents).toBe(56250);
        expect(result.taxCents).toBeGreaterThan(0);
        // Verify stock deduction is fractional
        const transactCall = mockTransactWrite.mock.calls[0][0];
        const stockUpdate = transactCall.find((item: any) => item.Update?.UpdateExpression?.includes('currentStock'));
        expect(stockUpdate.Update.ExpressionAttributeValues[':qty']).toBe(12.5);
    });

    test('should bill cement bags per piece — whole number only', async () => {
        const product = makeCementBag();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-cement-50kg', quantity: 10, unitPrice: 38000 }],
        });

        // subtotal = 10 × ₹380 = ₹3800.00 = 380000 paise
        expect(result.subtotalCents).toBe(380000);
        // 28% GST on ₹3800 → tax should be substantial
        expect(result.taxCents).toBeGreaterThan(0);
    });

    test('should bill wire per metre with fractional quantity (25.5 mtr)', async () => {
        const product = makeWire();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-wire-2.5mm', quantity: 25.5, unitPrice: 1800 }],
        });

        // 1800 * 25.5 = 45900 paise = ₹459.00
        expect(result.subtotalCents).toBe(45900);
    });

    test('should bill wall putty per kg with fractional weight (7.750 kg)', async () => {
        const product = makeWallPutty();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-wall-putty', quantity: 7.750, unitPrice: 2500 }],
        });

        // 2500 * 7.75 = 19375 paise = ₹193.75
        expect(result.subtotalCents).toBe(19375);
    });

    test('should bill sand per cubic foot in large quantity (500 cft)', async () => {
        const product = makeSand();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-sand', quantity: 500, unitPrice: 5500 }],
            customerName: 'Rajesh Contractors',
        });

        // 5500 * 500 = 2750000 paise = ₹27,500.00
        expect(result.subtotalCents).toBe(2750000);
        expect(result.taxCents).toBeGreaterThan(0);
    });
});

// ============================================================================
// 2. MIXED GST SLABS — Hardware Shop Reality
// ============================================================================
describe('HW-2: Mixed GST Slabs in Single Invoice', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 2 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should correctly calculate 5%, 18%, 28% GST items in one invoice', async () => {
        const products = [
            makeSand(),                     // 5% GST
            makePvcPipe(),                  // 18% GST
            makeCementBag(),                // 28% GST
        ];
        mockBatchGetItems.mockResolvedValue(products);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [
                { productId: 'prod-sand', quantity: 100, unitPrice: 5500 },       // 5% on ₹5,500
                { productId: 'prod-pvc-1inch', quantity: 20, unitPrice: 4500 },   // 18% on ₹900
                { productId: 'prod-cement-50kg', quantity: 5, unitPrice: 38000 }, // 28% on ₹1,900
            ],
            customerName: 'Suresh Builders',
        });

        expect(result.id).toBeDefined();
        // THE GOLDEN INVARIANT
        expect(result.subtotalCents + result.taxCents + result.roundOffCents)
            .toBe(result.totalCents);
        // Round-off within ±₹2
        expect(Math.abs(result.roundOffCents)).toBeLessThanOrEqual(200);
    });

    test('should handle IGST for inter-state hardware sale', async () => {
        const products = [makeCementBag(), makePvcPipe()];
        mockBatchGetItems.mockResolvedValue(products);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [
                { productId: 'prod-cement-50kg', quantity: 10, unitPrice: 38000 },
                { productId: 'prod-pvc-1inch', quantity: 50, unitPrice: 4500 },
            ],
            isInterState: true,
            customerName: 'Mumbai Contractors',
            customerGstin: '27AABCU9603R1ZM',
        });

        expect(result.id).toBeDefined();
        expect(result.subtotalCents + result.taxCents + result.roundOffCents)
            .toBe(result.totalCents);
    });
});

// ============================================================================
// 3. INVENTORY — Zero Stock, Insufficient Stock, Negative Qty
// ============================================================================
describe('HW-3: Inventory Edge Cases', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 3 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should reject sale when stock is zero', async () => {
        const product = makeCementBag({ currentStock: 0 });
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-cement-50kg', quantity: 1, unitPrice: 38000 }],
            })
        ).rejects.toThrow(/Insufficient stock/);
    });

    test('should reject sale when requested qty exceeds stock', async () => {
        const product = makePvcPipe({ currentStock: 10 });
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-pvc-1inch', quantity: 15, unitPrice: 4500 }],
            })
        ).rejects.toThrow(/Insufficient stock/);
    });

    test('should reject negative quantity (stock inflation attack)', async () => {
        const product = makeCementBag();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-cement-50kg', quantity: -5, unitPrice: 38000 }],
            })
        ).rejects.toThrow(/invalid quantity/i);
    });

    test('should reject zero quantity', async () => {
        const product = makeWire();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-wire-2.5mm', quantity: 0, unitPrice: 1800 }],
            })
        ).rejects.toThrow(/invalid quantity/i);
    });

    test('should reject NaN quantity', async () => {
        const product = makeSteelBar();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-tmt-bar', quantity: NaN, unitPrice: 6500 }],
            })
        ).rejects.toThrow(/invalid quantity/i);
    });

    test('should reject deleted product', async () => {
        const product = makePaintBrushSet({ isDeleted: true });
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-brush-set', quantity: 1, unitPrice: 25000 }],
            })
        ).rejects.toThrow(/Product not found/);
    });

    test('should handle concurrent stock deduction (TransactionCanceledException)', async () => {
        const product = makeCementBag({ currentStock: 1 });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockRejectedValue(
            Object.assign(new Error('Transaction cancelled'), { name: 'TransactionCanceledException' })
        );

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-cement-50kg', quantity: 1, unitPrice: 38000 }],
            })
        ).rejects.toThrow(/concurrent|Transaction|modification/i);
    });
});

// ============================================================================
// 4. DISCOUNTS & OFFERS — Item-level + Bill-level for Contractor Orders
// ============================================================================
describe('HW-4: Discounts — Contractor Bulk Orders', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 4 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should apply item-level discount on bulk cement order', async () => {
        const product = makeCementBag();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-cement-50kg',
                quantity: 50,
                unitPrice: 38000,
                discountCents: 100000, // ₹1,000 flat discount on line
            }],
            customerName: 'ABC Constructions',
        });

        expect(result.id).toBeDefined();
        // Gross = 50 × 38000 = 1900000. Discount = 100000. Taxable = 1800000
        expect(result.subtotalCents).toBe(1800000);
        expect(result.totalCents).toBeGreaterThan(result.subtotalCents); // tax added
    });

    test('should apply bill-level discount on mixed hardware order', async () => {
        const products = [makePvcPipe(), makeCementBag(), makePaintBrushSet()];
        mockBatchGetItems.mockResolvedValue(products);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [
                { productId: 'prod-pvc-1inch', quantity: 100, unitPrice: 4500 },
                { productId: 'prod-cement-50kg', quantity: 20, unitPrice: 38000 },
                { productId: 'prod-brush-set', quantity: 5, unitPrice: 25000 },
            ],
            discountCents: 50000, // ₹500 bill-level discount
            customerName: 'Rajesh Builders Pvt Ltd',
        });

        expect(result.id).toBeDefined();
        // subtotal should be reduced by bill discount
        const rawSubtotal = (100 * 4500) + (20 * 38000) + (5 * 25000);
        expect(result.subtotalCents).toBe(rawSubtotal - 50000);
    });

    test('should cap item discount at line gross — never negative taxable value', async () => {
        const product = makePaintBrushSet();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-brush-set',
                quantity: 1,
                unitPrice: 25000,
                discountCents: 999999, // Absurdly high — ₹9,999.99 discount on ₹250 item
            }],
        });

        expect(result.id).toBeDefined();
        expect(result.totalCents).toBeGreaterThanOrEqual(0);
    });

    test('should cap bill-level discount at subtotal', async () => {
        const product = makeWire();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-wire-2.5mm', quantity: 10, unitPrice: 1800 }],
            discountCents: 9999999, // Way more than subtotal
        });

        expect(result.id).toBeDefined();
        expect(result.subtotalCents).toBeGreaterThanOrEqual(0);
        expect(result.totalCents).toBeGreaterThanOrEqual(0);
    });
});

// ============================================================================
// 5. MRP ENFORCEMENT — Selling Above MRP Blocked
// ============================================================================
describe('HW-5: MRP Enforcement', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 5 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should reject sale price above MRP for cement', async () => {
        const product = makeCementBag({ mrpCents: 40000 }); // MRP ₹400
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-cement-50kg', quantity: 1, unitPrice: 42000 }],
            })
        ).rejects.toThrow(/exceeds MRP/);
    });

    test('should allow sale at exactly MRP', async () => {
        const product = makeCementBag({ mrpCents: 40000 });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-cement-50kg', quantity: 1, unitPrice: 40000 }],
        });
        expect(result.id).toBeDefined();
    });

    test('should skip MRP check for steel (no MRP — market rate)', async () => {
        const product = makeSteelBar({ mrpCents: undefined });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-tmt-bar', quantity: 100, unitPrice: 7000 }],
        });
        expect(result.id).toBeDefined();
    });

    test('should reject non-integer unit price in paise', async () => {
        const product = makePvcPipe();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-pvc-1inch', quantity: 10, unitPrice: 45.50 }],
            })
        ).rejects.toThrow(/integer paise/i);
    });
});

// ============================================================================
// 6. RETURNS & REFUNDS — Hardware Returns
// ============================================================================
describe('HW-6: Returns & Refunds', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('should reject return of more items than sold', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-hw-001',
            status: 'finalized',
            isDeleted: false,
            invoiceNumber: 'INV-000001',
        });
        mockQueryItems
            .mockResolvedValueOnce({
                items: [{
                    itemId: 'prod-cement-50kg',
                    name: 'Cement Bag 50kg',
                    quantity: 5,
                    unitPriceCents: 38000,
                    taxCents: 53200,
                }],
                lastKey: undefined,
            })
            .mockResolvedValueOnce({ items: [], lastKey: undefined });

        await expect(
            invoiceService.createReturn(TENANT_ID, 'inv-hw-001', [
                { itemId: 'prod-cement-50kg', quantity: 10, reason: 'Damaged bags' },
            ], USER_ID)
        ).rejects.toThrow(/only 5 returnable/);
    });

    test('should reject return from draft invoice', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-hw-draft', status: 'draft', isDeleted: false,
        });

        await expect(
            invoiceService.createReturn(TENANT_ID, 'inv-hw-draft', [
                { itemId: 'prod-cement-50kg', quantity: 1 },
            ], USER_ID)
        ).rejects.toThrow(/Cannot return items from a 'draft' invoice/);
    });

    test('should reject return from voided invoice', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-hw-voided', status: 'voided', isDeleted: false,
        });

        await expect(
            invoiceService.createReturn(TENANT_ID, 'inv-hw-voided', [
                { itemId: 'prod-pvc-1inch', quantity: 5 },
            ], USER_ID)
        ).rejects.toThrow(/Cannot return items from a 'voided' invoice/);
    });

    test('should track already-returned quantities across multiple returns', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-hw-multi', status: 'paid', isDeleted: false,
            invoiceNumber: 'INV-000002',
        });
        mockQueryItems
            .mockResolvedValueOnce({
                items: [{
                    itemId: 'prod-pvc-1inch', name: 'PVC Pipe 1 inch',
                    quantity: 100, unitPriceCents: 4500, taxCents: 81000,
                }],
                lastKey: undefined,
            })
            // Existing credit notes
            .mockResolvedValueOnce({
                items: [{ id: 'cn-001', originalInvoiceId: 'inv-hw-multi', isDeleted: false }],
                lastKey: undefined,
            })
            // Already returned 80 feet
            .mockResolvedValueOnce({
                items: [{ itemId: 'prod-pvc-1inch', quantity: 80 }],
                lastKey: undefined,
            });

        await expect(
            invoiceService.createReturn(TENANT_ID, 'inv-hw-multi', [
                { itemId: 'prod-pvc-1inch', quantity: 25, reason: 'Excess material' },
            ], USER_ID)
        ).rejects.toThrow(/only 20 returnable \(100 sold, 80 already returned\)/);
    });
});

// ============================================================================
// 7. INVOICE VOID — State Machine
// ============================================================================
describe('HW-7: Invoice Void — State Machine', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('should reject voiding a draft invoice', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-draft', status: 'draft', paidCents: 0,
            totalCents: 100000, isDeleted: false,
        });

        await expect(
            invoiceService.voidInvoice(TENANT_ID, 'inv-draft', 'Wrong order')
        ).rejects.toThrow(/Cannot void a draft invoice/);
    });

    test('should reject voiding a paid invoice', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-paid', status: 'paid', paidCents: 100000,
            totalCents: 100000, isDeleted: false,
        });

        await expect(
            invoiceService.voidInvoice(TENANT_ID, 'inv-paid', 'Error')
        ).rejects.toThrow(/has already been collected/);
    });

    test('should allow voiding finalized invoice with zero payment', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-fin', status: 'finalized', paidCents: 0,
            totalCents: 100000, isDeleted: false,
            invoiceNumber: 'INV-000005', notes: '',
        });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.voidInvoice(TENANT_ID, 'inv-fin', 'Customer cancelled');
        expect(result.status).toBe('voided');
    });
});

// ============================================================================
// 8. CONTRACTOR CREDIT — Large Orders, Mixed Payment
// ============================================================================
describe('HW-8: Contractor Credit Orders', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 8 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should create large contractor invoice with notes', async () => {
        const products = [makeCementBag(), makeSteelBar(), makeSand()];
        mockBatchGetItems.mockResolvedValue(products);
        mockTransactWrite.mockResolvedValue(undefined);
        mockQueryItems.mockResolvedValueOnce({
            items: [{ id: 'cust-123', phone: '9876543210', creditLimitCents: 500000000 }],
            lastKey: undefined,
        });

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [
                { productId: 'prod-cement-50kg', quantity: 100, unitPrice: 38000 },
                { productId: 'prod-tmt-bar', quantity: 2000, unitPrice: 6500 },
                { productId: 'prod-sand', quantity: 1000, unitPrice: 5500 },
            ],
            customerName: 'Sharma Construction Co.',
            customerPhone: '9876543210',
            paymentMode: 'credit',
            notes: 'Site: Green Valley Phase 2. Credit 30 days.',
        });

        expect(result.id).toBeDefined();
        expect(result.itemsCount).toBe(3);
        // Very large total: cement(₹38k) + steel(₹1.3L) + sand(₹55k) = ₹2.23L before tax
        expect(result.subtotalCents).toBe(
            (100 * 38000) + (2000 * 6500) + (1000 * 5500)
        );
    });

    test('should handle partial payment finalization', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-contractor',
            status: 'draft',
            paidCents: 500000,  // ₹5,000 partial
            totalCents: 2000000, // ₹20,000 total
            isDeleted: false,
        });
        mockQueryItems.mockResolvedValue({
            items: [{ itemId: 'prod-cement-50kg', quantity: 50 }],
            lastKey: undefined,
        });
        mockUpdateItem.mockResolvedValue({});

        const result = await invoiceService.finalizeInvoice(TENANT_ID, 'inv-contractor');
        expect(result.status).toBe('partially_paid');
        expect(result.balanceCents).toBe(1500000);
    });
});

// ============================================================================
// 9. GST ROUNDING — Indian Compliance
// ============================================================================
describe('HW-9: GST Rounding Compliance', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 9 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should maintain golden invariant: subtotal + tax + roundOff = total', async () => {
        const products = [makeSand(), makePvcPipe(), makeCementBag(), makeWire()];
        mockBatchGetItems.mockResolvedValue(products);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [
                { productId: 'prod-sand', quantity: 200, unitPrice: 5500 },
                { productId: 'prod-pvc-1inch', quantity: 33.5, unitPrice: 4500 },
                { productId: 'prod-cement-50kg', quantity: 7, unitPrice: 38000 },
                { productId: 'prod-wire-2.5mm', quantity: 150.75, unitPrice: 1800 },
            ],
        });

        expect(result.subtotalCents + result.taxCents + result.roundOffCents)
            .toBe(result.totalCents);
        expect(Math.abs(result.roundOffCents)).toBeLessThanOrEqual(200);
    });

    test('should handle stress rounding — many fractional-price items', async () => {
        // 8 items at ₹33.33 each with 18% GST
        const products = Array.from({ length: 8 }, (_, i) =>
            makePvcPipe({
                id: `prod-frac-${i}`,
                SK: `PRODUCT#prod-frac-${i}`,
                name: `Fitting ${i}`,
                salePriceCents: 3333,
                mrpCents: 5000,
            })
        );
        mockBatchGetItems.mockResolvedValue(products);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: products.map(p => ({
                productId: p.id,
                quantity: 3,
                unitPrice: 3333,
            })),
        });

        expect(result.subtotalCents + result.taxCents + result.roundOffCents)
            .toBe(result.totalCents);
    });
});

// ============================================================================
// 10. ROLE-BASED ACCESS — Cashier vs Owner
// ============================================================================
describe('HW-10: Role-Based Access Control', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 10 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should NOT allow cashier to perform manager override on quantity limit', async () => {
        const product = makeCementBag({
            attributes: { maxSaleQuantity: '20' },
        });
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(
                TENANT_ID, USER_ID,
                {
                    items: [{ productId: 'prod-cement-50kg', quantity: 50, unitPrice: 38000 }],
                    metadata: { managerOverride: true },
                },
                'cashier', // NOT in OVERRIDE_ROLES
            )
        ).rejects.toThrow(/exceeds the maximum allowed quantity of 20/);
    });

    test('should allow owner override on quantity limit', async () => {
        const product = makeCementBag({
            attributes: { maxSaleQuantity: '20' },
        });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID, USER_ID,
            {
                items: [{ productId: 'prod-cement-50kg', quantity: 50, unitPrice: 38000 }],
                metadata: { managerOverride: true, overrideReason: 'Contractor bulk approved' },
            },
            'owner',
        );
        expect(result.id).toBeDefined();
    });
});

// ============================================================================
// 11. CUSTOM MEASUREMENT BILLING — Per-Foot Cutting
// ============================================================================
describe('HW-11: Custom Measurement Billing (Per-Foot Cutting)', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 11 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should bill custom-cut pipe: 3 pieces × 4.5 ft each = 13.5 ft total', async () => {
        const product = makePvcPipe();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        // Customer asks: "Cut me 3 pieces of 4.5 ft each"
        // Total = 3 × 4.5 = 13.5 ft
        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-pvc-1inch', quantity: 13.5, unitPrice: 4500 }],
            notes: 'Custom cut: 3 pcs × 4.5 ft',
        });

        expect(result.subtotalCents).toBe(60750); // 4500 × 13.5
    });

    test('should bill very small custom cut (0.5 ft = 6 inches)', async () => {
        const product = makePvcPipe();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-pvc-1inch', quantity: 0.5, unitPrice: 4500 }],
        });

        expect(result.subtotalCents).toBe(2250); // 4500 × 0.5
    });

    test('should bill mixed measurements: wire (mtr) + pipe (ft) + putty (kg)', async () => {
        const products = [makeWire(), makePvcPipe(), makeWallPutty()];
        mockBatchGetItems.mockResolvedValue(products);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [
                { productId: 'prod-wire-2.5mm', quantity: 50.5, unitPrice: 1800 },   // mtr
                { productId: 'prod-pvc-1inch', quantity: 22.75, unitPrice: 4500 },    // ft
                { productId: 'prod-wall-putty', quantity: 5.250, unitPrice: 2500 },   // kg
            ],
            customerName: 'Walk-in',
        });

        expect(result.id).toBeDefined();
        expect(result.itemsCount).toBe(3);
        // Verify exact subtotal: (50.5×1800) + (22.75×4500) + (5.25×2500)
        const expected = Math.round(50.5 * 1800) + Math.round(22.75 * 4500) + Math.round(5.25 * 2500);
        expect(result.subtotalCents).toBe(expected);
    });
});

// ============================================================================
// 12. EMPTY INVOICE & EDGE CASES
// ============================================================================
describe('HW-12: Edge Cases & Failure Modes', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 12 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should reject empty invoice (no items)', async () => {
        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [],
            })
        ).rejects.toThrow(/at least one item/i);
    });

    test('should reject product not found', async () => {
        mockBatchGetItems.mockResolvedValue([]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-nonexistent', quantity: 1, unitPrice: 1000 }],
            })
        ).rejects.toThrow(/Product not found/);
    });

    test('should handle duplicate product entries in same invoice', async () => {
        const product = makeCementBag();
        // batchGetItems deduplicates, so only one product returned
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [
                { productId: 'prod-cement-50kg', quantity: 5, unitPrice: 38000 },
                { productId: 'prod-cement-50kg', quantity: 3, unitPrice: 38000 },
            ],
        });

        expect(result.id).toBeDefined();
        expect(result.itemsCount).toBe(2); // Two line items, same product
    });
});

// ============================================================================
// 13. FIX-HW-002 — CONTRACTOR CREDIT LIMIT ENFORCEMENT
// ============================================================================
describe('HW-13: Contractor Credit Limit Enforcement (FIX-HW-002)', () => {
    /** enforceUdharCreditLimit loads customer via getItem — must match phone lookup id */
    function stubCustomerGetItem(customerId: string, creditLimitCents: number) {
        mockGetItem.mockImplementation((_pk: string, sk: string) => {
            if (sk === `CUSTOMER#${customerId}`) {
                return Promise.resolve({
                    id: customerId,
                    creditLimitCents,
                    creditMaxAgeDays: 0,
                    creditMaxOpenBills: 0,
                    isDeleted: false,
                });
            }
            return Promise.resolve(null);
        });
    }

    /** Real outstanding comes from UDHARTXN# ledger in enforceUdharCreditLimit */
    function stubUdharLedger(outstandingCents: number, customerId: string) {
        mockQueryAllItems.mockImplementation((_pk, skPrefix) => {
            const p = String(skPrefix || '');
            if (p.startsWith('UDHARTXN')) {
                if (outstandingCents <= 0) return Promise.resolve([]);
                return Promise.resolve([{
                    type: 'given',
                    amountCents: outstandingCents,
                    udharPersonId: customerId,
                    isDeleted: false,
                }]);
            }
            if (p.startsWith('INVOICE')) {
                return Promise.resolve([]);
            }
            return Promise.resolve([]);
        });
    }

    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 13 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
        mockGetItem.mockResolvedValue(null);
        mockQueryAllItems.mockResolvedValue([]);
    });

    test('T3a: should reject credit invoice exceeding credit limit (enforceCreditLimit=true)', async () => {
        const product = makeCementBag();
        mockBatchGetItems.mockResolvedValue([product]);
        stubCustomerGetItem('cust-001', 200000);
        stubUdharLedger(0, 'cust-001');
        mockQueryItems
            .mockResolvedValue({ // customer lookup (credit check)
                items: [{
                    id: 'cust-001',
                    phone: '9876543210',
                    creditLimitCents: 200000,
                    outstandingBalanceCents: 0,
                    isDeleted: false,
                }],
                lastKey: undefined,
            });

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-cement-50kg', quantity: 50, unitPrice: 38000 }],
                paymentMode: 'credit',
                customerPhone: '9876543210',
                customerName: 'Sharma Builders',
                metadata: { enforceCreditLimit: true },
            })
        ).rejects.toThrow(/exceeds available credit/);
    });

    test('T3b: should reject when outstanding + invoice > creditLimit', async () => {
        const product = makePvcPipe();
        mockBatchGetItems.mockResolvedValue([product]);
        stubCustomerGetItem('cust-002', 200000);
        stubUdharLedger(150000, 'cust-002');
        mockQueryItems
            .mockResolvedValue({
                items: [{
                    id: 'cust-002',
                    phone: '9876543211',
                    creditLimitCents: 200000,
                    outstandingBalanceCents: 150000,
                    isDeleted: false,
                }],
                lastKey: undefined,
            });

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-pvc-1inch', quantity: 10, unitPrice: 4500 }],
                paymentMode: 'credit',
                customerPhone: '9876543211',
                metadata: { enforceCreditLimit: true },
            })
        ).rejects.toThrow(/exceeds available credit/);
    });

    test('T3c: should allow credit invoice at exactly credit limit (edge)', async () => {
        const product = makeCementBag();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);
        stubCustomerGetItem('cust-edge', 5000000);
        stubUdharLedger(0, 'cust-edge');
        mockQueryItems
            .mockResolvedValueOnce({
                items: [{
                    id: 'cust-edge',
                    phone: '9876543212',
                    creditLimitCents: 5000000,
                    outstandingBalanceCents: 0,
                    isDeleted: false,
                }],
                lastKey: undefined,
            });

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-cement-50kg', quantity: 1, unitPrice: 38000 }],
            paymentMode: 'credit',
            customerPhone: '9876543212',
            metadata: { enforceCreditLimit: true },
        });

        expect(result.id).toBeDefined();
    });

    test('T3d: should warn but allow when enforceCreditLimit is false (flag OFF)', async () => {
        const product = makeCementBag();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);
        stubCustomerGetItem('cust-003', 100000);
        stubUdharLedger(0, 'cust-003');
        mockQueryItems
            .mockResolvedValue({
                items: [{
                    id: 'cust-003',
                    phone: '9876543213',
                    creditLimitCents: 100000,
                    outstandingBalanceCents: 0,
                    isDeleted: false,
                }],
                lastKey: undefined,
            });

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-cement-50kg', quantity: 50, unitPrice: 38000 }],
            paymentMode: 'credit',
            customerPhone: '9876543213',
        });

        expect(result.id).toBeDefined();
        const creditWarning = result.warnings?.find(w => w.type === 'CREDIT_LIMIT_EXCEEDED');
        expect(creditWarning).toBeDefined();
    });

    test('T3e: CreditLimitExceededError has correct structured fields', async () => {
        const product = makePvcPipe();
        mockBatchGetItems.mockResolvedValue([product]);
        stubCustomerGetItem('cust-fields', 100000);
        stubUdharLedger(50000, 'cust-fields');
        mockQueryItems
            .mockResolvedValue({
                items: [{
                    id: 'cust-fields',
                    phone: '9876543214',
                    creditLimitCents: 100000,
                    outstandingBalanceCents: 50000,
                    isDeleted: false,
                }],
                lastKey: undefined,
            });

        try {
            await invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-pvc-1inch', quantity: 100, unitPrice: 4500 }],
                paymentMode: 'credit',
                customerPhone: '9876543214',
                metadata: { enforceCreditLimit: true },
            });
            throw new Error('Should have thrown');
        } catch (err: any) {
            if (err.message === 'Should have thrown') throw err;
            expect(err.name).toBe('CreditLimitExceededError');
            expect(err.code).toBe('CREDIT_LIMIT_EXCEEDED');
            expect(err.creditLimitCents).toBe(100000);
            expect(err.outstandingBalanceCents).toBe(50000);
            expect(err.availableCreditCents).toBe(50000);
            expect(err.invoiceTotalCents).toBeGreaterThan(50000);
        }
    });
});

// ============================================================================
// 14. FIX-HW-003 — CONCURRENT STOCK DEDUCTION REGRESSION GUARD
// ============================================================================
describe('HW-14: Concurrent Stock Regression Guard (FIX-HW-003)', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 14 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('T4a: should return STOCK_CONFLICT code on TransactionCanceledException', async () => {
        const product = makeCementBag({ currentStock: 5 });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockRejectedValue(
            Object.assign(new Error('Transaction cancelled'), {
                name: 'TransactionCanceledException',
                CancellationReasons: [
                    { Code: 'None' }, // invoice record
                    { Code: 'ConditionalCheckFailed' }, // stock deduction
                ],
            })
        );

        try {
            await invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-cement-50kg', quantity: 3, unitPrice: 38000 }],
            });
            fail('Should have thrown');
        } catch (err: any) {
            expect(err.statusCode).toBe(409);
            expect(err.code).toBe('STOCK_CONFLICT');
            expect(err.retryable).toBe(true);
            expect(err.message).toMatch(/concurrent sale detected/);
        }
    });

    test('T4b: should include REGRESSION GUARD comment on ConditionExpression', async () => {
        const product = makeCementBag({ currentStock: 10 });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-cement-50kg', quantity: 2, unitPrice: 38000 }],
        });

        // Verify the ConditionExpression is present in the transactWrite call
        const transactCall = mockTransactWrite.mock.calls[0][0];
        const stockUpdate = transactCall.find((item: any) =>
            item.Update?.UpdateExpression?.includes('currentStock')
        );
        expect(stockUpdate).toBeDefined();
        expect(stockUpdate.Update.ConditionExpression).toBe('currentStock >= :qty');
    });
});

// ============================================================================
// 15. FIX-HW-004 — UOM VALIDATION
// ============================================================================
describe('HW-15: UOM Validation (FIX-HW-004)', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 15 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('T5a: should reject billing PVC pipe in kg (base unit is ft)', async () => {
        const product = makePvcPipe(); // unit = 'ft'
        mockBatchGetItems.mockResolvedValue([product]);

        try {
            await invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-pvc-1inch', quantity: 5, unitPrice: 4500, unit: 'kg' }],
            });
            fail('Should have thrown UnitMismatchError');
        } catch (err: any) {
            expect(err.name).toBe('UnitMismatchError');
            expect(err.code).toBe('UNIT_MISMATCH');
            expect(err.productId).toBe('prod-pvc-1inch');
            expect(err.expectedUnit).toBe('ft');
            expect(err.receivedUnit).toBe('kg');
        }
    });

    test('T5b: should reject billing wire in ft (base unit is mtr)', async () => {
        const product = makeWire(); // unit = 'mtr'
        mockBatchGetItems.mockResolvedValue([product]);

        try {
            await invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-wire-2.5mm', quantity: 10, unitPrice: 1800, unit: 'ft' }],
            });
            fail('Should have thrown UnitMismatchError');
        } catch (err: any) {
            expect(err.name).toBe('UnitMismatchError');
            expect(err.code).toBe('UNIT_MISMATCH');
            expect(err.expectedUnit).toBe('mtr');
            expect(err.receivedUnit).toBe('ft');
        }
    });

    test('T5c: owner should bill pipe in pieces with conversionFactor=6 (6ft/piece)', async () => {
        const product = makePvcPipe({ currentStock: 100 }); // unit = 'ft'
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID, USER_ID,
            {
                items: [{
                    productId: 'prod-pvc-1inch',
                    quantity: 5,           // 5 pieces
                    unitPrice: 27000,      // ₹270/piece
                    unit: 'pcs',           // mismatch: base is 'ft'
                    conversionFactor: 6,   // each piece = 6ft
                }],
            },
            'owner', // Required for unit override
        );

        expect(result.id).toBeDefined();
        // Stock deduction should be 5 * 6 = 30 ft
        const transactCall = mockTransactWrite.mock.calls[0][0];
        const stockUpdate = transactCall.find((item: any) =>
            item.Update?.UpdateExpression?.includes('currentStock')
        );
        expect(stockUpdate.Update.ExpressionAttributeValues[':qty']).toBe(30);
        // Check unit conversion warning
        const conversionWarning = result.warnings?.find(w => w.type === 'UNIT_CONVERSION');
        expect(conversionWarning).toBeDefined();
    });

    test('T5d: cashier should NOT be able to use unit override', async () => {
        const product = makePvcPipe(); // unit = 'ft'
        mockBatchGetItems.mockResolvedValue([product]);

        try {
            await invoiceService.createInvoice(
                TENANT_ID, USER_ID,
                {
                    items: [{
                        productId: 'prod-pvc-1inch',
                        quantity: 5,
                        unitPrice: 27000,
                        unit: 'pcs',
                        conversionFactor: 6,
                    }],
                },
                'cashier', // NOT in OVERRIDE_ROLES
            );
            fail('Should have thrown');
        } catch (err: any) {
            expect(err.name).toBe('UnitMismatchError');
            expect(err.statusCode).toBe(403);
            expect(err.code).toBe('UNIT_MISMATCH');
        }
    });

    test('T5e: should pass when item.unit matches product.unit exactly', async () => {
        const product = makePvcPipe();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-pvc-1inch', quantity: 10, unitPrice: 4500, unit: 'ft' }],
        });

        expect(result.id).toBeDefined();
    });

    test('T5f: should skip UOM check when item.unit is not provided (backward compat)', async () => {
        const product = makePvcPipe();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-pvc-1inch', quantity: 10, unitPrice: 4500 }], // no unit
        });

        expect(result.id).toBeDefined();
    });
});

// ============================================================================
// 16. FIX-HW-005 — IGST MULTI-SLAB COVERAGE + MUTUAL EXCLUSIVITY
// ============================================================================
describe('HW-16: IGST Multi-Slab Coverage (FIX-HW-005)', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 16 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should calculate IGST correctly for sand (5%) inter-state', async () => {
        const product = makeSand();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-sand', quantity: 200, unitPrice: 5500 }],
            isInterState: true,
            customerGstin: '29AABCU9603R1ZM',
        });

        expect(result.id).toBeDefined();
        // IGST = 5% of 200×5500 = 5% of 1100000 = 55000
        expect(result.taxCents).toBe(55000);
        expect(result.subtotalCents + result.taxCents + result.roundOffCents)
            .toBe(result.totalCents);
        // CGST/SGST must be 0 for inter-state
        expect(result.cgstCents).toBe(0);
        expect(result.sgstCents).toBe(0);
    });

    test('should calculate IGST correctly for PVC pipe (18%) inter-state', async () => {
        const product = makePvcPipe();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-pvc-1inch', quantity: 50, unitPrice: 4500 }],
            isInterState: true,
            customerGstin: '29AABCU9603R1ZM',
        });

        expect(result.id).toBeDefined();
        // IGST = 18% of 50×4500 = 18% of 225000 = 40500
        expect(result.taxCents).toBe(40500);
        expect(result.subtotalCents + result.taxCents + result.roundOffCents)
            .toBe(result.totalCents);
    });

    test('should calculate mixed 5%+18%+28% IGST in single inter-state invoice', async () => {
        const products = [makeSand(), makePvcPipe(), makeCementBag()];
        mockBatchGetItems.mockResolvedValue(products);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [
                { productId: 'prod-sand', quantity: 100, unitPrice: 5500 },        // 5% IGST
                { productId: 'prod-pvc-1inch', quantity: 20, unitPrice: 4500 },    // 18% IGST
                { productId: 'prod-cement-50kg', quantity: 5, unitPrice: 38000 },  // 28% IGST
            ],
            isInterState: true,
            customerGstin: '29AABCU9603R1ZM',
        });

        expect(result.id).toBeDefined();
        // Golden invariant
        expect(result.subtotalCents + result.taxCents + result.roundOffCents)
            .toBe(result.totalCents);
        // CGST/SGST must be 0
        expect(result.cgstCents).toBe(0);
        expect(result.sgstCents).toBe(0);
        // IGST must be positive
        expect(result.igstCents).toBeGreaterThan(0);
    });

    test('intra-state: IGST must be 0, CGST/SGST must be non-zero', async () => {
        const product = makeCementBag();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-cement-50kg', quantity: 1, unitPrice: 38000 }],
            // No isInterState → intra-state
        });

        expect(result.igstCents).toBe(0);
        expect(result.cgstCents).toBeGreaterThan(0);
        expect(result.sgstCents).toBeGreaterThan(0);
        // CGST + SGST = total tax (no IGST)
        expect(result.cgstCents + result.sgstCents).toBe(result.taxCents);
    });

    test('FIX-HW-001: CGST/SGST floor+remainder pattern — cgst + sgst = tax exactly', async () => {
        // Use an item where tax is odd paise (forces floor vs ceil divergence)
        const product = makePvcPipe({
            id: 'prod-odd-tax',
            SK: 'PRODUCT#prod-odd-tax',
            name: 'Odd Tax Item',
            salePriceCents: 3333, // ₹33.33 → 18% = 599.94 → round per-line=600
            mrpCents: 5000,
        });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-odd-tax', quantity: 1, unitPrice: 3333 }],
        });

        // Key assertion: cgst + sgst must equal total taxCents exactly
        expect(result.cgstCents + result.sgstCents).toBe(result.taxCents);
        expect(result.igstCents).toBe(0);
        expect(result.subtotalCents + result.taxCents + result.roundOffCents)
            .toBe(result.totalCents);
    });
});



