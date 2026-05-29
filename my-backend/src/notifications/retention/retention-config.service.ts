// ============================================================================
// Retention Configuration — Service
// ============================================================================
// Orchestrates the read/write lifecycle of the retention configuration:
//
//   - getRetentionConfig() reads the persisted record (or returns the
//     env-derived default if no record has been written yet).
//   - setRetentionConfig() validates the new value, atomically writes the
//     audit-log entry FIRST (REQ 13.4), and only then persists the change.
//     If the audit-log write fails, the change is rejected and the
//     previous Archive_Period remains in effect (REQ 13.4a).
//
// The default Archive_Period is the spec's 90 days (REQ 6.8 / 13.4),
// overridable via the `NOTIFICATIONS_ARCHIVE_PERIOD_DAYS` environment
// variable so different environments (dev / staging / prod) can ship with
// different defaults without code changes (AGENTS.md "no hardcoded values").
//
// Validates: REQ 13.4, REQ 13.4a, REQ 6.8.
// ============================================================================

import { logger } from '../../utils/logger';
import {
    AuditLogUnavailableError,
    InvalidRetentionValueError,
} from './errors';
import {
    readRetentionConfig,
    writeRetentionConfig,
    type RetentionConfigRepoOptions,
} from './retention-config.repo';
import { recordRetentionChange } from './retention-audit';
import {
    MAX_ARCHIVE_PERIOD_DAYS,
    MIN_ARCHIVE_PERIOD_DAYS,
    type RetentionConfigRecord,
    type UpdateRetentionConfigInput,
} from './types';

// ---- Default resolution --------------------------------------------------

/**
 * Spec default Archive_Period — 90 days (REQ 6.8, REQ 13.4, glossary).
 * Used as the fall-back when neither a persisted record nor the env
 * override is available.
 */
const SPEC_DEFAULT_ARCHIVE_PERIOD_DAYS = 90;

/**
 * Env-variable name that overrides the default Archive_Period (in days).
 * Operators can ship different defaults per environment without a code
 * change, satisfying the AGENTS.md "no hardcoded values" rule.
 */
export const ARCHIVE_PERIOD_ENV_VAR = 'NOTIFICATIONS_ARCHIVE_PERIOD_DAYS';

/**
 * Resolve the default Archive_Period from the environment, falling back to
 * the spec default if the env value is unset or invalid. We deliberately
 * fall back silently on bad input (logged at warn) rather than throwing,
 * so a misconfigured environment cannot brick the entire notification
 * subsystem at boot.
 */
export function resolveDefaultArchivePeriodDays(
    env: NodeJS.ProcessEnv = process.env,
): number {
    const raw = env[ARCHIVE_PERIOD_ENV_VAR];
    if (raw === undefined || raw === null || raw === '') {
        return SPEC_DEFAULT_ARCHIVE_PERIOD_DAYS;
    }
    const parsed = Number.parseInt(raw, 10);
    if (
        !Number.isFinite(parsed) ||
        !Number.isInteger(parsed) ||
        parsed < MIN_ARCHIVE_PERIOD_DAYS ||
        parsed > MAX_ARCHIVE_PERIOD_DAYS
    ) {
        logger.warn(
            `Invalid ${ARCHIVE_PERIOD_ENV_VAR} value; falling back to spec default`,
            {
                received: raw,
                fallback: SPEC_DEFAULT_ARCHIVE_PERIOD_DAYS,
                min: MIN_ARCHIVE_PERIOD_DAYS,
                max: MAX_ARCHIVE_PERIOD_DAYS,
            },
        );
        return SPEC_DEFAULT_ARCHIVE_PERIOD_DAYS;
    }
    return parsed;
}

/**
 * Synthesise the default record returned by `getRetentionConfig` when no
 * row has yet been persisted. `version === 0` and `updated_by === null`
 * mark it as the unmodified default; the next successful update writes
 * version `1`.
 */
function defaultRecord(env: NodeJS.ProcessEnv = process.env): RetentionConfigRecord {
    return {
        archive_period_days: resolveDefaultArchivePeriodDays(env),
        updated_at: new Date(0).toISOString(),
        updated_by: null,
        version: 0,
    };
}

// ---- Public API ----------------------------------------------------------

export interface GetRetentionConfigOptions extends RetentionConfigRepoOptions {
    /** Override `process.env` — used by unit tests. */
    readonly env?: NodeJS.ProcessEnv;
}

/**
 * Read the current retention configuration. Returns the persisted record
 * if one exists, otherwise the default derived from the environment.
 */
export async function getRetentionConfig(
    options: GetRetentionConfigOptions = {},
): Promise<RetentionConfigRecord> {
    const persisted = await readRetentionConfig(options);
    if (persisted) return persisted;
    return defaultRecord(options.env);
}

export interface SetRetentionConfigOptions extends RetentionConfigRepoOptions {
    /** Override the timestamp source — used by unit tests. */
    readonly now?: () => Date;
    /** Override `process.env` — used by unit tests. */
    readonly env?: NodeJS.ProcessEnv;
}

/**
 * Apply a new retention configuration.
 *
 * Order of operations (the order matters for REQ 13.4a):
 *   1. Validate the input value.
 *   2. Read the current record (or default) to capture `previous_value`
 *      and `expectedVersion` for the optimistic-lock write.
 *   3. Write the Audit_Log entry. If this fails, throw
 *      `AuditLogUnavailableError` and persist NOTHING.
 *   4. Persist the new record with the version bumped by 1.
 *
 * If the persist step in (4) fails after (3) succeeded, the audit trail
 * already records the intent. The caller will retry against the unchanged
 * persistent state — the version-condition makes the retry safe (it will
 * pick up the same `expectedVersion` and try again). We do NOT attempt to
 * reverse the audit entry: the Audit_Log is append-only by spec
 * (REQ 6.3 / 12.6) and partial-success during a retention change is
 * acceptable provided the persistent state does not advance.
 */
export async function setRetentionConfig(
    input: UpdateRetentionConfigInput,
    options: SetRetentionConfigOptions = {},
): Promise<RetentionConfigRecord> {
    // 1. Validate.
    if (
        !Number.isInteger(input.archive_period_days) ||
        input.archive_period_days < MIN_ARCHIVE_PERIOD_DAYS ||
        input.archive_period_days > MAX_ARCHIVE_PERIOD_DAYS
    ) {
        throw new InvalidRetentionValueError(input.archive_period_days);
    }
    if (!input.actor_id || input.actor_id.trim() === '') {
        throw new InvalidRetentionValueError(
            input.actor_id,
            'actor_id is required for retention-config changes',
        );
    }

    // 2. Read current state.
    const current = await getRetentionConfig(options);
    const nowIso = (options.now ?? (() => new Date()))().toISOString();

    // No-op short-circuit: if the requested value matches the current
    // value, return without writing. This still satisfies REQ 13.4 (the
    // value is unchanged so no Audit_Log entry is required) and prevents
    // a flood of identical entries from misbehaving callers.
    if (current.archive_period_days === input.archive_period_days) {
        logger.debug('Retention config unchanged; skipping write', {
            archive_period_days: current.archive_period_days,
            actor_id: input.actor_id,
        });
        return current;
    }

    // 3. Write the Audit_Log entry FIRST. If this throws, we propagate the
    // AuditLogUnavailableError and the persistent state remains untouched.
    await recordRetentionChange({
        actor_id: input.actor_id,
        previous_archive_period_days: current.archive_period_days,
        new_archive_period_days: input.archive_period_days,
        timestamp: nowIso,
    });

    // 4. Persist the new record with version bumped.
    const next: RetentionConfigRecord = {
        archive_period_days: input.archive_period_days,
        updated_at: nowIso,
        updated_by: input.actor_id,
        version: current.version + 1,
    };

    try {
        return await writeRetentionConfig(next, current.version, options);
    } catch (err) {
        // The Audit_Log entry already records the intent. Surface the
        // persistence error to the caller; the persistent state is
        // unchanged because the conditional put failed atomically.
        logger.error('Retention config persistence failed after audit', {
            error: (err as Error).message,
            actor_id: input.actor_id,
            attempted_value: input.archive_period_days,
            previous_value: current.archive_period_days,
        });
        throw err;
    }
}

// Re-export error types so callers don't have to reach into `./errors`.
export {
    AuditLogUnavailableError,
    InvalidRetentionValueError,
};
