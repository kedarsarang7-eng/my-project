/**
 * customerWsHandler/index.mjs
 * API Gateway WebSocket handler for customer app.
 * Manages $connect / $disconnect / $default routes.
 *
 * $connect  — Verifies Cognito JWT from query string, stores connection
 * $disconnect — Removes connection record
 * $default  — Handles ping/pong keepalive
 */

import { CognitoJwtVerifier } from 'aws-jwt-verify';
import {
  DynamoDBClient,
  PutItemCommand,
  DeleteItemCommand,
} from '@aws-sdk/client-dynamodb';
import {
  ApiGatewayManagementApiClient,
  PostToConnectionCommand,
} from '@aws-sdk/client-apigatewaymanagementapi';
import { marshall } from '@aws-sdk/util-dynamodb';

const CONNECTIONS_TABLE = process.env.WS_CONNECTIONS_TABLE;
const USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;
const CLIENT_ID = process.env.COGNITO_MOBILE_CLIENT_ID;
const WS_ENDPOINT = process.env.WS_ENDPOINT;

const ddb = new DynamoDBClient({});

const verifier = CognitoJwtVerifier.create({
  userPoolId: USER_POOL_ID,
  tokenUse: 'access',
  clientId: CLIENT_ID,
});

export const handler = async (event) => {
  const { connectionId, routeKey } = event.requestContext;

  switch (routeKey) {
    case '$connect':
      return handleConnect(event, connectionId);
    case '$disconnect':
      return handleDisconnect(connectionId);
    default:
      return handleMessage(event, connectionId);
  }
};

async function handleConnect(event, connectionId) {
  // Token must be passed as query string: ?token=<access_token>
  const token = event.queryStringParameters?.token;

  if (!token) {
    console.warn(`WS connect rejected: no token. connId=${connectionId}`);
    return { statusCode: 401, body: 'Unauthorized' };
  }

  let payload;
  try {
    payload = await verifier.verify(token);
  } catch (err) {
    console.warn(`WS connect rejected: invalid token. connId=${connectionId}`, err.message);
    return { statusCode: 401, body: 'Unauthorized' };
  }

  const groups = payload['cognito:groups'] || [];
  const isCustomer = groups.includes('customer') || payload['custom:role'] === 'customer';

  if (!isCustomer) {
    return { statusCode: 403, body: 'Forbidden' };
  }

  const now = new Date().toISOString();
  // TTL: 2 hours (WebSocket connections are typically short-lived)
  const ttl = Math.floor(Date.now() / 1000) + 2 * 60 * 60;

  await ddb.send(new PutItemCommand({
    TableName: CONNECTIONS_TABLE,
    Item: marshall({
      connectionId,
      customerId: payload.sub,
      connectedAt: now,
      ttl,
      // GSI key for querying by customer
      GSI_Customer_PK: payload.sub,
    }),
  }));

  console.log(`WS connected: customerId=${payload.sub} connId=${connectionId}`);
  return { statusCode: 200, body: 'Connected' };
}

async function handleDisconnect(connectionId) {
  try {
    await ddb.send(new DeleteItemCommand({
      TableName: CONNECTIONS_TABLE,
      Key: marshall({ connectionId }),
    }));
    console.log(`WS disconnected: connId=${connectionId}`);
  } catch (err) {
    console.warn('Failed to remove connection:', err.message);
  }
  return { statusCode: 200, body: 'Disconnected' };
}

async function handleMessage(event, connectionId) {
  const body = JSON.parse(event.body || '{}');

  // Keepalive ping
  if (body.action === 'ping') {
    const apigw = new ApiGatewayManagementApiClient({ endpoint: WS_ENDPOINT });
    try {
      await apigw.send(new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: Buffer.from(JSON.stringify({ action: 'pong', ts: Date.now() })),
      }));
    } catch (err) {
      console.warn('Failed to send pong:', err.message);
    }
  }

  return { statusCode: 200, body: 'OK' };
}
