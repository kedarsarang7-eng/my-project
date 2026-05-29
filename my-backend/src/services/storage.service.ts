// ============================================================================
// Storage Service — S3 Pre-Signed URLs
// ============================================================================
// Generates time-limited URLs for secure file upload/download.
// The client NEVER gets raw S3 credentials — only temporary signed URLs.
// ============================================================================

import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl as awsGetSignedUrl } from '@aws-sdk/s3-request-presigner';
import { s3Config } from '../config/aws.config';

const s3Client = new S3Client({ region: s3Config.region });

export class StorageService {

    /**
     * Generate a pre-signed URL for uploading a file to S3.
     *
     * @param key - Full S3 key (e.g., "tenants/uuid/invoices/INV-001.pdf")
     * @param contentType - MIME type (e.g., "application/pdf", "image/jpeg")
     * @param contentLength - File size in bytes (MEDIUM FIX: enforced to prevent abuse)
     * @returns Pre-signed PUT URL valid for 5 minutes (HIGH FIX: reduced from 15 min)
     *
     * Usage from Flutter:
     * ```dart
     * final url = await api.getSignedUrl(action: 'upload', path: 'invoices/INV-001.pdf', fileSizeBytes);
     * await http.put(Uri.parse(url), body: fileBytes, headers: {'Content-Type': 'application/pdf'});
     * ```
     */
    async getUploadUrl(key: string, contentType: string, contentLength?: number): Promise<string> {
        // MEDIUM FIX: Validate content length
        const MAX_FILE_SIZE = 100 * 1024 * 1024; // 100MB max
        if (contentLength && contentLength > MAX_FILE_SIZE) {
            throw new Error(`File size ${contentLength} exceeds maximum allowed size of ${MAX_FILE_SIZE} bytes (100MB)`);
        }

        const command = new PutObjectCommand({
            Bucket: s3Config.bucketName,
            Key: key,
            ContentType: contentType,
            // MEDIUM FIX: Enforce Content-Length if provided
            ...(contentLength ? { ContentLength: contentLength } : {}),
        });

        return awsGetSignedUrl(s3Client, command, {
            expiresIn: s3Config.signedUrlExpiry, // 5 minutes (HIGH FIX)
        });
    }

    /**
     * Generate a pre-signed URL for downloading a file from S3.
     *
     * @param key - Full S3 key
     * @returns Pre-signed GET URL valid for 5 minutes (HIGH FIX: reduced from 15 min)
     *
     * Usage from Flutter:
     * ```dart
     * final url = await api.getSignedUrl(action: 'download', path: 'invoices/INV-001.pdf');
     * // Use url directly in Image.network() or launch in browser
     * ```
     */
    async getDownloadUrl(key: string): Promise<string> {
        const command = new GetObjectCommand({
            Bucket: s3Config.bucketName,
            Key: key,
        });

        return awsGetSignedUrl(s3Client, command, {
            expiresIn: s3Config.signedUrlExpiry, // 5 minutes (HIGH FIX)
        });
    }
}
