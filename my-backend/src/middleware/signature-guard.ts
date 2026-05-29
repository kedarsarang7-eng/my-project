import { APIGatewayProxyEventV2 } from 'aws-lambda';
import * as crypto from 'crypto';
import { AuthError, AppError } from '../utils/errors';
import { logger } from '../utils/logger';
import { Keys, getItem, putItem } from '../config/dynamodb.config';

/**
 * Validates asymmetric request signatures for sensitive financial transactions.
 */
export async function validateRequestSignature(event: APIGatewayProxyEventV2, tenantId: string): Promise<void> {
    const signature = event.headers?.['x-request-signature'];
    const timestampStr = event.headers?.['x-request-timestamp'];
    const nonce = event.headers?.['x-nonce'];

    if (!signature || !timestampStr || !nonce) {
        throw new AppError('Missing required signature headers for sensitive transaction.', 401, 'SIGNATURE_MISSING');
    }

    const timestamp = parseInt(timestampStr, 10);
    const now = Math.floor(Date.now() / 1000);

    if (Math.abs(now - timestamp) > 300) {
        throw new AppError('Request expired or timestamp invalid.', 401, 'SIGNATURE_EXPIRED');
    }

    // Nonce replay protection via DynamoDB with TTL
    const nonceKey = `NONCE#${tenantId}:${nonce}`;
    const existing = await getItem(nonceKey, 'META');
    if (existing) {
        throw new AppError('Replay attack detected: duplicate nonce.', 401, 'SIGNATURE_REPLAY');
    }
    await putItem({
        PK: nonceKey, SK: 'META',
        entityType: 'NONCE', tenantId, nonce,
        createdAt: new Date().toISOString(),
        ttl: Math.floor(Date.now() / 1000) + 300, // 5 min TTL
    });

    // Reconstruct payload
    const bodyString = event.body || '';
    const payloadToSign = `${event.requestContext?.http?.method || ''}:${event.rawPath}:${timestamp}:${nonce}:${bodyString}`;

    // Fetch tenant's public key from DynamoDB
    const tenant = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), Keys.tenantProfileSK());
    if (!tenant) throw new AuthError('Tenant not found.');

    const publicKeyPem = tenant.settings?.clientPublicKey;
    if (!publicKeyPem) {
        logger.warn('Tenant missing clientPublicKey', { tenantId });
        throw new AppError('Client signature key not configured.', 403, 'SIGNATURE_KEY_MISSING');
    }

    try {
        const isVerified = crypto.verify('SHA256', Buffer.from(payloadToSign), { key: publicKeyPem, format: 'pem', type: 'spki' }, Buffer.from(signature, 'base64'));
        if (!isVerified) {
            logger.error('Signature verification failed', { tenantId, nonce });
            throw new AppError('Invalid request signature.', 401, 'SIGNATURE_INVALID');
        }
    } catch (err) {
        logger.error('Signature verification error', { error: (err as Error).message, tenantId });
        throw new AppError('Signature verification failed.', 401, 'SIGNATURE_FAILED');
    }
}
