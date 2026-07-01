// ============================================
// Crypto Utilities — AES-256, RSA, Hashing
// ============================================
// This module provides all cryptographic operations for the SLS.
// SECURITY: Never log or expose raw keys. Always use environment variables.

import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

// ---- Constants ----

const AES_ALGORITHM = 'aes-256-gcm';
const AES_KEY_LENGTH = 32;  // 256 bits
const AES_IV_LENGTH = 16;   // 128 bits
const AES_TAG_LENGTH = 16;  // 128 bits
const KEY_CHARSET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I/O/0/1 (anti-confusion)
const KEY_SEGMENTS = 5;
const KEY_SEGMENT_LENGTH = 5;

// ---- License Key Generation ----

/**
 * Generate a cryptographically secure, human-readable license key.
 * Format: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX (25 alphanumeric + 4 dashes = 29 chars)
 * 
 * Why this is secure:
 * 1. Uses crypto.randomBytes() (CSPRNG), not Math.random()
 * 2. 28-char charset × 25 positions = ~120 bits of entropy
 * 3. Ambiguous characters (I/1, O/0) removed for readability
 * 4. Key is hashed with SHA-256 for DB lookups (never compared as plaintext)
 */
export function generateLicenseKey(): string {
    const parts: string[] = [];

    for (let i = 0; i < KEY_SEGMENTS; i++) {
        const bytes = crypto.randomBytes(KEY_SEGMENT_LENGTH);
        let segment = '';
        for (let j = 0; j < KEY_SEGMENT_LENGTH; j++) {
            segment += KEY_CHARSET[bytes[j] % KEY_CHARSET.length];
        }
        parts.push(segment);
    }

    return parts.join('-');
}

// ---- SHA-256 Hashing ----

/**
 * Hash a license key using SHA-256 for indexed database lookups.
 * The raw key is never stored directly in any query.
 */
export function hashKey(key: string): string {
    return crypto.createHash('sha256').update(key).digest('hex');
}

/**
 * Hash an HWID composite string for storage.
 * Input: concatenation of motherboard_id + disk_serial + mac_address
 */
export function hashHwid(hwid: string): string {
    return crypto.createHash('sha256').update(hwid).digest('hex');
}

// ---- AES-256-GCM Encryption ----

/**
 * Encrypt data using AES-256-GCM.
 * Returns a base64 string: IV + AuthTag + CipherText
 * Used for encrypting raw HWID components at rest.
 */
export function encrypt(plaintext: string): string {
    const keyHex = process.env.AES_ENCRYPTION_KEY;
    if (!keyHex || keyHex.length !== 64) {
        throw new Error('AES_ENCRYPTION_KEY must be a 64-character hex string (256 bits)');
    }

    const key = Buffer.from(keyHex, 'hex');
    const iv = crypto.randomBytes(AES_IV_LENGTH);
    const cipher = crypto.createCipheriv(AES_ALGORITHM, key, iv);

    let encrypted = cipher.update(plaintext, 'utf8');
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    const authTag = cipher.getAuthTag();

    // Pack: IV (16) + AuthTag (16) + Ciphertext
    const packed = Buffer.concat([iv, authTag, encrypted]);
    return packed.toString('base64');
}

/**
 * Decrypt AES-256-GCM encrypted data.
 */
export function decrypt(encryptedBase64: string): string {
    const keyHex = process.env.AES_ENCRYPTION_KEY;
    if (!keyHex || keyHex.length !== 64) {
        throw new Error('AES_ENCRYPTION_KEY must be a 64-character hex string (256 bits)');
    }

    const key = Buffer.from(keyHex, 'hex');
    const packed = Buffer.from(encryptedBase64, 'base64');

    const iv = packed.subarray(0, AES_IV_LENGTH);
    const authTag = packed.subarray(AES_IV_LENGTH, AES_IV_LENGTH + AES_TAG_LENGTH);
    const ciphertext = packed.subarray(AES_IV_LENGTH + AES_TAG_LENGTH);

    const decipher = crypto.createDecipheriv(AES_ALGORITHM, key, iv);
    decipher.setAuthTag(authTag);

    let decrypted = decipher.update(ciphertext);
    decrypted = Buffer.concat([decrypted, decipher.final()]);
    return decrypted.toString('utf8');
}

// ---- RSA Key Pair Operations (Offline Activation) ----

/**
 * Generate an RSA-2048 key pair and save to disk.
 * Called once during initial setup.
 */
export function generateRsaKeyPair(privateKeyPath: string, publicKeyPath: string): void {
    const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
        modulusLength: 2048,
        publicKeyEncoding: { type: 'spki', format: 'pem' },
        privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });

    // Ensure directory exists
    const dir = path.dirname(privateKeyPath);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }

    fs.writeFileSync(privateKeyPath, privateKey, { mode: 0o600 }); // owner-only read
    fs.writeFileSync(publicKeyPath, publicKey);
}

/**
 * Sign data with the RSA private key (for offline activation).
 * The signature can be verified by the desktop client using the public key.
 */
export function rsaSign(data: string): string {
    const privateKeyPath = process.env.RSA_PRIVATE_KEY_PATH || './keys/private.pem';

    if (!fs.existsSync(privateKeyPath)) {
        throw new Error(`RSA private key not found at ${privateKeyPath}. Run key generation first.`);
    }

    const privateKey = fs.readFileSync(privateKeyPath, 'utf8');
    const signature = crypto.sign('sha256', Buffer.from(data), {
        key: privateKey,
        padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
    });

    return signature.toString('base64');
}

/**
 * Verify an RSA signature (for testing / admin verification).
 */
export function rsaVerify(data: string, signatureBase64: string): boolean {
    const publicKeyPath = process.env.RSA_PUBLIC_KEY_PATH || './keys/public.pem';

    if (!fs.existsSync(publicKeyPath)) {
        throw new Error(`RSA public key not found at ${publicKeyPath}. Run key generation first.`);
    }

    const publicKey = fs.readFileSync(publicKeyPath, 'utf8');
    const signature = Buffer.from(signatureBase64, 'base64');

    return crypto.verify('sha256', Buffer.from(data), {
        key: publicKey,
        padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
    }, signature);
}

// ---- Utility: Generate Secure Random Token ----

/**
 * Generate a cryptographically secure random token (hex string).
 * Used for session tokens, nonces, etc.
 */
export function generateSecureToken(bytes = 32): string {
    return crypto.randomBytes(bytes).toString('hex');
}

/**
 * Generate a nonce for replay attack prevention.
 */
export function generateNonce(): string {
    return crypto.randomBytes(16).toString('hex');
}
