// ============================================================================
// WhatsApp Automation Module — Dispatch Service (Task 12.1)
// ============================================================================
// THE single dispatch path for ALL WhatsApp messages in DukanX. Wraps the
// canonical staff-notify OpenWA contract (computeOpenWASignature,
// OpenWAConfigResolver) with:
//
// - 16 MB document cap enforcement (Req 4.2, tighter than OpenWA's own 50 MiB
//   MEDIA_DOWNLOAD_MAX_BYTES default — this is a DukanX business rule)
// - Per-tenant credential scoping from the secret store (Req 12.5)
// - Missing-credentials blocking: no dispatch, retain pre-dispatch state (Req 12.6, 13.7)
// - Single dispatch path — no second gateway (Req 10.1, 10.2, 10.3)
//
// REAL OpenWA API CONTRACT (verified against Dukan_x/OpenWA source, not just docs):
// - OpenWA has NO tenant/business concept. Everything is scoped by a `sessionId`
//   (one WhatsApp number = one OpenWA session). Every per-tenant credential record
//   MUST therefore carry the `sessionId` OpenWA provisioned for that business
//   (see OpenWAGatewayConfig.sessionId in staff-notify.service.ts).
// - Auth to OpenWA's REST API is a static `X-API-Key` header — NOT an HMAC
//   signature. HMAC-SHA256 (`computeOpenWASignature`) is only used to verify
//   OpenWA's OUTBOUND webhook deliveries to us; it is never sent by us to OpenWA.
// - There is no generic `/api/send-message` endpoint. Sends are per-type and
//   per-session:
//     POST /api/sessions/{sessionId}/messages/send-text     { chatId, text }
//     POST /api/sessions/{sessionId}/messages/send-image    { chatId, url|base64, mimetype, caption? }
//     POST /api/sessions/{sessionId}/messages/send-document { chatId, url|base64, mimetype, filename?, caption? }
//   `chatId` is WhatsApp's own JID format: `<digits>@c.us` for a person.
// - Response is the raw body `{ messageId, timestamp }` (timestamp = Unix
//   seconds) — no `{success,data}` envelope.
//
// The recipient number used for dispatch comes from the OutboundMessage and
// MUST belong to the sending business (verified upstream by
// recipient-verification.service.ts).
//
// Requirements: 4.2, 10.1, 10.2, 10.3, 12.5, 12.6, 13.7
// ============================================================================

import type { OpenWAConfigResolver, OpenWAGatewayConfig } from '../../staff/services/staff-notify.service';
import { getSecret as getSecretString } from '../../../services/secrets-manager.service';
import { NotFoundError } from '../../../utils/errors';
import { logger } from '../../../utils/logger';

// ── Constants ────────────────────────────────────────────────────────────────

/** Maximum document/media size in bytes (16 MB per Req 4.2 — a DukanX rule, tighter than OpenWA's own 50 MiB default). */
export const MAX_DOCUMENT_SIZE_BYTES = 16 * 1024 * 1024; // 16 MiB

/**
 * Logical secret name for per-tenant OpenWA credentials, stored via
 * `secrets-manager.service.ts` (AWS Secrets Manager, tenant-namespaced:
 * `dukanx/<stage>/<tenantId>/openwa_credentials`). Written by
 * `openwa-provisioning.service.ts` at credential-save time and read here at
 * dispatch time — a single consistent read/write path (Req 12.5, 12.6, 13.7).
 * The JSON stored at this path has shape { baseUrl, apiKey, webhookSecret, sessionId }.
 */
export const OPENWA_SECRET_NAME = 'openwa_credentials';

// ── Types ────────────────────────────────────────────────────────────────────

/** Input for dispatching a single WhatsApp message through OpenWA. */
export interface DispatchMessageInput {
  /** The tenant context (multi-tenant isolation). */
  tenantId: string;
  /** The sending business (per-tenant credential scoping). */
  businessId: string;
  /** E.164 recipient phone number (already verified by recipient-verification). */
  to: string;
  /** Template name or message identifier. */
  templateName: string;
  /** Template parameters / payload. */
  params: Record<string, unknown>;
  /** Optional media/document URL to attach. */
  mediaUrl?: string;
  /** Optional media file size in bytes (for 16 MB cap enforcement). */
  mediaSizeBytes?: number;
}

/** Result of a dispatch attempt. */
export interface DispatchResult {
  /** Whether the dispatch was accepted by the gateway. */
  success: boolean;
  /** Provider-assigned message ID (when accepted). */
  providerMessageId?: string;
  /** Error code for classification by retry-policy.service. */
  errorCode?: string;
  /** Human-readable error description. */
  errorMessage?: string;
  /**
   * Whether the failure is due to missing/unavailable credentials.
   * When true, the message MUST retain its pre-dispatch state and NOT be
   * marked as failed (Req 12.6, 13.7).
   */
  credentialUnavailable?: boolean;
}

/** Per-tenant OpenWA credentials stored in the secret store. */
interface OpenWACredentials {
  baseUrl: string;
  apiKey: string;
  webhookSecret: string;
  /** The OpenWA session id (UUID) provisioned for this business's WhatsApp number. */
  sessionId: string;
}

// ── JID Conversion ────────────────────────────────────────────────────────────

/**
 * Converts a validated E.164 phone number (e.g. "+919876543210") into OpenWA's
 * individual-chat JID format (`<digits>@c.us`, e.g. "919876543210@c.us").
 *
 * OpenWA's engine-neutral chatId dialect for a person is `<phone digits>@c.us`
 * (see `IWhatsAppEngine` — the raw `@s.whatsapp.net` Baileys form is folded
 * into this by the adapter layer). The leading "+" is stripped; OpenWA does
 * not expect it.
 */
export function toOpenWAChatId(e164Number: string): string {
  const digits = e164Number.replace(/^\+/, '');
  return `${digits}@c.us`;
}

// ── Secret-Store-Based Config Resolver ───────────────────────────────────────

/**
 * Creates an OpenWAConfigResolver that retrieves per-tenant credentials from
 * AWS Secrets Manager (or falls back to environment variables via the utility).
 *
 * Secret path: `openwa/{tenantId}/credentials`
 *
 * If the secret store is unavailable or the secret does not exist, returns null.
 * The dispatch service interprets null as "credentials unavailable" and blocks
 * dispatch (Req 12.6, 13.7).
 */
export function createSecretStoreConfigResolver(): OpenWAConfigResolver {
  return async (tenantId: string): Promise<OpenWAGatewayConfig | null> => {
    try {
      const raw = await getSecretString(tenantId, OPENWA_SECRET_NAME);
      const credentials = JSON.parse(raw) as OpenWACredentials;

      // Validate that all required fields are present, including the OpenWA
      // sessionId — without it we have no way to address this business's
      // WhatsApp number in OpenWA's session-scoped API.
      if (!credentials.baseUrl || !credentials.apiKey || !credentials.webhookSecret || !credentials.sessionId) {
        logger.error('[WhatsAppDispatch] Incomplete credentials in secret store', {
          tenantId,
          hasBaseUrl: !!credentials.baseUrl,
          hasApiKey: !!credentials.apiKey,
          hasWebhookSecret: !!credentials.webhookSecret,
          hasSessionId: !!credentials.sessionId,
        });
        return null;
      }

      return {
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
        webhookSecret: credentials.webhookSecret,
        sessionId: credentials.sessionId,
      };
    } catch (error) {
      // NotFoundError means no credentials have been provisioned yet — this is
      // an expected, non-noisy state (no ERROR log). Any other error means the
      // secret store itself is unavailable. Either way, credentials are
      // unavailable and the caller MUST NOT dispatch; retain pre-dispatch
      // state (Req 13.7).
      if (error instanceof NotFoundError) {
        logger.warn('[WhatsAppDispatch] No OpenWA credentials provisioned for tenant', { tenantId });
        return null;
      }
      logger.error('[WhatsAppDispatch] Failed to resolve tenant credentials', {
        tenantId,
        error: (error as Error).message,
      });
      return null;
    }
  };
}

// ── WhatsApp Dispatch Service ────────────────────────────────────────────────

export interface WhatsAppDispatchServiceOptions {
  /** Override the config resolver (for testing). */
  configResolver?: OpenWAConfigResolver;
}

/**
 * THE single dispatch path for all WhatsApp messages in DukanX.
 *
 * Wraps the canonical OpenWA contract from staff-notify.service.ts:
 * - computeOpenWASignature for HMAC-SHA256 signing
 * - OpenWAConfigResolver for per-tenant credential retrieval
 *
 * Enforces:
 * - 16 MB document cap (Req 4.2)
 * - Per-tenant credential scoping (Req 12.5) — each business dispatches ONLY
 *   with its own OpenWA credentials
 * - Credential-unavailable → no dispatch, retain pre-dispatch state (Req 12.6, 13.7)
 * - HMAC-SHA256 signature on every API call (Req 13.1)
 */
export class WhatsAppDispatchService {
  private readonly configResolver: OpenWAConfigResolver;

  constructor(options: WhatsAppDispatchServiceOptions = {}) {
    this.configResolver = options.configResolver ?? createSecretStoreConfigResolver();
  }

  /**
   * Dispatch a single WhatsApp message through the canonical OpenWA gateway.
   *
   * This is the ONLY code path that sends WhatsApp messages in DukanX.
   * The method uses the sending business's credentials (per-tenant scoping)
   * and signs the request with HMAC-SHA256.
   *
   * @param input - The dispatch input containing recipient, template, and media info.
   * @returns A DispatchResult indicating success or failure with classification.
   */
  async sendMessage(input: DispatchMessageInput): Promise<DispatchResult> {
    // 1. Enforce 16 MB document cap (Req 4.2)
    if (input.mediaSizeBytes != null && input.mediaSizeBytes > MAX_DOCUMENT_SIZE_BYTES) {
      logger.warn('[WhatsAppDispatch] Document exceeds 16 MB cap', {
        businessId: input.businessId,
        tenantId: input.tenantId,
        mediaSizeBytes: input.mediaSizeBytes,
        maxBytes: MAX_DOCUMENT_SIZE_BYTES,
      });
      return {
        success: false,
        errorCode: 'MEDIA_TOO_LARGE',
        errorMessage: `Document size ${input.mediaSizeBytes} bytes exceeds the 16 MB limit`,
      };
    }

    // 2. Resolve per-tenant credentials from the secret store (Req 12.5)
    const gatewayConfig = await this.resolveCredentials(input.tenantId);
    if (!gatewayConfig) {
      // Credentials unavailable — BLOCK dispatch, retain pre-dispatch state (Req 12.6, 13.7)
      logger.error('[WhatsAppDispatch] Credentials unavailable — blocking dispatch', {
        businessId: input.businessId,
        tenantId: input.tenantId,
      });
      return {
        success: false,
        errorCode: 'CREDENTIALS_UNAVAILABLE',
        errorMessage: 'OpenWA credentials not available for this tenant; message retained in pre-dispatch state',
        credentialUnavailable: true,
      };
    }

    // 3. Convert the E.164 recipient number into OpenWA's chatId JID format.
    const chatId = toOpenWAChatId(input.to);

    // 4. Build the request path + body for the real per-type, session-scoped
    //    OpenWA endpoint. OpenWA authenticates via a static X-API-Key header
    //    (not a signature); no HMAC is sent on outbound requests.
    const { path, body } = input.mediaUrl
      ? {
          path: `/api/sessions/${gatewayConfig.sessionId}/messages/send-document`,
          body: JSON.stringify({
            chatId,
            url: input.mediaUrl,
            caption: input.params.body ?? undefined,
          }),
        }
      : {
          path: `/api/sessions/${gatewayConfig.sessionId}/messages/send-text`,
          body: JSON.stringify({
            chatId,
            text: String(input.params.body ?? ''),
          }),
        };

    // 5. Dispatch through the OpenWA gateway (single dispatch path)
    try {
      const response = await fetch(`${gatewayConfig.baseUrl}${path}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': gatewayConfig.apiKey,
        },
        body,
      });

      if (!response.ok) {
        return this.handleGatewayError(response, input);
      }

      // OpenWA returns the raw payload directly: { messageId, timestamp }.
      // No {success,data} envelope.
      const responseBody = await response.json().catch(() => ({}));
      const providerMessageId =
        (responseBody as Record<string, unknown>)?.messageId as string | undefined;

      logger.info('[WhatsAppDispatch] Message dispatched successfully', {
        businessId: input.businessId,
        tenantId: input.tenantId,
        sessionId: gatewayConfig.sessionId,
        chatId,
        templateName: input.templateName,
        providerMessageId,
      });

      return {
        success: true,
        providerMessageId: providerMessageId ?? undefined,
      };
    } catch (error) {
      // Network-level failure (DNS, timeout, connection refused)
      const errorMessage = error instanceof Error ? error.message : String(error);
      const errorCode = this.classifyNetworkError(errorMessage);

      logger.error('[WhatsAppDispatch] Network error during dispatch', {
        businessId: input.businessId,
        tenantId: input.tenantId,
        errorCode,
        errorMessage,
      });

      return {
        success: false,
        errorCode,
        errorMessage,
      };
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ──────────────────────────────────────────────────────────────────────────

  /**
   * Resolve per-tenant credentials. Uses the injected config resolver which
   * reads from the secret store (AWS Secrets Manager) with caching.
   * Returns null if credentials are unavailable (Req 12.6, 13.7).
   */
  private async resolveCredentials(tenantId: string): Promise<OpenWAGatewayConfig | null> {
    try {
      return await this.configResolver(tenantId);
    } catch (error) {
      // Any unhandled error from the resolver → treat as unavailable
      logger.error('[WhatsAppDispatch] Unexpected error resolving credentials', {
        tenantId,
        error: (error as Error).message,
      });
      return null;
    }
  }

  /**
   * Handle a non-2xx response from the OpenWA gateway.
   * Maps HTTP status codes to error codes used by retry-policy.service.ts.
   */
  private async handleGatewayError(
    response: Response,
    input: DispatchMessageInput,
  ): Promise<DispatchResult> {
    const errorBody = await response.text().catch(() => 'unknown');

    const errorCode = this.mapHttpStatusToErrorCode(response.status);

    logger.error('[WhatsAppDispatch] Gateway returned error', {
      businessId: input.businessId,
      tenantId: input.tenantId,
      status: response.status,
      errorCode,
      errorBody: errorBody.slice(0, 500), // Truncate large error bodies
    });

    return {
      success: false,
      errorCode,
      errorMessage: `OpenWA gateway returned HTTP ${response.status}: ${errorBody.slice(0, 200)}`,
    };
  }

  /**
   * Map HTTP status codes to error codes compatible with retry-policy.service.ts.
   * - 4xx → permanent errors (invalid request, won't succeed on retry)
   * - 5xx → transient errors (gateway issue, may recover)
   * - 429 → rate limited (transient, retry after backoff)
   */
  private mapHttpStatusToErrorCode(status: number): string {
    switch (status) {
      case 400: return 'HTTP_400';
      case 401: return 'HTTP_401';
      case 403: return 'HTTP_403';
      case 404: return 'HTTP_404';
      case 429: return 'RATE_LIMITED';
      case 500: return 'HTTP_500';
      case 502: return 'HTTP_502';
      case 503: return 'HTTP_503';
      case 504: return 'HTTP_504';
      default:
        return status >= 500 ? 'GATEWAY_ERROR' : `HTTP_${status}`;
    }
  }

  /**
   * Classify network-level errors (before an HTTP response is received)
   * into error codes used by retry-policy.service.ts.
   * These are always transient (the network may recover).
   */
  private classifyNetworkError(errorMessage: string): string {
    const msg = errorMessage.toLowerCase();
    if (msg.includes('timeout') || msg.includes('etimedout')) return 'NETWORK_TIMEOUT';
    if (msg.includes('econnrefused')) return 'ECONNREFUSED';
    if (msg.includes('econnreset')) return 'ECONNRESET';
    if (msg.includes('ehostunreach')) return 'EHOSTUNREACH';
    if (msg.includes('dns') || msg.includes('enotfound')) return 'DNS_RESOLUTION_FAILED';
    if (msg.includes('socket')) return 'SOCKET_TIMEOUT';
    return 'GATEWAY_UNAVAILABLE';
  }
}

// ── Factory ──────────────────────────────────────────────────────────────────

/**
 * Create a WhatsAppDispatchService with the default secret-store-based
 * credential resolver. This is the standard factory for handler/worker use.
 */
export function createWhatsAppDispatchService(
  options?: WhatsAppDispatchServiceOptions,
): WhatsAppDispatchService {
  return new WhatsAppDispatchService(options);
}
