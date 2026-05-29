// ============================================================================
// WEBSOCKET DISCONNECT HANDLER - $disconnect route
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { deleteItem } from '../utils/dynamodb';
import { TABLES } from '../constants/tables';

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  try {
    const connectionId = event.requestContext.connectionId;
    if (!connectionId) {
      return {
        statusCode: 400,
        body: 'Missing connectionId',
      };
    }

    // Remove connection from DynamoDB
    await deleteItem(TABLES.WEBSOCKET_CONNECTIONS, {
      connectionId,
    });

    console.log(`Connection closed: ${connectionId}`);

    return {
      statusCode: 200,
      body: 'Disconnected',
    };
  } catch (error) {
    console.error('WebSocket disconnect error:', error);
    return {
      statusCode: 500,
      body: 'Internal server error',
    };
  }
};
