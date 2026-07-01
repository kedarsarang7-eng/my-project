// ============================================
// Lambda: POST /api/client/validate
// ============================================
// Client-facing endpoint. Receives { license_key, machine_hwid }.
// Logic:
//   - Key NEW → bind HWID, set ACTIVE, return success
//   - Key ACTIVE + HWID matches → return success
//   - Key ACTIVE + HWID mismatch → return "Invalid Machine" error
//   - Key BANNED/INACTIVE → return error
//
// NO authentication required — this is called by the desktop client.
// Rate-limited by API Gateway throttling.

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { validateAndBindHwid } from '../services/dynamoLicenseService';
import { logger } from '../utils/logger';

interface ValidateBody {
    license_key: string;
    machine_hwid: string;
}

export async function handler(
    event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyResultV2> {
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
    };

    try {
        // ---- Parse Body ----
        if (!event.body) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ valid: false, error: 'Request body is required', code: 'INVALID_REQUEST' }),
            };
        }

        const body: ValidateBody = JSON.parse(
            event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString() : event.body
        );

        // ---- Validate Input ----
        if (!body.license_key || typeof body.license_key !== 'string') {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ valid: false, error: 'license_key is required', code: 'MISSING_KEY' }),
            };
        }

        if (!body.machine_hwid || typeof body.machine_hwid !== 'string') {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ valid: false, error: 'machine_hwid is required', code: 'MISSING_HWID' }),
            };
        }

        // Validate key format: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
        const keyRegex = /^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$/;
        if (!keyRegex.test(body.license_key)) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({
                    valid: false,
                    error: 'Invalid license key format. Expected: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
                    code: 'INVALID_FORMAT',
                }),
            };
        }

        // Validate HWID minimum length
        if (body.machine_hwid.length < 16) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ valid: false, error: 'machine_hwid must be at least 16 characters', code: 'INVALID_HWID' }),
            };
        }

        // ---- Validate & Bind ----
        const result = await validateAndBindHwid(body.license_key, body.machine_hwid);

        const sourceIp = event.requestContext?.http?.sourceIp || 'unknown';
        logger.info('License validation attempt', {
            license_key: body.license_key.substring(0, 10) + '...',
            success: result.success,
            ip: sourceIp,
        });

        if (!result.success) {
            // Determine appropriate error code
            let code = 'VALIDATION_FAILED';
            if (result.message.includes('Invalid Machine')) code = 'HWID_MISMATCH';
            else if (result.message.includes('banned')) code = 'LICENSE_BANNED';
            else if (result.message.includes('deactivated')) code = 'LICENSE_INACTIVE';
            else if (result.message.includes('expired')) code = 'LICENSE_EXPIRED';
            else if (result.message.includes('Invalid license')) code = 'INVALID_KEY';

            return {
                statusCode: 403,
                headers,
                body: JSON.stringify({ valid: false, error: result.message, code }),
            };
        }

        // ---- Success Response ----
        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                valid: true,
                message: result.message,
                license: {
                    business_type: result.license!.business_type,
                    tier: result.license!.tier,
                    license_type: result.license!.license_type,
                    feature_flags: result.license!.feature_flags,
                    expires_at: result.license!.expires_at,
                    activation_date: result.license!.activation_date,
                    max_devices: result.license!.max_devices,
                },
            }),
        };
    } catch (error: any) {
        if (error instanceof SyntaxError) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ valid: false, error: 'Invalid JSON in request body', code: 'INVALID_JSON' }),
            };
        }

        logger.error('validateLicense Lambda error', { error: error.message, stack: error.stack });
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({ valid: false, error: 'Internal server error', code: 'INTERNAL_ERROR' }),
        };
    }
}
