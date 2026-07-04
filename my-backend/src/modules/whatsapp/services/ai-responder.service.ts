// ============================================================================
// WhatsApp Automation Module — AI Responder Service (Task 15.1)
// ============================================================================
// Flag-gated AI response generation for inbound customer messages.
//
// DESIGN CONTRACTS:
// - Gated by `WA_AI_RESPONDER` feature flag (OFF by default via plan-feature-registry)
// - When DISABLED: returns `{ status: 'unavailable' }` and NEVER generates,
//   sends, stores, or returns any AI content (Req 15.3, 15.6)
// - When ENABLED: calls the real AI provider with a 30-second deadline
// - On AI failure (timeout, error, empty response): sends NOTHING, logs the
//   reason, and leaves the message for manual handling (Req 11.12)
// - Never fabricates content — if the provider fails, no response is produced
//
// Requirements: 11.10, 11.12, 15.2, 15.3, 15.6
// Design: AD-6 (AI_Responder is flag-gated and real)
// ============================================================================

import { logger } from '../../../utils/logger';
import { FeatureKey, PLAN_CORE_FEATURES, PlanTier } from '../../../config/plan-feature-registry';

// ── Constants ────────────────────────────────────────────────────────────────

/** The feature flag that gates AI responder functionality. */
export const AI_RESPONDER_FEATURE_KEY = FeatureKey.WA_AI_RESPONDER;

/** Maximum time (ms) to wait for the AI provider to respond. */
export const AI_PROVIDER_TIMEOUT_MS = 30_000;

/** Environment variable for the AI provider endpoint. */
const AI_PROVIDER_URL_ENV = 'WA_AI_PROVIDER_URL';

/** Environment variable for the AI provider API key. */
const AI_PROVIDER_KEY_ENV = 'WA_AI_PROVIDER_KEY';

// ── Types ────────────────────────────────────────────────────────────────────

/** Result status of an AI response attempt. */
export type AiResponderStatus =
  | 'unavailable'   // Feature flag is OFF — no AI content produced
  | 'success'       // AI provider returned a valid response
  | 'failure';      // AI provider failed — no content sent, message left for manual handling

/** Result from the AI responder service. */
export interface AiResponderResult {
  /** The status of the response attempt. */
  status: AiResponderStatus;
  /** The AI-generated response text (only present when status === 'success'). */
  responseText?: string;
  /** Error reason (only present when status === 'failure'). */
  failureReason?: string;
}

/** Input for generating an AI response. */
export interface AiResponderInput {
  /** The tenant context. */
  tenantId: string;
  /** The sending business. */
  businessId: string;
  /** The customer who sent the inbound message. */
  customerId: string;
  /** The inbound message text to respond to. */
  messageText: string;
  /** Optional conversation context (previous messages). */
  conversationContext?: string[];
}

/** Configuration for the AI provider. */
export interface AiProviderConfig {
  /** The provider endpoint URL. */
  url: string;
  /** The provider API key. */
  apiKey: string;
}

// ── Feature Flag Check ───────────────────────────────────────────────────────

/**
 * Checks whether the AI responder feature flag is enabled for the given plan tier.
 *
 * The WA_AI_RESPONDER feature key is only granted at the Enterprise tier.
 * When not granted, the AI responder is effectively OFF (Req 15.2, 15.3).
 *
 * @param planTier - The business's subscription tier
 * @returns true if the AI responder is enabled for this tier
 */
export function isAiResponderEnabled(planTier: PlanTier): boolean {
  const grantedFeatures = PLAN_CORE_FEATURES[planTier] ?? [];
  return grantedFeatures.includes(AI_RESPONDER_FEATURE_KEY);
}

// ── AI Provider Config Resolution ────────────────────────────────────────────

/**
 * Resolves AI provider configuration from environment variables.
 * Returns null if the provider is not configured (no URL or key).
 */
export function resolveAiProviderConfig(): AiProviderConfig | null {
  const url = process.env[AI_PROVIDER_URL_ENV];
  const apiKey = process.env[AI_PROVIDER_KEY_ENV];

  if (!url || !apiKey) {
    return null;
  }

  return { url, apiKey };
}

// ── AI Responder Service ─────────────────────────────────────────────────────

export interface AiResponderServiceOptions {
  /** Override the AI provider config (for testing). */
  providerConfig?: AiProviderConfig | null;
  /** Override the timeout (for testing). */
  timeoutMs?: number;
}

/**
 * AI Responder Service — generates automated replies to inbound customer messages.
 *
 * CRITICAL BEHAVIOR:
 * - When the feature flag is OFF → returns `{ status: 'unavailable' }` immediately.
 *   No AI content is generated, sent, stored, or returned (Req 15.3, 15.6).
 * - When the feature flag is ON → calls the real AI provider with a 30s deadline.
 * - On any AI failure → sends NOTHING, logs the failure, leaves the message
 *   for manual handling (Req 11.12).
 * - Never fabricates content.
 */
export class AiResponderService {
  private readonly providerConfig: AiProviderConfig | null;
  private readonly timeoutMs: number;

  constructor(options: AiResponderServiceOptions = {}) {
    this.providerConfig =
      options.providerConfig !== undefined
        ? options.providerConfig
        : resolveAiProviderConfig();
    this.timeoutMs = options.timeoutMs ?? AI_PROVIDER_TIMEOUT_MS;
  }

  /**
   * Attempt to generate an AI response for an inbound customer message.
   *
   * @param planTier - The business's subscription tier (for feature flag check)
   * @param input    - The inbound message details
   * @returns AiResponderResult indicating the outcome
   */
  async generateResponse(
    planTier: PlanTier,
    input: AiResponderInput,
  ): Promise<AiResponderResult> {
    // ── Gate 1: Feature flag check (Req 15.2, 15.3, 15.6) ───────────────
    if (!isAiResponderEnabled(planTier)) {
      // Feature is OFF — return unavailable, generate/send/store NOTHING
      return { status: 'unavailable' };
    }

    // ── Gate 2: Provider configuration check ─────────────────────────────
    if (!this.providerConfig) {
      logger.warn('[AiResponder] AI provider not configured — treating as unavailable', {
        businessId: input.businessId,
        tenantId: input.tenantId,
      });
      return { status: 'unavailable' };
    }

    // ── Call the real AI provider with a 30s deadline (Req 11.10) ─────────
    try {
      const responseText = await this.callProvider(input);

      // Validate the response — never return empty/null content
      if (!responseText || responseText.trim().length === 0) {
        logger.warn('[AiResponder] AI provider returned empty response', {
          businessId: input.businessId,
          tenantId: input.tenantId,
          customerId: input.customerId,
        });
        return {
          status: 'failure',
          failureReason: 'AI provider returned empty response',
        };
      }

      logger.info('[AiResponder] AI response generated successfully', {
        businessId: input.businessId,
        tenantId: input.tenantId,
        customerId: input.customerId,
        responseLength: responseText.length,
      });

      return {
        status: 'success',
        responseText,
      };
    } catch (error) {
      // ── On failure: send NOTHING, log the reason, leave for manual (Req 11.12) ──
      const failureReason = error instanceof Error ? error.message : String(error);

      logger.error('[AiResponder] AI provider call failed — message left for manual handling', {
        businessId: input.businessId,
        tenantId: input.tenantId,
        customerId: input.customerId,
        failureReason,
      });

      return {
        status: 'failure',
        failureReason,
      };
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ──────────────────────────────────────────────────────────────────────────

  /**
   * Call the real AI provider with a deadline.
   * Uses AbortController for timeout enforcement (30s default).
   *
   * @throws Error if the provider times out, returns a non-2xx, or network fails.
   */
  private async callProvider(input: AiResponderInput): Promise<string> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const requestBody = JSON.stringify({
        businessId: input.businessId,
        customerId: input.customerId,
        message: input.messageText,
        conversationContext: input.conversationContext ?? [],
      });

      const response = await fetch(this.providerConfig!.url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.providerConfig!.apiKey}`,
        },
        body: requestBody,
        signal: controller.signal,
      });

      if (!response.ok) {
        const errorBody = await response.text().catch(() => 'unknown');
        throw new Error(
          `AI provider returned HTTP ${response.status}: ${errorBody.slice(0, 200)}`,
        );
      }

      const body = await response.json() as Record<string, unknown>;
      const text = (body?.response ?? body?.text ?? body?.content) as string | undefined;

      if (!text || typeof text !== 'string') {
        throw new Error('AI provider response is missing a text field');
      }

      return text;
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        throw new Error(`AI provider timed out after ${this.timeoutMs}ms`);
      }
      throw error;
    } finally {
      clearTimeout(timeoutId);
    }
  }
}

// ── Factory ──────────────────────────────────────────────────────────────────

/**
 * Create an AiResponderService with the default configuration.
 * Standard factory for handler use.
 */
export function createAiResponderService(
  options?: AiResponderServiceOptions,
): AiResponderService {
  return new AiResponderService(options);
}
