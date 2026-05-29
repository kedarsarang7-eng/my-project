// ============================================================================
// Unified AuditLog Service — Centralized Audit Trail Management
// ============================================================================
// Provides a single helper for writing structured audit records and querying
// the audit log with filters. Used by all admin actions for compliance.
//
// Record Structure:
//   PK: AUDIT#{tenantId} | SK: {timestamp}#{ulid}
//   GSI1PK: AUDIT#{actorType}#{actorId} (for per-admin queries)
//   GSI2PK: AUDIT#{category} (for per-category queries)
//
// Usage:
//   await auditLog.write({
//     actor: { id: adminId, type: 'admin', role: 'super_admin' },
//     action: 'plan_upgrade',
//     target: { type: 'tenant', id: tenantId },
//     metadata: { previousPlan: 'basic', newPlan: 'pro' },
//   });
//
//   const logs = await auditLog.query({ tenantId, startTime, endTime });
// ============================================================================

import { Keys, putItem, queryItems } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { randomUUID } from 'crypto';

// ── Type Definitions ───────────────────────────────────────────────────────

export type ActorType = 'admin' | 'user' | 'system' | 'api_key' | 'webhook';
export type TargetType = 'tenant' | 'license' | 'plan_config' | 'user' | 'feature';
export type AuditCategory = 'plan_change' | 'license_change' | 'feature_override' | 'security' | 'billing' | 'system';

export interface AuditActor {
  id: string;
  type: ActorType;
  role?: string;
  email?: string;
  ipAddress?: string;
}

export interface AuditTarget {
  type: TargetType;
  id: string;
  name?: string;
}

export interface AuditRecord {
  id: string;
  timestamp: string;
  actor: AuditActor;
  action: string;
  category: AuditCategory;
  target: AuditTarget;
  tenantId?: string;
  metadata?: Record<string, unknown>;
  result?: 'success' | 'failure' | 'partial';
  errorMessage?: string;
  ttl?: number;
}

export interface AuditWriteInput {
  actor: AuditActor;
  action: string;
  category: AuditCategory;
  target: AuditTarget;
  tenantId?: string;
  metadata?: Record<string, unknown>;
  result?: 'success' | 'failure' | 'partial';
  errorMessage?: string;
  retentionDays?: number;
}

export interface AuditQueryFilters {
  tenantId?: string;
  actorId?: string;
  actorType?: ActorType;
  category?: AuditCategory;
  action?: string;
  targetType?: TargetType;
  targetId?: string;
  startTime?: Date;
  endTime?: Date;
  result?: 'success' | 'failure' | 'partial';
  limit?: number;
  cursor?: string;
}

// ── Constants ──────────────────────────────────────────────────────────────

const DEFAULT_RETENTION_DAYS = 730; // 2 years
// TABLE_NAME imported from dynamodb.config.ts via putItem/queryItems — no local override needed

// ── Service Implementation ─────────────────────────────────────────────────

/**
 * Write a unified audit log entry to DynamoDB.
 * This is the single point of entry for all audit logging.
 */
export async function writeAuditLog(input: AuditWriteInput): Promise<AuditRecord> {
  const now = new Date();
  const timestamp = now.toISOString();
  const id = randomUUID();
  const retentionDays = input.retentionDays ?? DEFAULT_RETENTION_DAYS;

  const record: AuditRecord = {
    id,
    timestamp,
    actor: input.actor,
    action: input.action,
    category: input.category,
    target: input.target,
    tenantId: input.tenantId,
    metadata: input.metadata,
    result: input.result ?? 'success',
    errorMessage: input.errorMessage,
    ttl: Math.floor(now.getTime() / 1000) + (retentionDays * 24 * 60 * 60),
  };

  // Build keys for single-table design
  const pk = input.tenantId 
    ? `AUDIT#TENANT#${input.tenantId}`
    : `AUDIT#GLOBAL`;
  const sk = `${timestamp}#${id}`;

  await putItem({
    PK: pk,
    SK: sk,
    GSI1PK: `AUDIT#ACTOR#${input.actor.type}#${input.actor.id}`,
    GSI2PK: `AUDIT#CAT#${input.category}`,
    entityType: 'AUDIT_LOG',
    ...record,
  });

  logger.info('[AuditLog] Record created', {
    id,
    action: input.action,
    category: input.category,
    actor: input.actor.id,
    tenantId: input.tenantId,
  });

  return record;
}

/**
 * Query audit logs with flexible filters.
 * Supports filtering by tenant, actor, category, time range, etc.
 */
export async function queryAuditLogs(filters: AuditQueryFilters): Promise<{
  items: AuditRecord[];
  nextCursor?: string;
}> {
  // Determine the most efficient query path based on filters
  if (filters.tenantId) {
    return queryByTenant(filters);
  } else if (filters.actorId && filters.actorType) {
    return queryByActor(filters);
  } else if (filters.category) {
    return queryByCategory(filters);
  } else {
    // Fallback: scan with filters (expensive, should be limited)
    return queryGlobal(filters);
  }
}

// ── Internal Query Implementations ─────────────────────────────────────────

async function queryByTenant(filters: AuditQueryFilters): Promise<{
  items: AuditRecord[];
  nextCursor?: string;
}> {
  const pk = `AUDIT#TENANT#${filters.tenantId}`;
  
  const result = await queryItems<Record<string, any>>(
    pk,
    filters.startTime?.toISOString() ?? undefined,
    {
      scanIndexForward: false,
      limit: filters.limit ?? 100,
      exclusiveStartKey: filters.cursor ? JSON.parse(Buffer.from(filters.cursor, 'base64').toString()) : undefined,
    }
  );

  let items = result.items.map(mapToAuditRecord);
  
  // Apply in-memory filters for remaining fields
  items = applyFilters(items, filters);

  return {
    items,
    nextCursor: result.lastKey 
      ? Buffer.from(JSON.stringify(result.lastKey)).toString('base64')
      : undefined,
  };
}

async function queryByActor(filters: AuditQueryFilters): Promise<{
  items: AuditRecord[];
  nextCursor?: string;
}> {
  const gsi1pk = `AUDIT#ACTOR#${filters.actorType}#${filters.actorId}`;
  
  const result = await queryItems<Record<string, any>>(
    gsi1pk,
    undefined,
    {
      indexName: 'GSI1',
      scanIndexForward: false,
      limit: filters.limit ?? 100,
      exclusiveStartKey: filters.cursor ? JSON.parse(Buffer.from(filters.cursor, 'base64').toString()) : undefined,
    }
  );

  let items = result.items.map(mapToAuditRecord);
  items = applyFilters(items, filters);

  return {
    items,
    nextCursor: result.lastKey 
      ? Buffer.from(JSON.stringify(result.lastKey)).toString('base64')
      : undefined,
  };
}

async function queryByCategory(filters: AuditQueryFilters): Promise<{
  items: AuditRecord[];
  nextCursor?: string;
}> {
  const gsi2pk = `AUDIT#CAT#${filters.category}`;
  
  const result = await queryItems<Record<string, any>>(
    gsi2pk,
    undefined,
    {
      indexName: 'GSI2',
      scanIndexForward: false,
      limit: filters.limit ?? 100,
      exclusiveStartKey: filters.cursor ? JSON.parse(Buffer.from(filters.cursor, 'base64').toString()) : undefined,
    }
  );

  let items = result.items.map(mapToAuditRecord);
  items = applyFilters(items, filters);

  return {
    items,
    nextCursor: result.lastKey 
      ? Buffer.from(JSON.stringify(result.lastKey)).toString('base64')
      : undefined,
  };
}

async function queryGlobal(filters: AuditQueryFilters): Promise<{
  items: AuditRecord[];
  nextCursor?: string;
}> {
  // Global scan with begins_with on SK pattern
  const result = await queryItems<Record<string, any>>(
    'AUDIT#GLOBAL',
    filters.startTime?.toISOString() ?? undefined,
    {
      scanIndexForward: false,
      limit: Math.min(filters.limit ?? 50, 100), // Limit for global queries
      exclusiveStartKey: filters.cursor ? JSON.parse(Buffer.from(filters.cursor, 'base64').toString()) : undefined,
    }
  );

  let items = result.items.map(mapToAuditRecord);
  items = applyFilters(items, filters);

  return {
    items,
    nextCursor: result.lastKey 
      ? Buffer.from(JSON.stringify(result.lastKey)).toString('base64')
      : undefined,
  };
}

// ── Helpers ────────────────────────────────────────────────────────────────

function mapToAuditRecord(item: Record<string, any>): AuditRecord {
  return {
    id: item.id,
    timestamp: item.timestamp,
    actor: item.actor,
    action: item.action,
    category: item.category,
    target: item.target,
    tenantId: item.tenantId,
    metadata: item.metadata,
    result: item.result,
    errorMessage: item.errorMessage,
    ttl: item.TTL,
  };
}

function applyFilters(items: AuditRecord[], filters: AuditQueryFilters): AuditRecord[] {
  return items.filter(item => {
    if (filters.action && item.action !== filters.action) return false;
    if (filters.result && item.result !== filters.result) return false;
    if (filters.targetType && item.target.type !== filters.targetType) return false;
    if (filters.targetId && item.target.id !== filters.targetId) return false;
    if (filters.endTime && new Date(item.timestamp) > filters.endTime) return false;
    return true;
  });
}

// ── Convenience Wrappers ───────────────────────────────────────────────────

export async function auditPlanChange(
  adminId: string,
  tenantId: string,
  previousPlan: string,
  newPlan: string,
  metadata?: Record<string, unknown>,
): Promise<AuditRecord> {
  return writeAuditLog({
    actor: { id: adminId, type: 'admin', role: 'super_admin' },
    action: 'plan_change',
    category: 'plan_change',
    target: { type: 'tenant', id: tenantId },
    tenantId,
    metadata: { previousPlan, newPlan, ...metadata },
    result: 'success',
  });
}

export async function auditLicenseOverride(
  adminId: string,
  licenseKey: string,
  tenantId: string,
  added: string[],
  removed: string[],
  reason?: string,
): Promise<AuditRecord> {
  return writeAuditLog({
    actor: { id: adminId, type: 'admin', role: 'super_admin' },
    action: 'license_feature_override',
    category: 'feature_override',
    target: { type: 'license', id: licenseKey },
    tenantId,
    metadata: { added, removed, reason },
    result: 'success',
  });
}

export async function auditPlanConfigUpdate(
  adminId: string,
  plan: string,
  delta: { added?: string[]; removed?: string[]; limits?: Record<string, unknown>; replaceDefaults?: string[] },
): Promise<AuditRecord> {
  return writeAuditLog({
    actor: { id: adminId, type: 'admin', role: 'super_admin' },
    action: 'plan_config_update',
    category: 'plan_change',
    target: { type: 'plan_config', id: plan },
    metadata: delta,
    result: 'success',
  });
}
