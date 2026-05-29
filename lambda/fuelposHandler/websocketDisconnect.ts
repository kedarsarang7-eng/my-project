import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, DeleteCommand } from '@aws-sdk/lib-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

/**
 * WebSocket $disconnect handler
 * Cleans up connection record on disconnect
 */
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const connectionId = event.requestContext?.connectionId;

    if (!connectionId) {
      return {
        statusCode: 500,
        body: JSON.stringify({ error: 'Missing connection ID' }),
      };
    }

    // Remove connection record
    const tableName = process.env.DYNAMODB_TABLE_WEBSOCKET_CONNECTIONS || 'WebSocketConnections';

    await docClient.send(
      new DeleteCommand({
        TableName: tableName,
        Key: { connectionId },
      })
    );

    console.log(`WebSocket connection closed: ${connectionId}`);

    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Disconnected' }),
    };
  } catch (error) {
    console.error('WebSocket disconnect error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};
