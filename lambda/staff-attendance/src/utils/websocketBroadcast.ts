// ============================================================================
// p28(b) WebSocket broadcast helper for staff-attendance handlers
// ============================================================================
//
// Queries PetrolWebSocketConnections for all active connections on a given
// stationId, then fans out a JSON message to each via API Gateway Management
// API (postToConnection).
//
// Stale connections (gone endpoints) are silently deleted from DynamoDB so the
// table stays clean without manual TTL-only cleanup.
//
// Usage:
//   await broadcastToStation(stationId, wsEndpoint, {
//     type: 'STAFF_CHECKED_IN',
//     payload: { shiftId, staffId, staffName, checkInTime },
//   });
// ============================================================================

import {
  ApiGatewayManagementApiClient,
  PostToConnectionCommand,
  GoneException,
} from '@aws-sdk/client-apigatewaymanagementapi';
import { queryItems, deleteItem } from './dynamodb';
import { TABLES } from '../constants/tables';

interface BroadcastPayload {
  type: string;
  payload: Record<string, unknown>;
  timestamp?: string;
}

interface ConnectionRecord {
  connectionId: string;
  stationId: string;
  role: string;
  userId: string;
  staffId?: string;
}

/**
 * Fan-out a JSON event to every WebSocket connection registered for
 * [stationId].  Stale (410 Gone) connections are pruned automatically.
 *
 * @param stationId   - DynamoDB GSI1PK value: STATION#{stationId}
 * @param wsEndpoint  - Full HTTPS endpoint for postToConnection calls,
 *                      e.g. https://{apiId}.execute-api.{region}.amazonaws.com/{stage}
 * @param message     - Event payload; `timestamp` defaults to now if omitted
 */
export async function broadcastToStation(
  stationId: string,
  wsEndpoint: string,
  message: BroadcastPayload,
): Promise<void> {
  const enriched = {
    ...message,
    timestamp: message.timestamp ?? new Date().toISOString(),
  };
  const data = Buffer.from(JSON.stringify(enriched));

  // Query connections by station GSI
  const { items } = await queryItems<ConnectionRecord>(TABLES.WEBSOCKET_CONNECTIONS, {
    keyConditionExpression: 'GSI1PK = :station',
    expressionAttributeValues: { ':station': `STATION#${stationId}` },
    indexName: 'GSI1',
  });

  if (items.length === 0) return;

  const client = new ApiGatewayManagementApiClient({ endpoint: wsEndpoint });

  await Promise.allSettled(
    items.map(async (conn) => {
      try {
        await client.send(
          new PostToConnectionCommand({
            ConnectionId: conn.connectionId,
            Data: data,
          }),
        );
      } catch (err) {
        if (err instanceof GoneException) {
          // Client disconnected without sending $disconnect — prune stale record
          await deleteItem(TABLES.WEBSOCKET_CONNECTIONS, {
            connectionId: conn.connectionId,
          }).catch(() => {/* best-effort */});
        } else {
          console.error(`WS broadcast failed for ${conn.connectionId}:`, err);
        }
      }
    }),
  );
}

/** Read the WS callback endpoint from the environment (injected by SAM/CDK). */
export function getWsEndpoint(): string {
  return process.env.WS_CALLBACK_ENDPOINT ?? '';
}
