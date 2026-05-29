// ============================================================================
// UNS Event_Bus — Event_Contract JSON Schema Validator
// ============================================================================
// Loads the canonical Event_Contract JSON Schema from the shared SDK package
// (`packages/notifications-sdk/event-contract.schema.json`) at module init
// time, compiles it once via Ajv (Draft 2020-12), and exposes a per-publish
// validate function.
//
// Why JSON Schema 2020-12: the schema file declares
//   "$schema": "https://json-schema.org/draft/2020-12/schema"
// so we must use Ajv's 2020-12 entry point — the default `ajv` import targets
// Draft-07 and would silently reject the 2020-12 vocabularies.
//
// Validates: REQ 3.6 (reject schema-invalid publish with structured error),
//            REQ 8.1 (single Event_Contract source of truth),
//            REQ 8.7 (sub_app publish rejection names offending fields).
// ============================================================================

import * as fs from 'fs';
import * as path from 'path';
import Ajv2020, { type ErrorObject, type ValidateFunction } from 'ajv/dist/2020';
import addFormats from 'ajv-formats';
import { logger } from '../../utils/logger';
import { EventContractValidationError } from './errors';
import type { EventContract, ValidationIssue } from './types';

// ---------------------------------------------------------------------------
// Schema location resolution
// ---------------------------------------------------------------------------
// The schema lives outside `my-backend/src/`, so the compiled output under
// `dist/` cannot reference it by relative path. We resolve at runtime in this
// fixed order:
//   1. Explicit override via `UNS_EVENT_CONTRACT_SCHEMA_PATH`.
//   2. Default monorepo layout: `<workspace>/packages/notifications-sdk/event-contract.schema.json`.
// The schema file is small (≤ 10 KB) so a single sync read at module load is
// fine and avoids race conditions in concurrent Lambda invocations.

const ENV_SCHEMA_PATH = 'UNS_EVENT_CONTRACT_SCHEMA_PATH';
const SCHEMA_FILENAME = 'event-contract.schema.json';
const SDK_RELATIVE_PATH = path.join('packages', 'notifications-sdk', SCHEMA_FILENAME);

function resolveSchemaPath(): string {
    const override = process.env[ENV_SCHEMA_PATH];
    if (override && override.trim().length > 0) {
        return path.resolve(override);
    }

    // Walk up from this file looking for the workspace root that contains
    // `packages/notifications-sdk/`. Works whether running from `src/` or
    // `dist/`. We search up to 6 levels which comfortably covers
    // `<root>/my-backend/src/notifications/event-bus/schema-validator.ts`.
    // Depth 8 is the loop bound (slightly more than 6) so symlinks or
    // unusual layouts still resolve before the cwd fallback.
    let dir = __dirname;
    for (let depth = 0; depth < 8; depth++) {
        const candidate = path.join(dir, SDK_RELATIVE_PATH);
        if (fs.existsSync(candidate)) {
            return candidate;
        }
        const parent = path.dirname(dir);
        if (parent === dir) break;
        dir = parent;
    }

    // Last-resort fallback to current working directory; surfaces a clearer
    // error than "ENOENT" if the schema is genuinely missing in production.
    return path.resolve(process.cwd(), SDK_RELATIVE_PATH);
}

// ---------------------------------------------------------------------------
// Ajv compile (once, at module init time)
// ---------------------------------------------------------------------------

interface CompiledValidator {
    schemaId: string;
    validate: ValidateFunction<EventContract>;
}

let cached: CompiledValidator | null = null;

function compile(): CompiledValidator {
    if (cached) return cached;

    const schemaPath = resolveSchemaPath();
    const raw = fs.readFileSync(schemaPath, 'utf8');
    const schema = JSON.parse(raw) as Record<string, unknown>;

    const ajv = new Ajv2020({
        allErrors: true,         // collect every issue per REQ 8.7 (name offending fields)
        strict: false,           // schema uses `description` heavily; strict mode flags those
        allowUnionTypes: true,   // `target_id` is `["string", "null"]`
        useDefaults: false,      // never mutate caller payload
        coerceTypes: false,      // never silently coerce, surface validation errors instead
    });
    addFormats(ajv);             // registers `uuid` and `date-time`

    const validate = ajv.compile<EventContract>(schema);

    cached = {
        schemaId: typeof schema.$id === 'string' ? schema.$id : 'unknown',
        validate,
    };

    logger.info('[EventBus] Event_Contract schema compiled', {
        schemaId: cached.schemaId,
        schemaPath,
    });

    return cached;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Convert Ajv `ErrorObject`s into the bus's `ValidationIssue` shape.
 * The bus carries the field path as a JSON Pointer (`/recipients/0/role`)
 * because that format is unambiguous and round-trips through HTTP responses
 * without escape hazards. We strip the leading `/` and replace `/` with `.`
 * to make the path human-readable in CloudWatch logs.
 */
function toIssues(errors: readonly ErrorObject[] | null | undefined): ValidationIssue[] {
    if (!errors) return [];
    return errors.map(err => {
        const rawPath = err.instancePath || '';
        const friendly = rawPath.replace(/^\//, '').replace(/\//g, '.');
        // For `required` errors the missing property name is in `params.missingProperty`.
        const missing = (err.params as { missingProperty?: string })?.missingProperty;
        const field = friendly || (missing ? missing : '<root>');
        const message = missing
            ? `Missing required field: ${missing}`
            : err.message ?? 'Schema validation failed';
        return {
            field,
            message,
            keyword: err.keyword,
        };
    });
}

/**
 * Validate an event payload against the Event_Contract schema.
 * Throws `EventContractValidationError` with field-level issues on failure.
 * Returns the same object on success (typed as `EventContract`) so callers
 * can chain into `sns:Publish` without re-asserting the type.
 *
 * The Event_Bus MUST call this BEFORE any external side effect (no SNS call,
 * no DynamoDB write, no AuditLog entry) so a rejected publish persists
 * nothing per REQ 3.6.
 */
export function validateEventContract(payload: unknown): EventContract {
    const { validate } = compile();
    if (!validate(payload)) {
        const issues = toIssues(validate.errors);
        const summary = issues.length === 1
            ? `Event_Contract validation failed: ${issues[0].field} — ${issues[0].message}`
            : `Event_Contract validation failed (${issues.length} issues)`;
        throw new EventContractValidationError(summary, issues);
    }
    return payload as EventContract;
}

/**
 * Non-throwing variant useful in batch publish paths where the caller wants
 * to accumulate failures rather than abort on the first invalid event.
 */
export function tryValidateEventContract(payload: unknown): {
    ok: true;
    event: EventContract;
} | {
    ok: false;
    issues: ValidationIssue[];
} {
    const { validate } = compile();
    if (validate(payload)) {
        return { ok: true, event: payload as EventContract };
    }
    return { ok: false, issues: toIssues(validate.errors) };
}

/**
 * Test-only hook — discards the cached validator so the next call recompiles.
 * Exported (not internal) because integration tests in
 * `my-backend/tests/notifications/` need it to swap the schema path between
 * fixtures.
 */
export function _resetSchemaValidatorForTests(): void {
    cached = null;
}
