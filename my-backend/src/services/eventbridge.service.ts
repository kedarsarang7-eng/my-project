// ============================================================================
// EventBridge Service � Event Bus Integration (Phase 2)
// ============================================================================
// Provides a simple interface for REST handlers to emit events to
// EventBridge instead of directly calling wsService.broadcastToBusiness().
//
// Benefits:
//   - Decouples REST handlers from broadcast logic
//   - Enables event replay, filtering, and audit logging
//   - Broadcaster Lambda handles fan-out asynchronously
//   - REST responses return faster (no broadcast latency)
//
// Usage in handlers:
//   import { emitToEventBridge } from '../services/eventbridge.service';
//   await emitToEventBridge('dukanx.orders', WSEventName.ORDER_CREATED, {
//       businessId: auth.tenantId,
//       data: { orderId: result.id },
//       targetAudience: 'business',
//   });
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import {
    EventBridgeClient,
    PutEventsCommand,
} from '@aws-sdk/client-eventbridge';
import { logger } from '../utils/logger';
import {
    WSEventName,
    WSEventBridgeDetail,
    ClientType,
} from '../types/websocket.types';
import { config } from '../config/environment';

// -- Configuration -----------------------------------------------------------

const REGION = config.aws.region;
const EVENT_BUS_NAME = config.awsEventBridge.busName || 'default';

// -- Client (lazy-initialized) -----------------------------------------------

let ebClient: EventBridgeClient | null = null;

function getClient(): EventBridgeClient {
    if (!ebClient) {
        ebClient = new EventBridgeClient(configureAwsClient({ region: REGION }));
    }
    return ebClient;
}

// -- EventBridge Source Constants ---------------------------------------------

export const EB_SOURCES = {
    ORDERS: 'dukanx.orders',
    BILLING: 'dukanx.billing',
    INVENTORY: 'dukanx.inventory',
    STAFF: 'dukanx.staff',
    PAYMENTS: 'dukanx.payments',
    SYSTEM: 'dukanx.system',
    CLINIC: 'dukanx.clinic',
    PUMP: 'dukanx.pump',
    SERVICE: 'dukanx.service',
} as const;

// Map event names to EventBridge sources for auto-routing
const EVENT_SOURCE_MAP: Partial<Record<WSEventName, string>> = {
    [WSEventName.ORDER_CREATED]: EB_SOURCES.ORDERS,
    [WSEventName.ORDER_UPDATED]: EB_SOURCES.ORDERS,
    [WSEventName.ORDER_COMPLETED]: EB_SOURCES.ORDERS,
    [WSEventName.KOT_CREATED]: EB_SOURCES.ORDERS,
    [WSEventName.KOT_STATUS_UPDATED]: EB_SOURCES.ORDERS,
    [WSEventName.KOT_ITEM_CANCELLED]: EB_SOURCES.ORDERS,
    [WSEventName.CHECKOUT_REQUESTED]: EB_SOURCES.ORDERS,
    [WSEventName.PAYMENT_SUCCESS]: EB_SOURCES.PAYMENTS,
    [WSEventName.PAYMENT_FAILED]: EB_SOURCES.PAYMENTS,
    [WSEventName.BILL_CREATED]: EB_SOURCES.BILLING,
    [WSEventName.BILL_UPDATED]: EB_SOURCES.BILLING,
    [WSEventName.INVENTORY_UPDATED]: EB_SOURCES.INVENTORY,
    [WSEventName.LOW_STOCK_ALERT]: EB_SOURCES.INVENTORY,
    [WSEventName.LOW_STOCK_RESOLVED]: EB_SOURCES.INVENTORY,
    [WSEventName.EXPIRY_ALERT]: EB_SOURCES.INVENTORY,
    [WSEventName.STAFF_ACTIVITY]: EB_SOURCES.STAFF,
    [WSEventName.STAFF_SALE_CREATED]: EB_SOURCES.STAFF,
    [WSEventName.STAFF_LOGIN]: EB_SOURCES.STAFF,
    [WSEventName.STAFF_LOGOUT]: EB_SOURCES.STAFF,
    [WSEventName.STAFF_ASSIGNED]: EB_SOURCES.STAFF,
    [WSEventName.PETROL_SALE_UPDATE]: EB_SOURCES.PUMP,
    [WSEventName.DIESEL_SALE_UPDATE]: EB_SOURCES.PUMP,
    [WSEventName.SHIFT_OPENED]: EB_SOURCES.PUMP,
    [WSEventName.SHIFT_CLOSED]: EB_SOURCES.PUMP,
    [WSEventName.VEHICLE_LINKED]: EB_SOURCES.PUMP,
    [WSEventName.APPOINTMENT_CREATED]: EB_SOURCES.CLINIC,
    [WSEventName.QUEUE_UPDATED]: EB_SOURCES.CLINIC,
    [WSEventName.PRESCRIPTION_CREATED]: EB_SOURCES.CLINIC,
    [WSEventName.SERVICE_JOB_CREATED]: EB_SOURCES.SERVICE,
    [WSEventName.SERVICE_STATUS_UPDATED]: EB_SOURCES.SERVICE,
    [WSEventName.PRICE_UPDATED]: EB_SOURCES.INVENTORY,
    [WSEventName.DASHBOARD_UPDATED]: EB_SOURCES.SYSTEM,
    [WSEventName.ADMIN_ACTION]: EB_SOURCES.SYSTEM,
    [WSEventName.NOTIFICATION]: EB_SOURCES.SYSTEM,
    [WSEventName.SYNC_COMPLETED]: EB_SOURCES.SYSTEM,
    [WSEventName.DEVICE_SYNC]: EB_SOURCES.SYSTEM,
    [WSEventName.CONNECTION_STATUS]: EB_SOURCES.SYSTEM,
};

// Map event names to default target audiences
const EVENT_AUDIENCE_MAP: Partial<Record<WSEventName, WSEventBridgeDetail['targetAudience']>> = {
    [WSEventName.ORDER_CREATED]: 'business',
    [WSEventName.ORDER_UPDATED]: 'business',
    [WSEventName.ORDER_COMPLETED]: 'business',
    [WSEventName.KOT_CREATED]: 'client_type',
    [WSEventName.KOT_STATUS_UPDATED]: 'client_type',
    [WSEventName.KOT_ITEM_CANCELLED]: 'client_type',
    [WSEventName.CHECKOUT_REQUESTED]: 'staff',
    [WSEventName.PAYMENT_SUCCESS]: 'business',
    [WSEventName.PAYMENT_FAILED]: 'business',
    [WSEventName.BILL_CREATED]: 'business',
    [WSEventName.BILL_UPDATED]: 'business',
    [WSEventName.INVENTORY_UPDATED]: 'business',
    [WSEventName.LOW_STOCK_ALERT]: 'business',
    [WSEventName.LOW_STOCK_RESOLVED]: 'business',
    [WSEventName.EXPIRY_ALERT]: 'business',
    [WSEventName.STAFF_ACTIVITY]: 'owner',
    [WSEventName.STAFF_SALE_CREATED]: 'business',
    [WSEventName.STAFF_LOGIN]: 'owner',
    [WSEventName.STAFF_LOGOUT]: 'owner',
    [WSEventName.STAFF_ASSIGNED]: 'owner',
    [WSEventName.PETROL_SALE_UPDATE]: 'business',
    [WSEventName.DIESEL_SALE_UPDATE]: 'business',
    [WSEventName.SHIFT_OPENED]: 'business',
    [WSEventName.SHIFT_CLOSED]: 'business',
    [WSEventName.VEHICLE_LINKED]: 'owner',
    [WSEventName.APPOINTMENT_CREATED]: 'business',
    [WSEventName.QUEUE_UPDATED]: 'business',
    [WSEventName.PRESCRIPTION_CREATED]: 'business',
    [WSEventName.SERVICE_JOB_CREATED]: 'business',
    [WSEventName.SERVICE_STATUS_UPDATED]: 'business',
    [WSEventName.PRICE_UPDATED]: 'business',
    [WSEventName.DASHBOARD_UPDATED]: 'business',
    [WSEventName.ADMIN_ACTION]: 'business',
    [WSEventName.NOTIFICATION]: 'business',
    [WSEventName.SYNC_COMPLETED]: 'business',
    [WSEventName.DEVICE_SYNC]: 'business',
    [WSEventName.CONNECTION_STATUS]: 'business',
};

// ============================================================================
// PUBLIC API
// ============================================================================

/**
 * Emit an event to EventBridge for asynchronous WebSocket fan-out.
 *
 * This replaces direct wsService calls in REST handlers for decoupled broadcasting.
 * The Broadcaster Lambda (ws-broadcaster.ts) picks up these events and handles delivery.
 *
 * @param event - The event name (e.g., WSEventName.ORDER_CREATED)
 * @param businessId - The tenant/business ID
 * @param data - Event payload data
 * @param options - Optional targeting overrides
 */
export async function emitToEventBridge(
    event: WSEventName,
    businessId: string,
    data: Record<string, unknown>,
    options?: {
        targetAudience?: WSEventBridgeDetail['targetAudience'];
        targetClientType?: ClientType;
        targetUserId?: string;
        source?: string;
    },
): Promise<void> {
    const source = options?.source || EVENT_SOURCE_MAP[event] || EB_SOURCES.SYSTEM;
    const targetAudience = options?.targetAudience || EVENT_AUDIENCE_MAP[event] || 'business';

    const detail: WSEventBridgeDetail = {
        businessId,
        event,
        data,
        targetAudience,
        targetClientType: options?.targetClientType,
        targetUserId: options?.targetUserId,
    };

    try {
        const client = getClient();
        await client.send(new PutEventsCommand({
            Entries: [{
                Source: source,
                DetailType: 'WSBroadcast',
                Detail: JSON.stringify(detail),
                EventBusName: EVENT_BUS_NAME,
            }],
        }));

        logger.info('[EventBridge] Event emitted', {
            source,
            event,
            businessId,
            targetAudience,
        });
    } catch (error) {
        logger.error('[EventBridge] Failed to emit event � falling back to direct broadcast', {
            event,
            businessId,
            error: (error as Error).message,
        });

        // Fallback: if EventBridge fails, broadcast directly
        // This ensures real-time delivery isn't lost due to EventBridge issues
        try {
            const wsService = await import('../services/websocket.service');
            await wsService.emitEvent(businessId, event, data, {
                customerId: options?.targetUserId,
            });
        } catch (fallbackError) {
            logger.error('[EventBridge] Fallback broadcast also failed', {
                event,
                businessId,
                error: (fallbackError as Error).message,
            });
        }
    }
}

/**
 * Emit multiple events in a single batch (up to 10 per EventBridge PutEvents call).
 * Useful for bulk operations (e.g., stock import that updates many items).
 */
export async function emitBatch(
    events: Array<{
        event: WSEventName;
        businessId: string;
        data: Record<string, unknown>;
    }>,
): Promise<void> {
    // EventBridge allows max 10 entries per PutEvents call
    const batches = [];
    for (let i = 0; i < events.length; i += 10) {
        batches.push(events.slice(i, i + 10));
    }

    const client = getClient();

    for (const batch of batches) {
        try {
            await client.send(new PutEventsCommand({
                Entries: batch.map(e => ({
                    Source: EVENT_SOURCE_MAP[e.event] || EB_SOURCES.SYSTEM,
                    DetailType: 'WSBroadcast',
                    Detail: JSON.stringify({
                        businessId: e.businessId,
                        event: e.event,
                        data: e.data,
                        targetAudience: EVENT_AUDIENCE_MAP[e.event] || 'business',
                    } as WSEventBridgeDetail),
                    EventBusName: EVENT_BUS_NAME,
                })),
            }));
        } catch (error) {
            logger.error('[EventBridge] Batch emit failed', {
                batchSize: batch.length,
                error: (error as Error).message,
            });
        }
    }

    logger.info('[EventBridge] Batch emitted', {
        totalEvents: events.length,
        batches: batches.length,
    });
}
