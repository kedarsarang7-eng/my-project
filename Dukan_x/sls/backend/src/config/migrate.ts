// ============================================
// Database Migration Runner
// ============================================

import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
dotenv.config();

import { pool, runMigration } from './database';
import { logger } from '../utils/logger';

async function migrate(): Promise<void> {
    const migrationsDir = path.join(__dirname, '../../migrations');
    const files = fs.readdirSync(migrationsDir)
        .filter(f => f.endsWith('.sql'))
        .sort();

    logger.info(`Found ${files.length} migration(s)`);

    for (const file of files) {
        logger.info(`Running migration: ${file}`);
        const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf-8');
        await runMigration(sql);
    }

    logger.info('All migrations completed');
    await pool.end();
    process.exit(0);
}

migrate().catch(err => {
    logger.error('Migration failed', { error: err.message });
    process.exit(1);
});
