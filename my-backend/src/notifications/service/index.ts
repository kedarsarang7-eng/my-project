// ============================================================================
// Notification_Service — Barrel Export
// ============================================================================
// Single import point for callers in `my-backend/src/handlers/`,
// `my-backend/src/notifications/sync/`, and tests.
//
// Validates: REQ 4.1 - 4.11.
// ============================================================================

// ---- Service class & factory --------------------------------------------
export {
    NotificationService,
    getDefaultNotificationService,
    __setDefaultNotificationServiceForTesting,
    type NotificationServiceOptions,
    type GetReplayInput,
    type PreferencesCaller,
} from './notification.service';

// ---- Unauthorized-access audit (REQ 12.7) -------------------------------
export {
    recordUnauthorizedAccessAttempt,
    type RecordUnauthorizedAccessAttemptInput,
    type UnauthorizedAccessReason,
} from './unauthorized-audit';

// ---- Types --------------------------------------------------------------
export type {
    CreateNotificationCaller,
    CreateNotificationInput,
    CreateNotificationResult,
    DispatchChannelAdapter,
    DispatchChannelArgs,
    DispatchOptions,
    DispatchRecipientOutcome,
    DispatchResult,
    MarkAsReadResult,
    NotificationRecord,
    ReplayResult,
    SetUserPreferencesInput,
    UserPreferenceRecord,
} from './types';

export { REPLAY_WINDOW_DAYS } from './types';

// ---- Errors -------------------------------------------------------------
export {
    AuthorizationError,
    NotificationNotFoundError,
    PreferenceValidationError,
    ReplayWindowExceededError,
} from './errors';

// ---- Authorization (interfaces + defaults) ------------------------------
export {
    AllowAllRecipientAuthorizer,
    DefaultCallerAuthorizer,
    PredicateRecipientAuthorizer,
    type CallerAuthorizer,
    type CanReceiveArgs,
    type RecipientAuthorizer,
} from './authz';

// ---- Deduplication ------------------------------------------------------
export {
    DEFAULT_DEDUP_WINDOW_SECONDS,
    computeDedupKey,
    findDuplicateForRecipient,
    type DedupKeyInput,
    type IsDuplicateForRecipientInput,
} from './dedup';

// ---- Lifecycle ----------------------------------------------------------
export {
    markAsRead,
    transitionToDelivered,
    transitionToDispatched,
    transitionToFailed,
    transitionToQueued,
    type MarkAsReadInput,
    type MarkAsReadOutput,
} from './lifecycle';
