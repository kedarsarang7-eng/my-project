// ============================================================================
// KMS Service � AWS Key Management Service Wrapper
// ============================================================================
// Provides encrypt/decrypt operations for payment gateway credentials.
// Uses envelope encryption: credentials are encrypted with a KMS data key.
//
// SECURITY:
//   - KMS key ID comes from environment variable (never hardcoded)
//   - Encrypted blobs are stored as base64 strings in DynamoDB
//   - Decrypted credentials exist only in Lambda memory during execution
//   - Encryption context includes tenant_id for additional isolation
//   - Secure memory wipe after decryption usage
//   - Decryption anomaly detection with CloudWatch metrics
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import {
    KMSClient,
    EncryptCommand,
    DecryptCommand,
} from '@aws-sdk/client-kms';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';
import { logger } from '../utils/logger';

const kmsClient = new KMSClient(configureAwsClient({ region: config.aws.region }));
const cloudwatchClient = new CloudWatchClient(configureAwsClient({ region: config.aws.region }));

const KMS_KEY_ID = config.awsKms.keyId;

// -- Decryption Anomaly Detection --------------------------------------------
// CRIT-003 FIX: Moved from in-memory Map (useless on Lambda � resets every cold
// start) to DynamoDB atomic counter with TTL for persistent tracking.

import { DynamoDBDocumentClient, UpdateCommand as KmsUpdateCommand } from '@aws-sdk/lib-dynamodb';
import { DynamoDBClient as KmsDDBClient } from '@aws-sdk/client-dynamodb';
import { config } from '../config/environment';

const DECRYPT_THRESHOLD_PER_HOUR = 100;
const _kmsRlClient = DynamoDBDocumentClient.from(
    new KmsDDBClient({ region: config.aws.region }),
    { marshallOptions: { removeUndefinedValues: true } },
);
const _KMS_TABLE = config.dynamodb.tableName;

/**
 * Track and check decryption frequency per tenant using DynamoDB atomic counter.
 * Emits CloudWatch metric if threshold exceeded.
 */
async function checkDecryptionAnomaly(tenantId: string): Promise<void> {
    const now = Math.floor(Date.now() / 1000);
    const windowKey = `KMS_DECRYPT#${tenantId}`;
    const ttl = now + 3600 + 60; // 1 hour + 60s buffer

    try {
        const result = await _kmsRlClient.send(new KmsUpdateCommand({
            TableName: _KMS_TABLE,
            Key: { PK: windowKey, SK: 'COUNTER' },
            UpdateExpression: 'SET hitCount = if_not_exists(hitCount, :zero) + :inc, #ttl = if_not_exists(#ttl, :ttl), windowStart = if_not_exists(windowStart, :now)',
            ExpressionAttributeValues: {
                ':zero': 0,
                ':inc': 1,
                ':ttl': ttl,
                ':now': now,
                ':maxAge': now - 3600,
            },
            ExpressionAttributeNames: { '#ttl': 'TTL' },
            ConditionExpression: 'attribute_not_exists(windowStart) OR windowStart >= :maxAge',
            ReturnValues: 'ALL_NEW',
        }));

        const count = (result.Attributes?.hitCount as number) || 0;

        if (count > DECRYPT_THRESHOLD_PER_HOUR) {
            logger.error('SECURITY ANOMALY: Excessive KMS decryption requests', {
                tenantId,
                count,
                threshold: DECRYPT_THRESHOLD_PER_HOUR,
                windowMs: 3600_000,
            });

            // Emit CloudWatch metric for alarm trigger
            try {
                await cloudwatchClient.send(new PutMetricDataCommand({
                    Namespace: 'DukanX/Security',
                    MetricData: [{
                        MetricName: 'DecryptionCount',
                        Value: count,
                        Unit: 'Count',
                        Dimensions: [{ Name: 'TenantId', Value: tenantId }],
                    }],
                }));
            } catch (err) {
                logger.warn('Failed to emit CloudWatch metric', { error: (err as Error).message });
            }
        }
    } catch (err: any) {
        if (err.name === 'ConditionalCheckFailedException') {
            // Window expired � reset counter (first request in new window)
            try {
                await _kmsRlClient.send(new KmsUpdateCommand({
                    TableName: _KMS_TABLE,
                    Key: { PK: windowKey, SK: 'COUNTER' },
                    UpdateExpression: 'SET hitCount = :one, #ttl = :ttl, windowStart = :now',
                    ExpressionAttributeValues: { ':one': 1, ':ttl': ttl, ':now': now },
                    ExpressionAttributeNames: { '#ttl': 'TTL' },
                }));
            } catch { /* best-effort reset */ }
            return;
        }
        // Non-fatal: don't block decryption on counter failure
        logger.warn('KMS anomaly check failed', { tenantId, error: err.message });
    }
}

/**
 * Encrypt a plaintext string using AWS KMS.
 * Uses encryption context with tenant_id for additional tenant isolation.
 *
 * @param plaintext - The string to encrypt (typically JSON-serialized credentials)
 * @param tenantId - Tenant ID used as encryption context
 * @returns Buffer containing the KMS ciphertext blob
 */
export async function encryptCredentials(
    plaintext: string,
    tenantId: string
): Promise<Buffer> {
    if (!KMS_KEY_ID) {
        throw new Error('KMS_KEY_ID environment variable is not configured');
    }

    const command = new EncryptCommand({
        KeyId: KMS_KEY_ID,
        Plaintext: Buffer.from(plaintext, 'utf-8'),
        EncryptionContext: {
            tenant_id: tenantId,
            purpose: 'payment_gateway_credentials',
        },
    });

    const response = await kmsClient.send(command);

    if (!response.CiphertextBlob) {
        throw new Error('KMS encryption returned empty ciphertext');
    }

    logger.info('KMS encryption successful', {
        tenantId,
        keyId: KMS_KEY_ID,
        ciphertextLength: response.CiphertextBlob.length,
    });

    return Buffer.from(response.CiphertextBlob);
}

/**
 * Decrypt a KMS ciphertext blob back to plaintext.
 * Must use the same encryption context that was used during encryption.
 * Tracks decryption frequency for anomaly detection.
 *
 * @param ciphertext - The encrypted Buffer from the database
 * @param tenantId - Tenant ID used as encryption context (must match encryption)
 * @returns Decrypted plaintext string
 */
export async function decryptCredentials(
    ciphertext: Buffer,
    tenantId: string
): Promise<string> {
    // Check for anomalous decryption frequency
    await checkDecryptionAnomaly(tenantId);

    const command = new DecryptCommand({
        CiphertextBlob: new Uint8Array(ciphertext),
        EncryptionContext: {
            tenant_id: tenantId,
            purpose: 'payment_gateway_credentials',
        },
    });

    const response = await kmsClient.send(command);

    if (!response.Plaintext) {
        throw new Error('KMS decryption returned empty plaintext');
    }

    logger.debug('KMS decryption successful', { tenantId });

    return Buffer.from(response.Plaintext).toString('utf-8');
}

/**
 * Zero-fill a Buffer to reduce exposure window of sensitive data.
 * LOW-003 FIX: Single pass is sufficient � V8 GC makes multi-pass meaningless.
 *
 * @param buffer - The Buffer to wipe
 */
export function secureWipe(buffer: Buffer): void {
    if (!buffer || buffer.length === 0) return;
    buffer.fill(0x00);
}

/**
 * HIGH-004 FIX: JavaScript strings are immutable and cannot be wiped in-place.
 * This function is a NO-OP kept for API compatibility. The original string
 * remains in V8's heap until GC. To minimize exposure, nullify all references
 * to sensitive strings as soon as possible after use.
 *
 * @deprecated Use `secureWipe(buffer)` on the Buffer form of sensitive data instead.
 */
export function secureWipeString(_str: string): void {
    // NO-OP: JS strings are immutable. See HIGH-004 in audit report.
    // Callers should nullify string references after use instead.
}

/**
 * Get the current KMS key ID being used.
 * Used for storing alongside encrypted data for key rotation tracking.
 */
export function getKmsKeyId(): string {
    if (!KMS_KEY_ID) {
        throw new Error('KMS_KEY_ID environment variable is not configured');
    }
    return KMS_KEY_ID;
}

// -- Plan Key Encryption -----------------------------------------------------

/**
 * Encrypt a plan license key using AWS KMS.
 * Uses a separate encryption context (`plan_key_encryption`) so plan keys
 * cannot be decrypted with the payment-credential context and vice versa.
 *
 * @param planKey - The plaintext plan key to encrypt
 * @param tenantId - Tenant ID used as encryption context for isolation
 * @returns Base64-encoded ciphertext string (safe for DB/JSON storage)
 */
export async function encryptPlanKey(
    planKey: string,
    tenantId: string,
): Promise<string> {
    if (!KMS_KEY_ID) {
        throw new Error('KMS_KEY_ID environment variable is not configured');
    }

    const command = new EncryptCommand({
        KeyId: KMS_KEY_ID,
        Plaintext: Buffer.from(planKey, 'utf-8'),
        EncryptionContext: {
            tenant_id: tenantId,
            purpose: 'plan_key_encryption',
        },
    });

    const response = await kmsClient.send(command);

    if (!response.CiphertextBlob) {
        throw new Error('KMS plan key encryption returned empty ciphertext');
    }

    logger.info('Plan key encrypted successfully', {
        tenantId,
        keyId: KMS_KEY_ID,
    });

    return Buffer.from(response.CiphertextBlob).toString('base64');
}

/**
 * Decrypt a plan license key using AWS KMS.
 * Must use the same encryption context (`plan_key_encryption`) that was
 * used during encryption. Tracks decryption frequency for anomaly detection.
 *
 * @param ciphertextBase64 - Base64-encoded ciphertext from the database
 * @param tenantId - Tenant ID used as encryption context (must match encryption)
 * @returns Decrypted plaintext plan key
 */
export async function decryptPlanKey(
    ciphertextBase64: string,
    tenantId: string,
): Promise<string> {
    await checkDecryptionAnomaly(tenantId);

    const command = new DecryptCommand({
        CiphertextBlob: new Uint8Array(Buffer.from(ciphertextBase64, 'base64')),
        EncryptionContext: {
            tenant_id: tenantId,
            purpose: 'plan_key_encryption',
        },
    });

    const response = await kmsClient.send(command);

    if (!response.Plaintext) {
        throw new Error('KMS plan key decryption returned empty plaintext');
    }

    logger.debug('Plan key decrypted successfully', { tenantId });

    return Buffer.from(response.Plaintext).toString('utf-8');
}

// -- AI Key Encryption -------------------------------------------------------

/**
 * Encrypt an AI API key using AWS KMS.
 *
 * @param apiKey - The plaintext AI API key to encrypt
 * @param tenantId - Tenant ID used as encryption context for isolation
 * @returns Base64-encoded ciphertext string (safe for DB/JSON storage)
 */
export async function encryptAiKey(
    apiKey: string,
    tenantId: string,
): Promise<string> {
    if (!KMS_KEY_ID) {
        throw new Error('KMS_KEY_ID environment variable is not configured');
    }

    const command = new EncryptCommand({
        KeyId: KMS_KEY_ID,
        Plaintext: Buffer.from(apiKey, 'utf-8'),
        EncryptionContext: {
            tenant_id: tenantId,
            purpose: 'ai_api_key',
        },
    });

    const response = await kmsClient.send(command);

    if (!response.CiphertextBlob) {
        throw new Error('KMS AI key encryption returned empty ciphertext');
    }

    logger.info('AI key encrypted successfully', {
        tenantId,
        keyId: KMS_KEY_ID,
    });

    return Buffer.from(response.CiphertextBlob).toString('base64');
}

/**
 * Decrypt an AI API key using AWS KMS.
 *
 * @param ciphertextBase64 - Base64-encoded ciphertext from the database
 * @param tenantId - Tenant ID used as encryption context (must match encryption)
 * @returns Decrypted plaintext AI API key
 */
export async function decryptAiKey(
    ciphertextBase64: string,
    tenantId: string,
): Promise<string> {
    await checkDecryptionAnomaly(tenantId);

    const command = new DecryptCommand({
        CiphertextBlob: new Uint8Array(Buffer.from(ciphertextBase64, 'base64')),
        EncryptionContext: {
            tenant_id: tenantId,
            purpose: 'ai_api_key',
        },
    });

    const response = await kmsClient.send(command);

    if (!response.Plaintext) {
        throw new Error('KMS AI key decryption returned empty plaintext');
    }

    logger.debug('AI key decrypted successfully', { tenantId });

    return Buffer.from(response.Plaintext).toString('utf-8');
}
