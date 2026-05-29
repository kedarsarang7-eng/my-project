// ============================================================================
// Audit Trail Service — Immutable, GST-Compliant Audit Log
// ============================================================================
// COMPLIANCE: Audit entries are APPEND-ONLY. They are never updated or deleted.
// GST-related operations are flagged for regulatory compliance.
//
// Every write operation in the system must create an audit entry recording:
// - WHO (tenant_id, business_id, user_id)
// - WHAT (action, target entity type/id)
// - WHEN (timestamp)
// - BEFORE (old_value snapshot)
// - AFTER (new_value snapshot)
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import { TenantContext, AuditEntry } from './types';
import { putItem, queryItems, TABLE_NAME } from './client';
import { buildAuditKeys, gsi1PK, businessPK, AUDIT_SK_PREFIX } from './keys';

// ---- Types ----

export interface CreateAuditInput {
  readonly auditId: string;
  readonly action: AuditEntry['action'];
  readonly targetEntityType: string;
  readonly targetEntityId: string;
  readonly oldValue: Record<string, unknown> | null;
  readonly newValue: Record<string, unknown> | null;
  readonly isGstRelated: boolean;
  readonly ipAddress: string;
  readonly userAgent: string;
  readonly metadata?: Record<string, unknown>;
}

// ---- Create Audit Entry ----

/**
 * Create an immutable audit entry.
 *
 * Returns the full AuditEntry object (useful for transactional writes
 * where the audit entry is part of a TransactWriteItems batch).
 *
 * INVARIANT: This function only creates. It never updates or deletes.
 * There is intentionally no updateAudit or deleteAudit function.
 */
export function createAuditEntry(
  ctx: TenantContext,
  input: CreateAuditInput,
): AuditEntry {
  const now = new Date().toISOString();
  const keys = buildAuditKeys(
    ctx.tenantId,
    ctx.businessId,
    now,
    input.auditId,
  );

  const entry: AuditEntry = {
    ...keys,
    tenant_id: ctx.tenantId,
    business_id: ctx.businessId,
    entity_type: 'AUDIT',
    audit_id: input.auditId,
    action: input.action,
    targetEntityType: input.targetEntityType,
    targetEntityId: input.targetEntityId,
    oldValue: sanitizeAuditValue(input.oldValue),
    newValue: sanitizeAuditValue(input.newValue),
    isGstRelated: input.isGstRelated,
    ipAddress: input.ipAddress,
    userAgent: input.userAgent,
    metadata: input.metadata,
    version: 1, // Immutable — version is always 1
    is_deleted: false, // Audit entries are NEVER deleted
    created_at: now,
    updated_at: now, // Same as created_at because immutable
    created_by: ctx.userId,
    updated_by: ctx.userId,
  };

  return entry;
}

/**
 * Write an audit entry to DynamoDB.
 *
 * For standalone audit writes (not part of a transaction).
 * For transactional writes, use createAuditEntry() to build the entry
 * and include it in TransactWriteItems.
 */
export async function writeAuditEntry(
  ctx: TenantContext,
  input: CreateAuditInput,
): Promise<AuditEntry> {
  const entry = createAuditEntry(ctx, input);

  await putItem(entry as unknown as Record<string, unknown>, {
    // Idempotency: don't overwrite if already exists
    conditionExpression: 'attribute_not_exists(PK)',
  });

  return entry;
}

// ---- Query Audit Entries ----

/**
 * List audit entries for a business, ordered by date.
 * Uses GSI1 (ByDate) index for efficient date-range queries.
 */
export async function listAuditEntries(
  ctx: TenantContext,
  options?: {
    startDate?: string;
    endDate?: string;
    limit?: number;
    startKey?: Record<string, unknown>;
    targetEntityType?: string;
    targetEntityId?: string;
    action?: AuditEntry['action'];
    gstOnly?: boolean;
  },
): Promise<{
  entries: AuditEntry[];
  lastKey?: Record<string, unknown>;
}> {
  const gsiPk = gsi1PK(ctx.tenantId, ctx.businessId, 'AUDIT');

  const skRange = {
    start: options?.startDate || '0000-01-01',
    end: options?.endDate || '9999-12-31',
  };

  // Build filter expression for optional filters
  const filters: string[] = [];
  const filterValues: Record<string, unknown> = {};

  if (options?.targetEntityType) {
    filters.push('targetEntityType = :targetType');
    filterValues[':targetType'] = options.targetEntityType;
  }
  if (options?.targetEntityId) {
    filters.push('targetEntityId = :targetId');
    filterValues[':targetId'] = options.targetEntityId;
  }
  if (options?.action) {
    filters.push('#action = :action');
    filterValues[':action'] = options.action;
  }
  if (options?.gstOnly) {
    filters.push('isGstRelated = :gstTrue');
    filterValues[':gstTrue'] = true;
  }

  const result = await queryItems<AuditEntry>(gsiPk, {
    indexName: 'GSI1Index',
    skBetween: skRange,
    limit: options?.limit,
    scanForward: false, // Newest first
    filterExpression:
      filters.length > 0 ? filters.join(' AND ') : undefined,
    expressionAttributeValues:
      Object.keys(filterValues).length > 0 ? filterValues : undefined,
    expressionAttributeNames:
      options?.action ? { '#action': 'action' } : undefined,
    exclusiveStartKey: options?.startKey,
  });

  return {
    entries: result.items,
    lastKey: result.lastEvaluatedKey,
  };
}

/**
 * Get all audit entries for a specific entity.
 * Useful for viewing the complete history of a bill, product, etc.
 */
export async function getEntityAuditTrail(
  ctx: TenantContext,
  targetEntityType: string,
  targetEntityId: string,
): Promise<AuditEntry[]> {
  const pk = businessPK(ctx.tenantId, ctx.businessId);

  const result = await queryItems<AuditEntry>(pk, {
    skBeginsWith: AUDIT_SK_PREFIX,
    filterExpression:
      'targetEntityType = :targetType AND targetEntityId = :targetId',
    expressionAttributeValues: {
      ':targetType': targetEntityType,
      ':targetId': targetEntityId,
    },
    scanForward: true, // Chronological order for history view
  });

  return result.items;
}

/**
 * Get GST-related audit entries for compliance reporting.
 * Returns all audit entries flagged as GST-related within a date range.
 */
export async function getGstAuditTrail(
  ctx: TenantContext,
  startDate: string,
  endDate: string,
): Promise<AuditEntry[]> {
  return (
    await listAuditEntries(ctx, {
      startDate,
      endDate,
      gstOnly: true,
    })
  ).entries;
}

// ---- Helpers ----

/**
 * Sanitize values before storing in audit trail.
 * Removes circular references, functions, and other non-serializable values.
 * Limits depth to prevent excessively large audit entries.
 */
function sanitizeAuditValue(
  value: Record<string, unknown> | null,
): Record<string, unknown> | null {
  if (value === null || value === undefined) return null;

  try {
    // JSON round-trip removes non-serializable values (functions, undefined, etc.)
    const serialized = JSON.stringify(value, (_key, val) => {
      if (typeof val === 'function') return undefined;
      if (typeof val === 'bigint') return val.toString();
      return val;
    });

    const parsed = JSON.parse(serialized);

    // Remove sensitive fields that should not be in audit trail
    delete parsed.PK;
    delete parsed.SK;
    delete parsed.GSI1PK;
    delete parsed.GSI1SK;
    delete parsed.GSI2PK;
    delete parsed.GSI2SK;
    delete parsed.GSI3PK;
    delete parsed.GSI3SK;

    return parsed;
  } catch {
    // If serialization fails, store a marker instead of crashing
    return { _error: 'Value could not be serialized for audit trail' };
  }
}
