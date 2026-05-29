// ============================================================================
// UNS — Payload sanitization (Task 16.2)
// ============================================================================
// Single canonical sanitizer for every Notification payload. Applied
// UNCONDITIONALLY by:
//
//   1. `Notification_Service.createNotification` — before persistence, so
//      the stored Notification.payload is already sanitized (REQ 12.2 first
//      half: "before persistence").
//   2. Every channel adapter (`channels/in-app.ts`, `push.ts`, `email.ts`,
//      `sms.ts`, `webhook.ts`) — before handing the payload to the
//      underlying transport, as defense-in-depth against payloads that
//      reached the adapter via paths bypassing `createNotification`
//      (REQ 12.2 second half: "before delivery").
//
// Scope of this module:
//
//   * Strip `<script>...</script>` blocks (including `<script src=...>`).
//   * Strip every other HTML tag (a notification payload is treated as
//     plain data, not markup) so cross-channel rendering is consistent —
//     in-app cards, email templates, and SMS bodies all see the same
//     scripting-tag-free string.
//   * Strip inline event handlers like `onerror=`, `onclick=` which can
//     ride non-`<script>` tags into XSS sinks.
//   * Strip `javascript:` URLs and similar dangerous URL schemes.
//   * Strip C0/C1 control characters (ASCII 0–8, 11–12, 14–31, 127), but
//     PRESERVE the whitespace runs the rest of the project relies on
//     (`\n`, `\r`, `\t`).
//   * Recurse through nested objects and arrays.
//   * Leave non-string primitives (number, boolean, null, undefined,
//     bigint, ISO timestamp strings, etc.) untouched.
//   * NEVER mutate the input — return a brand new object.
//
// Out of scope (kept separate per task 16.4):
//
//   * Redaction of secrets / PAN / government IDs. That is value-driven
//     (look for credit-card-shaped digits, redact). Sanitization is shape
//     -driven (look for scripting tags, strip). Mixing them would make
//     either path harder to reason about.
//
// No external deps — a tiny in-house sanitizer is preferable to pulling
// in DOMPurify on the backend (DOMPurify needs a DOM, which Lambda does
// not have, and we only need a narrow regex sweep).
//
// Validates: REQ 12.2.
// ============================================================================

// ----------------------------------------------------------------------------
// Patterns — kept module-local so callers cannot disable them.
// ----------------------------------------------------------------------------

/**
 * Match `<script ...>...</script>` (greedy across newlines), including
 * self-closing variants and ones with attributes. The `[\s\S]` class
 * matches any char including newline since the `s` (dotAll) regex flag
 * is not universally supported in older Node targets.
 */
const SCRIPT_BLOCK_RE = /<script\b[\s\S]*?(?:<\/script\s*>|$)/gi;

/**
 * Match self-closing or attribute-only `<script>` tags that have no
 * closing pair (e.g. `<script src="..."/>`). Run AFTER `SCRIPT_BLOCK_RE`
 * so we catch unpaired stragglers.
 */
const UNCLOSED_SCRIPT_TAG_RE = /<script\b[^>]*\/?>(?!\s*<\/script)/gi;

/**
 * Match every HTML/XML tag we want to drop entirely. After sanitization
 * the payload is plain text — keeping any tag opens a sink for the next
 * vulnerable renderer downstream. Tag content (the text between tags)
 * survives; only the angle-bracket markup is removed.
 */
const ANY_HTML_TAG_RE = /<\/?[a-z][^>]*>/gi;

/**
 * Match inline event-handler attributes (`onclick=`, `onerror=`, ...)
 * even when they appear in a string that the upstream tag stripper has
 * already walked. We take a belt-and-braces approach: drop the whole
 * `on<word>=...` attribute up to the next whitespace or end of string
 * so leftover fragments cannot be reassembled into a working handler.
 */
const EVENT_HANDLER_RE =
    /\bon[a-z]+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'>]+)/gi;

/**
 * Match dangerous URL schemes followed by a colon. We strip the scheme
 * marker so the payload no longer carries a clickable script URL while
 * keeping the rest of the value intact for human inspection.
 */
const DANGEROUS_URL_SCHEME_RE = /\b(javascript|vbscript|data)\s*:/gi;

/**
 * Match the C0/C1 control characters we strip. The character class
 * deliberately omits `\n` (0x0A), `\r` (0x0D), and `\t` (0x09) so
 * existing notification templates that depend on whitespace formatting
 * keep working. 0x7F (DEL) is included.
 */
// eslint-disable-next-line no-control-regex
const CONTROL_CHAR_RE = /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g;

// ----------------------------------------------------------------------------
// Public API
// ----------------------------------------------------------------------------

/**
 * Sanitize a notification payload IMMUTABLY.
 *
 * Recurses through nested objects and arrays; leaves non-string
 * primitives untouched. Returns a brand-new object so the caller can
 * safely substitute it for the original without worrying about hidden
 * aliases.
 *
 * Cycle detection: a `WeakSet` of already-visited containers prevents
 * infinite recursion if an unusual caller passes a cyclic structure.
 * Cycle hits collapse to `null` — the payload is metadata, not a graph,
 * so dropping the cycle is preferable to throwing.
 */
export function sanitizePayload(
    payload: Record<string, unknown>,
): Record<string, unknown> {
    if (payload === null || typeof payload !== 'object') {
        // Defensive — caller contracts guarantee a Record, but a
        // misbehaving caller MUST NOT bring the service down.
        return {};
    }
    const seen = new WeakSet<object>();
    const result = sanitizeValue(payload, seen) as Record<string, unknown>;
    return result ?? {};
}

/**
 * Sanitize a single string. Exported so adapters that compose their own
 * outbound text (e.g. the email subject in `email.ts`) can run the
 * sanitizer over a plain string without wrapping it in an object first.
 */
export function sanitizeString(value: string): string {
    if (typeof value !== 'string') return value;
    let out = value;
    // Order matters:
    //   1) strip `<script>` blocks WITH their content (the content is
    //      attacker-controlled JS, not user data we want to preserve)
    //   2) strip stray `<script>` tags missing a close
    //   3) strip every other HTML tag (markup itself, content survives)
    //   4) strip inline event handlers leaking through plain text
    //   5) strip dangerous URL schemes
    //   6) strip control characters
    out = out.replace(SCRIPT_BLOCK_RE, '');
    out = out.replace(UNCLOSED_SCRIPT_TAG_RE, '');
    out = out.replace(ANY_HTML_TAG_RE, '');
    out = out.replace(EVENT_HANDLER_RE, '');
    out = out.replace(DANGEROUS_URL_SCHEME_RE, '');
    out = out.replace(CONTROL_CHAR_RE, '');
    return out;
}

// ----------------------------------------------------------------------------
// Internal recursion helper
// ----------------------------------------------------------------------------

function sanitizeValue(value: unknown, seen: WeakSet<object>): unknown {
    if (value === null || value === undefined) {
        return value;
    }

    const t = typeof value;

    // Primitives that are not strings — return as-is (REQ 12.2 calls out
    // scripting tags + control characters in payload TEXT; numbers,
    // booleans, bigints, symbols cannot carry either).
    if (t === 'number' || t === 'boolean' || t === 'bigint' || t === 'symbol') {
        return value;
    }

    if (t === 'string') {
        return sanitizeString(value as string);
    }

    if (t === 'function') {
        // Functions have no place in a JSON-shaped notification payload.
        // Strip them rather than calling them or letting them leak.
        return undefined;
    }

    // Reference type — array or plain object. Detect cycles up-front.
    const obj = value as object;
    if (seen.has(obj)) {
        return null;
    }
    seen.add(obj);

    if (Array.isArray(value)) {
        const out: unknown[] = [];
        for (const item of value) {
            const cleaned = sanitizeValue(item, seen);
            if (cleaned !== undefined) {
                out.push(cleaned);
            }
        }
        return out;
    }

    // Date — keep ISO string representation untouched (it has no
    // scripting characters and the receiver may rely on the shape).
    if (value instanceof Date) {
        return new Date(value.getTime());
    }

    // Plain object — sanitize each value. Keys themselves are sanitized
    // too: an attacker who controls the key could otherwise smuggle a
    // scripting tag into a downstream renderer that prints the JSON
    // verbatim.
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
        const safeKey = sanitizeString(k);
        if (safeKey === '') {
            // Empty key after sanitization is dropped; preserving it
            // would re-introduce the very payload shape we just cleaned.
            continue;
        }
        const cleaned = sanitizeValue(v, seen);
        if (cleaned !== undefined) {
            out[safeKey] = cleaned;
        }
    }
    return out;
}

// ----------------------------------------------------------------------------
// Test seam
// ----------------------------------------------------------------------------

/**
 * Internal exports used only by unit tests. Production callers should
 * never reach for these; they exist so `__tests__/sanitization.test.ts`
 * can verify each individual regex sweep without re-implementing them.
 */
export const __test__ = {
    SCRIPT_BLOCK_RE,
    UNCLOSED_SCRIPT_TAG_RE,
    ANY_HTML_TAG_RE,
    EVENT_HANDLER_RE,
    DANGEROUS_URL_SCHEME_RE,
    CONTROL_CHAR_RE,
};
