// ============================================
// Database Connection — PostgreSQL Pool
// ============================================

import { Pool, PoolConfig } from 'pg';
import dotenv from 'dotenv';
import { logger } from '../utils/logger';

dotenv.config();

const poolConfig: PoolConfig = {
    connectionString: process.env.DATABASE_URL,
    max: parseInt(process.env.DB_MAX_CONNECTIONS || '8', 10), // EC2 t2.micro: keep low (8+8+5=21 of ~60 max)
    idleTimeoutMillis: 30000,   // close idle clients after 30s
    connectionTimeoutMillis: 5000,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
};

export const pool = new Pool(poolConfig);

// Log pool events
pool.on('connect', () => {
    logger.debug('New database connection established');
});

pool.on('error', (err) => {
    logger.error('Unexpected database pool error', { error: err.message });
});

/**
 * Execute a parameterized query against the database.
 * Always use parameterized queries to prevent SQL injection.
 */
export async function query<T = any>(text: string, params?: any[]): Promise<T[]> {
    const start = Date.now();
    const result = await pool.query(text, params);
    const duration = Date.now() - start;

    logger.debug('Executed query', {
        text: text.substring(0, 80),
        duration: `${duration}ms`,
        rows: result.rowCount,
    });

    return result.rows as T[];
}

/**
 * Execute a query and return a single row or null.
 */
export async function queryOne<T = any>(text: string, params?: any[]): Promise<T | null> {
    const rows = await query<T>(text, params);
    return rows.length > 0 ? rows[0] : null;
}

/**
 * Test the database connection.
 */
export async function testConnection(): Promise<boolean> {
    try {
        const result = await pool.query('SELECT NOW()');
        logger.info('Database connected', { time: result.rows[0].now });
        return true;
    } catch (error: any) {
        logger.error('Database connection failed', { error: error.message });
        return false;
    }
}

export default pool;
