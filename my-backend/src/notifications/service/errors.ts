// ============================================================================
// Notification_Service — Structured Errors
// ============================================================================
// All errors extend the project-wide `AppError` so the existing handler
// wrapper (and the AuditLog writer) categorise them in API responses
// without ad-hoc adapters.
//
// Validates: REQ 4.10 (authorization rejection), REQ 8.5 (replay window).
// ============================================================================

import { AppError } from '../../utils/errors';

/**
 * Raised when the caller of `createNotification` is not authorized to emit
 * on behalf of the supplied `actor_id`. The service rejects the call and
 * persists nothing (REQ 4.10).
 *
 * Status 403 keeps the surface consistent with the existing
 * `permission-guard.ts` rejection contract.
 */
export class AuthorizationError extends AppError {
    constructor(
        message: string,
        details?: { caller_id?: string; actor_id?: string; reason?: string },
    ) {
        super(message, 403, 'NOTIFICATION_AUTHORIZATION_DENIED', details);
        this.name = 'AuthorizationError';
    }
}

/**
 * Raised when `getReplay` is called with a `since` timestamp older than
 * the configured Replay_Window (default 7 days, REQ 8.5).
 *
 * Status 400 — caller-supplied parameter is out of range. The structured
 * `code: 'replay_window_exceeded'` matches the wording of REQ 8.5a so
 * sub-app clients can branch on it deterministically.
 */
export class ReplayWindowExceededError extends AppError {
    public readonly since: string;
    public readonly windowDays: number;

    constructor(since: string, windowDays: number) {
        super(
            `Replay 'since' (${since}) is older than the Replay_Window of ` +
                `${windowDays} day(s); replay denied.`,
            400,
            'replay_window_exceeded',
            { since, windowDays },
        );
        this.name = 'ReplayWindowExceededError';
        this.since = since;
        this.windowDays = windowDays;
    }
}

/**
 * Raised when a notification id supplied to `dispatch` or `markAsRead`
 * does not match any record. Distinct from a missing-recipient case so
 * the caller can branch on the structured code.
 */
export class NotificationNotFoundError extends AppError {
    constructor(notificationId: string) {
        super(
            `Notification ${notificationId} not found.`,
            404,
            'NOTIFICATION_NOT_FOUND',
            { notificationId },
        );
        this.name = 'NotificationNotFoundError';
    }
}

/**
 * Raised when an input payload supplied to `setUserPreferences` is
 * malformed (e.g. unknown channel, unknown category, malformed quiet-hours
 * pair). Surface as a 400 so HTTP callers know it is a client error.
 */
export class PreferenceValidationError extends AppError {
    constructor(message: string, details?: unknown) {
        super(message, 400, 'PREFERENCE_VALIDATION_ERROR', details);
        this.name = 'PreferenceValidationError';
    }
}
