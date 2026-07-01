// ============================================================================
// Storage Service — S3 Pre-Signed URLs (Express Backend)
// ============================================================================
// Generates time-limited URLs for secure file upload/download.
// The client NEVER gets raw S3 credentials — only temporary signed URLs.
//
// Mirrors the pattern in my-backend/src/services/storage.service.ts
// but adapted for Express (not Lambda).
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
// On EC2 with an IAM Instance Profile, credentials are auto-resolved.
// No need for explicit AWS_ACCESS_KEY / AWS_SECRET_KEY.

let client: S3Client | null = null;

function getClient(): S3Client {
    if (!client) {
        client = new S3Client({ region: s3Config.region });
    }
    return client;
}

// ── Service ─────────────────────────────────────────────────────────────────

/**
 * Generate a pre-signed PUT URL for uploading a file to S3.
 *
 * @param tenantId - Business/tenant UUID (used as path prefix)
 * @param filePath - Relative path within the tenant dir (e.g., "invoices/INV-001.pdf")
 * @param contentType - MIME type (e.g., "application/pdf", "image/jpeg")
 * @returns Pre-signed PUT URL valid for 15 minutes
 */
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

/**
 * Generate a pre-signed GET URL for downloading a file from S3.
 *
 * @param tenantId - Business/tenant UUID
 * @param filePath - Relative path within the tenant dir
 * @returns Pre-signed GET URL valid for 15 minutes
 */
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

/**
 * Delete a file from S3.
 *
 * @param tenantId - Business/tenant UUID
 * @param filePath - Relative path within the tenant dir
 */
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

/**
 * Build a tenant-scoped S3 key, preventing path traversal.
 */
function buildKey(tenantId: string, filePath: string): string {
    const sanitized = filePath.replace(/\.\./g, '').replace(/^\//, '');
    return `tenants/${tenantId}/${sanitized}`;
}
