/**
 * Resumable Backfill — Durable Checkpoint Migration Processing
 *
 * Processes records in bounded pages with durable checkpoints persisted in DynamoDB.
 * Supports safe resume from the last confirmed position after Lambda timeout/restart,
 * conditional writes that preserve records already migrated or changed by newer operations,
 * and idempotent reruns (same backfill ID produces same result).
 *
 * Checkpoint key: PK=TENANT#<tenantId>#BACKFILL#<backfillId>
 *
 * Requirements: 6.20–6.21, 6.33–6.36, 13.3–13.4
 */

import { MODEL_VERSION_CONFIG } from '../config/model-version.config';
import { PAGINATION_CONFIG } from '../config/pagination.config';

// ─── Types ───────────────────────────────────────────────────────────────────

export type BackfillStatus = 'INITIALIZED' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED' | 'ROLLED_BACK';

/** Backfill parameters defining what and how to migrate */
export interface BackfillParams {
  /** Source data model version to migrate from */
  readonly fromVersion: number;
  /** Target data model version to migrate to */
  readonly toVersion: number;
  /** Entity types to process (empty = all) */
  readonly entityTypes?: readonly string[];
  /** Maximum records per page */
  readonly pageSize?: number;
  /** Optional DynamoDB filter expression for record selection */
  readonly filterExpression?: string;
  /** Optional expression attribute values for filter */
  readonly expressionAttributeValues?: Readonly<Record<string, unknown>>;
}

/** Durable checkpoint persisted in DynamoDB */
export interface BackfillCheckpoint {
  /** Partition key: TENANT#<tenantId>#BACKFILL#<backfillId> */
  readonly PK: string;
  /** Sort key: META#BACKFILL */
  readonly SK: string;
  readonly tenantId: string;
  readonly backfillId: string;
  readonly status: BackfillStatus;
  readonly params: BackfillParams;
  /** Last evaluated key from the previous page (for resume) */
  readonly lastEvaluatedKey?: Record<string, unknown>;
  /** Total records processed so far */
  readonly processedCount: number;
  /** Total records skipped (already migrated or newer) */
  readonly skippedCount: number;
  /** Total records failed */
  readonly failedCount: number;
  /** Number of pages completed */
  readonly pagesCompleted: number;
  /** Timestamp of initialization */
  readonly startedAt: string;
  /** Timestamp of last checkpoint update */
  readonly lastCheckpointAt: string;
  /** Timestamp of completion (if completed) */
  readonly completedAt?: string;
  /** Error details if failed */
  readonly lastError?: string;
  /** Data model version stamped on the checkpoint itself */
  readonly dataModelVersion: number;
}

/** Result of processing a single page */
export interface PageResult {
  /** Records successfully migrated in this page */
  readonly migratedCount: number;
  /** Records skipped (already at target version or newer) */
  readonly skippedCount: number;
  /** Records that failed migration in this page */
  readonly failedCount: number;
  /** Whether more pages exist */
  readonly hasMore: boolean;
  /** Last evaluated key for the next page */
  readonly lastEvaluatedKey?: Record<string, unknown>;
}

/** Context for backfill operations (tenant + DynamoDB access) */
export interface BackfillContext {
  readonly tenantId: string;
  readonly tableName: string;
  readonly correlationId: string;
  /** DynamoDB DocumentClient send function */
  readonly send: (command: unknown) => Promise<unknown>;
}

// ─── Key Encoding ────────────────────────────────────────────────────────────

function buildBackfillPK(tenantId: string, backfillId: string): string {
  return `TENANT#${tenantId}#BACKFILL#${backfillId}`;
}

const BACKFILL_SK = 'META#BACKFILL';

// ─── Resumable Backfill ──────────────────────────────────────────────────────

export class ResumableBackfill {
  private readonly defaultPageSize: number;

  constructor(config?: { defaultPageSize?: number }) {
    this.defaultPageSize = config?.defaultPageSize ?? PAGINATION_CONFIG.defaultPageSize;
  }

  /**
   * Initialize a new backfill with a durable checkpoint.
   * Uses a conditional write to ensure the same backfillId is not re-initialized
   * (idempotent: if already exists, returns existing checkpoint).
   */
  async start(
    ctx: BackfillContext,
    backfillId: string,
    params: BackfillParams,
  ): Promise<BackfillCheckpoint> {
    const now = new Date().toISOString();
    const checkpoint: BackfillCheckpoint = {
      PK: buildBackfillPK(ctx.tenantId, backfillId),
      SK: BACKFILL_SK,
      tenantId: ctx.tenantId,
      backfillId,
      status: 'INITIALIZED',
      params,
      processedCount: 0,
      skippedCount: 0,
      failedCount: 0,
      pagesCompleted: 0,
      startedAt: now,
      lastCheckpointAt: now,
      dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
    };

    try {
      // Conditional write: only create if not already exists (prevents re-init)
      await ctx.send({
        type: 'PutCommand',
        input: {
          TableName: ctx.tableName,
          Item: checkpoint,
          ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
        },
      });
    } catch (err: unknown) {
      // If the checkpoint already exists, it's an idempotent re-start
      if (isConditionalCheckFailed(err)) {
        const existing = await this.getCheckpoint(ctx, backfillId);
        if (existing) {
          return existing;
        }
      }
      throw err;
    }

    return checkpoint;
  }

  /**
   * Process a bounded page of records.
   * - Reads records using the last evaluated key from the checkpoint
   * - Applies conditional writes that skip records already at target version or newer
   * - Updates the durable checkpoint after successful processing
   */
  async processPage(
    ctx: BackfillContext,
    backfillId: string,
    page: {
      items: readonly Record<string, unknown>[];
      lastEvaluatedKey?: Record<string, unknown>;
      hasMore: boolean;
    },
    migrateFn: (item: Record<string, unknown>) => Record<string, unknown>,
    targetVersion: number,
  ): Promise<PageResult> {
    let migratedCount = 0;
    let skippedCount = 0;
    let failedCount = 0;

    for (const item of page.items) {
      const itemVersion = Number(item['dataModelVersion'] ?? 0);

      // Skip records already at target version or newer (conditional write semantics)
      if (itemVersion >= targetVersion) {
        skippedCount++;
        continue;
      }

      try {
        const migratedItem = migrateFn(item);
        migratedItem['dataModelVersion'] = targetVersion;

        // Conditional write: only update if the record hasn't been changed
        // by a newer operation (version guard)
        await ctx.send({
          type: 'PutCommand',
          input: {
            TableName: ctx.tableName,
            Item: migratedItem,
            // Only write if the version is still what we read (no concurrent newer writes)
            ConditionExpression: '#dmv = :expectedVersion',
            ExpressionAttributeNames: { '#dmv': 'dataModelVersion' },
            ExpressionAttributeValues: { ':expectedVersion': itemVersion },
          },
        });

        migratedCount++;
      } catch (err: unknown) {
        if (isConditionalCheckFailed(err)) {
          // Record was already migrated or changed by a newer operation — skip
          skippedCount++;
        } else {
          failedCount++;
        }
      }
    }

    // Update the durable checkpoint after page processing
    const now = new Date().toISOString();
    await ctx.send({
      type: 'UpdateCommand',
      input: {
        TableName: ctx.tableName,
        Key: {
          PK: buildBackfillPK(ctx.tenantId, backfillId),
          SK: BACKFILL_SK,
        },
        UpdateExpression: `SET #status = :status, #lek = :lek, #pc = #pc + :migrated + :skipped + :failed, #sc = #sc + :skipped, #fc = #fc + :failed, #pages = #pages + :one, #lca = :now, #hasMore = :hasMore`,
        ExpressionAttributeNames: {
          '#status': 'status',
          '#lek': 'lastEvaluatedKey',
          '#pc': 'processedCount',
          '#sc': 'skippedCount',
          '#fc': 'failedCount',
          '#pages': 'pagesCompleted',
          '#lca': 'lastCheckpointAt',
          '#hasMore': 'hasMore',
        },
        ExpressionAttributeValues: {
          ':status': page.hasMore ? 'IN_PROGRESS' : 'COMPLETED',
          ':lek': page.lastEvaluatedKey ?? null,
          ':migrated': migratedCount,
          ':skipped': skippedCount,
          ':failed': failedCount,
          ':one': 1,
          ':now': now,
          ':hasMore': page.hasMore,
        },
      },
    });

    return {
      migratedCount,
      skippedCount,
      failedCount,
      hasMore: page.hasMore,
      lastEvaluatedKey: page.lastEvaluatedKey,
    };
  }

  /**
   * Resume a backfill from the last durable checkpoint.
   * Returns the checkpoint with the last evaluated key for continuation.
   * The caller uses lastEvaluatedKey to fetch the next page and calls processPage.
   */
  async resume(ctx: BackfillContext, backfillId: string): Promise<BackfillCheckpoint | null> {
    const checkpoint = await this.getCheckpoint(ctx, backfillId);
    if (!checkpoint) {
      return null;
    }

    // Only resume if the backfill is in a resumable state
    if (checkpoint.status === 'COMPLETED' || checkpoint.status === 'ROLLED_BACK') {
      return checkpoint;
    }

    // Mark as IN_PROGRESS on resume
    if (checkpoint.status === 'INITIALIZED' || checkpoint.status === 'FAILED') {
      const now = new Date().toISOString();
      await ctx.send({
        type: 'UpdateCommand',
        input: {
          TableName: ctx.tableName,
          Key: {
            PK: buildBackfillPK(ctx.tenantId, backfillId),
            SK: BACKFILL_SK,
          },
          UpdateExpression: 'SET #status = :status, #lca = :now',
          ExpressionAttributeNames: {
            '#status': 'status',
            '#lca': 'lastCheckpointAt',
          },
          ExpressionAttributeValues: {
            ':status': 'IN_PROGRESS',
            ':now': now,
          },
        },
      });

      return { ...checkpoint, status: 'IN_PROGRESS', lastCheckpointAt: now };
    }

    return checkpoint;
  }

  /**
   * Mark a backfill as complete.
   * Conditional on the backfill being in IN_PROGRESS state.
   */
  async complete(ctx: BackfillContext, backfillId: string): Promise<BackfillCheckpoint | null> {
    const now = new Date().toISOString();

    try {
      await ctx.send({
        type: 'UpdateCommand',
        input: {
          TableName: ctx.tableName,
          Key: {
            PK: buildBackfillPK(ctx.tenantId, backfillId),
            SK: BACKFILL_SK,
          },
          UpdateExpression: 'SET #status = :completed, #completedAt = :now, #lca = :now',
          ConditionExpression: '#status = :inProgress OR #status = :initialized',
          ExpressionAttributeNames: {
            '#status': 'status',
            '#completedAt': 'completedAt',
            '#lca': 'lastCheckpointAt',
          },
          ExpressionAttributeValues: {
            ':completed': 'COMPLETED',
            ':inProgress': 'IN_PROGRESS',
            ':initialized': 'INITIALIZED',
            ':now': now,
          },
        },
      });
    } catch (err: unknown) {
      if (isConditionalCheckFailed(err)) {
        // Already completed or in an incompatible state
        return this.getCheckpoint(ctx, backfillId);
      }
      throw err;
    }

    return this.getCheckpoint(ctx, backfillId);
  }

  /**
   * Mark a backfill as failed with error details.
   */
  async fail(ctx: BackfillContext, backfillId: string, error: string): Promise<void> {
    const now = new Date().toISOString();

    await ctx.send({
      type: 'UpdateCommand',
      input: {
        TableName: ctx.tableName,
        Key: {
          PK: buildBackfillPK(ctx.tenantId, backfillId),
          SK: BACKFILL_SK,
        },
        UpdateExpression: 'SET #status = :failed, #lastError = :error, #lca = :now',
        ExpressionAttributeNames: {
          '#status': 'status',
          '#lastError': 'lastError',
          '#lca': 'lastCheckpointAt',
        },
        ExpressionAttributeValues: {
          ':failed': 'FAILED',
          ':error': error,
          ':now': now,
        },
      },
    });
  }

  /**
   * Rollback: mark backfill as rolled back.
   * Used for forward-recovery or undoing a partial migration.
   */
  async rollback(ctx: BackfillContext, backfillId: string, reason: string): Promise<void> {
    const now = new Date().toISOString();

    await ctx.send({
      type: 'UpdateCommand',
      input: {
        TableName: ctx.tableName,
        Key: {
          PK: buildBackfillPK(ctx.tenantId, backfillId),
          SK: BACKFILL_SK,
        },
        UpdateExpression: 'SET #status = :rolledBack, #lastError = :reason, #lca = :now',
        ExpressionAttributeNames: {
          '#status': 'status',
          '#lastError': 'lastError',
          '#lca': 'lastCheckpointAt',
        },
        ExpressionAttributeValues: {
          ':rolledBack': 'ROLLED_BACK',
          ':reason': reason,
          ':now': now,
        },
      },
    });
  }

  /**
   * Get the effective page size for a backfill, bounded by configuration.
   */
  getPageSize(params: BackfillParams): number {
    const requested = params.pageSize ?? this.defaultPageSize;
    return Math.max(1, Math.min(requested, PAGINATION_CONFIG.maxPageSize));
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  private async getCheckpoint(
    ctx: BackfillContext,
    backfillId: string,
  ): Promise<BackfillCheckpoint | null> {
    const result = await ctx.send({
      type: 'GetCommand',
      input: {
        TableName: ctx.tableName,
        Key: {
          PK: buildBackfillPK(ctx.tenantId, backfillId),
          SK: BACKFILL_SK,
        },
        ConsistentRead: true,
      },
    }) as { Item?: BackfillCheckpoint };

    return result?.Item ?? null;
  }
}

// ─── Utility ─────────────────────────────────────────────────────────────────

function isConditionalCheckFailed(err: unknown): boolean {
  if (err && typeof err === 'object') {
    const name = (err as { name?: string }).name;
    const code = (err as { code?: string }).code;
    return (
      name === 'ConditionalCheckFailedException' ||
      code === 'ConditionalCheckFailedException'
    );
  }
  return false;
}
