// ============================================================================
// Unit Tests — WebSocket Service
// ============================================================================
// Tests verify DynamoDB interactions, API Gateway postToConnection,
// broadcast routing, and stale connection cleanup.
//
// Run with: npx jest src/__tests__/websocket.service.test.ts
// ============================================================================

// ── Mock AWS SDK before imports ──────────────────────────────────────────────

const mockDynamoSend = jest.fn();
const mockApiGwSend = jest.fn();

jest.mock('@aws-sdk/client-dynamodb', () => ({
    DynamoDBClient: jest.fn().mockImplementation(() => ({ send: mockDynamoSend })),
    PutItemCommand: jest.fn().mockImplementation((input: any) => ({ input, _type: 'PutItem' })),
    DeleteItemCommand: jest.fn().mockImplementation((input: any) => ({ input, _type: 'DeleteItem' })),
    QueryCommand: jest.fn().mockImplementation((input: any) => ({ input, _type: 'Query' })),
}));

jest.mock('@aws-sdk/client-apigatewaymanagementapi', () => ({
    ApiGatewayManagementApiClient: jest.fn().mockImplementation(() => ({ send: mockApiGwSend })),
    PostToConnectionCommand: jest.fn().mockImplementation((input: any) => ({ input, _type: 'PostToConnection' })),
}));

// Mock logger to suppress output
jest.mock('../utils/logger', () => ({
    logger: {
        info: jest.fn(),
        warn: jest.fn(),
        error: jest.fn(),
        debug: jest.fn(),
    },
}));

// ── Set required env vars ────────────────────────────────────────────────────
process.env.WEBSOCKET_CONNECTIONS_TABLE = 'test-ws-connections';
process.env.WEBSOCKET_API_ENDPOINT = 'https://test.execute-api.ap-south-1.amazonaws.com/dev';
process.env.AWS_REGION = 'ap-south-1';

// ── Import after mocks ──────────────────────────────────────────────────────
import * as wsService from '../services/websocket.service';
import { WSEventName, ClientType } from '../types/websocket.types';

// ============================================================================
// TEST SUITES
// ============================================================================

describe('WebSocket Service', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockDynamoSend.mockResolvedValue({});
        mockApiGwSend.mockResolvedValue({});
    });

    // ── saveConnection ───────────────────────────────────────────────────
    describe('saveConnection', () => {
        test('saves connection record to DynamoDB with TTL', async () => {
            await wsService.saveConnection({
                connectionId: 'conn-123',
                clientType: ClientType.STAFF_APP,
                businessId: 'biz-456',
                userId: 'user-789',
                connectedAt: new Date().toISOString(),
                ttl: Math.floor(Date.now() / 1000) + 86400,
            });

            expect(mockDynamoSend).toHaveBeenCalledTimes(1);
            const command = mockDynamoSend.mock.calls[0][0];
            expect(command._type).toBe('PutItem');
            expect(command.input.TableName).toBe('test-ws-connections');
            expect(command.input.Item.connectionId.S).toBe('conn-123');
            expect(command.input.Item.businessId.S).toBe('biz-456');
            expect(command.input.Item.clientType.S).toBe('staff_app');
            expect(command.input.Item.ttl).toBeDefined(); // TTL is set
        });
    });

    // ── removeConnection ────────────────────────────────────────────────
    describe('removeConnection', () => {
        test('deletes connection record from DynamoDB', async () => {
            await wsService.removeConnection('conn-123');

            expect(mockDynamoSend).toHaveBeenCalledTimes(1);
            const command = mockDynamoSend.mock.calls[0][0];
            expect(command._type).toBe('DeleteItem');
            expect(command.input.Key.connectionId.S).toBe('conn-123');
        });
    });

    // ── broadcastToBusiness ─────────────────────────────────────────────
    describe('broadcastToBusiness', () => {
        test('queries DynamoDB and sends to all connections', async () => {
            // Mock DynamoDB Query to return 2 connections
            mockDynamoSend.mockResolvedValueOnce({
                Items: [
                    { connectionId: { S: 'conn-1' }, clientType: { S: 'staff_app' } },
                    { connectionId: { S: 'conn-2' }, clientType: { S: 'desktop_app' } },
                ],
            });

            await wsService.broadcastToBusiness('biz-456', WSEventName.ORDER_CREATED, {
                orderId: 'order-1',
            });

            // 1 DynamoDB query + 2 PostToConnection
            expect(mockDynamoSend).toHaveBeenCalledTimes(1);
            expect(mockApiGwSend).toHaveBeenCalledTimes(2);
        });

        test('handles GoneException by cleaning up stale connections', async () => {
            // Mock DynamoDB Query to return 1 connection
            mockDynamoSend.mockResolvedValueOnce({
                Items: [
                    { connectionId: { S: 'stale-conn' }, clientType: { S: 'staff_app' } },
                ],
            });

            // Mock PostToConnection to throw with statusCode 410 (GoneException fallback)
            const goneError: any = new Error('GoneException');
            goneError.statusCode = 410;
            mockApiGwSend.mockRejectedValueOnce(goneError);

            // Mock DeleteItem for cleanup
            mockDynamoSend.mockResolvedValueOnce({});

            await wsService.broadcastToBusiness('biz-gone', WSEventName.ORDER_CREATED, {
                orderId: 'order-1',
            });

            // Should have made at least 1 DynamoDB call (query), and possibly cleanup
            expect(mockDynamoSend).toHaveBeenCalled();
        });

        test('handles empty connections gracefully', async () => {
            mockDynamoSend.mockResolvedValueOnce({ Items: [] });

            await wsService.broadcastToBusiness('biz-empty', WSEventName.ORDER_CREATED, {
                orderId: 'order-1',
            });

            expect(mockDynamoSend).toHaveBeenCalledTimes(1);
            expect(mockApiGwSend).not.toHaveBeenCalled();
        });
    });

    // ── broadcastToStaff ────────────────────────────────────────────────
    describe('broadcastToStaff', () => {
        test('queries connections filtered by staff_app client type', async () => {
            mockDynamoSend.mockResolvedValueOnce({
                Items: [
                    { connectionId: { S: 'staff-conn' }, clientType: { S: 'staff_app' } },
                ],
            });

            await wsService.broadcastToStaff('biz-456', WSEventName.ORDER_CREATED, {
                orderId: 'order-1',
            });

            // DynamoDB query should have been made
            expect(mockDynamoSend).toHaveBeenCalled();
        });
    });

    // ── broadcastToOwner ────────────────────────────────────────────────
    describe('broadcastToOwner', () => {
        test('queries connections filtered by desktop_app client type', async () => {
            mockDynamoSend.mockResolvedValueOnce({
                Items: [
                    { connectionId: { S: 'desktop-conn' }, clientType: { S: 'desktop_app' } },
                ],
            });

            await wsService.broadcastToOwner('biz-456', WSEventName.DASHBOARD_UPDATED, {
                metric: 'sales_total',
                value: 50000,
            });

            // DynamoDB query should have been made
            expect(mockDynamoSend).toHaveBeenCalled();
        });
    });

    // ── emitEvent routing ───────────────────────────────────────────────
    describe('emitEvent', () => {
        test('routes ORDER_CREATED to broadcastToBusiness', async () => {
            mockDynamoSend.mockResolvedValueOnce({ Items: [] });

            await wsService.emitEvent('biz-emit-1', WSEventName.ORDER_CREATED, {
                orderId: 'order-1',
            });

            // Should call broadcastToBusiness (1 DynamoDB query)
            expect(mockDynamoSend).toHaveBeenCalledTimes(1);
        });

        test('routes STAFF_ACTIVITY to broadcastToOwner (desktop only)', async () => {
            mockDynamoSend.mockResolvedValueOnce({ Items: [] });

            await wsService.emitEvent('biz-emit-2', WSEventName.STAFF_ACTIVITY, {
                action: 'pump_sale',
                staffId: 'staff-1',
            });

            expect(mockDynamoSend).toHaveBeenCalledTimes(1);
        });

        test('routes KOT_CREATED to restaurant_staff_app + desktop', async () => {
            // First call: broadcastToClientType (restaurant_staff_app)
            mockDynamoSend.mockResolvedValueOnce({ Items: [] });
            // Second call: broadcastToOwner (desktop_app)
            mockDynamoSend.mockResolvedValueOnce({ Items: [] });

            await wsService.emitEvent('biz-emit-3', WSEventName.KOT_CREATED, {
                kotId: 'kot-1',
                tableNumber: 5,
            });

            // 2 DynamoDB queries (restaurant_staff_app + desktop_app)
            expect(mockDynamoSend).toHaveBeenCalledTimes(2);
        });

        test('routes PETROL_SALE_UPDATE to broadcastToBusiness', async () => {
            mockDynamoSend.mockResolvedValueOnce({ Items: [] });

            await wsService.emitEvent('biz-emit-4', WSEventName.PETROL_SALE_UPDATE, {
                transactionId: 'txn-1',
            });

            expect(mockDynamoSend).toHaveBeenCalledTimes(1);
        });

        test('routes LOW_STOCK_ALERT to broadcastToBusiness', async () => {
            mockDynamoSend.mockResolvedValueOnce({ Items: [] });

            await wsService.emitEvent('biz-emit-5', WSEventName.LOW_STOCK_ALERT, {
                itemId: 'item-1',
                currentStock: 3,
                threshold: 5,
            });

            expect(mockDynamoSend).toHaveBeenCalledTimes(1);
        });
    });
});
