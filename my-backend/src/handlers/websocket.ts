// ============================================================================
// Lambda Handlers — WebSocket API Gateway ($connect, $disconnect, $default)
// ============================================================================
// These handlers manage WebSocket lifecycle events:
//   $connect    — Authenticate client via JWT, store connection in DynamoDB
//   $disconnect — Remove connection from DynamoDB
//   $default    — Handle incoming messages (ping, subscribe, etc.)
//
// The WebSocket URL format:
//   wss://<api-id>.execute-api.<region>.amazonaws.com/<stage>
//     ?authToken=<jwt>&clientType=staff_app&businessId=<id>
//     &staffId=<optional>&deviceId=<optional>
//
// SECURITY:
//   - JWT is verified using aws-jwt-verify (same as HTTP API handlers)
//   - Unauthorized connections are immediately rejected ($connect returns 401)
//   - All connection metadata is stored server-side in DynamoDB
// ============================================================================

import {
    APIGatewayProxyEventV2,
    APIGatewayProxyResultV2,
} from 'aws-lambda';
import { CognitoJwtVerifier } from 'aws-jwt-verify';
import { logger } from '../utils/logger';
import { wsConnectParamsSchema, wsClientMessageSchema } from '../schemas/websocket.schema';
import * as wsService from '../services/websocket.service';
import { ClientType, WSEventName } from '../types/websocket.types';
import { Keys, getItem, queryItems, putItem, updateItem } from '../config/dynamodb.config';
import { config } from '../config/environment';

// ── JWT Verifier (cached across warm Lambda invocations) ────────────────────

const USER_POOL_ID = config.cognito.userPoolId;
const CLIENT_IDS = [
    config.cognito.clientId,
    config.cognito.desktopClientId,
    config.cognito.mobileClientId,
    config.cognito.adminClientId,
].filter(Boolean) as string[];

let verifier: ReturnType<typeof CognitoJwtVerifier.create> | null = null;

function getVerifier() {
    if (!verifier) {
        verifier = CognitoJwtVerifier.create({
            userPoolId: USER_POOL_ID,
            tokenUse: 'access',
            clientId: CLIENT_IDS,
        });
    }
    return verifier;
}

// ============================================================================
// $connect — Authenticate and register connection
// ============================================================================

export async function wsConnect(
    event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
    const connectionId = (event.requestContext as any)?.connectionId;
    const queryParams = event.queryStringParameters || {};

    logger.info('[WebSocket] $connect attempt', {
        connectionId,
        clientType: queryParams.clientType,
        businessId: queryParams.businessId,
    });

    // 1. Validate query parameters
    const parsed = wsConnectParamsSchema.safeParse(queryParams);
    if (!parsed.success) {
        logger.warn('[WebSocket] Invalid connect params', {
            connectionId,
            errors: parsed.error.issues,
        });
        return { statusCode: 400, body: 'Invalid connection parameters' };
    }

    const { authToken, clientType, businessId, staffId, deviceId } = parsed.data;

    // 2. Verify JWT token
    try {
        const payload = await getVerifier().verify(authToken);

        // 2.5 Verify Business ID Ownership
        if (businessId) {
            const tenantId = (payload as Record<string, unknown>)['custom:tenant_id'] as string;
            const role = (payload as Record<string, unknown>)['custom:role'] as string;

            const business = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), `BUSINESS#${businessId}`);

            if (!business) {
                logger.warn('[WebSocket] Unauthorized business access attempt', {
                    connectionId,
                    businessId,
                    tenantId
                });
                return { statusCode: 403, body: 'Business access denied' };
            }

            if (role === 'staff') {
                const staffResult = await queryItems<Record<string, any>>(
                    Keys.tenantPK(tenantId), 'STAFF#',
                    {
                        filterExpression: 'businessId = :bid AND cognitoSub = :sub',
                        expressionAttributeValues: { ':bid': businessId, ':sub': payload.sub },
                        limit: 1,
                    }
                );
                if (staffResult.items.length === 0) {
                    logger.warn('[WebSocket] Staff unauthorized for this business', {
                        connectionId,
                        businessId,
                        userId: payload.sub
                    });
                    return { statusCode: 403, body: 'Staff unauthorized for this business' };
                }
            }
        }

        // 3. Store connection in DynamoDB
        await wsService.saveConnection({
            connectionId,
            clientType: clientType as ClientType,
            businessId,
            userId: payload.sub || '',
            staffId,
            deviceId,
            connectedAt: new Date().toISOString(),
            ttl: 0, // Set by saveConnection
        });

        logger.info('[WebSocket] $connect success', {
            connectionId,
            userId: payload.sub,
            clientType,
            businessId,
        });

        return { statusCode: 200, body: 'Connected' };
    } catch (error) {
        logger.warn('[WebSocket] $connect auth failed', {
            connectionId,
            error: (error as Error).message,
        });
        return { statusCode: 401, body: 'Unauthorized' };
    }
}

// ============================================================================
// $disconnect — Clean up connection
// ============================================================================

export async function wsDisconnect(
    event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
    const connectionId = (event.requestContext as any)?.connectionId;

    logger.info('[WebSocket] $disconnect', { connectionId });

    try {
        await wsService.removeConnection(connectionId);
    } catch (error) {
        logger.error('[WebSocket] Failed to remove connection', {
            connectionId,
            error: (error as Error).message,
        });
    }

    return { statusCode: 200, body: 'Disconnected' };
}

// ============================================================================
// $default — Handle incoming messages
// ============================================================================

export async function wsDefault(
    event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
    const connectionId = (event.requestContext as any)?.connectionId;
    const body = event.body || '';

    try {
        const message = JSON.parse(body);
        const parsed = wsClientMessageSchema.safeParse(message);

        if (!parsed.success) {
            logger.warn('[WebSocket] Invalid message format', {
                connectionId,
                errors: parsed.error.issues,
            });
            return { statusCode: 400, body: 'Invalid message format' };
        }

        switch (parsed.data.action) {
            case 'ping':
                // Client keepalive — update last seen for presence tracking
                try {
                    const presenceService = await import('../services/presence.service');
                    await presenceService.updateLastSeen(connectionId);
                } catch { /* non-critical */ }
                return { statusCode: 200, body: JSON.stringify({ action: 'pong' }) };

            case 'subscribe':
                // Phase 2: Persist event subscriptions to DynamoDB
                if (parsed.data.events && parsed.data.events.length > 0) {
                    await wsService.updateSubscriptions(connectionId, parsed.data.events as WSEventName[], 'subscribe');
                }
                logger.info('[WebSocket] Subscribe request', {
                    connectionId,
                    events: parsed.data.events,
                });
                return {
                    statusCode: 200,
                    body: JSON.stringify({
                        action: 'subscribed',
                        events: parsed.data.events,
                    }),
                };

            case 'unsubscribe':
                // Phase 2: Remove event subscriptions from DynamoDB
                if (parsed.data.events && parsed.data.events.length > 0) {
                    await wsService.updateSubscriptions(connectionId, parsed.data.events as WSEventName[], 'unsubscribe');
                }
                logger.info('[WebSocket] Unsubscribe request', {
                    connectionId,
                    events: parsed.data.events,
                });
                return {
                    statusCode: 200,
                    body: JSON.stringify({
                        action: 'unsubscribed',
                        events: parsed.data.events,
                    }),
                };

            case 'presence':
                // Phase 4: Handle presence status updates
                try {
                    const presenceService = await import('../services/presence.service');
                    await presenceService.updateLastSeen(connectionId);
                } catch { /* non-critical */ }
                logger.info('[WebSocket] Presence update', {
                    connectionId,
                    status: parsed.data.status,
                });
                return {
                    statusCode: 200,
                    body: JSON.stringify({
                        action: 'presence_ack',
                        status: parsed.data.status,
                    }),
                };

            default:
                return { statusCode: 400, body: 'Unknown action' };
        }
    } catch (error) {
        logger.error('[WebSocket] Error processing message', {
            connectionId,
            error: (error as Error).message,
        });
        return { statusCode: 500, body: 'Internal error' };
    }
}
