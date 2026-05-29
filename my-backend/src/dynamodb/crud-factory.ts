// ============================================================================
// Generic CRUD Service Factory — DynamoDB Multi-Tenant
// ============================================================================
// Provides type-safe CRUD operations for ANY entity type in the single-table.
// Every operation enforces tenant isolation via TenantContext.
//
// Usage:
//   const customerService = createCrudService<DynamoDBCustomer>({
//     entityType: 'CUSTOMER',
//     buildKeys: (ctx, id) => ({ PK: businessPK(...), SK: customerSK(id) }),
//   });
// ============================================================================

import { TenantContext } from './types';
import {
  getItem,
  putItem,
  updateItem,
  queryItems,
  transactWrite,
  TABLE_NAME,
} from './client';
import { businessPK, businessPKFromContext } from './keys';
import { createAuditEntry } from './audit';
import { v4 as uuidv4 } from 'uuid';

// ---- Types ----

export interface EntityKeyBuilder {
  PK: string;
  SK: string;
  GSI1PK?: string;
  GSI1SK?: string;
  GSI2PK?: string;
  GSI2SK?: string;
  GSI3PK?: string;
  GSI3SK?: string;
}

export interface CrudServiceConfig<T> {
  /** Entity type discriminator (e.g., 'CUSTOMER', 'PRODUCT') */
  entityType: string;

  /** Build PK/SK/GSI keys for an entity */
  buildKeys: (ctx: TenantContext, id: string, data?: Partial<T>) => EntityKeyBuilder;

  /** SK prefix for listing (e.g., 'CUSTOMER#') */
  skPrefix: string;

  /** GSI1 index name (if using date queries) */
  gsi1IndexName?: string;

  /** GSI1PK builder for date queries */
  buildGsi1PK?: (ctx: TenantContext) => string;

  /** Fields to validate on create */
  requiredFields?: string[];
}

export interface ListOptions {
  startDate?: string;
  endDate?: string;
  limit?: number;
  nextToken?: string;
  indexName?: string;
  filterExpression?: string;
  expressionAttributeValues?: Record<string, unknown>;
}

export interface CrudService<T> {
  create: (ctx: TenantContext, data: Partial<T> & { id?: string }, auditMeta?: { ipAddress: string; userAgent: string }) => Promise<T>;
  get: (ctx: TenantContext, id: string) => Promise<T | null>;
  list: (ctx: TenantContext, options?: ListOptions) => Promise<{ items: T[]; nextToken?: string }>;
  update: (ctx: TenantContext, id: string, updates: Partial<T>, expectedVersion?: number, auditMeta?: { ipAddress: string; userAgent: string }) => Promise<T>;
  softDelete: (ctx: TenantContext, id: string, expectedVersion: number, auditMeta?: { ipAddress: string; userAgent: string }) => Promise<void>;
}

// ---- Factory ----

export function createCrudService<T extends Record<string, unknown>>(
  config: CrudServiceConfig<T>,
): CrudService<T> {
  const { entityType, buildKeys, skPrefix, gsi1IndexName, buildGsi1PK } = config;

  return {
    // ---- Create ----
    async create(ctx, data, auditMeta) {
      const id = (data as any).id || uuidv4();
      const now = new Date().toISOString();
      const keys = buildKeys(ctx, id, data);

      // Validate required fields
      if (config.requiredFields) {
        for (const field of config.requiredFields) {
          if (!(data as any)[field] && (data as any)[field] !== 0 && (data as any)[field] !== false) {
            throw new Error(`${field} is required for ${entityType}`);
          }
        }
      }

      const item: Record<string, unknown> = {
        ...data,
        ...keys,
        [`${entityType.toLowerCase()}_id`]: id,
        tenant_id: ctx.tenantId,
        business_id: ctx.businessId,
        entity_type: entityType,
        created_at: now,
        updated_at: now,
        created_by: ctx.userId,
        updated_by: ctx.userId,
        version: 1,
        is_deleted: false,
      };

      // Remove 'id' from item (we use entity-specific id field)
      delete item.id;

      const auditEntry = createAuditEntry(ctx, {
        auditId: uuidv4(),
        action: 'CREATE',
        targetEntityType: entityType,
        targetEntityId: id,
        oldValue: null,
        newValue: item,
        isGstRelated: false,
        ipAddress: auditMeta?.ipAddress || 'unknown',
        userAgent: auditMeta?.userAgent || 'unknown',
      });

      await transactWrite({
        TransactItems: [
          { Put: { TableName: TABLE_NAME, Item: item } },
          { Put: { TableName: TABLE_NAME, Item: auditEntry } },
        ],
      });

      return item as unknown as T;
    },

    // ---- Get ----
    async get(ctx, id) {
      const keys = buildKeys(ctx, id);
      const item = await getItem<T>(keys.PK, keys.SK);

      if (!item) return null;
      if ((item as any).is_deleted) return null;

      // Validate ownership
      if ((item as any).tenant_id !== ctx.tenantId) {
        throw new Error(`SECURITY: Cross-tenant ${entityType} access attempt`);
      }

      return item;
    },

    // ---- List ----
    async list(ctx, options = {}) {
      let pk: string;
      let queryOpts: Record<string, unknown> = {};

      if (options.startDate && options.endDate && gsi1IndexName && buildGsi1PK) {
        // Date range query via GSI1
        pk = buildGsi1PK(ctx);
        queryOpts = {
          indexName: gsi1IndexName,
          skBetween: { start: options.startDate, end: options.endDate },
        };
      } else {
        // Primary table query
        pk = businessPKFromContext(ctx);
        queryOpts = {
          skBeginsWith: skPrefix,
        };
      }

      if (options.limit) queryOpts.limit = options.limit;

      const result = await queryItems<T>(pk, queryOpts);

      // Filter out soft-deleted
      const items = result.items.filter((item: any) => !item.is_deleted);

      return { items };
    },

    // ---- Update ----
    async update(ctx, id, updates, expectedVersion, auditMeta) {
      const keys = buildKeys(ctx, id);

      // Get current item for audit trail
      const current = await getItem<T>(keys.PK, keys.SK);
      if (!current || (current as any).is_deleted) {
        throw new Error(`${entityType} ${id} not found`);
      }
      if ((current as any).tenant_id !== ctx.tenantId) {
        throw new Error(`SECURITY: Cross-tenant ${entityType} update attempt`);
      }

      const now = new Date().toISOString();

      // Build update expression
      const updateFields: string[] = [];
      const exprValues: Record<string, unknown> = {};

      for (const [key, value] of Object.entries(updates)) {
        if (['PK', 'SK', 'tenant_id', 'business_id', 'entity_type', 'created_at', 'created_by'].includes(key)) continue;
        updateFields.push(`${key} = :${key}`);
        exprValues[`:${key}`] = value;
      }

      updateFields.push('updated_at = :updatedAt');
      exprValues[':updatedAt'] = now;
      updateFields.push('updated_by = :updatedBy');
      exprValues[':updatedBy'] = ctx.userId;
      updateFields.push('version = version + :inc');
      exprValues[':inc'] = 1;

      const updateExpression = `SET ${updateFields.join(', ')}`;

      // Optimistic locking
      let conditionExpression = 'attribute_exists(PK) AND is_deleted = :notDeleted';
      exprValues[':notDeleted'] = false;

      if (expectedVersion !== undefined) {
        conditionExpression += ' AND version = :expectedVersion';
        exprValues[':expectedVersion'] = expectedVersion;
      }

      const result = await updateItem(
        keys.PK,
        keys.SK,
        updateExpression,
        exprValues,
        { conditionExpression },
      );

      return result as unknown as T;
    },

    // ---- Soft Delete ----
    async softDelete(ctx, id, expectedVersion, auditMeta) {
      const keys = buildKeys(ctx, id);

      const current = await getItem<T>(keys.PK, keys.SK);
      if (!current) {
        throw new Error(`${entityType} ${id} not found`);
      }
      if ((current as any).tenant_id !== ctx.tenantId) {
        throw new Error(`SECURITY: Cross-tenant ${entityType} delete attempt`);
      }

      const now = new Date().toISOString();

      await updateItem(
        keys.PK,
        keys.SK,
        'SET is_deleted = :deleted, deleted_at = :deletedAt, deleted_by = :deletedBy, version = version + :inc',
        {
          ':deleted': true,
          ':deletedAt': now,
          ':deletedBy': ctx.userId,
          ':inc': 1,
          ':expectedVersion': expectedVersion,
          ':notDeleted': false,
        },
        {
          conditionExpression: 'version = :expectedVersion AND is_deleted = :notDeleted',
        },
      );
    },
  };
}
