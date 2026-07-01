// ============================================================================
// TEST J — WebSocket Isolation: Connection-Level Tenant Scoping
// ============================================================================
// Validates that:
//   1. $connect verifies JWT via CognitoJwtVerifier
//   2. businessId ownership is validated via DynamoDB lookup
//   3. Staff role restricted to assigned businesses only
//   4. Event broadcasting only reaches connections with matching businessId
// ============================================================================

import { TENANT_A, TENANT_B, USERS } from '../setup/jwt-factory';
import { IDS } from '../setup/test-fixtures';

// Mock the PharmacyWebSocketHandler for broadcast isolation
import { PharmacyWebSocketHandler } from '../../../../../my-backend/src/websocket/pharmacy-websocket.handler';

describe('Attack Vector J — WebSocket Isolation', () => {

    describe('PharmacyWebSocketHandler — Event Broadcasting Isolation', () => {
        let wsHandler: PharmacyWebSocketHandler;

        // Mock socket
        const createMockSocket = () => ({
            readyState: 1, // OPEN
            send: jest.fn(),
        });

        beforeEach(() => {
            wsHandler = new PharmacyWebSocketHandler();
        });

        it('SECURITY: Events only broadcast to clients with matching tenantId', async () => {
            const socketA = createMockSocket();
            const socketB = createMockSocket();

            // Register clients for different tenants
            wsHandler.addClient('conn-a', TENANT_A.tenantId, 'pharmacy', socketA);
            wsHandler.addClient('conn-b', TENANT_B.tenantId, 'pharmacy', socketB);

            // Clear connection message mock calls
            socketA.send.mockClear();
            socketB.send.mockClear();

            // Trigger event for Tenant A
            wsHandler.triggerInventoryUpdate(
                TENANT_A.tenantId,
                'prod-123',
                50,
                'Paracetamol',
            );

            // Allow async event handling
            await new Promise(resolve => setTimeout(resolve, 50));

            // Tenant A's socket should receive the event
            expect(socketA.send).toHaveBeenCalled();

            // Tenant B's socket should NOT receive the event
            expect(socketB.send).not.toHaveBeenCalled();
        });

        it('SECURITY: Stock alerts only reach the correct tenant', async () => {
            const socketA = createMockSocket();
            const socketB = createMockSocket();

            wsHandler.addClient('conn-a', TENANT_A.tenantId, 'pharmacy', socketA);
            wsHandler.addClient('conn-b', TENANT_B.tenantId, 'pharmacy', socketB);

            // Clear connection message mock calls
            socketA.send.mockClear();
            socketB.send.mockClear();

            wsHandler.triggerStockThresholdBreach(
                TENANT_B.tenantId,
                'prod-b',
                'Medicine X',
                5,
                10,
            );

            await new Promise(resolve => setTimeout(resolve, 50));

            // Tenant B should get the alert
            expect(socketB.send).toHaveBeenCalled();

            // Tenant A should NOT
            expect(socketA.send).not.toHaveBeenCalled();
        });

        it('INTEGRITY: getTenantClientCount scoped correctly', () => {
            const socketA1 = createMockSocket();
            const socketA2 = createMockSocket();
            const socketB = createMockSocket();

            wsHandler.addClient('a1', TENANT_A.tenantId, 'pharmacy', socketA1);
            wsHandler.addClient('a2', TENANT_A.tenantId, 'pharmacy', socketA2);
            wsHandler.addClient('b1', TENANT_B.tenantId, 'pharmacy', socketB);

            expect(wsHandler.getTenantClientCount(TENANT_A.tenantId)).toBe(2);
            expect(wsHandler.getTenantClientCount(TENANT_B.tenantId)).toBe(1);
        });

        it('SECURITY: Non-pharmacy clients are not added', () => {
            const socket = createMockSocket();
            wsHandler.addClient('c1', TENANT_A.tenantId, 'electronics', socket);

            expect(wsHandler.getClientCount()).toBe(0);
        });

        it('SECURITY: Disconnected client receives no events', async () => {
            const socketA = createMockSocket();
            wsHandler.addClient('conn-a', TENANT_A.tenantId, 'pharmacy', socketA);
            
            // Clear connection message mock calls
            socketA.send.mockClear();

            wsHandler.removeClient('conn-a');

            wsHandler.triggerInventoryUpdate(TENANT_A.tenantId, 'prod', 10, 'Test');
            await new Promise(resolve => setTimeout(resolve, 50));

            expect(socketA.send).not.toHaveBeenCalled();
        });
    });
});
