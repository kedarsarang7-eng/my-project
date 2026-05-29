import * as einvoiceService from '../services/einvoice.service';

const mockGetItem = jest.fn();
const mockQueryItems = jest.fn();

jest.mock('../config/dynamodb.config', () => ({
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
        invoiceSK: (id: string) => `INVOICE#${id}`,
    },
    getItem: (...args: any[]) => mockGetItem(...args),
    putItem: jest.fn(),
    updateItem: jest.fn(),
    queryItems: (...args: any[]) => mockQueryItems(...args),
}));

jest.mock('../middleware/audit', () => ({
    logAudit: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../utils/logger', () => ({
    logger: {
        info: jest.fn(),
        error: jest.fn(),
        warn: jest.fn(),
        debug: jest.fn(),
    },
}));

describe('EWay Bill service', () => {
    const tenantId = 't1';
    const invoiceId = 'inv1';

    beforeEach(() => {
        jest.clearAllMocks();
        process.env.NIC_EWAY_BILL_PATH = '';
        (global as any).fetch = jest.fn();
        const { logAudit } = require('../middleware/audit');
        logAudit.mockResolvedValue(undefined);

        mockGetItem
            // invoice
            .mockResolvedValueOnce({
                id: invoiceId,
                invoiceNumber: 'INV-001',
                createdAt: '2026-04-20T10:00:00.000Z',
            })
            // tenant profile
            .mockResolvedValueOnce({
                gstin: '27ABCDE1234F1Z5',
            })
            // settings
            .mockResolvedValueOnce({
                clientId: 'cid',
                clientSecret: 'csecret',
                username: 'user',
                password: 'pass',
                environment: 'sandbox',
            });
        mockQueryItems.mockResolvedValue({ items: [] });
    });

    test('generateEWayBill returns success for nested Data payload', async () => {
        (global as any).fetch
            // auth
            .mockResolvedValueOnce({
                ok: true,
                status: 200,
                json: async () => ({ Data: { AuthToken: 'token' } }),
                text: async () => '',
            })
            // eway
            .mockResolvedValueOnce({
                ok: true,
                status: 200,
                json: async () => ({ Data: { EwbNo: '111222333444', EwbDt: '2026-04-21T00:00:00.000Z', ValidUpto: '2026-04-22T00:00:00.000Z' } }),
                text: async () => '',
            });

        const result = await einvoiceService.generateEWayBill(tenantId, invoiceId, {
            fromPlace: 'Mumbai',
            toPlace: 'Pune',
            distanceKm: 160,
            vehicleNumber: 'MH12AB1234',
        });

        expect(result.status).toBe('success');
        expect(result.ewbNo).toBe('111222333444');
        expect((global as any).fetch).toHaveBeenCalledTimes(2);
    });

    test('generateEWayBill supports flat response payload', async () => {
        (global as any).fetch
            .mockResolvedValueOnce({
                ok: true,
                status: 200,
                json: async () => ({ Data: { AuthToken: 'token' } }),
                text: async () => '',
            })
            .mockResolvedValueOnce({
                ok: true,
                status: 200,
                json: async () => ({ ewayBillNo: '999888777666', ewayBillDate: '2026-04-21T00:00:00.000Z' }),
                text: async () => '',
            });

        const result = await einvoiceService.generateEWayBill(tenantId, invoiceId, {
            fromPlace: 'Mumbai',
            toPlace: 'Pune',
            distanceKm: 90,
        });

        expect(result.ewbNo).toBe('999888777666');
    });

    test('generateEWayBill uses configured endpoint path override', async () => {
        mockGetItem.mockReset();
        mockGetItem
            .mockResolvedValueOnce({
                id: invoiceId,
                invoiceNumber: 'INV-001',
                createdAt: '2026-04-20T10:00:00.000Z',
            })
            .mockResolvedValueOnce({ gstin: '27ABCDE1234F1Z5' })
            .mockResolvedValueOnce({
                clientId: 'cid',
                clientSecret: 'csecret',
                username: 'user',
                password: 'pass',
                environment: 'sandbox',
                ewayBillPath: '/eicore/v1.03/ewaybill',
            });

        (global as any).fetch
            .mockResolvedValueOnce({
                ok: true,
                status: 200,
                json: async () => ({ Data: { AuthToken: 'token' } }),
                text: async () => '',
            })
            .mockResolvedValueOnce({
                ok: true,
                status: 200,
                json: async () => ({ Data: { EwbNo: '123123123123', EwbDt: '2026-04-21T00:00:00.000Z' } }),
                text: async () => '',
            });

        await einvoiceService.generateEWayBill(tenantId, invoiceId, {
            fromPlace: 'Mumbai',
            toPlace: 'Pune',
            distanceKm: 90,
        });

        const secondCallUrl = (global as any).fetch.mock.calls[1][0] as string;
        expect(secondCallUrl).toContain('/eicore/v1.03/ewaybill');
    });

    test('generateEWayBill throws when NIC response missing EWB number', async () => {
        (global as any).fetch
            .mockResolvedValueOnce({
                ok: true,
                status: 200,
                json: async () => ({ Data: { AuthToken: 'token' } }),
                text: async () => '',
            })
            .mockResolvedValueOnce({
                ok: true,
                status: 200,
                json: async () => ({ Data: {} }),
                text: async () => '',
            });

        await expect(
            einvoiceService.generateEWayBill(tenantId, invoiceId, {
                fromPlace: 'Mumbai',
                toPlace: 'Pune',
                distanceKm: 90,
            }),
        ).rejects.toThrow('E-Way Bill generation failed');
    });

    test('generateEWayBill throws on NIC auth HTTP failure', async () => {
        (global as any).fetch
            .mockResolvedValueOnce({
                ok: false,
                status: 401,
                json: async () => ({}),
                text: async () => 'Unauthorized',
            });

        await expect(
            einvoiceService.generateEWayBill(tenantId, invoiceId, {
                fromPlace: 'Mumbai',
                toPlace: 'Pune',
                distanceKm: 90,
            }),
        ).rejects.toThrow('NIC authentication failed');
    });

    test('generateEWayBill throws on eway HTTP failure', async () => {
        (global as any).fetch
            .mockResolvedValueOnce({
                ok: true,
                status: 200,
                json: async () => ({ Data: { AuthToken: 'token' } }),
                text: async () => '',
            })
            .mockResolvedValueOnce({
                ok: false,
                status: 500,
                json: async () => ({}),
                text: async () => 'Server error',
            });

        await expect(
            einvoiceService.generateEWayBill(tenantId, invoiceId, {
                fromPlace: 'Mumbai',
                toPlace: 'Pune',
                distanceKm: 90,
            }),
        ).rejects.toThrow('E-Way Bill generation failed: HTTP 500');
    });
});

describe('EInvoice settings service', () => {
    const tenantId = 't-settings';

    beforeEach(() => {
        jest.clearAllMocks();
        mockGetItem.mockReset();
    });

    test('getEInvoiceSettings returns safe shape without secrets', async () => {
        mockGetItem.mockResolvedValueOnce({
            isEnabled: true,
            environment: 'production',
            username: 'nic-user',
            clientId: 'cid',
            clientSecret: 'secret',
            ewayBillPath: '/eicore/v1.03/ewaybill',
        });

        const result = await einvoiceService.getEInvoiceSettings(tenantId);

        expect(result).toEqual({
            isEnabled: true,
            environment: 'production',
            username: 'nic-user',
            hasClientId: true,
            hasClientSecret: true,
            ewayBillPath: '/eicore/v1.03/ewaybill',
        });
        expect((result as any).clientSecret).toBeUndefined();
    });

    test('upsertEInvoiceSettings keeps existing secret when omitted', async () => {
        mockGetItem.mockResolvedValueOnce({
            clientSecret: 'existing-secret',
            clientId: 'existing-id',
            username: 'existing-user',
            password: 'existing-pass',
            createdAt: '2026-04-26T00:00:00.000Z',
            ewayBillPath: '/ewaybill',
        });
        const dynamo = require('../config/dynamodb.config');

        await einvoiceService.upsertEInvoiceSettings(tenantId, {
            isEnabled: true,
            environment: 'sandbox',
            ewayBillPath: '/eicore/v1.03/ewaybill',
        });

        expect(dynamo.putItem).toHaveBeenCalledTimes(1);
        const saved = dynamo.putItem.mock.calls[0][0];
        expect(saved.clientSecret).toBe('existing-secret');
        expect(saved.clientId).toBe('existing-id');
        expect(saved.username).toBe('existing-user');
        expect(saved.ewayBillPath).toBe('/eicore/v1.03/ewaybill');
        expect(saved.SK).toBe('SETTINGS#EINVOICE');
    });
});

