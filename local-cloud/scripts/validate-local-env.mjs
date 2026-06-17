#!/usr/bin/env node
// =============================================================================
// DukanX Local Environment Validation Script
// =============================================================================
// Validates that LocalStack, Keycloak, DynamoDB tables, S3 buckets,
// and the auth flow are all operational.
//
// Usage: node local-cloud/scripts/validate-local-env.mjs
// =============================================================================

import { DynamoDBClient, ListTablesCommand } from '@aws-sdk/client-dynamodb';
import { S3Client, ListBucketsCommand } from '@aws-sdk/client-s3';
import { SQSClient, ListQueuesCommand } from '@aws-sdk/client-sqs';
import { SNSClient, ListTopicsCommand } from '@aws-sdk/client-sns';

const LOCAL_CONFIG = {
    endpoint: 'http://localhost:4566',
    region: 'ap-south-1',
    credentials: { accessKeyId: 'test', secretAccessKey: 'test' },
    forcePathStyle: true,
};

const STACK = 'dukan-saas-dev';

const REQUIRED_TABLES = [
    `${STACK}-auth-sessions`,
    `${STACK}-tenants`,
    `${STACK}-users`,
    `${STACK}-billing`,
    `${STACK}-audit-logs`,
    `${STACK}-customer-invoices`,
    `${STACK}-customer-ledger`,
    `${STACK}-customer-payments`,
    `${STACK}-customer-notifications`,
    `${STACK}-ws-connections`,
];

const REQUIRED_BUCKETS = [
    `${STACK}-uploads`,
    `${STACK}-exports`,
    `${STACK}-barcode-labels`,
];

const REQUIRED_QUEUES = [
    `${STACK}-email-notifications`,
    `${STACK}-email-notifications-dlq`,
    `${STACK}-audit-events`,
    `${STACK}-trial-provisioning`,
];

const results = [];

function record(check, pass, detail) {
    results.push({ check, pass, detail: detail || (pass ? 'OK' : 'FAILED') });
}

async function checkLocalStack() {
    try {
        const res = await fetch('http://localhost:4566/_localstack/health');
        const data = await res.json();
        const services = data.services || {};
        for (const svc of ['dynamodb', 's3', 'sqs', 'sns', 'events', 'secretsmanager']) {
            const status = services[svc];
            record(
                `LocalStack: ${svc}`,
                status === 'running' || status === 'available',
                status || 'not found'
            );
        }
    } catch (e) {
        record('LocalStack reachable', false, e.message);
    }
}

async function checkDynamoDB() {
    try {
        const dynamo = new DynamoDBClient(LOCAL_CONFIG);
        const { TableNames } = await dynamo.send(new ListTablesCommand({}));
        for (const table of REQUIRED_TABLES) {
            record(
                `DynamoDB table: ${table}`,
                TableNames.includes(table),
                TableNames.includes(table) ? 'exists' : '❌ MISSING'
            );
        }
    } catch (e) {
        record('DynamoDB connection', false, e.message);
    }
}

async function checkS3() {
    try {
        const s3 = new S3Client(LOCAL_CONFIG);
        const { Buckets } = await s3.send(new ListBucketsCommand({}));
        const bucketNames = (Buckets || []).map(b => b.Name);
        for (const bucket of REQUIRED_BUCKETS) {
            record(
                `S3 bucket: ${bucket}`,
                bucketNames.includes(bucket),
                bucketNames.includes(bucket) ? 'exists' : '❌ MISSING'
            );
        }
    } catch (e) {
        record('S3 connection', false, e.message);
    }
}

async function checkSQS() {
    try {
        const sqs = new SQSClient(LOCAL_CONFIG);
        const { QueueUrls } = await sqs.send(new ListQueuesCommand({}));
        const queueNames = (QueueUrls || []).map(url => {
            const parts = url.split('/');
            return parts[parts.length - 1];
        });
        for (const queue of REQUIRED_QUEUES) {
            record(
                `SQS queue: ${queue}`,
                queueNames.includes(queue),
                queueNames.includes(queue) ? 'exists' : '❌ MISSING'
            );
        }
    } catch (e) {
        record('SQS connection', false, e.message);
    }
}

async function checkKeycloak() {
    // Health check
    try {
        const res = await fetch('http://localhost:8080/health/ready');
        record('Keycloak health', res.ok, res.ok ? 'UP' : `status=${res.status}`);
    } catch (e) {
        record('Keycloak reachable', false, e.message);
        return; // Skip further Keycloak checks
    }

    // Realm check
    try {
        const res = await fetch('http://localhost:8080/realms/dukanx/.well-known/openid-configuration');
        const data = await res.json();
        record('Keycloak realm: dukanx', !!data.issuer, data.issuer || '❌ realm not found');
    } catch (e) {
        record('Keycloak realm: dukanx', false, e.message);
    }
}

async function checkAuthFlow() {
    // Get a token from Keycloak
    try {
        const params = new URLSearchParams({
            grant_type: 'password',
            client_id: 'dukanx-flutter-app',
            username: 'owner_test_001',
            password: 'Test@1234',
        });

        const res = await fetch(
            'http://localhost:8080/realms/dukanx/protocol/openid-connect/token',
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: params.toString(),
            }
        );

        if (!res.ok) {
            const err = await res.text();
            record('Auth: get Keycloak token', false, `HTTP ${res.status}: ${err}`);
            return;
        }

        const tokenData = await res.json();
        const token = tokenData.access_token;
        record('Auth: get Keycloak token', !!token, token ? '✅ Token received' : '❌ No token');

        if (token) {
            // Decode and check claims
            const parts = token.split('.');
            const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
            const tenantId = payload['custom:tenant_id'] || payload['tenantId'];
            const role = payload['custom:role'] || payload['role'];
            record(
                'Auth: JWT contains tenant_id',
                !!tenantId,
                tenantId ? `tenantId=${tenantId}` : '❌ Missing tenant_id claim'
            );
            record(
                'Auth: JWT contains role',
                !!role,
                role ? `role=${role}` : '❌ Missing role claim'
            );
        }
    } catch (e) {
        record('Auth: get Keycloak token', false, e.message);
    }
}

async function checkSeedData() {
    try {
        const { DynamoDBDocumentClient, GetCommand } = await import('@aws-sdk/lib-dynamodb');
        const rawClient = new DynamoDBClient(LOCAL_CONFIG);
        const docClient = DynamoDBDocumentClient.from(rawClient);

        // Check tenant-001 in tenants table
        const tenantResult = await docClient.send(new GetCommand({
            TableName: `${STACK}-tenants`,
            Key: { tenantId: 'tenant-001' },
        }));
        record(
            'Seed data: tenant-001',
            !!tenantResult.Item,
            tenantResult.Item ? `name=${tenantResult.Item.name}` : '❌ Not found'
        );
    } catch (e) {
        record('Seed data check', false, e.message);
    }
}

// ── Main ─────────────────────────────────────────────────────────────────
async function validate() {
    console.log('\n╔══════════════════════════════════════════════════════════════╗');
    console.log('║  DukanX Local Environment Validation                        ║');
    console.log('╚══════════════════════════════════════════════════════════════╝\n');

    await checkLocalStack();
    await checkDynamoDB();
    await checkS3();
    await checkSQS();
    await checkKeycloak();
    await checkAuthFlow();
    await checkSeedData();

    // Print results
    console.log('\n─── Results ────────────────────────────────────────────────────\n');
    let passed = 0, failed = 0;
    for (const r of results) {
        const icon = r.pass ? '✅' : '❌';
        console.log(`${icon} ${r.check}: ${r.detail}`);
        if (r.pass) passed++; else failed++;
    }

    console.log(`\n─── Summary ────────────────────────────────────────────────────`);
    console.log(`  ✅ Passed: ${passed}`);
    console.log(`  ❌ Failed: ${failed}`);
    console.log(`  📊 Total:  ${passed + failed}\n`);

    if (failed > 0) {
        console.log('⚠️  Fix all failures before proceeding.\n');
        process.exit(1);
    } else {
        console.log('🎉 All checks passed. Local environment is ready.\n');
    }
}

validate().catch(err => {
    console.error('Validation script error:', err);
    process.exit(1);
});
