// ============================================================================
// Offline Message Queue Service (Phase 4)
// ============================================================================
// Stores messages for users who are not currently connected.
// When the user reconnects, their missed messages are replayed.
//
// Architecture:
//   - DynamoDB table: dukanx-ws-offline-messages-{stage}
//   - PK: userId, SK: messageId (ULID for ordering)
//   - TTL: 24 hours (messages older than this are auto-deleted)
//   - On reconnection, client sends { action: 'replay', since: 'ISO-timestamp' }
//     and receives all queued messages
//
// Usage:
//   import * as offlineQueue from '../services/offline-queue.service';
//   await offlineQueue.queueMessage(userId, businessId, event, data);
//   const missed = await offlineQueue.getAndDeleteMessages(userId);
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import {
    DynamoDBClient,
    PutItemCommand,
    QueryCommand,
    BatchWriteItemCommand,
} from '@aws-sdk/client-dynamodb';
import { logger } from '../utils/logger';
import { WSEventName, WSOfflineMessage } from '../types/websocket.types';
import { config } from '../config/environment';

// -- Configuration -----------------------------------------------------------

const TABLE_NAME = config.extendedDynamo.offlineMessagesTable || 'dukanx-ws-offline-messages';
const REGION = config.aws.region;
const MESSAGE_TTL_SECONDS = 24 * 60 * 60; // 24 hours
const MAX_QUEUED_PER_USER = 100; // Prevent unbounded growth

// -- Client (lazy-initialized) -----------------------------------------------

let dynamoClient: DynamoDBClient | null = null;

function getDynamoClient(): DynamoDBClient {
    if (!dynamoClient) {
        dynamoClient = new DynamoDBClient(configureAwsClient({ region: REGION }));
    }
    return dynamoClient;
}

// ============================================================================
// PUBLIC API
// ============================================================================

/**
 * Generate a unique, time-ordered message ID (ULID-like).
 * Uses timestamp prefix for chronological ordering in DynamoDB range key.
 */
function generateMessageId(): string {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substring(2, 8);
    return `${timestamp}-${random}`;
}

/**
 * Queue a message for an offline user.
 * Called when broadcastToCustomer/broadcastToUser detects no active connections.
 */
export async function queueMessage(
    userId: string,
    businessId: string,
    event: WSEventName,
    data: Record<string, unknown>,
): Promise<void> {
    const dynamo = getDynamoClient();
    const messageId = generateMessageId();
    const now = new Date().toISOString();
    const ttl = Math.floor(Date.now() / 1000) + MESSAGE_TTL_SECONDS;

    try {
        await dynamo.send(new PutItemCommand({
            TableName: TABLE_NAME,
            Item: {
                userId: { S: userId },
                messageId: { S: messageId },
                businessId: { S: businessId },
                event: { S: event },
                data: { S: JSON.stringify(data) },
                createdAt: { S: now },
                ttl: { N: String(ttl) },
                delivered: { BOOL: false },
            },
        }));

        logger.info('[OfflineQueue] Message queued', {
            userId,
            messageId,
            event,
            businessId,
        });
    } catch (error) {
        logger.warn('[OfflineQueue] Failed to queue message � non-critical', {
            userId,
            event,
            error: (error as Error).message,
        });
    }
}

/**
 * Retrieve all queued messages for a user (for replay on reconnection).
 * Messages are returned in chronological order.
 *
 * @param userId - The user's Cognito sub
 * @param since - Optional ISO timestamp to only get messages after this time
 * @returns Array of offline messages, ordered by messageId (chronological)
 */
export async function getMessages(
    userId: string,
    since?: string,
): Promise<WSOfflineMessage[]> {
    const dynamo = getDynamoClient();

    try {
        const params: any = {
            TableName: TABLE_NAME,
            KeyConditionExpression: 'userId = :uid',
            ExpressionAttributeValues: {
                ':uid': { S: userId },
            },
            Limit: MAX_QUEUED_PER_USER,
            ScanIndexForward: true, // Oldest first
        };

        // Filter by timestamp if 'since' is provided
        if (since) {
            params.FilterExpression = 'createdAt > :since';
            params.ExpressionAttributeValues[':since'] = { S: since };
        }

        const result = await dynamo.send(new QueryCommand(params));

        return (result.Items || []).map(item => ({
            messageId: item.messageId?.S || '',
            businessId: item.businessId?.S || '',
            userId: item.userId?.S || '',
            event: (item.event?.S || '') as WSEventName,
            data: JSON.parse(item.data?.S || '{}'),
            createdAt: item.createdAt?.S || '',
            ttl: parseInt(item.ttl?.N || '0', 10),
            delivered: item.delivered?.BOOL || false,
        }));
    } catch (error) {
        logger.warn('[OfflineQueue] Failed to get messages', {
            userId,
            error: (error as Error).message,
        });
        return [];
    }
}

/**
 * Delete messages after successful delivery (cleanup).
 * Uses BatchWriteItem for efficiency (max 25 per batch).
 */
export async function deleteMessages(
    userId: string,
    messageIds: string[],
): Promise<void> {
    if (messageIds.length === 0) return;

    const dynamo = getDynamoClient();

    // BatchWriteItem supports max 25 items per call
    const batches = [];
    for (let i = 0; i < messageIds.length; i += 25) {
        batches.push(messageIds.slice(i, i + 25));
    }

    for (const batch of batches) {
        try {
            await dynamo.send(new BatchWriteItemCommand({
                RequestItems: {
                    [TABLE_NAME]: batch.map(messageId => ({
                        DeleteRequest: {
                            Key: {
                                userId: { S: userId },
                                messageId: { S: messageId },
                            },
                        },
                    })),
                },
            }));
        } catch (error) {
            logger.warn('[OfflineQueue] Failed to delete messages batch', {
                userId,
                batchSize: batch.length,
                error: (error as Error).message,
            });
        }
    }

    logger.info('[OfflineQueue] Messages cleaned up', {
        userId,
        count: messageIds.length,
    });
}

/**
 * Get queued messages and mark them as delivered.
 * Convenience function for the reconnection flow.
 */
export async function getAndDeliverMessages(
    userId: string,
    since?: string,
): Promise<WSOfflineMessage[]> {
    const messages = await getMessages(userId, since);

    if (messages.length > 0) {
        // Delete delivered messages in the background
        const messageIds = messages.map(m => m.messageId);
        deleteMessages(userId, messageIds).catch(() => { });
    }

    return messages;
}
