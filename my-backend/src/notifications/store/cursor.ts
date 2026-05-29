// ============================================================================
// Notification_Store — Pagination Cursor (REQ 6.9)
// ============================================================================
// REQ 6.9: "support cursor-based pagination for notification history queries
// using an opaque cursor that encodes (user_id, created_at, notification_id)."
//
// We base64url-encode a JSON tuple so the cursor:
//   - is opaque to clients (URL-safe, no base64 `+`/`/`/`=` characters);
//   - round-trips deterministically (encode then decode -> structural equal);
//   - carries everything DynamoDB needs to resume the query on the
//     `by-user-status` GSI without re-scanning prior pages.
//
// Cursors are compact (~80-120 bytes) so they fit comfortably in query strings.
// ============================================================================

import { InvalidCursorError } from './errors';

/**
 * The decoded shape of a pagination cursor. Mirrors the tuple required
 * by REQ 6.9 verbatim.
 */
export interface PaginationCursor {
    readonly user_id: string;
    readonly created_at: string;
    readonly notification_id: string;
}

const CURSOR_KEYS: readonly (keyof PaginationCursor)[] = [
    'user_id',
    'created_at',
    'notification_id',
];

// ---- base64url helpers ----------------------------------------------------
// `Buffer.from(..., 'base64url')` is supported on Node 16+; my-backend targets
// Node >= 20 (see package.json `engines.node`), so we use it directly.

function base64urlEncode(input: string): string {
    return Buffer.from(input, 'utf8').toString('base64url');
}

function base64urlDecode(input: string): string {
    return Buffer.from(input, 'base64url').toString('utf8');
}

// ---- Public API -----------------------------------------------------------

/**
 * Encode a `(user_id, created_at, notification_id)` tuple into the opaque
 * pagination cursor. The serialiser produces stable output: encoding the
 * same tuple twice yields the same string (sorted-key JSON).
 */
export function encodeCursor(cursor: PaginationCursor): string {
    // Validate inputs early so we never persist junk in the cursor.
    for (const key of CURSOR_KEYS) {
        const value = cursor[key];
        if (typeof value !== 'string' || value.length === 0) {
            throw new InvalidCursorError(
                `Cursor field '${key}' must be a non-empty string`,
            );
        }
    }

    // Sorted key order so encode-decode-encode round-trip is byte-stable.
    const ordered = {
        user_id: cursor.user_id,
        created_at: cursor.created_at,
        notification_id: cursor.notification_id,
    };
    return base64urlEncode(JSON.stringify(ordered));
}

/**
 * Decode an opaque cursor back into the `(user_id, created_at,
 * notification_id)` tuple. Throws `InvalidCursorError` on any malformed
 * input — clients must pass back exactly what the server returned.
 */
export function decodeCursor(encoded: string): PaginationCursor {
    if (typeof encoded !== 'string' || encoded.length === 0) {
        throw new InvalidCursorError('Cursor must be a non-empty string');
    }

    let raw: string;
    try {
        raw = base64urlDecode(encoded);
    } catch {
        throw new InvalidCursorError('Cursor is not valid base64url');
    }

    let parsed: unknown;
    try {
        parsed = JSON.parse(raw);
    } catch {
        throw new InvalidCursorError('Cursor payload is not valid JSON');
    }

    if (!parsed || typeof parsed !== 'object') {
        throw new InvalidCursorError('Cursor payload must be a JSON object');
    }

    const obj = parsed as Record<string, unknown>;
    for (const key of CURSOR_KEYS) {
        if (typeof obj[key] !== 'string' || (obj[key] as string).length === 0) {
            throw new InvalidCursorError(
                `Cursor field '${key}' is missing or not a string`,
            );
        }
    }

    return {
        user_id: obj.user_id as string,
        created_at: obj.created_at as string,
        notification_id: obj.notification_id as string,
    };
}

/**
 * Convenience helper used by the repository's pagination layer: build a
 * cursor from a Notification record + the recipient whose page we are
 * paginating. Returns `null` for callers that don't have a next page.
 */
export function cursorFromNotification(args: {
    user_id: string;
    created_at: string;
    notification_id: string;
} | null): string | null {
    if (!args) return null;
    return encodeCursor({
        user_id: args.user_id,
        created_at: args.created_at,
        notification_id: args.notification_id,
    });
}
