// ============================================
// License Controller — CRUD + Status Management
// ============================================

import { Router, Request, Response } from 'express';
import { requireCognitoAuth as requireAuth, requireCognitoAdmin as requireAdmin } from '../middleware/cognitoAuth';
import * as licenseService from '../services/licenseService';
import {
    createLicenseSchema, updateLicenseSchema, paginationSchema, validateBody
} from '../utils/validators';
import { logger } from '../utils/logger';

const router = Router();

// All routes require authentication
router.use(requireAuth);

/**
 * GET /api/licenses
 * List all licenses with pagination and filters.
 */
router.get('/', requireAdmin, async (req: Request, res: Response) => {
    try {
        const params = validateBody(paginationSchema, req.query);
        const result = await licenseService.listLicenses(params);
        res.json(result);
    } catch (error: any) {
        if (error.name === 'ZodError') {
            res.status(400).json({ error: 'Invalid query parameters', details: error.errors });
            return;
        }
        logger.error('List licenses error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /api/licenses/:id
 * Get a single license by ID.
 */
router.get('/:id', requireAdmin, async (req: Request, res: Response) => {
    try {
        const license = await licenseService.getLicenseById(req.params.id);
        if (!license) {
            res.status(404).json({ error: 'License not found', code: 'LICENSE_NOT_FOUND' });
            return;
        }
        res.json(license);
    } catch (error: any) {
        logger.error('Get license error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /api/licenses
 * Generate a new license key.
 */
router.post('/', requireAdmin, async (req: Request, res: Response) => {
    try {
        const data = validateBody(createLicenseSchema, req.body);
        const license = await licenseService.createLicense(data as any, req.user!.sub);
        res.status(201).json(license);
    } catch (error: any) {
        if (error.name === 'ZodError') {
            res.status(400).json({ error: 'Validation failed', details: error.errors });
            return;
        }
        logger.error('Create license error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * PUT /api/licenses/:id
 * Update license properties.
 */
router.put('/:id', requireAdmin, async (req: Request, res: Response) => {
    try {
        const data = validateBody(updateLicenseSchema, req.body);
        const license = await licenseService.updateLicense(req.params.id, data as any);
        if (!license) {
            res.status(404).json({ error: 'License not found', code: 'LICENSE_NOT_FOUND' });
            return;
        }
        res.json(license);
    } catch (error: any) {
        if (error.name === 'ZodError') {
            res.status(400).json({ error: 'Validation failed', details: error.errors });
            return;
        }
        logger.error('Update license error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * DELETE /api/licenses/:id
 * Soft-delete a license.
 */
router.delete('/:id', requireAdmin, async (req: Request, res: Response) => {
    try {
        const deleted = await licenseService.deleteLicense(req.params.id);
        if (!deleted) {
            res.status(404).json({ error: 'License not found', code: 'LICENSE_NOT_FOUND' });
            return;
        }
        res.json({ message: 'License deleted successfully' });
    } catch (error: any) {
        logger.error('Delete license error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ---- Status Control ----

/**
 * POST /api/licenses/:id/suspend
 */
router.post('/:id/suspend', requireAdmin, async (req: Request, res: Response) => {
    try {
        const license = await licenseService.changeStatus(req.params.id, 'suspended');
        if (!license) {
            res.status(404).json({ error: 'License not found' });
            return;
        }
        res.json({ message: 'License suspended', license });
    } catch (error: any) {
        logger.error('Suspend license error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /api/licenses/:id/ban
 */
router.post('/:id/ban', requireAdmin, async (req: Request, res: Response) => {
    try {
        const license = await licenseService.changeStatus(req.params.id, 'banned');
        if (!license) {
            res.status(404).json({ error: 'License not found' });
            return;
        }
        res.json({ message: 'License banned', license });
    } catch (error: any) {
        logger.error('Ban license error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /api/licenses/:id/reactivate
 */
router.post('/:id/reactivate', requireAdmin, async (req: Request, res: Response) => {
    try {
        const license = await licenseService.changeStatus(req.params.id, 'active');
        if (!license) {
            res.status(404).json({ error: 'License not found' });
            return;
        }
        res.json({ message: 'License reactivated', license });
    } catch (error: any) {
        logger.error('Reactivate license error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
