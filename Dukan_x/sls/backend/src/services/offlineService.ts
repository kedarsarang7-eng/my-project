// ============================================
// Offline Activation Service — RSA Sign/Verify
// ============================================
// Implements the offline activation flow:
// 1. Client generates a request file (license_key + HWID + nonce)
// 2. Admin uploads request → server signs it with RSA private key
// 3. Client imports signed license file → verifies with embedded public key

import { query, queryOne } from '../config/database';
import { rsaSign, rsaVerify, hashKey, hashHwid } from '../utils/crypto';
import { OfflineActivation, License } from '../models/types';
import * as licenseService from './licenseService';
import * as hwidService from './hwidService';
import { logger } from '../utils/logger';

/**
 * Sign an offline activation request.
 * This is called by the admin after receiving a request file from the user.
 */
export async function signOfflineRequest(
    licenseKey: string,
    hwid: string,
    nonce: string,
    signedBy: string,
    deviceName?: string
): Promise<{ activation: OfflineActivation | null; error?: string }> {

    // 1. Find and validate the license
    const keyHash = hashKey(licenseKey);
    const license = await licenseService.getLicenseByKeyHash(keyHash);

    if (!license) {
        return { activation: null, error: 'License key not found' };
    }

    const validity = licenseService.isLicenseValid(license);
    if (!validity.valid) {
        return { activation: null, error: validity.reason };
    }

    // 2. Check for duplicate nonce (replay prevention)
    const existingNonce = await queryOne<OfflineActivation>(
        'SELECT id FROM offline_activations WHERE request_nonce = $1',
        [nonce]
    );
    if (existingNonce) {
        return { activation: null, error: 'Nonce already used — possible replay attack' };
    }

    // 3. Bind the HWID
    const hwidResult = await hwidService.bindHwid(
        license.id, hwid, license.max_devices,
        { device_name: deviceName }
    );
    if (!hwidResult.binding) {
        return { activation: null, error: hwidResult.error };
    }

    // 4. Build the payload to sign
    const hwidHash = hashHwid(hwid);
    const payload = JSON.stringify({
        license_id: license.id,
        license_key: licenseKey,
        tier: license.tier,
        feature_flags: license.feature_flags,
        hwid_hash: hwidHash,
        nonce: nonce,
        issued_at: new Date().toISOString(),
        expires_at: license.expires_at?.toISOString() || null,
        license_type: license.license_type,
    });

    // 5. Sign with RSA private key
    const signature = rsaSign(payload);

    // 6. Store the activation record
    const activation = await queryOne<OfflineActivation>(
        `INSERT INTO offline_activations (
      license_id, request_nonce, request_hwid, request_data,
      signed_payload, signature, status, signed_by, signed_at, expires_at
    ) VALUES ($1, $2, $3, $4, $5, $6, 'signed', $7, NOW(), $8)
    RETURNING *`,
        [
            license.id, nonce, hwidHash,
            JSON.stringify({ license_key: licenseKey, hwid, nonce, device_name: deviceName }),
            payload, signature, signedBy,
            license.expires_at || null,
        ]
    );

    logger.info('Offline activation signed', {
        licenseId: license.id,
        nonce,
    });

    return { activation: activation! };
}

/**
 * Verify an offline activation signature.
 * This can be used by the admin panel to verify a license file is valid.
 */
export async function verifyOfflineSignature(
    payload: string,
    signature: string
): Promise<boolean> {
    try {
        return rsaVerify(payload, signature);
    } catch (error: any) {
        logger.error('Offline verification failed', { error: error.message });
        return false;
    }
}

/**
 * Get all offline activations for a license.
 */
export async function getActivations(licenseId: string): Promise<OfflineActivation[]> {
    return query<OfflineActivation>(
        'SELECT * FROM offline_activations WHERE license_id = $1 ORDER BY created_at DESC',
        [licenseId]
    );
}

/**
 * Revoke an offline activation.
 */
export async function revokeActivation(activationId: string): Promise<boolean> {
    const result = await queryOne<OfflineActivation>(
        `UPDATE offline_activations SET status = 'revoked' WHERE id = $1 RETURNING id`,
        [activationId]
    );
    return result !== null;
}
