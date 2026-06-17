import { config } from '../config/environment';
// ============================================================================
// Logger — Structured JSON Logging for Lambda / CloudWatch
// ============================================================================
// Automatically includes correlation ID and tenant ID from AsyncLocalStorage
// context when available — enables distributed tracing across services.
// ============================================================================

import * as context from './context';

type LogLevel = 'debug' | 'info' | 'warn' | 'error';

const LEVELS: Record<LogLevel, number> = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3,
};

const currentLevel: LogLevel = (config.app.logLevel as LogLevel) || 'info';

function shouldLog(level: LogLevel): boolean {
    return LEVELS[level] >= LEVELS[currentLevel];
}

// AUDIT FIX #13: Redact sensitive fields from log output
// Security_Layer (offline-license-activation, Req 17.10): "exclude secrets AND
// license keys from all log output." License keys and the Fingerprint_Hash
// originate and are validated on this License_Server, so the sensitive set also
// carries their field names; the `maskKey` pattern from license.service.ts is
// reused below to mask any DKX-/DKNX- key or JWT that appears INLINE in a
// message or string value (not only in a keyed field).
const SENSITIVE_KEYS = new Set([
    'password', 'previouspassword', 'proposedpassword', 'newpassword',
    'accesstoken', 'idtoken', 'refreshtoken', 'token', 'secret',
    'secretcode', 'confirmationcode', 'authorization', 'apikey', 'api_key',
    'creditcard', 'cardnumber', 'cvv', 'ssn',
    // License keys / machine binding / signing material (Req 17.10, 17.2).
    'licensekey', 'license_key', 'fingerprinthash', 'fingerprint_hash',
    'privatekey', 'private_key', 'signingkey', 'signing_key', 'jwt',
]);

// License keys in the existing DKX-/DKNX- formats, and JWT/RS256 tokens (three
// base64url segments). These can appear INLINE in a free-text message or a
// non-sensitive string field — not just as a keyed field — so they are masked
// there too (Req 17.10). Mirrors the packaged Local_Backend `logger.ts` and the
// Dart-side `LogScrubber` so a value is reduced identically across the stack.
const LICENSE_KEY_PATTERN = /\bDK[A-Z0-9]?X-[A-Z0-9]{3,}(?:-[A-Z0-9]{2,})*/gi;
const JWT_PATTERN = /\b[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/g;

/**
 * Mask a secret/key/license value, keeping only a short, non-reversible prefix.
 * Reuses the `maskKey` pattern established in license.service.ts.
 */
export function maskKey(value: string): string {
    if (!value) return '';
    if (value.length <= 4) return '****';
    return `${value.slice(0, 4)}****`;
}

/** Mask any DKX-/DKNX- license key or JWT that appears inline within a string. */
function scrubInline(text: string): string {
    if (!text) return text;
    return text
        .replace(JWT_PATTERN, (m) => maskKey(m))
        .replace(LICENSE_KEY_PATTERN, (m) => maskKey(m));
}

function redactSensitiveFields(obj: Record<string, unknown>): Record<string, unknown> {
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(obj)) {
        if (SENSITIVE_KEYS.has(key.toLowerCase())) {
            result[key] = '[REDACTED]';
        } else if (Array.isArray(value)) {
            result[key] = value.map((v) =>
                v && typeof v === 'object'
                    ? redactSensitiveFields(v as Record<string, unknown>)
                    : typeof v === 'string'
                      ? scrubInline(v)
                      : v,
            );
        } else if (value && typeof value === 'object') {
            result[key] = redactSensitiveFields(value as Record<string, unknown>);
        } else if (typeof value === 'string') {
            // A non-sensitive key may still carry an inline license key / JWT.
            result[key] = scrubInline(value);
        } else {
            result[key] = value;
        }
    }
    return result;
}

function log(level: LogLevel, message: string, meta?: Record<string, unknown>): void {
    if (!shouldLog(level)) return;

    // Auto-inject context from AsyncLocalStorage
    const tenantId = context.getTenantId();
    const correlationId = context.getCorrelationId();
    const userId = context.getUserId();

    // AUDIT FIX #13: Redact sensitive fields from log metadata
    const sanitizedMeta = meta ? redactSensitiveFields(meta) : {};

    const entry: Record<string, unknown> = {
        level,
        // Mask any DKX-/DKNX- license key or JWT that appears inline in the
        // free-text message (Req 17.10).
        message: scrubInline(message),
        timestamp: new Date().toISOString(),
        service: 'bizmate-backend',
        ...(correlationId ? { correlationId } : {}),
        ...(tenantId ? { tenantId } : {}),
        ...(userId ? { userId } : {}),
        ...sanitizedMeta,
    };

    // CloudWatch picks up JSON from stdout/stderr automatically
    if (level === 'error') {
        console.error(JSON.stringify(entry));
    } else {
        console.log(JSON.stringify(entry));
    }
}

export const logger = {
    debug: (msg: string, meta?: Record<string, unknown>) => log('debug', msg, meta),
    info: (msg: string, meta?: Record<string, unknown>) => log('info', msg, meta),
    warn: (msg: string, meta?: Record<string, unknown>) => log('warn', msg, meta),
    error: (msg: string, meta?: Record<string, unknown>) => log('error', msg, meta),
};
