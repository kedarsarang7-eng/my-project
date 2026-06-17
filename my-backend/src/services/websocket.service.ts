// ============================================================================
// WebSocket Broadcasting Service � Real-Time Event Delivery
// ============================================================================
// Manages WebSocket connections via DynamoDB and broadcasts events
// to connected clients through AWS API Gateway Management API.
//
// Architecture:
//   - Connections stored in DynamoDB with GSIs for efficient querying
//   - API Gateway Management API used to post messages to connections
//   - Stale connections auto-cleaned via DynamoDB TTL + on-send cleanup
//
// Usage in handlers:
//   import * as ws from '../services/websocket.service';
//   await ws.broadcastToBusiness(tenantId, { event, data });
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import {
    DynamoDBClient,
    PutItemCommand,
    DeleteItemCommand,
    GetItemCommand,
    UpdateItemCommand,
    QueryCommand,
    ScanCommand,
} from '@aws-sdk/client-dynamodb';
import {
    ApiGatewayManagementApiClient,
    PostToConnectionCommand,
    GoneException,
} from '@aws-sdk/client-apigatewaymanagementapi';
import { logger } from '../utils/logger';
import {
    WSConnectionRecord,
    WSEvent,
    WSEventName,
    ClientType,
} from '../types/websocket.types';
import {
    CloudWatchClient,
    PutMetricDataCommand,
} from '@aws-sdk/client-cloudwatch';
import { config } from '../config/environment';

// -- Configuration -----------------------------------------------------------

const TABLE_NAME = config.extendedDynamo.websocketConnectionsTable || 'WebsocketConnections';
const WS_ENDPOINT = config.websocket.endpoint || '';
const REGION = config.aws.region;

// Connection TTL: 24 hours (connections older than this are auto-removed by DynamoDB)
const CONNECTION_TTL_SECONDS = 24 * 60 * 60;

// -- Connection Cache (Phase 3: In-Memory, upgradeable to Redis) -------------
// Simple in-process cache to reduce DynamoDB reads during burst broadcasts.
// Cache entries expire after 30 seconds. In a multi-Lambda environment,
// this provides per-instance caching. For cross-instance caching, upgrade to
// ElastiCache Redis with the same key pattern: `ws:connections:{businessId}`

interface CacheEntry {
    connections: WSConnectionRecord[];
    expiresAt: number;
}

const connectionCache = new Map<string, CacheEntry>();
const CACHE_TTL_MS = 30_000; // 30 seconds

function getCachedConnections(cacheKey: string): WSConnectionRecord[] | null {
    const entry = connectionCache.get(cacheKey);
    if (entry && entry.expiresAt > Date.now()) {
        return entry.connections;
    }
    connectionCache.delete(cacheKey);
    return null;
}

function setCachedConnections(cacheKey: string, connections: WSConnectionRecord[]): void {
    connectionCache.set(cacheKey, {
        connections,
        expiresAt: Date.now() + CACHE_TTL_MS,
    });
    // Evict old entries if cache grows too large (prevent memory leak)
    if (connectionCache.size > 1000) {
        const now = Date.now();
        for (const [key, entry] of connectionCache) {
            if (entry.expiresAt < now) connectionCache.delete(key);
        }
    }
}

function invalidateCache(businessId: string): void {
    // Invalidate all cache keys containing this businessId
    for (const key of connectionCache.keys()) {
        if (key.includes(businessId)) connectionCache.delete(key);
    }
}

// -- Rate Limiting (Phase 3) -------------------------------------------------
// Simple per-business rate limiter to prevent broadcast storms.
// Allows max 100 events per business per 10 seconds.

const rateLimitMap = new Map<string, { count: number; windowStart: number }>();
const RATE_LIMIT_WINDOW_MS = 10_000; // 10 seconds
const RATE_LIMIT_MAX = 100; // max events per window

function checkRateLimit(businessId: string): boolean {
    const now = Date.now();
    const entry = rateLimitMap.get(businessId);

    if (!entry || (now - entry.windowStart) > RATE_LIMIT_WINDOW_MS) {
        rateLimitMap.set(businessId, { count: 1, windowStart: now });
        return true; // allowed
    }

    if (entry.count >= RATE_LIMIT_MAX) {
        logger.warn('[WebSocket] Rate limit exceeded', { businessId, count: entry.count });
        return false; // throttled
    }

    entry.count++;
    return true; // allowed
}

// -- CloudWatch Metrics (Phase 3) --------------------------------------------

let cwClient: CloudWatchClient | null = null;

function getCwClient(): CloudWatchClient {
    if (!cwClient) {
        cwClient = new CloudWatchClient(configureAwsClient({ region: REGION }));
    }
    return cwClient;
}

async function emitMetric(
    metricName: string,
    value: number,
    unit: 'Count' | 'Milliseconds' = 'Count',
): Promise<void> {
    try {
        await getCwClient().send(new PutMetricDataCommand({
            Namespace: 'DukanX/WebSocket',
            MetricData: [{
                MetricName: metricName,
                Value: value,
                Unit: unit,
                Timestamp: new Date(),
                Dimensions: [
                    { Name: 'Stage', Value: config.app.env || 'dev' },
                ],
            }],
        }));
    } catch {
        // Metrics are non-critical � silently fail
    }
}

// -- Clients (lazy-initialized) ----------------------------------------------

let dynamoClient: DynamoDBClient | null = null;
let apiGwClient: ApiGatewayManagementApiClient | null = null;

function getDynamoClient(): DynamoDBClient {
    if (!dynamoClient) {
        dynamoClient = new DynamoDBClient(configureAwsClient({ region: REGION }));
    }
    return dynamoClient;
}

function getApiGwClient(): ApiGatewayManagementApiClient {
    if (!apiGwClient) {
        if (!WS_ENDPOINT) {
            throw new Error('[WebSocket] WEBSOCKET_API_ENDPOINT not configured');
        }
        apiGwClient = new ApiGatewayManagementApiClient({
            region: REGION,
            endpoint: WS_ENDPOINT,
        });
    }
    return apiGwClient;
}

// ============================================================================
// CONNECTION MANAGEMENT
// ============================================================================

/**
 * Store a new WebSocket connection in DynamoDB.
 * Called from the $connect Lambda handler after successful authentication.
 */
export async function saveConnection(record: WSConnectionRecord): Promise<void> {
    const dynamo = getDynamoClient();
    const ttl = Math.floor(Date.now() / 1000) + CONNECTION_TTL_SECONDS;

    try {
        await dynamo.send(new PutItemCommand({
            TableName: TABLE_NAME,
            Item: {
                connectionId: { S: record.connectionId },
                clientType: { S: record.clientType },
                businessId: { S: record.businessId },
                userId: { S: record.userId },
                staffId: { S: record.staffId || '' },
                deviceId: { S: record.deviceId || '' },
                connectedAt: { S: record.connectedAt },
                ttl: { N: String(ttl) },
                isOnline: { BOOL: true },
                lastSeenAt: { S: new Date().toISOString() },
            },
        }));

        // Invalidate cached connections for this business
        invalidateCache(record.businessId);

        // Emit connection metric
        emitMetric('ConnectionsOpened', 1).catch(() => { });

        logger.info('[WebSocket] Connection saved', {
            connectionId: record.connectionId,
            clientType: record.clientType,
            businessId: record.businessId,
        });
    } catch (error) {
        logger.error('[WebSocket] Failed to save connection', {
            connectionId: record.connectionId,
            error: (error as Error).message,
        });
        throw error;
    }
}

/**
 * Remove a WebSocket connection from DynamoDB.
 * Called from the $disconnect Lambda handler.
 */
export async function removeConnection(connectionId: string): Promise<void> {
    const dynamo = getDynamoClient();

    // Get connection record before deleting (for cache invalidation)
    try {
        const getResult = await dynamo.send(new GetItemCommand({
            TableName: TABLE_NAME,
            Key: { connectionId: { S: connectionId } },
            ProjectionExpression: 'businessId',
        }));
        const businessId = getResult.Item?.businessId?.S;
        if (businessId) invalidateCache(businessId);
    } catch { /* best-effort cache invalidation */ }

    try {
        await dynamo.send(new DeleteItemCommand({
            TableName: TABLE_NAME,
            Key: { connectionId: { S: connectionId } },
        }));

        // Emit disconnection metric
        emitMetric('ConnectionsClosed', 1).catch(() => { });

        logger.info('[WebSocket] Connection removed', { connectionId });
    } catch (error) {
        logger.error('[WebSocket] Failed to remove connection', {
            connectionId,
            error: (error as Error).message,
        });
        throw error;
    }
}

// ============================================================================
// CONNECTION QUERIES
// ============================================================================

/**
 * Get all connections for a specific business.
 */
async function getConnectionsByBusiness(businessId: string): Promise<WSConnectionRecord[]> {
    // Check cache first (Phase 3)
    const cacheKey = `biz:${businessId}`;
    const cached = getCachedConnections(cacheKey);
    if (cached) {
        logger.debug('[WebSocket] Cache hit for business connections', { businessId, count: cached.length });
        return cached;
    }

    const dynamo = getDynamoClient();

    const result = await dynamo.send(new QueryCommand({
        TableName: TABLE_NAME,
        IndexName: 'businessId-index',
        KeyConditionExpression: 'businessId = :bid',
        ExpressionAttributeValues: {
            ':bid': { S: businessId },
        },
    }));

    const connections = (result.Items || []).map(itemToRecord);
    setCachedConnections(cacheKey, connections);
    return connections;
}

/**
 * Get connections for a specific business filtered by client type.
 */
async function getConnectionsByBusinessAndType(
    businessId: string,
    clientType: ClientType,
): Promise<WSConnectionRecord[]> {
    const dynamo = getDynamoClient();

    const result = await dynamo.send(new QueryCommand({
        TableName: TABLE_NAME,
        IndexName: 'businessId-index',
        KeyConditionExpression: 'businessId = :bid',
        FilterExpression: 'clientType = :ct',
        ExpressionAttributeValues: {
            ':bid': { S: businessId },
            ':ct': { S: clientType },
        },
    }));

    return (result.Items || []).map(itemToRecord);
}

/**
 * Get connections for a specific user within a business.
 */
async function getConnectionsByUser(
    businessId: string,
    userId: string,
): Promise<WSConnectionRecord[]> {
    const dynamo = getDynamoClient();

    const result = await dynamo.send(new QueryCommand({
        TableName: TABLE_NAME,
        IndexName: 'businessId-index',
        KeyConditionExpression: 'businessId = :bid',
        FilterExpression: 'userId = :uid',
        ExpressionAttributeValues: {
            ':bid': { S: businessId },
            ':uid': { S: userId },
        },
    }));

    return (result.Items || []).map(itemToRecord);
}

/**
 * Get connection for a specific device.
 */
async function getConnectionsByDevice(deviceId: string): Promise<WSConnectionRecord[]> {
    const dynamo = getDynamoClient();

    const result = await dynamo.send(new ScanCommand({
        TableName: TABLE_NAME,
        FilterExpression: 'deviceId = :did',
        ExpressionAttributeValues: {
            ':did': { S: deviceId },
        },
    }));

    return (result.Items || []).map(itemToRecord);
}

// ============================================================================
// BROADCASTING FUNCTIONS
// ============================================================================

/**
 * Broadcast an event to ALL connections for a specific business.
 *
 * Use when the event is relevant to every app/user within the business:
 *   - admin_action (kill switch)
 *   - notification (general)
 */
export async function broadcastToBusiness(
    businessId: string,
    event: WSEventName,
    data: Record<string, unknown>,
): Promise<void> {
    // Phase 3: Rate limiting
    if (!checkRateLimit(businessId)) {
        logger.warn('[WebSocket] Broadcast throttled by rate limit', { businessId, event });
        return;
    }

    const startTime = Date.now();
    const connections = await getConnectionsByBusiness(businessId);
    const payload = buildPayload(event, businessId, data);
    await sendToConnections(connections, payload, event);

    // Phase 3: Emit latency metric
    const latency = Date.now() - startTime;
    emitMetric('BroadcastLatency', latency, 'Milliseconds').catch(() => { });
    emitMetric('EventsBroadcast', 1).catch(() => { });
}

/**
 * Broadcast to staff_app connections only within a business.
 *
 * Use for:
 *   - order_created (new customer order ? staff fulfillment)
 *   - inventory_updated
 */
export async function broadcastToStaff(
    businessId: string,
    event: WSEventName,
    data: Record<string, unknown>,
): Promise<void> {
    const connections = await getConnectionsByBusinessAndType(businessId, ClientType.STAFF_APP);
    const payload = buildPayload(event, businessId, data);
    await sendToConnections(connections, payload, event);
}

/**
 * Broadcast to a specific customer within a business.
 *
 * Use for:
 *   - payment_success / payment_failed
 *   - order_updated (status change)
 */
export async function broadcastToCustomer(
    businessId: string,
    customerId: string,
    event: WSEventName,
    data: Record<string, unknown>,
): Promise<void> {
    const connections = await getConnectionsByUser(businessId, customerId);
    const payload = buildPayload(event, businessId, data);
    await sendToConnections(connections, payload, event);
}

/**
 * Broadcast to a specific client type within a business.
 *
 * Use for:
 *   - kot_created ? restaurant_staff_app
 *   - checkout_requested ? staff_app (cashier)
 */
export async function broadcastToClientType(
    businessId: string,
    clientType: ClientType,
    event: WSEventName,
    data: Record<string, unknown>,
): Promise<void> {
    const connections = await getConnectionsByBusinessAndType(businessId, clientType);
    const payload = buildPayload(event, businessId, data);
    await sendToConnections(connections, payload, event);
}

/**
 * Broadcast to a specific device.
 *
 * Use for targeted updates (e.g., sync completion for a specific device).
 */
export async function broadcastToDevice(
    deviceId: string,
    businessId: string,
    event: WSEventName,
    data: Record<string, unknown>,
): Promise<void> {
    const connections = await getConnectionsByDevice(deviceId);
    const payload = buildPayload(event, businessId, data);
    await sendToConnections(connections, payload, event);
}

/**
 * Broadcast a global event to ALL connected clients (all businesses).
 *
 * Use sparingly � only for platform-wide admin actions.
 */
export async function broadcastToAll(
    event: WSEventName,
    data: Record<string, unknown>,
): Promise<void> {
    const dynamo = getDynamoClient();
    const result = await dynamo.send(new ScanCommand({ TableName: TABLE_NAME }));
    const connections = (result.Items || []).map(itemToRecord);
    const payload = buildPayload(event, 'GLOBAL', data);
    await sendToConnections(connections, payload, event);
}

/**
 * Broadcast to owner/desktop connections only within a business.
 *
 * Use for:
 *   - dashboard_updated
 *   - staff login/logout monitoring
 *   - billing notifications
 */
export async function broadcastToOwner(
    businessId: string,
    event: WSEventName,
    data: Record<string, unknown>,
): Promise<void> {
    const connections = await getConnectionsByBusinessAndType(businessId, ClientType.DESKTOP_APP);
    const payload = buildPayload(event, businessId, data);
    await sendToConnections(connections, payload, event);
}

/**
 * Broadcast a manifest_invalidated event to all desktop apps connected to a tenant.
 * This signals clients to refresh their feature manifest via GET /tenant/config.
 *
 * Triggered by:
 *   - Plan upgrade/downgrade
 *   - PlanConfig DB override changes
 *   - Manual license feature overrides
 *
 * Payload:
 *   - reason: string describing what changed
 *   - refreshUrl: '/tenant/config' (stable endpoint)
 *   - refreshIntervalMs: 5000 (recommended backoff)
 */
export async function broadcastManifestInvalidated(
    tenantId: string,
    reason: string,
    triggeredBy: string,
): Promise<void> {
    const payload = {
        reason,
        triggeredBy,
        refreshUrl: '/tenant/config',
        refreshIntervalMs: 5000,
        timestamp: new Date().toISOString(),
    };

    logger.info('[WebSocket] Broadcasting manifest_invalidated', {
        tenantId,
        reason,
        triggeredBy,
    });

    // Target desktop apps specifically (Flutter clients)
    await broadcastToClientType(
        tenantId,
        ClientType.DESKTOP_APP,
        WSEventName.MANIFEST_INVALIDATED,
        payload,
    );
}

/**
 * High-level event emitter that routes events to the correct audience
 * based on event type. Simplifies handler code to a single call.
 *
 * Usage:
 *   await emitEvent(tenantId, WSEventName.ORDER_CREATED, { orderId, ... });
 */
export async function emitEvent(
    businessId: string,
    event: WSEventName,
    data: Record<string, unknown>,
    options?: {
        /** Target a specific customer by userId */
        customerId?: string;
        /** Target a specific staff member by userId */
        staffId?: string;
    },
): Promise<void> {
    switch (event) {
        // Orders ? staff + desktop
        case WSEventName.ORDER_CREATED:
        case WSEventName.ORDER_UPDATED:
        case WSEventName.ORDER_COMPLETED:
            await broadcastToBusiness(businessId, event, data);
            break;

        // KOT ? restaurant staff app + desktop
        case WSEventName.KOT_CREATED:
            await broadcastToClientType(businessId, ClientType.RESTAURANT_STAFF_APP, event, data);
            await broadcastToOwner(businessId, event, data);
            break;

        // Checkout ? cashier (staff app) + desktop
        case WSEventName.CHECKOUT_REQUESTED:
            await broadcastToStaff(businessId, event, data);
            await broadcastToOwner(businessId, event, data);
            break;

        // Payments ? specific customer + desktop
        case WSEventName.PAYMENT_SUCCESS:
        case WSEventName.PAYMENT_FAILED:
            if (options?.customerId) {
                await broadcastToCustomer(businessId, options.customerId, event, data);
            }
            await broadcastToOwner(businessId, event, data);
            break;

        // Billing ? business-wide
        case WSEventName.BILL_CREATED:
        case WSEventName.BILL_UPDATED:
            await broadcastToBusiness(businessId, event, data);
            break;

        // Inventory ? business-wide
        case WSEventName.INVENTORY_UPDATED:
        case WSEventName.LOW_STOCK_ALERT:
        case WSEventName.LOW_STOCK_RESOLVED:
        case WSEventName.EXPIRY_ALERT:
            await broadcastToBusiness(businessId, event, data);
            break;

        // Staff monitoring ? desktop only
        case WSEventName.STAFF_ACTIVITY:
        case WSEventName.STAFF_LOGIN:
        case WSEventName.STAFF_LOGOUT:
        case WSEventName.STAFF_ASSIGNED:
            await broadcastToOwner(businessId, event, data);
            break;

        // Staff sales ? business-wide (owner needs it, staff needs confirmation)
        case WSEventName.STAFF_SALE_CREATED:
        case WSEventName.PETROL_SALE_UPDATE:
        case WSEventName.DIESEL_SALE_UPDATE:
            await broadcastToBusiness(businessId, event, data);
            break;

        // Clinic ? business-wide
        case WSEventName.APPOINTMENT_CREATED:
        case WSEventName.QUEUE_UPDATED:
        case WSEventName.PRESCRIPTION_CREATED:
            await broadcastToBusiness(businessId, event, data);
            break;

        // Service business ? business-wide
        case WSEventName.SERVICE_JOB_CREATED:
        case WSEventName.SERVICE_STATUS_UPDATED:
            await broadcastToBusiness(businessId, event, data);
            break;

        // Pricing / Dashboard ? business-wide
        case WSEventName.PRICE_UPDATED:
        case WSEventName.DASHBOARD_UPDATED:
            await broadcastToBusiness(businessId, event, data);
            break;

        // Admin ? business-wide (or global handled separately)
        case WSEventName.ADMIN_ACTION:
            await broadcastToBusiness(businessId, event, data);
            break;

        // Notifications ? business-wide
        case WSEventName.NOTIFICATION:
            await broadcastToBusiness(businessId, event, data);
            break;

        // Sync ? business-wide
        case WSEventName.SYNC_COMPLETED:
        case WSEventName.DEVICE_SYNC:
            await broadcastToBusiness(businessId, event, data);
            break;

        // Plan Feature System v2 ? desktop apps only
        case WSEventName.MANIFEST_INVALIDATED:
            await broadcastToClientType(businessId, ClientType.DESKTOP_APP, event, data);
            break;

        // Smart Inventory Import ? desktop app owner only
        case WSEventName.IMPORT_PROGRESS:
        case WSEventName.IMPORT_COMPLETED:
        case WSEventName.IMPORT_FAILED:
            await broadcastToOwner(businessId, event, data);
            break;

        // In-Store Self Scan ? targeted to specific customer + business staff
        case WSEventName.IN_STORE_SESSION_STARTED:
        case WSEventName.IN_STORE_CART_UPDATED:
            await broadcastToCustomer(businessId, data.customerId as string, event, data);
            await broadcastToStaff(businessId, event, data);
            break;

        case WSEventName.IN_STORE_PAYMENT_SUCCESS:
        case WSEventName.IN_STORE_EXIT_QR_READY:
            await broadcastToCustomer(businessId, data.customerId as string, event, data);
            break;

        case WSEventName.IN_STORE_ORDER_VERIFIED:
            await broadcastToStaff(businessId, event, data);
            break;

        default:
            logger.warn('[WebSocket] Unknown event type in emitEvent', { event, businessId });
            await broadcastToBusiness(businessId, event, data);
            break;
    }
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

/**
 * Build a structured event payload.
 */
function buildPayload(event: WSEventName, businessId: string, data: Record<string, unknown>): string {
    const payload: WSEvent = {
        event,
        businessId,
        timestamp: new Date().toISOString(),
        data,
    };
    return JSON.stringify(payload);
}

/**
 * Send a message to multiple WebSocket connections.
 * Automatically cleans up stale/gone connections.
 *
 * Phase 2 enhancement: Filters by subscribedEvents before sending.
 */
async function sendToConnections(
    connections: WSConnectionRecord[],
    payload: string,
    eventName?: WSEventName,
): Promise<void> {
    if (connections.length === 0) return;

    // Phase 2: Filter by subscribed events (if the connection has subscriptions)
    let filteredConnections = connections;
    if (eventName) {
        filteredConnections = connections.filter(conn => {
            // If no subscribedEvents, send everything (backward-compatible)
            if (!conn.subscribedEvents || conn.subscribedEvents.length === 0) return true;
            return conn.subscribedEvents.includes(eventName);
        });

        if (filteredConnections.length < connections.length) {
            logger.debug('[WebSocket] Filtered by subscriptions', {
                total: connections.length,
                afterFilter: filteredConnections.length,
                event: eventName,
            });
        }
    }

    if (filteredConnections.length === 0) return;

    const apiGw = getApiGwClient();
    const staleConnectionIds: string[] = [];

    const results = await Promise.allSettled(
        filteredConnections.map(async (conn) => {
            try {
                await apiGw.send(new PostToConnectionCommand({
                    ConnectionId: conn.connectionId,
                    Data: new TextEncoder().encode(payload),
                }));
            } catch (error) {
                if (error instanceof GoneException || (error as any)?.statusCode === 410) {
                    // Connection is stale � mark for cleanup
                    staleConnectionIds.push(conn.connectionId);
                } else {
                    logger.warn('[WebSocket] Failed to post to connection', {
                        connectionId: conn.connectionId,
                        error: (error as Error).message,
                    });
                }
            }
        }),
    );

    // Clean up stale connections
    if (staleConnectionIds.length > 0) {
        logger.info('[WebSocket] Cleaning up stale connections', {
            count: staleConnectionIds.length,
        });
        await Promise.allSettled(
            staleConnectionIds.map((id) => removeConnection(id)),
        );

        // Phase 3: Emit stale connection metric
        emitMetric('StaleConnections', staleConnectionIds.length).catch(() => { });
    }

    const sent = filteredConnections.length - staleConnectionIds.length;
    logger.info('[WebSocket] Broadcast complete', {
        targetCount: filteredConnections.length,
        sentCount: sent,
        staleCount: staleConnectionIds.length,
    });

    // Phase 3: Emit fan-out metric
    emitMetric('MessagesSent', sent).catch(() => { });
}

/**
 * Convert a DynamoDB item to a WSConnectionRecord.
 */
function itemToRecord(item: Record<string, any>): WSConnectionRecord {
    // Parse subscribedEvents from DynamoDB StringSet
    let subscribedEvents: WSEventName[] | undefined;
    if (item.subscribedEvents?.SS) {
        subscribedEvents = item.subscribedEvents.SS as WSEventName[];
    } else if (item.subscribedEvents?.L) {
        subscribedEvents = item.subscribedEvents.L.map((e: any) => e.S) as WSEventName[];
    }

    return {
        connectionId: item.connectionId?.S || '',
        clientType: (item.clientType?.S || 'staff_app') as ClientType,
        businessId: item.businessId?.S || '',
        userId: item.userId?.S || '',
        staffId: item.staffId?.S || undefined,
        deviceId: item.deviceId?.S || undefined,
        connectedAt: item.connectedAt?.S || '',
        ttl: parseInt(item.ttl?.N || '0', 10),
        subscribedEvents,
        isOnline: item.isOnline?.BOOL ?? true,
        lastSeenAt: item.lastSeenAt?.S || undefined,
    };
}

// ============================================================================
// SUBSCRIPTION MANAGEMENT (Phase 2)
// ============================================================================

/**
 * Update the event subscriptions for a specific connection.
 * Called from the $default handler when a client sends a subscribe/unsubscribe message.
 */
export async function updateSubscriptions(
    connectionId: string,
    events: WSEventName[],
    action: 'subscribe' | 'unsubscribe',
): Promise<void> {
    const dynamo = getDynamoClient();

    try {
        if (action === 'subscribe') {
            // ADD events to the subscribedEvents StringSet
            await dynamo.send(new UpdateItemCommand({
                TableName: TABLE_NAME,
                Key: { connectionId: { S: connectionId } },
                UpdateExpression: 'ADD subscribedEvents :events',
                ExpressionAttributeValues: {
                    ':events': { SS: events },
                },
            }));
        } else {
            // DELETE events from the subscribedEvents StringSet
            await dynamo.send(new UpdateItemCommand({
                TableName: TABLE_NAME,
                Key: { connectionId: { S: connectionId } },
                UpdateExpression: 'DELETE subscribedEvents :events',
                ExpressionAttributeValues: {
                    ':events': { SS: events },
                },
            }));
        }

        logger.info('[WebSocket] Subscriptions updated', {
            connectionId,
            action,
            events,
        });
    } catch (error) {
        logger.warn('[WebSocket] Failed to update subscriptions', {
            connectionId,
            action,
            error: (error as Error).message,
        });
    }
}
