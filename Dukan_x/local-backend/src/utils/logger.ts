// ============================================================================
// Logger — minimal structured logger with secret scrubbing
// ============================================================================
// Mirrors the AWS backend's logging shape while guaranteeing that secrets,
// keys, and license keys never reach log output (Req 17.10). Reuses the
// `maskKey` pattern and, as the Security_Layer (task 18.1) requires, scrubs
// license keys (DKX-/DKNX-) and JWT/RS256 tokens inline in messages and string
// metadata too — not just keyed sensitive fields. Mirrors the Dart-side
// `LogScrubber` so values are reduced identically on both sides of the stack.
// ============================================================================

const SENSITIVE_KEY_PATTERN =
    /(password|secret|token|authorization|apikey|api_key|licensekey|license_key|fingerprinthash|privatekey|private_key)/i;

/** Masks a license/secret value, keeping only a short non-reversible prefix. */
export function maskKey(value: string): string {
    if (!value) return '';
    if (value.length <= 4) return '****';
    return `${value.slice(0, 4)}****`;
}

// License keys in the existing DKX-/DKNX- formats, and JWT/RS256 tokens (three
// base64url segments). These can appear inline in a free-text message — not
// just as a keyed metadata field — so they are masked in the message too
// (Req 17.10). Mirrors the Dart-side LogScrubber so values are reduced
// identically on both sides of the stack.
const LICENSE_KEY_PATTERN = /\bDK[A-Z0-9]?X-[A-Z0-9]{3,}(?:-[A-Z0-9]{2,})*/gi;
const JWT_PATTERN = /\b[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/g;

/** Scrubs license keys and JWTs that appear inline within a log message. */
function scrubMessage(message: string): string {
    if (!message) return message;
    return message
        .replace(JWT_PATTERN, (m) => maskKey(m))
        .replace(LICENSE_KEY_PATTERN, (m) => maskKey(m));
}

/** Recursively scrubs sensitive fields from a metadata object before logging. */
function scrub(meta: unknown): unknown {
    if (typeof meta === 'string') return scrubMessage(meta);
    if (meta === null || typeof meta !== 'object') return meta;
    if (Array.isArray(meta)) return meta.map(scrub);

    const out: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(meta as Record<string, unknown>)) {
        if (SENSITIVE_KEY_PATTERN.test(key)) {
            out[key] = typeof value === 'string' ? maskKey(value) : '****';
        } else if (typeof value === 'object' && value !== null) {
            out[key] = scrub(value);
        } else if (typeof value === 'string') {
            // A non-sensitive key may still carry an inline license key / JWT.
            out[key] = scrubMessage(value);
        } else {
            out[key] = value;
        }
    }
    return out;
}

function emit(level: 'info' | 'warn' | 'error', message: string, meta?: unknown): void {
    const line = {
        level,
        ts: new Date().toISOString(),
        msg: scrubMessage(message),
        ...(meta !== undefined ? { meta: scrub(meta) } : {}),
    };
    const serialized = JSON.stringify(line);
    if (level === 'error') {
        // eslint-disable-next-line no-console
        console.error(serialized);
    } else if (level === 'warn') {
        // eslint-disable-next-line no-console
        console.warn(serialized);
    } else {
        // eslint-disable-next-line no-console
        console.log(serialized);
    }
}

export const logger = {
    info: (message: string, meta?: unknown) => emit('info', message, meta),
    warn: (message: string, meta?: unknown) => emit('warn', message, meta),
    error: (message: string, meta?: unknown) => emit('error', message, meta),
};
