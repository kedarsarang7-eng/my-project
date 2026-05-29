// ============================================================================
// Retention Configuration — Structured Errors
// ============================================================================
// All errors extend `AppError` so the handler wrapper renders them with a
// consistent error envelope. One error type per failure mode the spec calls
// out:
//   - InvalidRetentionValueError — REQ 13.4 (validation)
//   - AuditLogUnavailableError   — REQ 13.4a (reject if audit-log down)
// ============================================================================

import { AppError } from '../../utils/errors';
import { MAX_ARCHIVE_PERIOD_DAYS, MIN_ARCHIVE_PERIOD_DAYS } from './types';

/**
 * Raised when the supplied `archive_period_days` is not a positive integer
 * inside the allowed bounds. The handler turns this into a 400 response.
 *
 * Validates: REQ 13.4 (configured retention only via authenticated change).
 */
export class InvalidRetentionValueError extends AppError {
    constructor(received: unknown, message?: string) {
        super(
            message ??
                `archive_period_days must be an integer between ` +
                    `${MIN_ARCHIVE_PERIOD_DAYS} and ${MAX_ARCHIVE_PERIOD_DAYS} (inclusive).`,
            400,
            'INVALID_RETENTION_VALUE',
            {
                received,
                min: MIN_ARCHIVE_PERIOD_DAYS,
                max: MAX_ARCHIVE_PERIOD_DAYS,
            },
        );
        this.name = 'InvalidRetentionValueError';
    }
}

/**
 * Raised when the Audit_Log subsystem cannot accept a write at the time of a
 * retention change. Per REQ 13.4a, the configuration change MUST be rejected
 * and the previous Archive_Period MUST remain in effect.
 *
 * Validates: REQ 13.4a.
 */
export class AuditLogUnavailableError extends AppError {
    public readonly cause: Error | null;

    constructor(cause?: unknown) {
        const causeError =
            cause instanceof Error
                ? cause
                : cause !== undefined
                    ? new Error(String(cause))
                    : null;
        super(
            'Retention configuration change rejected: the Audit_Log ' +
                'subsystem is unavailable. The previous Archive_Period ' +
                'remains in effect.',
            503,
            'AUDIT_LOG_UNAVAILABLE',
            { cause: causeError?.message ?? null },
        );
        this.name = 'AuditLogUnavailableError';
        this.cause = causeError;
    }
}
