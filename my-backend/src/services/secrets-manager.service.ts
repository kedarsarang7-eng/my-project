// ============================================================================
// Secrets Manager Service � AWS Secrets Manager Wrapper
// ============================================================================
// Optional alternative credential store for tenants who prefer
// per-secret storage over KMS-encrypted DB columns.
//
// Each secret is namespaced per tenant:
//   dukanx/<stage>/<tenant_id>/<secret_name>
//
// Usage is opt-in � the primary credential flow remains KMS via
// payment-config.service.ts. This service is offered for ultra-sensitive
// credentials or integrations requiring Secrets Manager.
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import {
    SecretsManagerClient,
    CreateSecretCommand,
    GetSecretValueCommand,
    UpdateSecretCommand,
    DeleteSecretCommand,
    ResourceNotFoundException,
} from '@aws-sdk/client-secrets-manager';
import { logger } from '../utils/logger';
import { AppError, NotFoundError } from '../utils/errors';
import { config } from '../config/environment';

const smClient = new SecretsManagerClient(configureAwsClient({
    region: config.aws.region,
}));

const STAGE = config.app.env || 'dev';

// -- Helpers -----------------------------------------------------------------

/**
 * Build a namespaced secret name.
 * Format: dukanx/<stage>/<tenantId>/<secretName>
 */
function buildSecretName(tenantId: string, secretName: string): string {
    return `dukanx/${STAGE}/${tenantId}/${secretName}`;
}

// -- Store Secret ------------------------------------------------------------

/**
 * Store a secret in AWS Secrets Manager.
 * If the secret already exists, it is updated.
 *
 * @param tenantId - Tenant UUID (used for namespacing)
 * @param secretName - Logical name (e.g. 'razorpay_credentials')
 * @param secretValue - JSON-serialized secret value
 */
export async function storeSecret(
    tenantId: string,
    secretName: string,
    secretValue: string,
): Promise<{ secretArn: string }> {
    const fullName = buildSecretName(tenantId, secretName);

    try {
        // Try to update existing secret first
        const updateResult = await smClient.send(new UpdateSecretCommand({
            SecretId: fullName,
            SecretString: secretValue,
        }));

        logger.info('Secret updated in Secrets Manager', {
            tenantId,
            secretName,
            arn: updateResult.ARN,
        });

        return { secretArn: updateResult.ARN || fullName };
    } catch (err) {
        if (err instanceof ResourceNotFoundException) {
            // Secret doesn't exist � create it
            const createResult = await smClient.send(new CreateSecretCommand({
                Name: fullName,
                SecretString: secretValue,
                Description: `DukanX tenant secret: ${secretName} (tenant: ${tenantId})`,
                Tags: [
                    { Key: 'service', Value: 'dukanx' },
                    { Key: 'tenant_id', Value: tenantId },
                    { Key: 'stage', Value: STAGE },
                ],
            }));

            logger.info('Secret created in Secrets Manager', {
                tenantId,
                secretName,
                arn: createResult.ARN,
            });

            return { secretArn: createResult.ARN || fullName };
        }

        logger.error('Failed to store secret', {
            tenantId,
            secretName,
            error: (err as Error).message,
        });
        throw new AppError('Failed to store secret', 500, 'SECRETS_MANAGER_ERROR');
    }
}

// -- Get Secret --------------------------------------------------------------

/**
 * Retrieve a secret from AWS Secrets Manager.
 *
 * @param tenantId - Tenant UUID
 * @param secretName - Logical name
 * @returns Decrypted secret value string
 */
export async function getSecret(
    tenantId: string,
    secretName: string,
): Promise<string> {
    const fullName = buildSecretName(tenantId, secretName);

    try {
        const result = await smClient.send(new GetSecretValueCommand({
            SecretId: fullName,
        }));

        if (!result.SecretString) {
            throw new AppError('Secret has no string value', 500, 'EMPTY_SECRET');
        }

        logger.debug('Secret retrieved from Secrets Manager', {
            tenantId,
            secretName,
        });

        return result.SecretString;
    } catch (err) {
        if (err instanceof ResourceNotFoundException) {
            throw new NotFoundError(`Secret '${secretName}' not found for tenant`);
        }
        logger.error('Failed to retrieve secret', {
            tenantId,
            secretName,
            error: (err as Error).message,
        });
        throw new AppError('Failed to retrieve secret', 500, 'SECRETS_MANAGER_ERROR');
    }
}

// -- Delete Secret -----------------------------------------------------------

/**
 * Mark a secret for deletion in AWS Secrets Manager.
 * Uses a 7-day recovery window by default.
 *
 * @param tenantId - Tenant UUID
 * @param secretName - Logical name
 */
export async function deleteSecret(
    tenantId: string,
    secretName: string,
): Promise<void> {
    const fullName = buildSecretName(tenantId, secretName);

    try {
        await smClient.send(new DeleteSecretCommand({
            SecretId: fullName,
            RecoveryWindowInDays: 7,
        }));

        logger.info('Secret marked for deletion', {
            tenantId,
            secretName,
            recoveryWindowDays: 7,
        });
    } catch (err) {
        if (err instanceof ResourceNotFoundException) {
            logger.warn('Secret not found for deletion (already deleted?)', {
                tenantId,
                secretName,
            });
            return;
        }
        logger.error('Failed to delete secret', {
            tenantId,
            secretName,
            error: (err as Error).message,
        });
        throw new AppError('Failed to delete secret', 500, 'SECRETS_MANAGER_ERROR');
    }
}
