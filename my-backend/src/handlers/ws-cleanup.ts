// ============================================================================
// Lambda Handler — WebSocket Connection Cleanup (EventBridge Scheduled)
// ============================================================================
// Triggered by: EventBridge scheduled rule (rate: 6 hours)
//
// Periodically cleans up stale WebSocket connections that haven't sent
// heartbeats in STALE_CONNECTION_AGE_HOURS.
//
// Benefits:
//   - Prevents memory leaks from accumulating stale connections
//   - Complements DynamoDB TTL cleanup (24 hours)
//   - Helps detect and remove dead connections faster
// ============================================================================

import { EventBridgeEvent } from 'aws-lambda';
import { cleanupStaleConnections } from '../utils/websocket-cleanup';
import { logger } from '../utils/logger';

/**
 * Scheduled handler — invoked every 6 hours by EventBridge rule
 */
export async function cleanupWebSocketConnections(
    event: EventBridgeEvent<'Scheduled Event', Record<string, unknown>>,
): Promise<{ statusCode: number; body: string }> {
    logger.info('[WebSocketCleanupHandler] Cleanup triggered');

    try {
        const result = await cleanupStaleConnections();

        logger.info('[WebSocketCleanupHandler] Cleanup completed successfully', result);

        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'WebSocket connection cleanup completed',
                ...result,
            }),
        };
    } catch (error) {
        logger.error('[WebSocketCleanupHandler] Cleanup failed', {
            error: (error as Error).message,
            stack: (error as Error).stack,
        });

        return {
            statusCode: 500,
            body: JSON.stringify({
                message: 'WebSocket connection cleanup failed',
                error: (error as Error).message,
            }),
        };
    }
}
