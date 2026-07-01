// ============================================
// Validate Controller — Client-Facing License Validation
// ============================================
// This is THE critical endpoint. Desktop/web clients call this
// to check if a license key is valid. It handles:
// 1. Key lookup (Redis cache → DB fallback)
// 2. Status & expiry checks
// 3. HWID binding / device limit enforcement
// 4. Geo-fencing
// 5. Session creation (floating licenses)
// 6. Audit logging

import { Router, Request, Response } from 'express';
import { validateRateLimiter } from '../middleware/rateLimiter';
import { getCountryCode, checkGeoFence } from '../middleware/geoFence';
import { getCachedValidation, cacheLicenseValidation, storeNonce } from '../config/redis';
import { hashKey, hashHwid } from '../utils/crypto';
import { validateSchema, validateBody } from '../utils/validators';
import * as licenseService from '../services/licenseService';
import * as hwidService from '../services/hwidService';
import * as sessionService from '../services/sessionService';
import * as analyticsService from '../services/analyticsService';
import { logger } from '../utils/logger';

const router = Router();

/**
 * POST /api/validate
 * Validate a license key and bind HWID.
 * 
 * This is rate-limited to 10 requests/minute per IP.
 * 
 * Request body:
 *   { license_key: "XXXXX-XXXXX-...", hwid: "composite-hwid-string", device_name?: "...", os_info?: "..." }
 * 
 * Success response:
 *   { valid: true, tier: "pro", feature_flags: {...}, session_token: "...", expires_at: "..." }
 * 
 * Failure response:
 *   { valid: false, error: "reason", code: "ERROR_CODE" }
 */
router.post('/', validateRateLimiter, async (req: Request, res: Response) => {
    const ip = req.ip || req.socket.remoteAddress || 'unknown';
    const userAgent = req.headers['user-agent'] || null;
    const countryCode = getCountryCode(req);

    try {
        // 1. ── Validate Input ──
        const { license_key, hwid, device_name, os_info } = validateBody(validateSchema, req.body);
        const keyHash = hashKey(license_key);
        const hwidHash = hashHwid(hwid);

        // 2. ── Check Redis Cache ──
        const cached = await getCachedValidation(keyHash) as any;
        // Note: We don't return cached results for validation because
        // HWID binding and session tracking must always be fresh.
        // Cache is used only to speed up the license lookup.

        // 3. ── Fetch License ──
        let license = cached?.license_data
            ? cached.license_data
            : await licenseService.getLicenseByKeyHash(keyHash);

        if (!license) {
            await logFailure(null, ip, countryCode, userAgent, hwidHash, 'invalid_key');
            res.status(404).json({ valid: false, error: 'Invalid license key', code: 'INVALID_KEY' });
            return;
        }

        // 4. ── Check Validity ──
        const validity = licenseService.isLicenseValid(license);
        if (!validity.valid) {
            await logFailure(license.id, ip, countryCode, userAgent, hwidHash, validity.reason!);
            res.status(403).json({
                valid: false,
                error: validity.reason,
                code: mapReasonToCode(validity.reason!),
            });
            return;
        }

        // 5. ── Geo-Fencing ──
        const geoResult = checkGeoFence(countryCode, license.allowed_countries);
        if (!geoResult.allowed) {
            await logFailure(license.id, ip, countryCode, userAgent, hwidHash, 'geo_blocked');
            res.status(403).json({
                valid: false,
                error: 'This license is not valid in your region',
                code: 'GEO_BLOCKED',
            });
            return;
        }

        // 6. ── HWID Binding ──
        const hwidResult = await hwidService.bindHwid(
            license.id, hwid, license.max_devices,
            { device_name, os_info }
        );

        if (!hwidResult.binding) {
            await logFailure(license.id, ip, countryCode, userAgent, hwidHash, 'device_limit');
            res.status(403).json({
                valid: false,
                error: hwidResult.error,
                code: 'DEVICE_LIMIT_EXCEEDED',
            });
            return;
        }

        // 7. ── Session Creation (Floating License) ──
        const sessionResult = await sessionService.createOrRefreshSession(
            license.id,
            hwidResult.binding.id,
            ip,
            countryCode,
            license.max_devices
        );

        if (!sessionResult.session) {
            await logFailure(license.id, ip, countryCode, userAgent, hwidHash, 'concurrent_limit');
            res.status(403).json({
                valid: false,
                error: sessionResult.error,
                code: 'CONCURRENT_LIMIT',
            });
            return;
        }

        // 8. ── Cache License Data ──
        await cacheLicenseValidation(keyHash, {
            license_data: {
                id: license.id,
                status: license.status,
                license_type: license.license_type,
                tier: license.tier,
                feature_flags: license.feature_flags,
                max_devices: license.max_devices,
                allowed_countries: license.allowed_countries,
                starts_at: license.starts_at,
                expires_at: license.expires_at,
            },
        });

        // 9. ── Log Success ──
        await analyticsService.logAccess(license.id, 'validate', true, {
            ip_address: ip,
            country_code: countryCode || undefined,
            user_agent: userAgent || undefined,
            hwid_hash: hwidHash,
            response_data: { tier: license.tier },
        });

        // 10. ── Return Success Response ──
        logger.info('License validated', { licenseId: license.id, tier: license.tier });

        res.json({
            valid: true,
            license_type: license.license_type,
            tier: license.tier,
            feature_flags: license.feature_flags,
            expires_at: license.expires_at,
            session_token: sessionResult.session.session_token,
            message: 'License is valid',
        });

    } catch (error: any) {
        if (error.name === 'ZodError') {
            res.status(400).json({
                valid: false,
                error: 'Invalid request format',
                code: 'INVALID_REQUEST',
                details: error.errors,
            });
            return;
        }
        logger.error('Validation error', { error: error.message });
        res.status(500).json({ valid: false, error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

/**
 * POST /api/validate/heartbeat
 * Keep a session alive. Clients should call this every 10-15 minutes.
 */
router.post('/heartbeat', async (req: Request, res: Response) => {
    try {
        const { session_token } = req.body;
        if (!session_token) {
            res.status(400).json({ error: 'Session token required' });
            return;
        }

        const alive = await sessionService.heartbeat(session_token);
        if (!alive) {
            res.status(404).json({ error: 'Session expired or not found', code: 'SESSION_EXPIRED' });
            return;
        }

        res.json({ alive: true, message: 'Session refreshed' });
    } catch (error: any) {
        logger.error('Heartbeat error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /api/validate/deactivate
 * End a session (user closes the app).
 */
router.post('/deactivate', async (req: Request, res: Response) => {
    try {
        const { session_token } = req.body;
        if (!session_token) {
            res.status(400).json({ error: 'Session token required' });
            return;
        }

        await sessionService.endSession(session_token);
        res.json({ message: 'Session ended' });
    } catch (error: any) {
        logger.error('Deactivate error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ---- Helper Functions ----

async function logFailure(
    licenseId: string | null,
    ip: string,
    country: string | null,
    userAgent: string | null,
    hwidHash: string,
    reason: string
): Promise<void> {
    await analyticsService.logAccess(licenseId, 'validate', false, {
        ip_address: ip,
        country_code: country || undefined,
        user_agent: userAgent || undefined,
        hwid_hash: hwidHash,
        failure_reason: reason,
    });
}

function mapReasonToCode(reason: string): string {
    if (reason.includes('suspended')) return 'LICENSE_SUSPENDED';
    if (reason.includes('banned')) return 'LICENSE_BANNED';
    if (reason.includes('revoked')) return 'LICENSE_REVOKED';
    if (reason.includes('expired')) return 'LICENSE_EXPIRED';
    if (reason.includes('not yet active')) return 'LICENSE_NOT_STARTED';
    return 'LICENSE_INVALID';
}

export default router;
