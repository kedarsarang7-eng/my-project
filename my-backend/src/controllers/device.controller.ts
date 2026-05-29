// ============================================================================
// Device Controller — Multi-Device Session Management (DynamoDB)
// ============================================================================
import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { Keys, queryItems, putItem, updateItem, getItem } from '../config/dynamodb.config';
import { verifyAuth } from '../middleware/cognito-auth';
import { logger } from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

// ── Types ────────────────────────────────────────────────────────────────
interface RegisterDeviceRequest {
    deviceId: string;
    deviceName?: string;
    platform?: string;
    appVersion?: string;
}

interface DeviceSession {
    id: string;
    deviceId: string;
    deviceName: string;
    platform: string;
    appVersion?: string;
    lastActiveAt: string;
    isActive: boolean;
    createdAt: string;
}

function jsonResponse(statusCode: number, body: unknown) {
    return { statusCode, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) };
}

/**
 * POST /devices/register — Register or re-activate a device session
 */
export async function registerDevice(event: APIGatewayProxyEventV2) {
    try {
        const auth = await verifyAuth(event);
        const body: RegisterDeviceRequest = JSON.parse(event.body || '{}');

        if (!body.deviceId) return jsonResponse(400, { error: 'deviceId is required' });

        const pk = Keys.tenantPK(auth.tenantId);
        const sk = `DEVICESESSION#${auth.sub}#${body.deviceId}`;
        const now = new Date().toISOString();

        // Upsert device session
        await putItem({
            PK: pk, SK: sk,
            entityType: 'DEVICE_SESSION',
            id: uuidv4(), tenantId: auth.tenantId, userSub: auth.sub,
            deviceId: body.deviceId, deviceName: body.deviceName || 'Unknown Device',
            platform: body.platform || 'unknown', appVersion: body.appVersion || null,
            lastActiveAt: now, isActive: true,
            createdAt: now, updatedAt: now,
        });

        logger.info('Device registered', { tenantId: auth.tenantId, userSub: auth.sub, deviceId: body.deviceId, platform: body.platform });
        return jsonResponse(200, { success: true, message: 'Device registered' });
    } catch (err) {
        logger.error('Device registration failed', { error: (err as Error).message });
        return jsonResponse((err as any).statusCode || 500, { error: (err as Error).message });
    }
}

/**
 * GET /devices — List all active devices for the current user
 */
export async function listDevices(event: APIGatewayProxyEventV2) {
    try {
        const auth = await verifyAuth(event);
        const pk = Keys.tenantPK(auth.tenantId);

        const sessions = await queryItems<Record<string, any>>(pk, `DEVICESESSION#${auth.sub}#`);

        const devices: DeviceSession[] = sessions.items.map(row => ({
            id: row.id,
            deviceId: row.deviceId,
            deviceName: row.deviceName,
            platform: row.platform,
            appVersion: row.appVersion,
            lastActiveAt: row.lastActiveAt || '',
            isActive: row.isActive,
            createdAt: row.createdAt || '',
        }));

        return jsonResponse(200, {
            devices,
            count: devices.length,
            currentDeviceId: auth.deviceId || null,
        });
    } catch (err) {
        logger.error('List devices failed', { error: (err as Error).message });
        return jsonResponse((err as any).statusCode || 500, { error: (err as Error).message });
    }
}

/**
 * POST /devices/{id}/deregister — Deactivate a device session (remote sign-out)
 */
export async function deregisterDevice(event: APIGatewayProxyEventV2) {
    try {
        const auth = await verifyAuth(event);
        const sessionId = event.pathParameters?.id;

        if (!sessionId) return jsonResponse(400, { error: 'Device session ID is required' });

        const pk = Keys.tenantPK(auth.tenantId);
        const now = new Date().toISOString();

        // Find the session by iterating device sessions for this user
        const sessions = await queryItems<Record<string, any>>(pk, `DEVICESESSION#${auth.sub}#`, {
            filterExpression: 'id = :sessionId',
            expressionAttributeValues: { ':sessionId': sessionId },
        });

        if (sessions.items.length === 0) return jsonResponse(404, { error: 'Device session not found' });

        const session = sessions.items[0];
        await updateItem(pk, session.SK, {
            updateExpression: 'SET isActive = :false, updatedAt = :now',
            expressionAttributeValues: { ':false': false, ':now': now },
        });

        logger.info('Device deregistered', { tenantId: auth.tenantId, sessionId });
        return jsonResponse(200, { success: true, message: 'Device deregistered' });
    } catch (err) {
        logger.error('Device deregistration failed', { error: (err as Error).message });
        return jsonResponse((err as any).statusCode || 500, { error: (err as Error).message });
    }
}

/**
 * POST /devices/heartbeat — Update last_active_at
 */
export async function deviceHeartbeat(event: APIGatewayProxyEventV2) {
    try {
        const auth = await verifyAuth(event);
        const deviceId = auth.deviceId || (JSON.parse(event.body || '{}') as { deviceId?: string }).deviceId;

        if (!deviceId) return jsonResponse(400, { error: 'deviceId required (header or body)' });

        const pk = Keys.tenantPK(auth.tenantId);
        const sk = `DEVICESESSION#${auth.sub}#${deviceId}`;
        const now = new Date().toISOString();

        const session = await getItem<Record<string, any>>(pk, sk);

        if (!session || !session.isActive) {
            return jsonResponse(410, { error: 'Device session expired or deregistered', code: 'DEVICE_DEREGISTERED' });
        }

        await updateItem(pk, sk, {
            updateExpression: 'SET lastActiveAt = :now, updatedAt = :now',
            expressionAttributeValues: { ':now': now },
        });

        return jsonResponse(200, { success: true });
    } catch (err) {
        logger.error('Device heartbeat failed', { error: (err as Error).message });
        return jsonResponse((err as any).statusCode || 500, { error: (err as Error).message });
    }
}
