// ============================================================================
// Signing Keys — RS256 local-auth key loader (secure runtime source only)
// ============================================================================
// Requirement 17.5 / 17.2: local JWTs are signed with RS256, and the signing
// key is sourced from the operating-system keychain — NEVER hardcoded in
// source. The Dart Security_Layer reads the key from the OS keychain at
// startup and hands it to this packaged process through the environment when
// the Backend_Supervisor spawns it (the same seam my-backend uses via
// config/environment.ts). This module is the single place that resolves that
// key material, mirroring my-backend's `resolveKey` pattern.
//
// Provide EITHER an inline PEM (…_KEY) OR a path to a PEM file (…_KEY_PATH).
// Inline PEM values may use literal "\n" sequences for newlines (common when a
// PEM is round-tripped through an environment variable).
//
// The public key is optional and falls back to the private key, because an
// RSA private key already contains the public key; jsonwebtoken can verify an
// RS256 token using the private key when a dedicated public key is not set.
// ============================================================================

import { readFileSync } from 'fs';
import { AppError } from '../utils/errors';

/** Environment variable names that may carry the RS256 local-auth key. */
const ENV = {
    privateKey: 'LOCAL_AUTH_PRIVATE_KEY',
    privateKeyPath: 'LOCAL_AUTH_PRIVATE_KEY_PATH',
    publicKey: 'LOCAL_AUTH_PUBLIC_KEY',
    publicKeyPath: 'LOCAL_AUTH_PUBLIC_KEY_PATH',
} as const;

/**
 * Resolve a PEM key from either an inline value or a file path. Inline values
 * containing literal "\n" sequences are normalised to real newlines so the PEM
 * parses correctly.
 */
function resolvePem(inline: string | undefined, filePath: string | undefined, label: string): string {
    if (inline && inline.trim().length > 0) {
        return inline.includes('\\n') ? inline.replace(/\\n/g, '\n') : inline;
    }
    if (filePath && filePath.trim().length > 0) {
        try {
            return readFileSync(filePath, 'utf8');
        } catch {
            throw new AppError(
                `Failed to read ${label} from its configured path.`,
                500,
                'LOCAL_AUTH_SIGNING_KEY_UNREADABLE',
            );
        }
    }
    throw new AppError(
        `${label} is not configured. The Backend_Supervisor must supply the ` +
            `RS256 local-auth signing key from the OS keychain via the ` +
            `${ENV.privateKey} (inline PEM) or ${ENV.privateKeyPath} (PEM path) ` +
            `environment variable before the Offline_Auth_Service can issue tokens.`,
        500,
        'LOCAL_AUTH_SIGNING_KEY_MISSING',
    );
}

/**
 * The RS256 private key used to sign local-auth JWTs, resolved at call time
 * from the secure runtime environment. Resolved lazily (not at import) so the
 * process can start and serve /health even before a key is provisioned.
 */
export function localAuthPrivateKey(): string {
    return resolvePem(
        process.env[ENV.privateKey],
        process.env[ENV.privateKeyPath],
        'Local-auth RS256 private key',
    );
}

/**
 * The RS256 public/verification key. Falls back to the private key (which
 * embeds the public key) when a dedicated public key is not provisioned.
 */
export function localAuthPublicKey(): string {
    if (
        (process.env[ENV.publicKey] && process.env[ENV.publicKey]!.trim().length > 0) ||
        (process.env[ENV.publicKeyPath] && process.env[ENV.publicKeyPath]!.trim().length > 0)
    ) {
        return resolvePem(
            process.env[ENV.publicKey],
            process.env[ENV.publicKeyPath],
            'Local-auth RS256 public key',
        );
    }
    return localAuthPrivateKey();
}
