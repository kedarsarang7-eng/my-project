
import { Client } from 'pg';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

async function createDatabase() {
    const targetDbName = process.env.DB_NAME || 'dukanx-db';

    // Connect to default 'postgres' database
    const client = new Client({
        host: process.env.DB_HOST,
        port: parseInt(process.env.DB_PORT || '5432'),
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: 'postgres', // Connect to default DB to create new one
        ssl: { rejectUnauthorized: false }
    });

    try {
        await client.connect();
        console.log('Connected to postgres database.');

        // Check if database exists
        const res = await client.query(`SELECT 1 FROM pg_database WHERE datname = $1`, [targetDbName]);

        if (res.rowCount === 0) {
            console.log(`Database ${targetDbName} does not exist. Creating...`);
            // CREATE DATABASE cannot run in a transaction block, and cannot use parameters for DB name
            await client.query(`CREATE DATABASE "${targetDbName}"`);
            console.log(`Database ${targetDbName} created successfully.`);
        } else {
            console.log(`Database ${targetDbName} already exists.`);
        }

    } catch (err) {
        console.error('Error creating database:', err);
    } finally {
        await client.end();
    }
}

createDatabase();
