// ============================================
// Admin DynamoDB Controller — Express Wrappers for Lambda Logic
// ============================================
// Exposes the DynamoDB-backed license key operations as Express routes
// so the Admin Panel can reach them through the same Express server.
//
// Routes:
//   GET  /api/admin/stats              — License stats from DynamoDB
//   POST /api/admin/generate-key       — Generate a new license key
//   POST /api/admin/revoke/:license_key — Ban/revoke/reactivate a key
// ============================================

import { Router, Request, Response } from 'express';
import { requireCognitoAuth as requireAuth, requireCognitoAdmin as requireAdmin } from '../middleware/cognitoAuth';
import {
    generateLicenseKey,
    getLicenseKey,
    getLicenseStats,
    listLicenseKeys,
    updateLicenseStatus,
    resetPrimaryHwid,
    addAllowedHwid,
    removeAllowedHwid,
    getDeviceList,
    DynamoLicenseStatus,
    VALID_BUSINESS_TYPES,
    BusinessType,
} from '../services/dynamoLicenseService';
import { logger } from '../utils/logger';

const router = Router();

// All routes require Cognito admin auth
router.use(requireAuth, requireAdmin);

// ---- GET /api/admin/stats ----
router.get('/stats', async (req: Request, res: Response) => {
    try {
        const stats = await getLicenseStats();
        const recentResult = await listLicenseKeys({ limit: 50 });

        res.json({
            stats: {
                total_licenses: stats.total,
                new_licenses: stats.new,
                active_licenses: stats.active,
                inactive_licenses: stats.inactive,
                banned_licenses: stats.banned,
            },
            recent_licenses: recentResult.items.map((lic) => ({
                license_key: lic.license_key,
                status: lic.status,
                business_type: lic.business_type || 'other',
                tier: lic.tier,
                client_name: lic.client_name,
                hwid: lic.hwid ? lic.hwid.substring(0, 12) + '...' : null,
                hwid_full: lic.hwid || null,
                allowed_hwids: lic.allowed_hwids || [],
                max_devices: lic.max_devices,
                activation_date: lic.activation_date,
                created_at: lic.created_at,
                expires_at: lic.expires_at,
            })),
        });
    } catch (error: any) {
        logger.error('Admin stats error', { error: error.message });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

// ---- POST /api/admin/generate-key ----
router.post('/generate-key', async (req: Request, res: Response) => {
    try {
        const { business_type, client_name, client_email, tier, license_type, max_devices, feature_flags, expires_at, notes } = req.body;

        // Validate business_type (REQUIRED)
        if (!business_type || !VALID_BUSINESS_TYPES.includes(business_type as BusinessType)) {
            res.status(400).json({
                error: `business_type is required. Must be one of: ${VALID_BUSINESS_TYPES.join(', ')}`,
            });
            return;
        }

        // Validate tier
        const validTiers = ['basic', 'pro', 'enterprise'];
        if (tier && !validTiers.includes(tier)) {
            res.status(400).json({ error: `Invalid tier. Must be one of: ${validTiers.join(', ')}` });
            return;
        }

        // Validate license_type
        const validTypes = ['trial', 'standard', 'lifetime'];
        if (license_type && !validTypes.includes(license_type)) {
            res.status(400).json({ error: `Invalid license_type. Must be one of: ${validTypes.join(', ')}` });
            return;
        }

        const license = await generateLicenseKey({
            business_type: business_type as BusinessType,
            client_name,
            client_email,
            tier,
            license_type,
            max_devices,
            feature_flags,
            expires_at,
            notes,
            issued_by: req.user!.sub,
        });

        logger.info('License key generated via admin controller', {
            key: license.license_key,
            business_type: license.business_type,
            admin: req.user!.email,
        });

        res.status(201).json({
            message: 'License key generated successfully',
            license_key: license.license_key,
            status: license.status,
            business_type: license.business_type,
            tier: license.tier,
            license_type: license.license_type,
            created_at: license.created_at,
            expires_at: license.expires_at,
        });
    } catch (error: any) {
        logger.error('Generate key error', { error: error.message });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

// ---- POST /api/admin/revoke/:license_key ----
router.post('/revoke/:license_key', async (req: Request, res: Response) => {
    try {
        const licenseKey = decodeURIComponent(req.params.license_key);
        const { action, reason } = req.body;

        // Validate action
        const validActions = ['ban', 'revoke', 'reactivate'];
        if (!action || !validActions.includes(action)) {
            res.status(400).json({ error: 'Invalid action. Must be: ban, revoke, or reactivate' });
            return;
        }

        // Check key exists
        const existing = await getLicenseKey(licenseKey);
        if (!existing) {
            res.status(404).json({ error: 'License key not found', code: 'NOT_FOUND' });
            return;
        }

        // Map action to DynamoDB status
        const statusMap: Record<string, DynamoLicenseStatus> = {
            ban: 'BANNED',
            revoke: 'INACTIVE',
            reactivate: 'ACTIVE',
        };
        const newStatus = statusMap[action];

        const updated = await updateLicenseStatus(licenseKey, newStatus, reason);

        logger.info('License status changed via admin controller', {
            license_key: licenseKey,
            action,
            new_status: newStatus,
            admin: req.user!.email,
        });

        res.json({
            message: `License ${action === 'reactivate' ? 'reactivated' : action === 'ban' ? 'banned' : 'revoked'} successfully`,
            license_key: licenseKey,
            status: updated?.status || newStatus,
            revoked_at: updated?.revoked_at,
        });
    } catch (error: any) {
        logger.error('Revoke license error', { error: error.message });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

// ---- GET /api/admin/:license_key/devices ----
router.get('/:license_key/devices', async (req: Request, res: Response) => {
    try {
        const licenseKey = decodeURIComponent(req.params.license_key);
        const devices = await getDeviceList(licenseKey);

        if (!devices) {
            res.status(404).json({ error: 'License key not found', code: 'NOT_FOUND' });
            return;
        }

        res.json(devices);
    } catch (error: any) {
        logger.error('Get devices error', { error: error.message });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

// ---- POST /api/admin/:license_key/reset-hwid ----
router.post('/:license_key/reset-hwid', async (req: Request, res: Response) => {
    try {
        const licenseKey = decodeURIComponent(req.params.license_key);
        const updated = await resetPrimaryHwid(licenseKey);

        if (!updated) {
            res.status(404).json({ error: 'License key not found', code: 'NOT_FOUND' });
            return;
        }

        logger.info('HWID reset via admin', {
            license_key: licenseKey,
            admin: req.user!.email,
        });

        res.json({
            message: 'Primary HWID reset. License is now in NEW state and can be activated on a new machine.',
            license_key: licenseKey,
            status: updated.status,
        });
    } catch (error: any) {
        logger.error('Reset HWID error', { error: error.message });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

// ---- POST /api/admin/:license_key/add-hwid ----
router.post('/:license_key/add-hwid', async (req: Request, res: Response) => {
    try {
        const licenseKey = decodeURIComponent(req.params.license_key);
        const { hwid, device_name } = req.body;

        if (!hwid || typeof hwid !== 'string' || hwid.length < 16) {
            res.status(400).json({ error: 'hwid is required and must be at least 16 characters' });
            return;
        }

        const result = await addAllowedHwid(licenseKey, hwid, device_name);

        if (!result.success) {
            res.status(400).json({ error: result.message });
            return;
        }

        logger.info('Allowed HWID added via admin', {
            license_key: licenseKey,
            hwid: hwid.substring(0, 12) + '...',
            admin: req.user!.email,
        });

        res.json({
            message: result.message,
            devices: {
                primary_hwid: result.license?.hwid || null,
                allowed_hwids: result.license?.allowed_hwids || [],
                max_devices: result.license?.max_devices || 1,
            },
        });
    } catch (error: any) {
        logger.error('Add HWID error', { error: error.message });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

// ---- DELETE /api/admin/:license_key/hwid/:hwid ----
router.delete('/:license_key/hwid/:hwid', async (req: Request, res: Response) => {
    try {
        const licenseKey = decodeURIComponent(req.params.license_key);
        const hwid = decodeURIComponent(req.params.hwid);

        const result = await removeAllowedHwid(licenseKey, hwid);

        if (!result.success) {
            res.status(400).json({ error: result.message });
            return;
        }

        logger.info('Allowed HWID removed via admin', {
            license_key: licenseKey,
            hwid: hwid.substring(0, 12) + '...',
            admin: req.user!.email,
        });

        res.json({ message: result.message });
    } catch (error: any) {
        logger.error('Remove HWID error', { error: error.message });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

export default router;
