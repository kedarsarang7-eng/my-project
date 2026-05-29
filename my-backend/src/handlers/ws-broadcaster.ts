// ============================================================================
// Broadcaster Lambda — EventBridge → WebSocket Fan-Out
// ============================================================================
// This Lambda is triggered by EventBridge rules whenever a REST handler
// emits a business event. It handles the fan-out to all relevant
// WebSocket connections.
//
// Architecture:
//   EventBridge Rule → This Lambda → DynamoDB Query → PostToConnection
//
// Phase 2: EventBridge integration
// Phase 3: Redis caching layer (optional, degrades to DynamoDB)
// Phase 4: Offline message queuing
// ============================================================================

import { EventBridgeEvent } from 'aws-lambda';
import { logger } from '../utils/logger';
import * as wsService from '../services/websocket.service';
import * as presenceService from '../services/presence.service';
import {
    WSEventBridgeDetail,
    WSEventName,
    ClientType,
} from '../types/websocket.types';

/**
 * EventBridge handler — invoked by rules matching `dukanx.*` sources.
 *
 * Each event carries a `WSEventBridgeDetail` with:
 *   - businessId, event name, data payload
 *   - targetAudience (business | staff | customer | owner | client_type)
 *   - optional targetClientType / targetUserId for narrowing
 */
export async function wsBroadcaster(
    event: EventBridgeEvent<'WSBroadcast', WSEventBridgeDetail>,
): Promise<void> {
    const detail = event.detail;

    logger.info('[Broadcaster] Event received', {
        source: event.source,
        detailType: event['detail-type'],
        businessId: detail.businessId,
        eventName: detail.event,
        targetAudience: detail.targetAudience,
    });

    try {
        switch (detail.targetAudience) {
            case 'business':
                await wsService.broadcastToBusiness(
                    detail.businessId,
                    detail.event,
                    detail.data,
                );
                break;

            case 'staff':
                await wsService.broadcastToStaff(
                    detail.businessId,
                    detail.event,
                    detail.data,
                );
                break;

            case 'customer':
                if (detail.targetUserId) {
                    await wsService.broadcastToCustomer(
                        detail.businessId,
                        detail.targetUserId,
                        detail.event,
                        detail.data,
                    );
                } else {
                    logger.warn('[Broadcaster] Customer target missing userId', {
                        businessId: detail.businessId,
                        event: detail.event,
                    });
                }
                break;

            case 'owner':
                await wsService.broadcastToOwner(
                    detail.businessId,
                    detail.event,
                    detail.data,
                );
                break;

            case 'client_type':
                if (detail.targetClientType) {
                    await wsService.broadcastToClientType(
                        detail.businessId,
                        detail.targetClientType,
                        detail.event,
                        detail.data,
                    );
                }
                break;

            default:
                // Fallback to business-wide broadcast
                await wsService.broadcastToBusiness(
                    detail.businessId,
                    detail.event,
                    detail.data,
                );
        }

        logger.info('[Broadcaster] Event processed successfully', {
            businessId: detail.businessId,
            event: detail.event,
        });
    } catch (error) {
        logger.error('[Broadcaster] Failed to process event', {
            businessId: detail.businessId,
            event: detail.event,
            error: (error as Error).message,
        });
        // Don't throw — EventBridge will retry on failure (with DLQ if configured)
    }
}
