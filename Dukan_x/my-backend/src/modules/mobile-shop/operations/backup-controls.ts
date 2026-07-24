/**
 * Backup Controls — Encrypted DynamoDB Backup Management
 *
 * Provides on-demand backup creation, listing, and encryption validation.
 * All operations require the dedicated BACKUP_RESTORE_ACTIONS identity
 * (never the application role). Every backup includes stage/tenant/timestamp
 * tags and an audit trail entry.
 *
 * Requirements: 6.37–6.40
 */

import type { TenantContextWire } from '../schemas/common.schema';

// ─── Types ───────────────────────────────────────────────────────────────────

/** Parameters for initiating an on-demand backup */
export interface InitiateBackupParams {
  /** Target DynamoDB table name (stage-scoped) */
  readonly tableName: string;
  /** Human-readable label for the backup */
  readonly label: string;
  /** Reason for backup (e.g. 'pre-migration', 'scheduled', 'manual') */
  readonly reason: string;
}

/** Result of a backup initiation */
export interface BackupResult {
  readonly backupArn: string;
  readonly backupName: string;
  readonly backupStatus: 'CREATING' | 'AVAILABLE' | 'DELETED';
  readonly createdAt: string;
  readonly tableName: string;
  readonly encrypted: boolean;
}

/** Filter parameters for listing backups */
export interface ListBackupsFilter {
  readonly tableName?: string;
  readonly fromDate?: string;
  readonly toDate?: string;
  readonly backupType?: 'USER' | 'SYSTEM' | 'ALL';
  readonly limit?: number;
}

/** Backup encryption validation result */
export interface EncryptionValidationResult {
  readonly backupArn: string;
  readonly encryptionEnabled: boolean;
  readonly encryptionType?: 'AWS_OWNED' | 'KMS' | 'UNKNOWN';
  readonly validatedAt: string;
}

/** Audit entry for backup operations */
export interface BackupAuditEntry {
  readonly operationType: 'INITIATE_BACKUP' | 'LIST_BACKUPS' | 'VALIDATE_ENCRYPTION';
  readonly actorId: string;
  readonly tenantId: string;
  readonly tableName: string;
  readonly backupArn?: string;
  readonly reason?: string;
  readonly stage: string;
  readonly occurredAt: string;
  readonly correlationId: string;
  readonly outcome: 'SUCCESS' | 'FAILURE';
  readonly errorMessage?: string;
}

// ─── Backup Service ──────────────────────────────────────────────────────────

/**
 * BackupService manages on-demand DynamoDB backups using the dedicated
 * BACKUP_RESTORE_ACTIONS role. It never uses the application identity.
 *
 * All backup operations:
 * - Require the backup/restore operational identity
 * - Include stage, tenant, and timestamp tags
 * - Record an audit trail entry for compliance
 */
export class BackupService {
  private readonly stage: string;

  constructor(
    private readonly deps: {
      /** DynamoDB client configured with backup/restore role credentials */
      readonly createBackup: (params: {
        tableName: string;
        backupName: string;
        tags: Record<string, string>;
      }) => Promise<BackupResult>;
      /** Lists backups using backup/restore role */
      readonly listTableBackups: (params: {
        tableName?: string;
        timeRangeUpperBound?: Date;
        timeRangeLowerBound?: Date;
        backupType?: string;
        limit?: number;
      }) => Promise<BackupResult[]>;
      /** Describes backup to check encryption status */
      readonly describeBackup: (backupArn: string) => Promise<{
        encrypted: boolean;
        encryptionType?: string;
      }>;
      /** Records audit trail entry */
      readonly recordAudit: (entry: BackupAuditEntry) => Promise<void>;
    },
    stage: string,
  ) {
    this.stage = stage;
  }

  /**
   * Initiates an on-demand DynamoDB backup.
   *
   * - Requires the dedicated backup/restore identity (not the application role)
   * - Tags backup with stage, tenant, timestamp, and reason
   * - Records audit trail entry regardless of outcome
   */
  async initiateBackup(
    ctx: TenantContextWire,
    params: InitiateBackupParams,
  ): Promise<BackupResult> {
    const now = new Date().toISOString();
    const backupName = `${params.tableName}-${ctx.tenantId}-${Date.now()}`;

    const tags: Record<string, string> = {
      stage: this.stage,
      tenantId: ctx.tenantId,
      createdAt: now,
      reason: params.reason,
      label: params.label,
      initiatedBy: ctx.subjectId,
    };

    try {
      const result = await this.deps.createBackup({
        tableName: params.tableName,
        backupName,
        tags,
      });

      await this.deps.recordAudit({
        operationType: 'INITIATE_BACKUP',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        tableName: params.tableName,
        backupArn: result.backupArn,
        reason: params.reason,
        stage: this.stage,
        occurredAt: now,
        correlationId: ctx.correlationId,
        outcome: 'SUCCESS',
      });

      return result;
    } catch (error) {
      await this.deps.recordAudit({
        operationType: 'INITIATE_BACKUP',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        tableName: params.tableName,
        reason: params.reason,
        stage: this.stage,
        occurredAt: now,
        correlationId: ctx.correlationId,
        outcome: 'FAILURE',
        errorMessage: error instanceof Error ? error.message : 'Unknown error',
      });
      throw error;
    }
  }

  /**
   * Lists available backups with optional filters.
   *
   * Records audit trail for every list operation.
   */
  async listBackups(
    ctx: TenantContextWire,
    filters: ListBackupsFilter = {},
  ): Promise<BackupResult[]> {
    const now = new Date().toISOString();
    const tableName = filters.tableName ?? '';

    try {
      const results = await this.deps.listTableBackups({
        tableName: filters.tableName,
        timeRangeLowerBound: filters.fromDate ? new Date(filters.fromDate) : undefined,
        timeRangeUpperBound: filters.toDate ? new Date(filters.toDate) : undefined,
        backupType: filters.backupType ?? 'ALL',
        limit: filters.limit,
      });

      await this.deps.recordAudit({
        operationType: 'LIST_BACKUPS',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        tableName,
        stage: this.stage,
        occurredAt: now,
        correlationId: ctx.correlationId,
        outcome: 'SUCCESS',
      });

      return results;
    } catch (error) {
      await this.deps.recordAudit({
        operationType: 'LIST_BACKUPS',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        tableName,
        stage: this.stage,
        occurredAt: now,
        correlationId: ctx.correlationId,
        outcome: 'FAILURE',
        errorMessage: error instanceof Error ? error.message : 'Unknown error',
      });
      throw error;
    }
  }

  /**
   * Validates that a backup has encryption enabled.
   *
   * Returns the encryption status and type for compliance evidence.
   */
  async validateBackupEncryption(
    ctx: TenantContextWire,
    backupArn: string,
  ): Promise<EncryptionValidationResult> {
    const now = new Date().toISOString();

    try {
      const description = await this.deps.describeBackup(backupArn);

      await this.deps.recordAudit({
        operationType: 'VALIDATE_ENCRYPTION',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        tableName: '',
        backupArn,
        stage: this.stage,
        occurredAt: now,
        correlationId: ctx.correlationId,
        outcome: 'SUCCESS',
      });

      return {
        backupArn,
        encryptionEnabled: description.encrypted,
        encryptionType: description.encryptionType as EncryptionValidationResult['encryptionType'],
        validatedAt: now,
      };
    } catch (error) {
      await this.deps.recordAudit({
        operationType: 'VALIDATE_ENCRYPTION',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        tableName: '',
        backupArn,
        stage: this.stage,
        occurredAt: now,
        correlationId: ctx.correlationId,
        outcome: 'FAILURE',
        errorMessage: error instanceof Error ? error.message : 'Unknown error',
      });
      throw error;
    }
  }
}
