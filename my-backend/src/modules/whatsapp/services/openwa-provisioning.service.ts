// ============================================================================
// WhatsApp Module — OpenWA Provisioning Service (Task 4)
// ============================================================================
// End-to-end credential provisioning for the OpenWA gateway, per business.
// Mirrors the payment-config.service.ts pattern: secrets are written to a
// dedicated secret store, a non-secret status record tracks the
// pending_verification -> active/failed lifecycle, and verification makes a
// REAL call to the external service before activation.
//
// SPLIT OF RESPONSIBILITIES (matches TenantPaymentConfig's KMS/DB split):
// - AWS Secrets Manager (secrets-manager.service.ts, tenant-namespaced
//   `dukanx/<stage>/<tenantId>/openwa_credentials`) — apiKey, webhookSecret,
//   baseUrl, sessionId. NEVER stored in DynamoDB.
// - DynamoDB WAPROV#CONFIG record (openwa-provisioning.repository.ts) —
//   status, sessionId (non-secret, needed for display + registry lookups),
//   baseUrl (non-secret), displayName, webhookId, verifiedAt, lastError.
// - OpenWA session registry (openwa-session-registry.service.ts) — the
//   sessionId -> (tenantId, businessId) reverse mapping the webhook handler
//   uses to resolve inbound deliveries without trusting client input.
//
// REAL OpenWA API calls made by this service (verified against
// Dukan_x/OpenWA source — see session.controller.ts, webhook.controller.ts):
// - GET  /api/sessions/:sessionId              — verify reachability + auth
// - POST /api/sessions/:sessionId/webhooks     — register our callback URL
// - DELETE /api/sessions/:sessionId/webhooks/:id — remove our callback URL
//
// Requirements: 8.4, 8.5, 10.1, 10.4, 12.1, 12.4, 12.5, 12.6, 13.7
// ============================================================================

import { randomUUID } from 'crypto';
import { storeSecret, getSecret, deleteSecret } from '../../../services/secrets-manager.service';
import { OpenWaProvisioningRepository } from '../repositories/openwa-provisioning.repository';
import {
  registerBusinessSession,
  deregisterBusinessSession,
} from './openwa-session-registry.service';
import { OPENWA_SECRET_NAME } from './whatsapp-dispatch.service';
import { AppError, NotFoundError } from '../../../utils/errors';
import { logger } from '../../../utils/logger';
import { config } from '../../../config/environment';
import type { OpenWaProvisioningConfig } from '../schemas/entities';
import type { SaveProvisioningConfigInput } from '../schemas/provisioning.schema';

// ── Types ────────────────────────────────────────────────────────────────────

/** Full credential shape persisted in the secret store (never returned to clients). */
interface OpenWaCredentials {
  baseUrl: string;
  apiKey: string;
  sessionId: string;
  webhookSecret: string;
}

/** Events OpenWA is asked to deliver to our webhook (message-level delivery/read receipts). */
const SUBSCRIBED_WEBHOOK_EVENTS = ['message.ack', 'message.failed'] as const;

// ── HTTP helper ──────────────────────────────────────────────────────────────

async function openWaFetch(
  baseUrl: string,
  apiKey: string,
  path: string,
  init: { method: string; body?: unknown },
): Promise<{ ok: boolean; status: number; json: unknown }> {
  const response = await fetch(`${baseUrl}${path}`, {
    method: init.method,
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': apiKey,
    },
    body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
  });
  const json = await response.json().catch(() => ({}));
  return { ok: response.ok, status: response.status, json };
}

/**
 * Build the public callback URL OpenWA should POST delivery events to.
 * Reuses the exact `callbackBaseUrl` pattern established in
 * handlers/payment.ts: prefer the live API Gateway domain, fall back to the
 * configured backend base URL when unavailable (e.g. local invocation).
 */
export function buildWebhookCallbackUrl(domainName?: string, stage?: string): string {
  const base = domainName
    ? `https://${domainName}${stage && stage !== '$default' ? `/${stage}` : ''}`
    : config.extendedApp.slsBackendUrl;

  if (!base) {
    throw new AppError(
      'Unable to determine backend base URL for OpenWA webhook registration',
      500,
      'WEBHOOK_BASE_URL_UNAVAILABLE',
    );
  }
  return `${base}/whatsapp/webhook`;
}

// ── Service ──────────────────────────────────────────────────────────────────

export class OpenWaProvisioningService {
  private readonly repo: OpenWaProvisioningRepository;

  constructor(repo?: OpenWaProvisioningRepository) {
    this.repo = repo ?? new OpenWaProvisioningRepository();
  }

  /** Get the current provisioning STATUS (never includes secrets). */
  async getStatus(
    tenantId: string,
    businessId: string,
  ): Promise<OpenWaProvisioningConfig | null> {
    return this.repo.get(tenantId, businessId);
  }

  /**
   * Save OpenWA credentials for a business:
   * 1. Write credentials to the secret store (create-or-update)
   * 2. Register the sessionId -> business mapping in the session registry
   * 3. Write/replace the pending_verification status record
   *
   * Does NOT activate the config — the caller must invoke `verifyAndActivate`
   * to confirm the session is actually reachable before it is used for
   * dispatch (mirrors payment-config.service.ts's pending_verification flow).
   */
  async saveConfig(
    tenantId: string,
    businessId: string,
    input: SaveProvisioningConfigInput,
  ): Promise<OpenWaProvisioningConfig> {
    const existing = await this.repo.get(tenantId, businessId);

    const credentials: OpenWaCredentials = {
      baseUrl: input.baseUrl.replace(/\/+$/, ''), // normalize trailing slash
      apiKey: input.apiKey,
      sessionId: input.sessionId,
      webhookSecret: input.webhookSecret,
    };

    await storeSecret(tenantId, OPENWA_SECRET_NAME, JSON.stringify(credentials));

    // Server-side, non-spoofable mapping the webhook handler relies on.
    await registerBusinessSession(tenantId, businessId, credentials.sessionId);

    const saved = await this.repo.upsert(tenantId, businessId, {
      id: existing?.id ?? randomUUID(),
      sessionId: credentials.sessionId,
      baseUrl: credentials.baseUrl,
      status: 'pending_verification',
      displayName: input.displayName,
      webhookId: undefined, // re-registered on next verifyAndActivate
      lastError: undefined,
      verifiedAt: undefined,
    });

    logger.info('[OpenWaProvisioning] Config saved (pending verification)', {
      tenantId,
      businessId,
      sessionId: credentials.sessionId,
    });

    return saved;
  }

  /**
   * Verify the saved credentials against the real OpenWA gateway and, on
   * success, register our webhook and activate the config.
   *
   * Verification steps (Req: no mocks — real API calls only):
   * 1. GET /api/sessions/:sessionId — confirms auth + session existence
   * 2. POST /api/sessions/:sessionId/webhooks — registers our callback
   *    (idempotent: replaces any previously registered webhook by deleting
   *    the old one first, so re-verification never leaves duplicates)
   *
   * On any failure, status is set to 'failed' with lastError populated and
   * an AppError is thrown — the caller (handler) surfaces this to the UI.
   */
  async verifyAndActivate(
    tenantId: string,
    businessId: string,
    webhookCallbackUrl: string,
  ): Promise<OpenWaProvisioningConfig> {
    const existing = await this.repo.get(tenantId, businessId);
    if (!existing) {
      throw new NotFoundError('OpenWA provisioning config');
    }

    const raw = await getSecret(tenantId, OPENWA_SECRET_NAME);
    const credentials = JSON.parse(raw) as OpenWaCredentials;

    // 1. Confirm the session exists and our API key is valid for it.
    const sessionCheck = await openWaFetch(
      credentials.baseUrl,
      credentials.apiKey,
      `/api/sessions/${credentials.sessionId}`,
      { method: 'GET' },
    );

    if (!sessionCheck.ok) {
      const lastError = `Session check failed: HTTP ${sessionCheck.status}`;
      await this.repo.update(tenantId, businessId, { status: 'failed', lastError });
      logger.error('[OpenWaProvisioning] Verification failed — session unreachable', {
        tenantId,
        businessId,
        sessionId: credentials.sessionId,
        status: sessionCheck.status,
      });
      throw new AppError(
        `OpenWA session verification failed: ${lastError}`,
        400,
        'OPENWA_VERIFICATION_FAILED',
      );
    }

    // 2. Replace any previously registered webhook (idempotent re-verification).
    if (existing.webhookId) {
      await openWaFetch(
        credentials.baseUrl,
        credentials.apiKey,
        `/api/sessions/${credentials.sessionId}/webhooks/${existing.webhookId}`,
        { method: 'DELETE' },
      ).catch((err) => {
        // Best-effort cleanup — a failure here must not block re-registration.
        logger.warn('[OpenWaProvisioning] Failed to delete stale webhook (continuing)', {
          tenantId,
          businessId,
          webhookId: existing.webhookId,
          error: (err as Error).message,
        });
      });
    }

    const webhookRegistration = await openWaFetch(
      credentials.baseUrl,
      credentials.apiKey,
      `/api/sessions/${credentials.sessionId}/webhooks`,
      {
        method: 'POST',
        body: {
          url: webhookCallbackUrl,
          events: [...SUBSCRIBED_WEBHOOK_EVENTS],
          secret: credentials.webhookSecret,
        },
      },
    );

    if (!webhookRegistration.ok) {
      const lastError = `Webhook registration failed: HTTP ${webhookRegistration.status}`;
      await this.repo.update(tenantId, businessId, { status: 'failed', lastError });
      logger.error('[OpenWaProvisioning] Verification failed — webhook registration', {
        tenantId,
        businessId,
        sessionId: credentials.sessionId,
        status: webhookRegistration.status,
      });
      throw new AppError(
        `OpenWA webhook registration failed: ${lastError}`,
        400,
        'OPENWA_WEBHOOK_REGISTRATION_FAILED',
      );
    }

    const webhookId = (webhookRegistration.json as Record<string, unknown>)?.id as string | undefined;
    const now = new Date().toISOString();

    const updated = await this.repo.update(tenantId, businessId, {
      status: 'active',
      webhookId,
      lastError: undefined,
      verifiedAt: now,
    });

    if (!updated) {
      throw new NotFoundError('OpenWA provisioning config');
    }

    logger.info('[OpenWaProvisioning] Config verified and activated', {
      tenantId,
      businessId,
      sessionId: credentials.sessionId,
      webhookId,
    });

    return updated;
  }

  /**
   * Remove OpenWA credentials for a business:
   * 1. Best-effort delete the registered webhook on the OpenWA side
   * 2. Delete the secret from the secret store
   * 3. Deregister the sessionId -> business mapping
   * 4. Delete the status record
   */
  async deleteConfig(tenantId: string, businessId: string): Promise<void> {
    const existing = await this.repo.get(tenantId, businessId);
    if (!existing) {
      throw new NotFoundError('OpenWA provisioning config');
    }

    if (existing.webhookId) {
      try {
        const raw = await getSecret(tenantId, OPENWA_SECRET_NAME);
        const credentials = JSON.parse(raw) as OpenWaCredentials;
        await openWaFetch(
          credentials.baseUrl,
          credentials.apiKey,
          `/api/sessions/${credentials.sessionId}/webhooks/${existing.webhookId}`,
          { method: 'DELETE' },
        );
      } catch (err) {
        // Best-effort — do not block local cleanup if OpenWA is unreachable.
        logger.warn('[OpenWaProvisioning] Failed to delete remote webhook during config removal', {
          tenantId,
          businessId,
          error: (err as Error).message,
        });
      }
    }

    await deleteSecret(tenantId, OPENWA_SECRET_NAME).catch((err) => {
      logger.warn('[OpenWaProvisioning] Failed to delete secret (continuing)', {
        tenantId,
        businessId,
        error: (err as Error).message,
      });
    });

    await deregisterBusinessSession(existing.sessionId);
    await this.repo.remove(tenantId, businessId);

    logger.info('[OpenWaProvisioning] Config deleted', { tenantId, businessId });
  }
}

export function createOpenWaProvisioningService(): OpenWaProvisioningService {
  return new OpenWaProvisioningService();
}
