import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { CognitoJwtVerifier } from 'aws-jwt-verify/cognito-verifier';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

// JWT Verifier for WebSocket auth
const verifier = CognitoJwtVerifier.create({
  userPoolId: process.env.COGNITO_USER_POOL_ID!,
  tokenUse: 'access',
  clientId: process.env.COGNITO_CLIENT_ID!,
});

/**
 * WebSocket $connect handler
 * CRITICAL: Verifies JWT before allowing connection
 */
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const connectionId = event.requestContext?.connectionId;
    const queryParams = event.queryStringParameters || {};
    const token = queryParams.token;

    if (!connectionId) {
      return {
        statusCode: 500,
        body: JSON.stringify({ error: 'Missing connection ID' }),
      };
    }

    if (!token) {
      console.warn(`Connection ${connectionId} rejected: No token provided`);
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized - Token required' }),
      };
    }

    // Verify JWT
    let decoded;
    try {
      decoded = await verifier.verify(token);
    } catch (err) {
      console.warn(`Connection ${connectionId} rejected: Invalid token`);
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized - Invalid token' }),
      };
    }

    const userId = decoded.sub;
    const tenantId = decoded['custom:tenantId'] || '';
    const role = decoded['custom:role'] || 'staff';

    if (!userId || !tenantId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized - Missing claims' }),
      };
    }

    // Store connection mapping with TTL
    const tableName = process.env.DYNAMODB_TABLE_WEBSOCKET_CONNECTIONS || 'WebSocketConnections';
    const ttl = Math.floor(Date.now() / 1000) + (2 * 60 * 60); // 2 hours

    await docClient.send(
      new PutCommand({
        TableName: tableName,
        Item: {
          connectionId,
          staffId: userId,
          tenantId,
          role,
          connectedAt: new Date().toISOString(),
          ttl,
        },
      })
    );

    console.log(`WebSocket connection established: ${connectionId} for user ${userId}`);

    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Connected' }),
    };
  } catch (error) {
    console.error('WebSocket connect error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};
