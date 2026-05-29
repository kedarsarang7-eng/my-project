// ============================================================================
// Notification_Store — Structured Errors
// ============================================================================
// All errors extend `AppError` from `my-backend/src/utils/errors.ts` so the
// existing handler wrapper categorises them in API responses unchanged.
//
// One error type per failure mode the spec calls out:
//   - LifecycleOrderingViolationError — REQ 6.7a
//   - AuditLogImmutableError          — REQ 6.3 / 12.6 (append-only)
//   - OptimisticLockError             — REQ 6.2 (`version`)
//   - InvalidCursorError              — REQ 6.9 (opaque cursor)
//   - DuplicateAuditEntryError        — defensive: same audit_id reused
// ============================================================================

import { AppError } from '../../utils/errors';
import type { LifecycleTimestamps, NotificationStatus } from './types';

/**
 * Raised when a state transition would violate the lifecycle ordering
 * invariant `created_at <= dispatched_at <= delivered_at <= read_at`.
 * Carries the offending tuple so callers can log a useful message.
 *
 * Validates: REQ 6.7a, design.md §"Lifecycle ordering invariant".
 */
export class LifecycleOrderingViolationError extends AppError {
    public readonly notificationId: string;
    public readonly attemptedStatus: NotificationStatus;
    public readonly current: LifecycleTimestamps;
    public readonly proposed: LifecycleTimestamps;

    constructor(
        notificationId: string,
        attemptedStatus: NotificationStatus,
        current: LifecycleTimestamps,
        proposed: LifecycleTimestamps,
        message?: string,
    ) {
        super(
            message ??
                `Lifecycle ordering violation on notification ${notificationId}: ` +
                    `attempted transition to '${attemptedStatus}' would break ` +
                    `created_at <= dispatched_at <= delivered_at <= read_at.`,
            422,
            'LIFECYCLE_ORDERING_VIOLATION',
            { notificationId, attemptedStatus, current, proposed },
        );
        this.name = 'LifecycleOrderingViolationError';
        this.notificationId = notificationId;
        this.attemptedStatus = attemptedStatus;
        this.current = current;
        this.proposed = proposed;
    }
}

/**
 * Raised when a caller attempts to update or delete an existing AuditLog
 * record. AuditLog is append-only by spec.
 *
 * Validates: REQ 6.3, REQ 12.6.
 */
export class AuditLogImmutableError extends AppError {
    constructor(operation: 'update' | 'delete', auditId: string) {
        super(
            `AuditLog is append-only. Operation '${operation}' is not permitted ` +
                `on audit_id ${auditId}.`,
            409,
            'AUDIT_LOG_IMMUTABLE',
            { operation, auditId },
        );
        this.name = 'AuditLogImmutableError';
    }
}

/**
 * Raised when an optimistic-lock update fails because the supplied
 * `expectedVersion` does not match the version stored in DynamoDB.
 *
 * Validates: REQ 6.2 (`version` field), REQ 4.9 + REQ 7.7 (idempotent prefs).
 */
export class OptimisticLockError extends AppError {
    public readonly expectedVersion: number;

    constructor(resource: string, expectedVersion: number) {
        super(
            `Optimistic lock failure on ${resource}: expected version ` +
                `${expectedVersion} but the record has been modified.`,
            409,
            'OPTIMISTIC_LOCK_FAILURE',
            { resource, expectedVersion },
        );
        this.name = 'OptimisticLockError';
        this.expectedVersion = expectedVersion;
    }
}

/**
 * Raised when a pagination cursor cannot be decoded.
 * The cursor is intentionally opaque to clients (REQ 6.9) — clients must
 * pass back exactly what the server gave them.
 */
export class InvalidCursorError extends AppError {
    constructor(message: string) {
        super(message, 400, 'INVALID_CURSOR');
        this.name = 'InvalidCursorError';
    }
}

/**
 * Raised when an `append` is attempted with an `audit_id` that already
 * exists. Catches both accidental re-publication and bad client behavior.
 */
export class DuplicateAuditEntryError extends AppError {
    constructor(auditId: string) {
        super(
            `AuditLog entry with audit_id ${auditId} already exists; append ` +
                `would not be append-only.`,
            409,
            'AUDIT_DUPLICATE',
            { auditId },
        );
        this.name = 'DuplicateAuditEntryError';
    }
}
