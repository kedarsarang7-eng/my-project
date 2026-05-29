// =============================================================================
// SQS + SNS Example — Message queue and pub/sub patterns
// =============================================================================

import { SQSClient, SendMessageCommand, ReceiveMessageCommand } from '@aws-sdk/client-sqs';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';

const config = {
  region: 'ap-south-1',
  endpoint: 'http://localhost:4566',
  credentials: { accessKeyId: 'test', secretAccessKey: 'test' },
};

const sqs = new SQSClient(config);
const sns = new SNSClient(config);

const STACK = 'dukan-saas-dev';
const ACCOUNT = '000000000000';

// ─── SQS: Send email notification ─────────────────────────────────────

async function sendEmailNotification(tenantId, email, template, data) {
  const queueUrl = `http://localhost:4566/${ACCOUNT}/${STACK}-email-notifications`;

  await sqs.send(new SendMessageCommand({
    QueueUrl: queueUrl,
    MessageBody: JSON.stringify({
      type: 'EMAIL',
      template,
      tenantId,
      to: email,
      data,
      createdAt: new Date().toISOString(),
    }),
    MessageAttributes: {
      tenant: { DataType: 'String', StringValue: tenantId },
      template: { DataType: 'String', StringValue: template },
    },
  }));

  console.log(`✓ Email queued: ${template} → ${email}`);
}

// ─── SNS: Publish tenant event ────────────────────────────────────────

async function notifyTenantEvent(eventType, tenantId, payload) {
  const topicArn = `arn:aws:sns:ap-south-1:${ACCOUNT}:${STACK}-tenant-events`;

  await sns.send(new PublishCommand({
    TopicArn: topicArn,
    Subject: eventType,
    Message: JSON.stringify({
      eventType,
      tenantId,
      payload,
      timestamp: new Date().toISOString(),
    }),
    MessageAttributes: {
      eventType: { DataType: 'String', StringValue: eventType },
      tenantId: { DataType: 'String', StringValue: tenantId },
    },
  }));

  console.log(`✓ SNS published: ${eventType} for ${tenantId}`);
}

// ─── SQS: Poll for messages ──────────────────────────────────────────

async function pollEmailQueue() {
  const queueUrl = `http://localhost:4566/${ACCOUNT}/${STACK}-email-notifications`;

  const result = await sqs.send(new ReceiveMessageCommand({
    QueueUrl: queueUrl,
    MaxNumberOfMessages: 10,
    WaitTimeSeconds: 5,
    MessageAttributeNames: ['All'],
  }));

  if (!result.Messages?.length) {
    console.log('No pending emails');
    return;
  }

  for (const msg of result.Messages) {
    const body = JSON.parse(msg.Body);
    console.log(`  📧 ${body.template} → ${body.to} (tenant: ${body.tenantId})`);
  }
}

// ─── Demo ─────────────────────────────────────────────────────────────

console.log('━━━ SQS + SNS Demo ━━━\n');

// Queue emails
await sendEmailNotification('tenant-001', 'admin@sharma.local', 'WELCOME', { name: 'Rajesh' });
await sendEmailNotification('tenant-001', 'cashier@sharma.local', 'INVITE', { invitedBy: 'Rajesh' });

// Publish SNS events
await notifyTenantEvent('PLAN_UPGRADED', 'tenant-001', { from: 'pro', to: 'premium' });

// Poll queue
console.log('\nPending emails:');
await pollEmailQueue();
