// ============================================================================
// schema — a tiny, dependency-free request-input validator
// ============================================================================
// Requirement 17.8 / 17.15: the Local_Backend validates ALL request inputs
// using schema validation BEFORE processing them, and a request whose input
// fails schema validation is rejected WITHOUT persisting any data, returning an
// error response that indicates the validation failure.
//
// Rather than pull in a heavy new dependency (zod/joi/ajv) — none of which the
// packaged backend already bundles — this module provides a minimal,
// allocation-light schema validator that covers exactly the field shapes the
// AWS contracts use (string / number / integer / boolean / array / enum, with
// required/optional, bounds, and pattern checks). It is pure and synchronous,
// so it runs entirely before any handler/store access and is trivial to unit-
// and property-test.
//
// The validator NEVER throws on invalid INPUT — it returns a structured list of
// human-readable error strings. It only throws (a programmer error) if a schema
// itself is malformed, which is caught at module load by the route definitions.
// ============================================================================

/** The primitive kinds a field can declare. */
export type FieldType = 'string' | 'number' | 'integer' | 'boolean' | 'array' | 'object';

/** A single field's validation rules. All bounds are inclusive. */
export interface FieldSchema {
    /** The expected primitive kind. */
    type: FieldType;
    /** Whether the field must be present (and non-null/undefined). Default false. */
    required?: boolean;
    /** For string/array: minimum length. */
    minLength?: number;
    /** For string/array: maximum length. */
    maxLength?: number;
    /** For number/integer: minimum value (inclusive). */
    min?: number;
    /** For number/integer: maximum value (inclusive). */
    max?: number;
    /** Allowed values (enum). The value must be strictly one of these. */
    enum?: ReadonlyArray<string | number>;
    /** For string: a RegExp the value must fully satisfy (via `.test`). */
    pattern?: RegExp;
    /** For array: the schema each element must satisfy. */
    items?: FieldSchema;
    /** Reject empty/whitespace-only strings when true (implies a trimmed check). */
    nonEmpty?: boolean;
}

/** A map of field name → rules for one request part (body/query/params). */
export type ObjectSchema = Record<string, FieldSchema>;

/** The schema for a whole request: any subset of body, query, and params. */
export interface RequestSchema {
    body?: ObjectSchema;
    query?: ObjectSchema;
    params?: ObjectSchema;
}

/** The result of validating a value against a schema. */
export interface ValidationResult {
    ok: boolean;
    /** Human-readable messages, one per failed constraint. Empty when ok. */
    errors: string[];
}

/**
 * Validate a single value against a {@link FieldSchema}, collecting errors into
 * `errors` with a `path` prefix for clear messages. `present` indicates whether
 * the key existed on the source object at all (so we can distinguish "missing"
 * from "explicitly null/undefined").
 */
function validateField(
    path: string,
    value: unknown,
    schema: FieldSchema,
    present: boolean,
    errors: string[],
): void {
    const missing = !present || value === undefined || value === null;

    if (missing) {
        if (schema.required) {
            errors.push(`'${path}' is required.`);
        }
        // Optional + absent → nothing further to check.
        return;
    }

    // ── Type check ──────────────────────────────────────────────────────────
    if (!hasType(value, schema.type)) {
        errors.push(`'${path}' must be of type ${schema.type}.`);
        // Type is wrong; further constraint checks would be meaningless.
        return;
    }

    // ── Enum ──────────────────────────────────────────────────────────────────
    if (schema.enum && !schema.enum.includes(value as string | number)) {
        errors.push(`'${path}' must be one of: ${schema.enum.join(', ')}.`);
    }

    // ── String / array length and string content ────────────────────────────
    if (schema.type === 'string') {
        const s = value as string;
        if (schema.nonEmpty && s.trim().length === 0) {
            errors.push(`'${path}' must not be empty.`);
        }
        if (schema.minLength !== undefined && s.length < schema.minLength) {
            errors.push(`'${path}' must be at least ${schema.minLength} characters.`);
        }
        if (schema.maxLength !== undefined && s.length > schema.maxLength) {
            errors.push(`'${path}' must be at most ${schema.maxLength} characters.`);
        }
        if (schema.pattern && !schema.pattern.test(s)) {
            errors.push(`'${path}' has an invalid format.`);
        }
    }

    // ── Number / integer bounds ───────────────────────────────────────────────
    if (schema.type === 'number' || schema.type === 'integer') {
        const n = value as number;
        if (schema.min !== undefined && n < schema.min) {
            errors.push(`'${path}' must be >= ${schema.min}.`);
        }
        if (schema.max !== undefined && n > schema.max) {
            errors.push(`'${path}' must be <= ${schema.max}.`);
        }
    }

    // ── Array length and element validation ──────────────────────────────────
    if (schema.type === 'array') {
        const arr = value as unknown[];
        if (schema.minLength !== undefined && arr.length < schema.minLength) {
            errors.push(`'${path}' must contain at least ${schema.minLength} item(s).`);
        }
        if (schema.maxLength !== undefined && arr.length > schema.maxLength) {
            errors.push(`'${path}' must contain at most ${schema.maxLength} item(s).`);
        }
        if (schema.items) {
            arr.forEach((element, index) => {
                validateField(`${path}[${index}]`, element, schema.items as FieldSchema, true, errors);
            });
        }
    }
}

/** Strict runtime type predicate for the supported field kinds. */
function hasType(value: unknown, type: FieldType): boolean {
    switch (type) {
        case 'string':
            return typeof value === 'string';
        case 'boolean':
            return typeof value === 'boolean';
        case 'number':
            return typeof value === 'number' && Number.isFinite(value);
        case 'integer':
            return typeof value === 'number' && Number.isInteger(value);
        case 'array':
            return Array.isArray(value);
        case 'object':
            return typeof value === 'object' && value !== null && !Array.isArray(value);
        default:
            return false;
    }
}

/**
 * Validate a plain object against an {@link ObjectSchema}. Unknown keys are
 * ignored (a permissive posture matching the AWS contracts, which tolerate
 * extra fields); only declared fields are constraint-checked. A non-object
 * source is treated as an empty object so that required fields are reported as
 * missing rather than crashing.
 */
export function validateObject(source: unknown, schema: ObjectSchema, label: string): ValidationResult {
    const errors: string[] = [];
    const obj: Record<string, unknown> =
        source !== null && typeof source === 'object' && !Array.isArray(source)
            ? (source as Record<string, unknown>)
            : {};

    for (const [field, rules] of Object.entries(schema)) {
        const present = Object.prototype.hasOwnProperty.call(obj, field);
        validateField(`${label}.${field}`, obj[field], rules, present, errors);
    }

    return { ok: errors.length === 0, errors };
}

/**
 * Validate an entire request (body/query/params) against a {@link RequestSchema}.
 * Returns the aggregate result; `errors` is the concatenation of every part's
 * failures, so a caller can reject once with all problems listed.
 */
export function validateRequestParts(
    parts: { body?: unknown; query?: unknown; params?: unknown },
    schema: RequestSchema,
): ValidationResult {
    const errors: string[] = [];

    if (schema.body) {
        errors.push(...validateObject(parts.body, schema.body, 'body').errors);
    }
    if (schema.query) {
        errors.push(...validateObject(parts.query, schema.query, 'query').errors);
    }
    if (schema.params) {
        errors.push(...validateObject(parts.params, schema.params, 'params').errors);
    }

    return { ok: errors.length === 0, errors };
}
