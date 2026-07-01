// ============================================================================
// Password Service — bcrypt(12) hashing and verification
// ============================================================================
// Requirements 9.2 / 17.4 / 17.5: passwords are hashed and verified using
// bcrypt with a work factor (cost) of 12. This module is the single place the
// Local_Backend hashes or verifies a password, so the cost factor is enforced
// in exactly one location.
//
// bcryptjs (pure-JS) is used rather than the native `bcrypt` addon so the
// packaged desktop backend needs no per-platform native build step.
// ============================================================================

import bcrypt from 'bcryptjs';

/** The required bcrypt work factor for all offline password hashing (Req 9.2/17.4). */
export const BCRYPT_WORK_FACTOR = 12;

/**
 * Hash a plaintext password with bcrypt at the required work factor.
 *
 * @param plaintext The user's plaintext password. Must be non-empty.
 * @returns         A bcrypt hash string (carries its own salt + cost).
 */
export async function hashPassword(plaintext: string): Promise<string> {
    if (typeof plaintext !== 'string' || plaintext.length === 0) {
        throw new Error('Cannot hash an empty password.');
    }
    const salt = await bcrypt.genSalt(BCRYPT_WORK_FACTOR);
    return bcrypt.hash(plaintext, salt);
}

/**
 * Verify a plaintext password against a stored bcrypt hash.
 *
 * Returns `false` (never throws) for any malformed/empty input or hash, so a
 * verification failure is indistinguishable from a wrong password and never
 * leaks a different error path for callers to probe.
 *
 * @param plaintext The candidate plaintext password.
 * @param hash      The stored bcrypt hash to compare against.
 * @returns         True only when the password matches the hash.
 */
export async function verifyPassword(plaintext: string, hash: string): Promise<boolean> {
    if (typeof plaintext !== 'string' || plaintext.length === 0) return false;
    if (typeof hash !== 'string' || hash.length === 0) return false;
    try {
        return await bcrypt.compare(plaintext, hash);
    } catch {
        return false;
    }
}

/**
 * Report the bcrypt work factor (cost) encoded in a hash, or null if the hash
 * is not a recognisable bcrypt string. Useful for verifying that stored hashes
 * meet the required cost (Req 9.2).
 */
export function workFactorOf(hash: string): number | null {
    // bcrypt hash format: $2<a|b|y>$<cost>$<22-char salt><31-char digest>
    const match = /^\$2[aby]\$(\d{2})\$/.exec(hash);
    return match ? parseInt(match[1], 10) : null;
}
