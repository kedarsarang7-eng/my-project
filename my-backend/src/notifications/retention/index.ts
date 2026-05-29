// ============================================================================
// Notification Retention Configuration — Barrel Export
// ============================================================================
// Single import point for callers in `my-backend/src/handlers/` and any
// future cold-storage mover that needs to read the configured
// Archive_Period.
//
// Validates: REQ 13.4, REQ 13.4a, REQ 6.8.
// ============================================================================

export type {
    RetentionConfigRecord,
    UpdateRetentionConfigInput,
} from './types';

export {
    MIN_ARCHIVE_PERIOD_DAYS,
    MAX_ARCHIVE_PERIOD_DAYS,
} from './types';

export {
    InvalidRetentionValueError,
    AuditLogUnavailableError,
} from './errors';

export {
    readRetentionConfig,
    writeRetentionConfig,
    RETENTION_CONFIG_PK,
    RETENTION_CONFIG_SK,
    type RetentionConfigRepoOptions,
} from './retention-config.repo';

export {
    recordRetentionChange,
    RETENTION_AUDIT_NOTIFICATION_ID,
    type RecordRetentionChangeInput,
} from './retention-audit';

export {
    updateRetentionConfigSchema,
    type UpdateRetentionConfigBody,
} from './validation';

export {
    getRetentionConfig,
    setRetentionConfig,
    resolveDefaultArchivePeriodDays,
    ARCHIVE_PERIOD_ENV_VAR,
    type GetRetentionConfigOptions,
    type SetRetentionConfigOptions,
} from './retention-config.service';
