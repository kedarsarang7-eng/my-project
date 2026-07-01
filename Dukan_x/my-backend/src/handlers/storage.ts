// ============================================================================
// Lambda Handler — Storage (S3 Signed URLs)
// ============================================================================
// Generates pre-signed URLs for secure file upload/download.
// Files are scoped to the tenant's directory in S3.
// Uses `authorizedHandler` for consistent security enforcement.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { StorageService } from '../services/storage.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

const storageService = new StorageService();

/**
 * GET /storage/signed-url?action=upload&path=invoices/INV-001.pdf&contentType=application/pdf
 * GET /storage/signed-url?action=download&path=products/img-001.jpg
 */
export const getSignedUrl = authorizedHandler([], async (event, _context, auth) => {
    const params = event.queryStringParameters || {};
    const { action, path: filePath, contentType } = params;

    if (!action || !filePath) {
        return response.badRequest('Missing required params: action, path');
    }

    if (action !== 'upload' && action !== 'download') {
        return response.badRequest('action must be "upload" or "download"');
    }

    if (action === 'upload' && !contentType) {
        return response.badRequest('contentType is required for upload');
    }

    // Security: scope the path to the tenant's directory
    // Prevents path traversal attacks (e.g., ../../other-tenant/secret.pdf)
    const sanitizedPath = filePath.replace(/\.\./g, '').replace(/^\//, '');
    const tenantScopedPath = `tenants/${auth.tenantId}/${sanitizedPath}`;

    let url: string;

    if (action === 'upload') {
        url = await storageService.getUploadUrl(tenantScopedPath, contentType!);
        logger.info('Generated upload URL', { tenantId: auth.tenantId, path: sanitizedPath });
    } else {
        url = await storageService.getDownloadUrl(tenantScopedPath);
        logger.info('Generated download URL', { tenantId: auth.tenantId, path: sanitizedPath });
    }

    return response.success({
        url,
        expiresIn: 900, // 15 minutes
        path: tenantScopedPath,
    });
});
