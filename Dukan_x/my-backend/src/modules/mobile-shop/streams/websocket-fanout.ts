/**
 * MobileShop WebSocket Fan-out — Pull Hint Publisher
 *
 * Receives domain change events and publishes MINIMAL pull hints
 * to connected WebSocket clients for the affected tenant.
 *
 * Key rules:
 * - WebSocket hints contain NO authoritative payload
 * - Only: { eventId, entityType, entityId, version, action }
 * - Pull remains the authoritative synchronization mechanism
 * - Stale connections (expired TTL or failed post) are removed
 * - Tenant binding is revalidated on every notification
 * - Connection posting errors are handled gracefully
 *
 * Requirements: 7.4, 7.10–7.15, 8.4
 */

import type {
  StreamRecord,
  PullHint,
  WebSocketConnection,
  WebSocketSendResult,
} from './stream-types';

// ─── Configuration ───────────────────────────────────────────────────────────

const CONNECTIONS_TABLE =
  process.env.CONNECTIONS_TABLE ?? 'MobileShopConnections';
const CONNECTIONS_GSI = process.env.CONNECTIONS_GSI ?? 'TenantIndex';
const WEBSOCKET_ENDPOINT = process.env.WEBSOCKET_ENDPOINT ?? '';

// ─── Lazy SDK Client Factories ───────────────────────────────────────────────
// AWS SDK v3 clients are loaded lazily for Lambda cold-start optimization.
// In the Lambda runtime, SDK packages are bundled or provided by the layer.

let dynamoClient: any;
let apiGwClient: any;

async function getDynamoClient(): Promise<any> {
  if (!dynamoClient) {
    const { DynamoDBClient } = await import('@aws-sdk/client-dynamodb');
    dynamoClient = new DynamoDBClient({});
  }
  return dynamoClient;
}

async function getApiGwClient(): Promise<any> {
  if (!apiGwClient) {
    const { ApiGatewayManagementApiClient } = await import(
      '@aws-sdk/client-apigatewaymanagementapi'
    );
    apiGwClient = new ApiGatewayManagementApiClient({
      endpoint: WEBSOCKET_ENDPOINT,
    });
  }
  return apiGwClient;
}

// ─── Public API ──────────────────────────────────────────────────────────────

/**
 * Fans out a minimal pull hint to all WebSocket connections for a tenant.
 *
 * Steps:
 * 1. Look up active connections for the tenant (GSI query)
 * 2. Filter expired connections (TTL check)
 * 3. Revalidate tenant binding
 * 4. Send minimal pull hint (NO authoritative payload)
 * 5. Remove stale/failed connections
 */
export async function fanoutPullHints(record: StreamRecord): Promise<void> {
  // Skip if WebSocket endpoint is not configured
  if (!WEBSOCKET_ENDPOINT) {
    return;
  }

  // Look up all connections for this tenant
  const connections = await queryTenantConnections(record.tenantId);
  if (connections.length === 0) return;

  // Build the minimal pull hint — NO authoritative payload
  const hint: PullHint = {
    eventId: record.eventId,
    entityType: record.entityType,
    entityId: record.entityId,
    version: record.version,
    action: record.action,
  };

  const payload = JSON.stringify(hint);

  // Fan out to all valid connections
  const results = await Promise.allSettled(
    connections.map((conn) => sendToConnection(conn, payload, record.tenantId)),
  );

  // Log summary for observability
  const sent = results.filter(
    (r) => r.status === 'fulfilled' && r.value.success,
  ).length;
  const removed = results.filter(
    (r) => r.status === 'fulfilled' && r.value.removed,
  ).length;

  if (removed > 0 || sent > 0) {
    console.log(
      JSON.stringify({
        eventType: 'WEBSOCKET_FANOUT',
        timestamp: new Date().toISOString(),
        tenantId: record.tenantId,
        entityType: record.entityType,
        connectionsQueried: connections.length,
        hintsSent: sent,
        connectionsRemoved: removed,
      }),
    );
  }
}

// ─── Connection Lookup ───────────────────────────────────────────────────────

/**
 * Queries the ConnectionsTable GSI for all connections belonging to a tenant.
 */
async function queryTenantConnections(
  tenantId: string,
): Promise<WebSocketConnection[]> {
  try {
    const { QueryCommand } = await import('@aws-sdk/client-dynamodb');
    const client = await getDynamoClient();

    const result = await client.send(
      new QueryCommand({
        TableName: CONNECTIONS_TABLE,
        IndexName: CONNECTIONS_GSI,
        KeyConditionExpression: 'tenantId = :tid',
        ExpressionAttributeValues: {
          ':tid': { S: tenantId },
        },
      }),
    );

    if (!result.Items || result.Items.length === 0) return [];

    const { unmarshall } = await import('@aws-sdk/util-dynamodb');

    return result.Items.map((item: Record<string, any>) => {
      const unmarshalled = unmarshall(item);
      return {
        connectionId: unmarshalled.connectionId as string,
        tenantId: unmarshalled.tenantId as string,
        subjectId: unmarshalled.subjectId as string,
        connectedAt: unmarshalled.connectedAt as string,
        ttl: unmarshalled.ttl as number,
      };
    });
  } catch (error) {
    const errorMessage =
      error instanceof Error ? error.message : 'Unknown error';
    console.log(
      JSON.stringify({
        eventType: 'WEBSOCKET_CONNECTION_QUERY_FAILURE',
        timestamp: new Date().toISOString(),
        tenantId,
        error: errorMessage,
      }),
    );
    return [];
  }
}

// ─── Connection Send ─────────────────────────────────────────────────────────

/**
 * Sends a pull hint to a single WebSocket connection.
 *
 * Handles:
 * - Expired TTL → remove connection
 * - Tenant binding mismatch → remove connection
 * - GoneException (HTTP 410) → remove connection
 * - Other posting errors → log and continue
 */
async function sendToConnection(
  connection: WebSocketConnection,
  payload: string,
  expectedTenantId: string,
): Promise<WebSocketSendResult> {
  const { connectionId } = connection;

  // Revalidate tenant binding — must match the event's tenant
  if (connection.tenantId !== expectedTenantId) {
    await removeConnection(connectionId);
    return { connectionId, success: false, removed: true, error: 'tenant_mismatch' };
  }

  // Check TTL expiry — remove stale connections
  const nowEpochSeconds = Math.floor(Date.now() / 1000);
  if (connection.ttl > 0 && connection.ttl < nowEpochSeconds) {
    await removeConnection(connectionId);
    return { connectionId, success: false, removed: true, error: 'expired' };
  }

  try {
    const { PostToConnectionCommand } = await import(
      '@aws-sdk/client-apigatewaymanagementapi'
    );
    const client = await getApiGwClient();

    await client.send(
      new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: Buffer.from(payload, 'utf-8'),
      }),
    );
    return { connectionId, success: true, removed: false };
  } catch (error) {
    // GoneException (HTTP 410) means the connection is stale — remove it
    if (isGoneError(error)) {
      await removeConnection(connectionId);
      return { connectionId, success: false, removed: true, error: 'gone' };
    }

    // Other errors — log but don't remove (could be transient)
    const errorMessage =
      error instanceof Error ? error.message : 'Unknown post error';
    console.log(
      JSON.stringify({
        eventType: 'WEBSOCKET_POST_FAILURE',
        timestamp: new Date().toISOString(),
        connectionId,
        tenantId: expectedTenantId,
        error: errorMessage,
      }),
    );
    return { connectionId, success: false, removed: false, error: errorMessage };
  }
}

// ─── Connection Removal ──────────────────────────────────────────────────────

/**
 * Removes a stale or invalid WebSocket connection from the connections table.
 * Also attempts to disconnect via API Gateway (best-effort).
 */
async function removeConnection(connectionId: string): Promise<void> {
  // Best-effort disconnect via API Gateway
  try {
    const { DeleteConnectionCommand } = await import(
      '@aws-sdk/client-apigatewaymanagementapi'
    );
    const client = await getApiGwClient();
    await client.send(new DeleteConnectionCommand({ ConnectionId: connectionId }));
  } catch {
    // Ignore — connection may already be gone
  }

  // Remove from connections table
  try {
    const { DeleteItemCommand } = await import('@aws-sdk/client-dynamodb');
    const client = await getDynamoClient();
    await client.send(
      new DeleteItemCommand({
        TableName: CONNECTIONS_TABLE,
        Key: {
          connectionId: { S: connectionId },
        },
      }),
    );
  } catch (error) {
    const errorMessage =
      error instanceof Error ? error.message : 'Unknown delete error';
    console.log(
      JSON.stringify({
        eventType: 'WEBSOCKET_CONNECTION_REMOVE_FAILURE',
        timestamp: new Date().toISOString(),
        connectionId,
        error: errorMessage,
      }),
    );
  }
}

// ─── Utilities ───────────────────────────────────────────────────────────────

/**
 * Checks if an error is a GoneException (HTTP 410) indicating
 * the WebSocket connection no longer exists.
 */
function isGoneError(error: unknown): boolean {
  if (error && typeof error === 'object') {
    const err = error as any;
    // AWS SDK v3 GoneException check
    if (err.name === 'GoneException') return true;
    // Fallback: check HTTP status code
    const statusCode = err.statusCode ?? err.$metadata?.httpStatusCode;
    return statusCode === 410;
  }
  return false;
}
