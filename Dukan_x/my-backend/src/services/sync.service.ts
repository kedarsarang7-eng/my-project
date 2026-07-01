// ============================================================================
// Sync Service — Offline-First Push/Pull
// ============================================================================
// Handles bidirectional sync between Flutter desktop/mobile and the cloud.
// Push: Client sends local changes (new bills, inventory updates, etc.)
// Pull: Client requests changes since last sync timestamp.
// ============================================================================

import { getPool } from '../config/db.config';
import { logger } from '../utils/logger';

// ---- Types ----

export interface PushRequest {
    changes: ChangeRecord[];
    deviceId?: string;
    lastSyncedAt?: string;
}

export interface ChangeRecord {
    table: string;
    action: 'insert' | 'update' | 'delete';
    id: string;
    data: Record<string, unknown>;
    localTimestamp: string;
}

export interface PushResponse {
    accepted: number;
    rejected: number;
    conflicts: ConflictRecord[];
    serverTimestamp: string;
}

export interface ConflictRecord {
    id: string;
    table: string;
    reason: string;
}

export interface PullRequest {
    lastSyncedAt: string;
    tables?: string[];
}

export interface PullResponse {
    changes: PulledChange[];
    serverTimestamp: string;
    hasMore: boolean;
}

export interface PulledChange {
    table: string;
    action: 'insert' | 'update' | 'delete';
    id: string;
    data: Record<string, unknown>;
    updatedAt: string;
}

// Allowed tables for sync (whitelist to prevent SQL injection)
const SYNCABLE_TABLES = new Set([
    'inventory', 'transactions', 'transaction_items',
    'vendors', 'purchase_orders', 'returns',
]);

// ---- Service Functions ----

/**
 * Process push from client — apply local changes to server.
 */
export async function pushChanges(
    tenantId: string,
    request: PushRequest
): Promise<PushResponse> {
    let accepted = 0;
    let rejected = 0;
    const conflicts: ConflictRecord[] = [];
    const db = getPool();

    for (const change of request.changes) {
        if (!SYNCABLE_TABLES.has(change.table)) {
            conflicts.push({ id: change.id, table: change.table, reason: 'Table not syncable' });
            rejected++;
            continue;
        }

        try {
            if (change.action === 'insert') {
                // Check for duplicate
                const existing = await db.query(
                    `SELECT id FROM ${change.table} WHERE id = $1 AND tenant_id = $2`,
                    [change.id, tenantId]
                );
                if (existing.rows.length > 0) {
                    conflicts.push({ id: change.id, table: change.table, reason: 'Already exists (duplicate)' });
                    rejected++;
                    continue;
                }

                // Build dynamic INSERT
                const data = { ...change.data, tenant_id: tenantId, id: change.id };
                const keys = Object.keys(data);
                const values = Object.values(data);
                const placeholders = keys.map((_, i) => `$${i + 1}`).join(', ');
                const columns = keys.join(', ');

                await db.query(
                    `INSERT INTO ${change.table} (${columns}) VALUES (${placeholders})`,
                    values
                );
                accepted++;

            } else if (change.action === 'update') {
                const data = { ...change.data };
                delete data.id;
                delete data.tenant_id;
                (data as any).updated_at = new Date().toISOString();

                const keys = Object.keys(data);
                const values = Object.values(data);
                const setClause = keys.map((k, i) => `${k} = $${i + 1}`).join(', ');

                const result = await db.query(
                    `UPDATE ${change.table} SET ${setClause} WHERE id = $${keys.length + 1} AND tenant_id = $${keys.length + 2}`,
                    [...values, change.id, tenantId]
                );

                if ((result.rowCount ?? 0) > 0) {
                    accepted++;
                } else {
                    conflicts.push({ id: change.id, table: change.table, reason: 'Not found' });
                    rejected++;
                }

            } else if (change.action === 'delete') {
                // Soft delete
                await db.query(
                    `UPDATE ${change.table} SET is_deleted = TRUE, updated_at = NOW() WHERE id = $1 AND tenant_id = $2`,
                    [change.id, tenantId]
                );
                accepted++;
            }
        } catch (err) {
            logger.warn('Sync push error for record', {
                id: change.id, table: change.table, error: (err as Error).message,
            });
            conflicts.push({ id: change.id, table: change.table, reason: (err as Error).message });
            rejected++;
        }
    }

    logger.info('Sync push completed', { tenantId, accepted, rejected });

    return {
        accepted,
        rejected,
        conflicts,
        serverTimestamp: new Date().toISOString(),
    };
}

/**
 * Pull changes from server since last sync timestamp.
 */
export async function pullChanges(
    tenantId: string,
    request: PullRequest
): Promise<PullResponse> {
    const db = getPool();
    const since = request.lastSyncedAt || '1970-01-01T00:00:00Z';
    const tables = request.tables?.filter(t => SYNCABLE_TABLES.has(t))
        || Array.from(SYNCABLE_TABLES);
    const limit = 500; // Max records per pull

    const changes: PulledChange[] = [];

    for (const table of tables) {
        const result = await db.query(
            `SELECT * FROM ${table}
             WHERE tenant_id = $1 AND updated_at > $2
             ORDER BY updated_at ASC
             LIMIT $3`,
            [tenantId, since, limit - changes.length]
        );

        for (const row of result.rows) {
            changes.push({
                table,
                action: row.is_deleted ? 'delete' : 'update',
                id: row.id,
                data: row,
                updatedAt: row.updated_at?.toISOString() || new Date().toISOString(),
            });
        }

        if (changes.length >= limit) break;
    }

    logger.info('Sync pull completed', { tenantId, changesCount: changes.length });

    return {
        changes,
        serverTimestamp: new Date().toISOString(),
        hasMore: changes.length >= limit,
    };
}
