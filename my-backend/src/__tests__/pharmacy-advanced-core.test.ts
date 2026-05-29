import { APIGatewayProxyEventV2 } from 'aws-lambda';

const mockPutItem = jest.fn().mockResolvedValue(undefined);
const mockGetItem = jest.fn().mockResolvedValue(null);
const mockUpdateItem = jest.fn().mockResolvedValue({});
const mockQueryItems = jest.fn().mockResolvedValue({ items: [], lastKey: undefined });

jest.mock('../middleware/handler-wrapper', () => ({
    authorizedHandler: (_roles: any, fn: any) => {
        return (event: APIGatewayProxyEventV2, context: any) =>
            fn(event, context, {
                tenantId: 'test-tenant-id',
                sub: 'test-user-id',
                role: 'owner',
                businessType: 'pharmacy',
            });
    },
}));

jest.mock('../services/revision-history.service', () => ({ recordRevision: jest.fn().mockResolvedValue(undefined) }));
jest.mock('../config/dynamodb.config', () => ({
    TABLE_NAME: 'test-table',
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
        productSK: (id: string) => `PRODUCT#${id}`,
    },
    putItem: (...args: any[]) => mockPutItem(...args),
    getItem: (...args: any[]) => mockGetItem(...args),
    updateItem: (...args: any[]) => mockUpdateItem(...args),
    queryItems: (...args: any[]) => mockQueryItems(...args),
    transactWrite: jest.fn().mockResolvedValue(undefined),
}));

function makeEvent(
    method: 'GET' | 'POST',
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

describe('Pharmacy Advanced Core', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('transmitNcpdpClaim stores claim in submitted state', async () => {
        const { transmitNcpdpClaim } = require('../handlers/pharmacy');
        const res = await transmitNcpdpClaim(makeEvent('POST', '/pharmacy/claims/transmit', {
            patientId: 'pt-1',
            prescriptionId: 'rx-1',
            pharmacyNpi: '1234567890',
            dateOfService: '2026-04-26',
            payerId: 'payer-a',
            payerBin: '123456',
            payerPcn: 'PCN123',
            memberId: 'MEM-001',
            groupId: 'GRP-001',
            lines: [{ productId: 'prod-1', ndc: '12345678901', quantity: 1, daysSupply: 30 }],
        }), {} as any);
        const body = parsed(res);

        expect(res.statusCode).toBe(201);
        expect(body.data.standard).toBe('NCPDP_D0');
        expect(body.data.status).toBe('submitted');
        expect(mockPutItem).toHaveBeenCalledTimes(1);
        expect(mockPutItem.mock.calls[0][0].GSI1PK).toBe('TENANT#test-tenant-id#ENTITY#RX_CLAIM');
    });

    test('createNextCobClaim builds secondary from primary', async () => {
        const { createNextCobClaim } = require('../handlers/pharmacy');
        mockGetItem.mockResolvedValueOnce({
            id: 'claim-1',
            patientId: 'pt-1',
            prescriptionId: 'rx-1',
            pharmacyNpi: '1234567890',
            lines: [{ ndc: '12345' }],
            coordinationLevel: 'primary',
            status: 'rejected',
            payerId: 'payer-a',
        });

        const res = await createNextCobClaim(
            makeEvent('POST', '/pharmacy/claims/{id}/cob/next', { nextPayerId: 'payer-b' }, { id: 'claim-1' }),
            {} as any,
        );
        const body = parsed(res);

        expect(res.statusCode).toBe(201);
        expect(body.data.coordinationLevel).toBe('secondary');
        expect(body.data.status).toBe('submitted');
        expect(mockPutItem).toHaveBeenCalledTimes(1);
        expect(mockPutItem.mock.calls[0][0].GSI1PK).toBe('TENANT#test-tenant-id#ENTITY#RX_CLAIM');
    });

    test('runClinicalScreening reports allergy and interaction alerts', async () => {
        const { runClinicalScreening } = require('../handlers/pharmacy');
        const res = await runClinicalScreening(makeEvent('POST', '/pharmacy/cds/screen', {
            patient: {
                allergies: ['penicillin'],
            },
            drugs: [
                {
                    productId: 'prod-a',
                    drugName: 'Drug A',
                    ingredients: ['penicillin'],
                    interactionTags: ['qt-prolong'],
                },
                {
                    productId: 'prod-b',
                    drugName: 'Drug B',
                    interactionTags: ['qt-prolong'],
                },
            ],
        }), {} as any);
        const body = parsed(res);

        expect(res.statusCode).toBe(200);
        expect(body.data.alertCount).toBeGreaterThanOrEqual(2);
        const allergy = body.data.alerts.find((a: any) => a.type === 'allergy');
        const interaction = body.data.alerts.find((a: any) => a.type === 'interaction');
        expect(allergy).toBeDefined();
        expect(interaction).toBeDefined();
    });

    test('upsertDrugMasterMapping persists mapping bridge', async () => {
        const { upsertDrugMasterMapping } = require('../handlers/pharmacy');
        const res = await upsertDrugMasterMapping(makeEvent('POST', '/pharmacy/drug-master/mappings', {
            productId: 'prod-1',
            ndc: '12345-6789',
            rxNorm: '1234',
            atc: 'N02BE01',
            indiaBrandCode: 'IND-PCM-500',
        }), {} as any);
        const body = parsed(res);

        expect(res.statusCode).toBe(201);
        expect(body.data.mapped).toBe(true);
        expect(mockPutItem).toHaveBeenCalledTimes(1);
        expect(mockPutItem.mock.calls[0][0].GSI1PK).toBe('TENANT#test-tenant-id#ENTITY#DRUG_MASTER_MAPPING');
    });

    test('recordProgramTrackEvent writes 340B event', async () => {
        const { recordProgramTrackEvent } = require('../handlers/pharmacy');
        const res = await recordProgramTrackEvent(makeEvent('POST', '/pharmacy/program-track/events', {
            programType: '340B',
            eventType: 'dispense',
            claimId: 'claim-123',
            prescriptionId: 'rx-123',
            amountPaise: 9900,
        }), {} as any);
        const body = parsed(res);

        expect(res.statusCode).toBe(201);
        expect(body.data.id).toBeDefined();
        expect(mockPutItem).toHaveBeenCalledTimes(1);
    });

    test('adjudicateClaim rejects re-adjudication of finalized claim', async () => {
        const { adjudicateClaim } = require('../handlers/pharmacy');
        mockGetItem.mockResolvedValueOnce({
            id: 'claim-final',
            status: 'approved',
        });
        const res = await adjudicateClaim(
            makeEvent('POST', '/pharmacy/claims/{id}/adjudicate', {
                outcome: 'approved',
                approvedAmountPaise: 1000,
                patientPayPaise: 100,
            }, { id: 'claim-final' }),
            {} as any,
        );
        const body = parsed(res);
        expect(res.statusCode).toBe(409);
        expect(body.error.code).toBe('CLAIM_ALREADY_FINALIZED');
    });

    test('createNextCobClaim rejects when current claim not rejected', async () => {
        const { createNextCobClaim } = require('../handlers/pharmacy');
        mockGetItem.mockResolvedValueOnce({
            id: 'claim-2',
            patientId: 'pt-1',
            prescriptionId: 'rx-1',
            pharmacyNpi: '1234567890',
            payerId: 'payer-a',
            status: 'approved',
            coordinationLevel: 'primary',
        });
        const res = await createNextCobClaim(
            makeEvent('POST', '/pharmacy/claims/{id}/cob/next', { nextPayerId: 'payer-b' }, { id: 'claim-2' }),
            {} as any,
        );
        const body = parsed(res);
        expect(res.statusCode).toBe(409);
        expect(body.error.code).toBe('COB_ALLOWED_ONLY_AFTER_REJECT');
    });

    test('transmitNcpdpClaim fails schema with invalid NPI', async () => {
        const { transmitNcpdpClaim } = require('../handlers/pharmacy');
        const res = await transmitNcpdpClaim(makeEvent('POST', '/pharmacy/claims/transmit', {
            patientId: 'pt-1',
            prescriptionId: 'rx-1',
            pharmacyNpi: 'BAD-NPI',
            dateOfService: '2026-04-26',
            payerId: 'payer-a',
            payerBin: '123456',
            payerPcn: 'PCN123',
            memberId: 'MEM-001',
            groupId: 'GRP-001',
            lines: [{ productId: 'prod-1', ndc: '12345678901', quantity: 1, daysSupply: 30 }],
        }), {} as any);

        expect(res.statusCode).toBe(400);
    });

    test('listClaims returns paginated filtered rows', async () => {
        const { listClaims } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValueOnce({
            items: [
                {
                    id: 'c1',
                    status: 'submitted',
                    coordinationLevel: 'primary',
                    payerId: 'payer-a',
                    prescriptionId: 'rx-1',
                    submittedAt: '2026-04-26T10:00:00.000Z',
                },
                {
                    id: 'c2',
                    status: 'approved',
                    coordinationLevel: 'secondary',
                    payerId: 'payer-b',
                    prescriptionId: 'rx-2',
                    submittedAt: '2026-04-26T11:00:00.000Z',
                },
            ],
            lastKey: undefined,
        });

        const res = await listClaims(
            makeEvent('GET', '/pharmacy/claims', undefined, undefined) as any,
            {} as any,
        );
        const body = parsed(res);
        expect(res.statusCode).toBe(200);
        expect(Array.isArray(body.data)).toBe(true);
        expect(body.meta.limit).toBeDefined();
        expect(body.data[0].id).toBe('c2');
        const callArgs = mockQueryItems.mock.calls[0];
        expect(callArgs[0]).toBe('TENANT#test-tenant-id#ENTITY#RX_CLAIM');
        expect(callArgs[2].indexName).toBe('GSI1');
    });

    test('listClaims supports cursor pagination', async () => {
        const { listClaims } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValue({
            items: [
                { id: 'c1', status: 'submitted', coordinationLevel: 'primary', payerId: 'p1', prescriptionId: 'rx1', submittedAt: '2026-04-26T10:00:00.000Z' },
                { id: 'c2', status: 'submitted', coordinationLevel: 'primary', payerId: 'p1', prescriptionId: 'rx2', submittedAt: '2026-04-26T09:00:00.000Z' },
                { id: 'c3', status: 'submitted', coordinationLevel: 'primary', payerId: 'p1', prescriptionId: 'rx3', submittedAt: '2026-04-26T08:00:00.000Z' },
            ],
            lastKey: undefined,
        });

        const ev1 = makeEvent('GET', '/pharmacy/claims') as any;
        ev1.queryStringParameters = { pageSize: '2' };
        const res1 = await listClaims(ev1, {} as any);
        const body1 = parsed(res1);
        expect(res1.statusCode).toBe(200);
        expect(body1.data.length).toBe(2);
        expect(body1.meta.hasMore).toBe(true);
        expect(typeof body1.meta.nextCursor).toBe('string');

        const ev2 = makeEvent('GET', '/pharmacy/claims') as any;
        ev2.queryStringParameters = { pageSize: '2', cursor: body1.meta.nextCursor };
        const res2 = await listClaims(ev2, {} as any);
        const body2 = parsed(res2);
        expect(res2.statusCode).toBe(200);
        expect(body2.data.length).toBe(1);
        expect(body2.data[0].id).toBe('c3');
    });

    test('listClaims applies status filter', async () => {
        const { listClaims } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValueOnce({
            items: [
                { id: 'c1', status: 'submitted', coordinationLevel: 'primary', payerId: 'p1', prescriptionId: 'rx1', submittedAt: '2026-04-26T10:00:00.000Z' },
                { id: 'c2', status: 'approved', coordinationLevel: 'secondary', payerId: 'p2', prescriptionId: 'rx2', submittedAt: '2026-04-26T10:00:00.000Z' },
            ],
            lastKey: undefined,
        });
        const ev = makeEvent('GET', '/pharmacy/claims') as any;
        ev.queryStringParameters = { status: 'approved' };
        const res = await listClaims(ev, {} as any);
        const body = parsed(res);
        expect(res.statusCode).toBe(200);
        expect(body.data.length).toBe(1);
        expect(body.data[0].id).toBe('c2');
    });

    test('listPriorAuthorizations returns rows', async () => {
        const { listPriorAuthorizations } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValueOnce({
            items: [{
                id: 'pa-1',
                patientId: 'pt-1',
                prescriptionId: 'rx-1',
                payerId: 'payer-a',
                productId: 'prod-1',
                status: 'submitted',
                updatedAt: '2026-04-26T10:00:00.000Z',
            }],
            lastKey: undefined,
        });
        const res = await listPriorAuthorizations(makeEvent('GET', '/pharmacy/prior-auth'), {} as any);
        const body = parsed(res);
        expect(res.statusCode).toBe(200);
        expect(body.data.length).toBe(1);
    });

    test('listPriorAuthorizations sorts by updatedAt desc', async () => {
        const { listPriorAuthorizations } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValueOnce({
            items: [
                { id: 'pa-1', status: 'submitted', updatedAt: '2026-04-26T09:00:00.000Z' },
                { id: 'pa-2', status: 'submitted', updatedAt: '2026-04-26T10:00:00.000Z' },
            ],
            lastKey: undefined,
        });
        const res = await listPriorAuthorizations(makeEvent('GET', '/pharmacy/prior-auth'), {} as any);
        const body = parsed(res);
        expect(res.statusCode).toBe(200);
        expect(body.data[0].id).toBe('pa-2');
    });

    test('listPriorAuthorizations supports cursor pagination', async () => {
        const { listPriorAuthorizations } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValue({
            items: [
                { id: 'pa-1', status: 'submitted', updatedAt: '2026-04-26T10:00:00.000Z' },
                { id: 'pa-2', status: 'submitted', updatedAt: '2026-04-26T09:00:00.000Z' },
                { id: 'pa-3', status: 'submitted', updatedAt: '2026-04-26T08:00:00.000Z' },
            ],
            lastKey: undefined,
        });
        const ev1 = makeEvent('GET', '/pharmacy/prior-auth') as any;
        ev1.queryStringParameters = { pageSize: '2' };
        const res1 = await listPriorAuthorizations(ev1, {} as any);
        const body1 = parsed(res1);
        expect(res1.statusCode).toBe(200);
        expect(body1.data.length).toBe(2);
        expect(body1.meta.hasMore).toBe(true);

        const ev2 = makeEvent('GET', '/pharmacy/prior-auth') as any;
        ev2.queryStringParameters = { pageSize: '2', cursor: body1.meta.nextCursor };
        const res2 = await listPriorAuthorizations(ev2, {} as any);
        const body2 = parsed(res2);
        expect(res2.statusCode).toBe(200);
        expect(body2.data.length).toBe(1);
        expect(body2.data[0].id).toBe('pa-3');
    });

    test('listPriorAuthorizations applies status filter', async () => {
        const { listPriorAuthorizations } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValueOnce({
            items: [
                { id: 'pa-1', status: 'submitted', updatedAt: '2026-04-26T10:00:00.000Z' },
                { id: 'pa-2', status: 'approved', updatedAt: '2026-04-26T10:00:00.000Z' },
            ],
            lastKey: undefined,
        });
        const ev = makeEvent('GET', '/pharmacy/prior-auth') as any;
        ev.queryStringParameters = { status: 'approved' };
        const res = await listPriorAuthorizations(ev, {} as any);
        const body = parsed(res);
        expect(res.statusCode).toBe(200);
        expect(body.data.length).toBe(1);
        expect(body.data[0].id).toBe('pa-2');
    });

    test('listDrugMasterMappings returns rows', async () => {
        const { listDrugMasterMappings } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValueOnce({
            items: [{
                productId: 'prod-1',
                ndc: '12345678901',
                rxNorm: '1234',
                atc: 'N02BE01',
                updatedAt: '2026-04-26T10:00:00.000Z',
            }],
            lastKey: undefined,
        });
        const res = await listDrugMasterMappings(makeEvent('GET', '/pharmacy/drug-master/mappings'), {} as any);
        const body = parsed(res);
        expect(res.statusCode).toBe(200);
        expect(body.data.length).toBe(1);
    });

    test('listDrugMasterMappings sorts by updatedAt desc', async () => {
        const { listDrugMasterMappings } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValueOnce({
            items: [
                { productId: 'prod-1', ndc: '12345678901', rxNorm: '111', atc: 'N02', updatedAt: '2026-04-26T08:00:00.000Z' },
                { productId: 'prod-2', ndc: '12345678902', rxNorm: '222', atc: 'N03', updatedAt: '2026-04-26T09:00:00.000Z' },
            ],
            lastKey: undefined,
        });
        const res = await listDrugMasterMappings(makeEvent('GET', '/pharmacy/drug-master/mappings'), {} as any);
        const body = parsed(res);
        expect(res.statusCode).toBe(200);
        expect(body.data[0].productId).toBe('prod-2');
    });

    test('listDrugMasterMappings supports cursor pagination', async () => {
        const { listDrugMasterMappings } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValue({
            items: [
                { productId: 'prod-1', ndc: '12345678901', rxNorm: '111', atc: 'N02', updatedAt: '2026-04-26T10:00:00.000Z' },
                { productId: 'prod-2', ndc: '12345678902', rxNorm: '222', atc: 'N03', updatedAt: '2026-04-26T09:00:00.000Z' },
                { productId: 'prod-3', ndc: '12345678903', rxNorm: '333', atc: 'N04', updatedAt: '2026-04-26T08:00:00.000Z' },
            ],
            lastKey: undefined,
        });
        const ev1 = makeEvent('GET', '/pharmacy/drug-master/mappings') as any;
        ev1.queryStringParameters = { pageSize: '2' };
        const res1 = await listDrugMasterMappings(ev1, {} as any);
        const body1 = parsed(res1);
        expect(res1.statusCode).toBe(200);
        expect(body1.data.length).toBe(2);
        expect(body1.meta.hasMore).toBe(true);

        const ev2 = makeEvent('GET', '/pharmacy/drug-master/mappings') as any;
        ev2.queryStringParameters = { pageSize: '2', cursor: body1.meta.nextCursor };
        const res2 = await listDrugMasterMappings(ev2, {} as any);
        const body2 = parsed(res2);
        expect(res2.statusCode).toBe(200);
        expect(body2.data.length).toBe(1);
        expect(body2.data[0].productId).toBe('prod-3');
    });

    test('listFormulary returns rows', async () => {
        const { listFormulary } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValueOnce({
            items: [{
                formularyId: 'f-1',
                payerId: 'payer-a',
                name: 'Base Formulary',
                products: [{ productId: 'prod-1', tier: 1 }],
                updatedAt: '2026-04-26T10:00:00.000Z',
            }],
            lastKey: undefined,
        });
        const res = await listFormulary(makeEvent('GET', '/pharmacy/formulary'), {} as any);
        const body = parsed(res);
        expect(res.statusCode).toBe(200);
        expect(body.data.length).toBe(1);
        expect(body.data[0].productCount).toBe(1);
    });

    test('listFormulary sorts by updatedAt desc', async () => {
        const { listFormulary } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValueOnce({
            items: [
                { formularyId: 'f-1', payerId: 'payer-a', name: 'Old', products: [], updatedAt: '2026-04-26T08:00:00.000Z' },
                { formularyId: 'f-2', payerId: 'payer-a', name: 'New', products: [], updatedAt: '2026-04-26T09:00:00.000Z' },
            ],
            lastKey: undefined,
        });
        const res = await listFormulary(makeEvent('GET', '/pharmacy/formulary'), {} as any);
        const body = parsed(res);
        expect(res.statusCode).toBe(200);
        expect(body.data[0].formularyId).toBe('f-2');
    });

    test('listFormulary supports cursor pagination', async () => {
        const { listFormulary } = require('../handlers/pharmacy');
        mockQueryItems.mockResolvedValue({
            items: [
                { formularyId: 'f-1', payerId: 'payer-a', name: 'One', products: [], updatedAt: '2026-04-26T10:00:00.000Z' },
                { formularyId: 'f-2', payerId: 'payer-a', name: 'Two', products: [], updatedAt: '2026-04-26T09:00:00.000Z' },
                { formularyId: 'f-3', payerId: 'payer-a', name: 'Three', products: [], updatedAt: '2026-04-26T08:00:00.000Z' },
            ],
            lastKey: undefined,
        });
        const ev1 = makeEvent('GET', '/pharmacy/formulary') as any;
        ev1.queryStringParameters = { pageSize: '2' };
        const res1 = await listFormulary(ev1, {} as any);
        const body1 = parsed(res1);
        expect(res1.statusCode).toBe(200);
        expect(body1.data.length).toBe(2);
        expect(body1.meta.hasMore).toBe(true);

        const ev2 = makeEvent('GET', '/pharmacy/formulary') as any;
        ev2.queryStringParameters = { pageSize: '2', cursor: body1.meta.nextCursor };
        const res2 = await listFormulary(ev2, {} as any);
        const body2 = parsed(res2);
        expect(res2.statusCode).toBe(200);
        expect(body2.data.length).toBe(1);
        expect(body2.data[0].formularyId).toBe('f-3');
    });

    test('getClaimById returns claim details', async () => {
        const { getClaimById } = require('../handlers/pharmacy');
        mockGetItem.mockResolvedValueOnce({
            id: 'c-1',
            patientId: 'pt-1',
            prescriptionId: 'rx-1',
            payerId: 'payer-a',
            standard: 'NCPDP_D0',
            status: 'submitted',
            coordinationLevel: 'primary',
            lines: [{ ndc: '12345678901' }],
            submittedAt: '2026-04-26T10:00:00.000Z',
            updatedAt: '2026-04-26T10:00:00.000Z',
        });
        const res = await getClaimById(makeEvent('GET', '/pharmacy/claims/{id}', undefined, { id: 'c-1' }), {} as any);
        const body = parsed(res);
        expect(res.statusCode).toBe(200);
        expect(body.data.id).toBe('c-1');
        expect(body.data.standard).toBe('NCPDP_D0');
    });

    test('getPriorAuthorizationById returns details', async () => {
        const { getPriorAuthorizationById } = require('../handlers/pharmacy');
        mockGetItem.mockResolvedValueOnce({
            id: 'pa-1',
            patientId: 'pt-1',
            prescriptionId: 'rx-1',
            productId: 'prod-1',
            payerId: 'payer-a',
            reason: 'Needs approval',
            diagnosisCodes: ['I10'],
            status: 'submitted',
            createdAt: '2026-04-26T10:00:00.000Z',
            updatedAt: '2026-04-26T10:00:00.000Z',
        });
        const res = await getPriorAuthorizationById(
            makeEvent('GET', '/pharmacy/prior-auth/{id}', undefined, { id: 'pa-1' }),
            {} as any,
        );
        const body = parsed(res);
        expect(res.statusCode).toBe(200);
        expect(body.data.id).toBe('pa-1');
        expect(body.data.diagnosisCodes[0]).toBe('I10');
    });
});

