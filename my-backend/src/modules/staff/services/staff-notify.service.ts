// ============================================================================
// Staff Module — Multi-Channel Notification Service (Task 11.3)
// ============================================================================
// Dispatches staff notifications through the existing `src/notifications`
// Delivery_Layer for Push, Email, In-App, and WebSocket channels.
// Routes WhatsApp through the canonical OpenWA_Gateway (Baileys, per-tenant
// API key, HMAC-SHA256 webhook verification) — NO second gateway (Req 8.5).
// SMS uses the flagged-off `createDeferredSmsAdapter()` from
// deferred-capabilities.service.ts — stays OFF (Req 8.6, 15.4).
//
// Notification entries are logged to the NotificationLog entity
// (SK: NOTIFLOG#{timestamp}#{id}) via `buildNotificationLogKeys` from keys.ts.
//
// Requirements: 8.4, 8.5, 8.6
// ============================================================================

import { randomUUID, createHmac, timingSafeEqual } from 'crypto';
import { logger } from '../../../utils/logger';
import { putItem } from '../../../config/dynamodb.config';
import { buildNotificationLogKeys, STAFF_ENTITY_TYPE } from '../keys';
import {
    createDeferredSmsAdapter,
    type StaffSmsAdapter,
    type StaffSmsNotificationInput,
} from './deferred-capabilities.service';

// ── Import from the existing notifications delivery layer ───────────────────
import {
    dispatchChannelAdapter,
} from '../../../notifications/channels';
import type { DispatchChannelAdapter } from '../../../notifications/service/types';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

/** Supported notification channels for the staff module. */
export type StaffNotificationChannel =
    | 'push'
    | 'email'
    | 'in_app'
    | 'websocket'
    | 'whatsapp'
    | 'sms';

/** Input for sending a staff notification. */
export interface StaffNotificationInput {
    /** Tenant context. */
    tenantId: string;
    /** Business context. */
    businessId: string;
    /** Recipient identifier (employee ID or user ID). */
    recipientId: string;
    /** Channels to deliver through. */
    channels: StaffNotificationChannel[];
    /** Notification template or event name. */
    template: string;
    /** Template variables / payload. */
    payload?: Record<string, unknown>;
    /** Optional phone number for WhatsApp/SMS (E.164 format). */
    phoneNumber?: string;
    /** Optional email for email channel. */
    email?: string;
}

/** Result of a notification dispatch attempt. */
export interface StaffNotificationResult {
    /** Unique notification log ID. */
    id: string;
    /** Per-channel outcomes. */
    outcomes: ChannelOutcome[];
}

/** Outcome for a single channel. */
export interface ChannelOutcome {
    channel: StaffNotificationChannel;
    status: 'sent' | 'failed' | 'flagged_off';
    error?: string;
}

// ────────────────────────────────────────────────────────────────────────────
// OpenWA Gateway Configuration
// ────────────────────────────────────────────────────────────────────────────

/**
 * OpenWA gateway configuration per tenant. In production, resolved from
 * environment or a per-tenant config store.
 */
export interface OpenWAGatewayConfig {
    /** Base URL for the OpenWA gateway API (e.g. https://openwa.example.com). */
    baseUrl: string;
    /** Per-tenant API key for authentication (sent as X-API-Key on every OpenWA REST call). */
    apiKey: string;
    /** HMAC-SHA256 secret used to verify OpenWA's OUTBOUND webhook deliveries (X-OpenWA-Signature). */
    webhookSecret: string;
    /**
     * The OpenWA session id (UUID) that this business is provisioned against.
     * OpenWA has no tenant/business concept of its own — every messaging and
     * webhook-management endpoint is scoped by `/api/sessions/:sessionId/...`.
     * This id is what maps a DukanX business to its OpenWA WhatsApp number.
     */
    sessionId: string;
}

/**
 * Resolves OpenWA gateway configuration for a tenant. Consumers inject
 * a real resolver; tests inject a stub. Defaults to environment variables.
 */
export type OpenWAConfigResolver = (
    tenantId: string,
) => Promise<OpenWAGatewayConfig | null>;

// ────────────────────────────────────────────────────────────────────────────
// HMAC-SHA256 Verification (reused pattern from payment gateways)
// ────────────────────────────────────────────────────────────────────────────

/**
 * Compute HMAC-SHA256 signature for an OpenWA webhook payload.
 * Uses the same `crypto.createHmac + timingSafeEqual` pattern as
 * Razorpay/PhonePe gateways (see payment-webhook.ts, razorpay.gateway.ts).
 */
export function computeOpenWASignature(
    payload: string,
    secret: string,
): string {
    return createHmac('sha256', secret).update(payload, 'utf8').digest('hex');
}

/**
 * Verify an incoming OpenWA webhook signature using constant-time comparison.
 * Returns `true` iff the signature matches (no timing side-channel).
 */
export function verifyOpenWAWebhookSignature(
    payload: string,
    signature: string,
    secret: string,
): boolean {
    const expected = computeOpenWASignature(payload, secret);
    try {
        const sigBuf = Buffer.from(signature, 'hex');
        const expectedBuf = Buffer.from(expected, 'hex');
        if (sigBuf.length !== expectedBuf.length) return false;
        return timingSafeEqual(sigBuf, expectedBuf);
    } catch {
        return false;
    }
}

// ────────────────────────────────────────────────────────────────────────────
// Default OpenWA Config Resolver (environment-based)
// ────────────────────────────────────────────────────────────────────────────

const defaultOpenWAConfigResolver: OpenWAConfigResolver = async (_tenantId) => {
    const baseUrl = process.env.OPENWA_GATEWAY_URL;
    const apiKey = process.env.OPENWA_API_KEY;
    const webhookSecret = process.env.OPENWA_WEBHOOK_SECRET;
    const sessionId = process.env.OPENWA_SESSION_ID;
    if (!baseUrl || !apiKey || !webhookSecret || !sessionId) {
        return null;
    }
    return { baseUrl, apiKey, webhookSecret, sessionId };
};

// ────────────────────────────────────────────────────────────────────────────
// Staff Notification Service
// ────────────────────────────────────────────────────────────────────────────

export interface StaffNotifyServiceOptions {
    /** Override the channel adapter for Push/Email/In-App/WebSocket dispatch. */
    channelAdapter?: DispatchChannelAdapter;
    /** Override the OpenWA config resolver (for testing). */
    openWAConfigResolver?: OpenWAConfigResolver;
    /** Override the SMS adapter (for testing; defaults to deferred adapter). */
    smsAdapter?: StaffSmsAdapter;
}

/**
 * Multi-channel notification service for the staff module.
 *
 * Dispatches through:
 * - Push/Email/In-App/WebSocket → existing `src/notifications` DeliveryLayer
 * - WhatsApp → existing OpenWA_Gateway (no second gateway; Req 8.5)
 * - SMS → flagged-off adapter interface only (Req 8.6)
 *
 * Every dispatch is logged to the NotificationLog (append-only).
 */
export class StaffNotifyService {
    private readonly channelAdapter: DispatchChannelAdapter;
    private readonly openWAConfigResolver: OpenWAConfigResolver;
    private readonly smsAdapter: StaffSmsAdapter;

    constructor(options: StaffNotifyServiceOptions = {}) {
        this.channelAdapter = options.channelAdapter ?? dispatchChannelAdapter;
        this.openWAConfigResolver =
            options.openWAConfigResolver ?? defaultOpenWAConfigResolver;
        this.smsAdapter = options.smsAdapter ?? createDeferredSmsAdapter();
    }

    /**
     * Dispatch a staff notification across the requested channels.
     * Logs each attempt to the NotificationLog entity.
     */
    async notify(input: StaffNotificationInput): Promise<StaffNotificationResult> {
        const id = randomUUID();
        const outcomes: ChannelOutcome[] = [];

        for (const channel of input.channels) {
            const outcome = await this.dispatchChannel(channel, input);
            outcomes.push(outcome);

            // Log each channel dispatch to the NotificationLog
            await this.logNotification({
                id: `${id}-${channel}`,
                tenantId: input.tenantId,
                businessId: input.businessId,
                channel,
                to: input.recipientId,
                template: input.template,
                status: outcome.status === 'sent' ? 'sent' : 'failed',
            });
        }

        return { id, outcomes };
    }

    // ──────────────────────────────────────────────────────────────────────
    // Channel dispatch routing
    // ──────────────────────────────────────────────────────────────────────

    private async dispatchChannel(
        channel: StaffNotificationChannel,
        input: StaffNotificationInput,
    ): Promise<ChannelOutcome> {
        switch (channel) {
            case 'push':
            case 'email':
            case 'in_app':
            case 'websocket':
                return this.dispatchViaDeliveryLayer(channel, input);
            case 'whatsapp':
                return this.dispatchViaOpenWA(input);
            case 'sms':
                return this.dispatchViaSms(input);
            default:
                return {
                    channel,
                    status: 'failed',
                    error: `Unknown channel: ${channel}`,
                };
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Push / Email / In-App / WebSocket — existing Delivery Layer
    // ──────────────────────────────────────────────────────────────────────

    /**
     * Dispatches through the existing `src/notifications` delivery layer.
     * Maps the staff channel name to the notification system's channel name.
     */
    private async dispatchViaDeliveryLayer(
        channel: StaffNotificationChannel,
        input: StaffNotificationInput,
    ): Promise<ChannelOutcome> {
        // Map staff channel names to the notification system's channel names
        const channelMap: Record<string, string> = {
            push: 'push',
            email: 'email',
            in_app: 'in_app',
            websocket: 'webhook', // WebSocket uses the webhook adapter path
        };
        const notifChannel = channelMap[channel] ?? channel;

        try {
            await this.channelAdapter({
                notification: {
                    notification_id: randomUUID(),
                    event_name: `staff.notification.${input.template}`,
                    category: 'system',
                    sub_category: 'staff',
                    priority: 'normal',
                    actor_id: 'system',
                    target_id: input.recipientId,
                    recipients: [
                        {
                            user_id: input.recipientId,
                            role: 'staff',
                            channels: [notifChannel as any],
                            status: 'emitted',
                            delivered_at: null,
                            read_at: null,
                        },
                    ],
                    payload: input.payload ?? {},
                    channels: [notifChannel as any],
                    status: 'emitted',
                    created_at: new Date().toISOString(),
                    dispatched_at: null,
                    delivered_at: null,
                    read_at: null,
                    dedup_key: '',
                    source_module: 'staff',
                    source_app: 'backend',
                },
                recipient: {
                    user_id: input.recipientId,
                    role: 'staff',
                },
                channel: notifChannel as any,
            });

            return { channel, status: 'sent' };
        } catch (err) {
            const error = err instanceof Error ? err.message : String(err);
            logger.error('Staff notification delivery failed', {
                channel,
                recipientId: input.recipientId,
                template: input.template,
                error,
            });
            return { channel, status: 'failed', error };
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // WhatsApp — routed through the existing OpenWA_Gateway (Req 8.5)
    // ──────────────────────────────────────────────────────────────────────

    /**
     * Routes WhatsApp messages through the existing OpenWA_Gateway.
     * Uses per-tenant API key scoping and HMAC-SHA256 webhook verification.
     * Does NOT introduce a second WhatsApp gateway (Req 8.5).
     */
    private async dispatchViaOpenWA(
        input: StaffNotificationInput,
    ): Promise<ChannelOutcome> {
        if (!input.phoneNumber) {
            return {
                channel: 'whatsapp',
                status: 'failed',
                error: 'Phone number required for WhatsApp channel',
            };
        }

        try {
            const config = await this.openWAConfigResolver(input.tenantId);
            if (!config) {
                return {
                    channel: 'whatsapp',
                    status: 'failed',
                    error: 'OpenWA gateway not configured for this tenant',
                };
            }

            // Build the message payload
            const messagePayload = JSON.stringify({
                to: input.phoneNumber,
                template: input.template,
                params: input.payload ?? {},
                businessId: input.businessId,
            });

            // Compute HMAC-SHA256 signature for the request
            // (same pattern as Razorpay/PhonePe payment gateways)
            const signature = computeOpenWASignature(
                messagePayload,
                config.webhookSecret,
            );

            // Send through the OpenWA gateway
            const response = await fetch(`${config.baseUrl}/api/send-message`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-API-Key': config.apiKey,
                    'X-OpenWA-Signature': `sha256=${signature}`,
                },
                body: messagePayload,
            });

            if (!response.ok) {
                const errorBody = await response.text().catch(() => 'unknown');
                logger.error('OpenWA gateway error', {
                    status: response.status,
                    error: errorBody,
                    tenantId: input.tenantId,
                    recipientId: input.recipientId,
                });
                return {
                    channel: 'whatsapp',
                    status: 'failed',
                    error: `OpenWA returned ${response.status}`,
                };
            }

            logger.info('Staff WhatsApp notification sent via OpenWA', {
                tenantId: input.tenantId,
                recipientId: input.recipientId,
                template: input.template,
            });

            return { channel: 'whatsapp', status: 'sent' };
        } catch (err) {
            const error = err instanceof Error ? err.message : String(err);
            logger.error('Staff WhatsApp notification failed', {
                recipientId: input.recipientId,
                error,
            });
            return { channel: 'whatsapp', status: 'failed', error };
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // SMS — flagged-off adapter interface only (Req 8.6)
    // ──────────────────────────────────────────────────────────────────────

    /**
     * Routes SMS through the deferred SMS adapter. The flag stays OFF
     * (Req 8.6, 15.4). Never sends a real message or fabricates delivery.
     */
    private async dispatchViaSms(
        input: StaffNotificationInput,
    ): Promise<ChannelOutcome> {
        const smsInput: StaffSmsNotificationInput = {
            employeeId: input.recipientId,
            phoneNumber: input.phoneNumber ?? '',
            templateId: input.template,
            templateVars: input.payload as Record<string, string> | undefined,
            businessId: input.businessId,
            tenantId: input.tenantId,
        };

        const result = await this.smsAdapter.send(smsInput);

        if (!result.available) {
            logger.info('Staff SMS notification flagged off', {
                recipientId: input.recipientId,
                template: input.template,
                reason: result.reason,
            });
            return { channel: 'sms', status: 'flagged_off' };
        }

        // If the flag is somehow ON but no provider exists, still flagged_off
        return { channel: 'sms', status: 'flagged_off' };
    }

    // ──────────────────────────────────────────────────────────────────────
    // NotificationLog persistence (append-only)
    // ──────────────────────────────────────────────────────────────────────

    /**
     * Persist a notification log entry to DynamoDB (append-only).
     * SK: NOTIFLOG#{timestamp}#{id}
     */
    private async logNotification(entry: {
        id: string;
        tenantId: string;
        businessId: string;
        channel: StaffNotificationChannel;
        to: string;
        template: string;
        status: 'sent' | 'failed';
    }): Promise<void> {
        const timestamp = new Date().toISOString();
        const keys = buildNotificationLogKeys(
            entry.tenantId,
            entry.businessId,
            timestamp,
            entry.id,
        );

        const item = {
            PK: keys.PK,
            SK: keys.SK,
            GSI1PK: keys.GSI1PK,
            GSI1SK: keys.GSI1SK,
            entityType: STAFF_ENTITY_TYPE.NOTIFICATION_LOG,
            tenantId: entry.tenantId,
            businessId: entry.businessId,
            id: entry.id,
            channel: entry.channel,
            to: entry.to,
            template: entry.template,
            status: entry.status,
            timestamp,
            isDeleted: false,
            createdAt: timestamp,
            updatedAt: timestamp,
        };

        try {
            await putItem(item as unknown as Record<string, unknown>);
        } catch (err) {
            // Best-effort logging — do not fail the notification on log error
            logger.error('Failed to persist notification log entry', {
                id: entry.id,
                error: (err as Error).message,
            });
        }
    }
}

// ────────────────────────────────────────────────────────────────────────────
// Factory — convenience for handler-level construction
// ────────────────────────────────────────────────────────────────────────────

/**
 * Create a StaffNotifyService with default wiring:
 * - Push/Email/In-App/WebSocket via the notifications DeliveryLayer
 * - WhatsApp via OpenWA_Gateway (env-based config)
 * - SMS via the deferred adapter (flagged OFF)
 */
export function createStaffNotifyService(
    options?: StaffNotifyServiceOptions,
): StaffNotifyService {
    return new StaffNotifyService(options);
}
