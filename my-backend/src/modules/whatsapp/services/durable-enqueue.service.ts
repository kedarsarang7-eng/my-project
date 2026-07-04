// ============================================================================
// WhatsApp Automation Module — Durable Enqueue Service (Task 11.3)
// ============================================================================
// Bridges the rule engine (which produces OutboundPlans) and the dispatcher
// (which sends messages) by durably persisting each OutboundMessage to
// DynamoDB BEFORE acknowledging enqueue, then sending an SQS FIFO message
// to trigger dispatch.
//
// DURABILITY GUARANTEE (Req 14.4, 14.7):
//   The OutboundMessage item is persisted to DynamoDB BEFORE the enqueue is
//   acknowledged. If DynamoDB persistence fails, the enqueue is NOT
//   acknowledged — the message is retained for retry and the failure is logged.
//
// ORDERING GUARANTEE (Req 9.2):
//   SQS FIFO with MessageGroupId = `${businessId}#${recipientId}` preserves
//   per-recipient enqueue order so messages to the same customer dispatch
//   in the order they were generated.
//
// MESSAGE DEDUPLICATION (Req 9.1):
//   SQS FIFO MessageDeduplicationId = outboundMessageId prevents duplicate
//   SQS messages if enqueue is retried after an SQS send failure.
//
// RECIPIENT NUMBER:
//   The recipientNumber comes from the verified CustomerProfile (already
//   validated upstream by recipient-verification.service.ts), NEVER from
//   raw event data.
//
// Requirements: 9.1, 9.2, 14.4, 14.7
// Design: AD-3 (Durable queue on SQS FIFO + DynamoDB OutboundMessage)
// ============================================================================

import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';
import { configureAwsClient } from '../../../config/aws.config';
import { config } from '../../../config/environment';
import { logger } from '../../../utils/logger';
import {
  OutboundMessageRepository,
  type OutboundMessageCreateInput,
} from '../repositories/outbound-message.repository';
import { DeliveryLogRepository } from '../repositories/delivery-log.repository';
import type { OutboundMessage } from '../schemas/entities';

// ── Types ────────────────────────────────────────────────────────────────────

/**
 * Input for durably enqueuing a single outbound WhatsApp message.
 * All fields are pre-validated by the engine before reaching this service.
 */
export interface DurableEnqueueInput {
  /** Unique event identifier that triggered this message. */
  eventId: string;
  /** Customer profile ID (unique identifier of the recipient). */
  recipientId: string;
  /**
   * E.164 validated phone number from the CustomerProfile.
   * MUST come from the verified stored profile, never from raw event data.
   */
  recipientNumber: string;
  /** The sending business's identifier (session-derived). */
  businessId: string;
  /** The tenant identifier (session-derived). */
  tenantId: string;
  /** Template ID used for rendering. */
  templateId: string;
  /** Exact template version used (for recoverability, Req 7.7). */
  templateVersion: number;
  /** The fully rendered message body (all placeholders resolved). */
  renderedBody: string;
  /** Optional media/document URL to attach. */
  mediaUrl?: string;
  /** Optional branch ID for multi-branch scoping (Req 11.7). */
  branchId?: string;
  /** Optional ISO-8601 UTC expiry timestamp for the message. */
  expiresAt?: string;
}

/**
 * Result of a durable enqueue operation.
 */
export interface DurableEnqueueResult {
  /** Whether the enqueue succeeded (persisted + SQS sent). */
  success: boolean;
  /** The persisted OutboundMessage (when success = true). */
  message?: OutboundMessage;
  /** Error details (when success = false). */
  error?: {
    /** Stage where the failure occurred. */
    stage: 'persist' | 'sqs';
    /** Error message for logging. */
    reason: string;
  };
}

// ── SQS Client (lazy singleton) ─────────────────────────────────────────────

let sqsClient: SQSClient | null = null;

function getSqsClient(): SQSClient {
  if (!sqsClient) {
    sqsClient = new SQSClient(configureAwsClient({ region: config.aws.region }));
  }
  return sqsClient;
}

/**
 * Test-only hook — replaces the SQS client for unit/integration tests.
 * @internal
 */
export function _setSqsClientForTests(client: SQSClient | null): void {
  sqsClient = client;
}

// ── Queue URL Resolution ─────────────────────────────────────────────────────

/**
 * Environment variable for the WhatsApp dispatch queue URL.
 * This is an SQS FIFO queue (.fifo suffix) used exclusively for
 * outbound WhatsApp message dispatch.
 */
const WA_DISPATCH_QUEUE_URL =
  process.env.WA_DISPATCH_QUEUE_URL || '';

// ── Durable Enqueue Service ──────────────────────────────────────────────────

export class DurableEnqueueService {
  private readonly outboundMessageRepo: OutboundMessageRepository;
  private readonly deliveryLogRepo: DeliveryLogRepository;
  private readonly queueUrl: string;

  constructor(options?: {
    outboundMessageRepo?: OutboundMessageRepository;
    deliveryLogRepo?: DeliveryLogRepository;
    queueUrl?: string;
  }) {
    this.outboundMessageRepo = options?.outboundMessageRepo ?? new OutboundMessageRepository();
    this.deliveryLogRepo = options?.deliveryLogRepo ?? new DeliveryLogRepository();
    this.queueUrl = options?.queueUrl ?? WA_DISPATCH_QUEUE_URL;
  }

  /**
   * Durably enqueue a single outbound WhatsApp message.
   *
   * SEQUENCE (Req 14.4, 14.7):
   * 1. Persist the OutboundMessage to DynamoDB with status = 'queued'
   * 2. Record a delivery log entry (state = 'queued')
   * 3. Send an SQS FIFO message to trigger the dispatcher
   *
   * If step 1 fails: enqueue is NOT acknowledged, failure is logged, and the
   * message is retained for retry by the caller.
   *
   * If step 3 fails (SQS send): the DynamoDB record exists (durable) so the
   * scheduler/sweeper can still pick it up; we log the SQS failure but still
   * report success since durability is guaranteed. The dispatcher will
   * eventually process it via the sweeper or a retry of the SQS send.
   *
   * @param input - Pre-validated enqueue input from the engine.
   * @returns Result indicating success or failure with stage info.
   */
  async enqueue(input: DurableEnqueueInput): Promise<DurableEnqueueResult> {
    // ── Step 1: Persist OutboundMessage to DynamoDB (BEFORE acknowledging) ──
    let persistedMessage: OutboundMessage;

    try {
      const createInput: OutboundMessageCreateInput = {
        eventId: input.eventId,
        recipientId: input.recipientId,
        recipientNumber: input.recipientNumber,
        templateId: input.templateId,
        templateVersion: input.templateVersion,
        renderedBody: input.renderedBody,
        mediaUrl: input.mediaUrl,
        branchId: input.branchId,
        expiresAt: input.expiresAt,
      };

      persistedMessage = await this.outboundMessageRepo.create(
        input.tenantId,
        input.businessId,
        createInput,
      );
    } catch (error) {
      // CRITICAL: DynamoDB persistence failed — DO NOT acknowledge enqueue.
      // Retain for retry. Log the failure. (Req 14.4, 14.7)
      const reason = error instanceof Error ? error.message : String(error);
      logger.error('[DurableEnqueue] DynamoDB persistence failed — NOT acknowledging enqueue', {
        eventId: input.eventId,
        recipientId: input.recipientId,
        businessId: input.businessId,
        tenantId: input.tenantId,
        error: reason,
      });

      return {
        success: false,
        error: { stage: 'persist', reason },
      };
    }

    // ── Step 2: Record delivery log entry (state = 'queued') ────────────────
    try {
      await this.deliveryLogRepo.create(input.tenantId, input.businessId, {
        outboundMessageId: persistedMessage.id,
        state: 'queued',
      });
    } catch (logError) {
      // Delivery log write failure is non-fatal: the message IS persisted.
      // Log the issue but proceed with SQS send.
      logger.warn('[DurableEnqueue] Delivery log write failed (non-fatal)', {
        outboundMessageId: persistedMessage.id,
        businessId: input.businessId,
        error: logError instanceof Error ? logError.message : String(logError),
      });
    }

    // ── Step 3: Send SQS FIFO message to trigger dispatcher ─────────────────
    try {
      await this.sendToDispatchQueue(persistedMessage, input.businessId, input.recipientId);
    } catch (sqsError) {
      // SQS send failed — the DynamoDB record is durable, so the message
      // WILL eventually be picked up by the scheduler/sweeper. Log the error
      // but report overall success since durability is guaranteed.
      const reason = sqsError instanceof Error ? sqsError.message : String(sqsError);
      logger.error('[DurableEnqueue] SQS FIFO send failed — message is durable, sweeper will retry', {
        outboundMessageId: persistedMessage.id,
        businessId: input.businessId,
        recipientId: input.recipientId,
        error: reason,
      });

      // Still return success: durability guarantee is met (Req 14.4).
      // The message exists in DynamoDB and will be dispatched by the sweeper.
      return {
        success: true,
        message: persistedMessage,
        error: { stage: 'sqs', reason },
      };
    }

    return {
      success: true,
      message: persistedMessage,
    };
  }

  /**
   * Enqueue multiple messages in sequence. Stops on the first persistence
   * failure and returns partial results so the caller knows which succeeded.
   *
   * @param inputs - Array of enqueue inputs (one per eligible recipient).
   * @returns Array of results in the same order as inputs.
   */
  async enqueueBatch(inputs: DurableEnqueueInput[]): Promise<DurableEnqueueResult[]> {
    const results: DurableEnqueueResult[] = [];

    for (const input of inputs) {
      const result = await this.enqueue(input);
      results.push(result);

      // On persistence failure, stop processing the batch — the caller
      // should retry the failed message and all subsequent ones.
      if (!result.success && result.error?.stage === 'persist') {
        logger.error('[DurableEnqueue] Batch halted on persistence failure', {
          processedCount: results.length,
          totalCount: inputs.length,
          failedEventId: input.eventId,
          failedRecipientId: input.recipientId,
        });
        break;
      }
    }

    return results;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ──────────────────────────────────────────────────────────────────────────

  /**
   * Send an SQS FIFO message to the WhatsApp dispatch queue.
   *
   * - MessageGroupId = `${businessId}#${recipientId}` preserves per-recipient
   *   enqueue order (Req 9.2).
   * - MessageDeduplicationId = outboundMessageId prevents duplicate SQS
   *   messages if this method is retried after a partial failure (Req 9.1).
   */
  private async sendToDispatchQueue(
    message: OutboundMessage,
    businessId: string,
    recipientId: string,
  ): Promise<void> {
    if (!this.queueUrl) {
      throw new Error('WA_DISPATCH_QUEUE_URL is not configured');
    }

    const messageBody = JSON.stringify({
      outboundMessageId: message.id,
      businessId,
      tenantId: message.tenantId,
      recipientId,
      recipientNumber: message.recipientNumber,
      templateId: message.templateId,
      enqueuedAt: message.createdAt,
    });

    const command = new SendMessageCommand({
      QueueUrl: this.queueUrl,
      MessageBody: messageBody,
      // Per-recipient ordering: messages to the same recipient in the same
      // business are dispatched in enqueue order (Req 9.2).
      MessageGroupId: `${businessId}#${recipientId}`,
      // Deduplication: if we retry the SQS send (e.g., after a transient
      // failure), SQS FIFO rejects the duplicate within its 5-minute window.
      MessageDeduplicationId: message.id,
    });

    await getSqsClient().send(command);

    logger.info('[DurableEnqueue] SQS FIFO message sent', {
      outboundMessageId: message.id,
      businessId,
      recipientId,
      messageGroupId: `${businessId}#${recipientId}`,
    });
  }
}

// ── Factory ──────────────────────────────────────────────────────────────────

/**
 * Create a DurableEnqueueService with default dependencies.
 * Standard factory for use in the Automation_Engine Lambda.
 */
export function createDurableEnqueueService(options?: {
  outboundMessageRepo?: OutboundMessageRepository;
  deliveryLogRepo?: DeliveryLogRepository;
  queueUrl?: string;
}): DurableEnqueueService {
  return new DurableEnqueueService(options);
}
