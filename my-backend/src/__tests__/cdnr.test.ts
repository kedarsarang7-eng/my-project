// ============================================================================
// CDNR / credit note tests (DynamoDB)
// ============================================================================

import { gstr1Report } from '../handlers/reports';
import { createReturn } from '../services/invoice.service';
import * as ddb from '../config/dynamodb.config';

jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: jest.fn().mockResolvedValue({
        sub: 'user-1',
        email: 'owner@test.com',
        tenantId: 't-1',
        role: 'owner',
        businessType: 'hardware',
    }),
    AuthError: class AuthError extends Error {
        statusCode = 401;
        constructor(m: string) {
            super(m);
            this.name = 'AuthError';
        }
    },
}));

jest.mock('../config/manifest-cache', () => ({
    getCachedManifest: jest.fn().mockResolvedValue({
        allowedFeatures: ['advanced_reports'],
        planTier: 'enterprise',
    }),
}));

jest.mock('../config/dynamodb.config', () => ({
    TABLE_NAME: 'test-table',
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
        tenantProfileSK: () => 'PROFILE',
        tenantSettingsSK: () => 'SETTINGS',
        invoiceLineItemPK: (id: string) => `INVOICE#${id}`,
        invoiceSK: (id: string) => `INVOICE#${id}`,
        productSK: (id: string) => `PRODUCT#${id}`,
        lineItemSK: (id: string) => `LINEITEM#${id}`,
    },
    getItem: jest.fn(),
    queryItems: jest.fn(),
    queryAllItems: jest.fn(),
    updateItem: jest.fn(),
    transactWrite: jest.fn(),
    batchWrite: jest.fn(),
}));

jest.mock('../utils/cache', () => ({
    getCached: async (_key: string, _ttl: number, fn: () => Promise<unknown>) => fn(),
    invalidateCache: jest.fn(),
}));

jest.mock('../utils/logger', () => ({
    logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

jest.mock('../middleware/audit', () => ({
    logAudit: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../services/websocket.service', () => ({
    emitEvent: jest.fn().mockResolvedValue(undefined),
}));

describe('GSTR-1 CDNR Logic', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('includes voided / returned B2B rows in CDNR payload', async () => {
        const MOCK_INVOICES = [
            {
                id: 'inv-1',
                invoiceNumber: 'INV-001',
                status: 'paid',
                createdAt: '2026-06-15T10:00:00.000Z',
                metadata: { customerGstin: '27AAAAA0000A1Z5' },
                totalCents: 10000,
                subtotalCents: 9000,
                igstCents: 1000,
                cgstCents: 0,
                sgstCents: 0,
            },
            {
                id: 'inv-2',
                invoiceNumber: 'INV-002',
                status: 'voided',
                metadata: { customerGstin: '07BBBBB1111B2Z6' },
                totalCents: 20000,
                subtotalCents: 18000,
                igstCents: 2000,
                cgstCents: 0,
                sgstCents: 0,
                createdAt: '2026-06-10T10:00:00.000Z',
                updatedAt: '2026-06-11T10:00:00.000Z',
            },
            {
                id: 'inv-3',
                invoiceNumber: 'INV-003',
                status: 'paid',
                returnInvoiceId: 'CN-XYZ-202606-0001',
                metadata: { customerGstin: '38CCCCC2222C3Z7' },
                totalCents: 30000,
                subtotalCents: 25000,
                igstCents: 5000,
                cgstCents: 0,
                sgstCents: 0,
                createdAt: '2026-06-12T10:00:00.000Z',
            },
            {
                id: 'inv-4',
                invoiceNumber: 'INV-004',
                status: 'voided',
                totalCents: 5000,
                createdAt: '2026-06-13T10:00:00.000Z',
            },
        ];

        (ddb.queryAllItems as jest.Mock).mockImplementation(async (pk: string, prefix?: string) => {
            const pref = String(prefix || '');
            const pkStr = String(pk || '');
            if (pkStr.startsWith('TENANT#') && pref.startsWith('INVOICE#') && pref === 'INVOICE#') {
                return MOCK_INVOICES;
            }
            if (pkStr.startsWith('INVOICE#') && pref.startsWith('LINEITEM')) {
                return [];
            }
            return [];
        });

        const event = {
            queryStringParameters: { from: '2026-06-01', to: '2026-06-30' },
            requestContext: { http: { method: 'GET' }, requestId: 'r1' },
            rawPath: '/reports/gstr1',
            headers: {},
        } as any;

        const res = (await gstr1Report(event, {} as any)) as { statusCode: number; body: string };
        expect(res.statusCode).toBe(200);
        const body = JSON.parse(res.body);

        expect(body.data.b2b).toHaveLength(2);
        expect(body.data.b2b.find((i: any) => i.invoiceNumber === 'INV-002')).toBeUndefined();

        expect(body.data.cdnr).toHaveLength(2);
        const cdnrNote1 = body.data.cdnr.find((c: any) => c.ctin === '07BBBBB1111B2Z6');
        expect(cdnrNote1).toBeDefined();
        expect(cdnrNote1.nt[0].ntNum).toBe('CN-INV-002');
        expect(cdnrNote1.nt[0].val).toBe(200);
        expect(cdnrNote1.nt[0].itms[0].igst).toBe(20);

        const cdnrNote2 = body.data.cdnr.find((c: any) => c.ctin === '38CCCCC2222C3Z7');
        expect(cdnrNote2.nt[0].ntNum).toBe('CN-XYZ-202606-0001');
    });
});

describe('createReturn sequence', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('writes returnInvoiceId and CN number from transactWrite', async () => {
        const yyyymm = new Date().toISOString().slice(0, 7).replace('-', '');
        (ddb.getItem as jest.Mock).mockImplementation((_pk: string, sk: string) => {
            const s = String(sk);
            if (s === 'INVOICE#inv-1') {
                return Promise.resolve({
                    id: 'inv-1',
                    invoiceNumber: 'INV-001',
                    status: 'paid',
                    tenantId: 't-1',
                    totalCents: 5000,
                });
            }
            if (s === 'PROFILE') return Promise.resolve({ name: 'SuperMart' });
            if (s === 'SETTINGS') return Promise.resolve({ invoicePrefix: 'SUP' });
            if (s.startsWith('COUNTER#CREDIT_NOTE#')) return Promise.resolve(null);
            return Promise.resolve(null);
        });

        (ddb.queryItems as jest.Mock).mockImplementation(async (_pk: string, prefix?: string) => {
            const p = String(prefix || '');
            if (p.startsWith('LINEITEM')) {
                return {
                    items: [{
                        itemId: 'pt-1',
                        quantity: 5,
                        unitPriceCents: 1000,
                        name: 'Item',
                        taxCents: 0,
                        lineTotalCents: 5000,
                    }],
                };
            }
            if (p.startsWith('CREDITNOTE')) return { items: [] };
            return { items: [] };
        });

        (ddb.transactWrite as jest.Mock).mockResolvedValue(undefined);

        const result = await createReturn('t-1', 'inv-1', [{ itemId: 'pt-1', quantity: 2 }], 'user-1');
        expect(result.creditNoteId).toBeDefined();
        expect(ddb.transactWrite).toHaveBeenCalled();

        const writeArg = (ddb.transactWrite as jest.Mock).mock.calls[0][0];
        const invoiceUpdate = writeArg.find((op: any) => /INVOICE#inv-1/.test((Object.values(op)[0] as any)?.Key?.SK || ''));
        expect(invoiceUpdate).toBeDefined();
        expect(invoiceUpdate.Update.UpdateExpression).toContain('returnInvoiceId');
        const cnNumVal = invoiceUpdate.Update.ExpressionAttributeValues[':cnNum'];
        expect(cnNumVal).toMatch(new RegExp(`^CN-SUP-${yyyymm}-\\d{4}$`));
    });
});
