// ============================================================================
// Delivery_Layer — Barrel Export + Default Façade Wiring
// ============================================================================
// Single import surface for callers (Phase 3 §2 / REQ 20.1 — exactly ONE
// canonical Delivery_Layer):
//
//   import {
//       dispatchChannelAdapter,   // <- pass to NotificationService
//       createDeliveryLayer,      // <- factory for custom wiring
//       inAppChannelAdapter,
//       pushChannelAdapter,
//       smsChannelAdapter,
//       webhookAdapter,
//       createEmailAdapter,
//   } from '../channels';
//
// The module re-exports every per-channel adapter (so producer-side
// modules can also reach into a specific transport for replay /
// administrative tooling) and exposes the unified `DeliveryLayer`
// façade plus a pre-wired default instance whose `dispatch` is the
// canonical `DispatchChannelAdapter` for `Notification_Service`
// construction.
//
// Validates: REQ 5.1-5.5, REQ 9.5, REQ 9.6.
// ============================================================================

import {
    DeliveryLayer,
    type DeliveryLayerOptions,
} from './delivery-layer';
import { inAppChannelAdapter } from './in-app';
import { pushChannelAdapter } from './push';
import { createEmailAdapter } from './email';
import { smsChannelAdapter } from './sms';
import { webhookAdapter } from './webhook';
import type { DispatchChannelAdapter } from '../service/types';

// ---------------------------------------------------------------------------
// Per-channel adapter re-exports
// ---------------------------------------------------------------------------

export { inAppChannelAdapter } from './in-app';
export {
    ackNotification,
    replayPendingForUser,
    IN_APP_CHANNEL,
} from './in-app';
export type {
    InAppDeliveryPayload,
    AckNotificationInput,
    AckNotificationResult,
    ReplayPendingInput,
    ReplayPendingResult,
} from './in-app';

export {
    pushChannelAdapter,
    PushAdapterConfigError,
    PushDeliveryError,
    PUSH_MAX_RETRIES,
    PUSH_BACKOFF_BASE_MS,
    PUSH_BACKOFF_MAX_MS,
    computePushBackoffMs,
} from './push';

export {
    EmailChannelAdapter,
    CognitoEmailResolver,
    EmailRecipientUnresolvedError,
    EmailDeliveryFailedError,
    createEmailAdapter,
    getRecipientEmail,
    renderEmailMessage,
    isTransientSesError,
    EMAIL_MAX_ATTEMPTS,
    EMAIL_INITIAL_BACKOFF_MS,
} from './email';
export type {
    EmailRecipientResolver,
    EmailAdapterOptions,
} from './email';

export {
    smsChannelAdapter,
    buildSmsBody,
    getRecipientPhone,
    __setRecipientPhoneResolver,
} from './sms';
export type { RecipientPhoneResolver } from './sms';

export {
    webhookAdapter,
    createWebhookAdapter,
    sendWebhook,
    getWebhookConfig,
    computeWebhookSignature,
    WebhookDeliveryError,
    WEBHOOK_MAX_ATTEMPTS,
    WEBHOOK_INITIAL_BACKOFF_MS,
    WEBHOOK_MAX_BACKOFF_MS,
    WEBHOOK_REQUEST_TIMEOUT_MS,
    WEBHOOK_SIGNATURE_HEADER,
} from './webhook';
export type {
    WebhookConfig,
    WebhookConfigResolver,
    WebhookAdapterOptions,
    WebhookPayload,
} from './webhook';

// ---------------------------------------------------------------------------
// Façade + rate-limiter re-exports
// ---------------------------------------------------------------------------

export {
    DeliveryLayer,
    DeliveryLayerConfigError,
    DEFAULT_RATE_LIMITS_PER_MINUTE,
} from './delivery-layer';
export type {
    DeliveryLayerOptions,
    ChannelAdapterRegistry,
    DeliveryOutcome,
} from './delivery-layer';

export {
    RateLimiter,
    createRateLimiter,
    RATE_LIMIT_WINDOW_MS,
} from './rate-limiter';
export type {
    RateLimiterOptions,
    RateLimitDecision,
    CoalescedFlush,
    FlushCallback,
    TimerScheduler,
    TimerHandle,
} from './rate-limiter';

// ---------------------------------------------------------------------------
// Factory — wires the five default adapters
// ---------------------------------------------------------------------------

/**
 * Build a `DeliveryLayer` pre-wired with the five canonical channel
 * adapters and the REQ 9.5 default rate limits. Callers MAY override any
 * adapter (`options.adapters`) or rate-limit setting
 * (`options.rateLimit`) — anything they don't override falls through to
 * the production wiring below.
 *
 * Defaults:
 *   - `in_app`  -> {@link inAppChannelAdapter}
 *   - `push`    -> {@link pushChannelAdapter}
 *   - `email`   -> {@link createEmailAdapter}() (Cognito-backed resolver)
 *   - `sms`     -> {@link smsChannelAdapter}
 *   - `webhook` -> {@link webhookAdapter}
 *
 *   - rate limits: REQ 9.5 defaults
 *     ({@link DEFAULT_RATE_LIMITS_PER_MINUTE})
 */
export function createDeliveryLayer(
    options: DeliveryLayerOptions = {},
): DeliveryLayer {
    const overrides = options.adapters ?? {};
    const adapters = {
        in_app: overrides.in_app ?? inAppChannelAdapter,
        push: overrides.push ?? pushChannelAdapter,
        email: overrides.email ?? createEmailAdapter(),
        sms: overrides.sms ?? smsChannelAdapter,
        webhook: overrides.webhook ?? webhookAdapter,
    };
    return new DeliveryLayer({
        ...options,
        adapters,
    });
}

// ---------------------------------------------------------------------------
// Default singleton — Notification_Service consumers wire this directly
// ---------------------------------------------------------------------------

let defaultLayer: DeliveryLayer | null = null;

/**
 * Lazily construct (and cache) a Lambda-container-scoped Delivery_Layer
 * with default wiring. Most callers use `dispatchChannelAdapter` below;
 * tests and one-off wiring scripts can reach the layer directly when
 * they need to call `setAdapter` or `getRateLimitPerMinute`.
 */
export function getDefaultDeliveryLayer(): DeliveryLayer {
    if (!defaultLayer) {
        defaultLayer = createDeliveryLayer();
    }
    return defaultLayer;
}

/**
 * Test/teardown helper — drop the cached default layer so the next call
 * builds a fresh one. Production code should NEVER need this.
 */
export function _resetDefaultDeliveryLayerForTests(): void {
    if (defaultLayer) {
        defaultLayer.dispose();
        defaultLayer = null;
    }
}

/**
 * Canonical `DispatchChannelAdapter` exported from the channels barrel.
 * Wires the default Delivery_Layer (REQ 9.5 rate limits, REQ 9.6 coalesce
 * behaviour, all five adapters from this folder).
 *
 * Callers in `my-backend/src/handlers/notifications/*` construct their
 * `NotificationService` with this:
 *
 *   import { dispatchChannelAdapter } from '../../notifications/channels';
 *   const service = new NotificationService({ dispatchChannelAdapter });
 *
 * — and the service routes every per-recipient-per-channel delivery
 * through the façade (Phase 3 §2 / REQ 20.1).
 */
export const dispatchChannelAdapter: DispatchChannelAdapter = async (args) => {
    return getDefaultDeliveryLayer().dispatch(args);
};
