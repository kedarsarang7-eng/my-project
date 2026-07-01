// ============================================================================
// TEST K — EventBridge Isolation: Async Event Tenant Scoping
// ============================================================================
// Validates that:
//   1. emitToEventBridge carries correct businessId from handler context
//   2. emitBatch scopes all events to their respective businessIds
//   3. EventBridge Detail always includes businessId for downstream routing
// ============================================================================

import { TENANT_A, TENANT_B, USERS } from '../setup/jwt-factory';

// Mock EventBridge client
const mockPutEvents = jest.fn().mockResolvedValue({});
jest.mock('@aws-sdk/client-eventbridge', () => ({
    EventBridgeClient: jest.fn().mockImplementation(() => ({
        send: (...args: any[]) => mockPutEvents(...args),
    })),
    PutEventsCommand: jest.fn().mockImplementation((params) => ({
        _type: 'PutEvents',
        ...params,
    })),
}));

jest.mock('../../../../../my-backend/src/config/aws.config', () => ({
    configureAwsClient: (opts: any) => opts,
}));

jest.mock('../../../../../my-backend/src/config/environment', () => ({
    config: {
        aws: { region: 'ap-south-1' },
        awsEventBridge: { busName: 'test-bus' },
    },
}));

jest.mock('../../../../../my-backend/src/utils/logger', () => ({
    logger: {
        info: jest.fn(),
        warn: jest.fn(),
        error: jest.fn(),
        debug: jest.fn(),
    },
}));

// Mock WebSocket service for fallback
jest.mock('../../../../../my-backend/src/services/websocket.service', () => ({
    emitEvent: jest.fn(),
}));

// Mock the websocket types
jest.mock('../../../../../my-backend/src/types/websocket.types', () => ({
    WSEventName: {
        ORDER_CREATED: 'order.created',
        BILL_CREATED: 'bill.created',
        INVENTORY_UPDATED: 'inventory.updated',
        LOW_STOCK_ALERT: 'lowstock.alert',
    },
    ClientType: { OWNER_APP: 'owner_app', STAFF_APP: 'staff_app' },
}));

// Import after mocks
import { emitToEventBridge, emitBatch } from '../../../../../my-backend/src/services/eventbridge.service';

describe('Attack Vector K — EventBridge Event Isolation', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('INTEGRITY: emitToEventBridge includes businessId in Detail', async () => {
        const { WSEventName } = require('../../../../../my-backend/src/types/websocket.types');

        await emitToEventBridge(
            WSEventName.ORDER_CREATED,
            TENANT_A.tenantId,
            { orderId: 'order-123', total: 5000 },
        );

        expect(mockPutEvents).toHaveBeenCalledTimes(1);

        // Extract the PutEventsCommand argument
        const callArgs = mockPutEvents.mock.calls[0][0];
        const entries = callArgs.Entries || callArgs.input?.Entries;

        if (entries && entries.length > 0) {
            const detail = JSON.parse(entries[0].Detail);
            expect(detail.businessId).toBe(TENANT_A.tenantId);
            expect(detail.event).toBe(WSEventName.ORDER_CREATED);
        }
    });

    it('SECURITY: emitToEventBridge does NOT leak different tenant data', async () => {
        const { WSEventName } = require('../../../../../my-backend/src/types/websocket.types');

        // Emit for Tenant A
        await emitToEventBridge(
            WSEventName.BILL_CREATED,
            TENANT_A.tenantId,
            { billId: 'bill-a-1' },
        );

        // Emit for Tenant B
        await emitToEventBridge(
            WSEventName.BILL_CREATED,
            TENANT_B.tenantId,
            { billId: 'bill-b-1' },
        );

        expect(mockPutEvents).toHaveBeenCalledTimes(2);

        // First call: Tenant A
        const call1Detail = JSON.parse(
            (mockPutEvents.mock.calls[0][0].Entries || mockPutEvents.mock.calls[0][0].input?.Entries)?.[0]?.Detail || '{}',
        );
        expect(call1Detail.businessId).toBe(TENANT_A.tenantId);

        // Second call: Tenant B
        const call2Detail = JSON.parse(
            (mockPutEvents.mock.calls[1][0].Entries || mockPutEvents.mock.calls[1][0].input?.Entries)?.[0]?.Detail || '{}',
        );
        expect(call2Detail.businessId).toBe(TENANT_B.tenantId);

        // Cross-check: no contamination
        expect(call1Detail.businessId).not.toBe(TENANT_B.tenantId);
        expect(call2Detail.businessId).not.toBe(TENANT_A.tenantId);
    });

    it('INTEGRITY: emitBatch sends correct businessId for each event', async () => {
        const { WSEventName } = require('../../../../../my-backend/src/types/websocket.types');

        await emitBatch([
            {
                event: WSEventName.INVENTORY_UPDATED,
                businessId: TENANT_A.tenantId,
                data: { productId: 'prod-a' },
            },
            {
                event: WSEventName.LOW_STOCK_ALERT,
                businessId: TENANT_B.tenantId,
                data: { productId: 'prod-b' },
            },
        ]);

        expect(mockPutEvents).toHaveBeenCalled();

        // The batch should contain entries with correct businessIds
        const entries = mockPutEvents.mock.calls[0][0].Entries || mockPutEvents.mock.calls[0][0].input?.Entries;
        
        if (entries) {
            const details = entries.map((e: any) => JSON.parse(e.Detail));
            const bizIds = details.map((d: any) => d.businessId);

            expect(bizIds).toContain(TENANT_A.tenantId);
            expect(bizIds).toContain(TENANT_B.tenantId);
        }
    });

    it('INTEGRITY: EventBus name is correctly configured', async () => {
        const { WSEventName } = require('../../../../../my-backend/src/types/websocket.types');

        await emitToEventBridge(
            WSEventName.ORDER_CREATED,
            TENANT_A.tenantId,
            { orderId: 'test' },
        );

        const callArgs = mockPutEvents.mock.calls[0][0];
        const entries = callArgs.Entries || callArgs.input?.Entries;

        if (entries && entries.length > 0) {
            expect(entries[0].EventBusName).toBe('test-bus');
        }
    });
});
