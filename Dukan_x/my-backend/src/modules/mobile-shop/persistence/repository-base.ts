/**
 * Repository Base — MobileShop DynamoDB Persistence
 *
 * Provides shared DynamoDB DocumentClient access, tenant validation on every
 * returned item, pagination limit enforcement, and typed result containers.
 *
 * Requirements: 6.6, 6.14, 6.19, 6.29, 8.9
 */

import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire } from '../schemas/common.schema';
import type { QueryInput, GetInput } from './access-patterns';
import { verifyItemTenant } from './key-codec';
import { PAGINATION_CONFIG } from '../config/pagination.config';

// ─── Types ───────────────────────────────────────────────────────────────────

/** A DynamoDB item record */
export type DynamoItem = Record<string, unknown>;

/** Paginated query result */
export interface PaginatedResult<T = DynamoItem> {
  readonly items: readonly T[];
  /** Raw LastEvaluatedKey for the continuation-token service to encrypt */
  readonly lastEvaluatedKey?: Record<string, unknown>;
  readonly hasMore: boolean;
  readonly count: number;
}

/** Single-item get result */
export interface GetResult<T = DynamoItem> {
  readonly item: T | null;
}

/** Security fault detail (logged, never returned to caller) */
export interface TenantMismatchFault {
  readonly expectedTenantId: string;
  readonly actualTenantId: unknown;
  readonly accessPatternId: string;
  readonly correlationId: string;
  readonly timestamp: string;
}

/** Logger interface — callers provide their own implementation */
export interface RepositoryLogger {
  warn(message: string, meta?: Record<string, unknown>): void;
  error(message: string, meta?: Record<string, unknown>): void;
  info(message: string, meta?: Record<string, unknown>): void;
}

// ─── Configuration ───────────────────────────────────────────────────────────

export interface RepositoryBaseConfig {
  /** DynamoDB table name */
  readonly tableName: string;
  /** Logger instance */
  readonly logger: RepositoryLogger;
}

// ─── Base Repository ─────────────────────────────────────────────────────────

/**
 * Abstract base repository providing:
 * - DynamoDB DocumentClient access
 * - Tenant verification on returned items (security fault on mismatch)
 * - Bounded pagination limits
 * - Typed query/get execution
 */
export abstract class RepositoryBase {
  protected readonly client: DynamoDBDocumentClient;
  protected readonly tableName: string;
  protected readonly logger: RepositoryLogger;

  constructor(client: DynamoDBDocumentClient, config: RepositoryBaseConfig) {
    this.client = client;
    this.tableName = config.tableName;
    this.logger = config.logger;
  }

  // ─── Query Execution ─────────────────────────────────────────────────────

  /**
   * Execute a typed query and validate tenant on every returned item.
   * Items failing tenant verification are silently dropped and a security fault is logged.
   */
  protected async executeQuery(
    ctx: TenantContextWire,
    input: QueryInput,
  ): Promise<PaginatedResult> {
    const { QueryCommand } = await import('@aws-sdk/lib-dynamodb');

    const command = new QueryCommand({
      TableName: this.tableName,
      IndexName: input.indexName,
      KeyConditionExpression: input.keyConditionExpression,
      ExpressionAttributeValues: input.expressionAttributeValues as Record<string, unknown>,
      ExpressionAttributeNames: input.expressionAttributeNames,
      Limit: input.limit,
      ScanIndexForward: input.scanIndexForward,
      ConsistentRead: input.consistentRead,
      ExclusiveStartKey: input.exclusiveStartKey as Record<string, unknown> | undefined,
      ReturnConsumedCapacity: 'TOTAL',
    });

    const result = await this.client.send(command);
    const rawItems = (result.Items ?? []) as DynamoItem[];

    // Validate tenant on every returned item
    const validItems = this.filterByTenant(ctx, rawItems, input.accessPatternId);

    return {
      items: validItems,
      lastEvaluatedKey: result.LastEvaluatedKey as Record<string, unknown> | undefined,
      hasMore: !!result.LastEvaluatedKey,
      count: validItems.length,
    };
  }

  // ─── Get Execution ───────────────────────────────────────────────────────

  /**
   * Execute a typed get and validate tenant on the returned item.
   * Returns null if not found or tenant mismatch.
   */
  protected async executeGet(
    ctx: TenantContextWire,
    input: GetInput,
  ): Promise<GetResult> {
    const { GetCommand } = await import('@aws-sdk/lib-dynamodb');

    const command = new GetCommand({
      TableName: this.tableName,
      Key: input.key,
      ConsistentRead: input.consistentRead,
      ReturnConsumedCapacity: 'TOTAL',
    });

    const result = await this.client.send(command);
    const item = result.Item as DynamoItem | undefined;

    if (!item) {
      return { item: null };
    }

    // Verify tenant identity on returned item
    if (!verifyItemTenant(item, ctx.tenantId)) {
      this.logTenantMismatch(ctx, item, input.accessPatternId);
      return { item: null };
    }

    return { item };
  }

  // ─── Pagination Helpers ──────────────────────────────────────────────────

  /**
   * Clamp a requested limit to configured bounds.
   */
  protected clampLimit(requestedLimit?: number): number {
    if (requestedLimit === undefined || requestedLimit === null) {
      return PAGINATION_CONFIG.defaultPageSize;
    }
    return Math.max(
      PAGINATION_CONFIG.minPageSize,
      Math.min(requestedLimit, PAGINATION_CONFIG.maxPageSize),
    );
  }

  // ─── Tenant Verification ────────────────────────────────────────────────

  /**
   * Filter items by tenant identity. Items that fail verification are
   * dropped and a security fault is logged.
   */
  private filterByTenant(
    ctx: TenantContextWire,
    items: DynamoItem[],
    accessPatternId: string,
  ): DynamoItem[] {
    const valid: DynamoItem[] = [];

    for (const item of items) {
      if (verifyItemTenant(item, ctx.tenantId)) {
        valid.push(item);
      } else {
        this.logTenantMismatch(ctx, item, accessPatternId);
      }
    }

    return valid;
  }

  /**
   * Log a security fault when a returned item's tenantId doesn't match.
   * Never discloses the mismatched item to the caller.
   */
  private logTenantMismatch(
    ctx: TenantContextWire,
    item: DynamoItem,
    accessPatternId: string,
  ): void {
    const fault: TenantMismatchFault = {
      expectedTenantId: ctx.tenantId,
      actualTenantId: item['tenantId'],
      accessPatternId,
      correlationId: ctx.correlationId,
      timestamp: new Date().toISOString(),
    };

    this.logger.error('SECURITY_FAULT: Tenant mismatch on returned item', {
      fault,
      // Never log the full item content — only metadata for investigation
      itemPK: item['PK'],
      itemSK: item['SK'],
    });
  }
}
