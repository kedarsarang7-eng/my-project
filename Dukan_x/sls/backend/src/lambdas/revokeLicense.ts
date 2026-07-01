// ============================================
// Lambda: POST /api/admin/revoke/{license_key}
// ============================================
// Immediately revoke or ban a license key.
// Protected by JWT admin authentication.

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { updateLicenseStatus, getLicenseKey, DynamoLicenseStatus } from '../services/dynamoLicenseService';
import { verifyAccessToken } from '../middleware/auth';
import { logger } from '../utils/logger';

interface RevokeBody {
    action: 'ban' | 'revoke' | 'reactivate';
    reason?: string;
}

export async function handler(
    event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyResultV2> {
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': process.env.CORS_ORIGIN || '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    try {
        // ---- Authenticate ----
        const authHeader = event.headers?.authorization || event.headers?.Authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return {
                statusCode: 401,
                headers,
                body: JSON.stringify({ error: 'Authentication required', code: 'AUTH_MISSING' }),
            };
        }

        const token = authHeader.split(' ')[1];
        const payload = verifyAccessToken(token);

        if (payload.role !== 'admin' && payload.role !== 'superadmin') {
            return {
                statusCode: 403,
                headers,
                body: JSON.stringify({ error: 'Admin access required', code: 'AUTH_FORBIDDEN' }),
            };
        }

        // ---- Extract license_key from path ----
        const licenseKey = event.pathParameters?.license_key;
        if (!licenseKey) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'license_key path parameter is required' }),
            };
        }

        // URL-decode the key (dashes may be encoded)
        const decodedKey = decodeURIComponent(licenseKey);

        // ---- Check key exists ----
        const existing = await getLicenseKey(decodedKey);
        if (!existing) {
            return {
                statusCode: 404,
                headers,
                body: JSON.stringify({ error: 'License key not found', code: 'NOT_FOUND' }),
            };
        }

        // ---- Parse Body ----
        let body: RevokeBody = { action: 'ban' };
        if (event.body) {
            body = JSON.parse(
                event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString() : event.body
            );
        }

        // ---- Map action to DynamoDB status ----
        let newStatus: DynamoLicenseStatus;
        switch (body.action) {
            case 'ban':
                newStatus = 'BANNED';
                break;
            case 'revoke':
                newStatus = 'INACTIVE';
                break;
            case 'reactivate':
                newStatus = 'ACTIVE';
                break;
            default:
                return {
                    statusCode: 400,
                    headers,
                    body: JSON.stringify({ error: 'Invalid action. Must be: ban, revoke, or reactivate' }),
                };
        }

        // ---- Update Status ----
        const updated = await updateLicenseStatus(decodedKey, newStatus, body.reason);

        logger.info('License status changed via Lambda', {
            license_key: decodedKey,
            action: body.action,
            new_status: newStatus,
            admin: payload.email,
        });

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                message: `License ${body.action === 'reactivate' ? 'reactivated' : body.action === 'ban' ? 'banned' : 'revoked'} successfully`,
                license_key: decodedKey,
                status: updated?.status || newStatus,
                revoked_at: updated?.revoked_at,
            }),
        };
    } catch (error: any) {
        if (error.name === 'TokenExpiredError') {
            return {
                statusCode: 401,
                headers,
                body: JSON.stringify({ error: 'Token expired', code: 'AUTH_EXPIRED' }),
            };
        }
        if (error.name === 'JsonWebTokenError') {
            return {
                statusCode: 401,
                headers,
                body: JSON.stringify({ error: 'Invalid token', code: 'AUTH_INVALID' }),
            };
        }

        logger.error('revokeLicense Lambda error', { error: error.message, stack: error.stack });
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({ error: 'Internal server error', code: 'INTERNAL_ERROR' }),
        };
    }
}
