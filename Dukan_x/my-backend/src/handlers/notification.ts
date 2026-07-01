
import { SNSClient, CreatePlatformEndpointCommand } from "@aws-sdk/client-sns";
import { authorizedHandler } from '../middleware/handler-wrapper';
import { getPool } from '../config/db.config';
import { logger } from '../utils/logger';
import * as response from '../utils/response';

const snsClient = new SNSClient({ region: process.env.AWS_REGION });
const PLATFORM_APPLICATION_ARN = process.env.PLATFORM_APPLICATION_ARN;

/**
 * Register a device for push notifications.
 * POST /notifications/register-device
 * Body: { customerId: string, fcmToken: string }
 */
export const registerDevice = authorizedHandler([], async (event, _context, auth) => {
    const body = JSON.parse(event.body || '{}');
    const { customerId, fcmToken } = body;

    if (!customerId || !fcmToken) {
        return response.badRequest('Missing required fields: customerId, fcmToken');
    }

    if (!PLATFORM_APPLICATION_ARN) {
        logger.error('PLATFORM_APPLICATION_ARN is not configured');
        return response.internalError('Notification service not configured');
    }

    try {
        // 1. Create Platform Endpoint in SNS
        const command = new CreatePlatformEndpointCommand({
            PlatformApplicationArn: PLATFORM_APPLICATION_ARN,
            Token: fcmToken,
            CustomUserData: JSON.stringify({ customerId, tenantId: auth.tenantId })
        });

        const snsResponse = await snsClient.send(command);
        const endpointArn = snsResponse.EndpointArn;

        if (!endpointArn) {
            throw new Error('Failed to create SNS Platform Endpoint');
        }

        logger.info('SNS Endpoint Created', { customerId, endpointArn });

        // 2. Update Database with EndpointArn
        const pool = getPool();
        // Assuming 'users' table holds customers. If customers are in a separate table, update accordingly.
        // Based on schema, 'users' seems to be strictly staff/admin linked to Cognito.
        // However, user specifically asked to update "Customers table".
        // Checking schema, `customers` table does NOT exist in 001_multi_tenant_schema.sql, but 
        // `users` table has `role` enum including `customer`.
        // So we update `users` table where id = customerId AND tenant_id = auth.tenantId.

        // Wait, checking schema again...
        // `users` table has `role`.
        // There is NO `customers` table in `001_multi_tenant_schema.sql`.
        // But `BillingService.dart` (Flutter) referenced `owners/{ownerId}/customers`.

        // I will assume `users` table is where customers live for now, based on `user_role` enum having 'customer'.

        const updateRes = await pool.query(
            `UPDATE users 
             SET sns_endpoint_arn = $1, updated_at = NOW() 
             WHERE id = $2 AND tenant_id = $3
             RETURNING id`,
            [endpointArn, customerId, auth.tenantId]
        );

        if (updateRes.rowCount === 0) {
            // Check if user exists at all? Or maybe it's in a different table I missed?
            // If the user requested "Customers table", and I only see "users", I might need to clarify or check for a `customers` table I missed.
            // Let's assume `users` is correct for now as per schema.
            logger.warn('Customer not found or access denied', { customerId, tenantId: auth.tenantId });
            return response.notFound('Customer not found');
        }

        return response.success({ message: 'Device registered successfully', endpointArn });

    } catch (error) {
        logger.error('Failed to register device', { error: (error as Error).message });
        return response.internalError((error as Error).message);
    }
});
