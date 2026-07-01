// ============================================
// Lambda: POST /api/admin/generate-key
// ============================================
// Generates a cryptographically secure license key and stores it in DynamoDB.
// Protected by JWT admin authentication.

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { generateLicenseKey, BusinessType, VALID_BUSINESS_TYPES } from '../services/dynamoLicenseService';
import { verifyAccessToken } from '../middleware/auth';
import { logger } from '../utils/logger';

interface GenerateKeyBody {
    business_type?: string;
    client_name?: string;
    client_email?: string;
    tier?: string;
    license_type?: string;
    max_devices?: number;
    feature_flags?: Record<string, boolean | number | string>;
    expires_at?: string;
    notes?: string;
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

        // ---- Parse Body ----
        let body: GenerateKeyBody = {};
        if (event.body) {
            body = JSON.parse(event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString() : event.body);
        }

        // ---- Validate tier ----
        const validTiers = ['basic', 'pro', 'enterprise'];
        if (body.tier && !validTiers.includes(body.tier)) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: `Invalid tier. Must be one of: ${validTiers.join(', ')}` }),
            };
        }

        // ---- Validate license_type ----
        const validTypes = ['trial', 'standard', 'lifetime'];
        if (body.license_type && !validTypes.includes(body.license_type)) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: `Invalid license_type. Must be one of: ${validTypes.join(', ')}` }),
            };
        }

        // ---- Generate Key ----
        const license = await generateLicenseKey({
            business_type: (VALID_BUSINESS_TYPES.includes(body.business_type as BusinessType) ? body.business_type : 'other') as BusinessType,
            client_name: body.client_name,
            client_email: body.client_email,
            tier: body.tier,
            license_type: body.license_type,
            max_devices: body.max_devices,
            feature_flags: body.feature_flags,
            expires_at: body.expires_at,
            notes: body.notes,
            issued_by: payload.sub,
        });

        logger.info('License key generated via Lambda', {
            key: license.license_key,
            admin: payload.email,
        });

        return {
            statusCode: 201,
            headers,
            body: JSON.stringify({
                message: 'License key generated successfully',
                license_key: license.license_key,
                status: license.status,
                tier: license.tier,
                license_type: license.license_type,
                created_at: license.created_at,
                expires_at: license.expires_at,
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

        logger.error('generateKey Lambda error', { error: error.message, stack: error.stack });
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({ error: 'Internal server error', code: 'INTERNAL_ERROR' }),
        };
    }
}
