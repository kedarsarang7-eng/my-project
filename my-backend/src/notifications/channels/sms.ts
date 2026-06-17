// ============================================================================
// Delivery_Layer — SMS channel adapter
// ============================================================================
// Implements the `DispatchChannelAdapter` for the `sms` channel of the
// Unified Notification System (UNS).
//
// Transport
// ---------
// AWS SNS `PublishCommand` with a phone-number target — the same pattern the
// legacy `sendSmsViaSns` helper in `src/handlers/academic_coaching.ts` already
// uses. Phase 3 §9.1 of the architecture lists Twilio as the default, but
// REQ 5.4 is explicit: "Twilio or an equivalent SMS provider configured per
// environment". This codebase already runs SNS-Publish for transactional SMS,
// so we reuse it rather than introducing a second provider.
//
// Retry policy
// ------------
// REQ 5.11 — up to 3 retries with exponential backoff on transient provider
// errors. After the budget is exhausted the adapter throws so the
// Notification_Service records a `failed` lifecycle event and routes the
// payload to the DLQ (REQ 9.3, Phase 3 §8.1, §8.2).
//
// Body
// ----
// Short-form SMS body. Where the event maps onto one of the SMS-specific
// templates exposed by `src/i18n/notification-templates.ts` (bill, payment,
// reminder, otp), that template is used. Otherwise a compact 160-char-clamped
// fallback is built from the payload — keeping the SMS-specific format short
// per Phase 2 channel matrix.
//
// Recipient phone resolution
// --------------------------
// `getRecipientPhone(userId)` is the placeholder lookup. Task 9.6 (the
// Delivery_Layer façade) will replace this with the real lookup against the
// users/staff/parents tables; for now it returns `null` so the adapter
// degrades gracefully when no phone is on file.
//
// Validates: REQ 5.4, REQ 5.11
// ============================================================================

import { configureAwsClient } from '../../config/aws.config';
import { PublishCommand, SNSClient } from '@aws-sdk/client-sns';

import { config } from '../../config/environment';
import { NotificationTemplates } from '../../i18n/notification-templates';
import { logger } from '../../utils/logger';
import { sanitizePayload } from '../service/sanitization';
import type { DispatchChannelArgs } from '../service/types';

// ---- Tunables ---------------------------------------------------------------

/**
 * REQ 5.11 — up to 3 retries (so 4 total attempts including the initial
 * publish) with exponential backoff on transient provider errors.
 */
const SMS_MAX_RETRIES = 3;

/**
 * Base backoff in milliseconds. Attempt N waits `BASE * 2^(N-1)` ms before
 * retrying (200, 400, 800 ms for the three retries).
 */
const SMS_BACKOFF_BASE_MS = 200;

/**
 * SMS body hard cap. SNS itself accepts longer messages but splits them into
 * multiple billed segments, and Phase 2's channel matrix calls for short
 * SMS-specific format. 160 GSM characters keeps every notification to a
 * single segment.
 */
const SMS_MAX_LENGTH = 160;

/**
 * Default country dialing code applied when a stored phone is missing the
 * `+<country>` prefix. `+91` matches the legacy `sendSmsViaSns` behaviour.
 */
const DEFAULT_COUNTRY_PREFIX = '+91';

// ---- Module-level SNS client (one per Lambda container) ---------------------

const snsClient = new SNSClient(configureAwsClient({ region: config.aws.region }));

// ---- Recipient phone resolution --------------------------------------------

/**
 * Placeholder phone-number lookup. Returns `null` when no phone is on file
 * for the given user — the adapter then no-ops cleanly.
 *
 * The real implementation (task 9.6 / Delivery_Layer wiring) will read the
 * recipient's phone from the users, staff, or parent records persisted in
 * DynamoDB. Until then the function is exported so tests can monkey-patch
 * it via dependency injection (`__setRecipientPhoneResolver`) and so the
 * Delivery_Layer façade can swap in the production resolver.
 */
export type RecipientPhoneResolver = (
    userId: string,
) => Promise<string | null>;

let recipientPhoneResolver: RecipientPhoneResolver = async (
    _userId: string,
): Promise<string | null> => null;

/**
 * Test/integration hook — replace the recipient-phone lookup with a custom
 * resolver. Returns the previous resolver so callers can restore it.
 */
export function __setRecipientPhoneResolver(
    resolver: RecipientPhoneResolver,
): RecipientPhoneResolver {
    const previous = recipientPhoneResolver;
    recipientPhoneResolver = resolver;
    return previous;
}

/**
 * Public resolver entry-point. Kept exported so the Delivery_Layer façade
 * (task 9.6) can wire its own implementation in.
 */
export async function getRecipientPhone(
    userId: string,
): Promise<string | null> {
    return recipientPhoneResolver(userId);
}

// ---- Transient-error classification ----------------------------------------

/**
 * Decide whether an SNS publish failure is transient (worth retrying) or
 * terminal (rethrow immediately).
 *
 * SNS surfaces `ThrottlingException`, `InternalErrorException`, network
 * errors, and 5xx HTTP statuses for transient conditions. Validation,
 * permission, and opt-out errors are terminal.
 */
function isTransientSmsError(err: unknown): boolean {
    if (!err || typeof err !== 'object') return false;
    const e = err as {
        name?: string;
        code?: string;
        $metadata?: { httpStatusCode?: number };
        retryable?: boolean;
    };

    if (e.retryable === true) return true;

    const status = e.$metadata?.httpStatusCode;
    if (typeof status === 'number') {
        if (status >= 500 && status < 600) return true;
        if (status === 429) return true;
    }

    const name = (e.name || e.code || '').toString();
    const transientNames = new Set([
        'ThrottlingException',
        'TooManyRequestsException',
        'InternalErrorException',
        'InternalFailure',
        'ServiceUnavailableException',
        'TimeoutError',
        'NetworkingError',
        'RequestTimeout',
        'RequestTimeoutException',
    ]);
    return transientNames.has(name);
}

// ---- Phone normalization ----------------------------------------------------

/**
 * Normalize a stored phone to E.164 form expected by SNS. Returns `null`
 * when the phone is too short to be a real number.
 */
function normalizePhone(phone: string | null | undefined): string | null {
    if (!phone) return null;
    const trimmed = phone.trim();
    if (trimmed.length < 10) return null;
    return trimmed.startsWith('+')
        ? trimmed
        : `${DEFAULT_COUNTRY_PREFIX}${trimmed}`;
}

// ---- Body builder -----------------------------------------------------------

/**
 * Pull a string field from the event payload, defaulting to `fallback` when
 * the field is missing or non-string.
 */
function payloadString(
    payload: Record<string, unknown>,
    key: string,
    fallback = '',
): string {
    const v = payload[key];
    return typeof v === 'string' && v.length > 0 ? v : fallback;
}

/**
 * Resolve the locale to render the SMS body in. Producers MAY pass `locale`
 * on the event payload; otherwise we fall back to English.
 */
function resolveLocale(payload: Record<string, unknown>): string {
    return payloadString(payload, 'locale', 'en');
}

/**
 * Build a short-form SMS body for the notification using the SMS-specific
 * templates from `notification-templates.ts` where available, falling back
 * to a compact `event_name + key payload fields` summary.
 *
 * The body is hard-capped at `SMS_MAX_LENGTH` to keep every send to a
 * single SMS segment.
 */
export function buildSmsBody(args: DispatchChannelArgs): string {
    const { notification } = args;
    // REQ 12.2 — defense-in-depth sanitization at the SMS boundary.
    // SMS bodies are typically rendered as plain text, but downstream
    // gateways may parse URLs / tags for click-tracking, so we strip
    // scripting markup and control bytes before composing the body.
    const payload = sanitizePayload(notification.payload ?? {});
    const locale = resolveLocale(payload);

    let body: string;

    switch (notification.event_name) {
        case 'invoice.bill.created': {
            body = NotificationTemplates.smsBill(locale, {
                shopName: payloadString(payload, 'shopName', 'DukanX'),
                invoiceNo: payloadString(payload, 'invoiceNo'),
                amount: payloadString(payload, 'amount'),
            });
            break;
        }
        case 'invoice.payment.received': {
            body = NotificationTemplates.smsPayment(locale, {
                shopName: payloadString(payload, 'shopName', 'DukanX'),
                amount: payloadString(payload, 'amount'),
                balance: payloadString(payload, 'balance', '0'),
            });
            break;
        }
        case 'invoice.payment.reminder': {
            body = NotificationTemplates.smsReminder(locale, {
                shopName: payloadString(payload, 'shopName', 'DukanX'),
                amount: payloadString(payload, 'amount'),
                phone: payloadString(payload, 'phone'),
            });
            break;
        }
        case 'auth.otp.requested': {
            const otp = payloadString(payload, 'otp');
            const minutesRaw = payload['otpMinutes'];
            const minutes = typeof minutesRaw === 'number' ? minutesRaw : 10;
            body = NotificationTemplates.smsOtp(locale, otp, minutes);
            break;
        }
        default: {
            // Generic short summary: prefer an explicit `smsBody` or
            // `message` field on the payload, else compose from the event
            // name + a short subject hint.
            const explicit =
                payloadString(payload, 'smsBody') ||
                payloadString(payload, 'message');
            if (explicit) {
                body = explicit;
            } else {
                const subject =
                    payloadString(payload, 'subject') ||
                    payloadString(payload, 'title') ||
                    notification.event_name;
                body = `DukanX: ${subject}`;
            }
            break;
        }
    }

    // Hard-cap to a single SMS segment.
    if (body.length > SMS_MAX_LENGTH) {
        body = body.slice(0, SMS_MAX_LENGTH);
    }
    return body;
}

// ---- Public adapter ---------------------------------------------------------

/**
 * `DispatchChannelAdapter` for the `sms` channel.
 *
 * - Skips silently when invoked for any channel other than `sms` — the
 *   Delivery_Layer façade dispatches per-channel, so this is a defensive
 *   guard rather than a routing decision.
 * - Resolves the recipient phone via `getRecipientPhone(userId)`. When no
 *   phone is on file the adapter logs and returns; the recipient simply
 *   does not receive an SMS for this notification (other channels still
 *   dispatch independently — failure isolation, Phase 3 §9.3).
 * - Publishes via SNS with retry + exponential backoff on transient errors.
 * - Throws on terminal failure or after the retry budget is exhausted, so
 *   the Notification_Service records a `failed` lifecycle event and the
 *   payload is routed to the DLQ.
 */
export const smsChannelAdapter = async (
    args: DispatchChannelArgs,
): Promise<void> => {
    if (args.channel !== 'sms') {
        return;
    }

    const { notification, recipient } = args;

    if (!config.aws.region) {
        logger.warn('[sms-adapter] aws.region not configured — skipping send', {
            notification_id: notification.notification_id,
            recipient_id: recipient.user_id,
        });
        return;
    }

    const rawPhone = await getRecipientPhone(recipient.user_id);
    const phone = normalizePhone(rawPhone);
    if (!phone) {
        logger.info('[sms-adapter] no phone on file — skipping send', {
            notification_id: notification.notification_id,
            event_name: notification.event_name,
            recipient_id: recipient.user_id,
        });
        return;
    }

    const message = buildSmsBody(args);
    if (!message) {
        logger.warn('[sms-adapter] empty SMS body — skipping send', {
            notification_id: notification.notification_id,
            event_name: notification.event_name,
            recipient_id: recipient.user_id,
        });
        return;
    }

    const command = new PublishCommand({
        PhoneNumber: phone,
        Message: message,
        MessageAttributes: {
            'AWS.SNS.SMS.SMSType': {
                DataType: 'String',
                StringValue: 'Transactional',
            },
            'AWS.SNS.SMS.SenderID': {
                DataType: 'String',
                StringValue: 'DukanX',
            },
        },
    });

    let lastError: unknown;
    for (let attempt = 0; attempt <= SMS_MAX_RETRIES; attempt += 1) {
        try {
            await snsClient.send(command);
            logger.info('[sms-adapter] SMS sent', {
                notification_id: notification.notification_id,
                event_name: notification.event_name,
                recipient_id: recipient.user_id,
                channel: args.channel,
                attempt: attempt + 1,
                phone_suffix: phone.slice(-4),
            });
            return;
        } catch (err) {
            lastError = err;
            const transient = isTransientSmsError(err);
            const willRetry = transient && attempt < SMS_MAX_RETRIES;
            logger.warn('[sms-adapter] SMS send failed', {
                notification_id: notification.notification_id,
                event_name: notification.event_name,
                recipient_id: recipient.user_id,
                attempt: attempt + 1,
                transient,
                will_retry: willRetry,
                error: (err as Error)?.message,
            });
            if (!willRetry) break;
            const delayMs = SMS_BACKOFF_BASE_MS * 2 ** attempt;
            await sleep(delayMs);
        }
    }

    // Retries exhausted (or terminal error) — surface to the service so it
    // records a `failed` lifecycle event and routes to the DLQ.
    throw lastError instanceof Error
        ? lastError
        : new Error(
              `sms-adapter: SMS publish failed after ${SMS_MAX_RETRIES + 1} attempts`,
          );
};

// ---- Helpers ---------------------------------------------------------------

function sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

// ---- Test surface ----------------------------------------------------------

/**
 * Internal hooks exposed only for unit tests. Production callers should not
 * import from `__test__`; the namespace is here so the Delivery_Layer façade
 * stays small and the test harness has stable injection points.
 */
export const __test__ = {
    isTransientSmsError,
    normalizePhone,
    SMS_MAX_RETRIES,
    SMS_BACKOFF_BASE_MS,
    SMS_MAX_LENGTH,
};
