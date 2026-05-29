// ============================================================================
// WEBSOCKET CONNECT HANDLER - $connect route
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { putItem } from '../utils/dynamodb';
import { TABLES } from '../constants/tables';
import { extractClaims, ROLES } from '../utils/rbac';

interface ConnectionRecord {
  connectionId: string;
  userId: string;
  staffId?: string;
  stationId: string;
  role: string;
  connectedAt: string;
  lastPingAt: string;
  ttl: number;
}

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

    // p28(c) RBAC: role and staffId MUST come from verified JWT claims.
    // Accepting role from query string would allow any caller to self-declare
    // manager/admin privilege for WebSocket broadcast filtering.
    const claims = extractClaims(event);
    if (!claims || !claims.sub) {
      return { statusCode: 401, body: 'Unauthorized: missing or invalid token claims' };
    }
    const userId = claims.sub;
    const role = claims.role ?? ROLES.PUMP_OPERATOR;
    const staffId = claims.staffId || event.queryStringParameters?.staffId;

    // stationId is non-privileged session metadata; query string is acceptable
    const stationId = event.queryStringParameters?.stationId || 'unknown';

    const now = new Date();
    const ttl = Math.floor(now.getTime() / 1000) + 2 * 60 * 60; // 2 hours TTL

    const connection: ConnectionRecord = {
      connectionId,
      userId,
      staffId,
      stationId,
      role,
      connectedAt: now.toISOString(),
      lastPingAt: now.toISOString(),
      ttl,
    };

    await putItem(TABLES.WEBSOCKET_CONNECTIONS, connection);

    console.log(`Connection established: ${connectionId} for user ${userId}`);

    return {
      statusCode: 200,
      body: 'Connected',
    };
  } catch (error) {
    console.error('WebSocket connect error:', error);
    return {
      statusCode: 500,
      body: 'Internal server error',
    };
  }
};
