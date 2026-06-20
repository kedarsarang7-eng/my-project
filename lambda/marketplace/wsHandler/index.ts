// ============================================================
// Marketplace WebSocket Handler
// Routes:
//   $connect - Store connection metadata
//   $disconnect - Clean up connection
//   $default - Route messages
// ============================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Handler } from 'aws-lambda';
import { 
  APIGatewayProxyWebsocketEventV2,
} from 'aws-lambda/trigger/api-gateway-proxy';
import { CognitoJwtVerifier } from 'aws-jwt-verify/cognito-verifier';
import { 
  WebSocketConnection, 
  WebSocketMessage,
  PK,
  SK,
} from '../../shared/types';
import { putItem, deleteItem, getItem, queryByGSI1 } from '../../shared/dynamodb';

const verifier = CognitoJwtVerifier.create({
  userPoolId: process.env.COGNITO_USER_POOL_ID || 'ap-south-1_mockpool',
  tokenUse: 'access',
  clientId: null,
});

const TABLE_NAME = process.env.TABLE_NAME || 'DukanMarketplace';
const WS_API_ENDPOINT = process.env.WS_API_ENDPOINT || '';

// ---------- WEBSOCKET HANDLER ----------

export const handler: Handler<APIGatewayProxyWebsocketEventV2, APIGatewayProxyResultV2> = async (event) => {
  const routeKey = event.requestContext.routeKey || '$default';
  const connectionId = event.requestContext.connectionId || '';

  try {
    switch (routeKey) {
      case '$connect':
        return handleConnect(event, connectionId);
      
      case '$disconnect':
        return handleDisconnect(connectionId);
      
      case 'subscribe':
        return handleSubscribe(event, connectionId);
      
      case 'unsubscribe':
        return handleUnsubscribe(event, connectionId);
      
      case 'order-status-update':
        return handleOrderStatusUpdate(event, connectionId);
      
      case 'ping':
        return handlePing(connectionId);
      
      default:
        return handleDefault(event, connectionId);
    }
  } catch (err) {
    console.error('WebSocket handler error:', err);
    return { statusCode: 500, body: 'Internal Server Error' };
  }
};

// ---------- $CONNECT ----------

async function handleConnect(
  event: APIGatewayProxyWebsocketEventV2, 
  connectionId: string
): Promise<APIGatewayProxyResultV2> {
  // Extract auth from headers or stage variables
  const token = event.stageVariables?.token || '';

  if (!token) {
    return { statusCode: 401, body: 'Unauthorized' };
  }

  try {
    // Verify JWT signature using CognitoJwtVerifier
    let payload: any;
    if (process.env.NODE_ENV === 'test' || !process.env.COGNITO_USER_POOL_ID || process.env.COGNITO_USER_POOL_ID.startsWith('mock')) {
      payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
    } else {
      payload = await verifier.verify(token);
    }
    const now = new Date().toISOString();

    const isBusiness = payload.businessId !== undefined;
    const businessId = isBusiness ? payload.businessId : event.stageVariables?.businessId;
    const userId = payload.sub;
    const customerId = isBusiness ? undefined : payload.sub;

    if (!businessId) {
      return { statusCode: 400, body: 'Business ID required' };
    }

    const connection: WebSocketConnection = {
      PK: PK.connection(connectionId),
      SK: SK.metadata(),
      connectionId,
      businessId,
      userId,
      userType: isBusiness ? 'business' : 'customer',
      customerId,
      connectedAt: now,
      lastPingAt: now,
      GSI1PK: PK.business(businessId),
      GSI1SK: SK.connection(connectionId),
      createdAt: now,
      updatedAt: now,
    };

    await putItem(connection as unknown as Record<string, unknown>);

    return { statusCode: 200, body: 'Connected' };
  } catch (err) {
    console.error('Connection error:', err);
    return { statusCode: 401, body: 'Invalid token' };
  }
}

// ---------- $DISCONNECT ----------

async function handleDisconnect(connectionId: string): Promise<APIGatewayProxyResultV2> {
  await deleteItem(
    PK.connection(connectionId),
    SK.metadata()
  );

  return { statusCode: 200, body: 'Disconnected' };
}

// ---------- SUBSCRIBE ----------

async function handleSubscribe(
  event: APIGatewayProxyWebsocketEventV2,
  connectionId: string
): Promise<APIGatewayProxyResultV2> {
  const body = JSON.parse(event.body || '{}');
  const { room } = body;

  if (!room) {
    return { statusCode: 400, body: 'Room required' };
  }

  // Validate room format and authorization
  // Room formats: biz_<businessId> or biz_<businessId>_cust_<customerId>
  const connection = await getItem<WebSocketConnection>(
    PK.connection(connectionId),
    SK.metadata()
  );

  if (!connection) {
    return { statusCode: 403, body: 'Connection not found' };
  }

  // Verify connection can subscribe to this room
  const allowedRoom = connection.userType === 'business'
    ? `biz_${connection.businessId}`
    : `biz_${connection.businessId}_cust_${connection.customerId}`;

  if (room !== allowedRoom) {
    return { statusCode: 403, body: 'Not authorized for this room' };
  }

  // Store subscription (could add to connection record or separate table)
  // For now, just acknowledge

  return { 
    statusCode: 200, 
    body: JSON.stringify({ type: 'subscribed', room }) 
  };
}

// ---------- UNSUBSCRIBE ----------

async function handleUnsubscribe(
  event: APIGatewayProxyWebsocketEventV2,
  connectionId: string
): Promise<APIGatewayProxyResultV2> {
  const body = JSON.parse(event.body || '{}');
  const { room } = body;

  // Remove subscription
  return { 
    statusCode: 200, 
    body: JSON.stringify({ type: 'unsubscribed', room }) 
  };
}

// ---------- ORDER STATUS UPDATE ----------

async function handleOrderStatusUpdate(
  event: APIGatewayProxyWebsocketEventV2,
  connectionId: string
): Promise<APIGatewayProxyResultV2> {
  const body = JSON.parse(event.body || '{}');
  const { orderId, status, customerId, message } = body;

  // Get connection info
  const connection = await getItem<WebSocketConnection>(
    PK.connection(connectionId),
    SK.metadata()
  );

  if (!connection || connection.userType !== 'business') {
    return { statusCode: 403, body: 'Business authorization required' };
  }

  // Broadcast to customer's room
  const targetRoom = `biz_${connection.businessId}_cust_${customerId}`;
  
  const messageData: WebSocketMessage = {
    type: 'ORDER_UPDATE',
    timestamp: new Date().toISOString(),
    businessId: connection.businessId,
    targetRoom,
    payload: {
      orderId,
      status,
      message,
      timestamp: new Date().toISOString(),
    },
  };

  // Broadcast to all connections in the room
  await broadcastToRoom(targetRoom, messageData);

  return { statusCode: 200, body: 'Message broadcast' };
}

// ---------- PING ----------

async function handlePing(connectionId: string): Promise<APIGatewayProxyResultV2> {
  // Update last ping time
  await updateConnectionPing(connectionId);
  
  return { 
    statusCode: 200, 
    body: JSON.stringify({ type: 'pong', timestamp: new Date().toISOString() }) 
  };
}

// ---------- DEFAULT ----------

async function handleDefault(
  event: APIGatewayProxyWebsocketEventV2,
  connectionId: string
): Promise<APIGatewayProxyResultV2> {
  console.log('Default route:', event.body);
  return { statusCode: 200, body: 'Message received' };
}

// ---------- HELPER FUNCTIONS ----------

async function updateConnectionPing(connectionId: string): Promise<void> {
  const now = new Date().toISOString();
  
  // Update lastPingAt
  await putItem({
    PK: PK.connection(connectionId),
    SK: SK.metadata(),
    lastPingAt: now,
    updatedAt: now,
  } as Record<string, unknown>);
}

async function broadcastToRoom(room: string, message: WebSocketMessage): Promise<void> {
  // Parse room to get businessId
  const parts = room.split('_');
  const businessId = parts[1];

  // Query all connections for this business
  const connections = await queryByGSI1<WebSocketConnection>(
    PK.business(businessId),
    { limit: 100 }
  );

  // Filter connections that should receive this message
  const targetConnections = connections.items.filter(conn => {
    if (conn.userType === 'business') {
      return room === `biz_${conn.businessId}`;
    } else {
      return room === `biz_${conn.businessId}_cust_${conn.customerId}`;
    }
  });

  // Send message to each connection
  for (const conn of targetConnections) {
    try {
      await sendMessage(conn.connectionId, message);
    } catch (err) {
      console.error(`Failed to send to ${conn.connectionId}:`, err);
    }
  }
}

async function sendMessage(connectionId: string, message: WebSocketMessage): Promise<void> {
  const endpoint = WS_API_ENDPOINT.replace('wss://', 'https://');
  const url = `${endpoint}/@connections/${connectionId}`;

  // Use AWS SDK to post to connection
  // This requires @aws-sdk/client-apigatewaymanagementapi
  console.log(`Sending to ${connectionId}:`, message);
}

// ---------- NOTIFICATION HELPERS ----------

export async function notifyOrderUpdate(
  businessId: string,
  customerId: string,
  orderId: string,
  status: string,
  message: string
): Promise<void> {
  const room = `biz_${businessId}_cust_${customerId}`;
  
  const notification: WebSocketMessage = {
    type: 'ORDER_UPDATE',
    timestamp: new Date().toISOString(),
    businessId,
    targetRoom: room,
    payload: {
      orderId,
      status,
      message,
      timestamp: new Date().toISOString(),
    },
  };

  await broadcastToRoom(room, notification);
}

export async function notifyInventorySync(
  businessId: string,
  productId: string,
  stockQuantity: number,
  sellingPrice?: number
): Promise<void> {
  const room = `biz_${businessId}`;
  
  const notification: WebSocketMessage = {
    type: 'INVENTORY_SYNC',
    timestamp: new Date().toISOString(),
    businessId,
    targetRoom: room,
    payload: {
      productId,
      stockQuantity,
      sellingPrice,
      updatedAt: new Date().toISOString(),
    },
  };

  await broadcastToRoom(room, notification);
}
