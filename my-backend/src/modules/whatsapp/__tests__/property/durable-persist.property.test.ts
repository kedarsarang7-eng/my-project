/**
 * Property-Based Tests: Every enqueue is durably persisted before acknowledgment
 * and dispatched exactly once.
 *
 * Feature: openwa-whatsapp-automation, Property 28
 *
 * **Validates: Requirements 14.4, 14.5, 14.6, 14.7**
 *
 * Property 28: Every enqueue is durably persisted before acknowledgment and
 * dispatched exactly once (run against LocalStack).
 *
 * The WhatsApp_Automation_System SHALL persist every enqueued Outbound_Message
 * to durable storage before acknowledging enqueue (Req 14.4). If persistence
 * fails, no ack is returned and the message is retained for retry (Req 14.7).
 * Each Outbound_Message is dispatched exactly once — no duplicates, no losses
 * (Req 14.5, 14.6).
 *
 * Strategy: Mock DynamoDB (OutboundMessageRepository) and SQS to track the
 * exact ordering of operations and verify:
 *  1. DynamoDB putItem occurs before SQS send (persist-before-ack)
 *  2. On persistence failure, no ack (success = false, no SQS send)
 *  3. Each message dispatched exactly once (no duplicate SQS sends)
 */

import * as fc from 'fast-check';

// ── Operation log to track ordering ──────────────────────────────────────────

type OpType = 'dynamo_put' | 'delivery_log' | 'sqs_send';
interface OpEntry {
  type: OpType;
  messageId?: string;
  businessId?: string;
  recipientId?: string;
}

let operationLog: OpEntry[] = [];
let persistShouldFail = false;
let sqsShouldFail = false;
let persistedMessages: Map<string, Record<string, unknown>> = new Map();
let sqsMessagesSent: Map<string, string[]> = new Map(); // messageId -> array of send attempts

// ── Mock OutboundMessageRepository ───────────────────────────────────────────

const mockCreate = jest.fn(
  async (_tenantId: string, _businessId: string, data: Record<string, unknown>) => {
    if (persistShouldFail) {
      operationLog.push({ type: 'dynamo_put', businessId: _businessId });
      throw new Error('DynamoDB persistence failed (simulated)');
    }

    const id = `msg_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
    const now = new Date().toISOString();
    const message = {
      id,
      businessId: _businessId,
      tenantId: _tenantId,
      eventId: data.eventId,
      recipientId: data.recipientId,
      recipientNumber: data.recipientNumber,
      templateId: data.templateId,
      templateVersion: data.templateVersion,
      renderedBody: data.renderedBody,
      mediaUrl: data.mediaUrl,
      branchId: data.branchId,
      status: 'queued',
      attempts: 0,
      expiresAt: data.expiresAt,
      createdAt: now,
      updatedAt: now,
    };

    operationLog.push({
      type: 'dynamo_put',
      messageId: id,
      businessId: _businessId,
      recipientId: data.recipientId as string,
    });
    persistedMessages.set(id, message);

    return message;
  },
);

// ── Mock DeliveryLogRepository ───────────────────────────────────────────────

const mockDeliveryLogCreate = jest.fn(
  async (_tenantId: string, _businessId: string, data: Record<string, unknown>) => {
    operationLog.push({ type: 'delivery_log', messageId: data.outboundMessageId as string });
    return {
      id: `log_${Date.now()}`,
      businessId: _businessId,
      tenantId: _tenantId,
      outboundMessageId: data.outboundMessageId,
      state: data.state,
      timestamp: new Date().toISOString(),
    };
  },
);

// ── Mock SQS Client ──────────────────────────────────────────────────────────

const mockSqsSend = jest.fn(async (command: unknown) => {
  const cmd = command as { input?: { MessageBody?: string; MessageDeduplicationId?: string } };
  const body = cmd.input?.MessageBody ? JSON.parse(cmd.input.MessageBody) : {};
  const messageId = body.outboundMessageId || cmd.input?.MessageDeduplicationId || 'unknown';

  if (sqsShouldFail) {
    operationLog.push({ type: 'sqs_send', messageId });
    throw new Error('SQS send failed (simulated)');
  }

  operationLog.push({
    type: 'sqs_send',
    messageId,
    businessId: body.businessId,
    recipientId: body.recipientId,
  });

  // Track SQS sends per message for exactly-once verification
  if (!sqsMessagesSent.has(messageId)) {
    sqsMessagesSent.set(messageId, []);
  }
  sqsMessagesSent.get(messageId)!.push(body.businessId);

  return { MessageId: `sqs_${messageId}` };
});

// ── Mock setup ───────────────────────────────────────────────────────────────

jest.mock('../../repositories/outbound-message.repository', () => ({
  OutboundMessageRepository: jest.fn().mockImplementation(() => ({
    create: mockCreate,
  })),
}));

jest.mock('../../repositories/delivery-log.repository', () => ({
  DeliveryLogRepository: jest.fn().mockImplementation(() => ({
    create: mockDeliveryLogCreate,
  })),
}));

jest.mock('@aws-sdk/client-sqs', () => ({
  SQSClient: jest.fn().mockImplementation(() => ({
    send: mockSqsSend,
  })),
  SendMessageCommand: jest.fn().mockImplementation((input) => ({ input })),
}));

jest.mock('../../../../config/aws.config', () => ({
  configureAwsClient: jest.fn(() => ({ region: 'us-east-1' })),
}));

jest.mock('../../../../config/environment', () => ({
  config: { aws: { region: 'us-east-1' } },
}));

jest.mock('../../../../utils/logger', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

// Import after mocks are set up
import { DurableEnqueueService, type DurableEnqueueInput } from '../../services/durable-enqueue.service';

// ── Generators ───────────────────────────────────────────────────────────────

const SAFE_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';

const safeIdArb = fc.stringOf(
  fc.constantFrom(...SAFE_CHARS.split('')),
  { minLength: 1, maxLength: 20 },
);

const e164Arb = fc.tuple(
  fc.constantFrom('+'),
  fc.stringOf(fc.constantFrom(...'0123456789'.split('')), { minLength: 8, maxLength: 15 }),
).map(([prefix, digits]) => prefix + digits);

const enqueueInputArb: fc.Arbitrary<DurableEnqueueInput> = fc.record({
  eventId: safeIdArb,
  recipientId: safeIdArb,
  recipientNumber: e164Arb,
  businessId: safeIdArb,
  tenantId: safeIdArb,
  templateId: safeIdArb,
  templateVersion: fc.integer({ min: 1, max: 100 }),
  renderedBody: fc.string({ minLength: 1, maxLength: 200 }),
});

// ── Helpers ──────────────────────────────────────────────────────────────────

function resetState() {
  operationLog = [];
  persistShouldFail = false;
  sqsShouldFail = false;
  persistedMessages.clear();
  sqsMessagesSent.clear();
  mockCreate.mockClear();
  mockDeliveryLogCreate.mockClear();
  mockSqsSend.mockClear();
}

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 28 — Durable persist and exactly-once dispatch', () => {
  let service: DurableEnqueueService;

  beforeEach(() => {
    resetState();
    service = new DurableEnqueueService({
      queueUrl: 'https://sqs.us-east-1.amazonaws.com/123456789/wa-dispatch.fifo',
    });
  });

  describe('1. DynamoDB putItem occurs before SQS send (persist-before-ack)', () => {
    it('for any valid enqueue input, DynamoDB persist always precedes SQS send in the operation log', async () => {
      await fc.assert(
        fc.asyncProperty(
          enqueueInputArb,
          async (input) => {
            resetState();
            service = new DurableEnqueueService({
              queueUrl: 'https://sqs.us-east-1.amazonaws.com/123456789/wa-dispatch.fifo',
            });

            const result = await service.enqueue(input);

            expect(result.success).toBe(true);

            // Find the dynamo_put and sqs_send operations
            const dynamoPutIndex = operationLog.findIndex(
              (op) => op.type === 'dynamo_put',
            );
            const sqsSendIndex = operationLog.findIndex(
              (op) => op.type === 'sqs_send',
            );

            // Both operations must have occurred
            expect(dynamoPutIndex).toBeGreaterThanOrEqual(0);
            expect(sqsSendIndex).toBeGreaterThanOrEqual(0);

            // DynamoDB persist MUST come before SQS send (Req 14.4)
            expect(dynamoPutIndex).toBeLessThan(sqsSendIndex);
          },
        ),
        { numRuns: 100 },
      );
    });

    it('the persisted message has status "queued" and matches input fields', async () => {
      await fc.assert(
        fc.asyncProperty(
          enqueueInputArb,
          async (input) => {
            resetState();
            service = new DurableEnqueueService({
              queueUrl: 'https://sqs.us-east-1.amazonaws.com/123456789/wa-dispatch.fifo',
            });

            const result = await service.enqueue(input);

            expect(result.success).toBe(true);
            expect(result.message).toBeDefined();
            expect(result.message!.status).toBe('queued');
            expect(result.message!.eventId).toBe(input.eventId);
            expect(result.message!.recipientId).toBe(input.recipientId);
            expect(result.message!.recipientNumber).toBe(input.recipientNumber);
            expect(result.message!.businessId).toBe(input.businessId);
            expect(result.message!.tenantId).toBe(input.tenantId);
            expect(result.message!.templateId).toBe(input.templateId);
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('2. On persistence failure, no ack (no SQS send occurs)', () => {
    it('when DynamoDB persist fails, enqueue returns success=false and SQS send is never called', async () => {
      await fc.assert(
        fc.asyncProperty(
          enqueueInputArb,
          async (input) => {
            resetState();
            persistShouldFail = true;
            service = new DurableEnqueueService({
              queueUrl: 'https://sqs.us-east-1.amazonaws.com/123456789/wa-dispatch.fifo',
            });

            const result = await service.enqueue(input);

            // Enqueue is NOT acknowledged (Req 14.7)
            expect(result.success).toBe(false);
            expect(result.error).toBeDefined();
            expect(result.error!.stage).toBe('persist');

            // No SQS send should have occurred
            const sqsSends = operationLog.filter((op) => op.type === 'sqs_send');
            expect(sqsSends).toHaveLength(0);

            // No message is returned
            expect(result.message).toBeUndefined();
          },
        ),
        { numRuns: 100 },
      );
    });

    it('persistence failure does not produce any delivery log entry', async () => {
      await fc.assert(
        fc.asyncProperty(
          enqueueInputArb,
          async (input) => {
            resetState();
            persistShouldFail = true;
            service = new DurableEnqueueService({
              queueUrl: 'https://sqs.us-east-1.amazonaws.com/123456789/wa-dispatch.fifo',
            });

            await service.enqueue(input);

            // No delivery log entry should be created on persistence failure
            const deliveryLogs = operationLog.filter(
              (op) => op.type === 'delivery_log',
            );
            expect(deliveryLogs).toHaveLength(0);
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('3. Each message dispatched exactly once (no duplicate SQS sends)', () => {
    it('for any batch of unique inputs, each message produces exactly one SQS send', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(enqueueInputArb, { minLength: 1, maxLength: 10 }),
          async (inputs) => {
            resetState();
            service = new DurableEnqueueService({
              queueUrl: 'https://sqs.us-east-1.amazonaws.com/123456789/wa-dispatch.fifo',
            });

            const results = await service.enqueueBatch(inputs);

            // All should succeed
            for (const result of results) {
              expect(result.success).toBe(true);
            }

            // Each persisted message should have exactly one SQS send
            const sqsSends = operationLog.filter((op) => op.type === 'sqs_send');
            const dynamoPuts = operationLog.filter((op) => op.type === 'dynamo_put');

            // One SQS send per successful persist (exactly once per message)
            expect(sqsSends.length).toBe(dynamoPuts.length);

            // Verify each message ID appears exactly once in SQS sends
            const sqsMessageIds = sqsSends.map((op) => op.messageId);
            const uniqueSqsIds = new Set(sqsMessageIds);
            expect(uniqueSqsIds.size).toBe(sqsMessageIds.length);
          },
        ),
        { numRuns: 100 },
      );
    });

    it('for any single enqueue, exactly one DynamoDB persist and one SQS send occur', async () => {
      await fc.assert(
        fc.asyncProperty(
          enqueueInputArb,
          async (input) => {
            resetState();
            service = new DurableEnqueueService({
              queueUrl: 'https://sqs.us-east-1.amazonaws.com/123456789/wa-dispatch.fifo',
            });

            const result = await service.enqueue(input);

            expect(result.success).toBe(true);

            // Exactly one persist
            const dynamoPuts = operationLog.filter(
              (op) => op.type === 'dynamo_put',
            );
            expect(dynamoPuts).toHaveLength(1);

            // Exactly one SQS send
            const sqsSends = operationLog.filter(
              (op) => op.type === 'sqs_send',
            );
            expect(sqsSends).toHaveLength(1);

            // The SQS send references the same message that was persisted
            expect(sqsSends[0].messageId).toBe(dynamoPuts[0].messageId);
          },
        ),
        { numRuns: 100 },
      );
    });

    it('SQS failure after persist still acknowledges success (durability guaranteed)', async () => {
      await fc.assert(
        fc.asyncProperty(
          enqueueInputArb,
          async (input) => {
            resetState();
            sqsShouldFail = true;
            service = new DurableEnqueueService({
              queueUrl: 'https://sqs.us-east-1.amazonaws.com/123456789/wa-dispatch.fifo',
            });

            const result = await service.enqueue(input);

            // Success is still true because the message is durably persisted (Req 14.4)
            // The sweeper will pick it up later
            expect(result.success).toBe(true);
            expect(result.message).toBeDefined();

            // DynamoDB persist DID occur
            const dynamoPuts = operationLog.filter(
              (op) => op.type === 'dynamo_put',
            );
            expect(dynamoPuts).toHaveLength(1);

            // SQS was attempted but failed — error stage is recorded
            expect(result.error).toBeDefined();
            expect(result.error!.stage).toBe('sqs');
          },
        ),
        { numRuns: 100 },
      );
    });

    it('batch halts on first persistence failure — no subsequent messages are sent to SQS', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(enqueueInputArb, { minLength: 2, maxLength: 6 }),
          fc.integer({ min: 0, max: 4 }),
          async (inputs, failIndex) => {
            resetState();
            const actualFailIndex = Math.min(failIndex, inputs.length - 1);
            let callCount = 0;

            // Override mock to fail on a specific call
            mockCreate.mockImplementation(
              async (_tenantId: string, _businessId: string, data: Record<string, unknown>) => {
                const currentCall = callCount++;
                if (currentCall === actualFailIndex) {
                  operationLog.push({ type: 'dynamo_put', businessId: _businessId });
                  throw new Error('DynamoDB persistence failed (simulated)');
                }

                const id = `msg_${currentCall}_${Math.random().toString(36).slice(2, 10)}`;
                const now = new Date().toISOString();
                const message = {
                  id,
                  businessId: _businessId,
                  tenantId: _tenantId,
                  eventId: data.eventId,
                  recipientId: data.recipientId,
                  recipientNumber: data.recipientNumber,
                  templateId: data.templateId,
                  templateVersion: data.templateVersion,
                  renderedBody: data.renderedBody,
                  mediaUrl: data.mediaUrl,
                  branchId: data.branchId,
                  status: 'queued',
                  attempts: 0,
                  expiresAt: data.expiresAt,
                  createdAt: now,
                  updatedAt: now,
                };

                operationLog.push({
                  type: 'dynamo_put',
                  messageId: id,
                  businessId: _businessId,
                  recipientId: data.recipientId as string,
                });
                return message;
              },
            );

            service = new DurableEnqueueService({
              queueUrl: 'https://sqs.us-east-1.amazonaws.com/123456789/wa-dispatch.fifo',
            });

            const results = await service.enqueueBatch(inputs);

            // Results up to the failure point: succeeded ones are before failIndex
            const succeededResults = results.filter((r) => r.success);
            const failedResults = results.filter((r) => !r.success);

            expect(succeededResults.length).toBe(actualFailIndex);
            expect(failedResults.length).toBe(1);

            // Batch halts — no results for inputs after the failed one
            expect(results.length).toBe(actualFailIndex + 1);

            // SQS sends match only the successful persists (exactly once per success)
            const sqsSends = operationLog.filter((op) => op.type === 'sqs_send');
            expect(sqsSends.length).toBe(actualFailIndex);
          },
        ),
        { numRuns: 100 },
      );
    });
  });
});
