// ============================================================================
// Secrets Manager Migration Utility
// ============================================================================
// Safely manages secrets stored in AWS Secrets Manager instead of environment variables.
//
// Problem: API keys and secrets in environment variables are visible in logs
// and CloudFormation, creating security risks.
//
// Solution:
//   1. Store secrets in AWS Secrets Manager (encrypted at rest)
//   2. Cache secrets in memory with TTL (1 hour default)
//   3. Rotate secrets without redeploying Lambda
//   4. Audit all secret access via CloudTrail
//
// Benefits:
//   - Secrets never appear in logs, CloudFormation, or environment
//   - Centralized secret management and rotation
//   - Fine-grained IAM permissions per secret
//   - Audit trail for compliance
//
// MIGRATION PATH:
//   1. Create secrets in AWS Secrets Manager console
//   2. Replace config.extendedSecrets.genericSecret with getSecret('secret-name')
//   3. Monitor rotation via CloudTrail
// ============================================================================

import {
    SecretsManagerClient,
    GetSecretValueCommand,
    RotateSecretCommand,
} from '@aws-sdk/client-secrets-manager';
import { logger } from './logger';
import { config } from '../config/environment';

interface CachedSecret {
    value: string;
    expiresAt: number;
}

let secretsClient: SecretsManagerClient;
const secretCache = new Map<string, CachedSecret>();
const CACHE_TTL_MINUTES = 60; // Cache secrets for 1 hour

function getSecretsClient(): SecretsManagerClient {
    if (!secretsClient) {
        secretsClient = new SecretsManagerClient({
            region: config.aws.region,
        });
    }
    return secretsClient;
}

/**
 * Get a secret from AWS Secrets Manager (with caching).
 * 
 * Usage:
 *   const apiKey = await getSecret('my-internal-api-key');
 *   const dbPassword = await getSecret('prod/database-password');
 */
export async function getSecret(secretName: string): Promise<string> {
    // Check cache first
    const cached = secretCache.get(secretName);
    if (cached && cached.expiresAt > Date.now()) {
        logger.debug('[SecretsManager] Cache hit', { secretName });
        return cached.value;
    }

    try {
        logger.info('[SecretsManager] Fetching secret', { secretName });

        const client = getSecretsClient();
        const response = await client.send(
            new GetSecretValueCommand({
                SecretId: secretName,
            })
        );

        const secretValue = response.SecretString || (response.SecretBinary && 
            Buffer.from(response.SecretBinary).toString('utf-8'));
        if (!secretValue) {
            throw new Error(`Secret ${secretName} is empty`);
        }

        // Cache the secret
        const expiresAt = Date.now() + CACHE_TTL_MINUTES * 60 * 1000;
        secretCache.set(secretName, {
            value: secretValue,
            expiresAt,
        });

        logger.info('[SecretsManager] Secret retrieved and cached', { secretName });
        return secretValue;
    } catch (error) {
        logger.error('[SecretsManager] Failed to get secret', {
            secretName,
            error: (error as Error).message,
        });

        // Fallback to environment variable as last resort (for backward compatibility)
        const envKey = secretName.toUpperCase().replace(/-/g, '_');
        const envValue = process.env[envKey];
        if (envValue) {
            logger.warn('[SecretsManager] Falling back to environment variable', {
                secretName,
                envKey,
            });
            return envValue;
        }

        throw error;
    }
}

/**
 * Get a JSON secret from Secrets Manager (e.g., API credentials object).
 * 
 * Usage:
 *   const credentials = await getJsonSecret('payment-gateway-credentials');
 *   console.log(credentials.api_key, credentials.api_secret);
 */
export async function getJsonSecret<T = Record<string, any>>(
    secretName: string,
): Promise<T> {
    const value = await getSecret(secretName);

    try {
        return JSON.parse(value);
    } catch (error) {
        logger.error('[SecretsManager] Failed to parse JSON secret', {
            secretName,
            error: (error as Error).message,
        });
        throw new Error(`Secret ${secretName} is not valid JSON`);
    }
}

/**
 * Clear the secret cache (useful for testing or manual rotation).
 */
export function clearSecretCache(secretName?: string): void {
    if (secretName) {
        secretCache.delete(secretName);
        logger.info('[SecretsManager] Secret cache cleared', { secretName });
    } else {
        secretCache.clear();
        logger.info('[SecretsManager] All secret caches cleared');
    }
}

/**
 * Initiate a secret rotation in AWS Secrets Manager.
 * (Usually triggered by Lambda rotation function, not application code)
 */
export async function initiateSecretRotation(secretName: string): Promise<string> {
    try {
        logger.info('[SecretsManager] Initiating secret rotation', { secretName });

        const client = getSecretsClient();
        const response = await client.send(
            new RotateSecretCommand({
                SecretId: secretName,
            })
        );

        // Clear cache on rotation
        clearSecretCache(secretName);

        logger.info('[SecretsManager] Secret rotation initiated', {
            secretName,
            versionId: response.VersionId,
        });

        return response.VersionId || '';
    } catch (error) {
        logger.error('[SecretsManager] Failed to initiate rotation', {
            secretName,
            error: (error as Error).message,
        });
        throw error;
    }
}

/**
 * Get all cached secrets (for monitoring/debugging).
 */
export function getCachedSecretNames(): string[] {
    return Array.from(secretCache.keys());
}

/**
 * Validate that a required secret exists (run on Lambda startup).
 */
export async function validateRequiredSecrets(requiredSecrets: string[]): Promise<void> {
    logger.info('[SecretsManager] Validating required secrets', {
        count: requiredSecrets.length,
    });

    const results = await Promise.allSettled(
        requiredSecrets.map(name => getSecret(name))
    );

    const failed = requiredSecrets.filter((name, i) => results[i].status === 'rejected');
    if (failed.length > 0) {
        throw new Error(`Missing required secrets: ${failed.join(', ')}`);
    }

    logger.info('[SecretsManager] All required secrets validated');
}

// ============================================================================
// INTEGRATION EXAMPLES
// ============================================================================

/**
 * Example: Migration from environment variables to Secrets Manager
 *
 * BEFORE:
 *   const apiKey = config.extendedSecrets.internalApiKey;  // Visible in logs!
 *
 * AFTER:
 *   const apiKey = await getSecret('internal-api-key');
 *
 * SETUP:
 *   1. Create secret in AWS Secrets Manager:
 *      aws secretsmanager create-secret --name internal-api-key --secret-string "your-key-here"
 *
 *   2. Add IAM permission to Lambda role:
 *      {
 *        "Effect": "Allow",
 *        "Action": "secretsmanager:GetSecretValue",
 *        "Resource": "arn:aws:secretsmanager:*:*:secret:internal-api-key*"
 *      }
 *
 *   3. On Lambda startup:
 *      await validateRequiredSecrets([
 *        'internal-api-key',
 *        'payment-gateway-credentials',
 *        'email-service-key'
 *      ]);
 *
 *   4. In handlers:
 *      const apiKey = await getSecret('internal-api-key');
 */
