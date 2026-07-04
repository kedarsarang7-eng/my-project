// ============================================================================
// WhatsApp Module — OpenWA Status Webhook Handler (Task 12.3)
// ============================================================================
// Receives delivery/read (`message.ack`) event callbacks from the OpenWA
// gateway. Corrected against OpenWA's actual webhook contract (verified from
// source, not just docs — see Dukan_x/OpenWA/src/modules/session/session.service.ts
// and webhook.service.ts):
//
// - OpenWA wraps EVERY delivery in an envelope:
//     { event, timestamp, sessionId, idempotencyKey, deliveryId, data }
//   The status fields we care about live under `data`, not at the payload root.
// - OpenWA has no tenant/business concept: the envelope carries `sessionId`
//   ONLY — never a `tenantId`/`businessId`. We resolve the owning business
//   server-side via the session registry; we do NOT trust any businessId a
//   caller might smuggle into the body.
// - The `data.messageId` for a `message.ack` event is OpenWA's own WhatsApp
//   message id, which is what we stored as `OutboundMessage.providerMessageId`
//   at dispatch time — NOT our internal OutboundMessage.id.
// - The relevant event is `message.ack`, carrying `data.status` (canonical:
//   pending|sent|delivered|read|failed) and the deprecated `data.ack` integer.
//   A distinct `message.failed` event is also dispatched for status "failed";
//   we treat both the same way since `data.status` is authoritative either way.
//
// SECURITY-FIRST PROCESSING ORDER:
// 1. HMAC-SHA256 signature verification (constant-time) — BEFORE any processing
// 2. On mismatch: reject immediately, record Audit_Log rejection, return 401
// 3. On valid signature: parse envelope, resolve sessionId -> business via the
//    registry, resolve the matching OutboundMessage by providerMessageId,
//    check for duplicate status events, update Delivery_Log within 5s
//
// CRITICAL CONTRACTS:
// - NEVER fabricate a delivered/read status (Req 8.6, 15.4)
// - Only record statuses actually reported by OpenWA
// - Ignore duplicate status events (same state already recorded for the message)
// - Webhook secret + sessionId are per-tenant, retrieved via OpenWAConfigResolver
// - This is a PUBLIC route — no Cognito auth, signature-only trust
//
// Requirements: 8.4, 8.5, 8.6, 8.9, 10.4, 10.5, 15.4
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { verifyOpenWAWebhookSignature } from '../../staff/services/staff-notify.service';
import { createSecretStoreConfigResolver } from '../services/whatsapp-dispatch.service';
import { resolveBusinessBySessionId } from '../services/openwa-session-registry.service';
import { DeliveryLogRepository } from '../repositories/delivery-log.repository';
import { OutboundMessageRepository } from '../repositories/outbound-message.repository';
import { WaAuditService } from '../services/wa-audit.service';
import { logger } from '../../../utils/logger';
import * as response from '../../../utils/response';
import type { OutboundMessageStatus, DeliveryLogState } from '../schemas/entities';
import type { OpenWAConfigResolver } from '../../staff/services/staff-notify.service';

// ── Constants ─────────────────────────────────────────────────────────────────

/**
 * The HTTP header carrying the HMAC-SHA256 signature from OpenWA.
 * Format: `sha256=<hex>` — we strip the prefix before verification.
 */
const SIGNATURE_HEADER = 'x-openwa-signature';

/**
 * Canonical delivery statuses OpenWA can report on `data.status` for a
 * `message.ack` / `message.failed` event. These are the ONLY states we
 * accept from the webhook — anything else is rejected (never fabricated,
 * Req 8.6). Matches OpenWA's `DeliveryStatus` type exactly.
 */
const VALID_WEBHOOK_STATUSES = ['pending', 'sent', 'delivered', 'read', 'failed'] as const;
type WebhookStatus = (typeof VALID_WEBHOOK_STATUSES)[number];

/** OpenWA event names this handler processes; anything else is acknowledged and ignored. */
const HANDLED_EVENTS = ['message.ack', 'message.failed'] as const;

// ── Zod Schema for OpenWA's real webhook envelope ────────────────────────────

const webhookEnvelopeSchema = z.object({
  event: z.string().trim().min(1),
  timestamp: z.string().trim().min(1),
  /** OpenWA's session identifier — the ONLY tenancy hint OpenWA sends. */
  sessionId: z.string().trim().min(1).max(128),
  idempotencyKey: z.string().trim().min(1).optional(),
  deliveryId: z.string().trim().min(1).optional(),
  data: z.object({
    /** OpenWA's own WhatsApp message id — matches OutboundMessage.providerMessageId. */
    messageId: z.string().trim().min(1).max(256),
    status: z.enum(VALID_WEBHOOK_STATUSES),
    /** Deprecated legacy integer ack code, kept for logging only. */
    ack: z.number().optional(),
  }).passthrough(),
});

type WebhookEnvelope = z.infer<typeof webhookEnvelopeSchema>;

// ── Instances ─────────────────────────────────────────────────────────────────

const deliveryLogRepo = new DeliveryLogRepository();
const outboundMessageRepo = new OutboundMessageRepository();
const auditService = new WaAuditService();
const configResolver: OpenWAConfigResolver = createSecretStoreConfigResolver();

// ── Exported Handler ──────────────────────────────────────────────────────────

/**
 * Lambda handler for OpenWA status webhooks.
 *
 * This is a PUBLIC route — authentication is via HMAC-SHA256 signature only.
 * No Cognito token is required or expected.
 *
 * Processing order:
 * 1. Extract raw body and signature header; parse the envelope enough to read `sessionId`
 * 2. Resolve sessionId -> (tenantId, businessId) via the session registry
 *    (NEVER trust a client-supplied tenantId/businessId — OpenWA doesn't send one)
 * 3. Verify HMAC-SHA256 signature using that business's webhook secret (FIRST — before any
 *    business-logic processing of the event data)
 * 4. Validate the full envelope; ignore event types we don't handle
 * 5. Resolve the matching OutboundMessage by providerMessageId (OpenWA's own message id)
 * 6. Check for duplicate status (skip if already recorded)
 * 7. Update Delivery_Log with the reported status
 */
export async function webhookHandler(
  event: APIGatewayProxyEventV2,
  _context: Context,
): Promise<APIGatewayProxyResultV2> {
  const startTime = Date.now();

  // ── Step 1: Extract raw body and signature ──────────────────────────────
  const rawBody = event.body ?? '';
  if (!rawBody) {
    logger.warn('[WebhookHandler] Empty body received');
    return response.error(400, 'EMPTY_BODY', 'Request body is required');
  }

  const signatureHeader = event.headers?.[SIGNATURE_HEADER]
    ?? event.headers?.['X-OpenWA-Signature']
    ?? '';

  if (!signatureHeader) {
    logger.warn('[WebhookHandler] Missing signature header');
    await recordRejection('unknown', 'unknown', 'missing_signature', {
      reason: 'X-OpenWA-Signature header is absent',
      sourceIp: event.requestContext?.http?.sourceIp ?? 'unknown',
    });
    return response.error(401, 'SIGNATURE_MISSING', 'X-OpenWA-Signature header is required');
  }

  // Strip the `sha256=` prefix if present (OpenWA format)
  const signature = signatureHeader.startsWith('sha256=')
    ? signatureHeader.slice(7)
    : signatureHeader;

  // ── Step 2: Resolve sessionId -> business, server-side only ─────────────
  // OpenWA's envelope carries `sessionId` ONLY — it has no tenant/business
  // concept and sends no businessId/tenantId. We must never trust a
  // client-supplied value for these; resolve strictly through our own
  // sessionId -> business registry (populated at credential-provisioning time).
  let sessionId: string;
  try {
    const parsed = JSON.parse(rawBody);
    sessionId = typeof parsed?.sessionId === 'string' ? parsed.sessionId : '';
    if (!sessionId) {
      logger.warn('[WebhookHandler] Payload missing sessionId');
      await recordRejection('unknown', 'unknown', 'missing_session_id', {
        reason: 'Webhook envelope does not contain sessionId',
        sourceIp: event.requestContext?.http?.sourceIp ?? 'unknown',
      });
      return response.error(400, 'MISSING_SESSION_ID', 'Payload must include sessionId');
    }
  } catch {
    logger.warn('[WebhookHandler] Payload is not valid JSON');
    await recordRejection('unknown', 'unknown', 'invalid_json', {
      reason: 'Webhook body is not valid JSON',
      sourceIp: event.requestContext?.http?.sourceIp ?? 'unknown',
    });
    return response.error(400, 'INVALID_JSON', 'Request body is not valid JSON');
  }

  const owner = await resolveBusinessBySessionId(sessionId);
  if (!owner) {
    logger.warn('[WebhookHandler] No business provisioned for this OpenWA sessionId — ignoring', { sessionId });
    await recordRejection('unknown', 'unknown', 'unknown_session', {
      reason: `No business is registered for OpenWA sessionId '${sessionId}'`,
      sourceIp: event.requestContext?.http?.sourceIp ?? 'unknown',
    });
    // Unknown session: acknowledge without processing rather than reject, since the
    // signature has not been checked yet and we have no secret to check it against.
    return response.success({ acknowledged: true, action: 'ignored_unknown_session' });
  }
  const { tenantId, businessId } = owner;

  // Resolve THIS business's webhook secret (and sessionId, for cross-check) from the secret store.
  const gatewayConfig = await configResolver(tenantId);
  if (!gatewayConfig) {
    logger.error('[WebhookHandler] Cannot resolve webhook secret for tenant', { tenantId, sessionId });
    await recordRejection(tenantId, businessId, 'secret_unavailable', {
      reason: 'Webhook secret could not be resolved for this tenant',
      sourceIp: event.requestContext?.http?.sourceIp ?? 'unknown',
    });
    return response.error(401, 'SECRET_UNAVAILABLE', 'Cannot verify webhook signature');
  }

  // Defense-in-depth: the resolved credential's own sessionId must match the
  // envelope's sessionId. A mismatch means the registry and the secret store
  // have drifted, or something is spoofing a session id — reject either way.
  if (gatewayConfig.sessionId !== sessionId) {
    logger.error('[WebhookHandler] sessionId mismatch between registry and credential store', {
      tenantId,
      businessId,
      envelopeSessionId: sessionId,
      credentialSessionId: gatewayConfig.sessionId,
    });
    await recordRejection(tenantId, businessId, 'session_mismatch', {
      reason: 'Envelope sessionId does not match the provisioned credential sessionId',
      sourceIp: event.requestContext?.http?.sourceIp ?? 'unknown',
    });
    return response.error(401, 'SESSION_MISMATCH', 'Session identity mismatch');
  }

  // ── Step 3: HMAC-SHA256 Signature Verification (Req 8.4, 8.5, 10.4, 10.5) ─
  // This MUST happen BEFORE any business-logic processing of the event data.
  // Uses constant-time comparison (crypto.timingSafeEqual) to prevent timing attacks.
  const isValid = verifyOpenWAWebhookSignature(rawBody, signature, gatewayConfig.webhookSecret);

  if (!isValid) {
    // REJECT: signature mismatch — do NOT process payload (Req 8.5, 10.5)
    logger.warn('[WebhookHandler] HMAC-SHA256 signature verification FAILED', {
      tenantId,
      businessId,
      sessionId,
      sourceIp: event.requestContext?.http?.sourceIp,
    });

    // Record Audit_Log rejection entry (Req 8.5)
    await recordRejection(tenantId, businessId, 'hmac_mismatch', {
      reason: 'HMAC-SHA256 signature does not match the expected value',
      sourceIp: event.requestContext?.http?.sourceIp ?? 'unknown',
    });

    return response.error(401, 'SIGNATURE_INVALID', 'Webhook signature verification failed');
  }

  // ── Step 4: Parse and validate the full webhook envelope ─────────────────
  let envelope: WebhookEnvelope;
  try {
    const parsed = JSON.parse(rawBody);
    envelope = webhookEnvelopeSchema.parse(parsed);
  } catch (err) {
    logger.warn('[WebhookHandler] Invalid webhook envelope after signature verification', {
      tenantId,
      businessId,
      error: err instanceof Error ? err.message : String(err),
    });
    return response.error(400, 'INVALID_PAYLOAD', 'Webhook payload does not conform to expected schema');
  }

  // Ignore event types we don't act on (session.*, message.received, message.reaction, etc.)
  if (!HANDLED_EVENTS.includes(envelope.event as (typeof HANDLED_EVENTS)[number])) {
    logger.debug('[WebhookHandler] Unhandled event type — acknowledging without action', {
      tenantId,
      businessId,
      event: envelope.event,
    });
    return response.success({ acknowledged: true, action: 'ignored_unhandled_event' });
  }

  const providerMessageId = envelope.data.messageId;
  const reportedStatus = envelope.data.status;

  // ── Step 5: Resolve the matching OutboundMessage by providerMessageId ───
  // OpenWA's own message id (envelope.data.messageId) is what we stored as
  // OutboundMessage.providerMessageId at dispatch time — NOT our record id.
  const outboundMessage = await outboundMessageRepo.findByProviderMessageId(
    tenantId,
    businessId,
    providerMessageId,
  );

  if (!outboundMessage) {
    // Unknown message — could be from a manually sent message or stale webhook.
    // Log and acknowledge (don't reject; the signature was valid).
    logger.info('[WebhookHandler] No matching OutboundMessage found — ignoring', {
      tenantId,
      businessId,
      providerMessageId,
      status: reportedStatus,
    });
    return response.success({ acknowledged: true, action: 'ignored_unknown_message' });
  }

  // ── Step 6: Duplicate detection (Req 8.9) ──────────────────────────────
  // If the message is already in the reported state (or a later state), ignore.
  if (isDuplicateOrStaleStatus(outboundMessage.status, reportedStatus)) {
    logger.info('[WebhookHandler] Duplicate/stale status event — ignoring', {
      tenantId,
      businessId,
      messageId: outboundMessage.id,
      currentStatus: outboundMessage.status,
      reportedStatus,
    });
    return response.success({ acknowledged: true, action: 'duplicate_ignored' });
  }

  // "pending" and "sent" are not terminal/advancing states we act on via this
  // webhook path (dispatch already sets "sent"); only advance on delivered/read/failed.
  if (reportedStatus === 'pending' || reportedStatus === 'sent') {
    return response.success({ acknowledged: true, action: 'no_op_status' });
  }

  // ── Step 7: Update OutboundMessage status and append Delivery_Log ───────
  // Must complete within 5 seconds of webhook receipt (Req 8.4).
  const mappedStatus = mapWebhookStatusToOutboundStatus(reportedStatus);
  const failureReason = reportedStatus === 'failed'
    ? `OpenWA reported delivery failure (event: ${envelope.event}, ack: ${envelope.data.ack ?? 'n/a'})`
    : undefined;

  await outboundMessageRepo.updateStatus(
    tenantId,
    businessId,
    outboundMessage.id,
    mappedStatus,
    reportedStatus === 'failed' ? { lastError: failureReason } : undefined,
  );

  // Append a Delivery_Log entry (append-only, Req 8.3)
  await deliveryLogRepo.create(tenantId, businessId, {
    outboundMessageId: outboundMessage.id,
    state: mapWebhookStatusToDeliveryLogState(reportedStatus),
    reason: failureReason,
  });

  const elapsed = Date.now() - startTime;
  logger.info('[WebhookHandler] Status update processed', {
    tenantId,
    businessId,
    messageId: outboundMessage.id,
    newStatus: mappedStatus,
    elapsedMs: elapsed,
  });

  return response.success({
    acknowledged: true,
    action: 'status_updated',
    messageId: outboundMessage.id,
    newStatus: mappedStatus,
  });
}

// ── Helper Functions ──────────────────────────────────────────────────────────

/**
 * Determines if a reported status is a duplicate or stale transition.
 *
 * The lifecycle order is: queued → sent → delivered → read → (failed/expired terminal)
 * A status is considered duplicate/stale if:
 * - The current status equals the reported status (exact duplicate)
 * - The current status is later in the lifecycle than the reported status
 * - The current status is already terminal (failed/expired)
 *
 * This prevents backward transitions and duplicate processing (Req 8.9).
 */
function isDuplicateOrStaleStatus(
  currentStatus: OutboundMessageStatus,
  reportedStatus: WebhookStatus,
): boolean {
  // Terminal states: no further transitions allowed
  if (currentStatus === 'failed' || currentStatus === 'expired') {
    return true;
  }

  // Same status = exact duplicate
  if (currentStatus === reportedStatus) {
    return true;
  }

  // Define lifecycle order (higher = later in lifecycle)
  const order: Record<string, number> = {
    pending: 0,
    queued: 0,
    sent: 1,
    delivered: 2,
    read: 3,
    failed: 4,
    expired: 4,
  };

  const currentOrder = order[currentStatus] ?? -1;
  const reportedOrder = order[reportedStatus] ?? -1;

  // If current is already at or past the reported status, it's stale
  return currentOrder >= reportedOrder;
}

/**
 * Map a webhook-reported status to the OutboundMessage status enum.
 * Only maps statuses actually reported by OpenWA — never fabricates (Req 8.6, 15.4).
 * Callers only invoke this for delivered/read/failed (pending/sent are handled
 * as a no-op earlier), but the switch is exhaustive over the full wire type.
 */
function mapWebhookStatusToOutboundStatus(webhookStatus: WebhookStatus): OutboundMessageStatus {
  switch (webhookStatus) {
    case 'pending': return 'queued';
    case 'sent': return 'sent';
    case 'delivered': return 'delivered';
    case 'read': return 'read';
    case 'failed': return 'failed';
    default:
      // Exhaustive check — never fabricate
      return webhookStatus satisfies never;
  }
}

/**
 * Map a webhook-reported status to the DeliveryLog state enum.
 * Only maps statuses actually reported by OpenWA (Req 8.6, 15.4).
 */
function mapWebhookStatusToDeliveryLogState(webhookStatus: WebhookStatus): DeliveryLogState {
  switch (webhookStatus) {
    case 'pending': return 'queued';
    case 'sent': return 'sent';
    case 'delivered': return 'delivered';
    case 'read': return 'read';
    case 'failed': return 'failed';
    default:
      return webhookStatus satisfies never;
  }
}

/**
 * Records an Audit_Log entry for a webhook rejection (Req 8.5).
 *
 * Fire-and-forget — if the audit write fails, we still reject the webhook
 * (security comes first), but we log the audit failure for operational visibility.
 */
async function recordRejection(
  tenantId: string,
  businessId: string,
  reason: string,
  meta: { reason: string; sourceIp: string },
): Promise<void> {
  try {
    await auditService.recordWebhookRejection(
      {
        tenantId: tenantId || 'unknown',
        businessId: businessId || 'unknown',
        actor: 'system:webhook_verifier',
      },
      {
        source: meta.sourceIp,
        reason,
        requestMeta: { detailedReason: meta.reason },
      },
    );
  } catch (err) {
    // Audit write failed — log but don't break the rejection flow.
    // The webhook is still rejected (security is never compromised for audit).
    logger.error('[WebhookHandler] Failed to write audit rejection entry', {
      tenantId,
      businessId,
      reason,
      error: err instanceof Error ? err.message : String(err),
    });
  }
}
