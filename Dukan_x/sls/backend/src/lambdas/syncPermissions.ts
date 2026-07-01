
// ============================================
// Lambda: GET /api/rbac/sync
// ============================================
// Syncs effective permissions for the authenticated user.
// Returns permissions list and lease expiry time.
//
// Headers:
//   Authorization: Bearer <token>
//   x-shop-id: <tenant_id>

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { verifyAccessToken } from '../middleware/auth';
import { syncPermissions } from '../services/rbacService';
import { logger } from '../utils/logger';

export async function handler(
    event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyResultV2> {
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': process.env.CORS_ORIGIN || '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-shop-id',
    };

    try {
        // 1. Authenticate (JWT)
        const authHeader = event.headers?.authorization || event.headers?.Authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return {
                statusCode: 401,
                headers,
                body: JSON.stringify({ error: 'Authentication required', code: 'AUTH_MISSING' }),
            };
        }

        const token = authHeader.split(' ')[1];
        let payload;
        try {
            payload = verifyAccessToken(token);
        } catch (err) {
            return {
                statusCode: 401,
                headers,
                body: JSON.stringify({ error: 'Invalid or expired token', code: 'AUTH_INVALID' }),
            };
        }

        const userId = payload.sub;

        // 2. Extract Tenant ID
        const tenantId = event.headers?.['x-shop-id'] || event.queryStringParameters?.shop_id;

        if (!tenantId) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'Tenant ID (x-shop-id) is required', code: 'TENANT_MISSING' }),
            };
        }

        // 3. Sync Permissions
        const result = await syncPermissions(tenantId, userId);

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify(result),
        };

    } catch (error: any) {
        logger.error('syncPermissions Lambda error', { error: error.message, stack: error.stack });

        // Return safe error
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({ error: 'Internal server error', code: 'INTERNAL_ERROR' }),
        };
    }
}
