// ============================================
// HWID Service — Hardware ID Binding & Management
// ============================================
// Manages the binding of license keys to physical hardware.
// Each license can bind to max_devices unique HWIDs.

import { query, queryOne } from '../config/database';
import { hashHwid, encrypt } from '../utils/crypto';
import { HwidBinding } from '../models/types';
import { logger } from '../utils/logger';

/**
 * Bind an HWID to a license.
 * Returns the binding if successful, null if device limit reached.
 * 
 * Flow:
 * 1. Check if HWID is already bound to this license → update last_seen
 * 2. Check if device limit reached → reject
 * 3. Create new binding
 */
export async function bindHwid(
    licenseId: string,
    hwid: string,
    maxDevices: number,
    deviceInfo?: { device_name?: string; os_info?: string }
): Promise<{ binding: HwidBinding | null; error?: string }> {
    const hwidHash = hashHwid(hwid);

    // 1. Check if this HWID is already bound to this license
    const existing = await queryOne<HwidBinding>(
        'SELECT * FROM hwid_bindings WHERE license_id = $1 AND hwid_hash = $2 AND is_active = TRUE',
        [licenseId, hwidHash]
    );

    if (existing) {
        // Update last_seen timestamp
        await query(
            'UPDATE hwid_bindings SET last_seen_at = NOW() WHERE id = $1',
            [existing.id]
        );
        return { binding: existing };
    }

    // 2. Count current active bindings
    const countResult = await queryOne<{ count: string }>(
        'SELECT COUNT(*) as count FROM hwid_bindings WHERE license_id = $1 AND is_active = TRUE',
        [licenseId]
    );
    const currentCount = parseInt(countResult?.count || '0', 10);

    if (currentCount >= maxDevices) {
        logger.warn('HWID binding rejected: device limit reached', {
            licenseId,
            currentCount,
            maxDevices,
        });
        return {
            binding: null,
            error: `Device limit reached (${currentCount}/${maxDevices}). Reset an existing device to use this key.`,
        };
    }

    // 3. Create new binding (encrypt raw HWID components for storage)
    const binding = await queryOne<HwidBinding>(
        `INSERT INTO hwid_bindings (
      license_id, hwid_hash, device_name, os_info
    ) VALUES ($1, $2, $3, $4) RETURNING *`,
        [
            licenseId,
            hwidHash,
            deviceInfo?.device_name || null,
            deviceInfo?.os_info || null,
        ]
    );

    logger.info('HWID bound to license', {
        licenseId,
        deviceCount: currentCount + 1,
        maxDevices,
    });

    return { binding: binding! };
}

/**
 * Check if an HWID is bound to a license (without creating a binding).
 */
export async function isHwidBound(licenseId: string, hwid: string): Promise<boolean> {
    const hwidHash = hashHwid(hwid);
    const result = await queryOne<HwidBinding>(
        'SELECT id FROM hwid_bindings WHERE license_id = $1 AND hwid_hash = $2 AND is_active = TRUE',
        [licenseId, hwidHash]
    );
    return result !== null;
}

/**
 * Get all HWID bindings for a license.
 */
export async function getBindings(licenseId: string): Promise<HwidBinding[]> {
    return query<HwidBinding>(
        'SELECT * FROM hwid_bindings WHERE license_id = $1 ORDER BY bound_at DESC',
        [licenseId]
    );
}

/**
 * Reset (deactivate) a specific HWID binding.
 * Used when a user changes their PC — admin clicks "Reset HWID".
 */
export async function resetHwid(bindingId: string): Promise<boolean> {
    const result = await queryOne<HwidBinding>(
        'UPDATE hwid_bindings SET is_active = FALSE WHERE id = $1 RETURNING id',
        [bindingId]
    );

    if (result) {
        logger.info('HWID reset', { bindingId });
        return true;
    }
    return false;
}

/**
 * Reset ALL HWID bindings for a license.
 * Use with caution — allows the license to be used on entirely new devices.
 */
export async function resetAllHwids(licenseId: string): Promise<number> {
    const result = await query<HwidBinding>(
        'UPDATE hwid_bindings SET is_active = FALSE WHERE license_id = $1 AND is_active = TRUE RETURNING id',
        [licenseId]
    );

    logger.info('All HWIDs reset for license', { licenseId, count: result.length });
    return result.length;
}
