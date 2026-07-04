// ============================================================================
// Staff Module — PII Crypto & Masking Service (Task 3.1)
// ============================================================================
// Field-level encryption + masking primitives for sensitive employee PII
// (Aadhaar, PAN, Passport, Driving Licence, bank account, UPI).
//
// AD-6 — FIELD-LEVEL ENCRYPTION AT THE SERVICE BOUNDARY
// -----------------------------------------------------
// PII values are encrypted BEFORE persistence using envelope encryption via the
// existing KMS wrapper (`services/kms.service.ts`) — the same client, encryption
// context and anomaly detection the payment/plan/AI key flows use. No new crypto
// dependency and no second key-management surface is introduced. Encryption is
// bound to `{ tenant_id, purpose: 'staff_pii' }` so a staff-PII blob cannot be
// decrypted under any other purpose (payment, plan key, AI key) and vice-versa.
//
// SECURITY INVARIANTS
//   1. Plaintext PII is NEVER logged (only field kind + tenant appear in logs).
//   2. A decrypt failure THROWS — callers MUST NOT fall back to plaintext.
//   3. The default display representation of any PII field is its masked form;
//      unmasking is role-gated elsewhere (tasks 3.2 / 3.5), not here.
//
// This service provides ONLY the crypto + masking primitives and the
// full-Aadhaar-capture feature flag (kept OFF). Role-gating, persistence and
// audit-on-unmask are wired in tasks 3.2 and 3.3.
//
// Requirements: 2.3 (Aadhaar → last 4 + encrypted), 2.4 (PAN/Passport/DL →
// encrypted + list-view mask), 2.6 (bank/UPI → encrypted + masked),
// 2.8 (full Aadhaar capture behind a Feature_Flag that stays OFF).
// ============================================================================

import * as kmsService from '../../../services/kms.service';
import * as featureFlagService from '../../../services/feature-flag.service';
import { logger } from '../../../utils/logger';
import { AppError } from '../../../utils/errors';

// ── PII field kinds ───────────────────────────────────────────────────────────
// The set of sensitive field kinds the module encrypts and masks. Each kind maps
// to a masking rule below; there is no per-business-type branching (AD-2).

export type PiiFieldKind =
    | 'aadhaar'
    | 'pan'
    | 'passport'
    | 'driving_licence'
    | 'bank_account'
    | 'upi';

// Encryption-context purpose that isolates staff PII ciphertext from every other
// KMS use case in the platform. Must be identical on encrypt and decrypt.
const PII_ENCRYPTION_PURPOSE = 'staff_pii';

// ── Encryption / decryption ─────────────────────────────────────────────────

/**
 * Encrypt a single PII field value for at-rest storage.
 *
 * @param value    - Plaintext PII value (must be non-empty)
 * @param tenantId - Tenant ID bound into the KMS encryption context (isolation)
 * @returns Base64 ciphertext safe to persist in DynamoDB (never the plaintext)
 * @throws AppError if the value is empty (nothing to encrypt)
 */
export async function encryptField(value: string, tenantId: string): Promise<string> {
    if (typeof value !== 'string' || value.length === 0) {
        throw new AppError('PII_ENCRYPT_EMPTY', 'Cannot encrypt an empty PII value');
    }
    if (!tenantId) {
        throw new AppError('PII_ENCRYPT_NO_TENANT', 'tenantId is required to encrypt PII');
    }

    // NOTE: plaintext is intentionally NEVER logged.
    return kmsService.encryptWithContext(value, tenantId, PII_ENCRYPTION_PURPOSE);
}

/**
 * Decrypt a single PII field value.
 *
 * A decryption failure THROWS and is surfaced to the caller — there is NO
 * fallback that returns the ciphertext or any other value as plaintext. This
 * guarantees a corrupted/forged blob or a wrong tenant context can never leak a
 * usable value (Req 2.3, 2.4, 2.6).
 *
 * @param cipher   - Base64 ciphertext produced by {@link encryptField}
 * @param tenantId - Tenant ID used as the encryption context (must match)
 * @returns Decrypted plaintext PII value
 * @throws Error/AppError on any decryption failure (never returns plaintext)
 */
export async function decryptField(cipher: string, tenantId: string): Promise<string> {
    if (typeof cipher !== 'string' || cipher.length === 0) {
        throw new AppError('PII_DECRYPT_EMPTY', 'Cannot decrypt an empty ciphertext');
    }
    if (!tenantId) {
        throw new AppError('PII_DECRYPT_NO_TENANT', 'tenantId is required to decrypt PII');
    }

    try {
        return await kmsService.decryptWithContext(cipher, tenantId, PII_ENCRYPTION_PURPOSE);
    } catch (err) {
        // Log the failure WITHOUT the ciphertext or any plaintext. Do NOT fall
        // back to returning the input — a failed decrypt must never leak data.
        logger.error('PII decryption failed', {
            tenantId,
            error: (err as Error).message,
        });
        throw new AppError(
            'PII_DECRYPT_FAILED',
            'Failed to decrypt PII value',
            undefined,
        );
    }
}

// ── Masking ───────────────────────────────────────────────────────────────────
// The masked value is the DEFAULT display representation for every PII field.
// Aadhaar reveals only its last 4 digits (Req 2.3); other IDs / bank / UPI reveal
// only a small permitted portion suitable for list views (Req 2.4, 2.6).

const MASK_CHAR = 'X';

// How many trailing characters each kind may reveal in a list-view mask.
const REVEAL_LAST: Record<PiiFieldKind, number> = {
    aadhaar: 4, // Req 2.3 — last 4 digits only
    pan: 4,
    passport: 4,
    driving_licence: 4,
    bank_account: 4,
    upi: 0, // UPI handled specially (keep the @provider portion, mask the VPA name)
};

/**
 * Mask a PII value for display. Returns the masked representation only; it does
 * NOT decrypt — callers pass the already-decrypted plaintext (or a raw value on
 * capture) they intend to display.
 *
 * Rules:
 *   - aadhaar        → reveal last 4 digits, mask the rest (e.g. `XXXXXXXX1234`).
 *   - pan/passport/  → reveal last 4 characters (list-view mask).
 *     driving_licence/
 *     bank_account
 *   - upi            → keep the `@provider` suffix, mask the VPA local part
 *                      (e.g. `XXXX@okhdfc`); values without `@` reveal last 4.
 *
 * An empty/undefined value returns an empty string. A value shorter than the
 * revealed length is fully masked (never reveals more than the rule allows).
 */
export function mask(value: string | null | undefined, kind: PiiFieldKind): string {
    if (value === null || value === undefined || value === '') {
        return '';
    }

    if (kind === 'upi') {
        return maskUpi(value);
    }

    if (kind === 'aadhaar') {
        // Aadhaar is digits-only in practice; strip formatting so the mask always
        // reflects the last 4 DIGITS regardless of spaces/hyphens in the input.
        const digits = value.replace(/\D/g, '');
        const source = digits.length > 0 ? digits : value;
        return revealLast(source, REVEAL_LAST.aadhaar);
    }

    return revealLast(value, REVEAL_LAST[kind]);
}

/**
 * Reveal only the last `revealCount` characters of `value`, replacing every
 * preceding character with the mask character. If the value is at most
 * `revealCount` long, it is fully masked (so a short value can never expose all
 * of itself). The masked prefix length mirrors the hidden length.
 */
function revealLast(value: string, revealCount: number): string {
    const len = value.length;
    if (revealCount <= 0 || len <= revealCount) {
        return MASK_CHAR.repeat(len);
    }
    const hidden = len - revealCount;
    return MASK_CHAR.repeat(hidden) + value.slice(hidden);
}

/**
 * Mask a UPI VPA (`name@provider`): keep the `@provider` suffix (non-sensitive
 * routing info) and mask the local part. A value without `@` falls back to a
 * reveal-last-4 mask.
 */
function maskUpi(value: string): string {
    const at = value.indexOf('@');
    if (at <= 0) {
        return revealLast(value, 4);
    }
    const local = value.slice(0, at);
    const provider = value.slice(at); // includes '@'
    return MASK_CHAR.repeat(local.length) + provider;
}

// ── Full-Aadhaar-capture Feature Flag (Req 2.8) ───────────────────────────────
// Full Aadhaar capture is gated behind a Feature_Flag that REMAINS OFF pending
// documented legal review. Resolution is FAIL-CLOSED: if the flag is missing,
// inactive, or not explicitly `true`, capture is disabled. This service never
// creates or enables the flag.

/** Feature flag key controlling full Aadhaar number capture. Stays OFF. */
export const FULL_AADHAAR_CAPTURE_FLAG = 'staff_full_aadhaar_capture';

/**
 * Resolve whether full Aadhaar capture is enabled. FAIL-CLOSED: returns `false`
 * unless a flag with this key exists, is active, and has an explicit `true`
 * default value. On any lookup error, returns `false` (capture stays OFF).
 */
export async function isFullAadhaarCaptureEnabled(): Promise<boolean> {
    try {
        const flag = await featureFlagService.getFeatureFlag(FULL_AADHAAR_CAPTURE_FLAG);
        if (!flag || !flag.is_active) {
            return false;
        }
        return flag.default_value === true;
    } catch (err) {
        logger.warn('Full Aadhaar capture flag lookup failed; defaulting OFF', {
            error: (err as Error).message,
        });
        return false;
    }
}

/**
 * Guard for the full-Aadhaar-capture code path. Throws a 403 AppError unless the
 * flag is explicitly enabled, so callers cannot capture a full Aadhaar number
 * while the flag remains OFF (Req 2.8).
 */
export async function assertFullAadhaarCaptureAllowed(): Promise<void> {
    const enabled = await isFullAadhaarCaptureEnabled();
    if (!enabled) {
        throw new AppError(
            'Full Aadhaar capture is disabled pending legal review',
            403,
            'FULL_AADHAAR_CAPTURE_DISABLED',
        );
    }
}
