// =============================================================================
// Smoke Test — Verify local cloud services are operational
// =============================================================================

const ENDPOINT = 'http://localhost:4566';
const REGION = 'ap-south-1';
const STACK = 'dukan-saas-dev';

const results = [];

function log(service, status, detail = '') {
  const icon = status === 'PASS' ? '✅' : status === 'WARN' ? '⚠️' : '❌';
  results.push({ service, status, detail });
  console.log(`  ${icon} ${service.padEnd(25)} ${status} ${detail}`);
}

async function checkHealth() {
  try {
    const res = await fetch(`${ENDPOINT}/_localstack/health`);
    const data = await res.json();
    log('LocalStack Health', 'PASS', `v${data.version || 'unknown'}`);
    return data;
  } catch (e) {
    log('LocalStack Health', 'FAIL', e.message);
    return null;
  }
}

async function checkDynamoDB() {
  try {
    const res = await fetch(`${ENDPOINT}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-amz-json-1.0',
        'X-Amz-Target': 'DynamoDB_20120810.ListTables',
      },
      body: JSON.stringify({}),
    });
    const data = await res.json();
    const count = data.TableNames?.length || 0;
    log('DynamoDB', count > 0 ? 'PASS' : 'WARN', `${count} tables`);
  } catch (e) {
    log('DynamoDB', 'FAIL', e.message);
  }
}

async function checkS3() {
  try {
    const res = await fetch(`${ENDPOINT}`, {
      headers: { 'Host': 's3.localhost.localstack.cloud:4566' },
    });
    log('S3', res.ok ? 'PASS' : 'WARN', `status ${res.status}`);
  } catch (e) {
    log('S3', 'FAIL', e.message);
  }
}

async function checkSQS() {
  try {
    const res = await fetch(`${ENDPOINT}/?Action=ListQueues`, {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    });
    log('SQS', res.ok ? 'PASS' : 'WARN', `status ${res.status}`);
  } catch (e) {
    log('SQS', 'FAIL', e.message);
  }
}

async function checkRedis() {
  try {
    // Simple TCP check
    const { createConnection } = await import('net');
    return new Promise((resolve) => {
      const socket = createConnection({ host: 'localhost', port: 6379 }, () => {
        log('Redis', 'PASS', 'port 6379');
        socket.destroy();
        resolve();
      });
      socket.on('error', () => {
        log('Redis', 'FAIL', 'port 6379 unreachable');
        resolve();
      });
      socket.setTimeout(2000, () => {
        log('Redis', 'FAIL', 'timeout');
        socket.destroy();
        resolve();
      });
    });
  } catch (e) {
    log('Redis', 'FAIL', e.message);
  }
}

async function checkMailhog() {
  try {
    const res = await fetch('http://localhost:8025/api/v1/messages?limit=1');
    log('Mailhog (Email)', res.ok ? 'PASS' : 'WARN', `status ${res.status}`);
  } catch (e) {
    log('Mailhog (Email)', 'FAIL', e.message);
  }
}

// ─── Run All Checks ───────────────────────────────────────────────────

console.log('━━━ DukanX Local Cloud — Smoke Test ━━━\n');

await checkHealth();
await checkDynamoDB();
await checkS3();
await checkSQS();
await checkRedis();
await checkMailhog();

const pass = results.filter((r) => r.status === 'PASS').length;
const warn = results.filter((r) => r.status === 'WARN').length;
const fail = results.filter((r) => r.status === 'FAIL').length;

console.log(`\n━━━ Results: ${pass} pass, ${warn} warn, ${fail} fail ━━━`);

if (fail > 0) {
  console.log('\n❌ Some services are not running. Run: make up');
  process.exit(1);
} else {
  console.log('\n✅ All services operational!');
}
