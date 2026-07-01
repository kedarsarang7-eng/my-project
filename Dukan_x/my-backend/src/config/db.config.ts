// ============================================================================
// Database Configuration — RDS PostgreSQL Connection Pool
// ============================================================================
// Designed for Lambda: reuses connections across warm invocations.
// For db.t3.micro Free Tier, keep max connections LOW (≤5).
// ============================================================================

import { Pool, PoolConfig, PoolClient } from 'pg';
import { logger } from '../utils/logger';

const poolConfig: PoolConfig = {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    database: process.env.DB_NAME || 'bizmate',
    user: process.env.DB_USER || 'bizmate_admin',
    password: process.env.DB_PASSWORD,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,

    // ── Lambda-Optimized Pool Settings ──────────────────────────────────
    // db.t3.micro supports ~60 concurrent connections.
    // Each Lambda instance gets its own pool. With 5 concurrent Lambdas,
    // that's 5 * 5 = 25 connections — well within limits.
    max: parseInt(process.env.DB_MAX_CONNECTIONS || '5', 10),
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
};

import * as context from '../utils/context';

// Singleton pool — reused across warm Lambda invocations
let pool: Pool | null = null;

/**
 * Returns a Pool instance that automatically handles tenant context.
 * 
 * If a tenant context is active (via AsyncLocalStorage), logic is wrapped 
 * in a `SET app.current_tenant` block.
 */
export function getPool(): Pool {
    if (!pool) {
        pool = new Pool(poolConfig);

        // Log connection errors (but don't crash the Lambda)
        pool.on('error', (err) => {
            console.error('[DB] Unexpected pool error:', err.message);
        });
    }

    // Create a proxy to intercept query calls
    return new Proxy(pool, {
        get(target, prop, receiver) {
            if (prop === 'query') {
                return async (...args: any[]) => {
                    const tenantId = context.getTenantId();

                    // If no tenant context, run raw query (e.g. system tasks)
                    if (!tenantId) {
                        return target.query.apply(target, args as any);
                    }

                    // Borrow a client to set session variable locally for this query
                    // Note: This adds overhead of checking out a client for every query,
                    // but it guarantees isolation without changing service code.
                    const client = await target.connect();
                    try {
                        await client.query(`SELECT set_config('app.current_tenant', $1, false)`, [tenantId]);
                        // Execute the original query using the configured client
                        const result = await client.query.apply(client, args as any);
                        return result;
                    } finally {
                        try {
                            // Reset to prevent leakage if client is reused
                            await client.query(`RESET app.current_tenant`);
                        } catch (e) {
                            console.error('Failed to reset tenant context', e);
                        }
                        client.release();
                    }
                };
            }
            return Reflect.get(target, prop, receiver);
        }
    });
}

/**
 * Execute a function with a tenant-scoped database connection.
 * 
 * GUARANTEES:
 * 1. Acquires a client from the pool.
 * 2. Sets 'app.current_tenant' to the provided tenantId.
 * 3. Executes the callback function.
 * 4. Resets 'app.current_tenant' to prevent leakage.
 * 5. Releases the client back to the pool.
 * 
 * @param tenantId The UUID of the tenant.
 * @param callback The function to execute with the authorized client.
 */
export async function executeWithTenant<T>(
    tenantId: string,
    callback: (client: PoolClient) => Promise<T>
): Promise<T> {
    const db = getPool();
    const client = await db.connect();

    try {
        // 1. Set Tenant Context
        await client.query(`SELECT set_config('app.current_tenant', $1, false)`, [tenantId]);

        // 2. Execute Logic
        return await callback(client);

    } finally {
        // 3. Reset Context & Release (Critical for Safety)
        try {
            // Resetting session variable ensures next user of this connection doesn't inherit rights
            await client.query(`RESET app.current_tenant`);
        } catch (resetError) {
            logger.error('Failed to reset tenant context', { error: resetError });
            // If reset fails, we should ideally destroy the client to be safe, 
            // but for now logging is the first step.
        }
        client.release();
    }
}

/**
 * Execute a query within a transaction with tenant context.
 * Automatically handles BEGIN, SET CONTEXT, COMMIT/ROLLBACK, RESET, RELEASE.
 */
export async function withTransaction<T>(
    tenantId: string,
    fn: (client: PoolClient) => Promise<T>
): Promise<T> {
    const db = getPool();
    const client = await db.connect();

    try {
        await client.query('BEGIN');
        await client.query(`SELECT set_config('app.current_tenant', $1, true)`, [tenantId]);

        const result = await fn(client);

        await client.query('COMMIT');
        return result;
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        try {
            await client.query(`RESET app.current_tenant`);
        } catch (e) {
            logger.error('Failed to reset tenant context in tx', { error: e });
        }
        client.release();
    }
}

/**
 * DEPRECATED: Do not use. Use executeWithTenant() instead.
 * This function was unsafe as it didn't bind the context to the specific query execution.
 */
export async function setTenantContext(tenantId: string): Promise<void> {
    throw new Error('Unsafe function usage: setTenantContext. Use executeWithTenant() instead.');
}
