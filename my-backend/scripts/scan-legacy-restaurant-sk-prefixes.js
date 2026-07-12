#!/usr/bin/env node
/* eslint-disable no-console */
// ============================================================================
// Phase 1, step 4 — Read-only scan for records under the OLD (pre-fix)
// sync.service.ts restaurant SK prefixes: RESTTABLE#, RESTFLOOR#, RESTBILL#,
// RESTKOT#. These diverged from resto.ts's canonical RESTOTABLE#, RESTOFLOOR#,
// RESTOBILL#, KOT#/KOTITEM# prefixes before the Phase 1 fix.
//
// This script performs a SCAN (not Query) because the legacy prefix could be
// under any tenant partition. Scans are expensive — this is a one-time
// diagnostic, not something to run routinely.
//
// SAFETY: --dry-run is the default and the ONLY mode this script supports.
// It reports counts and sample keys; it does NOT write, delete, or migrate
// anything. A separate backfill script (not yet written — see Phase 1 step 5)
// would be needed if this scan finds records to migrate, and THAT script
// requires its own --dry-run-by-default + --execute confirmation gate.
//
// Usage:
//   node scripts/scan-legacy-restaurant-sk-prefixes.js
//
// Requires valid AWS credentials (or LocalStack env vars) for whichever
// environment TABLE_NAME/DYNAMODB_TABLE resolves to. This script will NOT
// run against production without production credentials being present in
// the environment — it inherits whatever the environment is configured for,
// same as any other script in this package. Run it explicitly against the
// environment you want to check; it will not guess.
// ============================================================================

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand } = require('@aws-sdk/lib-dynamodb');

const IS_LOCAL = process.env.NODE_ENV === 'local' || process.env.USE_LOCALSTACK === 'true';
const LOCALSTACK_ENDPOINT = process.env.LOCALSTACK_ENDPOINT || 'http://localhost:4566';
const TABLE_NAME = process.env.DYNAMODB_TABLE || process.env.TABLE_NAME;

const LEGACY_PREFIXES = ['RESTTABLE#', 'RESTFLOOR#', 'RESTBILL#', 'RESTKOT#'];

async function main() {
    if (!TABLE_NAME) {
        console.error('ERROR: DYNAMODB_TABLE (or TABLE_NAME) env var is not set. Refusing to scan without an explicit table name.');
        process.exit(1);
    }

    const clientConfig = { region: process.env.AWS_REGION || 'ap-south-1' };
    if (IS_LOCAL) {
        clientConfig.endpoint = LOCALSTACK_ENDPOINT;
        clientConfig.credentials = { accessKeyId: 'test', secretAccessKey: 'test' };
        console.log(`[LOCAL] Scanning against LocalStack at ${LOCALSTACK_ENDPOINT}, table=${TABLE_NAME}`);
    } else {
        console.log(`[REMOTE] Scanning table=${TABLE_NAME} in region=${clientConfig.region} using ambient AWS credentials.`);
        console.log('This will incur DynamoDB scan read cost. Proceeding in read-only dry-run mode.');
    }

    const client = new DynamoDBClient(clientConfig);
    const doc = DynamoDBDocumentClient.from(client);

    const results = {};
    for (const prefix of LEGACY_PREFIXES) results[prefix] = { count: 0, sampleKeys: [] };

    let lastKey;
    let pagesScanned = 0;
    const MAX_PAGES = 50; // safety cap — this is a diagnostic scan, not a full migration

    do {
        const res = await doc.send(new ScanCommand({
            TableName: TABLE_NAME,
            FilterExpression: 'begins_with(SK, :p0) OR begins_with(SK, :p1) OR begins_with(SK, :p2) OR begins_with(SK, :p3)',
            ExpressionAttributeValues: {
                ':p0': LEGACY_PREFIXES[0],
                ':p1': LEGACY_PREFIXES[1],
                ':p2': LEGACY_PREFIXES[2],
                ':p3': LEGACY_PREFIXES[3],
            },
            ExclusiveStartKey: lastKey,
            Limit: 500,
        }));

        for (const item of res.Items || []) {
            const matched = LEGACY_PREFIXES.find((p) => String(item.SK || '').startsWith(p));
            if (!matched) continue;
            results[matched].count++;
            if (results[matched].sampleKeys.length < 5) {
                results[matched].sampleKeys.push({ PK: item.PK, SK: item.SK, updatedAt: item.updatedAt });
            }
        }

        lastKey = res.LastEvaluatedKey;
        pagesScanned++;
    } while (lastKey && pagesScanned < MAX_PAGES);

    console.log('\n=== Legacy restaurant SK prefix scan — DRY RUN REPORT (read-only, no writes) ===');
    let totalFound = 0;
    for (const prefix of LEGACY_PREFIXES) {
        const r = results[prefix];
        totalFound += r.count;
        console.log(`\n${prefix}: ${r.count} record(s) found`);
        if (r.sampleKeys.length > 0) {
            console.log('  Sample keys:', JSON.stringify(r.sampleKeys, null, 2));
        }
    }
    console.log(`\nPages scanned: ${pagesScanned}${pagesScanned >= MAX_PAGES ? ' (hit safety cap — table may have more; re-run with a higher cap if needed)' : ' (complete)'}`);
    console.log(`\nTOTAL legacy-prefixed records found: ${totalFound}`);
    if (totalFound === 0) {
        console.log('\nNo records found under the old sync.service.ts prefixes. No migration/backfill is needed.');
    } else {
        console.log('\nRecords found under old prefixes. Human review required before writing any backfill script.');
    }
}

main().catch((err) => {
    console.error('Scan failed:', err);
    process.exit(1);
});
