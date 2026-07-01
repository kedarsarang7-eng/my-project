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
     * @returns Pre-signed PUT URL valid for 15 minutes
     *
     * Usage from Flutter:
     * ```dart
     * final url = await api.getSignedUrl(action: 'upload', path: 'invoices/INV-001.pdf');
     * await http.put(Uri.parse(url), body: fileBytes, headers: {'Content-Type': 'application/pdf'});
     * ```
     */
    async getUploadUrl(key: string, contentType: string): Promise<string> {
        const command = new PutObjectCommand({
            Bucket: s3Config.bucketName,
            Key: key,
            ContentType: contentType,
        });

        return awsGetSignedUrl(s3Client, command, {
            expiresIn: s3Config.signedUrlExpiry, // 15 minutes
        });
    }

    /**
     * Generate a pre-signed URL for downloading a file from S3.
     *
     * @param key - Full S3 key
     * @returns Pre-signed GET URL valid for 15 minutes
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
            expiresIn: s3Config.signedUrlExpiry,
        });
    }
}
