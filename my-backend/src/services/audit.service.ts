// ============================================================================
// AUDIT TRAIL SERVICE — Change Tracking for Compliance
// ============================================================================
// Tracks all sensitive changes: student updates, fee edits, result changes,
// staff salary changes with who/what/when details.
// ============================================================================

import { putItem, queryItems, Keys } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import crypto from 'crypto';

const AUDIT_TTL_DAYS = 365 * 7; // 7 years retention

export interface AuditEntry {
  id: string;
  tenantId: string;
  entityType: string;
  entityId: string;
  action: 'create' | 'update' | 'delete' | 'view' | 'export' | 'login' | 'payment';
  performedBy: string;
  performedByName?: string;
  timestamp: string;
  changes?: Record<string, { old?: any; new?: any }>;
  metadata?: Record<string, any>;
  ipAddress?: string;
  userAgent?: string;
  requestId?: string;
}

function uid(): string {
  return crypto.randomUUID().replace(/-/g, '').substring(0, 16).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

/**
 * Log an audit entry for a data change
 */
export async function logAudit(entry: Omit<AuditEntry, 'id' | 'timestamp'>): Promise<void> {
  const auditEntry: AuditEntry = {
    id: uid(),
    timestamp: now(),
    ...entry,
  };

  const ttl = Math.floor(Date.now() / 1000) + (AUDIT_TTL_DAYS * 24 * 60 * 60);

  await putItem({
    PK: Keys.tenantPK(entry.tenantId),
    SK: `AUDIT#${auditEntry.timestamp}#${auditEntry.id}`,
    GSI1PK: `AUDIT_ENTITY#${entry.tenantId}#${entry.entityType}#${entry.entityId}`,
    GSI1SK: auditEntry.timestamp,
    ...auditEntry,
    _ttl: ttl,
  });

  logger.info('Audit entry created', {
    tenantId: entry.tenantId,
    entityType: entry.entityType,
    entityId: entry.entityId,
    action: entry.action,
    performedBy: entry.performedBy,
  });
}

/**
 * Log create action
 */
export async function logCreate(
  tenantId: string,
  entityType: string,
  entityId: string,
  newData: Record<string, any>,
  context: { performedBy: string; performedByName?: string; ipAddress?: string; userAgent?: string; requestId?: string }
): Promise<void> {
  await logAudit({
    tenantId,
    entityType,
    entityId,
    action: 'create',
    performedBy: context.performedBy,
    performedByName: context.performedByName,
    ipAddress: context.ipAddress,
    userAgent: context.userAgent,
    requestId: context.requestId,
    changes: Object.fromEntries(
      Object.entries(newData).map(([key, value]) => [key, { new: value }])
    ),
  });
}

/**
 * Log update action with change detection
 */
export async function logUpdate(
  tenantId: string,
  entityType: string,
  entityId: string,
  oldData: Record<string, any>,
  newData: Record<string, any>,
  context: { performedBy: string; performedByName?: string; ipAddress?: string; userAgent?: string; requestId?: string },
  sensitiveFields?: string[]
): Promise<void> {
  const changes: Record<string, { old?: any; new?: any }> = {};
  
  for (const key of Object.keys(newData)) {
    if (oldData[key] !== newData[key]) {
      changes[key] = {
        old: oldData[key],
        new: newData[key],
      };
    }
  }

  // Only log if there are actual changes
  if (Object.keys(changes).length === 0) return;

  await logAudit({
    tenantId,
    entityType,
    entityId,
    action: 'update',
    performedBy: context.performedBy,
    performedByName: context.performedByName,
    ipAddress: context.ipAddress,
    userAgent: context.userAgent,
    requestId: context.requestId,
    changes,
    metadata: sensitiveFields ? { sensitiveFields } : undefined,
  });
}

/**
 * Log delete action
 */
export async function logDelete(
  tenantId: string,
  entityType: string,
  entityId: string,
  deletedData: Record<string, any>,
  context: { performedBy: string; performedByName?: string; ipAddress?: string; userAgent?: string; requestId?: string }
): Promise<void> {
  await logAudit({
    tenantId,
    entityType,
    entityId,
    action: 'delete',
    performedBy: context.performedBy,
    performedByName: context.performedByName,
    ipAddress: context.ipAddress,
    userAgent: context.userAgent,
    requestId: context.requestId,
    changes: Object.fromEntries(
      Object.entries(deletedData).map(([key, value]) => [key, { old: value }])
    ),
  });
}

/**
 * Log payment action
 */
export async function logPayment(
  tenantId: string,
  entityType: string,
  entityId: string,
  amountPaisa: number,
  paymentMethod: string,
  context: { performedBy: string; performedByName?: string; ipAddress?: string; requestId?: string }
): Promise<void> {
  await logAudit({
    tenantId,
    entityType,
    entityId,
    action: 'payment',
    performedBy: context.performedBy,
    performedByName: context.performedByName,
    ipAddress: context.ipAddress,
    requestId: context.requestId,
    metadata: {
      amountPaisa,
      paymentMethod,
      amount: amountPaisa / 100,
    },
  });
}

/**
 * Query audit trail for an entity
 */
export async function getEntityAuditTrail(
  tenantId: string,
  entityType: string,
  entityId: string,
  options: { fromDate?: string; toDate?: string; limit?: number } = {}
): Promise<AuditEntry[]> {
  const { fromDate, toDate, limit = 50 } = options;

  let filterExpression = '';
  const expressionAttributeValues: Record<string, any> = {
    ':pk': `AUDIT_ENTITY#${tenantId}#${entityType}#${entityId}`,
  };

  if (fromDate) {
    filterExpression = filterExpression 
      ? `${filterExpression} AND GSI1SK >= :fromDate`
      : 'GSI1SK >= :fromDate';
    expressionAttributeValues[':fromDate'] = fromDate;
  }

  if (toDate) {
    filterExpression = filterExpression 
      ? `${filterExpression} AND GSI1SK <= :toDate`
      : 'GSI1SK <= :toDate';
    expressionAttributeValues[':toDate'] = toDate;
  }

  const result = await queryItems(
    expressionAttributeValues[':pk'],
    '',
    {
      indexName: 'GSI1',
      limit,
      scanIndexForward: false, // Most recent first
      filterExpression: filterExpression || undefined,
      expressionAttributeValues: filterExpression ? expressionAttributeValues : undefined,
    }
  );

  return result.items as unknown as AuditEntry[];
}

/**
 * Query all audit entries for a tenant
 */
export async function getTenantAuditTrail(
  tenantId: string,
  options: { 
    fromDate?: string; 
    toDate?: string; 
    entityType?: string;
    action?: string;
    performedBy?: string;
    limit?: number 
  } = {}
): Promise<AuditEntry[]> {
  const { fromDate, toDate, entityType, action, performedBy, limit = 100 } = options;

  // Build filter expression
  const filters: string[] = [];
  const values: Record<string, any> = {};

  if (entityType) {
    filters.push('entityType = :entityType');
    values[':entityType'] = entityType;
  }

  if (action) {
    filters.push('action = :action');
    values[':action'] = action;
  }

  if (performedBy) {
    filters.push('performedBy = :performedBy');
    values[':performedBy'] = performedBy;
  }

  if (fromDate) {
    filters.push('#ts >= :fromDate');
    values[':fromDate'] = fromDate;
  }

  if (toDate) {
    filters.push('#ts <= :toDate');
    values[':toDate'] = toDate;
  }

  const result = await queryItems(
    Keys.tenantPK(tenantId),
    'AUDIT#',
    {
      limit,
      scanIndexForward: false,
      filterExpression: filters.length > 0 ? filters.join(' AND ') : undefined,
      expressionAttributeNames: filters.some(f => f.includes('#ts')) 
        ? { '#ts': 'timestamp' } 
        : undefined,
      expressionAttributeValues: filters.length > 0 ? values : undefined,
    }
  );

  return result.items as unknown as AuditEntry[];
}
