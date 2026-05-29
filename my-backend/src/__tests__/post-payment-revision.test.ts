// @ts-nocheck
import { executePostPaymentActions } from '../services/post-payment.service';

const mockGetItem = jest.fn();
const mockQueryItems = jest.fn();
const mockUpdateItem = jest.fn();
const mockRecordRevision = jest.fn();

jest.mock('../config/dynamodb.config', () => ({
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
        invoiceSK: (id: string) => `INVOICE#${id}`,
        invoiceLineItemPK: (id: string) => `INVOICE#${id}`,
    },
    getItem: (...args: any[]) => mockGetItem(...args),
    queryItems: (...args: any[]) => mockQueryItems(...args),
    updateItem: (...args: any[]) => mockUpdateItem(...args),
}));

jest.mock('../services/revision-history.service', () => ({
    recordRevision: (...args: any[]) => mockRecordRevision(...args),
}));

jest.mock('../services/whatsapp.service', () => ({
    sendPaymentConfirmation: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('@aws-sdk/client-s3', () => ({
    S3Client: jest.fn().mockImplementation(() => ({
        send: jest.fn().mockResolvedValue(undefined),
    })),
    PutObjectCommand: jest.fn().mockImplementation((x) => x),
}));

describe('Post payment revision trail', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockUpdateItem.mockResolvedValue({});
        mockRecordRevision.mockResolvedValue(undefined);
    });

    test('executePostPaymentActions writes revision for staff sale + invoice paid status', async () => {
        mockGetItem.mockResolvedValueOnce({
            id: 'inv-1',
            invoiceNumber: 'INV-1',
            totalCents: 2500,
            status: 'draft',
            customerPhone: null,
        }).mockResolvedValueOnce({});
        mockQueryItems.mockResolvedValueOnce({
            items: [
                {
                    PK: 'TENANT#test-tenant',
                    SK: 'STAFFSALE#sale-1',
                    id: 'sale-1',
                    staffId: 'staff-1',
                    paymentStatus: 'pending',
                },
            ],
        }).mockResolvedValueOnce({ items: [] });

        await executePostPaymentActions({
            tenantId: 'test-tenant',
            invoiceId: 'inv-1',
            paymentOrderId: 'order-1',
            amountCents: 2500,
        });

        expect(mockRecordRevision).toHaveBeenCalledWith(
            'test-tenant',
            'staff_sales_details',
            'sale-1',
            'status_change',
            'system',
            expect.objectContaining({ paymentStatus: 'pending' }),
            expect.objectContaining({ paymentStatus: 'paid' }),
            expect.objectContaining({ source: 'post-payment.executePostPaymentActions', paymentOrderId: 'order-1' }),
        );
        expect(mockRecordRevision).toHaveBeenCalledWith(
            'test-tenant',
            'transactions',
            'inv-1',
            'status_change',
            'system',
            expect.objectContaining({ status: 'draft' }),
            expect.objectContaining({ status: 'paid', paidCents: 2500, balanceCents: 0 }),
            expect.objectContaining({ source: 'post-payment.executePostPaymentActions', paymentOrderId: 'order-1' }),
        );
    });
});

