import { Pool } from 'pg';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config();

const pool = new Pool({
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT || '5432'),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

async function main() {
    try {
        console.log('Connecting to database...');
        const client = await pool.connect();
        try {
            console.log('Reading Trigger SQL...');
            const sqlPath = path.join(__dirname, '../sql/003_auto_rls_trigger.sql');
            const sqlContent = fs.readFileSync(sqlPath, 'utf8');

            console.log('Deploying Event Trigger...');
            await client.query(sqlContent);
            console.log('SUCCESS: Event Trigger created/updated.');
        } finally {
            client.release();
        }
    } catch (err) {
        console.error('Error applying trigger:', err);
    } finally {
        await pool.end();
    }
}

main();
