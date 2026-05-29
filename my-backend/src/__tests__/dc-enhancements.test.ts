// @ts-nocheck
/// <reference types="jest" />
// ============================================================================
// DC (Decoration & Catering) Module Enhancement Tests
// ============================================================================
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { WSEventName } from '../types/websocket.types';

// ---- Test Helpers ----
function makeEvent(overrides: Partial<APIGatewayProxyEventV2> = {}): APIGatewayProxyEventV2 {
    return {
        version: '2.0',
        routeKey: '$default',
        rawPath: '/',
        rawQueryString: '',
        headers: { authorization: 'Bearer test-token' },
        requestContext: {
            accountId: '123',
            apiId: 'test',
            domainName: 'test.execute-api.us-east-1.amazonaws.com',
            domainPrefix: 'test',
            http: { method: 'GET', path: '/', protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'test' },
            requestId: 'test-req-id',
            routeKey: '$default',
            stage: '$default',
            time: new Date().toISOString(),
            timeEpoch: Date.now(),
        },
        isBase64Encoded: false,
        ...overrides,
    } as APIGatewayProxyEventV2;
}

const mockContext: Context = {
    callbackWaitsForEmptyEventLoop: false,
    functionName: 'test',
    functionVersion: '1',
    invokedFunctionArn: 'arn:aws:lambda:us-east-1:123:function:test',
    memoryLimitInMB: '128',
    awsRequestId: 'test-req',
    logGroupName: '/aws/lambda/test',
    logStreamName: 'test-stream',
    getRemainingTimeInMillis: () => 30000,
    done: () => { },
    fail: () => { },
    succeed: () => { },
};

function parseBody(result: any): any {
    return JSON.parse(result.body || '{}');
}

// Mock dependencies
jest.mock('../services/websocket.service');
jest.mock('../utils/logger');
jest.mock('../config/dynamodb.config', () => ({
    Keys: {
        tenantPK: (tenantId: string) => `TENANT#${tenantId}`,
        dcEventSK: (id: string) => `DC_EVENT#${id}`,
        dcVendorSK: (id: string) => `DC_VENDOR#${id}`,
        dcExpenseSK: (id: string) => `DC_EXPENSE#${id}`,
        dcQuoteSK: (id: string) => `DC_QUOTE#${id}`,
        dcEventGSI1PK: (tenantId: string) => `TENANT#${tenantId}#DC_EVENTS`,
        dcEventGSI1SK: (date: string, id: string) => `${date}#${id}`,
    },
    queryAllItems: jest.fn(),
    queryItems: jest.fn(),
    putItem: jest.fn(),
    getItem: jest.fn(),
    updateItem: jest.fn(),
    deleteItem: jest.fn(),
}));

const mockDynamoDB = jest.requireMock('../config/dynamodb.config');
const mockWebSocket = jest.requireMock('../services/websocket.service');

describe('DC Module - Phase 1: Critical Backend Fixes', () => {
    const auth = { tenantId: 'test-tenant', sub: 'user-123', businessType: 'DECORATION_CATERING' };

    beforeEach(() => {
        jest.clearAllMocks();
    });

    describe('Missing CRUD Endpoints', () => {
        describe('getQuote', () => {
            it('should return a single quote by ID', async () => {
                const mockQuote = {
                    id: 'quote-123',
                    quoteNumber: 'QT-2026-001',
                    customerName: 'Test Customer',
                    status: 'draft',
                    isDeleted: false,
                };
                mockDynamoDB.getItem.mockResolvedValue(mockQuote);

                const event = { pathParameters: { id: 'quote-123' } } as any;
                const result = await getQuote(event, {} as any, auth as any);

                expect(result.statusCode).toBe(200);
                expect(JSON.parse(result.body).data).toEqual(mockQuote);
            });

            it('should return 404 for non-existent quote', async () => {
                mockDynamoDB.getItem.mockResolvedValue(null);

                const event = { pathParameters: { id: 'non-existent' } } as any;
                const result = await getQuote(event, {} as any, auth as any);

                expect(result.statusCode).toBe(404);
            });
        });

        describe('Expense CRUD', () => {
            it('getExpense should return a single expense', async () => {
                const mockExpense = {
                    id: 'expense-123',
                    category: 'decorations',
                    amountPaisa: 50000,
                    date: '2026-05-20',
                };
                mockDynamoDB.getItem.mockResolvedValue(mockExpense);

                const event = { pathParameters: { id: 'expense-123' } } as any;
                const result = await getExpense(event, {} as any, auth as any);

                expect(result.statusCode).toBe(200);
                expect(JSON.parse(result.body).data).toEqual(mockExpense);
            });

            it('updateExpense should update allowed fields', async () => {
                const existing = {
                    id: 'expense-123',
                    category: 'decorations',
                    amountPaisa: 50000,
                };
                mockDynamoDB.getItem.mockResolvedValue(existing);
                mockDynamoDB.updateItem.mockResolvedValue({});

                const event = {
                    pathParameters: { id: 'expense-123' },
                    body: JSON.stringify({ category: 'catering', amountPaisa: 75000 }),
                } as any;
                const result = await updateExpense(event, {} as any, auth as any);

                expect(result.statusCode).toBe(200);
                expect(mockDynamoDB.updateItem).toHaveBeenCalled();
            });

            it('deleteExpense should hard delete expense', async () => {
                mockDynamoDB.getItem.mockResolvedValue({ id: 'expense-123' });
                mockDynamoDB.deleteItem.mockResolvedValue({});

                const event = { pathParameters: { id: 'expense-123' } } as any;
                const result = await deleteExpense(event, {} as any, auth as any);

                expect(result.statusCode).toBe(200);
                expect(mockDynamoDB.deleteItem).toHaveBeenCalled();
            });
        });
    });

    describe('Vendor totalDue Calculation', () => {
        it('listVendors should calculate totalPaidPaisa, totalDuePaisa, totalExpensePaisa', async () => {
            const vendors = [
                { id: 'v1', name: 'Flower Vendor', phone: '9999999999', vendorType: 'flowers', isDeleted: false },
            ];
            const expenses = [
                { id: 'e1', paidTo: 'Flower Vendor', amountPaisa: 100000, isDeleted: false },
                { id: 'e2', paidTo: 'Flower Vendor', amountPaisa: 50000, isDeleted: false },
            ];
            const payments = [
                { id: 'p1', vendorId: 'v1', amountPaisa: 80000 },
            ];

            mockDynamoDB.queryAllItems
                .mockResolvedValueOnce(vendors)
                .mockResolvedValueOnce(expenses)
                .mockResolvedValueOnce(payments);

            const event = {} as any;
            const result = await listVendors(event, {} as any, auth as any);
            const responseData = JSON.parse(result.body).data;

            expect(responseData[0]).toMatchObject({
                totalExpensePaisa: 150000,
                totalPaidPaisa: 80000,
                totalDuePaisa: 70000,
            });
        });

        it('createVendor should initialize with zero totals', async () => {
            mockDynamoDB.putItem.mockResolvedValue({});

            const event = {
                body: JSON.stringify({
                    name: 'New Vendor',
                    phone: '9999999999',
                    vendorType: 'catering',
                }),
            } as any;
            await createVendor(event, {} as any, auth as any);

            expect(mockDynamoDB.putItem).toHaveBeenCalledWith(
                expect.objectContaining({
                    totalPaidPaisa: 0,
                    totalDuePaisa: 0,
                    rating: 0,
                    ratingCount: 0,
                })
            );
        });
    });
});

describe('DC Module - Phase 2: Dashboard Filtering & WebSocket', () => {
    const auth = { tenantId: 'test-tenant', sub: 'user-123', businessType: 'DECORATION_CATERING' };

    beforeEach(() => {
        jest.clearAllMocks();
    });

    describe('Date Range Filtering', () => {
        it('getDashboard should filter by date range', async () => {
            const events = [
                { id: 'e1', eventDate: '2026-05-15', status: 'confirmed' },
                { id: 'e2', eventDate: '2026-05-20', status: 'confirmed' },
                { id: 'e3', eventDate: '2026-06-01', status: 'confirmed' },
            ];
            const invoices = [
                { id: 'i1', createdAt: '2026-05-10T10:00:00Z', totalPaisa: 100000 },
                { id: 'i2', createdAt: '2026-05-20T10:00:00Z', totalPaisa: 200000 },
            ];
            const expenses = [
                { id: 'ex1', date: '2026-05-15', amountPaisa: 30000 },
            ];

            mockDynamoDB.queryAllItems
                .mockResolvedValueOnce(events)
                .mockResolvedValueOnce(invoices)
                .mockResolvedValueOnce(expenses)
                .mockResolvedValueOnce([])
                .mockResolvedValueOnce([]);

            const event = {
                queryStringParameters: { from: '2026-05-01', to: '2026-05-31' },
            } as any;
            const result = await getDashboard(event, {} as any, auth as any);
            const responseData = JSON.parse(result.body).data;

            expect(responseData.dateRange).toEqual({ from: '2026-05-01', to: '2026-05-31' });
            expect(responseData.kpis.totalEvents).toBe(2); // Only e1 and e2
            expect(responseData.kpis.revenueThisMonthPaisa).toBe(300000);
        });

        it('getDashboard should use default month range when no dates provided', async () => {
            mockDynamoDB.queryAllItems
                .mockResolvedValueOnce([])
                .mockResolvedValueOnce([])
                .mockResolvedValueOnce([])
                .mockResolvedValueOnce([])
                .mockResolvedValueOnce([]);

            const event = {} as any;
            const result = await getDashboard(event, {} as any, auth as any);
            const responseData = JSON.parse(result.body).data;

            expect(responseData.dateRange.from).toMatch(/^\d{4}-\d{2}-01$/);
        });
    });

    describe('WebSocket Broadcasting', () => {
        it('createEvent should broadcast DC_EVENT_CREATED', async () => {
            mockDynamoDB.putItem.mockResolvedValue({});

            const event = {
                body: JSON.stringify({
                    customerName: 'Test',
                    customerPhone: '9999999999',
                    eventType: 'wedding',
                    eventDate: '2026-06-15',
                    guestCount: 100,
                }),
            } as any;
            await createEvent(event, {} as any, auth as any);

            expect(mockWebSocket.broadcastToClientType).toHaveBeenCalledWith(
                'test-tenant',
                expect.any(String),
                WSEventName.DC_EVENT_CREATED,
                expect.objectContaining({ eventId: expect.any(String) })
            );
        });

        it('updateEvent should broadcast DC_EVENT_STATUS_CHANGED when status changes', async () => {
            const existing = {
                id: 'event-123',
                status: 'enquiry',
            };
            mockDynamoDB.getItem.mockResolvedValue(existing);
            mockDynamoDB.updateItem.mockResolvedValue({});

            const event = {
                pathParameters: { id: 'event-123' },
                body: JSON.stringify({ status: 'confirmed' }),
            } as any;
            await updateEvent(event, {} as any, auth as any);

            expect(mockWebSocket.broadcastToClientType).toHaveBeenCalledWith(
                'test-tenant',
                expect.any(String),
                WSEventName.DC_EVENT_STATUS_CHANGED,
                expect.objectContaining({
                    eventId: 'event-123',
                    statusChanged: true,
                    previousStatus: 'enquiry',
                })
            );
        });
    });
});

describe('DC Module - Phase 3: Scheduling & Ratings', () => {
    const auth = { tenantId: 'test-tenant', sub: 'user-123', businessType: 'DECORATION_CATERING' };

    beforeEach(() => {
        jest.clearAllMocks();
    });

    describe('Event Scheduling Fields', () => {
        it('createEvent should accept scheduling times', async () => {
            mockDynamoDB.putItem.mockResolvedValue({});

            const event = {
                body: JSON.stringify({
                    customerName: 'Test',
                    customerPhone: '9999999999',
                    eventType: 'wedding',
                    eventDate: '2026-06-15',
                    guestCount: 100,
                    setupTime: '14:00',
                    serviceStartTime: '16:00',
                    serviceEndTime: '22:00',
                    cleanupTime: '23:00',
                }),
            } as any;
            await createEvent(event, {} as any, auth as any);

            expect(mockDynamoDB.putItem).toHaveBeenCalledWith(
                expect.objectContaining({
                    setupTime: '14:00',
                    serviceStartTime: '16:00',
                    serviceEndTime: '22:00',
                    cleanupTime: '23:00',
                })
            );
        });

        it('updateEvent should allow updating scheduling times', async () => {
            mockDynamoDB.getItem.mockResolvedValue({ id: 'event-123', status: 'confirmed' });
            mockDynamoDB.updateItem.mockResolvedValue({});

            const event = {
                pathParameters: { id: 'event-123' },
                body: JSON.stringify({
                    setupTime: '13:00',
                    serviceStartTime: '15:00',
                }),
            } as any;
            await updateEvent(event, {} as any, auth as any);

            expect(mockDynamoDB.updateItem).toHaveBeenCalledWith(
                expect.any(String),
                expect.any(String),
                expect.objectContaining({
                    updateExpression: expect.stringContaining('setupTime'),
                })
            );
        });
    });
});
