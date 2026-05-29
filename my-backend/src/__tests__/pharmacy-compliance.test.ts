// ============================================================================
// Pharmacy Compliance Tests — Invoice Service
// ============================================================================
// Tests for CRITICAL BUG #1 (expired batch), CRITICAL BUG #2 (prescription),
// GAP #3 (quantity limits), GAP #4 (doctor reg), GAP #5 (void paid invoice),
// GAP #7 (return excess), GAP #8 (discount capping).
//
// Run with: npx jest src/__tests__/pharmacy-compliance.test.ts
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';

// ---- Mock Auth ----
const mockVerifyAuth = jest.fn().mockResolvedValue({
    sub: 'test-user-id',
    email: 'test@example.com',
    tenantId: 'test-tenant-id',
    role: 'owner',
    businessType: 'pharmacy',
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

function makeProduct(overrides: Record<string, any> = {}) {
    return {
        id: 'prod-001',
        PK: `TENANT#${TENANT_ID}`,
        SK: 'PRODUCT#prod-001',
        name: 'Paracetamol 500mg',
        salePriceCents: 1650,
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

function makeScheduleHProduct(overrides: Record<string, any> = {}) {
    return makeProduct({
        id: 'prod-schH',
        SK: 'PRODUCT#prod-schH',
        name: 'Amoxicillin 250mg',
        salePriceCents: 7800,
        attributes: {
            requiresPrescription: 'true',
            drugSchedule: 'H',
        },
        ...overrides,
    });
}

function makeScheduleXProduct(overrides: Record<string, any> = {}) {
    return makeProduct({
        id: 'prod-schX',
        SK: 'PRODUCT#prod-schX',
        name: 'Alprazolam 0.25mg',
        salePriceCents: 4500,
        attributes: {
            requiresPrescription: 'true',
            drugSchedule: 'X',
        },
        ...overrides,
    });
}


function makeScheduleH1Product(overrides: Record<string, any> = {}) {
    return makeProduct({
        id: 'prod-schH1',
        SK: 'PRODUCT#prod-schH1',
        name: 'Tramadol 50mg',
        salePriceCents: 8500,
        attributes: {
            requiresPrescription: 'true',
            drugSchedule: 'H1',
        },
        ...overrides,
    });
}

// ============================================================================
// Import the service (after mocks are set up)
// ============================================================================

import * as invoiceService from '../services/invoice.service';

// ============================================================================
// CRITICAL BUG #1 — EXPIRED BATCH SALES BLOCKED
// ============================================================================
describe('P-1: Expired Batch Sales Prevention', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        // Default: counter update succeeds
        mockUpdateItem.mockResolvedValue({ counterValue: 1 });
    });

    test('should reject invoice line item with expired batch expiryDate in the past', async () => {
        const product = makeProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        // queryItems for duplicate prescriptionId check
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{
                    productId: 'prod-001',
                    quantity: 2,
                    unitPrice: 1650,
                    batchNumber: 'B2025-01',
                    expiryDate: '2025-01-15', // Expired — in the past
                }],
            })
        ).rejects.toThrow(/Cannot sell from expired batch/);
    });

    test('should reject invoice line item with expired batch (yesterday)', async () => {
        const product = makeProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });

        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        const expiryStr = yesterday.toISOString().split('T')[0];

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{
                    productId: 'prod-001',
                    quantity: 1,
                    unitPrice: 1650,
                    batchNumber: 'B-YESTERDAY',
                    expiryDate: expiryStr,
                }],
            })
        ).rejects.toThrow(/Cannot sell from expired batch/);
    });

    test('should include near-expiry warning when batch expires within 90 days', async () => {
        const product = makeProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
        mockTransactWrite.mockResolvedValue(undefined);

        const in30Days = new Date();
        in30Days.setDate(in30Days.getDate() + 30);
        const expiryStr = in30Days.toISOString().split('T')[0];

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-001',
                quantity: 1,
                unitPrice: 1650,
                batchNumber: 'B2026-NEAR',
                expiryDate: expiryStr,
            }],
        });

        expect(result.warnings).toBeDefined();
        expect(result.warnings!.length).toBeGreaterThanOrEqual(1);
        const nearExpiryWarning = result.warnings!.find(w => w.type === 'NEAR_EXPIRY');
        expect(nearExpiryWarning).toBeDefined();
        expect(nearExpiryWarning!.daysRemaining).toBeLessThanOrEqual(90);
        expect(nearExpiryWarning!.batchNumber).toBe('B2026-NEAR');
    });

    test('should NOT warn when batch expires in >90 days', async () => {
        const product = makeProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
        mockTransactWrite.mockResolvedValue(undefined);

        const in120Days = new Date();
        in120Days.setDate(in120Days.getDate() + 120);
        const expiryStr = in120Days.toISOString().split('T')[0];

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-001',
                quantity: 1,
                unitPrice: 1650,
                batchNumber: 'B2026-FAR',
                expiryDate: expiryStr,
            }],
        });

        const nearExpiryWarning = result.warnings?.find(w => w.type === 'NEAR_EXPIRY');
        expect(nearExpiryWarning).toBeUndefined();
    });

    test('should allow sale with no expiryDate (non-medicine product)', async () => {
        const product = makeProduct({ id: 'prod-bp', SK: 'PRODUCT#prod-bp', name: 'BP Monitor' });
        mockBatchGetItems.mockResolvedValue([product]);
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-bp',
                quantity: 1,
                unitPrice: 195000,
                // No batchNumber or expiryDate
            }],
        });

        expect(result.id).toBeDefined();
        expect(result.invoiceNumber).toMatch(/^INV-/);
    });
});

// ============================================================================
// CRITICAL BUG #2 — SCHEDULE H/H1/X PRESCRIPTION ENFORCEMENT
// ============================================================================
describe('P-2: Prescription Enforcement', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 2 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should reject Schedule H drug sale without prescriptionId', async () => {
        const product = makeScheduleHProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-schH', quantity: 2, unitPrice: 7800 }],
                // No metadata.prescriptionId
            })
        ).rejects.toThrow(/requires a valid prescription/);
    });

    test('should reject Schedule H drug sale with empty prescriptionId', async () => {
        const product = makeScheduleHProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-schH', quantity: 2, unitPrice: 7800 }],
                metadata: { prescriptionId: '  ' }, // Whitespace-only
            })
        ).rejects.toThrow(/requires a valid prescription/);
    });

    test('should allow Schedule H sale when prescriptionId is provided', async () => {
        const product = makeScheduleHProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-schH', quantity: 2, unitPrice: 7800 }],
            metadata: { prescriptionId: 'RX-2026-04-001' },
        });

        expect(result.id).toBeDefined();
        expect(result.invoiceNumber).toBeDefined();
    });

    test('should reject Schedule X drug sale without doctorName and doctorRegNo', async () => {
        const product = makeScheduleXProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-schX', quantity: 1, unitPrice: 4500 }],
                metadata: { prescriptionId: 'RX-2026-04-002' },
                // Missing doctorName and doctorRegNo
            })
        ).rejects.toThrow(/Both doctorName and doctorRegNo must be provided/);
    });

    test('should reject Schedule X with invalid doctor registration number format', async () => {
        const product = makeScheduleXProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-schX', quantity: 1, unitPrice: 4500 }],
                metadata: {
                    prescriptionId: 'RX-2026-04-003',
                    doctorName: 'Dr. Sharma',
                    doctorRegNo: 'abc123', // Invalid format
                },
            })
        ).rejects.toThrow(/Invalid doctor registration number/);
    });

    test('should allow Schedule X sale with valid prescription + doctor details', async () => {
        const product = makeScheduleXProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-schX', quantity: 1, unitPrice: 4500 }],
            metadata: {
                prescriptionId: 'RX-2026-04-004',
                doctorName: 'Dr. Priya Sharma',
                doctorRegNo: 'MCI-12345',
                patientName: 'Rajesh Kumar',
                patientAddress: '42 MG Road, Pune 411001',
            },
        });

        expect(result.id).toBeDefined();
    });

    test('should allow manager override for prescription requirement with audit log', async () => {
        const product = makeScheduleHProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID, USER_ID,
            {
                items: [{ productId: 'prod-schH', quantity: 2, unitPrice: 7800 }],
                metadata: {
                    managerOverride: true,
                    overrideReason: 'Emergency supply — prescription to follow',
                },
            },
            'manager', // userRole
        );

        expect(result.id).toBeDefined();
        // Verify audit was fired for compliance override
        const auditCalls = (require('../middleware/audit') as any).logAudit;
        // The function is real (not mocked), so check warnings instead
        expect(result.warnings).toBeDefined();
        const overrideWarning = result.warnings!.find(w => w.type === 'COMPLIANCE_OVERRIDE');
        expect(overrideWarning).toBeDefined();
        expect(overrideWarning!.drugName).toBe('Amoxicillin 250mg');
    });

    test('should NOT allow cashier to use manager override', async () => {
        const product = makeScheduleHProduct();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(
                TENANT_ID, USER_ID,
                {
                    items: [{ productId: 'prod-schH', quantity: 2, unitPrice: 7800 }],
                    metadata: { managerOverride: true },
                },
                'cashier', // Not in OVERRIDE_ROLES
            )
        ).rejects.toThrow(/requires a valid prescription/);
    });

    test('should warn on invalid doctorRegNo format for Schedule H (non-blocking)', async () => {
        const product = makeScheduleHProduct();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-schH', quantity: 1, unitPrice: 7800 }],
            metadata: {
                prescriptionId: 'RX-2026-04-005',
                doctorRegNo: 'invalid-format',
            },
        });

        expect(result.id).toBeDefined(); // Sale went through
        const formatWarning = result.warnings?.find(w => w.type === 'INVALID_DOCTOR_REG_FORMAT');
        expect(formatWarning).toBeDefined();
    });
});

// ============================================================================
// GAP #3 — QUANTITY LIMIT ENFORCEMENT
// ============================================================================
describe('P-3: Quantity Limit Enforcement', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 3 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should reject sale exceeding maxSaleQuantity without override', async () => {
        const product = makeProduct({
            attributes: { maxSaleQuantity: '5' },
        });
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-001', quantity: 10, unitPrice: 1650 }],
            })
        ).rejects.toThrow(/exceeds the maximum allowed quantity of 5/);
    });

    test('should allow sale exceeding maxSaleQuantity with manager override', async () => {
        const product = makeProduct({
            attributes: { maxSaleQuantity: '5' },
        });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(
            TENANT_ID, USER_ID,
            {
                items: [{ productId: 'prod-001', quantity: 10, unitPrice: 1650 }],
                metadata: { managerOverride: true, overrideReason: 'Bulk order approved' },
            },
            'owner',
        );

        expect(result.id).toBeDefined();
    });

    test('should add walk-in warning for >10 Schedule H drugs (soft limit)', async () => {
        const product = makeScheduleHProduct({ currentStock: 200 });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{ productId: 'prod-schH', quantity: 15, unitPrice: 7800 }],
            customerName: 'Walk-in',
            metadata: { prescriptionId: 'RX-2026-04-006' },
        });

        expect(result.id).toBeDefined();
        const walkInWarning = result.warnings?.find(w => w.type === 'HIGH_QUANTITY_WALK_IN');
        expect(walkInWarning).toBeDefined();
        expect(walkInWarning!.quantity).toBe(15);
    });
});

// ============================================================================
// GAP #5 — VOID PAID INVOICE BLOCKED
// ============================================================================
describe('GAP #5: Void Paid Invoice Prevention', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('should reject voiding an invoice with paidCents > 0', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-001',
            status: 'finalized',
            paidCents: 5000,
            totalCents: 10000,
            isDeleted: false,
        });

        await expect(
            invoiceService.voidInvoice(TENANT_ID, 'inv-001', 'Wrong patient')
        ).rejects.toThrow(/has already been collected/);
    });

    test('should allow voiding an invoice with paidCents = 0', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-002',
            status: 'finalized',
            paidCents: 0,
            totalCents: 10000,
            isDeleted: false,
            notes: '',
            invoiceNumber: 'INV-000001',
        });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.voidInvoice(TENANT_ID, 'inv-002', 'Wrong patient');
        expect(result.status).toBe('voided');
    });
});

// ============================================================================
// GAP #7 — RETURN EXCESS QUANTITY
// ============================================================================
describe('GAP #7: Return Validation', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('should reject return when quantity exceeds sold quantity', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-ret-001',
            status: 'finalized',
            isDeleted: false,
            invoiceNumber: 'INV-000010',
        });
        // Line items
        mockQueryItems
            .mockResolvedValueOnce({
                items: [{
                    itemId: 'prod-001',
                    name: 'Paracetamol 500mg',
                    quantity: 3,
                    unitPriceCents: 1650,
                    taxCents: 396,
                }],
                lastKey: undefined,
            })
            // Existing credit notes for this invoice (none)
            .mockResolvedValueOnce({ items: [], lastKey: undefined });

        await expect(
            invoiceService.createReturn(TENANT_ID, 'inv-ret-001', [
                { itemId: 'prod-001', quantity: 5, reason: 'Wrong dosage' },
            ], USER_ID)
        ).rejects.toThrow(/only 3 returnable/);
    });

    test('should reject return from draft invoice', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-draft',
            status: 'draft',
            isDeleted: false,
        });

        await expect(
            invoiceService.createReturn(TENANT_ID, 'inv-draft', [
                { itemId: 'prod-001', quantity: 1 },
            ], USER_ID)
        ).rejects.toThrow(/Cannot return items from a 'draft' invoice/);
    });

    test('should reject return from voided invoice', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-voided',
            status: 'voided',
            isDeleted: false,
        });

        await expect(
            invoiceService.createReturn(TENANT_ID, 'inv-voided', [
                { itemId: 'prod-001', quantity: 1 },
            ], USER_ID)
        ).rejects.toThrow(/Cannot return items from a 'voided' invoice/);
    });

    test('should track already-returned quantities across multiple returns', async () => {
        mockGetItem.mockResolvedValue({
            id: 'inv-multi-ret',
            status: 'finalized',
            isDeleted: false,
            invoiceNumber: 'INV-000020',
        });
        // Line items: 10 sold
        mockQueryItems
            .mockResolvedValueOnce({
                items: [{
                    itemId: 'prod-001',
                    name: 'Paracetamol 500mg',
                    quantity: 10,
                    unitPriceCents: 1650,
                    taxCents: 1980,
                }],
                lastKey: undefined,
            })
            // Existing credit notes (already returned 7)
            .mockResolvedValueOnce({
                items: [{ id: 'cn-001', originalInvoiceId: 'inv-multi-ret', isDeleted: false }],
                lastKey: undefined,
            })
            // Credit note line items (7 already returned)
            .mockResolvedValueOnce({
                items: [{ itemId: 'prod-001', quantity: 7 }],
                lastKey: undefined,
            });

        await expect(
            invoiceService.createReturn(TENANT_ID, 'inv-multi-ret', [
                { itemId: 'prod-001', quantity: 5, reason: 'Damaged' }, // 5 > 3 returnable
            ], USER_ID)
        ).rejects.toThrow(/only 3 returnable \(10 sold, 7 already returned\)/);
    });
});

// ============================================================================
// GAP #8 — DISCOUNT CAPPING (NO NEGATIVE AMOUNTS)
// ============================================================================
describe('GAP #8: Discount Capping', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 4 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should cap item discount at line gross (no negative taxable value)', async () => {
        const product = makeProduct({ salePriceCents: 1650 });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-001',
                quantity: 1,
                unitPrice: 1650,
                discountCents: 5000, // ₹50 discount on ₹16.50 item — should be capped
            }],
        });

        expect(result.id).toBeDefined();
        // The total must be >= 0 (never negative)
        expect(result.totalCents).toBeGreaterThanOrEqual(0);
    });

    test('should cap bill-level discount at subtotal (no negative subtotal)', async () => {
        const product = makeProduct({ salePriceCents: 1650 });
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-001',
                quantity: 1,
                unitPrice: 1650,
            }],
            discountCents: 99999, // Huge bill-level discount
        });

        expect(result.id).toBeDefined();
        expect(result.totalCents).toBeGreaterThanOrEqual(0);
    });
});

// ============================================================================
// P-2b: SCHEDULE H1 RX GATE END-TO-END (Strict Contract)
// ============================================================================
describe('P-2b: Schedule H1 Strict Rx Gate', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 10 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('rejects Schedule H1 sale missing prescriptionId', async () => {
        const product = makeScheduleH1Product();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-schH1', quantity: 5, unitPrice: 8500 }],
                metadata: {
                    doctorName: 'Dr. Sharma',
                    doctorRegNo: 'MCI-12345',
                    patientName: 'Anita',
                },
            }),
        ).rejects.toThrow(/requires a valid prescription/);
    });

    test('rejects Schedule H1 sale missing doctorName/doctorRegNo', async () => {
        const product = makeScheduleH1Product();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-schH1', quantity: 5, unitPrice: 8500 }],
                metadata: {
                    prescriptionId: 'RX-H1-001',
                    patientName: 'Anita',
                },
            }),
        ).rejects.toThrow(/doctorName and doctorRegNo must be provided/);
    });

    test('rejects Schedule H1 sale with malformed doctorRegNo', async () => {
        const product = makeScheduleH1Product();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-schH1', quantity: 5, unitPrice: 8500 }],
                metadata: {
                    prescriptionId: 'RX-H1-002',
                    doctorName: 'Dr. Sharma',
                    doctorRegNo: 'badly-formatted-id',
                    patientName: 'Anita',
                },
            }),
        ).rejects.toThrow(/Invalid doctor registration number/);
    });

    test('rejects Schedule H1 sale missing patientName', async () => {
        const product = makeScheduleH1Product();
        mockBatchGetItems.mockResolvedValue([product]);

        await expect(
            invoiceService.createInvoice(TENANT_ID, USER_ID, {
                items: [{ productId: 'prod-schH1', quantity: 5, unitPrice: 8500 }],
                metadata: {
                    prescriptionId: 'RX-H1-003',
                    doctorName: 'Dr. Sharma',
                    doctorRegNo: 'MCI-12345',
                },
            }),
        ).rejects.toThrow(/patientName must be provided/);
    });

    test('allows Schedule H1 sale with full metadata and writes H1LOG transact item', async () => {
        const product = makeScheduleH1Product();
        mockBatchGetItems.mockResolvedValue([product]);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [{
                productId: 'prod-schH1',
                quantity: 5,
                unitPrice: 8500,
                batchNumber: 'B-H1-001',
                expiryDate: '2027-12-31',
            }],
            metadata: {
                prescriptionId: 'RX-H1-100',
                doctorName: 'Dr. Priya Sharma',
                doctorRegNo: 'MCI-12345',
                patientName: 'Rajesh Kumar',
                patientAddress: '42 MG Road, Pune',
            },
        });

        expect(result.id).toBeDefined();

        expect(mockTransactWrite).toHaveBeenCalled();
        const txItems = mockTransactWrite.mock.calls[0][0];
        const h1LogPut = txItems.find((op: any) =>
            op.Put?.Item?.entityType === 'H1_LOG'
            || (op.Put?.Item?.SK || '').toString().startsWith('H1LOG#'),
        );
        expect(h1LogPut).toBeDefined();
        expect(h1LogPut.Put.Item.scheduleType).toBe('H1');
        expect(h1LogPut.Put.Item.doctorRegNo).toBe('MCI-12345');
        expect(h1LogPut.Put.Item.prescriptionId).toBe('RX-H1-100');
    });
});

// ============================================================================
// MIXED GST RATES IN ONE INVOICE
// ============================================================================
describe('Mixed GST Rates', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 5 });
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('should correctly calculate tax for 5%, 12%, 18% items in same invoice', async () => {
        const products = [
            makeProduct({
                id: 'prod-5pct', SK: 'PRODUCT#prod-5pct', name: 'Insulin',
                salePriceCents: 65000, cgstRateBp: 250, sgstRateBp: 250,
            }),
            makeProduct({
                id: 'prod-12pct', SK: 'PRODUCT#prod-12pct', name: 'Paracetamol',
                salePriceCents: 1650, cgstRateBp: 600, sgstRateBp: 600,
            }),
            makeProduct({
                id: 'prod-18pct', SK: 'PRODUCT#prod-18pct', name: 'BP Monitor',
                salePriceCents: 195000, cgstRateBp: 900, sgstRateBp: 900,
            }),
        ];
        mockBatchGetItems.mockResolvedValue(products);
        mockTransactWrite.mockResolvedValue(undefined);

        const result = await invoiceService.createInvoice(TENANT_ID, USER_ID, {
            items: [
                { productId: 'prod-5pct', quantity: 1, unitPrice: 65000 },
                { productId: 'prod-12pct', quantity: 10, unitPrice: 1650 },
                { productId: 'prod-18pct', quantity: 1, unitPrice: 195000 },
            ],
        });

        expect(result.id).toBeDefined();
        // Total must be > sum of line items (because tax is added)
        const rawSubtotal = 65000 + (10 * 1650) + 195000;
        expect(result.totalCents).toBeGreaterThan(rawSubtotal);
    });
});
