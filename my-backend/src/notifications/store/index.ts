// ============================================================================
// Notification_Store — Barrel export
// ============================================================================
// Single import point for callers in `my-backend/src/notifications/service/`,
// `event-bus/`, `channels/`, `sync/`, etc.
//
// Validates: REQ 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7a, 6.8, 6.9, 19.2.
// ============================================================================

// ---- Types ---------------------------------------------------------------
export type {
    NotificationCategory,
    NotificationPriority,
    NotificationChannel,
    NotificationStatus,
    LifecycleState,
    NotificationRecipient,
    NotificationRecord,
    LifecycleTimestamps,
    QuietHours,
    UserPreferenceRecord,
    AuditOutcome,
    AuditLogRecord,
    PaginatedNotifications,
} from './types';

// ---- Errors --------------------------------------------------------------
export {
    LifecycleOrderingViolationError,
    AuditLogImmutableError,
    OptimisticLockError,
    InvalidCursorError,
    DuplicateAuditEntryError,
} from './errors';

// ---- Cursor helpers (REQ 6.9) -------------------------------------------
export {
    encodeCursor,
    decodeCursor,
    cursorFromNotification,
    type PaginationCursor,
} from './cursor';

// ---- Key / table-name helpers -------------------------------------------
export {
    NOTIFICATION_TABLE,
    USER_PREFERENCE_TABLE,
    AUDIT_LOG_TABLE,
    UNREAD_COUNT_TABLE,
    UNREAD_COUNT_FIELD,
    GSI_BY_USER_STATUS,
    GSI_BY_USER_CATEGORY,
    GSI_BY_DEDUP_KEY,
    userStatusGsiKey,
    userCategoryGsiKey,
    dedupGsiKey,
    auditSortKey,
} from './keys';

// ---- Notification repository --------------------------------------------
export {
    createNotification,
    getNotification,
    updateLifecycle,
    deleteNotification,
    listByUserStatus,
    listByUserCategory,
    findByDedupKey,
    getRecordsOlderThan,
    assertLifecycleOrdering,
    lifecycleTimestampsAreOrdered,
    type NotificationRepoOptions,
    type UpdateLifecycleInput,
    type ListByUserStatusInput,
    type ListByUserCategoryInput,
    type FindByDedupKeyInput,
    type GetRecordsOlderThanInput,
    type GetRecordsOlderThanResult,
} from './notification.repo';

// ---- UserPreference repository ------------------------------------------
export {
    createUserPreference,
    getUserPreference,
    updateUserPreference,
    upsertUserPreference,
    deleteUserPreference,
    type UserPreferenceRepoOptions,
    type CreateUserPreferenceInput,
    type UpdateUserPreferenceInput,
} from './user-preference.repo';

// ---- AuditLog repository (append-only) ----------------------------------
// Note: `update` and `delete` are intentionally exported as throwing stubs
// (REQ 6.3 / REQ 12.6 — AuditLog is append-only).
export {
    append as appendAuditLog,
    appendBatch as appendAuditLogBatch,
    query as queryAuditLog,
    update as updateAuditLog,
    delete as deleteAuditLog,
    type AuditLogRepoOptions,
    type QueryAuditLogInput,
    type QueryAuditLogResult,
} from './audit-log.repo';

// ---- Unread-count projection (DynamoDB Streams handler) ------------------
// The Lambda entry point is `handler`; tests and direct-write callers can
// reuse `applyUnreadCountDelta` and `computeUnreadDeltas` without spinning
// up the stream event.
export {
    handler as unreadCountProjectionHandler,
    applyUnreadCountDelta,
    computeUnreadDeltas,
    lifecycleDelta as unreadCountLifecycleDelta,
    type UnreadCountProjectionOptions,
} from './unread-count.projection';
