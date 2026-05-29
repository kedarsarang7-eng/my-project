// ============================================================================
// WEBSOCKET DEFAULT HANDLER - $default route
// ============================================================================
//
// Handles all non-connect/non-disconnect WebSocket frames.
// Currently only handles ping→pong keepalives.  All other message types are
// logged and dropped (one-way server-push architecture).
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  ApiGatewayManagementApiClient,
  PostToConnectionCommand,
} from '@aws-sdk/client-apigatewaymanagementapi';
import { updateItem } from '../utils/dynamodb';
import { TABLES } from '../constants/tables';

export const handler = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  const connectionId = event.requestContext.connectionId;
  if (!connectionId) {
    return { statusCode: 400, body: 'Missing connectionId' };
  }

  try {
    const body = event.body ? JSON.parse(event.body) : {};
    const type = body?.type ?? 'unknown';

    // Update lastPingAt so TTL-based cleanup is accurate
    await updateItem(
      TABLES.WEBSOCKET_CONNECTIONS,
      { connectionId },
      { lastPingAt: new Date().toISOString() },
    );

    if (type === 'ping') {
      // Build callback URL from requestContext
      const domain = event.requestContext.domainName;
      const stage = event.requestContext.stage;
      const endpoint = `https://${domain}/${stage}`;

      const client = new ApiGatewayManagementApiClient({ endpoint });
      await client.send(
        new PostToConnectionCommand({
          ConnectionId: connectionId,
          Data: Buffer.from(JSON.stringify({ type: 'pong', timestamp: new Date().toISOString() })),
        }),
      );
    } else {
      console.log(`WS $default: unhandled type="${type}" conn=${connectionId}`);
    }

    return { statusCode: 200, body: 'OK' };
  } catch (error) {
    console.error('WebSocket default error:', error);
    return { statusCode: 500, body: 'Internal server error' };
  }
};
