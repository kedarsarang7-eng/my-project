// ============================================================================
// UNS Event_Bus — Payload Redaction Validator (Task 16.4, REQ 12.8)
// ============================================================================
// Sibling of `schema-validator.ts`. Where the schema validator enforces the
// STRUCTURAL contract (field shapes, required keys, enum values), this
// validator enforces the SECURITY contract (REQ 12.8: payloads MUST NOT
// include secret values, full PAN, or full government-issued identifiers;
// only redacted references).
//
// The two validators run in sequence inside `publisher.ts`:
//
//   1. `validateEventContract` (schema)    — REQ 3.6
//   2. `validatePayloadRedaction` (this)   — REQ 12.8
//   3. SNS publish
//
// Failing this step throws the same `EventContractValidationError` the
// schema validator throws, with `keyword` set to the redaction pattern
// name (`pan_india`, `credit_card`, ...) so caller tooling can branch on
// the structured taxonomy without regex-matching the message.
//
// Why a SEPARATE validator instead of folding the patterns into the JSON
// Schema? Two reasons, both spelled out in the task brief:
//
//   - JSON Schema cannot express "this 16-digit string must NOT pass the
//     Luhn checksum" — Luhn is procedural. The schema is the single
//     source of structural truth (REQ 8.1); we keep it that way.
//
//   - Producers should be able to evolve their payload shape (add/remove
//     fields) without touching the redaction policy. Decoupling the two
//     validators means a schema change does not risk a regression in
//     security policy and vice versa.
//
// Validates: REQ 12.8.
// ============================================================================

import {
    findSensitiveOccurrences,
    REDACTION_PATTERN,
    STRICT_REDACTION_CONFIG,
    type RedactionConfig,
    type RedactionPattern,
    type SensitiveOccurrence,
} from '../service/redaction';
import { EventContractValidationError } from './errors';
import type { EventContract, ValidationIssue } from './types';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Validate that the event payload (and recipient/target metadata) is free
 * of raw secrets, full PAN, full credit cards, full Aadhaar, and other
 * forbidden identifiers per REQ 12.8.
 *
 * Throws `EventContractValidationError` on the FIRST publish that
 * carries a forbidden value. The error's `issues` array names every
 * offending field path so the producer can fix all leaks in one round-
 * trip rather than the publish-fix-publish-fix loop a single-issue
 * error would cause.
 *
 * The `validated` parameter MUST already have passed
 * `validateEventContract`; this validator focuses on the payload fields
 * (and a defence-in-depth pass over recipients and target_id) without
 * re-checking the structural shape.
 *
 * Returns the same object on success so callers can chain into
 * `sns:Publish` without re-asserting the type.
 */
export function validatePayloadRedaction(
    validated: EventContract,
    config: RedactionConfig = STRICT_REDACTION_CONFIG,
): EventContract {
    const issues = collectAllIssues(validated, config);
    if (issues.length === 0) return validated;

    const summary = issues.length === 1
        ? `Event_Contract redaction policy violation: ${issues[0].field} ` +
          `— ${issues[0].message}`
        : `Event_Contract redaction policy violation (${issues.length} issues)`;
    throw new EventContractValidationError(summary, issues);
}

/**
 * Non-throwing variant useful in batch publish paths where the caller
 * wants to accumulate failures rather than abort on the first invalid
 * event. Mirrors the shape of `tryValidateEventContract`.
 */
export function tryValidatePayloadRedaction(
    validated: EventContract,
    config: RedactionConfig = STRICT_REDACTION_CONFIG,
): { ok: true } | { ok: false; issues: ValidationIssue[] } {
    const issues = collectAllIssues(validated, config);
    if (issues.length === 0) return { ok: true };
    return { ok: false, issues };
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Run the redactor over the security-relevant slices of the envelope.
 * We focus on `payload` (REQ 12.8 says "in notification payloads") plus
 * three lighter passes that catch a forbidden value smuggled past the
 * payload key:
 *
 *   - `target_id`    — sometimes carries an external customer reference
 *                      that lazy producers populate with a raw card or
 *                      Aadhaar.
 *   - `recipients[]` — `target_id` per recipient has the same risk.
 *   - `sub_category` — free-text snake_case slug; safe in 99.9% of cases
 *                      but a misuse could put a token here.
 *
 * We deliberately DO NOT scan `actor_id`, `source_module`, `source_app`,
 * `event_name`, `category`, `priority`, `created_at`, `dedup_key`,
 * `dedup_scope_fields`, `channels`, or `id`. Those are bus-controlled
 * fields with their own structural shape — flagging a digit run inside
 * a UUID would be a false positive that would break every publish.
 */
function collectAllIssues(
    event: EventContract,
    config: RedactionConfig,
): ValidationIssue[] {
    const out: ValidationIssue[] = [];

    pushOccurrencesUnder(out, event.payload, 'payload', config);

    if (event.target_id !== undefined && event.target_id !== null) {
        pushOccurrencesUnder(out, event.target_id, 'target_id', config);
    }

    if (event.sub_category !== undefined) {
        pushOccurrencesUnder(out, event.sub_category, 'sub_category', config);
    }

    for (let i = 0; i < event.recipients.length; i++) {
        const r = event.recipients[i];
        if (r.target_id !== undefined && r.target_id !== null) {
            pushOccurrencesUnder(
                out,
                r.target_id,
                `recipients[${i}].target_id`,
                config,
            );
        }
    }

    return out;
}

function pushOccurrencesUnder(
    out: ValidationIssue[],
    value: unknown,
    rootField: string,
    config: RedactionConfig,
): void {
    const occurrences = findSensitiveOccurrences(value, config);
    for (const occ of occurrences) {
        out.push(toIssue(rootField, occ));
    }
}

function toIssue(rootField: string, occ: SensitiveOccurrence): ValidationIssue {
    // Reframe the redactor's `<root>`-rooted path as a path under the
    // EventContract field we were scanning, so operators see a complete
    // path from envelope root down to the offending leaf.
    const subPath = occ.path === '<root>' ? '' : occ.path;
    const field = subPath ? `${rootField}.${subPath}` : rootField;
    return {
        field,
        message: humanReason(occ),
        keyword: occ.pattern,
    };
}

/**
 * Build the human-readable reason. We deliberately do NOT echo the raw
 * match — the redactor returned it strictly so we could compute the
 * length/last-4 hint. Logging the raw value would defeat the very
 * policy we are enforcing.
 */
function humanReason(occ: SensitiveOccurrence): string {
    switch (occ.pattern) {
        case REDACTION_PATTERN.CREDIT_CARD: {
            const last4 = occ.match.slice(-4);
            return (
                `Raw payment card number detected (Luhn-valid, ending in ${last4}). ` +
                `REQ 12.8 forbids embedding full payment card numbers in notification ` +
                `payloads — pass a redacted reference (e.g. "****${last4}") instead.`
            );
        }
        case REDACTION_PATTERN.PAN_INDIA:
            return (
                `Raw PAN (Indian Permanent Account Number) detected. ` +
                `REQ 12.8 forbids embedding full government-issued identifiers ` +
                `in notification payloads — pass a redacted reference instead.`
            );
        case REDACTION_PATTERN.AADHAAR:
            return (
                `Raw Aadhaar (12-digit Indian government identifier) detected. ` +
                `REQ 12.8 forbids embedding full government-issued identifiers ` +
                `in notification payloads — pass a redacted reference instead.`
            );
        case REDACTION_PATTERN.BEARER_TOKEN:
            return (
                `Raw Bearer token detected. REQ 12.8 forbids embedding ` +
                `secret values in notification payloads — pass a redacted ` +
                `reference (e.g. "[REDACTED]") instead.`
            );
        case REDACTION_PATTERN.AWS_ACCESS_KEY:
            return (
                `Raw AWS access key id detected. REQ 12.8 forbids embedding ` +
                `secret values in notification payloads.`
            );
        case REDACTION_PATTERN.SENSITIVE_KEY_VALUE:
            return (
                `Field name suggests a secret value (token / password / secret / ` +
                `apikey / authorization). REQ 12.8 forbids embedding secret ` +
                `values in notification payloads — replace with a redacted ` +
                `reference before publish.`
            );
        default: {
            // Exhaustiveness check — TypeScript will complain here if a new
            // pattern is added without updating this switch.
            const _exhaustive: never = occ.pattern as never;
            void _exhaustive;
            return `Forbidden value detected (${occ.pattern as RedactionPattern}).`;
        }
    }
}
