// ============================================================================
// WhatsApp Automation Module — OpenWA Session Registry (Webhook Correction)
// ============================================================================
// OpenWA has no tenant/business concept: every messaging endpoint and every
// webhook delivery is scoped by an OpenWA `sessionId` (one WhatsApp number =
// one session). The webhook payload OpenWA actually sends carries `sessionId`
// — it never carries a `tenantId` or `businessId` field.
//
// This registry is the server-side, non-spoofable mapping from an OpenWA
// `sessionId` back to the DukanX (tenantId, businessId) pair that owns it.
// The webhook handler MUST resolve the business this way and MUST NOT trust
// any tenantId/businessId value present in the inbound webhook body.
//
// The mapping is written once, at credential-provisioning time (when a
// business is linked to an OpenWA session), and read on every webhook.
// Stored outside the per-business partition (there is no businessId yet at
// lookup time) under a dedicated, narrow key namespace.
// ============================================================================

import { getItem, putItem, deleteItem } from '../../../config/dynamodb.config';
import { logger } from '../../../utils/logger';

/** Dedicated PK namespace for the session→business registry (not business-scoped). */
const REGISTRY_PK_PREFIX = 'OPENWA_SESSION_REGISTRY#';
const REGISTRY_SK = 'MAPPING';

export interface OpenWASessionMapping {
  sessionId: string;
  tenantId: string;
  businessId: string;
  createdAt: string;
}

/**
 * Resolve the (tenantId, businessId) that owns a given OpenWA sessionId.
 * Returns null if no business has been provisioned against this session —
 * the caller (webhook handler) must reject/ignore rather than guess.
 */
export async function resolveBusinessBySessionId(
  sessionId: string,
): Promise<{ tenantId: string; businessId: string } | null> {
  if (!sessionId || sessionId.trim().length === 0) {
    return null;
  }

  try {
    const item = await getItem<OpenWASessionMapping & { PK: string; SK: string }>(
      `${REGISTRY_PK_PREFIX}${sessionId}`,
      REGISTRY_SK,
    );
    if (!item) return null;
    return { tenantId: item.tenantId, businessId: item.businessId };
  } catch (err) {
    logger.error('[OpenWASessionRegistry] Failed to resolve session mapping', {
      sessionId,
      error: err instanceof Error ? err.message : String(err),
    });
    return null;
  }
}

/**
 * Register (or overwrite) the OpenWA sessionId → business mapping. Called by
 * the credential-provisioning flow when a business is linked to an OpenWA
 * session, so the webhook handler can later resolve inbound events without
 * trusting any client-supplied tenantId/businessId.
 */
export async function registerBusinessSession(
  tenantId: string,
  businessId: string,
  sessionId: string,
): Promise<void> {
  const now = new Date().toISOString();
  const item: OpenWASessionMapping & { PK: string; SK: string } = {
    PK: `${REGISTRY_PK_PREFIX}${sessionId}`,
    SK: REGISTRY_SK,
    sessionId,
    tenantId,
    businessId,
    createdAt: now,
  };
  await putItem(item as unknown as Record<string, unknown>);
}

/**
 * Remove the OpenWA sessionId → business mapping. Called by the credential-
 * provisioning flow when a business's OpenWA credentials are deleted, so a
 * stale session can no longer resolve to a business the webhook would act on.
 */
export async function deregisterBusinessSession(sessionId: string): Promise<void> {
  if (!sessionId || sessionId.trim().length === 0) return;
  await deleteItem(`${REGISTRY_PK_PREFIX}${sessionId}`, REGISTRY_SK);
}
