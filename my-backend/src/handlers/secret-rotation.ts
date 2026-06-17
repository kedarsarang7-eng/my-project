import { configureAwsClient } from '../config/aws.config';
import { SecretsManagerClient, PutSecretValueCommand, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { randomBytes } from 'crypto';
import { logger } from '../utils/logger';
import { config } from '../config/environment';

const smClient = new SecretsManagerClient(configureAwsClient({ region: config.aws.region }));

export const rotateInternalSecret = async (event: any): Promise<void> => {
    logger.info('Starting scheduled INTERNAL_API_SECRET rotation');

    try {
        const secretId = config.extendedSecrets.internalSecretArn;
        
        if (!secretId) {
            throw new Error('INTERNAL_SECRET_ARN environment variable not configured.');
        }

        // Generate a new secure 32-byte hex API secret
        const newSecretValue = randomBytes(32).toString('hex');

        // Create the new payload format (Assuming JSON payload for consistency)
        const newSecretPayload = JSON.stringify({
            INTERNAL_API_SECRET: newSecretValue
        });

        const putCommand = new PutSecretValueCommand({
            SecretId: secretId,
            SecretString: newSecretPayload,
            // Automatically adds a new version, retaining the old one briefly if needed
        });

        await smClient.send(putCommand);

        logger.info('Successfully rotated INTERNAL_API_SECRET', { secretId });
    } catch (err) {
        logger.error('Failed to rotate INTERNAL_API_SECRET', { error: (err as Error).message });
        throw err;
    }
};
