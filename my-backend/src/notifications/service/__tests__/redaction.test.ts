// ============================================================================
// UNS — Payload redaction tests (Task 16.4)
// ============================================================================
// Validates: REQ 12.8 — payloads MUST NOT include secret values, full PAN,
// or full government-issued identifiers; only redacted references.
//
// Coverage:
//   1. Luhn validation (valid / invalid)
//   2. Credit-card detection — flags Luhn-valid, ignores Luhn-invalid
//   3. PAN (Indian) detection
//   4. Aadhaar detection (with separator variants)
//   5. Bearer token detection
//   6. AWS access key detection
//   7. Sensitive-key-name detection (token, password, secret, ...)
//   8. Recursion through nested objects and arrays
//   9. Redacted reference shape (`****<last4>` / `[REDACTED]`)
//  10. Immutability of input
//  11. Configurable detector toggles (test-only loosening)
// ============================================================================

import { describe, expect, test } from '@jest/globals';
import {
    containsSensitiveValues,
    findSensitiveOccurrences,
    isLuhnValid,
    redactPayload,
    redactString,
    REDACTION_PATTERN,
    STRICT_REDACTION_CONFIG,
} from '../redaction';

// ----------------------------------------------------------------------------
// Luhn primitive
// ----------------------------------------------------------------------------

describe('redaction — Luhn checksum', () => {
    test('accepts canonical test card numbers (Luhn-valid)', () => {
        // Industry-standard PAN test sequences (none refer to a real
        // cardholder; they are the fixed values published by every
        // payment processor for reproducible test fixtures).
        expect(isLuhnValid('4111111111111111')).toBe(true);  // Visa 16
        expect(isLuhnValid('5500000000000004')).toBe(true);  // MasterCard 16
        expect(isLuhnValid('340000000000009')).toBe(true);   // Amex 15
        expect(isLuhnValid('6011000000000004')).toBe(true);  // Discover 16
        expect(isLuhnValid('30000000000004')).toBe(true);    // Diners 14
    });

    test('rejects digit sequences that fail the Luhn checksum', () => {
        expect(isLuhnValid('4111111111111112')).toBe(false);
        expect(isLuhnValid('1234567890123456')).toBe(false);
        expect(isLuhnValid('0000000000000001')).toBe(false);
    });

    test('rejects sequences shorter than 13 or longer than 19 digits', () => {
        expect(isLuhnValid('411111111112')).toBe(false);            // 12 digits
        expect(isLuhnValid('41111111111111111111')).toBe(false);    // 20 digits
    });

    test('rejects strings containing non-digit characters', () => {
        expect(isLuhnValid('4111-1111-1111-1111')).toBe(false);
        expect(isLuhnValid('4111 1111 1111 1111')).toBe(false);
        expect(isLuhnValid('411111111111111X')).toBe(false);
    });

    test('rejects empty string', () => {
        expect(isLuhnValid('')).toBe(false);
    });
});

// ----------------------------------------------------------------------------
// String-level detection
// ----------------------------------------------------------------------------

describe('redaction — credit card detection', () => {
    test('redacts a Luhn-valid 16-digit card to ****<last4>', () => {
        const input = 'Card 4111111111111111 was charged';
        expect(redactString(input)).toBe('Card ****1111 was charged');
    });

    test('redacts a Luhn-valid card with hyphen separators', () => {
        const input = 'pan=4111-1111-1111-1111';
        expect(redactString(input)).toBe('pan=****1111');
    });

    test('redacts a Luhn-valid card with space separators', () => {
        const input = 'pan=4111 1111 1111 1111';
        expect(redactString(input)).toBe('pan=****1111');
    });

    test('does NOT redact a 16-digit sequence that fails Luhn', () => {
        const input = 'order id 1234567890123456 dispatched';
        expect(redactString(input)).toBe(input);
    });

    test('reports a Luhn-valid card as a sensitive occurrence', () => {
        const occ = findSensitiveOccurrences({ note: '4111111111111111' });
        expect(occ).toHaveLength(1);
        expect(occ[0].pattern).toBe(REDACTION_PATTERN.CREDIT_CARD);
        expect(occ[0].path).toBe('note');
        expect(occ[0].match).toBe('4111111111111111');
    });

    test('does NOT report a Luhn-invalid 16-digit run', () => {
        const occ = findSensitiveOccurrences({ orderId: '1234567890123456' });
        expect(occ).toHaveLength(0);
    });

    test('redacts an Amex-style 15-digit card', () => {
        const out = redactString('Card 340000000000009 was charged');
        expect(out).toBe('Card ****0009 was charged');
    });
});

// ----------------------------------------------------------------------------

describe('redaction — Indian PAN detection', () => {
    test('redacts a canonical PAN (5 letters, 4 digits, 1 letter)', () => {
        const input = 'PAN: ABCDE1234F filed on 31 Mar';
        expect(redactString(input)).toBe('PAN: ****234F filed on 31 Mar');
    });

    test('reports a PAN as a sensitive occurrence', () => {
        const occ = findSensitiveOccurrences({ pan: 'ABCDE1234F' });
        expect(occ).toHaveLength(1);
        expect(occ[0].pattern).toBe(REDACTION_PATTERN.PAN_INDIA);
        expect(occ[0].path).toBe('pan');
    });

    test('does NOT flag a string that almost-but-not-quite matches PAN', () => {
        // 4 letters, 4 digits, 1 letter — fails PAN shape.
        expect(findSensitiveOccurrences({ x: 'ABCD1234F' })).toHaveLength(0);
        // All lowercase — PAN must be uppercase.
        expect(findSensitiveOccurrences({ x: 'abcde1234f' })).toHaveLength(0);
    });
});

// ----------------------------------------------------------------------------

describe('redaction — Aadhaar detection', () => {
    test('redacts a 12-digit Aadhaar without separators', () => {
        // Use a non-Luhn-valid 12-digit run so the credit-card detector
        // does not steal the match.
        expect(redactString('Aadhaar 123412341235')).toBe('Aadhaar ****1235');
    });

    test('redacts a 12-digit Aadhaar with space separators', () => {
        expect(redactString('Aadhaar 1234 1234 1235')).toBe('Aadhaar ****1235');
    });

    test('redacts a 12-digit Aadhaar with hyphen separators', () => {
        expect(redactString('Aadhaar 1234-1234-1235')).toBe('Aadhaar ****1235');
    });

    test('reports an Aadhaar as a sensitive occurrence', () => {
        const occ = findSensitiveOccurrences({ aadhaar: '1234 1234 1235' });
        expect(occ).toHaveLength(1);
        expect(occ[0].pattern).toBe(REDACTION_PATTERN.AADHAAR);
    });

    test('does NOT double-flag a 12-digit run that would also match credit-card shape', () => {
        // The credit-card regex requires ≥13 digits, so a 12-digit run is
        // owned exclusively by the Aadhaar pattern. This test pins that
        // contract: a 12-digit string is reported as Aadhaar, never as
        // both Aadhaar and credit_card.
        const occ = findSensitiveOccurrences({ x: '100000000018' });
        expect(occ).toHaveLength(1);
        expect(occ[0].pattern).toBe(REDACTION_PATTERN.AADHAAR);
    });
});

// ----------------------------------------------------------------------------

describe('redaction — Bearer token detection', () => {
    test('redacts a Bearer JWT-shaped token', () => {
        const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJhYmMifQ.signature1234567';
        const input = `Authorization: Bearer ${jwt}`;
        expect(redactString(input)).toBe('Authorization: [REDACTED]');
    });

    test('redacts a Bearer opaque token of ≥16 chars', () => {
        const input = 'Bearer abcdef0123456789xyz';
        expect(redactString(input)).toBe('[REDACTED]');
    });

    test('does NOT redact short non-token strings starting with "Bearer "', () => {
        // The regex requires ≥16 chars to avoid flagging the literal phrase.
        const input = 'Bearer brief';
        expect(redactString(input)).toBe(input);
    });

    test('reports a Bearer token as a sensitive occurrence', () => {
        const occ = findSensitiveOccurrences({
            note: 'Bearer abcdef0123456789xyz',
        });
        expect(occ).toHaveLength(1);
        expect(occ[0].pattern).toBe(REDACTION_PATTERN.BEARER_TOKEN);
    });
});

// ----------------------------------------------------------------------------

describe('redaction — AWS access key detection', () => {
    test('redacts an AKIA-prefixed access key', () => {
        const input = 'access=AKIAIOSFODNN7EXAMPLE detected';
        expect(redactString(input)).toBe('access=[REDACTED] detected');
    });

    test('reports an AWS access key as a sensitive occurrence', () => {
        const occ = findSensitiveOccurrences({
            cred: 'AKIAIOSFODNN7EXAMPLE',
        });
        expect(occ).toHaveLength(1);
        expect(occ[0].pattern).toBe(REDACTION_PATTERN.AWS_ACCESS_KEY);
    });

    test('does NOT flag a non-AKIA prefixed 20-char run', () => {
        // 20 uppercase characters but no `AKIA` prefix.
        expect(findSensitiveOccurrences({ x: 'ZZZZIOSFODNN7EXAMPLE' }))
            .toHaveLength(0);
    });
});

// ----------------------------------------------------------------------------

describe('redaction — sensitive-key-name detection', () => {
    test('redacts the value when the key name says "token"', () => {
        const out = redactPayload({ token: 'short-but-secret' });
        expect(out).toEqual({ token: '[REDACTED]' });
    });

    test('redacts the value when the key name says "password"', () => {
        const out = redactPayload({ password: 'p@ssw0rd!' });
        expect(out).toEqual({ password: '[REDACTED]' });
    });

    test('redacts the value when the key name contains "secret"', () => {
        const out = redactPayload({ clientSecret: 'abc123' });
        expect(out).toEqual({ clientSecret: '[REDACTED]' });
    });

    test('redacts the value when the key name contains "apikey"', () => {
        const out = redactPayload({ apiKey: 'xyz' });
        expect(out).toEqual({ apiKey: '[REDACTED]' });
    });

    test('reports a sensitive-named field as an occurrence', () => {
        const occ = findSensitiveOccurrences({ password: 'short' });
        expect(occ).toHaveLength(1);
        expect(occ[0].pattern).toBe(REDACTION_PATTERN.SENSITIVE_KEY_VALUE);
        expect(occ[0].path).toBe('password');
    });

    test('does NOT flag a sensitive-named field with empty / null value', () => {
        // An empty / null sensitive field is not a leak; flagging it
        // would force every form to nullify before publish, which is
        // user-hostile.
        expect(findSensitiveOccurrences({ token: '' })).toHaveLength(0);
        expect(findSensitiveOccurrences({ token: null })).toHaveLength(0);
        expect(findSensitiveOccurrences({ token: undefined })).toHaveLength(0);
    });

    test('does NOT match unrelated keys that contain coincidental substrings', () => {
        // The list is deliberately conservative; a field called `notes`
        // or `description` should not be redacted.
        const out = redactPayload({ notes: 'this is fine', description: 'x' });
        expect(out).toEqual({ notes: 'this is fine', description: 'x' });
    });
});

// ----------------------------------------------------------------------------
// Recursion
// ----------------------------------------------------------------------------

describe('redaction — recursion through nested objects and arrays', () => {
    test('redacts a deeply nested credit card', () => {
        const input = {
            outer: {
                middle: {
                    inner: { card: '4111111111111111' },
                },
            },
        };
        const out = redactPayload(input);
        expect(
            (
                (
                    (out.outer as Record<string, unknown>)
                        .middle as Record<string, unknown>
                ).inner as Record<string, unknown>
            ).card,
        ).toBe('****1111');
    });

    test('reports a deeply nested PAN with a dotted path', () => {
        const occ = findSensitiveOccurrences({
            customer: { kyc: { pan: 'ABCDE1234F' } },
        });
        expect(occ).toHaveLength(1);
        expect(occ[0].path).toBe('customer.kyc.pan');
        expect(occ[0].pattern).toBe(REDACTION_PATTERN.PAN_INDIA);
    });

    test('redacts cards inside arrays of objects', () => {
        const input = {
            cards: [
                { number: '4111111111111111' },
                { number: '5500000000000004' },
            ],
        };
        const out = redactPayload(input);
        expect(out.cards).toEqual([
            { number: '****1111' },
            { number: '****0004' },
        ]);
    });

    test('reports array element paths as [index]', () => {
        const occ = findSensitiveOccurrences({
            cards: [{ number: '4111111111111111' }],
        });
        expect(occ).toHaveLength(1);
        expect(occ[0].path).toBe('cards[0].number');
    });

    test('handles arrays of strings', () => {
        const out = redactPayload({
            tags: ['safe', '4111111111111111', 'also-safe'],
        });
        expect(out.tags).toEqual(['safe', '****1111', 'also-safe']);
    });

    test('non-string primitives pass through untouched', () => {
        const out = redactPayload({
            count: 42,
            active: true,
            ratio: 3.14,
            zero: 0,
            big: BigInt('100'),
        });
        expect(out.count).toBe(42);
        expect(out.active).toBe(true);
        expect(out.ratio).toBe(3.14);
        expect(out.zero).toBe(0);
        expect(out.big).toBe(BigInt('100'));
    });

    test('null and undefined pass through untouched', () => {
        const out = redactPayload({ a: null, b: undefined });
        expect(out.a).toBeNull();
        expect(out.b).toBeUndefined();
    });

    test('cycles do not cause infinite recursion', () => {
        type Cyclic = { name: string; self?: Cyclic };
        const input: Cyclic = { name: 'safe' };
        input.self = input;
        const out = redactPayload(
            input as unknown as Record<string, unknown>,
        );
        expect(out.name).toBe('safe');
        expect(out.self).toBeNull();
    });
});

// ----------------------------------------------------------------------------
// Redacted reference shape
// ----------------------------------------------------------------------------

describe('redaction — redacted reference shape', () => {
    test('credit card → ****<last4>', () => {
        expect(redactString('4111111111111111')).toBe('****1111');
    });

    test('PAN → ****<last4>', () => {
        expect(redactString('ABCDE1234F')).toBe('****234F');
    });

    test('Aadhaar → ****<last4>', () => {
        expect(redactString('1234 1234 1235')).toBe('****1235');
    });

    test('Bearer token → [REDACTED]', () => {
        expect(redactString('Bearer abcdef0123456789xyz')).toBe('[REDACTED]');
    });

    test('AWS access key → [REDACTED]', () => {
        expect(redactString('AKIAIOSFODNN7EXAMPLE')).toBe('[REDACTED]');
    });

    test('sensitive-key-name value → [REDACTED]', () => {
        const out = redactPayload({ apiKey: 'short' });
        expect(out.apiKey).toBe('[REDACTED]');
    });
});

// ----------------------------------------------------------------------------
// Immutability
// ----------------------------------------------------------------------------

describe('redaction — immutability of input', () => {
    test('does not mutate the input object', () => {
        const input = {
            card: '4111111111111111',
            nested: { pan: 'ABCDE1234F' },
        };
        const before = JSON.parse(JSON.stringify(input));
        redactPayload(input);
        expect(input).toEqual(before);
    });

    test('returns a new object reference', () => {
        const input = { foo: 'bar' };
        const out = redactPayload(input);
        expect(out).not.toBe(input);
    });

    test('returns new nested object references when redacting', () => {
        const inner = { pan: 'ABCDE1234F' };
        const input = { wrapper: inner };
        const out = redactPayload(input);
        expect(out.wrapper).not.toBe(inner);
        expect((out.wrapper as Record<string, string>).pan).toBe('****234F');
    });

    test('returns new array references', () => {
        const arr = ['4111111111111111', 'safe'];
        const input = { items: arr };
        const out = redactPayload(input);
        expect(out.items).not.toBe(arr);
        expect(out.items).toEqual(['****1111', 'safe']);
    });
});

// ----------------------------------------------------------------------------
// Configurable detector toggles
// ----------------------------------------------------------------------------

describe('redaction — configurable detector toggles', () => {
    test('strict config enables every detector', () => {
        expect(STRICT_REDACTION_CONFIG.creditCard).toBe(true);
        expect(STRICT_REDACTION_CONFIG.panIndia).toBe(true);
        expect(STRICT_REDACTION_CONFIG.aadhaar).toBe(true);
        expect(STRICT_REDACTION_CONFIG.bearerToken).toBe(true);
        expect(STRICT_REDACTION_CONFIG.awsAccessKey).toBe(true);
        expect(STRICT_REDACTION_CONFIG.sensitiveKeyValue).toBe(true);
    });

    test('disabling creditCard skips Luhn-valid card detection', () => {
        const cfg = { ...STRICT_REDACTION_CONFIG, creditCard: false };
        expect(redactString('4111111111111111', cfg)).toBe('4111111111111111');
        expect(findSensitiveOccurrences('4111111111111111', cfg)).toHaveLength(0);
    });

    test('disabling panIndia skips PAN detection', () => {
        const cfg = { ...STRICT_REDACTION_CONFIG, panIndia: false };
        expect(redactString('ABCDE1234F', cfg)).toBe('ABCDE1234F');
    });

    test('disabling sensitiveKeyValue allows raw values under sensitive keys', () => {
        const cfg = { ...STRICT_REDACTION_CONFIG, sensitiveKeyValue: false };
        const out = redactPayload({ token: 'opaque-value' }, cfg);
        expect(out).toEqual({ token: 'opaque-value' });
    });
});

// ----------------------------------------------------------------------------
// containsSensitiveValues helper
// ----------------------------------------------------------------------------

describe('redaction — containsSensitiveValues helper', () => {
    test('returns true when any pattern matches', () => {
        expect(containsSensitiveValues({ pan: 'ABCDE1234F' })).toBe(true);
    });

    test('returns false on a fully clean payload', () => {
        expect(
            containsSensitiveValues({
                customerName: 'Alice',
                amount: '500.00',
                invoiceNo: 'INV-001',
            }),
        ).toBe(false);
    });

    test('returns false on null / undefined / empty', () => {
        expect(containsSensitiveValues(null)).toBe(false);
        expect(containsSensitiveValues(undefined)).toBe(false);
        expect(containsSensitiveValues({})).toBe(false);
    });
});

// ----------------------------------------------------------------------------
// Realistic scenarios
// ----------------------------------------------------------------------------

describe('redaction — realistic notification payloads', () => {
    test('realistic invoice payload has no false positives', () => {
        const input = {
            customerName: 'Alice',
            invoiceNo: 'INV-2024-001',
            amount: '500.00',
            shopName: 'DukanX',
            items: [
                { name: 'Widget', qty: 2 },
                { name: 'Sprocket', qty: 1 },
            ],
            metadata: {
                tags: ['urgent'],
                priority: 'high',
            },
        };
        expect(findSensitiveOccurrences(input)).toHaveLength(0);
        expect(redactPayload(input)).toEqual(input);
    });

    test('payload with a card and a PAN reports both', () => {
        const input = {
            customer: { name: 'Alice', pan: 'ABCDE1234F' },
            payment: { card: '4111111111111111' },
        };
        const occ = findSensitiveOccurrences(input);
        expect(occ).toHaveLength(2);
        const patterns = occ.map((o) => o.pattern).sort();
        expect(patterns).toEqual(
            [REDACTION_PATTERN.CREDIT_CARD, REDACTION_PATTERN.PAN_INDIA].sort(),
        );
        const paths = occ.map((o) => o.path).sort();
        expect(paths).toEqual(['customer.pan', 'payment.card']);
    });

    test('payload with an Authorization Bearer header is redacted', () => {
        const input = {
            requestHeaders: {
                Authorization: 'Bearer abcdef0123456789xyz',
                'Content-Type': 'application/json',
            },
        };
        const out = redactPayload(input);
        // Either the bearer-token pattern or the sensitive-key-value
        // pattern (or both) will redact this. The end state is that the
        // raw token does NOT appear.
        const stringified = JSON.stringify(out);
        expect(stringified).not.toContain('abcdef0123456789xyz');
        expect(stringified).toContain('[REDACTED]');
    });
});
