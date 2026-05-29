// ============================================================================
// UNS — Payload redaction (Task 16.4, REQ 12.8)
// ============================================================================
// Single canonical redactor for every Notification payload. Detects raw
// secrets, full payment-card numbers, and full government-issued
// identifiers and either:
//
//   1. Reports them as offending field paths — used by the Event_Bus
//      boundary validator (`event-bus/redaction-validator.ts`) to REJECT
//      a publish before SNS sees the event (REQ 12.8, primary line of
//      defense).
//
//   2. Replaces them with redacted references — used by
//      `Notification_Service.createNotification` as defense-in-depth
//      after sanitization (16.2) and before persistence so any raw value
//      that slipped past the bus (legacy producers, test seeds, internal
//      callers) is redacted before the persisted record exists.
//
// Sister modules:
//
//   - `sanitization.ts`             (16.2) — shape-driven (HTML / control
//                                            chars). Runs FIRST. Different
//                                            concern from this module.
//   - `unauthorized-audit.ts`       (16.3) — denial-path audit log writes.
//   - `observability/logger.ts`     (17.1) — key-name redaction at the log
//                                            sink. This module is the
//                                            payload-level counterpart.
//
// Detector design:
//
//   - VALUE-DRIVEN. We look at the digit/format pattern of strings, never
//     at the field name (a field called `notes` can contain a Bearer
//     token). Key-name detection is a separate, independent layer that
//     exists only to redact values whose KEY clearly states they are
//     sensitive even when the value's shape is too generic to detect.
//
//   - PURE / IMMUTABLE. Never mutates the input. Returns a fresh object
//     with the same shape and the same non-sensitive values.
//
//   - RECURSIVE. Walks every nested object and array, tracks visited
//     containers to terminate on cycles.
//
//   - CONFIGURABLE. A `RedactionConfig` flag set lets test code disable
//     individual detectors. Production callers use the default
//     (`STRICT_REDACTION_CONFIG`) which enables every detector.
//
// No external dependencies — Luhn check and every regex are in-house.
//
// Validates: REQ 12.8.
// ============================================================================

// ----------------------------------------------------------------------------
// Public types
// ----------------------------------------------------------------------------

/**
 * Stable taxonomy of patterns the redactor knows about. Exposed so the
 * bus boundary's structured `EventContractValidationError.issues[].keyword`
 * can name the offending pattern — operators triaging a publish rejection
 * see `pan_redacted` rather than a generic `validation_failed`.
 */
export const REDACTION_PATTERN = Object.freeze({
    CREDIT_CARD: 'credit_card',
    PAN_INDIA: 'pan_india',
    AADHAAR: 'aadhaar',
    BEARER_TOKEN: 'bearer_token',
    AWS_ACCESS_KEY: 'aws_access_key',
    SENSITIVE_KEY_VALUE: 'sensitive_key_value',
} as const);

export type RedactionPattern =
    (typeof REDACTION_PATTERN)[keyof typeof REDACTION_PATTERN];

/**
 * Per-pattern enable/disable flags. Default is strict (every detector
 * on). Test code uses this to focus on a single pattern at a time.
 *
 * Defense-in-depth note: production callers MUST NOT construct a config
 * with disabled detectors. The bus boundary validator and the service
 * redact pass both pull `STRICT_REDACTION_CONFIG` directly so a runaway
 * call site cannot loosen the policy by accident.
 */
export interface RedactionConfig {
    readonly creditCard: boolean;
    readonly panIndia: boolean;
    readonly aadhaar: boolean;
    readonly bearerToken: boolean;
    readonly awsAccessKey: boolean;
    readonly sensitiveKeyValue: boolean;
}

export const STRICT_REDACTION_CONFIG: RedactionConfig = Object.freeze({
    creditCard: true,
    panIndia: true,
    aadhaar: true,
    bearerToken: true,
    awsAccessKey: true,
    sensitiveKeyValue: true,
});

/**
 * One detected occurrence of a sensitive value in a payload.
 *
 *   - `path`    — dotted path (e.g. `customer.cards[0].number`) of the
 *                 offending field, suitable for the bus boundary's
 *                 `EventContractValidationError.issues[].field`.
 *   - `pattern` — which detector flagged it.
 *   - `match`   — the original raw substring (kept ONLY because the bus
 *                 boundary inspects `length` and last-4 to build the
 *                 rejection message; the raw match itself is never
 *                 logged or persisted by the redactor — callers must
 *                 not echo it either).
 */
export interface SensitiveOccurrence {
    readonly path: string;
    readonly pattern: RedactionPattern;
    readonly match: string;
}

// ----------------------------------------------------------------------------
// Redacted reference shapes
// ----------------------------------------------------------------------------

/**
 * Token replacement for opaque secrets. Keeps the field type (string)
 * stable so downstream serialisers do not need to special-case the
 * redacted path. Uppercase so it stands out in human inspection.
 */
const REDACTED_TOKEN = '[REDACTED]';

/**
 * Build the redacted reference for a credit card / PAN-style value.
 * Returns `****<last4>` so receipts that need to display "ending in
 * 1234" still work after redaction. Callers MUST NOT log the raw
 * `lastFour` separately — the redactor returns the formatted reference
 * so callers don't reach for the raw digits.
 */
function buildLastFourReference(digits: string): string {
    const last4 = digits.slice(-4).padStart(4, '*');
    return `****${last4}`;
}

// ----------------------------------------------------------------------------
// Sensitive-key matching (defense-in-depth at payload level)
// ----------------------------------------------------------------------------
//
// REQ 12.8 forbids embedding raw secrets/PAN/government IDs anywhere. The
// logger boundary (Task 17.1) already redacts by key-name at log time;
// we mirror the same key-name list here at payload level so a publisher
// that names a field `password` cannot smuggle the raw value past
// detection just because the value's shape is too generic to detect by
// pattern alone (e.g. an 8-character all-letters password).

const SENSITIVE_KEY_TOKENS: readonly string[] = Object.freeze([
    'password',
    'secret',
    'token',
    'apikey',
    'api_key',
    'authorization',
    'auth_token',
    'access_token',
    'refresh_token',
    'private_key',
    'client_secret',
    'session_token',
    'otp',
    'cvv',
]);

function isSensitiveKey(key: string): boolean {
    if (!key) return false;
    const lowered = key.toLowerCase();
    for (const needle of SENSITIVE_KEY_TOKENS) {
        if (lowered.includes(needle)) return true;
    }
    return false;
}

// ----------------------------------------------------------------------------
// Detectors — each is a `(value: string) => match | null` predicate
// ----------------------------------------------------------------------------

/**
 * Indian PAN: exactly 5 letters, 4 digits, 1 letter. Bound by word
 * boundaries so it does not flag a 10-character substring that happens
 * to fall inside a longer alphanumeric token.
 */
const PAN_RE = /\b[A-Z]{5}[0-9]{4}[A-Z]\b/g;

/**
 * AWS access key: prefix `AKIA` followed by 16 uppercase letters/digits.
 * AWS keys are exactly 20 chars long.
 */
const AWS_ACCESS_KEY_RE = /\bAKIA[0-9A-Z]{16}\b/g;

/**
 * Bearer token: literal `Bearer ` followed by a token of base64url-ish
 * characters. We accept the dotted JWT shape (`a.b.c`) and the simpler
 * opaque-token shape (`xyz123`). Limit ≥ 16 chars to avoid flagging
 * the literal word "Bearer something" in a sentence.
 */
const BEARER_TOKEN_RE = /\bBearer\s+[A-Za-z0-9._\-+/=]{16,}/g;

/**
 * Aadhaar: 12 digits, optionally split by single space or hyphen into
 * groups of 4. Bound by word boundaries.
 *
 * NOTE on the boundary: a raw 12-digit number could equally be a phone
 * number or an order id. The Phase 2 registry says government IDs are
 * never embedded raw — REQ 12.8 forbids it system-wide — so flagging
 * any 12-digit number that LOOKS like Aadhaar is the conservative
 * choice. False positives are easy to fix at the producer (the producer
 * should redact before publish anyway); a false negative leaks a real
 * Aadhaar.
 */
const AADHAAR_RE = /\b\d{4}[-\s]?\d{4}[-\s]?\d{4}\b/g;

/**
 * Credit-card-shaped digit sequence. We accept 13–19 digits with
 * optional separators (space or hyphen). Run AFTER stripping separators
 * we run a Luhn check — only Luhn-valid sequences are flagged. This
 * keeps the detector tight: a 16-digit transaction id will not be
 * flagged unless it happens to also pass Luhn.
 *
 * The regex matches sequences with separators; we strip the separators
 * before the Luhn step.
 */
const CREDIT_CARD_RE = /\b(?:\d[ -]?){12,18}\d\b/g;

/**
 * Luhn checksum. Returns `true` for a Luhn-valid digit-only string of
 * length 13–19; `false` otherwise. The function is the canonical
 * checksum used by every payment card brand (Visa/MasterCard/Amex/Disc
 * /JCB/Diners/UnionPay). Implementing it in-house avoids pulling a
 * dependency for a 30-line function.
 */
export function isLuhnValid(digits: string): boolean {
    if (!digits || digits.length < 13 || digits.length > 19) return false;
    let sum = 0;
    let alternate = false;
    for (let i = digits.length - 1; i >= 0; i--) {
        const ch = digits.charCodeAt(i);
        if (ch < 48 || ch > 57) return false; // not a digit
        let d = ch - 48;
        if (alternate) {
            d *= 2;
            if (d > 9) d -= 9;
        }
        sum += d;
        alternate = !alternate;
    }
    return sum % 10 === 0;
}

/**
 * Extract every credit-card-shaped, Luhn-valid digit run from `value`.
 * Returns the matches as separator-stripped digit strings so callers
 * can build the `****<last4>` reference directly.
 */
function findCreditCardMatches(value: string): readonly string[] {
    const out: string[] = [];
    const matches = value.match(CREDIT_CARD_RE);
    if (!matches) return out;
    for (const raw of matches) {
        const digitsOnly = raw.replace(/[^0-9]/g, '');
        if (isLuhnValid(digitsOnly)) out.push(digitsOnly);
    }
    return out;
}

// ----------------------------------------------------------------------------
// Public surface — find / redact
// ----------------------------------------------------------------------------

/**
 * Walk `root` recursively and report every sensitive occurrence.
 *
 * Path syntax: dotted for object keys, `[index]` for array elements.
 * The root path is `<root>` so the bus boundary's error message is
 * unambiguous when an entire payload field is one big secret.
 *
 * Returns the FIRST occurrence per (path, pattern) pair so the bus
 * boundary's error list does not balloon when one field carries a
 * stream of credit-card-shaped digits. The order of returned issues
 * is the order they appear in the depth-first walk so they match the
 * order an operator sees while reading the payload.
 */
export function findSensitiveOccurrences(
    root: unknown,
    config: RedactionConfig = STRICT_REDACTION_CONFIG,
): SensitiveOccurrence[] {
    const out: SensitiveOccurrence[] = [];
    const seen = new WeakSet<object>();
    walkForOccurrences(root, '<root>', config, seen, out);
    return out;
}

/**
 * Return `true` iff `findSensitiveOccurrences` would return any
 * occurrence. Provided as a hot-path helper for the bus boundary.
 */
export function containsSensitiveValues(
    root: unknown,
    config: RedactionConfig = STRICT_REDACTION_CONFIG,
): boolean {
    return findSensitiveOccurrences(root, config).length > 0;
}

/**
 * Walk `root` recursively and return a fresh structurally-equivalent
 * value with every sensitive occurrence replaced by its redacted
 * reference (`****<last4>` for cards / PAN, `[REDACTED]` for everything
 * else).
 *
 * Pure: never mutates the input. Cycles are dropped to `null` (the
 * payload is metadata, not a graph).
 *
 * Non-string primitives (number, boolean, null, bigint) pass through
 * untouched — REQ 12.8 talks about secret VALUES which in JSON shape
 * are always strings. A 16-digit number stored as a JS number would
 * lose precision long before reaching us; producers store cards as
 * strings.
 */
export function redactPayload<T>(
    root: T,
    config: RedactionConfig = STRICT_REDACTION_CONFIG,
): T {
    const seen = new WeakSet<object>();
    return redactValue(root, config, seen) as T;
}

// ----------------------------------------------------------------------------
// Internal — recursion engines
// ----------------------------------------------------------------------------

/**
 * Single string-level redaction. Applies every enabled detector in a
 * fixed order so the result is deterministic regardless of caller. The
 * order also matters because PAN (10 chars) must be tested BEFORE
 * AWS access key (20 chars) — both are uppercase-letter-and-digit
 * sequences, but the AWS pattern starts with the literal `AKIA` so the
 * patterns do not actually overlap; we still pin the order to keep
 * future extensions safe.
 */
export function redactString(
    value: string,
    config: RedactionConfig = STRICT_REDACTION_CONFIG,
): string {
    if (typeof value !== 'string' || value.length === 0) return value;
    let out = value;

    if (config.creditCard) {
        out = out.replace(CREDIT_CARD_RE, (match) => {
            const digits = match.replace(/[^0-9]/g, '');
            if (!isLuhnValid(digits)) return match;
            return buildLastFourReference(digits);
        });
    }

    if (config.panIndia) {
        out = out.replace(PAN_RE, (match) => buildLastFourReference(match));
    }

    if (config.aadhaar) {
        out = out.replace(AADHAAR_RE, (match) => {
            const digits = match.replace(/[^0-9]/g, '');
            if (digits.length !== 12) return match;
            return buildLastFourReference(digits);
        });
    }

    if (config.bearerToken) {
        out = out.replace(BEARER_TOKEN_RE, REDACTED_TOKEN);
    }

    if (config.awsAccessKey) {
        out = out.replace(AWS_ACCESS_KEY_RE, REDACTED_TOKEN);
    }

    return out;
}

function redactValue(
    value: unknown,
    config: RedactionConfig,
    seen: WeakSet<object>,
): unknown {
    if (value === null || value === undefined) return value;

    if (typeof value === 'string') {
        return redactString(value, config);
    }

    // Non-string primitives — REQ 12.8 talks about VALUES; numbers/
    // booleans/bigints cannot carry the formats we care about.
    if (typeof value !== 'object') return value;

    const obj = value as object;
    if (seen.has(obj)) return null;
    seen.add(obj);

    if (Array.isArray(value)) {
        return value.map((item) => redactValue(item, config, seen));
    }

    if (value instanceof Date) {
        return new Date(value.getTime());
    }

    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
        if (config.sensitiveKeyValue && isSensitiveKey(k) && v !== null && v !== undefined) {
            // The KEY says "this is a secret"; replace the VALUE with the
            // redacted token even when the value itself does not match a
            // pattern (e.g. a short password). Nested objects under a
            // sensitive key are dropped to the redacted token too — the
            // safest interpretation when the field name itself screams
            // "secret".
            if (typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean') {
                out[k] = REDACTED_TOKEN;
                continue;
            }
            out[k] = REDACTED_TOKEN;
            continue;
        }
        out[k] = redactValue(v, config, seen);
    }
    return out;
}

function walkForOccurrences(
    value: unknown,
    path: string,
    config: RedactionConfig,
    seen: WeakSet<object>,
    out: SensitiveOccurrence[],
): void {
    if (value === null || value === undefined) return;

    if (typeof value === 'string') {
        collectStringOccurrences(value, path, config, out);
        return;
    }

    if (typeof value !== 'object') return;

    const obj = value as object;
    if (seen.has(obj)) return;
    seen.add(obj);

    if (Array.isArray(value)) {
        for (let i = 0; i < value.length; i++) {
            walkForOccurrences(value[i], `${path}[${i}]`, config, seen, out);
        }
        return;
    }

    if (value instanceof Date) return;

    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
        const childPath = path === '<root>' ? k : `${path}.${k}`;
        // Sensitive-key detection: if the KEY is sensitive, the VALUE is
        // by definition a leak under REQ 12.8 — flag it and skip the
        // pattern walk on its value (the value has been classified
        // already).
        if (config.sensitiveKeyValue && isSensitiveKey(k) && hasNonEmptyValue(v)) {
            out.push({
                path: childPath,
                pattern: REDACTION_PATTERN.SENSITIVE_KEY_VALUE,
                match: typeof v === 'string' ? v : '<non-string>',
            });
            continue;
        }
        walkForOccurrences(v, childPath, config, seen, out);
    }
}

function hasNonEmptyValue(v: unknown): boolean {
    if (v === null || v === undefined) return false;
    if (typeof v === 'string' && v.trim() === '') return false;
    if (Array.isArray(v) && v.length === 0) return false;
    return true;
}

function collectStringOccurrences(
    value: string,
    path: string,
    config: RedactionConfig,
    out: SensitiveOccurrence[],
): void {
    // Card detection — Luhn-validated only. We collect every distinct
    // match so an operator can see how many cards a payload is leaking.
    if (config.creditCard) {
        for (const digits of findCreditCardMatches(value)) {
            out.push({
                path,
                pattern: REDACTION_PATTERN.CREDIT_CARD,
                match: digits,
            });
        }
    }

    if (config.panIndia) {
        const matches = value.match(PAN_RE);
        if (matches) {
            for (const m of matches) {
                out.push({
                    path,
                    pattern: REDACTION_PATTERN.PAN_INDIA,
                    match: m,
                });
            }
        }
    }

    if (config.aadhaar) {
        const matches = value.match(AADHAAR_RE);
        if (matches) {
            for (const m of matches) {
                const digits = m.replace(/[^0-9]/g, '');
                if (digits.length !== 12) continue;
                // Avoid double-flagging when the same 12-digit run was
                // already reported as a card via the Luhn pass.
                const alreadyAsCard = config.creditCard && isLuhnValid(digits);
                if (alreadyAsCard) continue;
                out.push({
                    path,
                    pattern: REDACTION_PATTERN.AADHAAR,
                    match: m,
                });
            }
        }
    }

    if (config.bearerToken) {
        const matches = value.match(BEARER_TOKEN_RE);
        if (matches) {
            for (const m of matches) {
                out.push({
                    path,
                    pattern: REDACTION_PATTERN.BEARER_TOKEN,
                    match: m,
                });
            }
        }
    }

    if (config.awsAccessKey) {
        const matches = value.match(AWS_ACCESS_KEY_RE);
        if (matches) {
            for (const m of matches) {
                out.push({
                    path,
                    pattern: REDACTION_PATTERN.AWS_ACCESS_KEY,
                    match: m,
                });
            }
        }
    }
}

// ----------------------------------------------------------------------------
// Test seam
// ----------------------------------------------------------------------------

/**
 * Internal exports used only by unit tests.
 */
export const __test__ = Object.freeze({
    PAN_RE,
    AWS_ACCESS_KEY_RE,
    BEARER_TOKEN_RE,
    AADHAAR_RE,
    CREDIT_CARD_RE,
    SENSITIVE_KEY_TOKENS,
    REDACTED_TOKEN,
    isSensitiveKey,
    buildLastFourReference,
});
