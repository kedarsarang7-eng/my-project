// @ts-nocheck
import { recordRevision } from '../services/revision-history.service';

const mockPutItem = jest.fn().mockResolvedValue(undefined);

jest.mock('../config/dynamodb.config', () => ({
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
    },
    putItem: (...args: any[]) => mockPutItem(...args),
}));

describe('revision-history sanitizer', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('recordRevision redacts sensitive keys in before/after/metadata', async () => {
        await recordRevision(
            'tenant-1',
            'transactions',
            'inv-1',
            'update',
            'system',
            { password: 'x', nested: { token: 'abc', keep: 1 } },
            { qrPayload: 'upi://qrcode', webhookRaw: { rawPayload: { pin: '1234' } } },
            { gatewayResponse: { secret: 's3cr3t' }, note: 'ok' },
        );

        expect(mockPutItem).toHaveBeenCalledTimes(1);
        const payload = mockPutItem.mock.calls[0][0];
        expect(payload.before).toMatchObject({
            password: '[REDACTED]',
            nested: { token: '[REDACTED]', keep: 1 },
        });
        expect(payload.after).toMatchObject({
            qrPayload: '[REDACTED]',
            webhookRaw: '[REDACTED]',
        });
        expect(payload.metadata).toMatchObject({
            gatewayResponse: '[REDACTED]',
            note: 'ok',
        });
    });

    test('recordRevision partially masks pii fields', async () => {
        await recordRevision(
            'tenant-1',
            'customers',
            'cust-1',
            'update',
            'system',
            { phone: '9876543210', email: 'alice@example.com', doctorRegNo: 'MCI1234567' },
            { customerPhone: '9988776655', gstin: '27ABCDE1234F1Z5', vehicleNumber: 'MH12AB1234', upiId: 'alice@upi' },
            null,
        );

        const payload = mockPutItem.mock.calls[0][0];
        expect(payload.before).toMatchObject({
            phone: '98***10',
            email: 'al***om',
            doctorRegNo: 'MC***67',
        });
        expect(payload.after).toMatchObject({
            customerPhone: '99***55',
            gstin: '27***Z5',
            vehicleNumber: 'MH***34',
            upiId: 'al***pi',
        });
    });
});

