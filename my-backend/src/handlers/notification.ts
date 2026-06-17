// ============================================================================
// Lambda Handler � Push Notifications (Device Registration) (DynamoDB)
// ============================================================================
import { configureAwsClient } from '../config/aws.config';
import { SNSClient, CreatePlatformEndpointCommand } from "@aws-sdk/client-sns";
import { authorizedHandler } from '../middleware/handler-wrapper';
import { Keys, updateItem } from '../config/dynamodb.config';
import { parseBody } from '../middleware/validation';
import { registerDeviceSchema } from '../schemas';
import { logger } from '../utils/logger';
import * as response from '../utils/response';
import { config } from '../config/environment';

const snsClient = new SNSClient(configureAwsClient({ region: config.aws.region }));
const PLATFORM_APPLICATION_ARN = config.awsSns.platformApplicationArn;

/**
 * POST /notifications/register-device
 */
export const registerDevice = authorizedHandler([], async (event, _context, auth) => {
    const parsed = parseBody(registerDeviceSchema, event);
    if (!parsed.success) return parsed.error;

    const { fcmToken, platform, deviceName } = parsed.data;

    if (!PLATFORM_APPLICATION_ARN) {
        logger.error('PLATFORM_APPLICATION_ARN is not configured');
        return response.internalError('Notification service not configured');
    }

    try {
        const command = new CreatePlatformEndpointCommand({
            PlatformApplicationArn: PLATFORM_APPLICATION_ARN,
            Token: fcmToken,
            CustomUserData: JSON.stringify({
                tenantId: auth.tenantId,
                userId: auth.sub,
                platform,
                deviceName,
            })
        });

        const snsResponse = await snsClient.send(command);
        const endpointArn = snsResponse.EndpointArn;

        if (!endpointArn) {
            throw new Error('Failed to create SNS Platform Endpoint');
        }

        logger.info('SNS Endpoint Created', { endpointArn, platform });

        // Update user record in DynamoDB
        await updateItem(
            Keys.tenantPK(auth.tenantId),
            Keys.userSK(auth.sub),
            {
                updateExpression: 'SET snsEndpointArn = :arn, updatedAt = :now',
                expressionAttributeValues: {
                    ':arn': endpointArn,
                    ':now': new Date().toISOString(),
                },
            },
        );

        return response.success({ message: 'Device registered successfully', endpointArn });
    } catch (error) {
        logger.error('Failed to register device', { error: (error as Error).message });
        return response.internalError('Failed to register device for notifications');
    }
});
