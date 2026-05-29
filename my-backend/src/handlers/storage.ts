// ============================================================================
// Lambda Handler — Storage (S3 Signed URLs)
// ============================================================================
// Generates pre-signed URLs for secure file upload/download.
// Files are scoped to the tenant's directory in S3.
// Uses `authorizedHandler` for consistent security enforcement.
//
// SECURITY: Path traversal protection via strict path validation.
// ============================================================================

import path from 'path';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { StorageService } from '../services/storage.service';
import { parseQuery, validateUploadSize } from '../middleware/validation';
import { signedUrlSchema } from '../schemas';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { UserRole } from '../types/tenant.types';

const storageService = new StorageService();

// AUDIT FIX #7: MIME type allowlist — only allow safe file types for upload
const ALLOWED_UPLOAD_MIME_TYPES = [
    'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml',
    'application/pdf',
    'text/csv', 'text/plain',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', // .xlsx
    'application/vnd.ms-excel', // .xls
    'application/json',
];

/**
 * Sanitize and validate a file path to prevent path traversal attacks.
 * Only allows alphanumeric characters, dashes, underscores, dots, and slashes.
 * Rejects any traversal attempts including encoded sequences.
 */
function sanitizePath(rawPath: string): string {
    // 1. Decode any URL encoding first
    let decoded: string;
    try {
        decoded = decodeURIComponent(rawPath);
    } catch {
        throw new Error('Invalid file path encoding');
    }

    // 2. Normalize the path and convert backslashes
    const normalized = path.normalize(decoded).replace(/\\/g, '/');

    // 3. Reject any traversal patterns
    if (normalized.includes('..') || normalized.startsWith('/')) {
        throw new Error('Path traversal detected');
    }

    // 4. Only allow safe characters (alphanumeric, dash, underscore, dot, slash)
    if (!/^[a-zA-Z0-9\-_./]+$/.test(normalized)) {
        throw new Error('Invalid characters in file path');
    }

    // 5. Reject suspicious patterns
    if (normalized.includes('//') || normalized.startsWith('.')) {
        throw new Error('Invalid file path format');
    }

    return normalized;
}

/**
 * GET /storage/signed-url?action=upload&path=invoices/INV-001.pdf&contentType=application/pdf&maxSizeMB=10
 * GET /storage/signed-url?action=download&path=products/img-001.jpg
 */
export const getSignedUrl = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.CASHIER, UserRole.ACCOUNTANT, UserRole.CHARTERED_ACCOUNTANT],
    async (event, _context, auth) => {
    const parsed = parseQuery(signedUrlSchema, event);
    if (!parsed.success) return parsed.error;

    const { action, path: rawFilePath, contentType, maxSizeMB, contentLength } = parsed.data;

    // Security: validate request size and MIME type before generating URL
    if (action === 'upload') {
        // AUDIT FIX #7: Reject disallowed MIME types
        if (!ALLOWED_UPLOAD_MIME_TYPES.includes(contentType!)) {
            return response.badRequest(`Unsupported file type: ${contentType}. Allowed: ${ALLOWED_UPLOAD_MIME_TYPES.join(', ')}`);
        }
        const sizeCheck = validateUploadSize(event, maxSizeMB || 10);
        if (!sizeCheck.valid) {
            return response.badRequest(sizeCheck.error || 'Invalid upload size');
        }
    }

    // Security: sanitize path and scope to tenant's directory
    let sanitizedPath: string;
    try {
        sanitizedPath = sanitizePath(rawFilePath);
    } catch (err) {
        return response.badRequest((err as Error).message);
    }

    const tenantScopedPath = `tenants/${auth.tenantId}/${sanitizedPath}`;

    let url: string;

    if (action === 'upload') {
        // MEDIUM FIX: Pass contentLength for enforced size validation
        url = await storageService.getUploadUrl(tenantScopedPath, contentType!, contentLength);
        logger.info('Generated upload URL', { path: sanitizedPath, maxSizeMB: maxSizeMB || 10, contentLength });
    } else {
        url = await storageService.getDownloadUrl(tenantScopedPath);
        logger.info('Generated download URL', { path: sanitizedPath });
    }

    return response.success({
        url,
        expiresIn: 900, // 15 minutes
        path: tenantScopedPath,
        maxUploadSizeMB: action === 'upload' ? (maxSizeMB || 10) : undefined,
    });
});
