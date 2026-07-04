// ============================================================================
// WhatsApp Module — OpenWA Provisioning Request Schemas (Task 4)
// ============================================================================
// Zod validation for the OpenWA credential-provisioning API:
//   POST   /whatsapp/provisioning         — save credentials + register webhook
//   GET    /whatsapp/provisioning         — get status (no secrets returned)
//   POST   /whatsapp/provisioning/verify  — verify session reachability, activate
//   DELETE /whatsapp/provisioning         — remove credentials + registered webhook
//
// SECURITY: apiKey/webhookSecret are write-only — never echoed back in any
// response (mirrors payment.schema.ts / payment-config.ts conventions).
// ============================================================================

import { z } from 'zod';

// ── Save Provisioning Config ────────────────────────────────────────────────

export const saveProvisioningConfigSchema = z.object({
  /** Base URL of the OpenWA gateway instance, e.g. https://openwa.example.com */
  baseUrl: z.string().trim().url().max(500),
  /** Static API key sent as X-API-Key on every OpenWA REST call. */
  apiKey: z.string().trim().min(1).max(500),
  /** The OpenWA session id (UUID) already created for this business's number. */
  sessionId: z.string().trim().min(1).max(128),
  /** HMAC-SHA256 secret used to verify OpenWA's outbound webhook deliveries. */
  webhookSecret: z.string().trim().min(16).max(500),
  /** Optional friendly label shown in the UI. */
  displayName: z.string().trim().max(100).optional(),
});

export type SaveProvisioningConfigInput = z.infer<typeof saveProvisioningConfigSchema>;

// ── Verify Provisioning Config ──────────────────────────────────────────────
// No body required — verification always targets the current business's
// saved config (session-derived, never client-supplied).

export const verifyProvisioningConfigSchema = z.object({}).optional();

// ── Delete Provisioning Config ──────────────────────────────────────────────
// No body required — deletion always targets the current business's config.

export const deleteProvisioningConfigSchema = z.object({}).optional();
