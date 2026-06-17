// ============================================================================
// Presence Service � Online/Offline Staff Tracking (Phase 4)
// ============================================================================
// Tracks which staff/users are currently online and broadcasts
// presence changes to the business owner's dashboard.
//
// Architecture:
//   - DynamoDB stores presence records (userId ? status)
//   - Updated on $connect, $disconnect, and explicit presence messages
//   - Owner desktop receives PRESENCE_CHANGED events
//   - Graceful fallback: if presence tracking fails, core broadcast continues
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import {
    DynamoDBClient,
    PutItemCommand,
    GetItemCommand,
    DeleteItemCommand,
    QueryCommand,
    UpdateItemCommand,
} from '@aws-sdk/client-dynamodb';
import { logger } from '../utils/logger';
import { ClientType, WSPresenceRecord } from '../types/websocket.types';
import { config } from '../config/environment';

// -- Configuration -----------------------------------------------------------

const CONNECTIONS_TABLE = config.extendedDynamo.websocketConnectionsTable || 'WebsocketConnections';
const REGION = config.aws.region;

// -- Client (lazy-initialized) -----------------------------------------------

let dynamoClient: DynamoDBClient | null = null;

function getDynamoClient(): DynamoDBClient {
    if (!dynamoClient) {
        dynamoClient = new DynamoDBClient(configureAwsClient({ region: REGION }));
    }
    return dynamoClient;
}

// ============================================================================
// PRESENCE TRACKING
// ============================================================================

/**
 * Mark a user as online when they connect.
 * Updates the connection record with presence metadata.
 */
export async function markOnline(
    connectionId: string,
    userId: string,
    businessId: string,
): Promise<void> {
    try {
        const dynamo = getDynamoClient();
        await dynamo.send(new UpdateItemCommand({
            TableName: CONNECTIONS_TABLE,
            Key: { connectionId: { S: connectionId } },
            UpdateExpression: 'SET isOnline = :online, lastSeenAt = :now',
            ExpressionAttributeValues: {
                ':online': { BOOL: true },
                ':now': { S: new Date().toISOString() },
            },
        }));

        logger.info('[Presence] User marked online', { userId, businessId, connectionId });
    } catch (error) {
        logger.warn('[Presence] Failed to mark online � non-critical', {
            userId,
            error: (error as Error).message,
        });
    }
}

/**
 * Mark a user as offline when they disconnect.
 * Also checks if they have other active connections before going fully offline.
 */
export async function markOffline(
    connectionId: string,
    userId: string,
    businessId: string,
): Promise<void> {
    try {
        const dynamo = getDynamoClient();

        // Check if user has other active connections
        const result = await dynamo.send(new QueryCommand({
            TableName: CONNECTIONS_TABLE,
            IndexName: 'businessId-index',
            KeyConditionExpression: 'businessId = :bid',
            FilterExpression: 'userId = :uid AND connectionId <> :cid',
            ExpressionAttributeValues: {
                ':bid': { S: businessId },
                ':uid': { S: userId },
                ':cid': { S: connectionId },
            },
        }));

        const otherConnections = (result.Items || []).length;
        const isFullyOffline = otherConnections === 0;

        logger.info('[Presence] User disconnect', {
            userId, businessId, connectionId,
            otherConnections, isFullyOffline,
        });

        // Only broadcast offline status if no other connections remain
        if (isFullyOffline) {
            logger.info('[Presence] User fully offline � no remaining connections', {
                userId, businessId,
            });
        }
    } catch (error) {
        logger.warn('[Presence] Failed to process offline � non-critical', {
            userId, connectionId,
            error: (error as Error).message,
        });
    }
}

/**
 * Update last-seen timestamp for heartbeat/activity tracking.
 */
export async function updateLastSeen(
    connectionId: string,
): Promise<void> {
    try {
        const dynamo = getDynamoClient();
        await dynamo.send(new UpdateItemCommand({
            TableName: CONNECTIONS_TABLE,
            Key: { connectionId: { S: connectionId } },
            UpdateExpression: 'SET lastSeenAt = :now',
            ExpressionAttributeValues: {
                ':now': { S: new Date().toISOString() },
            },
        }));
    } catch (error) {
        // Silently fail � presence is non-critical
        logger.debug('[Presence] Failed to update lastSeen', {
            connectionId,
            error: (error as Error).message,
        });
    }
}

/**
 * Get presence status for all staff within a business.
 * Returns which staff members are currently online.
 */
export async function getBusinessPresence(
    businessId: string,
): Promise<WSPresenceRecord[]> {
    try {
        const dynamo = getDynamoClient();

        const result = await dynamo.send(new QueryCommand({
            TableName: CONNECTIONS_TABLE,
            IndexName: 'businessId-index',
            KeyConditionExpression: 'businessId = :bid',
            ExpressionAttributeValues: {
                ':bid': { S: businessId },
            },
        }));

        // Group connections by userId to determine presence
        const userMap = new Map<string, {
            userId: string;
            connections: number;
            clientTypes: Set<ClientType>;
            lastSeenAt: string;
        }>();

        for (const item of result.Items || []) {
            const userId = item.userId?.S || '';
            if (!userId) continue;

            const existing = userMap.get(userId);
            const clientType = (item.clientType?.S || '') as ClientType;
            const lastSeen = item.lastSeenAt?.S || item.connectedAt?.S || '';

            if (existing) {
                existing.connections++;
                existing.clientTypes.add(clientType);
                if (lastSeen > existing.lastSeenAt) {
                    existing.lastSeenAt = lastSeen;
                }
            } else {
                userMap.set(userId, {
                    userId,
                    connections: 1,
                    clientTypes: new Set([clientType]),
                    lastSeenAt: lastSeen,
                });
            }
        }

        return Array.from(userMap.values()).map(u => ({
            userId: u.userId,
            businessId,
            status: 'online' as const,
            lastSeenAt: u.lastSeenAt,
            activeConnections: u.connections,
            clientTypes: Array.from(u.clientTypes),
        }));
    } catch (error) {
        logger.warn('[Presence] Failed to get business presence', {
            businessId,
            error: (error as Error).message,
        });
        return [];
    }
}
