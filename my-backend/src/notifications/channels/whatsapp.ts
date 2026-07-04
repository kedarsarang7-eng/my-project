// ============================================================================
// WhatsApp Channel Adapter — Routes through canonical WhatsAppDispatchService
// ============================================================================
// Plugs WhatsApp into the Notification_Delivery_Layer so any notification
// with channel 'whatsapp' is dispatched through the single canonical OpenWA
// gateway (WhatsAppDispatchService). This consolidates ALL WhatsApp traffic
// onto the same recipient-verification pipeline (Req 10.6, 10.8).
//
// The adapter resolves the recipient's WhatsApp number from the notification
// payload (payload.whatsapp_phone) or falls back to querying the customer
// profile. If no number is available the delivery is skipped with a warning.
//
// Requirements: 10.6, 10.8
// ============================================================================

import {
  createWhatsAppDispatchService,
  type WhatsAppDispatchService,
} from '../../modules/whatsapp/services/whatsapp-dispatch.service';
import { logger } from '../../utils/logger';
import type { DispatchChannelAdapter, DispatchChannelArgs } from '../service/types';

// ── Singleton dispatch service (reuses per-Lambda container) ─────────────────

let dispatchService: WhatsAppDispatchService | null = null;

function getDispatchService(): WhatsAppDispatchService {
  if (!dispatchService) {
    dispatchService = createWhatsAppDispatchService();
  }
  return dispatchService;
}

// ── Channel Adapter ─────────────────────────────────────────────────────────

/**
 * WhatsApp channel adapter for the Notification_Delivery_Layer.
 *
 * Routes every WhatsApp delivery through `WhatsAppDispatchService` (the
 * single canonical gateway). The adapter reads the following fields from
 * the notification payload:
 *
 * - `payload.whatsapp_phone` — E.164 recipient phone (required)
 * - `payload.whatsapp_template` — template name (default: 'notification')
 * - `payload.whatsapp_params` — template parameters (default: { body: message })
 * - `payload.tenant_id` — tenant context (required)
 * - `payload.business_id` — business context (falls back to tenant_id)
 * - `payload.message` or `payload.body` — text content when no template params
 *
 * If `whatsapp_phone` is missing the adapter logs a warning and returns
 * without throwing (the notification is not deliverable on this channel).
 */
export const whatsappChannelAdapter: DispatchChannelAdapter = async (
  args: DispatchChannelArgs,
): Promise<void> => {
  const { notification, recipient } = args;
  const payload = notification.payload ?? {};

  // Resolve recipient phone
  const phone =
    (payload.whatsapp_phone as string) ||
    (payload.phone as string) ||
    (payload.recipient_phone as string);

  if (!phone) {
    logger.warn('[whatsapp-channel] No whatsapp_phone in payload — skipping', {
      notification_id: notification.notification_id,
      user_id: recipient.user_id,
    });
    return;
  }

  // Resolve tenant/business context
  const tenantId = (payload.tenant_id as string) || '';
  const businessId = (payload.business_id as string) || tenantId;

  if (!tenantId) {
    logger.warn('[whatsapp-channel] No tenant_id in payload — skipping', {
      notification_id: notification.notification_id,
      user_id: recipient.user_id,
    });
    return;
  }

  // Resolve template and params
  const templateName =
    (payload.whatsapp_template as string) || 'notification';
  const templateParams =
    (payload.whatsapp_params as Record<string, unknown>) || {
      body: (payload.message as string) || (payload.body as string) || '',
    };
  const mediaUrl = payload.media_url as string | undefined;

  // Dispatch through the canonical OpenWA gateway
  const service = getDispatchService();
  const result = await service.sendMessage({
    tenantId,
    businessId,
    to: phone,
    templateName,
    params: templateParams,
    mediaUrl,
  });

  if (!result.success) {
    // If credentials are unavailable, we don't throw (message is retained
    // in pre-dispatch state by the dispatch service). For other errors,
    // throw so the delivery layer records a failure for this channel.
    if (result.credentialUnavailable) {
      logger.warn('[whatsapp-channel] Credentials unavailable — retained', {
        notification_id: notification.notification_id,
        user_id: recipient.user_id,
        errorCode: result.errorCode,
      });
      return;
    }

    throw new Error(
      `WhatsApp dispatch failed: ${result.errorCode} — ${result.errorMessage}`,
    );
  }

  logger.info('[whatsapp-channel] Dispatched via OpenWA', {
    notification_id: notification.notification_id,
    user_id: recipient.user_id,
    providerMessageId: result.providerMessageId,
  });
};

/**
 * Test helper — reset the cached dispatch service instance.
 */
export function _resetWhatsAppChannelAdapterForTests(): void {
  dispatchService = null;
}
