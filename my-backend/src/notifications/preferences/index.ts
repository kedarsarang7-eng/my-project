// ============================================================================
// Preference_Engine — Barrel Export
// ============================================================================
// Single import point for callers in `my-backend/src/notifications/service/`,
// `channels/`, `sync/`, etc.
//
// The Preference_Engine is a stateless resolver (REQ 7.8). It reads only
// the `UserPreferenceRecord` it is handed; it never opens a DynamoDB
// connection of its own. Notification_Service is responsible for
// fetching the record once per dispatch and passing it through.
//
// Validates: REQ 7.1, 7.2, 7.2a, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8.
// ============================================================================

// ---- Public resolver surface --------------------------------------------
export {
    resolveChannels,
    resolveAllowedChannels,
    type ResolverInput,
    type ResolverNotification,
    type ResolverNotificationFlags,
    type ResolverRecipient,
    type ResolverResult,
    type ResolutionReason,
} from './resolver';

// ---- Quiet-hours helpers (exposed for tests and direct callers) ---------
export {
    isInQuietHours,
    parseHHMM,
    type QuietHoursEvaluation,
} from './quiet-hours';

// ---- Role / system defaults ---------------------------------------------
export {
    SYSTEM_DEFAULT_CHANNELS,
    ROLE_DEFAULT_CHANNELS,
    getRoleDefaultChannels,
} from './role-defaults';
