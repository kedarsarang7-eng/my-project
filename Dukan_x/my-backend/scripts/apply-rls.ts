import { Pool, PoolClient } from 'pg';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { fileURLToPath } from 'url';

// Load environment variables
dotenv.config();

// Create a pool
const pool = new Pool({
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT || '5432'),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

async function main() {
    let client: PoolClient | null = null;
    try {
        console.log('Connecting to database...');
        client = await pool.connect();

        console.log('Reading SQL file...');
        const sqlPath = path.join(__dirname, '../sql/002_apply_rls_function.sql');
        const sqlContent = fs.readFileSync(sqlPath, 'utf8');

        console.log('Executing SQL function creation script...');
        await client.query(sqlContent);
        console.log('Function `apply_rls_to_all_tables` created/updated successfully.');

        console.log('Running apply_rls_to_all_tables()...');
        const res = await client.query('SELECT * FROM apply_rls_to_all_tables()');

        console.log('Result:');
        if (res.rows.length === 0) {
            console.log('No tables processed (or function returned no rows).');
        } else {
            console.table(res.rows);
        }

    } catch (err) {
        console.error('Error executing script:', err);
    } finally {
        if (client) {
            client.release();
        }
        await pool.end();
    }
}

main();
