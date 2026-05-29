// =============================================================================
// Step Functions Example — Execute trial provisioning workflow
// =============================================================================

import { SFNClient, StartExecutionCommand, DescribeExecutionCommand } from '@aws-sdk/client-sfn';

const config = {
  region: 'ap-south-1',
  endpoint: 'http://localhost:4566',
  credentials: { accessKeyId: 'test', secretAccessKey: 'test' },
};

const sfn = new SFNClient(config);
const STACK = 'dukan-saas-dev';

async function startTrialProvisioning(tenantId, adminEmail) {
  const stateMachineArn = `arn:aws:states:ap-south-1:000000000000:stateMachine:${STACK}-trial-provisioning`;

  const result = await sfn.send(new StartExecutionCommand({
    stateMachineArn,
    name: `trial-${tenantId}-${Date.now()}`,
    input: JSON.stringify({ tenantId, adminEmail }),
  }));

  console.log(`✓ Execution started: ${result.executionArn}`);
  return result.executionArn;
}

async function waitForCompletion(executionArn, maxWait = 30000) {
  const start = Date.now();
  while (Date.now() - start < maxWait) {
    const result = await sfn.send(new DescribeExecutionCommand({ executionArn }));
    console.log(`  Status: ${result.status}`);
    if (result.status === 'SUCCEEDED') {
      console.log('  Output:', JSON.parse(result.output || '{}'));
      return result;
    }
    if (result.status === 'FAILED' || result.status === 'ABORTED') {
      console.error('  Error:', result.error, result.cause);
      return result;
    }
    await new Promise(r => setTimeout(r, 2000));
  }
  console.error('  Timeout waiting for execution');
}

// ─── Demo ─────────────────────────────────────────────────────────────

console.log('━━━ Step Functions Demo — Trial Provisioning ━━━\n');

const arn = await startTrialProvisioning('tenant-trial-001', 'trial@example.com');
await waitForCompletion(arn);
