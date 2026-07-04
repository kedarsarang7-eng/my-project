// ============================================================================
// WhatsApp Automation — Dispatcher Lambda (Task 11.4)
// ============================================================================
// SQS FIFO-triggered worker that drains the dispatch queue at the configured
// rate limit, dispatches messages through the canonical OpenWA gateway, and
// handles retries/expiry/verification.
//
// TRIGGER: SQS FIFO queue (WA_DISPATCH_QUEUE_URL)
//
// DESIGN CONTRACTS:
// - Claims messages under the SQS visibility timeout; if the worker dies before
//   recording a terminal state, the message returns to the queue for reprocessing
//   without duplication (Req 14.5, 14.6).
// - Rate-limits dispatch to the configured gateway rate (per-tenant, from
//   manifest.rateLimits). Excess messages are NOT deleted from the queue —
//   they remain for the next invocation interval (Req 14.3).
// - Per-recipient ordering is preserved by SQS FIFO MessageGroupId
//   (businessId#recipientId) — messages in the same group are delivered
//   in order (Req 9.2).
// - Expired messages are detected before dispatch and marked expired without
//   sending (Req 9.4).
// - Before dispatch: verifies recipient identity via recipient-verification
//   service. On verification failure: STOPS delivery, logs reason, and notifies
//   operator (Req 16.1–16.6).
// - Exactly-once dispatch via idempotent status transitions: a message already
//   in a terminal state (sent/failed/expired) is acknowledged without re-dispatch.
// - Transient failures: apply retry policy (schedule next attempt, return to queue).
// - Permanent failures: immediately mark failed.
// - Success: update status to 'sent', log delivery entry.
//
// Requirements: 9.2, 9.5, 14.3, 14.5, 14.6
// ============================================================================

import { logger } from '../../../utils/logger';
import {
  WhatsAppDispatchService,
  createWhatsAppDispatchService,
  type DispatchResult,
} from '../services/whatsapp-dispatch.service';
import {
  nextAttempt,
  isMessageExpired,
  createRetryPolicy,
  type RetryPolicy,
  type DispatchAttemptState,
} from '../services/retry-policy.service';
import {
  verifyRecipient,
  extractVerificationInput,
  type RecipientVerificationResult,
} from '../services/recipient-verification.service';
import { OperatorAlertService, ALERT_CATEGORIES } from '../services/operator-alert.service';
import { OutboundMessageRepository } from '../repositories/outbound-message.repository';
import { DeliveryLogRepository } from '../repositories/delivery-log.repository';
import { CustomerProfileRepository } from '../repositories/customer-profile.repository';
import type { OutboundMessage, OutboundMessageStatus, CustomerProfile } from '../schemas/entities';
import { whatsappManifest } from '../manifest';
import { PlanTier } from '../../../config/plan-feature-registry';

// ── Types ─────────────────────────────────────────────────────────────────────

/**
 * SQS event delivered to the Lambda by the FIFO trigger.
 * Standard AWS SQS event envelope.
 */
interface SQSEvent {
  Records: SQSRecord[];
}

interface SQSRecord {
  messageId: string;
  receiptHandle: string;
  body: string;
  attributes: {
    ApproximateReceiveCount?: string;
    SentTimestamp?: string;
    MessageGroupId?: string;
    MessageDeduplicationId?: string;
    [key: string]: string | undefined;
  };
  messageAttributes: Record<string, { stringValue?: string; dataType?: string }>;
  md5OfBody: string;
  eventSource: string;
  eventSourceARN: string;
  awsRegion: string;
}

/**
 * The SQS message body schema for dispatch queue messages.
 * Written by durable-enqueue.service.ts.
 */
interface DispatchQueueMessage {
  outboundMessageId: string;
  businessId: string;
  tenantId: string;
  recipientId: string;
  recipientNumber: string;
  eventId: string;
  /** The category of the automation (for recipient verification context). */
  category?: string;
  /** Document type for document automations (triggers recipient verification). */
  documentType?: string;
}

/**
 * Batch item failure response for partial batch failure reporting.
 * Allows SQS to only retry the failed messages.
 */
interface SQSBatchResponse {
  batchItemFailures: Array<{ itemIdentifier: string }>;
}

/** Terminal statuses where re-dispatch is never allowed. */
const TERMINAL_STATUSES: ReadonlySet<OutboundMessageStatus> = new Set<OutboundMessageStatus>([
  'sent',
  'delivered',
  'read',
  'failed',
  'expired',
]);

/** Document automation categories that require recipient verification. */
const DOCUMENT_AUTOMATION_TYPES: ReadonlySet<string> = new Set([
  'invoice',
  'receipt',
  'quotation',
  'estimate',
  'order_confirmation',
  'credit_note',
  'debit_note',
  'payment_confirmation',
  'refund_confirmation',
  'purchase_order',
  'delivery_challan',
]);

// ── Service Instances ─────────────────────────────────────────────────────────

const outboundMessageRepo = new OutboundMessageRepository();
const deliveryLogRepo = new DeliveryLogRepository();
const customerProfileRepo = new CustomerProfileRepository();
const dispatchService: WhatsAppDispatchService = createWhatsAppDispatchService();
const operatorAlertService = new OperatorAlertService();

// ── Rate Limit Configuration ──────────────────────────────────────────────────

/**
 * Resolves the rate limit (messages per minute) for a given tenant tier.
 * Falls back to BASIC tier if the tier is unrecognized.
 */
function resolveRateLimit(tier?: string): number {
  const rateLimits = whatsappManifest.rateLimits as unknown as Record<string, number>;
  if (tier && rateLimits[tier]) {
    return rateLimits[tier];
  }
  return rateLimits[PlanTier.BASIC] || 100;
}

/**
 * Computes how many messages can be dispatched in this invocation interval.
 * Since the Lambda is triggered per-batch by SQS, the effective throttle is:
 * the batch size is capped by the configured rate limit for the invocation window.
 *
 * The SQS batch size is typically configured to match or stay under the rate limit.
 * However, if more messages arrive in a batch than the rate allows, we process
 * only up to the limit and report the excess as batch item failures so SQS
 * retains them for the next interval.
 */
function computeDispatchBudget(batchSize: number, rateLimit: number): number {
  // Rate limit is per minute. A Lambda invocation processes one batch.
  // We allow the full rate limit per invocation since the SQS trigger
  // frequency is managed by AWS to stay within the concurrent execution model.
  // If the batch is smaller than the budget, we process all of them.
  return Math.min(batchSize, rateLimit);
}

// ── Lambda Handler ────────────────────────────────────────────────────────────

/**
 * Main Lambda handler for the whatsappDispatcher.
 *
 * Triggered by SQS FIFO queue. Processes each message in the batch:
 * 1. Parse the dispatch queue message
 * 2. Fetch the OutboundMessage from DynamoDB (source of truth)
 * 3. Check for terminal status (exactly-once: skip if already terminal)
 * 4. Check for expiry (mark expired, do NOT dispatch)
 * 5. Verify recipient identity (for document automations)
 * 6. Dispatch via WhatsAppDispatchService
 * 7. Handle result: success → sent, transient → retry, permanent → failed
 *
 * Uses partial batch failure reporting: messages that fail processing are
 * reported back so SQS only retries those specific messages.
 */
export async function handler(event: SQSEvent): Promise<SQSBatchResponse> {
  const records = event.Records || [];
  const batchItemFailures: Array<{ itemIdentifier: string }> = [];

  if (records.length === 0) {
    return { batchItemFailures };
  }

  // Determine rate limit from the first record's tenant context.
  // In FIFO SQS with a single queue, all messages share the same gateway limit.
  const firstMessage = safeParseBody(records[0].body);
  const tier = firstMessage?.tier;
  const rateLimit = resolveRateLimit(tier);
  const budget = computeDispatchBudget(records.length, rateLimit);

  logger.info('[WhatsAppDispatcher] Processing batch', {
    batchSize: records.length,
    rateLimit,
    budget,
  });

  // Process records up to the budget. Excess records are reported as failures
  // so SQS retains them for the next polling interval (Req 14.3).
  for (let i = 0; i < records.length; i++) {
    const record = records[i];

    // Rate limiting: if we've exceeded the budget, retain the rest
    if (i >= budget) {
      batchItemFailures.push({ itemIdentifier: record.messageId });
      continue;
    }

    try {
      const outcome = await processRecord(record);

      if (outcome === 'retry') {
        // Return to queue for reprocessing (visibility timeout will re-deliver)
        batchItemFailures.push({ itemIdentifier: record.messageId });
      }
      // 'success' and 'skipped' both mean the message is acknowledged (deleted from queue)
    } catch (err) {
      // Unhandled error: return to queue (Req 14.6 — worker failure returns message)
      logger.error('[WhatsAppDispatcher] Unhandled error processing record', {
        sqsMessageId: record.messageId,
        error: err instanceof Error ? err.message : String(err),
      });
      batchItemFailures.push({ itemIdentifier: record.messageId });
    }
  }

  logger.info('[WhatsAppDispatcher] Batch complete', {
    total: records.length,
    processed: records.length - batchItemFailures.length,
    retried: batchItemFailures.length,
  });

  return { batchItemFailures };
}

// ── Record Processing ─────────────────────────────────────────────────────────

type RecordOutcome = 'success' | 'skipped' | 'retry';

/**
 * Processes a single SQS record through the full dispatch pipeline.
 *
 * Returns:
 * - 'success': message dispatched and status updated (ack from queue)
 * - 'skipped': message already in terminal state or expired (ack from queue)
 * - 'retry': transient failure, return to queue for later attempt
 */
async function processRecord(record: SQSRecord): Promise<RecordOutcome> {
  // ── Step 1: Parse the message body ──────────────────────────────────
  const queueMsg = safeParseBody(record.body);
  if (!queueMsg) {
    logger.error('[WhatsAppDispatcher] Malformed SQS message body — discarding', {
      sqsMessageId: record.messageId,
      body: record.body?.slice(0, 200),
    });
    // Malformed messages can never succeed; acknowledge to prevent infinite retry
    return 'skipped';
  }

  const { outboundMessageId, businessId, tenantId, recipientId } = queueMsg;

  // ── Step 2: Fetch the OutboundMessage (source of truth) ─────────────
  const message = await outboundMessageRepo.get(tenantId, businessId, outboundMessageId);
  if (!message) {
    logger.warn('[WhatsAppDispatcher] OutboundMessage not found — discarding', {
      outboundMessageId,
      businessId,
      tenantId,
    });
    // Message was likely deleted or never persisted; acknowledge
    return 'skipped';
  }

  // ── Step 3: Exactly-once check — skip if already in terminal state ──
  if (TERMINAL_STATUSES.has(message.status)) {
    logger.info('[WhatsAppDispatcher] Message already in terminal state — skipping', {
      outboundMessageId,
      businessId,
      status: message.status,
    });
    return 'skipped';
  }

  // ── Step 4: Expiry check — expired messages are NEVER dispatched ────
  const now = new Date().toISOString();
  const retryPolicy = createRetryPolicy({
    expirySeconds: message.expiresAt
      ? Math.max(60, Math.floor((Date.parse(message.expiresAt) - Date.parse(message.createdAt)) / 1000))
      : undefined,
  });

  const expiryState: DispatchAttemptState = {
    attempts: message.attempts,
    errorCode: '',
    enqueuedAt: message.createdAt,
    now,
    expiresAt: message.expiresAt,
  };

  if (isMessageExpired(expiryState, retryPolicy)) {
    logger.info('[WhatsAppDispatcher] Message expired — marking as expired', {
      outboundMessageId,
      businessId,
      createdAt: message.createdAt,
      expiresAt: message.expiresAt,
    });
    await markExpired(message, tenantId, businessId);
    return 'skipped';
  }

  // ── Step 5: Recipient verification (for document automations) ───────
  if (requiresRecipientVerification(queueMsg)) {
    const verificationOutcome = await performRecipientVerification(
      message,
      queueMsg,
      tenantId,
      businessId,
    );
    if (verificationOutcome === 'blocked') {
      return 'skipped'; // Delivery blocked, operator alerted
    }
    if (verificationOutcome === 'retry') {
      return 'retry'; // Transient failure fetching profiles
    }
  }

  // ── Step 6: Dispatch via WhatsAppDispatchService ────────────────────
  const dispatchResult = await dispatchService.sendMessage({
    tenantId,
    businessId,
    to: message.recipientNumber,
    templateName: message.templateId,
    params: { body: message.renderedBody },
    mediaUrl: message.mediaUrl,
  });

  // ── Step 7: Handle dispatch result ──────────────────────────────────
  if (dispatchResult.success) {
    return handleSuccess(message, tenantId, businessId, dispatchResult);
  }

  // Credential unavailable: retain in pre-dispatch state, retry later (Req 12.6)
  if (dispatchResult.credentialUnavailable) {
    logger.warn('[WhatsAppDispatcher] Credentials unavailable — retrying later', {
      outboundMessageId,
      businessId,
    });
    return 'retry';
  }

  // Apply retry policy to classify the failure
  return handleFailure(message, tenantId, businessId, dispatchResult, retryPolicy);
}

// ── Success Handling ──────────────────────────────────────────────────────────

/**
 * Handle a successful dispatch: update OutboundMessage status to 'sent'
 * and append a delivery log entry.
 */
async function handleSuccess(
  message: OutboundMessage,
  tenantId: string,
  businessId: string,
  result: DispatchResult,
): Promise<RecordOutcome> {
  try {
    await outboundMessageRepo.updateStatus(tenantId, businessId, message.id, 'sent', {
      attempts: message.attempts + 1,
      providerMessageId: result.providerMessageId,
    });

    await safeLogDelivery(tenantId, businessId, message.id, 'sent');

    logger.info('[WhatsAppDispatcher] Message dispatched successfully', {
      outboundMessageId: message.id,
      businessId,
      providerMessageId: result.providerMessageId,
    });
  } catch (err) {
    // Status update failed after successful dispatch. The message was sent but
    // we couldn't record it. Next time it's picked up, the exactly-once check
    // should handle it (or the webhook will set delivered/read).
    logger.error('[WhatsAppDispatcher] Failed to update status after successful dispatch', {
      outboundMessageId: message.id,
      businessId,
      error: err instanceof Error ? err.message : String(err),
    });
  }

  return 'success';
}

// ── Failure Handling ──────────────────────────────────────────────────────────

/**
 * Handle a failed dispatch by applying the retry policy:
 * - Permanent error → immediately mark failed
 * - Transient error with retries remaining → schedule retry (return to queue)
 * - Max attempts exhausted → mark failed
 * - Expired → mark expired
 */
async function handleFailure(
  message: OutboundMessage,
  tenantId: string,
  businessId: string,
  result: DispatchResult,
  policy: RetryPolicy,
): Promise<RecordOutcome> {
  const now = new Date().toISOString();
  const errorCode = result.errorCode || 'UNKNOWN_ERROR';

  const attemptState: DispatchAttemptState = {
    attempts: message.attempts + 1, // this attempt counts
    errorCode,
    enqueuedAt: message.createdAt,
    now,
    expiresAt: message.expiresAt,
  };

  const decision = nextAttempt(attemptState, policy);

  switch (decision.action) {
    case 'retry': {
      // Update attempt count and next retry time, then return to queue
      await outboundMessageRepo.updateStatus(tenantId, businessId, message.id, 'queued', {
        attempts: message.attempts + 1,
        lastError: result.errorMessage?.slice(0, 1000),
        nextAttemptAt: decision.retryAt,
      });

      logger.info('[WhatsAppDispatcher] Transient failure — scheduling retry', {
        outboundMessageId: message.id,
        businessId,
        errorCode,
        attempts: message.attempts + 1,
        retryAt: decision.retryAt,
        reason: decision.reason,
      });

      return 'retry';
    }

    case 'failed': {
      await outboundMessageRepo.updateStatus(tenantId, businessId, message.id, 'failed', {
        attempts: message.attempts + 1,
        lastError: result.errorMessage?.slice(0, 1000),
      });

      await safeLogDelivery(
        tenantId,
        businessId,
        message.id,
        'failed',
        decision.reason,
      );

      logger.info('[WhatsAppDispatcher] Permanent failure — marked failed', {
        outboundMessageId: message.id,
        businessId,
        errorCode,
        reason: decision.reason,
      });

      return 'success'; // Acknowledge from queue — no more retries
    }

    case 'expired': {
      await markExpired(message, tenantId, businessId);
      return 'skipped';
    }

    default:
      return 'retry';
  }
}

// ── Expiry Handling ───────────────────────────────────────────────────────────

/**
 * Mark a message as expired in both the OutboundMessage and the Delivery_Log.
 */
async function markExpired(
  message: OutboundMessage,
  tenantId: string,
  businessId: string,
): Promise<void> {
  try {
    await outboundMessageRepo.updateStatus(tenantId, businessId, message.id, 'expired', {
      lastError: 'Message expired before dispatch',
    });
    await safeLogDelivery(tenantId, businessId, message.id, 'expired', 'Message expired before dispatch');
  } catch (err) {
    logger.error('[WhatsAppDispatcher] Failed to mark message as expired', {
      outboundMessageId: message.id,
      businessId,
      error: err instanceof Error ? err.message : String(err),
    });
  }
}

// ── Recipient Verification ────────────────────────────────────────────────────

/**
 * Determines whether a message requires recipient verification before dispatch.
 * Document automations (invoices, receipts, etc.) MUST verify the recipient
 * identity to prevent wrong-recipient delivery (Req 16.1–16.6).
 */
function requiresRecipientVerification(queueMsg: DispatchQueueMessage): boolean {
  if (!queueMsg.documentType) return false;
  return DOCUMENT_AUTOMATION_TYPES.has(queueMsg.documentType.toLowerCase());
}

/**
 * Perform recipient verification for a document automation.
 * On failure: blocks delivery, logs reason, and raises an Operator_Alert.
 *
 * Returns:
 * - 'ok': verification passed, proceed with dispatch
 * - 'blocked': verification failed, delivery stopped
 * - 'retry': transient error fetching profiles, try again later
 */
async function performRecipientVerification(
  message: OutboundMessage,
  queueMsg: DispatchQueueMessage,
  tenantId: string,
  businessId: string,
): Promise<'ok' | 'blocked' | 'retry'> {
  // Fetch customer profiles for the business (needed for verification)
  let profiles: Map<string, CustomerProfile>;
  try {
    const profilesList = await customerProfileRepo.list(tenantId, businessId);
    profiles = new Map(profilesList.map((p) => [p.id, p]));
  } catch (err) {
    logger.error('[WhatsAppDispatcher] Failed to fetch profiles for verification', {
      outboundMessageId: message.id,
      businessId,
      error: err instanceof Error ? err.message : String(err),
    });
    return 'retry';
  }

  // Build verification input
  const verificationInput = extractVerificationInput(
    message.recipientId,
    businessId,
    { customerNumber: message.recipientNumber },
  );

  // Run the pure verification function
  const result: RecipientVerificationResult = verifyRecipient(verificationInput, profiles);

  if (result.verified) {
    // Verification passed — the stored number matches the message's target
    return 'ok';
  }

  // Verification FAILED — STOP delivery (Req 16.2, 16.3)
  logger.error('[WhatsAppDispatcher] Recipient verification failed — blocking dispatch', {
    outboundMessageId: message.id,
    businessId,
    recipientId: message.recipientId,
    failureType: result.failureType,
    reason: result.reason,
  });

  // Mark message as failed
  await outboundMessageRepo.updateStatus(tenantId, businessId, message.id, 'failed', {
    attempts: message.attempts,
    lastError: `Recipient verification failed: ${result.reason}`.slice(0, 1000),
  });

  // Log delivery failure
  await safeLogDelivery(
    tenantId,
    businessId,
    message.id,
    'failed',
    `Recipient verification failed: ${result.reason}`,
  );

  // Raise Operator Alert (Req 16.6)
  try {
    await operatorAlertService.raiseOperatorAlert({
      eventId: message.eventId,
      businessId,
      tenantId,
      documentType: queueMsg.documentType || 'unknown',
      customerId: message.recipientId,
      category: mapVerificationFailureToAlertCategory(result.failureType),
      reason: result.reason,
      details: {
        storedPhoneNumber: message.recipientNumber,
      },
    });
  } catch (alertErr) {
    // Alert dispatch failure is non-fatal — the delivery is already blocked
    logger.error('[WhatsAppDispatcher] Failed to raise operator alert', {
      outboundMessageId: message.id,
      businessId,
      error: alertErr instanceof Error ? alertErr.message : String(alertErr),
    });
  }

  return 'blocked';
}

/**
 * Maps a recipient verification failure type to an operator alert category.
 */
function mapVerificationFailureToAlertCategory(
  failureType: string,
): typeof ALERT_CATEGORIES[keyof typeof ALERT_CATEGORIES] {
  switch (failureType) {
    case 'NUMBER_MISMATCH':
      return ALERT_CATEGORIES.PHONE_NUMBER_CHANGED;
    case 'PROFILE_DELETED':
      return ALERT_CATEGORIES.PROFILE_DELETED;
    case 'PROFILE_NOT_FOUND':
    case 'MULTIPLE_PROFILES':
    case 'MISSING_CUSTOMER_ID':
    case 'MISSING_BUSINESS_ID':
      return ALERT_CATEGORIES.RECIPIENT_MISMATCH;
    case 'INVALID_STORED_NUMBER':
    case 'INVALID_EVENT_NUMBER':
      return ALERT_CATEGORIES.PHONE_NUMBER_CHANGED;
    default:
      return ALERT_CATEGORIES.RECIPIENT_MISMATCH;
  }
}

// ── Delivery Log Helpers ──────────────────────────────────────────────────────

/**
 * Safely write a delivery log entry. Non-fatal on failure.
 */
async function safeLogDelivery(
  tenantId: string,
  businessId: string,
  outboundMessageId: string,
  state: 'sent' | 'failed' | 'expired',
  reason?: string,
): Promise<void> {
  try {
    await deliveryLogRepo.create(tenantId, businessId, {
      outboundMessageId,
      state,
      reason,
    });
  } catch (err) {
    logger.warn('[WhatsAppDispatcher] Failed to write delivery log entry', {
      outboundMessageId,
      state,
      error: err instanceof Error ? err.message : String(err),
    });
  }
}

// ── Message Parsing ───────────────────────────────────────────────────────────

/**
 * Safely parse the SQS message body. Returns null on malformed input.
 */
function safeParseBody(body: string): (DispatchQueueMessage & { tier?: string }) | null {
  try {
    const parsed = JSON.parse(body);
    if (
      !parsed ||
      typeof parsed !== 'object' ||
      !parsed.outboundMessageId ||
      !parsed.businessId ||
      !parsed.tenantId
    ) {
      return null;
    }
    return parsed as DispatchQueueMessage & { tier?: string };
  } catch {
    return null;
  }
}
