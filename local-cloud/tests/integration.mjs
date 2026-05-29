// =============================================================================
// Integration Tests — DukanX Local Cloud
// =============================================================================
// These tests run against the local Docker environment.
// Prerequisites: make up && make seed
// =============================================================================

import { DynamoDBClient, ScanCommand } from '@aws-sdk/client-dynamodb';
import { SQSClient, SendMessageCommand, ReceiveMessageCommand, PurgeQueueCommand } from '@aws-sdk/client-sqs';
import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';
import { strict as assert } from 'assert';

const config = {
  region: 'ap-south-1',
  endpoint: 'http://localhost:4566',
  credentials: { accessKeyId: 'test', secretAccessKey: 'test' },
};

const STACK = 'dukan-saas-dev';
const ddb = new DynamoDBClient(config);
const sqs = new SQSClient(config);
const s3 = new S3Client({ ...config, forcePathStyle: true });
const sm = new SecretsManagerClient(config);
const ssm = new SSMClient(config);

let passed = 0;
let failed = 0;

async function test(name, fn) {
  try {
    await fn();
    console.log(`  ✅ ${name}`);
    passed++;
  } catch (err) {
    console.log(`  ❌ ${name}: ${err.message}`);
    failed++;
  }
}

// ─── DynamoDB Tests ───────────────────────────────────────────────────

console.log('\n━━━ DynamoDB ━━━');

await test('Tenants table has seeded data', async () => {
  const result = await ddb.send(new ScanCommand({ TableName: `${STACK}-tenants`, Limit: 10 }));
  assert(result.Count > 0, `Expected >0 tenants, got ${result.Count}`);
});

await test('Users table has seeded data', async () => {
  const result = await ddb.send(new ScanCommand({ TableName: `${STACK}-users`, Limit: 10 }));
  assert(result.Count > 0, `Expected >0 users, got ${result.Count}`);
});

await test('Billing table has subscription', async () => {
  const result = await ddb.send(new ScanCommand({ TableName: `${STACK}-billing`, Limit: 10 }));
  assert(result.Count > 0, `Expected >0 billing items, got ${result.Count}`);
});

// ─── SQS Tests ────────────────────────────────────────────────────────

console.log('\n━━━ SQS ━━━');

const queueUrl = `http://localhost:4566/000000000000/${STACK}-email-notifications`;

await test('Send message to SQS', async () => {
  await sqs.send(new SendMessageCommand({
    QueueUrl: queueUrl,
    MessageBody: JSON.stringify({ test: true, ts: Date.now() }),
  }));
});

await test('Receive message from SQS', async () => {
  const result = await sqs.send(new ReceiveMessageCommand({
    QueueUrl: queueUrl,
    MaxNumberOfMessages: 1,
    WaitTimeSeconds: 3,
  }));
  assert(result.Messages?.length > 0, 'No messages received');
  const body = JSON.parse(result.Messages[0].Body);
  assert(body.test === true, 'Message content mismatch');
});

// ─── S3 Tests ─────────────────────────────────────────────────────────

console.log('\n━━━ S3 ━━━');

await test('Upload to S3', async () => {
  await s3.send(new PutObjectCommand({
    Bucket: `${STACK}-uploads`,
    Key: 'test/hello.txt',
    Body: 'Hello from integration test',
    ContentType: 'text/plain',
  }));
});

await test('Download from S3', async () => {
  const result = await s3.send(new GetObjectCommand({
    Bucket: `${STACK}-uploads`,
    Key: 'test/hello.txt',
  }));
  const body = await result.Body.transformToString();
  assert(body === 'Hello from integration test', `Got: ${body}`);
});

await test('Delete from S3', async () => {
  await s3.send(new DeleteObjectCommand({
    Bucket: `${STACK}-uploads`,
    Key: 'test/hello.txt',
  }));
});

// ─── Secrets Manager Tests ────────────────────────────────────────────

console.log('\n━━━ Secrets Manager ━━━');

await test('Retrieve JWT signing key', async () => {
  const result = await sm.send(new GetSecretValueCommand({
    SecretId: `${STACK}/jwt-signing-key`,
  }));
  const secret = JSON.parse(result.SecretString);
  assert(secret.key, 'Missing key in secret');
});

// ─── SSM Parameter Store Tests ────────────────────────────────────────

console.log('\n━━━ SSM Parameter Store ━━━');

await test('Get environment parameter', async () => {
  const result = await ssm.send(new GetParameterCommand({
    Name: `/${STACK}/environment`,
  }));
  assert(result.Parameter.Value === 'dev', `Expected dev, got ${result.Parameter.Value}`);
});

await test('Get feature flags', async () => {
  const result = await ssm.send(new GetParameterCommand({
    Name: `/${STACK}/feature-flags`,
  }));
  const flags = JSON.parse(result.Parameter.Value);
  assert(flags.enableWebSocket === true, 'Feature flag mismatch');
});

// ─── Results ──────────────────────────────────────────────────────────

console.log(`\n━━━ Results: ${passed} passed, ${failed} failed ━━━`);
process.exit(failed > 0 ? 1 : 0);
