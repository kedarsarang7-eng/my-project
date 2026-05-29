import { APIGatewayProxyEventV2 } from 'aws-lambda';

const mockGetItem = jest.fn();
const mockPutItem = jest.fn();
const mockUpdateItem = jest.fn();

jest.mock('../middleware/handler-wrapper', () => ({
    authorizedHandler: (_roles: any, fn: any) => {
        return (event: APIGatewayProxyEventV2, context: any) =>
            fn(event, context, {
                tenantId: 'tenant-1',
                sub: 'user-1',
                role: 'owner',
                businessType: 'clinic',
            });
    },
}));

jest.mock('../config/dynamodb.config', () => ({
    getItem: (...args: any[]) => mockGetItem(...args),
    putItem: (...args: any[]) => mockPutItem(...args),
    updateItem: (...args: any[]) => mockUpdateItem(...args),
}));

function makeEvent(
    method: string,
    rawPath: string,
    body?: unknown,
    pathParameters?: Record<string, string>,
): APIGatewayProxyEventV2 {
    return {
        version: '2.0',
        routeKey: `${method} ${rawPath}`,
        rawPath,
        rawQueryString: '',
        headers: { authorization: 'Bearer test-token', 'content-type': 'application/json' },
        requestContext: {
            accountId: '123',
            apiId: 'test',
            domainName: 'test.local',
            domainPrefix: 'test',
            http: { method, path: rawPath, protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'jest' },
            requestId: 'req-1',
            routeKey: `${method} ${rawPath}`,
            stage: '$default',
            time: new Date().toISOString(),
            timeEpoch: Date.now(),
        },
        isBase64Encoded: false,
        body: body === undefined ? undefined : JSON.stringify(body),
        pathParameters,
    } as APIGatewayProxyEventV2;
}

function parsed(result: any) {
    return JSON.parse(result.body || '{}');
}

describe('shared-prescriptions handlers', () => {
    let handlers: any;

    beforeAll(() => {
        handlers = require('../handlers/shared-prescriptions');
    });

    beforeEach(() => {
        jest.clearAllMocks();
        mockGetItem.mockResolvedValue(null);
        mockPutItem.mockResolvedValue(undefined);
        mockUpdateItem.mockResolvedValue(undefined);
    });

    test('uploadSharedPrescription creates new shared prescription', async () => {
        const res = await handlers.uploadSharedPrescription(
            makeEvent('POST', '/prescriptions', {
                rx_id: 'RX-1001',
                doctor_name: 'Dr A',
                patient_name: 'Patient A',
                items: [{ medicineName: 'Tab A', dosage: '1-0-1', duration: '5d' }],
            }),
            {} as any,
        );
        const body = parsed(res);

        expect(res.statusCode).toBe(201);
        expect(body.success).toBe(true);
        expect(mockPutItem).toHaveBeenCalledTimes(1);
        const item = mockPutItem.mock.calls[0][0];
        expect(item.PK).toBe('PRESCRIPTION');
        expect(item.SK).toBe('PRESCRIPTION#RX-1001');
        expect(item.clinic_shop_id).toBe('tenant-1');
        expect(item.status).toBe('pending');
    });

    test('uploadSharedPrescription rejects duplicate rx id', async () => {
        mockGetItem.mockResolvedValueOnce({ rx_id: 'RX-1001' });
        const res = await handlers.uploadSharedPrescription(
            makeEvent('POST', '/prescriptions', {
                rx_id: 'RX-1001',
                doctor_name: 'Dr A',
                patient_name: 'Patient A',
                items: [{ medicineName: 'Tab A' }],
            }),
            {} as any,
        );
        const body = parsed(res);

        expect(res.statusCode).toBe(409);
        expect(body.success).toBe(false);
        expect(mockPutItem).not.toHaveBeenCalled();
    });

    test('getSharedPrescription blocks cross-tenant access', async () => {
        mockGetItem.mockResolvedValueOnce({
            rx_id: 'RX-1',
            clinic_shop_id: 'tenant-2',
            items: [],
        });
        const res = await handlers.getSharedPrescription(
            makeEvent('GET', '/prescriptions/RX-1', undefined, { rxId: 'RX-1' }),
            {} as any,
        );
        const body = parsed(res);

        expect(res.statusCode).toBe(403);
        expect(body.success).toBe(false);
    });

    test('dispenseSharedPrescription marks pending rx as dispensed', async () => {
        mockGetItem.mockResolvedValueOnce({
            rx_id: 'RX-9',
            clinic_shop_id: 'tenant-1',
            status: 'pending',
        });

        const res = await handlers.dispenseSharedPrescription(
            makeEvent('PATCH', '/prescriptions/RX-9/dispense', {}, { rxId: 'RX-9' }),
            {} as any,
        );
        const body = parsed(res);

        expect(res.statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(mockUpdateItem).toHaveBeenCalledTimes(1);
    });
});
