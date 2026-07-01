// ============================================
// Lambda: GET /api/admin/stats
// ============================================
// Returns count of total, active, new, inactive, and banned licenses.
// Protected by JWT admin authentication.

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { getLicenseStats, listLicenseKeys } from '../services/dynamoLicenseService';
import { verifyAccessToken } from '../middleware/auth';
import { logger } from '../utils/logger';

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

        // ---- Fetch Stats ----
        const stats = await getLicenseStats();

        // ---- Fetch recent licenses (last 10) for the dashboard ----
        const recentResult = await listLicenseKeys({ limit: 10 });

        logger.info('Admin stats fetched', { admin: payload.email, stats });

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                stats: {
                    total_licenses: stats.total,
                    new_licenses: stats.new,
                    active_licenses: stats.active,
                    inactive_licenses: stats.inactive,
                    banned_licenses: stats.banned,
                },
                recent_licenses: recentResult.items.map((lic) => ({
                    license_key: lic.license_key,
                    status: lic.status,
                    tier: lic.tier,
                    client_name: lic.client_name,
                    hwid: lic.hwid ? lic.hwid.substring(0, 12) + '...' : null,
                    activation_date: lic.activation_date,
                    created_at: lic.created_at,
                    expires_at: lic.expires_at,
                })),
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

        logger.error('adminStats Lambda error', { error: error.message, stack: error.stack });
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({ error: 'Internal server error', code: 'INTERNAL_ERROR' }),
        };
    }
}
