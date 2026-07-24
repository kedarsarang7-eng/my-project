/**
 * Export Controls — DynamoDB Export-to-S3 Management
 *
 * Provides export initiation and status checking for DynamoDB table exports.
 * All operations require the dedicated BACKUP_RESTORE_ACTIONS identity
 * (separate from the application read role). Export bucket must use approved
 * encryption.
 *
 * Requirements: 6.37–6.40
 */

import type { TenantContextWire } from '../schemas/common.schema';

// ─── Types ───────────────────────────────────────────────────────────────────

/** Export format options */
export type ExportFormat = 'DYNAMODB_JSON' | 'ION';

/** Parameters for initiating a DynamoDB export */
export interface InitiateExportParams {
  /** Source table ARN */
  readonly tableArn: string;
  /** S3 bucket for export (must have approved encryption) */
  readonly s3Bucket: string;
  /** S3 prefix for export files */
  readonly s3Prefix: string;
  /** Point in time for export (ISO 8601); defaults to current time */
  readonly exportTime?: string;
  /** Export format */
  readonly exportFormat: ExportFormat;
  /** Reason for export */
  readonly reason: string;
}

/** Export status */
export type ExportStatus = 'IN_PROGRESS' | 'COMPLETED' | 'FAILED';

/** Result of an export initiation or status check */
export interface ExportResult {
  readonly exportArn: string;
  readonly exportStatus: ExportStatus;
  readonly tableArn: string;
  readonly s3Bucket: string;
  readonly s3Prefix: string;
  readonly exportFormat: ExportFormat;
  readonly exportTime: string;
  readonly startTime?: string;
  readonly endTime?: string;
  readonly itemCount?: number;
  readonly exportSizeBytes?: number;
  readonly encrypted: boolean;
}

/** Audit entry for export operations */
export interface ExportAuditEntry {
  readonly operationType: 'INITIATE_EXPORT' | 'CHECK_EXPORT_STATUS';
  readonly actorId: string;
  readonly tenantId: string;
  readonly tableArn: string;
  readonly exportArn?: string;
  readonly s3Bucket?: string;
  readonly reason?: string;
  readonly stage: string;
  readonly occurredAt: string;
  readonly correlationId: string;
  readonly outcome: 'SUCCESS' | 'FAILURE';
  readonly errorMessage?: string;
}

// ─── Export Service ──────────────────────────────────────────────────────────

/**
 * ExportService manages DynamoDB export-to-S3 operations using the dedicated
 * BACKUP_RESTORE_ACTIONS identity. It never uses the application read role.
 *
 * All export operations:
 * - Require a separate export permission (not application read)
 * - Validate the export bucket has approved encryption
 * - Record an audit trail entry for compliance
 */
export class ExportService {
  private readonly stage: string;

  constructor(
    private readonly deps: {
      /** Initiates DynamoDB export using backup/restore role */
      readonly exportTable: (params: {
        tableArn: string;
        s3Bucket: string;
        s3Prefix: string;
        exportTime?: Date;
        exportFormat: ExportFormat;
      }) => Promise<ExportResult>;
      /** Checks export status/progress using backup/restore role */
      readonly describeExport: (exportArn: string) => Promise<ExportResult>;
      /** Validates S3 bucket encryption configuration */
      readonly validateBucketEncryption: (bucket: string) => Promise<{
        encrypted: boolean;
        encryptionType: string;
      }>;
      /** Records audit trail entry */
      readonly recordAudit: (entry: ExportAuditEntry) => Promise<void>;
    },
    stage: string,
  ) {
    this.stage = stage;
  }

  /**
   * Initiates a DynamoDB export to S3.
   *
   * - Validates the target S3 bucket has approved encryption
   * - Requires the dedicated backup/restore identity (not application role)
   * - Records audit trail regardless of outcome
   */
  async initiateExport(
    ctx: TenantContextWire,
    params: InitiateExportParams,
  ): Promise<ExportResult> {
    const now = new Date().toISOString();

    // Validate bucket encryption before initiating export
    const bucketEncryption = await this.deps.validateBucketEncryption(params.s3Bucket);
    if (!bucketEncryption.encrypted) {
      const error = new Error(
        `Export bucket "${params.s3Bucket}" does not have approved encryption enabled`,
      );
      await this.deps.recordAudit({
        operationType: 'INITIATE_EXPORT',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        tableArn: params.tableArn,
        s3Bucket: params.s3Bucket,
        reason: params.reason,
        stage: this.stage,
        occurredAt: now,
        correlationId: ctx.correlationId,
        outcome: 'FAILURE',
        errorMessage: error.message,
      });
      throw error;
    }

    try {
      const result = await this.deps.exportTable({
        tableArn: params.tableArn,
        s3Bucket: params.s3Bucket,
        s3Prefix: params.s3Prefix,
        exportTime: params.exportTime ? new Date(params.exportTime) : undefined,
        exportFormat: params.exportFormat,
      });

      await this.deps.recordAudit({
        operationType: 'INITIATE_EXPORT',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        tableArn: params.tableArn,
        exportArn: result.exportArn,
        s3Bucket: params.s3Bucket,
        reason: params.reason,
        stage: this.stage,
        occurredAt: now,
        correlationId: ctx.correlationId,
        outcome: 'SUCCESS',
      });

      return result;
    } catch (error) {
      await this.deps.recordAudit({
        operationType: 'INITIATE_EXPORT',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        tableArn: params.tableArn,
        s3Bucket: params.s3Bucket,
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
   * Checks the status/progress of an existing export.
   *
   * Records audit trail for status checks.
   */
  async checkExportStatus(
    ctx: TenantContextWire,
    exportArn: string,
  ): Promise<ExportResult> {
    const now = new Date().toISOString();

    try {
      const result = await this.deps.describeExport(exportArn);

      await this.deps.recordAudit({
        operationType: 'CHECK_EXPORT_STATUS',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        tableArn: result.tableArn,
        exportArn,
        stage: this.stage,
        occurredAt: now,
        correlationId: ctx.correlationId,
        outcome: 'SUCCESS',
      });

      return result;
    } catch (error) {
      await this.deps.recordAudit({
        operationType: 'CHECK_EXPORT_STATUS',
        actorId: ctx.subjectId,
        tenantId: ctx.tenantId,
        tableArn: '',
        exportArn,
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
