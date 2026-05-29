// ============================================================================
// UNS — Payload sanitization tests (Task 16.2)
// ============================================================================
// Validates: REQ 12.2 — payload sanitization is applied unconditionally and
// removes scripting tags and control characters before persistence and
// before delivery.
//
// Coverage:
//   1. HTML `<script>` block removal (with content)
//   2. `javascript:` URL scheme stripping (and vbscript, data)
//   3. `on*=` event-handler attribute stripping
//   4. C0/C1 control-character stripping (preserves \n, \r, \t)
//   5. Nested object recursion
//   6. Array recursion
//   7. Non-string primitives untouched (number, boolean, null, bigint)
//   8. Immutability of input
// ============================================================================

import { describe, expect, test } from '@jest/globals';
import {
    sanitizePayload,
    sanitizeString,
} from '../sanitization';

describe('sanitization — sanitizeString', () => {
    test('strips <script> blocks including their content', () => {
        const input = 'hello <script>alert(1)</script> world';
        expect(sanitizeString(input)).toBe('hello  world');
    });

    test('strips <script src="..."> with attributes and no body', () => {
        const input = 'before <script src="evil.js"></script> after';
        expect(sanitizeString(input)).toBe('before  after');
    });

    test('strips self-closing / unclosed <script> tags', () => {
        // `<script src="x"/>` and `<script>` with no closing pair both
        // collapse to end-of-string under SCRIPT_BLOCK_RE — that is the
        // safer choice when faced with attacker-controlled markup. Text
        // that follows an unclosed `<script` opener is dropped along
        // with the tag rather than re-rendered.
        const a = 'a<script src="x"/>b';
        const b = 'a<script>b'; // never closed
        expect(sanitizeString(a)).toBe('a');
        expect(sanitizeString(b)).toBe('a');
    });

    test('strips other HTML tags but keeps inner text', () => {
        const input = 'hello <b>brave</b> <em>new</em> world';
        expect(sanitizeString(input)).toBe('hello brave new world');
    });

    test('strips javascript: URL scheme', () => {
        const input = 'click javascript:alert(1) here';
        // The "javascript:" marker is removed; the rest is preserved.
        expect(sanitizeString(input)).toBe('click alert(1) here');
    });

    test('strips vbscript: and data: URL schemes', () => {
        expect(sanitizeString('vbscript:msgbox(1)')).toBe('msgbox(1)');
        expect(sanitizeString('data:text/html,<b>x</b>')).toBe('text/html,x');
    });

    test('strips on*= event-handler attributes (double quotes)', () => {
        const input = 'before onclick="alert(1)" after';
        expect(sanitizeString(input)).toBe('before  after');
    });

    test('strips on*= event-handler attributes (single quotes)', () => {
        const input = "before onerror='alert(1)' after";
        expect(sanitizeString(input)).toBe('before  after');
    });

    test('strips on*= event-handler attributes (no quotes)', () => {
        const input = 'before onmouseover=alert(1) after';
        expect(sanitizeString(input)).toBe('before  after');
    });

    test('strips C0 control characters (0x00–0x08)', () => {
        const input = 'a\x00b\x01c\x07d\x08e';
        expect(sanitizeString(input)).toBe('abcde');
    });

    test('strips C0 control characters (0x0B, 0x0C)', () => {
        // 0x0B (vertical tab), 0x0C (form feed)
        const input = 'a\x0Bb\x0Cc';
        expect(sanitizeString(input)).toBe('abc');
    });

    test('strips C0/C1 control characters (0x0E–0x1F, 0x7F)', () => {
        const input = `a\x0Eb\x1Fc\x7Fd`;
        expect(sanitizeString(input)).toBe('abcd');
    });

    test('preserves \\n, \\r, \\t whitespace runs', () => {
        const input = 'line1\nline2\tindent\rcr';
        expect(sanitizeString(input)).toBe('line1\nline2\tindent\rcr');
    });

    test('preserves regular text untouched', () => {
        const text = 'Plain text with numbers 123 and symbols !@#$%^&*()';
        expect(sanitizeString(text)).toBe(text);
    });

    test('handles deeply nested malicious markup', () => {
        const input = '<div><p>hello<script>alert(1)</script></p></div>';
        expect(sanitizeString(input)).toBe('hello');
    });

    test('returns non-strings as-is (defensive guard)', () => {
        expect(sanitizeString(42 as unknown as string)).toBe(42);
        expect(sanitizeString(null as unknown as string)).toBe(null);
    });
});

describe('sanitization — sanitizePayload (recursion)', () => {
    test('recurses through nested objects', () => {
        const input = {
            outer: {
                middle: {
                    inner: '<script>bad()</script>safe',
                },
            },
        };
        const out = sanitizePayload(input);
        expect(
            (out.outer as Record<string, Record<string, string>>).middle.inner,
        ).toBe('safe');
    });

    test('recurses through arrays of strings', () => {
        const input = {
            list: ['<b>one</b>', 'two', '<script>x</script>three'],
        };
        const out = sanitizePayload(input);
        expect(out.list).toEqual(['one', 'two', 'three']);
    });

    test('recurses through arrays of objects', () => {
        const input = {
            items: [
                { title: '<i>a</i>', body: 'plain' },
                { title: 'b', body: '<script>evil()</script>clean' },
            ],
        };
        const out = sanitizePayload(input);
        expect(out.items).toEqual([
            { title: 'a', body: 'plain' },
            { title: 'b', body: 'clean' },
        ]);
    });

    test('recurses through arrays of arrays', () => {
        const input = {
            matrix: [
                ['<u>row1col1</u>', 'row1col2'],
                ['row2col1', '<script>x</script>row2col2'],
            ],
        };
        const out = sanitizePayload(input);
        expect(out.matrix).toEqual([
            ['row1col1', 'row1col2'],
            ['row2col1', 'row2col2'],
        ]);
    });

    test('sanitizes object keys that contain scripting markup', () => {
        const input = {
            '<script>k</script>safekey': 'value',
        };
        const out = sanitizePayload(input);
        expect(Object.keys(out)).toEqual(['safekey']);
        expect(out.safekey).toBe('value');
    });
});

describe('sanitization — non-string primitives untouched', () => {
    test('numbers pass through', () => {
        const out = sanitizePayload({ count: 42, price: 3.14 });
        expect(out.count).toBe(42);
        expect(out.price).toBe(3.14);
    });

    test('booleans pass through', () => {
        const out = sanitizePayload({ active: true, disabled: false });
        expect(out.active).toBe(true);
        expect(out.disabled).toBe(false);
    });

    test('null passes through', () => {
        const out = sanitizePayload({ optional: null });
        expect(out.optional).toBeNull();
    });

    test('bigint passes through', () => {
        const out = sanitizePayload({ huge: BigInt('9007199254740993') });
        expect(out.huge).toBe(BigInt('9007199254740993'));
    });

    test('ISO timestamp strings remain untouched', () => {
        const iso = '2024-06-15T10:30:00.000Z';
        const out = sanitizePayload({ created_at: iso });
        expect(out.created_at).toBe(iso);
    });

    test('mixed primitives + dirty strings — only strings change', () => {
        const out = sanitizePayload({
            id: 1,
            name: '<script>x</script>Alice',
            active: true,
            score: null,
        });
        expect(out.id).toBe(1);
        expect(out.name).toBe('Alice');
        expect(out.active).toBe(true);
        expect(out.score).toBeNull();
    });
});

describe('sanitization — immutability of input', () => {
    test('does not mutate the input object', () => {
        const input = {
            title: '<script>bad()</script>Original',
            nested: { key: 'value' },
        };
        const before = JSON.parse(JSON.stringify(input));
        sanitizePayload(input);
        expect(input).toEqual(before);
    });

    test('returns a new object reference', () => {
        const input = { foo: 'bar' };
        const out = sanitizePayload(input);
        expect(out).not.toBe(input);
    });

    test('returns new nested object references', () => {
        const inner = { key: 'value' };
        const input = { wrapper: inner };
        const out = sanitizePayload(input);
        expect(out.wrapper).not.toBe(inner);
    });

    test('returns new array references', () => {
        const arr = ['a', 'b'];
        const input = { items: arr };
        const out = sanitizePayload(input);
        expect(out.items).not.toBe(arr);
    });

    test('does not mutate nested arrays in input', () => {
        const input = {
            items: ['<b>one</b>', 'two'],
        };
        const before = [...input.items];
        sanitizePayload(input);
        expect(input.items).toEqual(before);
    });
});

describe('sanitization — defense-in-depth edge cases', () => {
    test('empty payload yields empty payload', () => {
        expect(sanitizePayload({})).toEqual({});
    });

    test('payload with only safe data is untouched in shape', () => {
        const input = {
            customerName: 'Alice',
            invoiceNo: 'INV-001',
            amount: '500.00',
        };
        expect(sanitizePayload(input)).toEqual(input);
    });

    test('cycles do not cause infinite recursion', () => {
        type Cyclic = { name: string; self?: Cyclic };
        const input: Cyclic = { name: 'safe' };
        input.self = input;
        // Should not throw / hang; cycle collapses to null.
        const out = sanitizePayload(
            input as unknown as Record<string, unknown>,
        );
        expect(out.name).toBe('safe');
        expect(out.self).toBeNull();
    });

    test('functions in payload are dropped', () => {
        const input = {
            safe: 'value',
            evil: () => 'pwned',
        };
        const out = sanitizePayload(input);
        expect(out.safe).toBe('value');
        expect('evil' in out).toBe(false);
    });

    test('Date objects are cloned to a fresh Date', () => {
        const date = new Date('2024-01-01T00:00:00.000Z');
        const out = sanitizePayload({ when: date });
        expect(out.when).toBeInstanceOf(Date);
        expect((out.when as Date).getTime()).toBe(date.getTime());
        expect(out.when).not.toBe(date);
    });

    test('handles a realistic bill notification payload', () => {
        const input = {
            customerName: 'Alice<script>steal()</script>',
            invoiceNo: 'INV-001',
            amount: '500.00',
            shopName: 'DukanX',
            link: 'javascript:alert(1)',
            items: [
                { name: 'Widget<b>!</b>', qty: 2 },
                { name: 'Sprocket', qty: 1 },
            ],
            metadata: {
                tags: ['urgent', '<i>VIP</i>'],
                priority: 'high',
            },
            __null_byte: 'before\x00after',
        };
        const out = sanitizePayload(input);
        expect(out.customerName).toBe('Alice');
        expect(out.invoiceNo).toBe('INV-001');
        expect(out.link).toBe('alert(1)');
        expect((out.items as Array<{ name: string; qty: number }>)[0])
            .toEqual({ name: 'Widget!', qty: 2 });
        expect((out.metadata as { tags: string[]; priority: string }).tags)
            .toEqual(['urgent', 'VIP']);
        expect(out.__null_byte).toBe('beforeafter');
    });

    test('returns empty object for non-object input (defensive guard)', () => {
        expect(
            sanitizePayload(null as unknown as Record<string, unknown>),
        ).toEqual({});
        expect(
            sanitizePayload(
                undefined as unknown as Record<string, unknown>,
            ),
        ).toEqual({});
        expect(
            sanitizePayload(
                'string' as unknown as Record<string, unknown>,
            ),
        ).toEqual({});
    });
});
