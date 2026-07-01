// ============================================================================
// Lambda Handler — Mandi (Vegetable Broker) Sync Endpoint
// ============================================================================
// Endpoints:
//   POST /veg-broker/sync/push  — Push Mandi entities from device to server
//   POST /veg-broker/sync/pull  — Pull Mandi entities from server to device
//   GET  /veg-broker/sync/query — Query a specific Mandi record by RID
//
// All handlers wrapped in withRequestContext for tenant context isolation.
// Tenant isolation: PK = TENANT#{tenantId} — every read/write is scoped.
// Cross-tenant access is denied with an authorization-failure response.
//
// Requirements: 14.2, 14.3, 14.4
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { BusinessType } from '../types/tenant.types';
import { parseBody, parseQuery } from '../middleware/validation';
import { withRequestContext, generateRID } from '../utils/context';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
    Keys,
    getItem,
    putItem,
    queryItems,
    batchWrite,
    updateItem,
} from '../config/dynamodb.config';

// ── Mandi Entity Types ──────────────────────────────────────────────────────

/** Mandi-specific SK prefixes in the single-table design */
const MANDI_SK_PREFIXES = {
    farmer: 'FARMER#',
    commission_ledger: 'COMMLEDGER#',
    vegetable_lot: 'VEGLOT#',
    mandi_settlement: 'MANDISETTLEMENT#',
    rate_history: 'RATEHISTORY#',
    buyer: 'MANDIBUYER#',
} as const;

type MandiEntityTable = keyof typeof MANDI_SK_PREFIXES;

const VALID_MANDI_TABLES = new Set<string>(Object.keys(MANDI_SK_PREFIXES));

// ── Zod Schemas ─────────────────────────────────────────────────────────────

const mandiEntitySchema = z.object({
    table: z.enum([
        'farmer',
        'commission_ledger',
        'vegetable_lot',
        'mandi_settlement',
        'rate_history',
        'buyer',
    ]),
    action: z.enum(['insert', 'update', 'delete']),
    id: z.string().min(1).max(200),
    data: z.record(z.string(), z.unknown()),
    localTimestamp: z.string(),
});

const mandiSyncPushSchema = z.object({
    entities: z.array(mandiEntitySchema).min(1).max(200),
    deviceId: z.string().max(100).optional(),
    lastSyncedAt: z.string().optional(),
});

const mandiSyncPullSchema = z.object({
    lastSyncedAt: z.string().min(1),
    tables: z
        .array(z.enum([
            'farmer',
            'commission_ledger',
            'vegetable_lot',
            'mandi_settlement',
            'rate_history',
            'buyer',
        ]))
        .max(10)
        .optional(),
});

const mandiQuerySchema = z.object({
    table: z.enum([
        'farmer',
        'commission_ledger',
        'vegetable_lot',
        'mandi_settlement',
        'rate_history',
        'buyer',
    ]),
    id: z.string().min(1).max(200),
});

// ── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Verify a Mandi record belongs to the requesting tenant.
 * Returns true if the record's owning tenant matches, false otherwise.
 */
function verifyRecordOwnership(
    record: Record<string, unknown> | null,
    tenantId: string
): boolean {
    if (!record) return true; // No record = no ownership conflict (record doesn't exist)
    const recordTenantId = record.tenantId as string | undefined;
    // PK-based isolation means records under TENANT#{tenantId} inherently belong
    // to that tenant. This check is defense-in-depth for the tenantId field.
    if (recordTenantId && recordTenantId !== tenantId) {
        return false;
    }
    return true;
}

/**
 * Build the SK for a Mandi entity given its table and ID.
 */
function buildMandiSK(table: MandiEntityTable, id: string): string {
    return `${MANDI_SK_PREFIXES[table]}${id}`;
}

// ── Push Handler ────────────────────────────────────────────────────────────

/**
 * POST /veg-broker/sync/push
 * Client pushes Mandi entities (farmers, lots, ledger entries, etc.) to server.
 * Wrapped in withRequestContext for tenant context establishment (R14.2).
 * Restricts writes to owning tenant (R14.3, R14.4).
 */
export const mandiSyncPush = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        return withRequestContext(auth.tenantId, async (rid) => {
            const parsed = parseBody(mandiSyncPushSchema, event);
            if (!parsed.success) return parsed.error;

            const { entities, deviceId } = parsed.data;
            const now = new Date().toISOString();
            let accepted = 0;
            let rejected = 0;
            const errors: Array<{ id: string; table: string; reason: string }> = [];

            for (const entity of entities) {
                const sk = buildMandiSK(entity.table as MandiEntityTable, entity.id);
                const pk = Keys.tenantPK(auth.tenantId);

                try {
                    if (entity.action === 'insert') {
                        // Insert: write record scoped to this tenant's PK
                        await putItem({
                            PK: pk,
                            SK: sk,
                            tenantId: auth.tenantId,
                            entityType: entity.table,
                            entityId: entity.id,
                            ...entity.data,
                            syncState: 'synced',
                            deviceId: deviceId || null,
                            createdAt: entity.localTimestamp || now,
                            updatedAt: now,
                            serverReceivedAt: now,
                        });
                        accepted++;
                    } else if (entity.action === 'update') {
                        // Update: verify ownership before modifying
                        const existing = await getItem<Record<string, unknown>>(pk, sk);

                        if (existing && !verifyRecordOwnership(existing, auth.tenantId)) {
                            // Cross-tenant write attempt — deny (R14.4)
                            logger.error('MANDI CROSS-TENANT WRITE DENIED', {
                                rid,
                                tenantId: auth.tenantId,
                                entityTable: entity.table,
                                entityId: entity.id,
                            });
                            errors.push({
                                id: entity.id,
                                table: entity.table,
                                reason: 'Authorization failure: access denied to this record',
                            });
                            rejected++;
                            continue;
                        }

                        // Apply update within the tenant's partition
                        await putItem({
                            PK: pk,
                            SK: sk,
                            tenantId: auth.tenantId,
                            entityType: entity.table,
                            entityId: entity.id,
                            ...entity.data,
                            syncState: 'synced',
                            deviceId: deviceId || null,
                            updatedAt: now,
                            serverReceivedAt: now,
                            // Preserve createdAt from existing or use local timestamp
                            createdAt: (existing as any)?.createdAt || entity.localTimestamp || now,
                        });
                        accepted++;
                    } else if (entity.action === 'delete') {
                        // Soft delete: verify ownership first
                        const existing = await getItem<Record<string, unknown>>(pk, sk);

                        if (existing && !verifyRecordOwnership(existing, auth.tenantId)) {
                            logger.error('MANDI CROSS-TENANT DELETE DENIED', {
                                rid,
                                tenantId: auth.tenantId,
                                entityTable: entity.table,
                                entityId: entity.id,
                            });
                            errors.push({
                                id: entity.id,
                                table: entity.table,
                                reason: 'Authorization failure: access denied to this record',
                            });
                            rejected++;
                            continue;
                        }

                        // Soft delete within tenant partition
                        await updateItem(pk, sk, {
                            updateExpression: 'SET isDeleted = :true, updatedAt = :now, syncState = :synced',
                            expressionAttributeValues: {
                                ':true': true,
                                ':now': now,
                                ':synced': 'synced',
                            },
                        });
                        accepted++;
                    }
                } catch (err) {
                    logger.warn('Mandi sync push entity error', {
                        rid,
                        entityId: entity.id,
                        table: entity.table,
                        error: (err as Error).message,
                    });
                    errors.push({
                        id: entity.id,
                        table: entity.table,
                        reason: (err as Error).message,
                    });
                    rejected++;
                }
            }

            logger.info('Mandi sync push completed', {
                rid,
                tenantId: auth.tenantId,
                accepted,
                rejected,
                total: entities.length,
            });

            return response.success({
                accepted,
                rejected,
                errors: errors.length > 0 ? errors : undefined,
                serverTimestamp: now,
            });
        });
    },
    { requiredBusinessType: BusinessType.VEGETABLES_BROKER }
);

// ── Pull Handler ────────────────────────────────────────────────────────────

/**
 * POST /veg-broker/sync/pull
 * Client pulls Mandi entities updated since lastSyncedAt.
 * Wrapped in withRequestContext for tenant context establishment (R14.2).
 * Only returns records belonging to the requesting tenant (R14.3).
 */
export const mandiSyncPull = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        return withRequestContext(auth.tenantId, async (rid) => {
            const parsed = parseBody(mandiSyncPullSchema, event);
            if (!parsed.success) return parsed.error;

            const { lastSyncedAt, tables } = parsed.data;
            const pk = Keys.tenantPK(auth.tenantId);

            // Determine which Mandi tables to pull
            const tablesToPull: MandiEntityTable[] = tables && tables.length > 0
                ? tables as MandiEntityTable[]
                : (Object.keys(MANDI_SK_PREFIXES) as MandiEntityTable[]);

            const changes: Array<{
                table: string;
                id: string;
                action: 'insert' | 'update' | 'delete';
                data: Record<string, unknown>;
                serverTimestamp: string;
            }> = [];

            for (const table of tablesToPull) {
                const skPrefix = MANDI_SK_PREFIXES[table];

                // Query all records in this table for this tenant, filter by updatedAt
                const result = await queryItems<Record<string, unknown>>(
                    pk,
                    skPrefix,
                    {
                        filterExpression: 'updatedAt > :since',
                        expressionAttributeValues: {
                            ':since': lastSyncedAt,
                        },
                    }
                );

                for (const item of result.items) {
                    // Defense-in-depth: verify each record belongs to this tenant
                    if (!verifyRecordOwnership(item, auth.tenantId)) {
                        continue; // Skip cross-tenant records (should never happen with PK isolation)
                    }

                    const isDeleted = item.isDeleted === true;
                    const { PK, SK, tenantId: _t, syncState, serverReceivedAt, ...data } = item;

                    changes.push({
                        table,
                        id: item.entityId as string,
                        action: isDeleted ? 'delete' : 'update',
                        data: isDeleted ? {} : data,
                        serverTimestamp: item.updatedAt as string,
                    });
                }
            }

            logger.info('Mandi sync pull completed', {
                rid,
                tenantId: auth.tenantId,
                changeCount: changes.length,
                tables: tablesToPull,
            });

            return response.success({
                changes,
                serverTimestamp: new Date().toISOString(),
            });
        });
    },
    { requiredBusinessType: BusinessType.VEGETABLES_BROKER }
);

// ── Query Handler ───────────────────────────────────────────────────────────

/**
 * GET /veg-broker/sync/query
 * Query a specific Mandi record by table + RID.
 * Wrapped in withRequestContext for tenant context establishment (R14.2).
 * Denies cross-tenant reads with authorization-failure (R14.3, R14.4).
 */
export const mandiSyncQuery = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        return withRequestContext(auth.tenantId, async (rid) => {
            const parsed = parseQuery(mandiQuerySchema, event);
            if (!parsed.success) return parsed.error;

            const { table, id } = parsed.data;
            const sk = buildMandiSK(table as MandiEntityTable, id);
            const pk = Keys.tenantPK(auth.tenantId);

            // Read from the requesting tenant's partition only (R14.3)
            const record = await getItem<Record<string, unknown>>(pk, sk);

            if (!record) {
                return response.notFound('Mandi record');
            }

            // Defense-in-depth ownership check (R14.4)
            if (!verifyRecordOwnership(record, auth.tenantId)) {
                logger.error('MANDI CROSS-TENANT READ DENIED', {
                    rid,
                    tenantId: auth.tenantId,
                    entityTable: table,
                    entityId: id,
                    recordTenantId: record.tenantId,
                });
                return response.error(
                    403,
                    'AUTHORIZATION_FAILURE',
                    'Access denied: you do not have permission to access this record'
                );
            }

            // Strip internal DynamoDB keys from response
            const { PK, SK, syncState, serverReceivedAt, ...data } = record;

            return response.success({
                table,
                id,
                data,
            });
        });
    },
    { requiredBusinessType: BusinessType.VEGETABLES_BROKER }
);
