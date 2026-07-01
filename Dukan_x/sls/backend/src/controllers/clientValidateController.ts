// ============================================
// Client Validate Controller — DynamoDB-backed License Validation
// ============================================
// This is the client-facing Express endpoint that wraps the DynamoDB
// validateAndBindHwid logic. Desktop/web clients call this to validate
// their license key + HWID and receive business_type for module gating.
//
// Routes:
//   POST /api/client/validate   — Validate license key + bind HWID
//   POST /api/client/heartbeat  — Keep session alive (update last_validated_at)
//
// NO authentication required — called by desktop client before login.
// Rate-limited by generalRateLimiter in app.ts.

import { Router, Request, Response } from 'express';
import {
    validateAndBindHwid,
    getLicenseKey,
} from '../services/dynamoLicenseService';
import { logger } from '../utils/logger';

const router = Router();

// ---- POST /api/client/validate ----
router.post('/validate', async (req: Request, res: Response) => {
    const ip = req.ip || req.socket.remoteAddress || 'unknown';

    try {
        const { license_key, machine_hwid, hwid, device_name, os_info } = req.body;

        // Support both field names (machine_hwid and hwid)
        const resolvedHwid = machine_hwid || hwid;

        // ---- Validate Input ----
        if (!license_key || typeof license_key !== 'string') {
            res.status(400).json({ valid: false, error: 'license_key is required', code: 'MISSING_KEY' });
            return;
        }

        if (!resolvedHwid || typeof resolvedHwid !== 'string') {
            res.status(400).json({ valid: false, error: 'machine_hwid is required', code: 'MISSING_HWID' });
            return;
        }

        // Validate key format: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
        const keyRegex = /^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$/;
        if (!keyRegex.test(license_key)) {
            res.status(400).json({
                valid: false,
                error: 'Invalid license key format. Expected: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
                code: 'INVALID_FORMAT',
            });
            return;
        }

        // Validate HWID minimum length
        if (resolvedHwid.length < 16) {
            res.status(400).json({ valid: false, error: 'HWID must be at least 16 characters', code: 'INVALID_HWID' });
            return;
        }

        // ---- Validate & Bind ----
        const result = await validateAndBindHwid(license_key, resolvedHwid);

        logger.info('Client license validation', {
            license_key: license_key.substring(0, 10) + '...',
            success: result.success,
            ip,
            device_name,
        });

        if (!result.success) {
            // Determine appropriate error code
            let code = 'VALIDATION_FAILED';
            if (result.message.includes('Invalid Machine')) code = 'HWID_MISMATCH';
            else if (result.message.includes('banned')) code = 'LICENSE_BANNED';
            else if (result.message.includes('deactivated')) code = 'LICENSE_INACTIVE';
            else if (result.message.includes('expired')) code = 'LICENSE_EXPIRED';
            else if (result.message.includes('Invalid license')) code = 'INVALID_KEY';

            res.status(403).json({ valid: false, error: result.message, code });
            return;
        }

        // ---- Success Response ----
        res.json({
            valid: true,
            message: result.message,
            license: {
                business_type: result.license!.business_type,
                tier: result.license!.tier,
                license_type: result.license!.license_type,
                feature_flags: result.license!.feature_flags,
                expires_at: result.license!.expires_at,
                activation_date: result.license!.activation_date,
                max_devices: result.license!.max_devices,
            },
        });

    } catch (error: any) {
        if (error instanceof SyntaxError) {
            res.status(400).json({ valid: false, error: 'Invalid JSON in request body', code: 'INVALID_JSON' });
            return;
        }
        logger.error('Client validate error', { error: error.message, ip });
        res.status(500).json({ valid: false, error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

// ---- POST /api/client/heartbeat ----
router.post('/heartbeat', async (req: Request, res: Response) => {
    try {
        const { license_key, machine_hwid, hwid } = req.body;
        const resolvedHwid = machine_hwid || hwid;

        if (!license_key || !resolvedHwid) {
            res.status(400).json({ error: 'license_key and machine_hwid are required' });
            return;
        }

        // Quick validation — just check the key exists and HWID matches
        const license = await getLicenseKey(license_key);
        if (!license) {
            res.status(404).json({ error: 'License not found', code: 'INVALID_KEY' });
            return;
        }

        if (license.status !== 'ACTIVE') {
            res.status(403).json({ error: `License is ${license.status}`, code: 'LICENSE_INACTIVE' });
            return;
        }

        const allowedHwids = license.allowed_hwids || [];
        const isPrimary = license.hwid === resolvedHwid;
        const isAllowed = allowedHwids.includes(resolvedHwid);

        if (!isPrimary && !isAllowed) {
            res.status(403).json({ error: 'Device mismatch', code: 'HWID_MISMATCH' });
            return;
        }

        res.json({ alive: true, message: 'Heartbeat OK' });
    } catch (error: any) {
        logger.error('Client heartbeat error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
