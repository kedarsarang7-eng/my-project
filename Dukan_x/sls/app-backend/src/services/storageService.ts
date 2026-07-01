// ============================================================================
// Storage Service — S3 Pre-Signed URLs (App Backend)
// ============================================================================
// Generates time-limited URLs for secure file upload/download.
// The client NEVER gets raw S3 credentials — only temporary signed URLs.
//
// Identical to sls/backend/src/services/storageService.ts
// Both Express backends share the same S3 bucket.
// ============================================================================

import { S3Client, GetObjectCommand, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { logger } from '../utils/logger';

// ── Config ──────────────────────────────────────────────────────────────────

const s3Config = {
    bucketName: process.env.S3_BUCKET_NAME || 'dukanx-tenant-storage',
    region: process.env.S3_REGION || process.env.AWS_REGION || 'ap-south-1',
    signedUrlExpiry: 900, // 15 minutes
};

// ── S3 Client (Singleton) ───────────────────────────────────────────────────

let client: S3Client | null = null;

function getClient(): S3Client {
    if (!client) {
        client = new S3Client({ region: s3Config.region });
    }
    return client;
}

// ── Service ─────────────────────────────────────────────────────────────────

export async function getUploadUrl(
    tenantId: string,
    filePath: string,
    contentType: string,
): Promise<{ url: string; key: string; expiresIn: number }> {
    const key = buildKey(tenantId, filePath);

    const command = new PutObjectCommand({
        Bucket: s3Config.bucketName,
        Key: key,
        ContentType: contentType,
    });

    const url = await getSignedUrl(getClient(), command, {
        expiresIn: s3Config.signedUrlExpiry,
    });

    logger.info('Generated S3 upload URL', { tenantId, key });
    return { url, key, expiresIn: s3Config.signedUrlExpiry };
}

export async function getDownloadUrl(
    tenantId: string,
    filePath: string,
): Promise<{ url: string; key: string; expiresIn: number }> {
    const key = buildKey(tenantId, filePath);

    const command = new GetObjectCommand({
        Bucket: s3Config.bucketName,
        Key: key,
    });

    const url = await getSignedUrl(getClient(), command, {
        expiresIn: s3Config.signedUrlExpiry,
    });

    logger.info('Generated S3 download URL', { tenantId, key });
    return { url, key, expiresIn: s3Config.signedUrlExpiry };
}

export async function deleteFile(tenantId: string, filePath: string): Promise<void> {
    const key = buildKey(tenantId, filePath);

    const command = new DeleteObjectCommand({
        Bucket: s3Config.bucketName,
        Key: key,
    });

    await getClient().send(command);
    logger.info('Deleted S3 object', { tenantId, key });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function buildKey(tenantId: string, filePath: string): string {
    const sanitized = filePath.replace(/\.\./g, '').replace(/^\//, '');
    return `tenants/${tenantId}/${sanitized}`;
}
