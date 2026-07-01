// ============================================================================
// Unit tests — request-input schema validator (Req 17.8 / 17.15)
// ============================================================================
// Spec: offline-license-activation — Task 17.2
//   "Validate every request input before processing; reject schema-invalid
//    input with no persistence."
//   Requirements: 17.8, 17.15
//
// These example-based unit tests exercise the pure validator core directly
// (the property test for "schema validation precedes persistence" is the
// separate task 17.4 / Property 35). They cover the constraint kinds the AWS
// contracts rely on: required/optional, type, bounds, length, enum, pattern,
// and nested array items, plus the aggregate request validator.
// ============================================================================

import {
    FieldSchema,
    validateObject,
    validateRequestParts,
} from '../middleware/schema';

describe('validateObject — required & type (Req 17.8)', () => {
    test('a present, correctly-typed required field passes', () => {
        const schema = { name: { type: 'string', required: true } as FieldSchema };
        const result = validateObject({ name: 'Widget' }, schema, 'body');
        expect(result.ok).toBe(true);
        expect(result.errors).toEqual([]);
    });

    test('a missing required field fails with a clear message', () => {
        const schema = { name: { type: 'string', required: true } as FieldSchema };
        const result = validateObject({}, schema, 'body');
        expect(result.ok).toBe(false);
        expect(result.errors).toContain("'body.name' is required.");
    });

    test('a null required field is treated as missing', () => {
        const schema = { name: { type: 'string', required: true } as FieldSchema };
        const result = validateObject({ name: null }, schema, 'body');
        expect(result.ok).toBe(false);
    });

    test('an absent OPTIONAL field passes (no error)', () => {
        const schema = { note: { type: 'string' } as FieldSchema };
        expect(validateObject({}, schema, 'body').ok).toBe(true);
    });

    test('a wrong-typed field fails the type check', () => {
        const schema = { quantity: { type: 'integer', required: true } as FieldSchema };
        const result = validateObject({ quantity: 'five' }, schema, 'body');
        expect(result.ok).toBe(false);
        expect(result.errors).toContain("'body.quantity' must be of type integer.");
    });

    test('a non-object source reports required fields as missing (no crash)', () => {
        const schema = { name: { type: 'string', required: true } as FieldSchema };
        expect(validateObject(undefined, schema, 'body').ok).toBe(false);
        expect(validateObject('a string', schema, 'body').ok).toBe(false);
        expect(validateObject([], schema, 'body').ok).toBe(false);
    });

    test('unknown keys are ignored (permissive, matching AWS contracts)', () => {
        const schema = { name: { type: 'string', required: true } as FieldSchema };
        const result = validateObject({ name: 'X', extra: 'ignored' }, schema, 'body');
        expect(result.ok).toBe(true);
    });
});

describe('validateObject — numbers, integers, bounds', () => {
    test('integer rejects a non-integer number', () => {
        const schema = { qty: { type: 'integer', required: true } as FieldSchema };
        expect(validateObject({ qty: 1.5 }, schema, 'body').ok).toBe(false);
    });

    test('number rejects NaN/Infinity', () => {
        const schema = { amount: { type: 'number', required: true } as FieldSchema };
        expect(validateObject({ amount: NaN }, schema, 'body').ok).toBe(false);
        expect(validateObject({ amount: Infinity }, schema, 'body').ok).toBe(false);
    });

    test('min / max bounds are inclusive', () => {
        const schema = { n: { type: 'integer', min: 1, max: 3 } as FieldSchema };
        expect(validateObject({ n: 1 }, schema, 'q').ok).toBe(true);
        expect(validateObject({ n: 3 }, schema, 'q').ok).toBe(true);
        expect(validateObject({ n: 0 }, schema, 'q').ok).toBe(false);
        expect(validateObject({ n: 4 }, schema, 'q').ok).toBe(false);
    });
});

describe('validateObject — strings (length / nonEmpty / pattern / enum)', () => {
    test('nonEmpty rejects whitespace-only strings', () => {
        const schema = { s: { type: 'string', nonEmpty: true } as FieldSchema };
        expect(validateObject({ s: '   ' }, schema, 'body').ok).toBe(false);
        expect(validateObject({ s: 'ok' }, schema, 'body').ok).toBe(true);
    });

    test('minLength / maxLength are enforced', () => {
        const schema = { s: { type: 'string', minLength: 2, maxLength: 4 } as FieldSchema };
        expect(validateObject({ s: 'a' }, schema, 'body').ok).toBe(false);
        expect(validateObject({ s: 'abcde' }, schema, 'body').ok).toBe(false);
        expect(validateObject({ s: 'abc' }, schema, 'body').ok).toBe(true);
    });

    test('pattern must fully match', () => {
        const schema = { code: { type: 'string', pattern: /^\d+$/ } as FieldSchema };
        expect(validateObject({ code: '123' }, schema, 'q').ok).toBe(true);
        expect(validateObject({ code: '12a' }, schema, 'q').ok).toBe(false);
    });

    test('enum restricts to the allowed set', () => {
        const schema = { order: { type: 'string', enum: ['ASC', 'DESC'] } as FieldSchema };
        expect(validateObject({ order: 'ASC' }, schema, 'q').ok).toBe(true);
        expect(validateObject({ order: 'sideways' }, schema, 'q').ok).toBe(false);
    });
});

describe('validateObject — arrays and nested items', () => {
    test('array type and minLength', () => {
        const schema = { items: { type: 'array', required: true, minLength: 1 } as FieldSchema };
        expect(validateObject({ items: [] }, schema, 'body').ok).toBe(false);
        expect(validateObject({ items: [1] }, schema, 'body').ok).toBe(true);
        expect(validateObject({ items: 'nope' }, schema, 'body').ok).toBe(false);
    });

    test('each element is validated against the items schema', () => {
        const schema = {
            tags: { type: 'array', items: { type: 'string', nonEmpty: true } } as FieldSchema,
        };
        expect(validateObject({ tags: ['a', 'b'] }, schema, 'body').ok).toBe(true);
        const bad = validateObject({ tags: ['a', ''] }, schema, 'body');
        expect(bad.ok).toBe(false);
        expect(bad.errors.some((e) => e.includes('tags[1]'))).toBe(true);
    });
});

describe('validateRequestParts — aggregate over body/query/params', () => {
    test('collects errors across all parts', () => {
        const result = validateRequestParts(
            { body: {}, query: {}, params: {} },
            {
                body: { name: { type: 'string', required: true } },
                query: { key: { type: 'string', required: true } },
                params: { id: { type: 'string', required: true } },
            },
        );
        expect(result.ok).toBe(false);
        expect(result.errors).toEqual(
            expect.arrayContaining([
                "'body.name' is required.",
                "'query.key' is required.",
                "'params.id' is required.",
            ]),
        );
    });

    test('passes when every declared part is valid', () => {
        const result = validateRequestParts(
            { body: { name: 'X' }, query: { key: 'k' }, params: { id: '1' } },
            {
                body: { name: { type: 'string', required: true } },
                query: { key: { type: 'string', required: true } },
                params: { id: { type: 'string', required: true } },
            },
        );
        expect(result.ok).toBe(true);
        expect(result.errors).toEqual([]);
    });

    test('an empty schema validates anything (uniform pass-through stage)', () => {
        expect(validateRequestParts({ body: { anything: true } }, {}).ok).toBe(true);
    });
});
