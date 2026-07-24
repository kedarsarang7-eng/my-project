/**
 * Operations — Barrel Export
 *
 * Backup, restore, export, and throttling recovery controls.
 * All backup/restore/export operations use a SEPARATE IAM identity
 * from the application role (BACKUP_RESTORE_ACTIONS).
 *
 * Requirements: 6.37–6.40, 8.13, 13.6
 */

// Backup Controls
export {
  BackupService,
  type InitiateBackupParams,
  type BackupResult,
  type ListBackupsFilter,
  type EncryptionValidationResult,
  type BackupAuditEntry,
} from './backup-controls';

// Restore Controls
export {
  RestoreService,
  type RestoreSource,
  type InitiateRestoreParams,
  type RestoreResult,
  type TargetValidationResult,
  type RestoreDrillResult,
  type RestoreAuditEntry,
} from './restore-controls';

// Throttling Recovery
export {
  ThrottlingRecoveryService,
  type RateLimitedPending,
  type RateLimitedExhausted,
  type ThrottlingOutcome,
  type RetryPolicyKey,
  type RetryBudgetState,
} from './throttling-recovery';

// Export Controls
export {
  ExportService,
  type ExportFormat,
  type InitiateExportParams,
  type ExportStatus,
  type ExportResult,
  type ExportAuditEntry,
} from './export-controls';
