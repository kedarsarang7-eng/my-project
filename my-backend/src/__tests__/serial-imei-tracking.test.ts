// ============================================================================
// Serial/IMEI Tracking Tests — Consumer Protection Act Compliance
// ============================================================================
// Tests for IMEI/serial number enforcement on electronics and mobile_shop
// business types. Verifies:
//   (a) sale without IMEI on mobile_shop rejected
//   (b) duplicate IMEI rejected
//   (c) accessory sold without IMEI succeeds
//   (d) serial lookup returns correct invoice
//   (e) electronics without serial number rejected
//   (f) service items exempt from serial requirement
//   (g) IMEI format validation via Zod schema
//
// Run with: npx jest src/__tests__/serial-imei-tracking.test.ts
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { BusinessType } from '../types/tenant.types';

// ---- Mock Auth ----
const mockVerifyAuth = jest.fn().mockResolvedValue({
    sub: 'test-user-id',
    email: 'test@example.com',
    tenantId: 'test-tenant-id',
    role: 'owner',
    businessType: 'electronics',
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
        hsnMasterSK: (h: string) => `HSN#${h}`,
        serialTrackSK: (id: string) => `SERIAL#${id}`,
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

function makeElectronicsProduct(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-tv-001',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-tv-001',
        name: 'Samsung 55" Smart TV',
        salePriceCents: 5500000,
        currentStock: 10,
        lowStockThreshold: 2,
        cgstRateBp: 900,
        sgstRateBp: 900,
        isDeleted: false,
        isService: false,
        unit: 'pcs',
        category: 'television',
        hsnCode: '85287100',
        attributes: {},
        ...overrides,
    };
}

function makeMobileProduct(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-phone-001',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-phone-001',
        name: 'iPhone 16 Pro',
        salePriceCents: 13490000,
        currentStock: 15,
        lowStockThreshold: 3,
        cgstRateBp: 900,
        sgstRateBp: 900,
        isDeleted: false,
        isService: false,
        unit: 'pcs',
        category: 'smartphone',
        hsnCode: '85171290',
        attributes: {},
        ...overrides,
    };
}

function makeAccessoryProduct(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-case-001',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-case-001',
        name: 'iPhone Case - Clear',
        salePriceCents: 99900,
        currentStock: 50,
        lowStockThreshold: 5,
        cgstRateBp: 900,
        sgstRateBp: 900,
        isDeleted: false,
        isService: false,
        unit: 'pcs',
        category: 'accessory',
        hsnCode: '39269099',
        attributes: {},
        ...overrides,
    };
}

function makeServiceProduct(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-svc-001',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-svc-001',
        name: 'Screen Repair Service',
        salePriceCents: 250000,
        currentStock: 999,
        lowStockThreshold: 0,
        cgstRateBp: 900,
        sgstRateBp: 900,
        isDeleted: false,
        isService: true,
        unit: 'pcs',
        category: 'service',
        attributes: {},
        ...overrides,
    };
}

// ============================================================================
// Import the service (after mocks are set up)
// ============================================================================

import * as invoiceService from '../services/invoice.service';
import { InvoiceValidationError } from '../utils/errors';

// ============================================================================
// TEST 1: MOBILE_SHOP WITHOUT IMEI REJECTED
// ============================================================================
describe('SERIAL-001: Mobile Shop IMEI Enforcement', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 1 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should reject sale without IMEI on mobile_shop for non-accessory product', async () => {
        const product = makeMobileProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(
                TENANT_ID, USER_ID,
                {
                    items: [{
                        productId: 'prod-phone-001',
                        quantity: 1,
                        unitPrice: 13490000,
                        // Missing imei1
                    }],
                },
                'cashier',
                BusinessType.MOBILE_SHOP,
            )
        ).rejects.toThrow(/IMEI number is required/);
    });

    test('should reject sale with empty IMEI string on mobile_shop', async () => {
        const product = makeMobileProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(
                TENANT_ID, USER_ID,
                {
                    items: [{
                        productId: 'prod-phone-001',
                        quantity: 1,
                        unitPrice: 13490000,
                        imei1: '   ', // Whitespace-only
                    }],
                },
                'cashier',
                BusinessType.MOBILE_SHOP,
            )
        ).rejects.toThrow(/IMEI number is required/);
    });

    test('should throw InvoiceValidationError (not InvoiceError) for missing IMEI', async () => {
        const product = makeMobileProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        try {
            await invoiceService.createInvoice(
                TENANT_ID, USER_ID,
                {
                    items: [{
                        productId: 'prod-phone-001',
                        quantity: 1,
                        unitPrice: 13490000,
                    }],
                },
                'cashier',
                BusinessType.MOBILE_SHOP,
            );
            fail('Expected InvoiceValidationError');
        } catch (err: any) {
            expect(err).toBeInstanceOf(InvoiceValidationError);
            expect(err.statusCode).toBe(422);
            expect(err.code).toBe('INVOICE_VALIDATION_ERROR');
            expect(err.details).toMatchObject({ field: 'imei1' });
        }
    });

    test('should allow sale with valid IMEI on mobile_shop', async () => {
        const product = makeMobileProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID, USER_ID,
            {
                items: [{
                    productId: 'prod-phone-001',
                    quantity: 1,
                    unitPrice: 13490000,
                    imei1: '123456789012345',
                }],
            },
            'cashier',
            BusinessType.MOBILE_SHOP,
        );

        expect(result.id).toBeDefined();
        expect(result.invoiceNumber).toMatch(/^INV-/);

        // Verify SERIALTRACK# record was included in transactWrite
        const transactCall = mockTransactWrite.mock.calls[0][0];
        const serialTrackPut = transactCall.find(
            (op: any) => op.Put?.Item?.entityType === 'SERIALTRACK',
        );
        expect(serialTrackPut).toBeDefined();
        expect(serialTrackPut.Put.Item.imei1).toBe('123456789012345');
        expect(serialTrackPut.Put.Item.productName).toBe('iPhone 16 Pro');
        expect(serialTrackPut.Put.ConditionExpression).toBe('attribute_not_exists(SK)');
    });
});

// ============================================================================
// TEST 2: DUPLICATE IMEI REJECTED
// ============================================================================
describe('SERIAL-002: Duplicate IMEI/Serial Prevention', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 2 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should reject duplicate IMEI sale via TransactionCanceledException', async () => {
        const product = makeMobileProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        // Simulate TransactionCanceledException with ConditionalCheckFailed on SERIAL# key
        const txError: any = new Error('Transaction cancelled');
        txError.name = 'TransactionCanceledException';
        txError.CancellationReasons = [
            { Code: 'None' }, // stock deduction — OK
            { Code: 'None' }, // invoice header — OK
            { Code: 'None' }, // line item — OK
            { Code: 'ConditionalCheckFailed' }, // SERIALTRACK# — DUPLICATE
        ];
        mockTransactWrite.mockRejectedValue(txError);

        // We need to also mock what transactItems looks like when the error is thrown.
        // The service builds transactItems internally, so we can't directly control indices.
        // Instead, verify that the error is thrown with the right message pattern.
        await expect(
            invoiceService.createInvoice(
                TENANT_ID, USER_ID,
                {
                    items: [{
                        productId: 'prod-phone-001',
                        quantity: 1,
                        unitPrice: 13490000,
                        imei1: '123456789012345',
                    }],
                },
                'cashier',
                BusinessType.MOBILE_SHOP,
            )
        ).rejects.toThrow(/already been sold|concurrent/i);
    });
});

// ============================================================================
// TEST 3: ACCESSORY SOLD WITHOUT IMEI SUCCEEDS
// ============================================================================
describe('SERIAL-003: Accessory Exemption', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 3 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should allow accessory sale without IMEI on mobile_shop', async () => {
        const accessory = makeAccessoryProduct();
        mockBatchGetItems.mockResolvedValue([accessory]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID, USER_ID,
            {
                items: [{
                    productId: 'prod-case-001',
                    quantity: 2,
                    unitPrice: 99900,
                    // No IMEI — should be fine for accessories
                }],
            },
            'cashier',
            BusinessType.MOBILE_SHOP,
        );

        expect(result.id).toBeDefined();
        expect(result.invoiceNumber).toMatch(/^INV-/);
    });

    test('should allow accessory sale without serial number on electronics', async () => {
        const accessory = makeAccessoryProduct({
            id: 'prod-cable-001',
            SK: 'PRODUCT#prod-cable-001',
            name: 'HDMI Cable 2m',
        });
        mockBatchGetItems.mockResolvedValue([accessory]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID, USER_ID,
            {
                items: [{
                    productId: 'prod-cable-001',
                    quantity: 1,
                    unitPrice: 50000,
                    // No serialNumber — accessory exempt
                }],
            },
            'cashier',
            BusinessType.ELECTRONICS,
        );

        expect(result.id).toBeDefined();
    });
});

// ============================================================================
// TEST 4: SERIAL LOOKUP RETURNS CORRECT INVOICE
// ============================================================================
describe('SERIAL-004: Serial Lookup Endpoint', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('should return product and invoice details for a tracked serial number', async () => {
        // This tests the serialLookup handler via the service layer.
        // The handler calls getItem on SERIAL#{serial}, so we mock that.
        mockGetItem.mockResolvedValue({
            PK: 'TENANT#test-tenant-id',
            SK: 'SERIAL#SN-TV-2026-001',
            entityType: 'SERIALTRACK',
            serialNumber: 'SN-TV-2026-001',
            imei1: null,
            imei2: null,
            productId: 'prod-tv-001',
            productName: 'Samsung 55" Smart TV',
            invoiceId: 'inv-abc-123',
            invoiceNumber: 'INV-000042',
            customerName: 'Rajesh Kumar',
            customerPhone: '+919876543210',
            soldAt: '2026-04-11T10:00:00.000Z',
            warrantyExpiryDate: null,
        });

        // Import inventory handler (serialLookup)
        const { serialLookup } = await import('../handlers/inventory');

        const event = {
            version: '2.0',
            routeKey: 'GET /inventory/serial-lookup',
            rawPath: '/inventory/serial-lookup',
            rawQueryString: 'serial=SN-TV-2026-001',
            headers: { authorization: 'Bearer test-token' },
            queryStringParameters: { serial: 'SN-TV-2026-001' },
            requestContext: {
                accountId: 'local', apiId: 'local', domainName: 'localhost', domainPrefix: '',
                http: { method: 'GET', path: '/inventory/serial-lookup', protocol: 'https', sourceIp: '127.0.0.1', userAgent: 'test' },
                requestId: 'test-req', routeKey: 'GET /inventory/serial-lookup', stage: '$default',
                time: new Date().toISOString(), timeEpoch: Date.now(),
            },
        } as unknown as APIGatewayProxyEventV2;

        const context = {} as Context;
        const result: any = await serialLookup(event, context);
        const body = JSON.parse(result.body);

        expect(result.statusCode).toBe(200);
        expect(body.data.serialNumber).toBe('SN-TV-2026-001');
        expect(body.data.productName).toBe('Samsung 55" Smart TV');
        expect(body.data.soldInvoiceId).toBe('inv-abc-123');
        expect(body.data.invoiceNumber).toBe('INV-000042');
        expect(body.data.customerName).toBe('Rajesh Kumar');
        expect(body.data.soldAt).toBe('2026-04-11T10:00:00.000Z');
    });

    test('should return 404 for unknown serial number', async () => {
        mockGetItem.mockResolvedValue(null);

        const { serialLookup } = await import('../handlers/inventory');

        const event = {
            version: '2.0',
            routeKey: 'GET /inventory/serial-lookup',
            rawPath: '/inventory/serial-lookup',
            rawQueryString: 'serial=UNKNOWN-123',
            headers: { authorization: 'Bearer test-token' },
            queryStringParameters: { serial: 'UNKNOWN-123' },
            requestContext: {
                accountId: 'local', apiId: 'local', domainName: 'localhost', domainPrefix: '',
                http: { method: 'GET', path: '/inventory/serial-lookup', protocol: 'https', sourceIp: '127.0.0.1', userAgent: 'test' },
                requestId: 'test-req', routeKey: 'GET /inventory/serial-lookup', stage: '$default',
                time: new Date().toISOString(), timeEpoch: Date.now(),
            },
        } as unknown as APIGatewayProxyEventV2;

        const context = {} as Context;
        const result: any = await serialLookup(event, context);

        expect(result.statusCode).toBe(404);
    });
});

// ============================================================================
// TEST 5: ELECTRONICS WITHOUT SERIAL NUMBER REJECTED
// ============================================================================
describe('SERIAL-005: Electronics Serial Number Enforcement', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 5 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should reject sale without serialNumber on electronics for non-accessory', async () => {
        const product = makeElectronicsProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(
                TENANT_ID, USER_ID,
                {
                    items: [{
                        productId: 'prod-tv-001',
                        quantity: 1,
                        unitPrice: 5500000,
                        // Missing serialNumber
                    }],
                },
                'cashier',
                BusinessType.ELECTRONICS,
            )
        ).rejects.toThrow(/Serial number is required/);
    });

    test('should allow sale with serialNumber on electronics', async () => {
        const product = makeElectronicsProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID, USER_ID,
            {
                items: [{
                    productId: 'prod-tv-001',
                    quantity: 1,
                    unitPrice: 5500000,
                    serialNumber: 'SN-TV-2026-001',
                }],
            },
            'cashier',
            BusinessType.ELECTRONICS,
        );

        expect(result.id).toBeDefined();

        // Verify SERIALTRACK# was created with serial number
        const transactCall = mockTransactWrite.mock.calls[0][0];
        const serialTrackPut = transactCall.find(
            (op: any) => op.Put?.Item?.entityType === 'SERIALTRACK',
        );
        expect(serialTrackPut).toBeDefined();
        expect(serialTrackPut.Put.Item.serialNumber).toBe('SN-TV-2026-001');
        expect(serialTrackPut.Put.Item.SK).toBe('SERIAL#SN-TV-2026-001');
    });
});

// ============================================================================
// TEST 6: SERVICE ITEMS EXEMPT FROM SERIAL REQUIREMENT
// ============================================================================
describe('SERIAL-006: Service Item Exemption', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 6 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should allow service item sale without serial on electronics', async () => {
        const service = makeServiceProduct();
        mockBatchGetItems.mockResolvedValue([service]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID, USER_ID,
            {
                items: [{
                    productId: 'prod-svc-001',
                    quantity: 1,
                    unitPrice: 250000,
                    // No serialNumber — service exempt
                }],
            },
            'cashier',
            BusinessType.ELECTRONICS,
        );

        expect(result.id).toBeDefined();
    });

    test('should allow service item sale without IMEI on mobile_shop', async () => {
        const service = makeServiceProduct();
        mockBatchGetItems.mockResolvedValue([service]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID, USER_ID,
            {
                items: [{
                    productId: 'prod-svc-001',
                    quantity: 1,
                    unitPrice: 250000,
                    // No imei1 — service exempt
                }],
            },
            'cashier',
            BusinessType.MOBILE_SHOP,
        );

        expect(result.id).toBeDefined();
    });
});

// ============================================================================
// TEST 7: IMEI FORMAT VALIDATION (ZOD SCHEMA LEVEL)
// ============================================================================
describe('SERIAL-007: IMEI Format Validation (Zod)', () => {
    test('should accept valid 15-digit IMEI in schema', () => {
        const { createInvoiceSchema } = require('../schemas');
        const result = createInvoiceSchema.safeParse({
            items: [{
                productId: '550e8400-e29b-41d4-a716-446655440000',
                name: 'Test Phone',
                quantity: 1,
                unitPriceCents: 1000000,
                imei1: '123456789012345',
            }],
        });
        expect(result.success).toBe(true);
    });

    test('should reject 14-digit IMEI', () => {
        const { createInvoiceSchema } = require('../schemas');
        const result = createInvoiceSchema.safeParse({
            items: [{
                productId: '550e8400-e29b-41d4-a716-446655440000',
                name: 'Test Phone',
                quantity: 1,
                unitPriceCents: 1000000,
                imei1: '12345678901234', // 14 digits
            }],
        });
        expect(result.success).toBe(false);
    });

    test('should reject 16-digit IMEI', () => {
        const { createInvoiceSchema } = require('../schemas');
        const result = createInvoiceSchema.safeParse({
            items: [{
                productId: '550e8400-e29b-41d4-a716-446655440000',
                name: 'Test Phone',
                quantity: 1,
                unitPriceCents: 1000000,
                imei1: '1234567890123456', // 16 digits
            }],
        });
        expect(result.success).toBe(false);
    });

    test('should reject IMEI with letters', () => {
        const { createInvoiceSchema } = require('../schemas');
        const result = createInvoiceSchema.safeParse({
            items: [{
                productId: '550e8400-e29b-41d4-a716-446655440000',
                name: 'Test Phone',
                quantity: 1,
                unitPriceCents: 1000000,
                imei1: '12345678901234A', // Contains letter
            }],
        });
        expect(result.success).toBe(false);
    });

    test('should allow omitting IMEI fields entirely', () => {
        const { createInvoiceSchema } = require('../schemas');
        const result = createInvoiceSchema.safeParse({
            items: [{
                productId: '550e8400-e29b-41d4-a716-446655440000',
                name: 'Test Phone',
                quantity: 1,
                unitPriceCents: 1000000,
                // No imei1, imei2, or serialNumber — all optional at schema level
            }],
        });
        expect(result.success).toBe(true);
    });
});

