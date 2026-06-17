// ============================================================================
// Lambda Handler — Generic Entity Actions (Soft Delete, Restore, Update)
// ============================================================================
// Purpose: Unified CRUD operations with soft-delete support
// Handles: Products, Customers, Staff, Suppliers, Job Cards, Orders
// ============================================================================
import { configureAwsClient } from '../config/aws.config';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, queryItems, putItem, updateItem, getItem, TABLE_NAME } from '../config/dynamodb.config';
import { parseBody } from '../middleware/validation';
import { DynamoDBClient, DeleteItemCommand } from '@aws-sdk/client-dynamodb';
import { marshall } from '@aws-sdk/util-dynamodb';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { AuthContext, UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { recordRevision } from '../services/revision-history.service';

const dynamo = new DynamoDBClient(configureAwsClient({}));

// ── Entity Types ─────────────────────────────────────────────────────────────

type EntityType = 
  | 'PRODUCT' 
  | 'CUSTOMER' 
  | 'STAFF' 
  | 'SUPPLIER' 
  | 'AUTOPARTS_JOB_CARD'
  | 'JEWELLERY_CUSTOM_ORDER'
  | 'JEWELLERY_OLD_GOLD_EXCHANGE'
  | 'HALLMARK_JEWELLERY';

interface SoftDeleteItem {
  isDeleted: boolean;
  deletedAt?: string;
  deletedBy?: string;
  originalSK?: string;
}

// ── Validation Schemas ───────────────────────────────────────────────────────

import { z } from 'zod';

const updateSchema = z.object({
  status: z.string().optional(),
  isActive: z.boolean().optional(),
  isBlocked: z.boolean().optional(),
  blockReason: z.string().optional(),
}).passthrough();

// ── Helper Functions ─────────────────────────────────────────────────────────

function getSKPrefix(entityType: EntityType): string {
  const prefixes: Record<EntityType, string> = {
    'PRODUCT': 'PRODUCT#',
    'CUSTOMER': 'CUSTOMER#',
    'STAFF': 'STAFF#',
    'SUPPLIER': 'SUPPLIER#',
    'AUTOPARTS_JOB_CARD': 'AUTOPARTS_JOB_CARD#',
    'JEWELLERY_CUSTOM_ORDER': 'JEWELLERY_ORDER#',
    'JEWELLERY_OLD_GOLD_EXCHANGE': 'JEWELLERY_EXCHANGE#',
    'HALLMARK_JEWELLERY': 'PRODUCT#',
  };
  return prefixes[entityType] || `${entityType}#`;
}

async function getEntityById(
  tenantId: string,
  entityType: EntityType,
  entityId: string,
): Promise<Record<string, unknown> | null> {
  const pk = Keys.tenantPK(tenantId);
  const skPrefix = getSKPrefix(entityType);
  
  // Try direct lookup first
  const directResult = await getItem<Record<string, unknown>>(
    pk,
    `${skPrefix}${entityId}`,
  );
  
  if (directResult) return directResult;
  
  // Query by ID field if direct lookup fails
  const queryResult = await queryItems(
    pk,
    skPrefix,
    {
      filterExpression: 'entityId = :id OR id = :id',
      expressionAttributeValues: { ':id': entityId },
    },
  );
  
  const items = queryResult.items || [];
  return items.length > 0 ? items[0] : null;
}

// ─── Soft Delete Handler ─────────────────────────────────────────────────────

/**
 * DELETE /{entityType}/{id}?soft=true
 * Soft delete an entity (marks as deleted, moves to recycle bin)
 */
export const softDeleteEntity = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const entityType = event.pathParameters?.entityType?.toUpperCase() as EntityType;
    const entityId = event.pathParameters?.id;
    
    if (!entityType || !entityId) {
      return response.badRequest('Entity type and ID are required');
    }

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getEntityById(auth.tenantId, entityType, entityId);
    
    if (!existing) {
      return response.notFound(`${entityType} not found`);
    }

    const sk = existing.SK as string;
    const now = new Date().toISOString();

    // Mark as deleted
    const updateResult = await updateItem(pk, sk, {
      updateExpression: 'SET #isDeleted = :deleted, #deletedAt = :now, #deletedBy = :userId, #originalSK = :sk',
      expressionAttributeNames: {
        '#isDeleted': 'isDeleted',
        '#deletedAt': 'deletedAt',
        '#deletedBy': 'deletedBy',
        '#originalSK': 'originalSK',
      },
      expressionAttributeValues: {
        ':deleted': true,
        ':now': now,
        ':userId': auth.sub,
        ':sk': sk,
      },
    });

    await recordRevision(
      auth.tenantId,
      entityType,
      entityId,
      'delete',
      auth.sub,
      existing,
      { isDeleted: true, deletedAt: now },
    );

    logger.info('Entity soft deleted', {
      entityType,
      entityId,
      tenantId: auth.tenantId,
      handler: 'entityActions',
    });

    return response.success({
      message: `${entityType} moved to recycle bin`,
      entityId,
      deletedAt: now,
    });
  },
  { requiredFeature: FeatureKey.AUDIT_LOGS },
);

// ─── Restore Handler ───────────────────────────────────────────────────────────

/**
 * POST /{entityType}/{id}/restore
 * Restore a soft-deleted entity from recycle bin
 */
export const restoreEntity = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const entityType = event.pathParameters?.entityType?.toUpperCase() as EntityType;
    const entityId = event.pathParameters?.id;
    
    if (!entityType || !entityId) {
      return response.badRequest('Entity type and ID are required');
    }

    const pk = Keys.tenantPK(auth.tenantId);
    const skPrefix = getSKPrefix(entityType);
    
    // Find the deleted item
    const queryResult = await queryItems(
      pk,
      skPrefix,
      {
        filterExpression: '(entityId = :id OR id = :id) AND isDeleted = :deleted',
        expressionAttributeValues: {
          ':id': entityId,
          ':deleted': true,
        },
      },
    );

    const items = queryResult.items || [];
    if (items.length === 0) {
      return response.notFound(`Deleted ${entityType} not found in recycle bin`);
    }

    const existing = items[0];
    const sk = existing.SK as string;
    const now = new Date().toISOString();

    // Restore by removing deletion markers
    const updateResult = await updateItem(pk, sk, {
      updateExpression: 'REMOVE #isDeleted, #deletedAt, #deletedBy, #originalSK SET #restoredAt = :now, #restoredBy = :userId',
      expressionAttributeNames: {
        '#isDeleted': 'isDeleted',
        '#deletedAt': 'deletedAt',
        '#deletedBy': 'deletedBy',
        '#originalSK': 'originalSK',
        '#restoredAt': 'restoredAt',
        '#restoredBy': 'restoredBy',
      },
      expressionAttributeValues: {
        ':now': now,
        ':userId': auth.sub,
      },
    });

    await recordRevision(
      auth.tenantId,
      entityType,
      entityId,
      'status_change',
      auth.sub,
      existing,
      { isDeleted: false, restoredAt: now, status: 'restored' },
    );

    logger.info('Entity restored', {
      entityType,
      entityId,
      tenantId: auth.tenantId,
      handler: 'entityActions',
    });

    return response.success({
      message: `${entityType} restored successfully`,
      entityId,
      restoredAt: now,
    });
  },
  { requiredFeature: FeatureKey.AUDIT_LOGS },
);

// ─── Permanent Delete Handler ────────────────────────────────────────────────

/**
 * DELETE /{entityType}/{id}?permanent=true
 * Permanently delete an entity (bypasses recycle bin)
 */
export const permanentDeleteEntity = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN],
  async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const entityType = event.pathParameters?.entityType?.toUpperCase() as EntityType;
    const entityId = event.pathParameters?.id;
    
    if (!entityType || !entityId) {
      return response.badRequest('Entity type and ID are required');
    }

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getEntityById(auth.tenantId, entityType, entityId);
    
    if (!existing) {
      return response.notFound(`${entityType} not found`);
    }

    const sk = existing.SK as string;

    await recordRevision(auth.tenantId, TABLE_NAME, entityId, 'delete', auth.sub, existing, null);

    await dynamo.send(new DeleteItemCommand({
      TableName: TABLE_NAME,
      Key: marshall({ PK: pk, SK: sk }),
    }));

    logger.info('Permanent entity deleted', {
      entityType,
      entityId,
      sk,
      tenantId: auth.tenantId,
      deletedBy: auth.sub,
    });

    return response.success({
      message: `${entityType} permanently deleted`,
      entityId,
    });
  },
  { requiredFeature: FeatureKey.AUDIT_LOGS },
);

// ─── Generic Update Handler ───────────────────────────────────────────────────

/**
 * PATCH /{entityType}/{id}
 * Update entity fields (status, isActive, isBlocked, etc.)
 */
export const updateEntity = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const entityType = event.pathParameters?.entityType?.toUpperCase() as EntityType;
    const entityId = event.pathParameters?.id;
    
    if (!entityType || !entityId) {
      return response.badRequest('Entity type and ID are required');
    }

    const valid = parseBody(updateSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getEntityById(auth.tenantId, entityType, entityId);
    
    if (!existing) {
      return response.notFound(`${entityType} not found`);
    }

    const sk = existing.SK as string;
    const now = new Date().toISOString();

    // Build update expression from body
    const updateParts: string[] = [];
    const exprNames: Record<string, string> = {};
    const exprValues: Record<string, unknown> = {};

    for (const [key, value] of Object.entries(body as Record<string, unknown>)) {
      const placeholder = `:${key}`;
      updateParts.push(`#${key} = ${placeholder}`);
      exprNames[`#${key}`] = key;
      exprValues[placeholder] = value;
    }

    updateParts.push('#updatedAt = :now');
    exprNames['#updatedAt'] = 'updatedAt';
    exprValues[':now'] = now;

    const updateExpr = `SET ${updateParts.join(', ')}`;

    const updateResult = await updateItem(pk, sk, {
      updateExpression: updateExpr,
      expressionAttributeNames: exprNames,
      expressionAttributeValues: exprValues,
    });

    const attrs = updateResult?.Attributes;

    await recordRevision(
      auth.tenantId,
      entityType,
      entityId,
      'update',
      auth.sub,
      existing as Record<string, unknown>,
      (attrs || body) as Record<string, unknown>,
    );

    logger.info('Entity updated', {
      entityType,
      entityId,
      updates: Object.keys(body),
      tenantId: auth.tenantId,
      handler: 'entityActions',
    });

    return response.success({
      message: `${entityType} updated successfully`,
      entityId,
      updatedFields: Object.keys(body),
      updatedAt: now,
    });
  },
  { requiredFeature: FeatureKey.AUDIT_LOGS },
);

// ─── List Deleted Items Handler ─────────────────────────────────────────────

/**
 * GET /deleted-items?type={entityType}&limit={n}
 * List all soft-deleted items (recycle bin)
 */
export const listDeletedItems = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const entityType = event.queryStringParameters?.type as EntityType | undefined;
    const limit = parseInt(event.queryStringParameters?.limit || '50');

    const pk = Keys.tenantPK(auth.tenantId);
    
    // Query all items and filter deleted ones
    const queryResult = await queryItems(
      pk,
      undefined,
      {
        filterExpression: 'isDeleted = :deleted',
        expressionAttributeValues: { ':deleted': true },
        limit,
      },
    );

    let items = queryResult.items || [];

    // Filter by entity type if specified
    if (entityType) {
      const skPrefix = getSKPrefix(entityType);
      items = items.filter((item: any) => (item.SK as string)?.startsWith(skPrefix));
    }

    // Add metadata about original entity type
    const enrichedItems = items.map((item: Record<string, unknown>) => ({
      ...item,
      entityType: detectEntityType(item.SK as string),
    }));

    logger.info('Listed deleted items', {
      count: enrichedItems.length,
      filteredByType: entityType,
      tenantId: auth.tenantId,
      handler: 'entityActions',
    });

    return response.success({
      data: enrichedItems,
      count: enrichedItems.length,
      canRestore: true,
      canPermanentDelete: auth.role === UserRole.OWNER || auth.role === UserRole.ADMIN,
    });
  },
  { requiredFeature: FeatureKey.AUDIT_LOGS },
);

function detectEntityType(sk: string): string {
  if (sk.startsWith('PRODUCT#')) return 'PRODUCT';
  if (sk.startsWith('CUSTOMER#')) return 'CUSTOMER';
  if (sk.startsWith('STAFF#')) return 'STAFF';
  if (sk.startsWith('SUPPLIER#')) return 'SUPPLIER';
  if (sk.startsWith('AUTOPARTS_JOB_CARD#')) return 'AUTOPARTS_JOB_CARD';
  if (sk.startsWith('JEWELLERY_ORDER#')) return 'JEWELLERY_CUSTOM_ORDER';
  if (sk.startsWith('JEWELLERY_EXCHANGE#')) return 'JEWELLERY_OLD_GOLD_EXCHANGE';
  return 'UNKNOWN';
}

// ─── Batch Delete Handler ────────────────────────────────────────────────────

/**
 * POST /{entityType}/batch-delete
 * Delete multiple entities at once
 */
export const batchDeleteEntities = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const entityType = event.pathParameters?.entityType?.toUpperCase() as EntityType;
    
    const batchDeleteSchema = z.object({
      ids: z.array(z.string()),
      soft: z.boolean().default(true),
    });
    
    const valid = parseBody(batchDeleteSchema, event);
    
    if (!valid.success) return valid.error;
    const body = valid.data;

    const now = new Date().toISOString();
    const results: Array<{ id: string; success: boolean; error?: string }> = [];

    // Process each ID
    const data = valid.data;
    for (const id of data.ids) {
      try {
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getEntityById(auth.tenantId, entityType, id);
        
        if (!existing) {
          results.push({ id, success: false, error: 'Not found' });
          continue;
        }

        const sk = existing.SK as string;

        if (data.soft !== false) {
          // Soft delete
          await updateItem(pk, sk, {
            updateExpression: 'SET #isDeleted = :deleted, #deletedAt = :now, #deletedBy = :userId',
            expressionAttributeNames: {
              '#isDeleted': 'isDeleted',
              '#deletedAt': 'deletedAt',
              '#deletedBy': 'deletedBy',
            },
            expressionAttributeValues: {
              ':deleted': true,
              ':now': now,
              ':userId': auth.sub,
            },
          });
        }

        results.push({ id, success: true });
      } catch (err: any) {
        results.push({ id, success: false, error: err.message });
      }
    }

    const successCount = results.filter(r => r.success).length;
    const failedCount = results.length - successCount;

    logger.info('Batch delete completed', {
      entityType,
      total: data.ids.length,
      success: successCount,
      failed: failedCount,
      tenantId: auth.tenantId,
      handler: 'entityActions',
    });

    return response.success({
      message: `Batch delete completed: ${successCount} successful, ${failedCount} failed`,
      results,
      successCount,
      failedCount,
    });
  },
  { requiredFeature: FeatureKey.AUDIT_LOGS },
);

// Default export
export default {
  softDeleteEntity,
  restoreEntity,
  permanentDeleteEntity,
  updateEntity,
  listDeletedItems,
  batchDeleteEntities,
};
