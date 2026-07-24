/**
 * Restore Controls — DynamoDB Table Restore and Drill Automation
 *
 * Provides PITR and backup-based restore initiation, target validation,
 * and restore-drill recording for compliance evidence. All operations
 * require the dedicated BACKUP_RESTORE_ACTIONS identity (separate from
 * the application role).
 *
 * Requirements: 6.37–6.40
 */

import type { TenantContextWire } from '../schemas/common.schema';

// ─── Types ───────────────────────────────────────────────────────────────────

/** Restore source type */
export type RestoreSource = 'POINT_IN_TIME' | 'FROM_BACKUP';

/** Parameters for initiating a table restore */
export interface InitiateRestoreParams {
  /** Source table name */
  readonly sourceTableName: string;
  /** Target table name for the restore (must not conflict) */
  readonly targetTableName: string;
  /** Type of restore */
  readonly restoreSource: RestoreSource;
  /** For PITR: point in time to restore to (ISO 8601) */
  readonly restoreDateTime?: string;
  /** For FROM_BACKUP: the backup ARN to restore from */
  readonly backupArn?: string;
  /** Reason for the restore operation */
  readonly reason: string;
}

/** Result of a restore initiation */
export interface RestoreResult {
  readonly targetTableName: string;
  readonly restoreSource: RestoreSource;
  readonly restoreStatus: 'RESTORING' | 'ACTIVE' | 'FAILED';
  readonly restoreDateTime?: string;
  readonly backupArn?: string;
  readonly initiatedAt: string;
}

/** Target validation result */
export interface TargetValidationResult {
  readonly targetTableName: string;
  readonly isValid: boolean;
  readonly conflictReason?: string;
  readonly validatedAt: string;
}

/** Restore drill result for compliance recording */
export interface RestoreDrillResult {
  readonly drillId: string;
  readonly sourceTableName: string;
  readonly targetTableName: string;
  readonly restoreSource: RestoreSource;
  readonly startedAt: string;
  readonly completedAt: string;
  readonly durationMs: number;
  readonly recordCountVerified: boolean;
  readonly dataIntegrityPassed: boolean;
  readonly encryptionVerified: boolean;
  readonly notes?: string;
  readonly outcome: 'PASS' | 'FAIL' | 'PARTIAL';
}

/** Audit entry for restore operations */
export interface RestoreAuditEntry {
  readonly operationType:
    | 'INITIATE_RESTORE'
    | 'VALIDATE_TARGET'
    | 'RECORD_DRILL';
  readonly actorId: string;
  readonly tenantId: string;
  readonly sourceTableName?: string;
  readonly targetTableName: string;
  readonly restoreSource?: RestoreSource;
  readonly stage: string;
  readonly occurredAt: string;
  readonly correlationId: string;
  readonly outcome: 'SUCCESS' | 'FAILURE';
  readonly errorMessage?: string;
}

// ─── Restore Service ─────────────────────────────────────────────────────────

/**
 * RestoreService manages DynamoDB table restore operations using the dedicated
 * BACKUP_RESTORE_ACTIONS identity. Supports both PITR and backup-based restores.
 *
 * Also provides restore-drill automation: scheduled or manual drill execution
 * with compliance evidence recording.
 */
export class RestoreService {
  private readonly stage: string;

  constructor(
    private readonly deps: {
      /** Restore table from PITR using backup/restore role */
      readonly restoreToPointInTime: (params: {
        sourceTableName: string;
        targetTableName: string;
        restoreDateTime: Date;
      }) => Promise<RestoreResult>;
      /** Restore table from backup using backup/restore role */
      readonly restoreFromBackup: (params: {
        backupArn: string;
        targetTableName: string;
      }) => Promise<RestoreResult>;
      /** Check whether a table name already exists */
      readonly tableExists: (tableName: string) => Promise<boolean>;
      /** Persist drill result for compliance evidence */
      readonly persistDrillResult: (result: RestoreDrillResult) => Promise<void>;
      /** Records audit trail entry */
      readonly recordAudit: (entry: RestoreAuditEntry) => Promise<void>;
    },
    stage: string,
  ) {
    this.stage = stage;
  }

  /**
   * Initiates a table restore operation.
   *
   * - Validates restore parameters and target table name
   * - Uses the dedicated backup/restore identity (never application role)
   * - Records audit trail regardless of outcome
   */
  async initiateRestore(
    ctx: TenantContextWire,
    params: InitiateRestoreParams,
  ): Promise<RestoreResult> {
    const now = new Date().toISOString();

    // Validate target doesn't conflict
    const targetValidation = await this.validateRestoreTarget(ctx, params.targetTableName);
    if (!targetValidation.isValid) {
      const error = new Error(
        `Restore target conflict: ${targetValidation.conflictReason}`,
      );
      await this.deps.recordAudit({
        operationType: 'INITIATE_RESTORE',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        sourceTableName: params.sourceTableName,
        targetTableName: params.targetTableName,
        restoreSource: params.restoreSource,
        stage: this.stage,
        occurredAt: now,
        correlationId: ctx.correlationId,
        outcome: 'FAILURE',
        errorMessage: error.message,
      });
      throw error;
    }

    try {
      let result: RestoreResult;

      if (params.restoreSource === 'POINT_IN_TIME') {
        if (!params.restoreDateTime) {
          throw new Error('restoreDateTime is required for POINT_IN_TIME restore');
        }
        result = await this.deps.restoreToPointInTime({
          sourceTableName: params.sourceTableName,
          targetTableName: params.targetTableName,
          restoreDateTime: new Date(params.restoreDateTime),
        });
      } else {
        if (!params.backupArn) {
          throw new Error('backupArn is required for FROM_BACKUP restore');
        }
        result = await this.deps.restoreFromBackup({
          backupArn: params.backupArn,
          targetTableName: params.targetTableName,
        });
      }

      await this.deps.recordAudit({
        operationType: 'INITIATE_RESTORE',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        sourceTableName: params.sourceTableName,
        targetTableName: params.targetTableName,
        restoreSource: params.restoreSource,
        stage: this.stage,
        occurredAt: now,
        correlationId: ctx.correlationId,
        outcome: 'SUCCESS',
      });

      return result;
    } catch (error) {
      await this.deps.recordAudit({
        operationType: 'INITIATE_RESTORE',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        sourceTableName: params.sourceTableName,
        targetTableName: params.targetTableName,
        restoreSource: params.restoreSource,
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
   * Validates that a target table name does not conflict with existing tables.
   *
   * Prevents accidental overwrites during restore operations.
   */
  async validateRestoreTarget(
    ctx: TenantContextWire,
    targetTableName: string,
  ): Promise<TargetValidationResult> {
    const now = new Date().toISOString();

    const exists = await this.deps.tableExists(targetTableName);

    await this.deps.recordAudit({
      operationType: 'VALIDATE_TARGET',
      actorId: ctx.subjectId,
      tenantId: ctx.tenantId,
      targetTableName,
      stage: this.stage,
      occurredAt: now,
      correlationId: ctx.correlationId,
      outcome: 'SUCCESS',
    });

    if (exists) {
      return {
        targetTableName,
        isValid: false,
        conflictReason: `Table "${targetTableName}" already exists`,
        validatedAt: now,
      };
    }

    return {
      targetTableName,
      isValid: true,
      validatedAt: now,
    };
  }

  /**
   * Records a restore drill result for compliance evidence.
   *
   * Restore drills verify that backup/PITR recovery works correctly.
   * Can be triggered as a scheduled check or manually by operators.
   */
  async recordRestoreDrill(
    ctx: TenantContextWire,
    drillResult: RestoreDrillResult,
  ): Promise<void> {
    const now = new Date().toISOString();

    try {
      await this.deps.persistDrillResult(drillResult);

      await this.deps.recordAudit({
        operationType: 'RECORD_DRILL',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        sourceTableName: drillResult.sourceTableName,
        targetTableName: drillResult.targetTableName,
        restoreSource: drillResult.restoreSource,
        stage: this.stage,
        occurredAt: now,
        correlationId: ctx.correlationId,
        outcome: 'SUCCESS',
      });
    } catch (error) {
      await this.deps.recordAudit({
        operationType: 'RECORD_DRILL',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        sourceTableName: drillResult.sourceTableName,
        targetTableName: drillResult.targetTableName,
        restoreSource: drillResult.restoreSource,
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
