// @ts-nocheck
/// <reference types="jest" />
// ============================================================================
// Unit + Handler Tests — Customer Balance Rollup Stream (Part 2)
// ============================================================================
// Covers:
//   • computeBalanceFromRows — pure aggregation math (incl. edge cases)
//   • recomputeCustomerBalance — I/O path (queries + putItem)
//   • handler — stream event routing, isolation (no-throw), filtering
//
// Run with: npx jest src/__tests__/customer-rollup-stream.test.ts
// ============================================================================

// ---- Mock DynamoDB ----
const mockQueryAllItems = jest.fn().mockResolvedValue([]);
const mockPutItem = jest.fn().mockResolvedValue(undefined);

jest.mock('../config/dynamodb.config', () => ({
    TABLE_NAME: 'test-table',
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
        customerSK: (id: string) => `CUSTOMER#${id}`,
        customerBalanceSK: (id: string) => `CUSTOMER#${id}#BALANCE`,
        invoiceSK: (id: string) => `INVOICE#${id}`,
        paymentSK: (id: string) => `PAYMENT#${id}`,
    },
    getItem: jest.fn(),
    putItem: (...args: any[]) => mockPutItem(...args),
    queryItems: jest.fn(),
    queryAllItems: (...args: any[]) => mockQueryAllItems(...args),
    updateItem: jest.fn(),
}));

import {
    computeBalanceFromRows,
    recomputeCustomerBalance,
    handler,
} from '../handlers/customer-rollup-stream';

const TENANT = 't1';
const CUSTOMER = 'c1';
const NOW = '2026-06-21T10:00:00.000Z';

describe('computeBalanceFromRows — pure aggregation', () => {
    test('empty ledger yields zero balances', () => {
        const b = computeBalanceFromRows(TENANT, CUSTOMER, [], [], NOW);
        expect(b.totalBilledCents).toBe(0);
        expect(b.totalPaidCents).toBe(0);
        expect(b.outstandingCents).toBe(0);
        expect(b.invoiceCount).toBe(0);
        expect(b.paymentCount).toBe(0);
        expect(b.lastInvoiceAt).toBeNull();
        expect(b.lastPaymentAt).toBeNull();
        expect(b.SK).toBe('CUSTOMER#c1#BALANCE');
        expect(b.PK).toBe('TENANT#t1');
    });

    test('sums invoice totals, paid, and balance', () => {
        const invoices = [
            { totalCents: 100000, paidCents: 50000, balanceCents: 50000, createdAt: '2026-06-01T00:00:00.000Z' },
            { totalCents: 200000, paidCents: 200000, balanceCents: 0, createdAt: '2026-06-10T00:00:00.000Z' },
        ];
        const b = computeBalanceFromRows(TENANT, CUSTOMER, invoices, [], NOW);
        expect(b.totalBilledCents).toBe(300000);
        expect(b.totalPaidCents).toBe(250000);
        expect(b.outstandingCents).toBe(50000);
        expect(b.invoiceCount).toBe(2);
        expect(b.lastInvoiceAt).toBe('2026-06-10T00:00:00.000Z');
    });

    test('excludes voided/draft invoices from totals but counts payments', () => {
        const invoices = [
            { totalCents: 100000, paidCents: 100000, balanceCents: 0, createdAt: '2026-06-01T00:00:00.000Z', status: 'paid' },
            { totalCents: 999999, paidCents: 0, balanceCents: 999999, createdAt: '2026-06-02T00:00:00.000Z', status: 'voided' },
            { totalCents: 500000, paidCents: 0, balanceCents: 500000, createdAt: '2026-06-03T00:00:00.000Z', status: 'draft' },
        ];
        const payments = [
            { amountCents: 100000, createdAt: '2026-06-05T00:00:00.000Z' },
        ];
        const b = computeBalanceFromRows(TENANT, CUSTOMER, invoices, payments, NOW);
        expect(b.totalBilledCents).toBe(100000); // only the paid one
        expect(b.invoiceCount).toBe(1);
        expect(b.paymentCount).toBe(1);
        expect(b.lastPaymentAt).toBe('2026-06-05T00:00:00.000Z');
    });

    test('excludes soft-deleted invoices and payments', () => {
        const invoices = [
            { totalCents: 100, paidCents: 0, balanceCents: 100, createdAt: '2026-06-01T00:00:00.000Z' },
            { totalCents: 999, paidCents: 999, balanceCents: 0, createdAt: '2026-06-02T00:00:00.000Z', isDeleted: true },
        ];
        const b = computeBalanceFromRows(TENANT, CUSTOMER, invoices, [{ amountCents: 50, isDeleted: true }], NOW);
        expect(b.totalBilledCents).toBe(100);
        expect(b.invoiceCount).toBe(1);
        expect(b.paymentCount).toBe(0);
    });

    test('clamps negative outstanding to zero (overpayment drift)', () => {
        const invoices = [{ totalCents: 100, paidCents: 300, balanceCents: -200, createdAt: NOW }];
        const b = computeBalanceFromRows(TENANT, CUSTOMER, invoices, [], NOW);
        expect(b.outstandingCents).toBe(0);
        // paid is reported as-is (faithful to the ledger); outstanding is the display clamp.
        expect(b.totalPaidCents).toBe(300);
    });

    test('handles very large currency values without overflow', () => {
        const big = 9_007_199_254_740_993; // > 2^53-safe territory for addition sanity
        const invoices = [{ totalCents: big, paidCents: 1, balanceCents: big - 1, createdAt: NOW }];
        const b = computeBalanceFromRows(TENANT, CUSTOMER, invoices, [], NOW);
        expect(b.totalBilledCents).toBe(big);
        expect(b.outstandingCents).toBe(big - 1);
    });

    test('lastInvoiceAt picks the latest timestamp', () => {
        const invoices = [
            { totalCents: 1, paidCents: 0, balanceCents: 1, createdAt: '2026-01-01T00:00:00.000Z' },
            { totalCents: 1, paidCents: 0, balanceCents: 1, createdAt: '2026-12-01T00:00:00.000Z' },
            { totalCents: 1, paidCents: 0, balanceCents: 1, createdAt: '2026-06-01T00:00:00.000Z' },
        ];
        const b = computeBalanceFromRows(TENANT, CUSTOMER, invoices, [], NOW);
        expect(b.lastInvoiceAt).toBe('2026-12-01T00:00:00.000Z');
    });
});

describe('recomputeCustomerBalance — I/O', () => {
    beforeEach(() => {
        mockQueryAllItems.mockReset();
        mockPutItem.mockReset();
    });

    test('queries INVOICE# + PAYMENT# in parallel and writes BALANCE item', async () => {
        mockQueryAllItems
            // first call = invoices, second = payments (Promise.all preserves order)
            .mockResolvedValueOnce([{ totalCents: 1000, paidCents: 400, balanceCents: 600, createdAt: NOW }])
            .mockResolvedValueOnce([{ amountCents: 400, createdAt: NOW }]);

        const result = await recomputeCustomerBalance(TENANT, CUSTOMER, NOW);

        expect(mockQueryAllItems).toHaveBeenCalledTimes(2);
        expect(mockPutItem).toHaveBeenCalledTimes(1);
        expect(result.outstandingCents).toBe(600);
        expect(result.totalBilledCents).toBe(1000);
        // The persisted item carries the BALANCE SK.
        const putArg = mockPutItem.mock.calls[0][0];
        expect(putArg.SK).toBe('CUSTOMER#c1#BALANCE');
        expect(putArg.entityType).toBe('CUSTOMER_BALANCE');
        expect(putArg.updatedAt).toBe(NOW);
    });
});

// ---- Stream handler ----
// Build a DynamoDB stream record image in marshalled { S: ... } form, since the
// handler unmarshalls exactly like Lambda delivers it.
function marshall(obj: Record<string, any>): any {
    const out: any = {};
    for (const [k, v] of Object.entries(obj)) {
        if (typeof v === 'string') out[k] = { S: v };
        else if (typeof v === 'boolean') out[k] = { BOOL: v };
        else if (typeof v === 'number') out[k] = { N: String(v) };
        else out[k] = { S: JSON.stringify(v) };
    }
    return out;
}

function record(eventName: string, newImage: Record<string, any>, oldImage?: Record<string, any>) {
    return {
        eventName,
        dynamodb: {
            NewImage: marshall(newImage),
            ...(oldImage ? { OldImage: marshall(oldImage) } : {}),
        },
    };
}

describe('handler — stream event routing', () => {
    beforeEach(() => {
        mockQueryAllItems.mockReset();
        mockPutItem.mockReset();
        mockQueryAllItems.mockResolvedValue([]);
    });

    test('recomputes on an INVOICE INSERT with customerId', async () => {
        await handler({
            Records: [record('INSERT', {
                PK: 'TENANT#t1',
                SK: 'INVOICE#inv1',
                entityType: 'INVOICE',
                tenantId: 't1',
                customerId: 'c1',
                totalCents: 5000,
                paidCents: 0,
                balanceCents: 5000,
                createdAt: NOW,
            })],
        } as any);

        expect(mockPutItem).toHaveBeenCalledTimes(1);
        expect(mockPutItem.mock.calls[0][0].customerId).toBe('c1');
    });

    test('recomputes on a PAYMENT MODIFY', async () => {
        await handler({
            Records: [record('MODIFY', {
                PK: 'TENANT#t1',
                SK: 'PAYMENT#p1',
                entityType: 'PAYMENT',
                tenantId: 't1',
                customerId: 'c1',
                amountCents: 1000,
                createdAt: NOW,
            })],
        } as any);

        expect(mockPutItem).toHaveBeenCalledTimes(1);
    });

    test('ignores REMOVE events', async () => {
        await handler({ Records: [{ eventName: 'REMOVE', dynamodb: { NewImage: marshall({ entityType: 'INVOICE', tenantId: 't1', customerId: 'c1' }) } }] } as any);
        expect(mockPutItem).not.toHaveBeenCalled();
    });

    test('ignores non-INVOICE/PAYMENT entityTypes (e.g. PRODUCT)', async () => {
        await handler({
            Records: [record('INSERT', { entityType: 'PRODUCT', tenantId: 't1', customerId: 'c1' })],
        } as any);
        expect(mockPutItem).not.toHaveBeenCalled();
    });

    test('ignores records with no customerId (walk-in / malformed)', async () => {
        await handler({
            Records: [record('INSERT', { entityType: 'INVOICE', tenantId: 't1' })],
        } as any);
        expect(mockPutItem).not.toHaveBeenCalled();
    });

    test('one failed record does NOT abort processing of the rest (no-throw)', async () => {
        // First record: no customerId but valid -> processed; force a throw inside recompute
        // by making queryAllItems reject.
        mockQueryAllItems.mockReset();
        mockQueryAllItems.mockRejectedValueOnce(new Error('transient dynamo error'));
        mockQueryAllItems.mockResolvedValue([]); // subsequent calls succeed

        // Should not throw out of the handler.
        await expect(handler({
            Records: [
                record('INSERT', { PK: 'TENANT#t1', entityType: 'INVOICE', tenantId: 't1', customerId: 'c-bad', createdAt: NOW }),
                record('INSERT', { PK: 'TENANT#t1', entityType: 'INVOICE', tenantId: 't1', customerId: 'c-ok', createdAt: NOW }),
            ],
        } as any)).resolves.toBeUndefined();

        // The second record still got rolled up despite the first failing.
        expect(mockPutItem).toHaveBeenCalled();
    });

    test('idempotent: re-delivering the same record recomputes to the same state', async () => {
        mockQueryAllItems.mockReset();
        mockQueryAllItems.mockResolvedValue([{ totalCents: 1000, paidCents: 0, balanceCents: 1000, createdAt: NOW }]);

        const rec = record('INSERT', { PK: 'TENANT#t1', entityType: 'INVOICE', tenantId: 't1', customerId: 'c1', createdAt: NOW });
        await handler({ Records: [rec] } as any);
        await handler({ Records: [rec] } as any); // re-delivery

        expect(mockPutItem).toHaveBeenCalledTimes(2);
        const first = mockPutItem.mock.calls[0][0];
        const second = mockPutItem.mock.calls[1][0];
        expect(second).toEqual(first);
    });
});
