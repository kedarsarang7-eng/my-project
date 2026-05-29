import { BusinessType } from '../types/tenant.types';

const mockGetItem = jest.fn().mockResolvedValue(null);
const mockPutItem = jest.fn().mockResolvedValue(undefined);
const mockQueryItems = jest.fn().mockResolvedValue({ items: [], lastKey: undefined });
const mockQueryAllItems = jest.fn().mockResolvedValue([]);
const mockUpdateItem = jest.fn().mockResolvedValue({});
const mockBatchWrite = jest.fn().mockResolvedValue(undefined);
const mockBatchGetItems = jest.fn().mockResolvedValue([]);
const mockTransactWrite = jest.fn().mockResolvedValue(undefined);
const mockScanTable = jest.fn().mockResolvedValue([]);

jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: jest.fn().mockResolvedValue({
        sub: 'test-user-id',
        email: 'test@grocery.com',
        tenantId: 'test-tenant-id',
        role: 'owner',
        businessType: 'grocery',
        planTier: 'professional',
    }),
    requireRole: jest.fn(),
    AuthError: class AuthError extends Error {
        statusCode: number;
        constructor(msg: string, code = 401) { super(msg); this.statusCode = code; this.name = 'AuthError'; }
    },
}));

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
        tenantProfileSK: () => 'PROFILE',
        tenantSettingsSK: () => 'SETTINGS',
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

import * as invoiceService from '../services/invoice.service';

describe('Grocery FEFO Batch Consumption', () => {
    const TENANT_ID = 'test-tenant-id';
    const USER_ID = 'test-user-id';

    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({ counterValue: 1 });
    });

    test('consumes nearest expiry batch first (FEFO)', async () => {
        mockBatchGetItems.mockResolvedValue([
            {
                id: 'prod-onion',
                SK: 'PRODUCT#prod-onion',
                name: 'Onions',
                salePriceCents: 3500,
                currentStock: 20,
                cgstRateBp: 0,
                sgstRateBp: 0,
                isDeleted: false,
                isService: false,
                unit: 'kg',
            },
        ]);

        mockQueryItems.mockImplementation((_pk: string, skPrefix: string) => {
            if (skPrefix.startsWith('GROCBATCH#prod-onion#')) {
                return Promise.resolve({
                    items: [
                        {
                            SK: 'GROCBATCH#prod-onion#B2',
                            batchNumber: 'B2',
                            expiryDate: '2026-05-20',
                            currentQty: 10,
                            status: 'active',
                        },
                        {
                            SK: 'GROCBATCH#prod-onion#B1',
                            batchNumber: 'B1',
                            expiryDate: '2026-05-10',
                            currentQty: 10,
                            status: 'active',
                        },
                    ],
                    lastKey: undefined,
                });
            }
            return Promise.resolve({ items: [], lastKey: undefined });
        });

        await invoiceService.createInvoice(
            TENANT_ID,
            USER_ID,
            {
                items: [{ productId: 'prod-onion', quantity: 6, unitPrice: 3500 }],
            },
            'owner',
            BusinessType.GROCERY,
        );

        const transactItems = mockTransactWrite.mock.calls[0][0];
        const batchUpdates = transactItems.filter((x: any) => x.Update?.Key?.SK?.startsWith('GROCBATCH#prod-onion#'));
        expect(batchUpdates.length).toBe(1);
        expect(batchUpdates[0].Update.Key.SK).toBe('GROCBATCH#prod-onion#B1');
        expect(batchUpdates[0].Update.ExpressionAttributeValues[':qty']).toBe(6);
    });

    test('rejects when unexpired batch stock insufficient', async () => {
        mockBatchGetItems.mockResolvedValue([
            {
                id: 'prod-milk',
                SK: 'PRODUCT#prod-milk',
                name: 'Milk',
                salePriceCents: 2800,
                currentStock: 100,
                cgstRateBp: 0,
                sgstRateBp: 0,
                isDeleted: false,
                isService: false,
                unit: 'pcs',
            },
        ]);

        mockQueryItems.mockImplementation((_pk: string, skPrefix: string) => {
            if (skPrefix.startsWith('GROCBATCH#prod-milk#')) {
                return Promise.resolve({
                    items: [
                        { SK: 'GROCBATCH#prod-milk#E1', batchNumber: 'E1', expiryDate: '2026-05-09', currentQty: 2, status: 'active' },
                    ],
                    lastKey: undefined,
                });
            }
            return Promise.resolve({ items: [], lastKey: undefined });
        });

        await expect(
            invoiceService.createInvoice(
                TENANT_ID,
                USER_ID,
                { items: [{ productId: 'prod-milk', quantity: 5, unitPrice: 2800 }] },
                'owner',
                BusinessType.GROCERY,
            ),
        ).rejects.toThrow(/Insufficient unexpired batch stock/);
    });
});
