// =============================================================================
// Lambda Local Invoker — Invoke Lambda handlers directly without SAM
// =============================================================================
// Usage:
//   node local-cloud/scripts/invoke-lambda.mjs <handlerDir> <eventJson>
//   node local-cloud/scripts/invoke-lambda.mjs billingHandler '{"httpMethod":"GET"...}'
// =============================================================================

import { pathToFileURL } from 'url';
import { resolve } from 'path';

const [,, handlerDir, eventJson] = process.argv;

if (!handlerDir) {
  console.error('Usage: invoke-lambda.mjs <handlerDir> [eventJson]');
  console.error('Example: invoke-lambda.mjs billingHandler \'{"httpMethod":"GET","path":"/billing/plans"}\'');
  process.exit(1);
}

// Set environment variables for local execution
process.env.AWS_ENDPOINT_URL = 'http://localhost:4566';
process.env.AWS_REGION = 'ap-south-1';
process.env.AWS_ACCESS_KEY_ID = 'test';
process.env.AWS_SECRET_ACCESS_KEY = 'test';
process.env.DYNAMODB_TABLE_AUTH = 'dukan-saas-dev-auth-sessions';
process.env.DYNAMODB_TABLE_TENANTS = 'dukan-saas-dev-tenants';
process.env.DYNAMODB_TABLE_USERS = 'dukan-saas-dev-users';
process.env.DYNAMODB_TABLE_BILLING = 'dukan-saas-dev-billing';
process.env.DYNAMODB_TABLE_AUDIT = 'dukan-saas-dev-audit-logs';
process.env.ENVIRONMENT = 'dev';

const handlerPath = resolve('lambda', handlerDir, 'index.mjs');
const handlerUrl = pathToFileURL(handlerPath).href;

const event = eventJson ? JSON.parse(eventJson) : {
  httpMethod: 'GET',
  path: '/',
  headers: {},
  requestContext: { http: { method: 'GET', path: '/', sourceIp: '127.0.0.1', userAgent: 'local-invoke' } },
  pathParameters: {},
  queryStringParameters: {},
  body: null,
};

const context = {
  functionName: handlerDir,
  functionVersion: '$LATEST',
  invokedFunctionArn: `arn:aws:lambda:ap-south-1:000000000000:function:${handlerDir}`,
  memoryLimitInMB: '256',
  awsRequestId: crypto.randomUUID(),
  logGroupName: `/aws/lambda/${handlerDir}`,
  logStreamName: '2026/05/23/[$LATEST]local',
  getRemainingTimeInMillis: () => 29000,
};

console.log(`━━━ Invoking lambda/${handlerDir} ━━━`);
console.log(`Event: ${JSON.stringify(event, null, 2).slice(0, 200)}...`);
console.log('');

const start = performance.now();

try {
  const mod = await import(handlerUrl);
  const result = await mod.handler(event, context);
  const duration = (performance.now() - start).toFixed(1);

  console.log(`━━━ Response (${duration}ms) ━━━`);
  console.log(JSON.stringify(result, null, 2));
} catch (err) {
  const duration = (performance.now() - start).toFixed(1);
  console.error(`━━━ Error (${duration}ms) ━━━`);
  console.error(err);
  process.exit(1);
}
