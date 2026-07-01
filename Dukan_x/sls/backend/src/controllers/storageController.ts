// ============================================================================
// Storage Controller — S3 Signed URL Endpoints
// ============================================================================
// Provides tenant-scoped file upload/download via pre-signed S3 URLs.
// Requires Cognito auth. Tenant ID is extracted from the JWT.
// ============================================================================

import { Router, Request, Response } from 'express';
import { requireCognitoAuth } from '../middleware/cognitoAuth';
import * as storageService from '../services/storageService';
import { logger } from '../utils/logger';

const router = Router();

// All storage routes require authentication
router.use(requireCognitoAuth);

/**
 * GET /api/storage/signed-url?action=upload&path=invoices/INV-001.pdf&contentType=application/pdf
 * GET /api/storage/signed-url?action=download&path=products/img-001.jpg
 *
 * Returns a pre-signed S3 URL for the requested action.
 * The tenant directory is automatically scoped from the JWT.
 */
router.get('/signed-url', async (req: Request, res: Response) => {
    try {
        const { action, path: filePath, contentType } = req.query as Record<string, string>;

        if (!action || !filePath) {
            res.status(400).json({ error: 'Missing required params: action, path' });
            return;
        }

        if (action !== 'upload' && action !== 'download') {
            res.status(400).json({ error: 'action must be "upload" or "download"' });
            return;
        }

        if (action === 'upload' && !contentType) {
            res.status(400).json({ error: 'contentType is required for upload' });
            return;
        }

        // Tenant ID from Cognito JWT
        const tenantId = req.cognitoUser?.tenantId || req.cognitoUser?.sub;

        if (!tenantId) {
            res.status(403).json({ error: 'No tenant context in token' });
            return;
        }

        if (action === 'upload') {
            const result = await storageService.getUploadUrl(tenantId, filePath, contentType);
            res.json(result);
        } else {
            const result = await storageService.getDownloadUrl(tenantId, filePath);
            res.json(result);
        }
    } catch (error: any) {
        logger.error('Storage signed-url error', { error: error.message });
        res.status(500).json({ error: 'Failed to generate signed URL' });
    }
});

/**
 * DELETE /api/storage/file?path=invoices/INV-001.pdf
 *
 * Deletes a file from the tenant's S3 directory.
 */
router.delete('/file', async (req: Request, res: Response) => {
    try {
        const filePath = req.query.path as string;

        if (!filePath) {
            res.status(400).json({ error: 'Missing required param: path' });
            return;
        }

        const tenantId = req.cognitoUser?.tenantId || req.cognitoUser?.sub;

        if (!tenantId) {
            res.status(403).json({ error: 'No tenant context in token' });
            return;
        }

        await storageService.deleteFile(tenantId, filePath);
        res.json({ success: true, message: 'File deleted' });
    } catch (error: any) {
        logger.error('Storage delete error', { error: error.message });
        res.status(500).json({ error: 'Failed to delete file' });
    }
});

export default router;
