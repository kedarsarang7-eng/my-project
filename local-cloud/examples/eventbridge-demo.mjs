// =============================================================================
// EventBridge Example — Publish and subscribe to domain events
// =============================================================================

const ENDPOINT = 'http://localhost:4566';
const STACK = 'dukan-saas-dev';
const REGION = 'ap-south-1';

// Using AWS SDK v3
import { EventBridgeClient, PutEventsCommand } from '@aws-sdk/client-eventbridge';
import { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } from '@aws-sdk/client-sqs';

const ebClient = new EventBridgeClient({
  region: REGION,
  endpoint: ENDPOINT,
  credentials: { accessKeyId: 'test', secretAccessKey: 'test' },
});

const sqsClient = new SQSClient({
  region: REGION,
  endpoint: ENDPOINT,
  credentials: { accessKeyId: 'test', secretAccessKey: 'test' },
});

// ─── Publish Events ───────────────────────────────────────────────────

async function publishSubscriptionCreated(tenantId, plan) {
  const result = await ebClient.send(new PutEventsCommand({
    Entries: [{
      Source: 'dukan.billing',
      DetailType: 'SubscriptionCreated',
      Detail: JSON.stringify({
        tenantId,
        plan,
        seats: 1,
        createdAt: new Date().toISOString(),
      }),
      EventBusName: `${STACK}-main-bus`,
    }],
  }));
  console.log('✓ SubscriptionCreated event published:', result.FailedEntryCount === 0 ? 'success' : 'failed');
  return result;
}

async function publishTenantCreated(tenantId, name) {
  const result = await ebClient.send(new PutEventsCommand({
    Entries: [{
      Source: 'dukan.tenants',
      DetailType: 'TenantCreated',
      Detail: JSON.stringify({
        tenantId,
        name,
        createdAt: new Date().toISOString(),
      }),
      EventBusName: `${STACK}-main-bus`,
    }],
  }));
  console.log('✓ TenantCreated event published:', result.FailedEntryCount === 0 ? 'success' : 'failed');
  return result;
}

// ─── Consume Events (from SQS target) ─────────────────────────────────

async function consumeAuditEvents(maxMessages = 5) {
  const queueUrl = `${ENDPOINT}/000000000000/${STACK}-audit-events`;
  const result = await sqsClient.send(new ReceiveMessageCommand({
    QueueUrl: queueUrl,
    MaxNumberOfMessages: maxMessages,
    WaitTimeSeconds: 5,
  }));

  if (!result.Messages?.length) {
    console.log('No messages in audit-events queue');
    return [];
  }

  for (const msg of result.Messages) {
    console.log('  Event:', JSON.parse(msg.Body));
    await sqsClient.send(new DeleteMessageCommand({
      QueueUrl: queueUrl,
      ReceiptHandle: msg.ReceiptHandle,
    }));
  }
  return result.Messages;
}

// ─── Demo ─────────────────────────────────────────────────────────────

console.log('━━━ EventBridge + SQS Demo ━━━\n');

await publishTenantCreated('tenant-demo-001', 'Demo Store');
await publishSubscriptionCreated('tenant-demo-001', 'pro');

console.log('\nWaiting 2s for event delivery...');
await new Promise(r => setTimeout(r, 2000));

console.log('\nConsuming events from SQS:');
await consumeAuditEvents();
