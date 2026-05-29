import { APIGatewayProxyEventV2 } from 'aws-lambda';

const mockPutItem = jest.fn().mockResolvedValue(undefined);
const mockGetItem = jest.fn().mockResolvedValue(null);
const mockUpdateItem = jest.fn().mockResolvedValue(undefined);
const mockQueryItems = jest.fn().mockResolvedValue({ items: [], lastKey: undefined });

jest.mock('../services/revision-history.service', () => ({ recordRevision: jest.fn().mockResolvedValue(undefined) }));
jest.mock('../middleware/handler-wrapper', () => ({
    authorizedHandler: (_roles: any, fn: any) => {
        return (event: APIGatewayProxyEventV2, context: any) =>
            fn(event, context, {
                tenantId: 'test-tenant-id',
                sub: 'test-user-id',
                role: 'owner',
                businessType: 'hardware',
            });
    },
}));

jest.mock('../config/dynamodb.config', () => ({
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
    },
    putItem: (...args: any[]) => mockPutItem(...args),
    getItem: (...args: any[]) => mockGetItem(...args),
    updateItem: (...args: any[]) => mockUpdateItem(...args),
    queryItems: (...args: any[]) => mockQueryItems(...args),
}));

function makeEvent(
    method: 'GET' | 'POST',
    rawPath: string,
    body?: unknown,
    queryStringParameters?: Record<string, string>,
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
        queryStringParameters,
        pathParameters,
    } as APIGatewayProxyEventV2;
}

function parsed(result: any) {
    return JSON.parse(result.body || '{}');
}

describe('Wave 4 Handler Coverage', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        delete process.env.PUMP_FLEET_INTEGRATION_ENABLED;
        delete process.env.PUMP_FLEET_PROVIDER_API_KEY;
        delete process.env.PUMP_ATG_INTEGRATION_ENABLED;
        delete process.env.PUMP_ATG_CONNECTOR_TOKEN;
    });

    test('hardware deposit create persists normalized ledger fields', async () => {
        const { createDeposit } = require('../handlers/hardware-deposits');
        const res = await createDeposit(makeEvent('POST', '/hardware/deposits', {
            customerId: '4bc7dc15-c8e2-4f4e-8829-8a06e6ec8cbf',
            itemType: 'Gas Cylinder',
            quantity: 2,
            depositAmountCents: 30000,
        }), {} as any);

        expect(res.statusCode).toBe(201);
        expect(mockPutItem).toHaveBeenCalledTimes(1);
        const item = mockPutItem.mock.calls[0][0];
        expect(item.entityType).toBe('HARDWARE_DEPOSIT');
        expect(item.outstandingDepositCents).toBe(30000);
        expect(item.status).toBe('open');
    });

    test('hardware settle rejects over-return quantity', async () => {
        const { settleDeposit } = require('../handlers/hardware-deposits');
        mockGetItem.mockResolvedValueOnce({
            id: 'dep-1',
            quantity: 5,
            returnedQuantity: 4,
            refundedAmountCents: 1000,
            depositAmountCents: 5000,
            status: 'open',
            isDeleted: false,
        });

        const res = await settleDeposit(
            makeEvent('POST', '/hardware/deposits/dep-1/settle', { returnedQuantity: 2, refundAmountCents: 500 }, undefined, { id: 'dep-1' }),
            {} as any,
        );
        const body = parsed(res);

        expect(res.statusCode).toBe(422);
        expect(body.error.code).toBe('RETURN_QTY_EXCEEDS_DEPOSIT');
        expect(mockUpdateItem).not.toHaveBeenCalled();
    });

    test('hardware project close updates status when active', async () => {
        const { closeProject } = require('../handlers/hardware-projects');
        mockGetItem.mockResolvedValueOnce({
            id: 'proj-1',
            status: 'active',
            isDeleted: false,
        });

        const res = await closeProject(
            makeEvent('POST', '/hardware/projects/proj-1/close', undefined, undefined, { id: 'proj-1' }),
            {} as any,
        );
        const body = parsed(res);

        expect(res.statusCode).toBe(200);
        expect(body.data.status).toBe('closed');
        expect(mockUpdateItem).toHaveBeenCalledTimes(1);
    });

    test('pharmacy evidence upload stores lowercase hash', async () => {
        const { uploadPrescriptionEvidence } = require('../handlers/pharmacy-compliance');
        const hash = 'ABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCD';
        const res = await uploadPrescriptionEvidence(makeEvent('POST', '/pharmacy/prescriptions/evidence', {
            prescriptionId: 'RX-123',
            storagePath: 's3://bucket/rx-123.pdf',
            fileHashSha256: hash,
        }), {} as any);

        expect(res.statusCode).toBe(201);
        expect(mockPutItem).toHaveBeenCalledTimes(1);
        const item = mockPutItem.mock.calls[0][0];
        expect(item.entityType).toBe('RX_EVIDENCE');
        expect(item.fileHashSha256).toBe(hash.toLowerCase());
    });

    test('pharmacy return policy blocks schedule X', async () => {
        const { evaluateReturnPolicy } = require('../handlers/pharmacy-compliance');
        const res = await evaluateReturnPolicy(makeEvent('POST', '/pharmacy/return-policy/evaluate', {
            stateCode: 'MH',
            drugSchedule: 'X',
            hasInvoice: true,
            invoiceAgeDays: 0,
        }), {} as any);
        const body = parsed(res);

        expect(res.statusCode).toBe(200);
        expect(body.data.allowed).toBe(false);
        expect(body.data.policyCode).toBe('BLOCK_SCHEDULE_X');
    });

    test('pump fleet authorize hard-fails when integration not configured', async () => {
        const { authorizeFleetCard } = require('../handlers/pump-integrations');
        const res = await authorizeFleetCard(makeEvent('POST', '/pump/fleet/authorize', {
            provider: 'fuelnet',
            cardNumber: '12345678',
            amountCents: 1000,
        }), {} as any);
        const body = parsed(res);

        expect(res.statusCode).toBe(501);
        expect(body.error.code).toBe('FLEET_INTEGRATION_NOT_CONFIGURED');
    });

    test('pump ATG ingest hard-fails when connector not configured', async () => {
        const { ingestAtgReading } = require('../handlers/pump-integrations');
        const res = await ingestAtgReading(makeEvent('POST', '/pump/atg/ingest', {
            tankId: 'a08d8c23-2a79-4f71-9e4b-a555637a5f75',
            source: 'atg',
            measuredVolumeLiters: 100.5,
            measuredAt: '2026-04-26T12:00:00.000Z',
        }), {} as any);
        const body = parsed(res);

        expect(res.statusCode).toBe(501);
        expect(body.error.code).toBe('ATG_INTEGRATION_NOT_CONFIGURED');
        expect(mockPutItem).not.toHaveBeenCalled();
    });

    test('pump fleet authorize fails when enabled but creds missing', async () => {
        process.env.PUMP_FLEET_INTEGRATION_ENABLED = 'true';
        const { authorizeFleetCard } = require('../handlers/pump-integrations');
        const res = await authorizeFleetCard(makeEvent('POST', '/pump/fleet/authorize', {
            provider: 'fuelnet',
            cardNumber: '12345678',
            amountCents: 1000,
        }), {} as any);
        const body = parsed(res);

        expect(res.statusCode).toBe(501);
        expect(body.error.code).toBe('FLEET_INTEGRATION_CREDENTIALS_MISSING');
    });

    test('pump ATG ingest fails when enabled but creds missing', async () => {
        process.env.PUMP_ATG_INTEGRATION_ENABLED = 'true';
        const { ingestAtgReading } = require('../handlers/pump-integrations');
        const res = await ingestAtgReading(makeEvent('POST', '/pump/atg/ingest', {
            tankId: 'a08d8c23-2a79-4f71-9e4b-a555637a5f75',
            source: 'atg',
            measuredVolumeLiters: 100.5,
            measuredAt: '2026-04-26T12:00:00.000Z',
        }), {} as any);
        const body = parsed(res);

        expect(res.statusCode).toBe(501);
        expect(body.error.code).toBe('ATG_INTEGRATION_CREDENTIALS_MISSING');
        expect(mockPutItem).not.toHaveBeenCalled();
    });

    test('pump manual dip writes tank dip record', async () => {
        const { recordManualDip } = require('../handlers/pump-integrations');
        const res = await recordManualDip(makeEvent('POST', '/pump/tank-dip', {
            tankId: '2c9ef83a-0275-46f8-9307-00c5e7b99073',
            dipLevelMm: 800,
            observedVolumeLiters: 2900,
        }), {} as any);

        expect(res.statusCode).toBe(201);
        expect(mockPutItem).toHaveBeenCalledTimes(1);
        const item = mockPutItem.mock.calls[0][0];
        expect(item.entityType).toBe('TANK_DIP_READING');
        expect(item.source).toBe('manual');
    });
});




