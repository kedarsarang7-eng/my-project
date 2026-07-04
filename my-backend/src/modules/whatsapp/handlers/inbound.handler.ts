// ============================================================================
// WhatsApp Module — Inbound Message Handler (Task 15.1)
// ============================================================================
// Handles inbound WhatsApp messages from customers. Responsibilities:
//
// 1. Opt-out keyword detection: routes recognized opt-out keywords to the
//    consent service, which transitions the customer to opted_out (Req 2.6)
// 2. AI Responder dispatch: when the WA_AI_RESPONDER flag is ON, forwards
//    the message to the AI responder for automated reply generation
// 3. Graceful failure: on AI failure, sends NOTHING to the customer, logs
//    the reason, and leaves the message for manual handling (Req 11.12)
//
// CRITICAL BEHAVIOR:
// - Opt-out keywords are ALWAYS checked first, regardless of AI flag state
// - When AI is disabled (flag OFF): no AI content is generated/sent/stored
// - When AI fails: no response is sent, message is left for manual handling
// - Never fabricates content
//
// Requirements: 2.6, 11.10, 11.12, 15.2, 15.3, 15.6
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { ValidationError, AuthError } from '../../../utils/errors';
import { buildTenantContext } from '../../../dynamodb/tenant-guard';
import { logger } from '../../../utils/logger';
import { FeatureKey, PlanTier } from '../../../config/plan-feature-registry';
import { isOptOutKeyword, detectOptOutKeyword } from '../services/consent.service';
import { CustomerProfileRepository } from '../repositories/customer-profile.repository';
import { WaAuditService } from '../services/wa-audit.service';
import {
  AiResponderService,
  createAiResponderService,
  type AiResponderResult,
} from '../services/ai-responder.service';
import { WhatsAppDispatchService, createWhatsAppDispatchService } from '../services/whatsapp-dispatch.service';

// ── Constants ─────────────────────────────────────────────────────────────────

/** Roles allowed to receive inbound webhook events. */
const ALLOWED_ROLES: UserRole[] = [
  UserRole.OWNER,
  UserRole.ADMIN,
  UserRole.MANAGER,
  UserRole.STAFF,
];

/** The WA_CORE feature key gates basic inbound message handling. */
const REQUIRED_FEATURE = FeatureKey.WA_CORE;

// ── Zod Schema for Inbound Message ───────────────────────────────────────────

const inboundMessageSchema = z.object({
  /** The inbound message unique ID from the WhatsApp provider. */
  messageId: z.string().trim().min(1).max(256),
  /** The sender's phone number (E.164). */
  from: z.string().trim().min(1).max(20),
  /** The message text content. */
  text: z.string().min(0).max(10_000),
  /** Timestamp of when the message was received (ISO-8601). */
  timestamp: z.string().trim().min(1).optional(),
  /** Optional: customer identifier if already resolved. */
  customerId: z.string().trim().min(1).max(128).optional(),
});

type InboundMessage = z.infer<typeof inboundMessageSchema>;

// ── Instances ─────────────────────────────────────────────────────────────────

const customerRepo = new CustomerProfileRepository();
const auditService = new WaAuditService();
const aiResponder: AiResponderService = createAiResponderService();
const dispatchService: WhatsAppDispatchService = createWhatsAppDispatchService();

// ── Result Types ──────────────────────────────────────────────────────────────

/** The outcome of processing an inbound message. */
export interface InboundProcessingResult {
  /** What action was taken. */
  action: 'opt_out_processed' | 'ai_response_sent' | 'ai_unavailable' | 'ai_failed' | 'no_action';
  /** Details about the processing outcome. */
  detail?: string;
}

// ── Main Handler ──────────────────────────────────────────────────────────────

/**
 * Lambda handler for inbound WhatsApp messages.
 *
 * This handler is typically invoked by the webhook receiver or an EventBridge
 * event when a customer sends a message to the business.
 *
 * Processing order:
 * 1. Opt-out keyword detection (ALWAYS checked first, Req 2.6)
 * 2. AI responder dispatch (only when flag is ON, Req 11.10)
 * 3. On any AI failure → no message sent, logged, left for manual handling (Req 11.12)
 */
export const inboundHandler = authorizedHandler(
  ALLOWED_ROLES,
  async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
    auth: AuthContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const { tenantId, businessId } = await resolveInboundTenantScope(event, auth);

    // Parse and validate the inbound message payload
    const body = parseJsonBody(event);
    const message = inboundMessageSchema.parse(body);

    // Resolve plan tier for feature flag checks
    const planTier = resolvePlanTier(auth);

    // Process the inbound message
    const result = await processInboundMessage(tenantId, businessId, message, planTier);

    return response.success(result);
  },
  { requiredFeature: REQUIRED_FEATURE },
);

// ── Core Processing Logic ────────────────────────────────────────────────────

/**
 * Processes an inbound message through the consent and AI pipeline.
 *
 * @param tenantId   - The authenticated tenant
 * @param businessId - The authenticated business
 * @param message    - The parsed inbound message
 * @param planTier   - The business's plan tier (for feature flag evaluation)
 * @returns Processing result indicating what action was taken
 */
export async function processInboundMessage(
  tenantId: string,
  businessId: string,
  message: InboundMessage,
  planTier: PlanTier,
): Promise<InboundProcessingResult> {
  // ── Step 1: Opt-out keyword detection (ALWAYS runs first, Req 2.6) ─────
  const optOutResult = await handleOptOutDetection(tenantId, businessId, message);
  if (optOutResult) {
    return optOutResult;
  }

  // ── Step 2: AI Responder dispatch (Req 11.10, 15.2, 15.3, 15.6) ────────
  const aiResult = await handleAiResponder(tenantId, businessId, message, planTier);
  return aiResult;
}

// ── Opt-Out Keyword Handling (Req 2.6) ───────────────────────────────────────

/**
 * Checks if the inbound message is an opt-out keyword.
 * If it is, transitions the customer's consent state to opted_out.
 *
 * Returns a processing result if opt-out was detected, or null to continue
 * to the next processing step.
 *
 * The consent transition must complete within 60 seconds of message receipt (Req 2.6).
 */
async function handleOptOutDetection(
  tenantId: string,
  businessId: string,
  message: InboundMessage,
): Promise<InboundProcessingResult | null> {
  // Only check if there is text content
  if (!message.text || message.text.trim().length === 0) {
    return null;
  }

  // Detect opt-out keyword (case-insensitive, whitespace-trimmed)
  const keyword = detectOptOutKeyword(message.text);
  if (!keyword) {
    return null;
  }

  // Opt-out keyword detected — transition customer to opted_out
  logger.info('[InboundHandler] Opt-out keyword detected', {
    businessId,
    tenantId,
    from: message.from,
    keyword,
  });

  try {
    // Resolve the customer profile by phone number
    const customer = await customerRepo.findByWhatsappNumber(tenantId, businessId, message.from);

    if (!customer) {
      logger.warn('[InboundHandler] Opt-out received but no customer profile found', {
        businessId,
        tenantId,
        from: message.from,
        keyword,
      });
      return {
        action: 'opt_out_processed',
        detail: `Opt-out keyword "${keyword}" received but no customer profile found for ${message.from}`,
      };
    }

    // Only transition if not already opted_out
    if (customer.consentState === 'opted_out') {
      return {
        action: 'opt_out_processed',
        detail: `Customer already opted out; keyword "${keyword}" acknowledged`,
      };
    }

    // Transition consent to opted_out
    const previousState = customer.consentState;
    await customerRepo.setConsentState(tenantId, businessId, customer.id, 'opted_out');

    // Record audit entry (Req 2.7)
    await auditService.recordConsentChange(
      { tenantId, businessId, actor: 'system:opt_out_keyword' },
      {
        customerId: customer.id,
        previousState,
        newState: 'opted_out',
        source: `opt_out_keyword:${keyword}`,
      },
    );

    logger.info('[InboundHandler] Customer opted out via keyword', {
      businessId,
      tenantId,
      customerId: customer.id,
      keyword,
      previousState,
    });

    return {
      action: 'opt_out_processed',
      detail: `Customer ${customer.id} consent changed from ${previousState} to opted_out via keyword "${keyword}"`,
    };
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);
    logger.error('[InboundHandler] Error processing opt-out keyword', {
      businessId,
      tenantId,
      from: message.from,
      keyword,
      error: reason,
    });

    // Even on error, we report the opt-out was detected (fail-open for consent)
    return {
      action: 'opt_out_processed',
      detail: `Opt-out keyword "${keyword}" detected but consent update failed: ${reason}`,
    };
  }
}

// ── AI Responder Handling (Req 11.10, 11.12, 15.2, 15.3, 15.6) ──────────────

/**
 * Attempts AI response generation for the inbound message.
 *
 * CRITICAL BEHAVIOR:
 * - When the feature flag is OFF → returns `ai_unavailable`, NO content generated
 * - When the provider fails → sends NOTHING, logs the failure, leaves for manual
 * - When successful → dispatches the AI response to the customer
 */
async function handleAiResponder(
  tenantId: string,
  businessId: string,
  message: InboundMessage,
  planTier: PlanTier,
): Promise<InboundProcessingResult> {
  // Call the AI responder service (handles flag check internally)
  const aiResult: AiResponderResult = await aiResponder.generateResponse(planTier, {
    tenantId,
    businessId,
    customerId: message.customerId ?? message.from,
    messageText: message.text,
  });

  switch (aiResult.status) {
    case 'unavailable':
      // Feature flag is OFF — no AI content generated/sent/stored (Req 15.3, 15.6)
      return {
        action: 'ai_unavailable',
        detail: 'AI responder is disabled for this business tier',
      };

    case 'failure':
      // AI failed — send NOTHING, log the reason, leave for manual (Req 11.12)
      logger.warn('[InboundHandler] AI response failed — message left for manual handling', {
        businessId,
        tenantId,
        from: message.from,
        customerId: message.customerId,
        failureReason: aiResult.failureReason,
      });
      return {
        action: 'ai_failed',
        detail: `AI provider failed: ${aiResult.failureReason}; message left for manual handling`,
      };

    case 'success':
      // AI generated a response — dispatch it to the customer
      return await dispatchAiResponse(tenantId, businessId, message, aiResult.responseText!);

    default:
      return { action: 'no_action' };
  }
}

/**
 * Dispatches the AI-generated response to the customer via WhatsApp.
 *
 * If dispatch fails, the failure is logged but no error is thrown —
 * the message is left for manual handling (Req 11.12).
 */
async function dispatchAiResponse(
  tenantId: string,
  businessId: string,
  message: InboundMessage,
  responseText: string,
): Promise<InboundProcessingResult> {
  try {
    const dispatchResult = await dispatchService.sendMessage({
      tenantId,
      businessId,
      to: message.from,
      templateName: '__ai_response__',
      params: { text: responseText },
    });

    if (dispatchResult.success) {
      logger.info('[InboundHandler] AI response dispatched successfully', {
        businessId,
        tenantId,
        to: message.from,
        providerMessageId: dispatchResult.providerMessageId,
      });
      return {
        action: 'ai_response_sent',
        detail: `AI response dispatched to ${message.from}`,
      };
    }

    // Dispatch failed — send NOTHING, log the reason, leave for manual (Req 11.12)
    logger.error('[InboundHandler] AI response dispatch failed — message left for manual handling', {
      businessId,
      tenantId,
      to: message.from,
      errorCode: dispatchResult.errorCode,
      errorMessage: dispatchResult.errorMessage,
    });
    return {
      action: 'ai_failed',
      detail: `AI response generated but dispatch failed: ${dispatchResult.errorMessage}; message left for manual handling`,
    };
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);
    logger.error('[InboundHandler] Unexpected error dispatching AI response', {
      businessId,
      tenantId,
      to: message.from,
      error: reason,
    });
    return {
      action: 'ai_failed',
      detail: `AI response generated but dispatch threw: ${reason}; message left for manual handling`,
    };
  }
}

// ── Tenant Scope Resolution (Req 12.4) ──────────────────────────────────────

/**
 * Resolve the BusinessID exclusively from the authenticated session.
 * SECURITY (Req 12.4): BusinessID is NEVER taken from client-supplied input.
 */
async function resolveInboundTenantScope(
  event: APIGatewayProxyEventV2,
  auth: AuthContext,
): Promise<{ tenantId: string; businessId: string }> {
  const businessId =
    event.headers?.['x-active-business'] ||
    event.headers?.['x-business-id'] ||
    event.headers?.['X-Business-Id'] ||
    event.headers?.['x-shop-id'] ||
    '';

  if (!businessId || businessId.trim() === '') {
    throw new AuthError('Authenticated business context is required');
  }

  const scope = await buildTenantContext(auth, businessId);

  return {
    tenantId: scope.tenantContext.tenantId,
    businessId: scope.tenantContext.businessId,
  };
}

// ── Helper Functions ─────────────────────────────────────────────────────────

/**
 * Resolve the plan tier from the auth context.
 * Defaults to BASIC if not available (most restrictive — AI flag OFF).
 */
function resolvePlanTier(auth: AuthContext): PlanTier {
  const tier = auth.planTier as string | undefined;
  if (tier && Object.values(PlanTier).includes(tier as PlanTier)) {
    return tier as PlanTier;
  }
  return PlanTier.BASIC;
}

function parseJsonBody(event: APIGatewayProxyEventV2): Record<string, unknown> {
  if (!event.body) {
    throw new ValidationError('Request body is required');
  }
  try {
    const parsed = JSON.parse(event.body) as unknown;
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      throw new ValidationError('Request body must be a JSON object');
    }
    return parsed as Record<string, unknown>;
  } catch (err) {
    if (err instanceof ValidationError) throw err;
    throw new ValidationError('Request body is not valid JSON');
  }
}
