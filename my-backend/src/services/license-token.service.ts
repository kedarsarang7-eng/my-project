// ============================================================================
// License Token Service — RS256 Signing Layer (additive)
// ============================================================================
// Wraps the EXISTING, UNCHANGED LicenseKeyPayload into an RS256-signed
// License_Token with a 365-day TTL, machine-bound by Fingerprint_Hash, and
// provides a 12-hour local-auth JWT helper for the offline backend.
//
// Design constraints honoured here (offline-license-activation spec):
//   • Req 2.2  — The LicenseKeyPayload is reused verbatim. NO field is added,
//                removed, renamed, or retyped. The token only ADDS the standard
//                JWT binding/TTL claims (fingerprintHash, iat, exp).
//   • Req 5.5  — License_Token is RS256-signed with a 365-day TTL; a separate
//                12-hour local-auth JWT helper is provided.
//   • Keys are NEVER hardcoded — they are loaded from env (inline PEM or a PEM
//                file path) via config/environment.ts.
//
// This module is purely additive: it does not modify license.service.ts,
// license-denylist.service.ts, or the LicenseKeyPayload type, and it has no
// effect on Cloud_Subscription_Mode behavior.
// ============================================================================

import { readFileSync } from 'fs';
import * as jwt from 'jsonwebtoken';
import { config } from '../config/environment';
import { logger } from '../utils/logger';
import { AppError } from '../utils/errors';
import { LicenseKeyPayload } from '../types/license.types';

// -- Constants ---------------------------------------------------------------

/** License_Token time-to-live in seconds: 365 days (Req 5.5). */
export const LICENSE_TOKEN_TTL_SECONDS = 365 * 24 * 60 * 60;

/** Local-auth JWT time-to-live in seconds: 12 hours (Req 4.1 / 9.1). */
export const LOCAL_AUTH_TTL_SECONDS = 12 * 60 * 60;

/** RS256 is the only algorithm this layer signs/verifies with (Req 5.5). */
const SIGNING_ALGORITHM: jwt.Algorithm = 'RS256';

const LICENSE_TOKEN_ISSUER = 'dukanx-license-server';
const LOCAL_AUTH_ISSUER = 'dukanx-offline-auth';

// -- Types -------------------------------------------------------------------

/**
 * The verified claim set of a License_Token. It is exactly the existing
 * LicenseKeyPayload (reused verbatim) plus the standard JWT binding/TTL claims.
 * The LicenseKeyPayload portion is NOT modified in any way (Req 2.2).
 */
export interface LicenseTokenClaims extends LicenseKeyPayload {
    /** Machine binding: SHA256(cpuId + macAddress + hddSerial) (Req 5.2). */
    fingerprintHash: string;
    /** Issued-at, seconds since epoch (standard JWT claim). */
    iat: number;
    /** Expiry, seconds since epoch — iat + 365 days (Req 5.5). */
    exp: number;
    /** Issuer (standard JWT claim). */
    iss?: string;
}

/** Input claims for a local-auth JWT (Offline_Auth_Service session token). */
export interface LocalAuthClaims {
    /** The authenticated user id. */
    userId: string;
    /** The tenant the user belongs to. */
    tenantId: string;
    /** The user's RBAC role (owner | manager | cashier | viewer). */
    role: string;
    /** Optional session identifier, used for targeted session invalidation. */
    sessionId?: string;
}

/** The verified claim set of a local-auth JWT. */
export interface VerifiedLocalAuthClaims extends LocalAuthClaims {
    iat: number;
    exp: number;
    iss?: string;
}

// -- Key Loading (env only — never hardcoded) --------------------------------

/**
 * Resolve a PEM key from either an inline value or a file path.
 * Inline values may contain literal "\n" sequences (common in env files),
 * which are normalised to real newlines so the PEM parses correctly.
 */
function resolveKey(inline: string, filePath: string, label: string): string {
    if (inline && inline.trim().length > 0) {
        return inline.includes('\\n') ? inline.replace(/\\n/g, '\n') : inline;
    }
    if (filePath && filePath.trim().length > 0) {
        try {
            return readFileSync(filePath, 'utf8');
        } catch (err) {
            throw new AppError(
                `Failed to read ${label} from path`,
                500,
                'LICENSE_SIGNING_KEY_UNREADABLE',
            );
        }
    }
    throw new AppError(
        `${label} is not configured. Set the corresponding RS256 key env var ` +
            `(inline PEM or *_PATH) before using the license signing layer.`,
        500,
        'LICENSE_SIGNING_KEY_MISSING',
    );
}

function licensePrivateKey(): string {
    return resolveKey(
        config.licenseToken.privateKey,
        config.licenseToken.privateKeyPath,
        'License_Token private key',
    );
}

function licensePublicKey(): string {
    return resolveKey(
        config.licenseToken.publicKey,
        config.licenseToken.publicKeyPath,
        'License_Token public key',
    );
}

function localAuthPrivateKey(): string {
    // Fall back to the License_Token key pair when a dedicated local-auth key
    // is not configured, so a single key pair is enough for a basic deployment.
    if (config.licenseToken.localAuthPrivateKey || config.licenseToken.localAuthPrivateKeyPath) {
        return resolveKey(
            config.licenseToken.localAuthPrivateKey,
            config.licenseToken.localAuthPrivateKeyPath,
            'Local-auth private key',
        );
    }
    return licensePrivateKey();
}

function localAuthPublicKey(): string {
    if (config.licenseToken.localAuthPublicKey || config.licenseToken.localAuthPublicKeyPath) {
        return resolveKey(
            config.licenseToken.localAuthPublicKey,
            config.licenseToken.localAuthPublicKeyPath,
            'Local-auth public key',
        );
    }
    return licensePublicKey();
}

// -- License_Token: sign / verify --------------------------------------------

/**
 * Sign a License_Token: the UNCHANGED LicenseKeyPayload bound to a machine by
 * its Fingerprint_Hash, RS256-signed with a 365-day TTL (Req 5.5).
 *
 * The payload is spread in verbatim — this layer never mutates, adds, removes,
 * renames, or retypes any LicenseKeyPayload field (Req 2.2). Only the standard
 * JWT claims (fingerprintHash binding, iat, exp, iss) are added by signing.
 *
 * @param payload         The existing license payload, used as-is.
 * @param fingerprintHash SHA256(cpuId + macAddress + hddSerial) machine binding.
 * @returns               The compact RS256 JWT string.
 */
export function signLicenseToken(
    payload: LicenseKeyPayload,
    fingerprintHash: string,
): string {
    if (!fingerprintHash || fingerprintHash.trim().length === 0) {
        throw new AppError(
            'A non-empty fingerprintHash is required to bind a License_Token.',
            400,
            'LICENSE_TOKEN_FINGERPRINT_REQUIRED',
        );
    }

    // Spread the payload verbatim, then add only the machine-binding claim.
    // jsonwebtoken injects iat/exp from the options below.
    const claims = { ...payload, fingerprintHash };

    const token = jwt.sign(claims, licensePrivateKey(), {
        algorithm: SIGNING_ALGORITHM,
        expiresIn: LICENSE_TOKEN_TTL_SECONDS,
        issuer: LICENSE_TOKEN_ISSUER,
    });

    logger.info('License_Token signed', {
        tenantId: payload.tenantId,
        plan: payload.plan,
        ttlDays: LICENSE_TOKEN_TTL_SECONDS / 86400,
    });

    return token;
}

/**
 * Verify a License_Token against the RS256 public key.
 * Throws on any tampering, expiry, wrong issuer, or signature mismatch.
 *
 * @returns The verified claims, equal to the issued claims (Property 9).
 */
export function verifyLicenseToken(token: string): LicenseTokenClaims {
    try {
        return jwt.verify(token, licensePublicKey(), {
            algorithms: [SIGNING_ALGORITHM],
            issuer: LICENSE_TOKEN_ISSUER,
        }) as LicenseTokenClaims;
    } catch (err) {
        // Do not leak token contents; report a uniform verification failure.
        throw new AppError(
            'License_Token verification failed.',
            401,
            'LICENSE_TOKEN_INVALID',
        );
    }
}

// -- Local-auth JWT: sign / verify (12-hour helper) --------------------------

/**
 * Sign a local-auth JWT for the offline backend session, RS256-signed with a
 * 12-hour TTL (Req 4.1 / 9.1). Separate concern from the License_Token, but it
 * shares the RS256 signing approach and (by default) the same key pair.
 */
export function signLocalAuthToken(claims: LocalAuthClaims): string {
    if (!claims.userId || !claims.tenantId) {
        throw new AppError(
            'userId and tenantId are required to issue a local-auth token.',
            400,
            'LOCAL_AUTH_CLAIMS_REQUIRED',
        );
    }

    const token = jwt.sign(claims, localAuthPrivateKey(), {
        algorithm: SIGNING_ALGORITHM,
        expiresIn: LOCAL_AUTH_TTL_SECONDS,
        issuer: LOCAL_AUTH_ISSUER,
        subject: claims.userId,
    });

    logger.info('Local-auth token issued', {
        tenantId: claims.tenantId,
        ttlHours: LOCAL_AUTH_TTL_SECONDS / 3600,
    });

    return token;
}

/**
 * Verify a local-auth JWT against the RS256 public key.
 * Throws on any tampering, expiry, wrong issuer, or signature mismatch.
 */
export function verifyLocalAuthToken(token: string): VerifiedLocalAuthClaims {
    try {
        return jwt.verify(token, localAuthPublicKey(), {
            algorithms: [SIGNING_ALGORITHM],
            issuer: LOCAL_AUTH_ISSUER,
        }) as VerifiedLocalAuthClaims;
    } catch (err) {
        throw new AppError(
            'Local-auth token verification failed.',
            401,
            'LOCAL_AUTH_TOKEN_INVALID',
        );
    }
}
