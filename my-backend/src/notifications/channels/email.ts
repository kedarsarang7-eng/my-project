// ============================================================================
// Delivery_Layer — Email Channel Adapter
// ============================================================================
// SMTP-via-SES adapter for the Notification_System. Mirrors the existing
// `sendEmailViaSes` pattern in `my-backend/src/handlers/academic_coaching.ts`
// and consumes `@aws-sdk/client-ses` (already in package.json).
//
// Behaviour pinned by:
//   • REQ 5.3  — Email channel uses SMTP (delivered via Amazon SES here,
//                which is the workspace's existing SMTP-compatible service).
//   • REQ 5.10 — Up to 3 retries with exponential backoff on transient SMTP
//                errors before recording a `failed` lifecycle event.
//   • Phase 3 §9.2 — "Up to 3 retries with exponential backoff on transient
//                SMTP errors" (terminal failure rolls up to the bus-level
//                retry budget; the service writes the lifecycle audit).
//   • Phase 3 §9.3 — Failure isolation: this adapter MUST throw a typed
//                error on terminal failure so the calling
//                `Notification_Service.dispatch` records a `failed`
//                lifecycle audit entry without blocking other channels.
//
// The adapter is exposed as a `DispatchChannelAdapter` callback so the
// future Delivery_Layer façade (task 9.6) can register it alongside the
// other channel adapters.
// ============================================================================

import { configureAwsClient } from '../../config/aws.config';
import {
    SESClient,
    SendEmailCommand,
    type SendEmailCommandOutput,
} from '@aws-sdk/client-ses';
import {
    CognitoIdentityProviderClient,
    AdminGetUserCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { config } from '../../config/environment';
import { logger } from '../../utils/logger';
import { NotificationTemplates } from '../../i18n/notification-templates';
import { t, normalizeLocale } from '../../i18n/i18n.service';
import { sanitizePayload } from '../service/sanitization';
import type {
    DispatchChannelAdapter,
    DispatchChannelArgs,
} from '../service/types';
import type { NotificationRecord } from '../store/types';

// ---------------------------------------------------------------------------
// Public configuration knobs
// ---------------------------------------------------------------------------

/**
 * Default retry budget (REQ 5.10). The bus-level outer envelope (5 attempts)
 * sits on top; the adapter only owns the inner channel-specific budget.
 */
export const EMAIL_MAX_ATTEMPTS = 3;

/**
 * Initial backoff in milliseconds. Each retry doubles the delay
 * (250 → 500 → 1000 ms). Tunable per environment via
 * `EmailAdapterOptions.initialBackoffMs`.
 */
export const EMAIL_INITIAL_BACKOFF_MS = 250;

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/**
 * Thrown when the adapter has no recipient email address (resolver returned
 * `null`/empty). Distinct from delivery failures so the calling service can
 * audit `denied_no_address` separately from `failed_smtp`.
 *
 * This is a TERMINAL error — never retried.
 */
export class EmailRecipientUnresolvedError extends Error {
    public readonly userId: string;
    constructor(userId: string) {
        super(`No email address resolved for recipient '${userId}'`);
        this.name = 'EmailRecipientUnresolvedError';
        this.userId = userId;
    }
}

/**
 * Thrown after the configured retry budget (`EMAIL_MAX_ATTEMPTS`) has been
 * exhausted on transient SMTP/SES errors. The `cause` field carries the
 * final underlying error so the audit log captures it verbatim.
 */
export class EmailDeliveryFailedError extends Error {
    public readonly attempts: number;
    public readonly recipientEmail: string;
    public readonly notificationId: string;
    public override readonly cause?: unknown;
    constructor(
        notificationId: string,
        recipientEmail: string,
        attempts: number,
        cause: unknown,
    ) {
        const reason = cause instanceof Error ? cause.message : String(cause);
        super(
            `Email delivery failed for notification ${notificationId} ` +
                `to ${maskEmail(recipientEmail)} after ${attempts} attempt(s): ${reason}`,
        );
        this.name = 'EmailDeliveryFailedError';
        this.notificationId = notificationId;
        this.recipientEmail = recipientEmail;
        this.attempts = attempts;
        this.cause = cause;
    }
}

// ---------------------------------------------------------------------------
// Recipient resolver — pluggable so tests / future user-repo wiring can swap
// ---------------------------------------------------------------------------

/**
 * Resolver contract used by the email adapter to find a recipient's email
 * address from their `user_id`. Phase 4 accepts that the address comes from
 * a separate source (Cognito today; a dedicated user-repo later). The
 * resolver returns `null` when the recipient has no resolvable email — the
 * adapter then throws `EmailRecipientUnresolvedError` (terminal).
 */
export interface EmailRecipientResolver {
    /**
     * @param userId Cognito sub / DukanX user id.
     * @returns The recipient's email address, or `null` when unknown.
     */
    resolve(userId: string): Promise<string | null>;
}

/**
 * Default resolver: calls `cognito-idp:AdminGetUser` and reads the `email`
 * attribute. Caches lookups for the lifetime of the Lambda container so a
 * burst of notifications to the same user does not multiply IAM calls.
 *
 * Failures (network, throttling, missing user) collapse to `null` so the
 * adapter records a clean `EmailRecipientUnresolvedError` instead of a
 * stack-trace from deep inside the AWS SDK.
 */
export class CognitoEmailResolver implements EmailRecipientResolver {
    private readonly cognito: CognitoIdentityProviderClient;
    private readonly userPoolId: string;
    private readonly cache = new Map<string, string | null>();
    private readonly cacheTtlMs: number;
    private readonly cacheTimestamps = new Map<string, number>();

    constructor(opts?: {
        client?: CognitoIdentityProviderClient;
        userPoolId?: string;
        cacheTtlMs?: number;
    }) {
        this.cognito =
            opts?.client ??
            new CognitoIdentityProviderClient(configureAwsClient({ region: config.cognito.region }));
        this.userPoolId = opts?.userPoolId ?? config.cognito.userPoolId;
        // 5-minute default cache — same horizon as license cache.
        this.cacheTtlMs = opts?.cacheTtlMs ?? 5 * 60 * 1000;
    }

    async resolve(userId: string): Promise<string | null> {
        if (!userId) return null;

        const cachedAt = this.cacheTimestamps.get(userId);
        if (cachedAt !== undefined && Date.now() - cachedAt < this.cacheTtlMs) {
            return this.cache.get(userId) ?? null;
        }

        try {
            const out = await this.cognito.send(
                new AdminGetUserCommand({
                    UserPoolId: this.userPoolId,
                    Username: userId,
                }),
            );
            const emailAttr = out.UserAttributes?.find(
                (a) => a.Name === 'email',
            );
            const verifiedAttr = out.UserAttributes?.find(
                (a) => a.Name === 'email_verified',
            );
            const email = emailAttr?.Value?.trim() ?? null;
            // We accept verified=true OR missing (Cognito does not always set
            // it on imports). We only reject when explicitly false.
            const verified = verifiedAttr?.Value !== 'false';
            const final = email && verified ? email : null;
            this.cache.set(userId, final);
            this.cacheTimestamps.set(userId, Date.now());
            return final;
        } catch (err) {
            logger.warn('[email-adapter] CognitoEmailResolver failed', {
                user_id: userId,
                error: err instanceof Error ? err.message : String(err),
            });
            return null;
        }
    }
}

// ---------------------------------------------------------------------------
// Adapter options
// ---------------------------------------------------------------------------

export interface EmailAdapterOptions {
    /** Override the SES client (tests inject a stub). */
    readonly sesClient?: SESClient;
    /** Override the recipient resolver (tests inject a stub). */
    readonly resolver?: EmailRecipientResolver;
    /** From-address for outgoing email. Defaults to `SES_FROM_EMAIL` env. */
    readonly fromEmail?: string;
    /** Maximum attempts (default 3, REQ 5.10). */
    readonly maxAttempts?: number;
    /** Initial backoff in ms (default 250). */
    readonly initialBackoffMs?: number;
    /**
     * Sleep function — overridable for tests so we can run the retry path
     * without real wall-clock waits. Defaults to `setTimeout`-based sleep.
     */
    readonly sleep?: (ms: number) => Promise<void>;
}

// ---------------------------------------------------------------------------
// Adapter
// ---------------------------------------------------------------------------

/**
 * The email channel adapter. Construct once per Lambda cold start and
 * register the `.send` method (or use the `createEmailAdapter` factory) on
 * the Delivery_Layer façade.
 */
export class EmailChannelAdapter {
    private readonly ses: SESClient;
    private readonly resolver: EmailRecipientResolver;
    private readonly fromEmail: string;
    private readonly maxAttempts: number;
    private readonly initialBackoffMs: number;
    private readonly sleep: (ms: number) => Promise<void>;

    constructor(options: EmailAdapterOptions = {}) {
        this.ses =
            options.sesClient ?? new SESClient(configureAwsClient({ region: config.aws.region }));
        this.resolver = options.resolver ?? new CognitoEmailResolver();
        this.fromEmail =
            options.fromEmail ??
            process.env.SES_FROM_EMAIL ??
            'noreply@dukanx.in';
        this.maxAttempts = options.maxAttempts ?? EMAIL_MAX_ATTEMPTS;
        this.initialBackoffMs =
            options.initialBackoffMs ?? EMAIL_INITIAL_BACKOFF_MS;
        this.sleep = options.sleep ?? defaultSleep;
    }

    /**
     * Conform to the `DispatchChannelAdapter` signature so the service can
     * forward `args` directly. The service ALREADY filters the channel set
     * before invoking us, so a non-`email` channel here is a wiring bug —
     * we throw instead of silently dropping.
     */
    public readonly send: DispatchChannelAdapter = async (args) => {
        if (args.channel !== 'email') {
            throw new Error(
                `EmailChannelAdapter received non-email channel '${args.channel}'`,
            );
        }
        await this.deliver(args);
    };

    /**
     * Resolve the recipient email, render the template, and attempt
     * delivery with retries.
     */
    private async deliver(args: DispatchChannelArgs): Promise<void> {
        const { notification, recipient } = args;

        const toAddress = await this.resolver.resolve(recipient.user_id);
        if (!toAddress || !toAddress.includes('@')) {
            throw new EmailRecipientUnresolvedError(recipient.user_id);
        }

        const message = renderEmailMessage(notification);
        await this.sendWithRetry(toAddress, message, notification);
    }

    private async sendWithRetry(
        toAddress: string,
        message: RenderedEmail,
        notification: NotificationRecord,
    ): Promise<void> {
        let attempt = 0;
        let lastError: unknown = null;

        // Loop attempts 1..maxAttempts. The "+1" is so the FINAL attempt is
        // the Nth (e.g. 3 attempts total when maxAttempts=3).
        while (attempt < this.maxAttempts) {
            attempt += 1;
            try {
                const out = await this.ses.send(
                    new SendEmailCommand({
                        Source: this.fromEmail,
                        Destination: { ToAddresses: [toAddress] },
                        Message: {
                            Subject: { Data: message.subject, Charset: 'UTF-8' },
                            Body: message.html
                                ? {
                                      Html: { Data: message.html, Charset: 'UTF-8' },
                                      Text: { Data: message.text, Charset: 'UTF-8' },
                                  }
                                : {
                                      Text: { Data: message.text, Charset: 'UTF-8' },
                                  },
                        },
                        Tags: [
                            { Name: 'notification_id', Value: notification.notification_id },
                            { Name: 'event_name', Value: tagSafe(notification.event_name) },
                            { Name: 'priority', Value: notification.priority },
                        ],
                    }),
                );
                logger.info('[email-adapter] sent', {
                    notification_id: notification.notification_id,
                    event_name: notification.event_name,
                    to: maskEmail(toAddress),
                    attempt,
                    sesMessageId: messageIdOf(out),
                });
                return;
            } catch (err) {
                lastError = err;
                const transient = isTransientSesError(err);
                logger.warn('[email-adapter] send failed', {
                    notification_id: notification.notification_id,
                    event_name: notification.event_name,
                    to: maskEmail(toAddress),
                    attempt,
                    transient,
                    error: err instanceof Error ? err.message : String(err),
                });

                // Terminal (non-transient) errors short-circuit immediately.
                if (!transient) {
                    throw new EmailDeliveryFailedError(
                        notification.notification_id,
                        toAddress,
                        attempt,
                        err,
                    );
                }

                // No retry budget left.
                if (attempt >= this.maxAttempts) break;

                // Exponential backoff: 250ms, 500ms, 1000ms (with the
                // configured initial value as base).
                const delay = this.initialBackoffMs * 2 ** (attempt - 1);
                await this.sleep(delay);
            }
        }

        throw new EmailDeliveryFailedError(
            notification.notification_id,
            toAddress,
            attempt,
            lastError,
        );
    }
}

// ---------------------------------------------------------------------------
// Factory — returns the adapter as a plain DispatchChannelAdapter callback
// ---------------------------------------------------------------------------

/**
 * Build an email adapter and return its `.send` callback. Convenient for
 * the future Delivery_Layer façade (task 9.6) which wires every channel as
 * a `DispatchChannelAdapter`.
 *
 *   const deliver = createEmailAdapter();
 *   await deliver({ notification, recipient, channel: 'email' });
 */
export function createEmailAdapter(
    options: EmailAdapterOptions = {},
): DispatchChannelAdapter {
    const adapter = new EmailChannelAdapter(options);
    return adapter.send;
}

/**
 * Phase 4 helper exported per the task spec: resolve a recipient email by
 * `user_id`. Defaults to the Cognito-backed resolver. Tests can pass an
 * explicit resolver to swap behaviour without instantiating the adapter.
 */
export async function getRecipientEmail(
    userId: string,
    resolver: EmailRecipientResolver = new CognitoEmailResolver(),
): Promise<string | null> {
    return resolver.resolve(userId);
}

// ---------------------------------------------------------------------------
// Template rendering
// ---------------------------------------------------------------------------

interface RenderedEmail {
    readonly subject: string;
    readonly text: string;
    /** HTML body — optional; fallback to plain text only when absent. */
    readonly html?: string;
}

/**
 * Pick a localized template by `event_name` and render it against the
 * notification payload. Falls back to a generic subject/body when no
 * template is registered for the event.
 *
 * The locale is taken from `notification.payload.locale` (string), then
 * from `notification.payload.recipient_locale`, and finally `'en'` so
 * tenants that don't pass a locale get English without throwing.
 */
export function renderEmailMessage(
    notification: NotificationRecord,
): RenderedEmail {
    // REQ 12.2 — defense-in-depth sanitization at the email boundary
    // before any template renders the payload into HTML/text. Email
    // bodies are the most common XSS sink in transactional notification
    // systems, so the sanitizer runs unconditionally even though
    // `Notification_Service.createNotification` already cleaned the
    // payload at persistence time.
    const payload = sanitizePayload(notification.payload ?? {});
    const localeRaw =
        (typeof payload.locale === 'string' && payload.locale) ||
        (typeof payload.recipient_locale === 'string' && payload.recipient_locale) ||
        'en';
    const locale = normalizeLocale(localeRaw);

    // Use a `notification`-shaped projection that carries the sanitized
    // payload so the per-event branches below pick it up automatically.
    const safeNotification: NotificationRecord = {
        ...notification,
        payload,
    };

    // Map well-known events to the existing `NotificationTemplates` push
    // payloads (push title/body works equally well for short emails). For
    // anything unrecognised we render a generic envelope.
    switch (safeNotification.event_name) {
        case 'invoice.bill.created':
        case 'billing.invoice.created': {
            const params = pickBillCreatedParams(payload);
            const push = NotificationTemplates.billCreatedPush(locale, params);
            return {
                subject: push.title,
                text: emailBodyText(push.body, params.shopName, params.link),
            };
        }
        case 'payment.payment.received':
        case 'invoice.payment.received': {
            const params = pickPaymentReceivedParams(payload);
            const push = NotificationTemplates.paymentReceivedPush(locale, params);
            return {
                subject: push.title,
                text: emailBodyText(push.body, params.shopName),
            };
        }
        case 'inventory.stock.low': {
            const params = pickLowStockParams(payload);
            const push = NotificationTemplates.lowStockPush(locale, params);
            return { subject: push.title, text: push.body };
        }
        case 'inventory.product.expiring': {
            const params = pickExpiryParams(payload);
            const push = NotificationTemplates.expiryWarningPush(locale, params);
            return { subject: push.title, text: push.body };
        }
        case 'system.plan.expiring': {
            const days = Number(payload.days ?? 0);
            const push = NotificationTemplates.planExpiringPush(locale, { days });
            return { subject: push.title, text: push.body };
        }
        case 'orders.order.created':
        case 'restaurant.order.created': {
            const params = pickNewOrderParams(payload);
            const push = NotificationTemplates.newOrderPush(locale, params);
            return { subject: push.title, text: push.body };
        }
        default:
            return renderGenericEmail(safeNotification, locale);
    }
}

/**
 * Generic email shape used when no template matches the `event_name`.
 *
 * Subject:  "<event_name>"  — namespaced and human-readable enough.
 * Body:     A short summary line + the JSON payload, prefixed with the
 *           localized "notifications.dailySummary" frame for consistency
 *           with the rest of the i18n surface. Falls back to a plain
 *           description when the template is unavailable.
 */
function renderGenericEmail(
    notification: NotificationRecord,
    locale: string,
): RenderedEmail {
    const subjectPrefix = t('common.success', locale) || 'Notification';
    const subject = `${subjectPrefix}: ${humanizeEventName(notification.event_name)}`;
    const lines: string[] = [
        humanizeEventName(notification.event_name),
        '',
        `Priority: ${notification.priority}`,
        `Category: ${notification.category}`,
    ];
    if (notification.target_id) {
        lines.push(`Target: ${notification.target_id}`);
    }
    if (notification.payload && Object.keys(notification.payload).length > 0) {
        lines.push('', 'Details:');
        for (const [k, v] of Object.entries(notification.payload)) {
            lines.push(`  ${k}: ${stringifyValue(v)}`);
        }
    }
    return { subject, text: lines.join('\n') };
}

// ---------------------------------------------------------------------------
// Payload pickers — narrow the loose `payload: Record<string, unknown>` to
// the typed param shapes consumed by `NotificationTemplates`.
// ---------------------------------------------------------------------------

function pickBillCreatedParams(payload: Record<string, unknown>) {
    return {
        customerName: stringField(payload, 'customerName', 'Customer'),
        invoiceNo: stringField(payload, 'invoiceNo', '-'),
        amount: stringField(payload, 'amount', '0'),
        shopName: stringField(payload, 'shopName', 'DukanX'),
        link:
            typeof payload.link === 'string' && payload.link
                ? payload.link
                : undefined,
    };
}

function pickPaymentReceivedParams(payload: Record<string, unknown>) {
    return {
        customerName: stringField(payload, 'customerName', 'Customer'),
        amount: stringField(payload, 'amount', '0'),
        balance: stringField(payload, 'balance', '0'),
        shopName: stringField(payload, 'shopName', 'DukanX'),
        date:
            typeof payload.date === 'string' && payload.date
                ? payload.date
                : undefined,
    };
}

function pickLowStockParams(payload: Record<string, unknown>) {
    return {
        productName: stringField(payload, 'productName', 'Item'),
        quantity: Number(payload.quantity ?? 0),
        unit: stringField(payload, 'unit', 'pcs'),
    };
}

function pickExpiryParams(payload: Record<string, unknown>) {
    return {
        productName: stringField(payload, 'productName', 'Item'),
        date: stringField(payload, 'date', ''),
    };
}

function pickNewOrderParams(payload: Record<string, unknown>) {
    return {
        customerName: stringField(payload, 'customerName', 'Customer'),
        orderNo:
            typeof payload.orderNo === 'string' && payload.orderNo
                ? payload.orderNo
                : undefined,
    };
}

function stringField(
    payload: Record<string, unknown>,
    key: string,
    fallback: string,
): string {
    const v = payload[key];
    return typeof v === 'string' && v.length > 0 ? v : fallback;
}

function stringifyValue(v: unknown): string {
    if (v === null || v === undefined) return '';
    if (typeof v === 'string') return v;
    if (typeof v === 'number' || typeof v === 'boolean') return String(v);
    try {
        return JSON.stringify(v);
    } catch {
        return '';
    }
}

function humanizeEventName(eventName: string): string {
    // 'invoice.payment.received' → 'Invoice Payment Received'
    return eventName
        .split('.')
        .map((part) =>
            part
                .split('_')
                .map((s) => (s ? s[0].toUpperCase() + s.slice(1) : ''))
                .join(' '),
        )
        .join(' ');
}

function emailBodyText(
    line: string,
    shopName: string,
    link?: string,
): string {
    const parts: string[] = [line];
    if (link) parts.push('', link);
    parts.push('', `— ${shopName}`);
    return parts.join('\n');
}

// ---------------------------------------------------------------------------
// SES error classification (REQ 5.10 — "transient SMTP error")
// ---------------------------------------------------------------------------

/**
 * SES error codes / HTTP statuses we treat as TRANSIENT (worth retrying).
 *
 * Source: AWS SES error reference. Non-transient examples (`MessageRejected`,
 * `MailFromDomainNotVerified`, `ConfigurationSetDoesNotExist`,
 * `AccountSendingPausedException`) are ALL caller / config issues — retrying
 * them would just burn budget.
 */
const TRANSIENT_SES_ERROR_NAMES = new Set<string>([
    'Throttling',
    'ThrottlingException',
    'TooManyRequestsException',
    'SendingPausedException', // tenant-level transient (paused, may resume)
    'ServiceUnavailable',
    'ServiceUnavailableException',
    'InternalFailure',
    'InternalServerError',
    'RequestTimeout',
    'RequestTimeoutException',
    'TimeoutError',
]);

const TRANSIENT_NETWORK_ERROR_CODES = new Set<string>([
    'ECONNRESET',
    'ETIMEDOUT',
    'ECONNREFUSED',
    'EPIPE',
    'EAI_AGAIN',
    'ENOTFOUND',
    'EHOSTUNREACH',
    'ENETUNREACH',
]);

/**
 * Returns `true` when `err` looks like a transient SMTP / SES failure that
 * could plausibly succeed on retry (rate-limit, 5xx, network blip).
 */
export function isTransientSesError(err: unknown): boolean {
    if (!err || typeof err !== 'object') return false;

    const e = err as {
        name?: string;
        code?: string;
        $metadata?: { httpStatusCode?: number };
        retryable?: boolean;
    };

    if (e.retryable === true) return true;
    if (e.name && TRANSIENT_SES_ERROR_NAMES.has(e.name)) return true;
    if (e.code && TRANSIENT_NETWORK_ERROR_CODES.has(e.code)) return true;

    const status = e.$metadata?.httpStatusCode;
    if (typeof status === 'number') {
        // 408 Request Timeout, 429 Too Many Requests, 5xx server-side errors.
        if (status === 408 || status === 429) return true;
        if (status >= 500 && status < 600) return true;
    }

    return false;
}

// ---------------------------------------------------------------------------
// Small utilities
// ---------------------------------------------------------------------------

function defaultSleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * SES tag values must match `^[\w\-]+$`. The event_name uses dots, which
 * are NOT valid in tag values — replace them with underscores so the
 * `Tags` array doesn't reject the call.
 */
function tagSafe(value: string): string {
    return value.replace(/[^\w\-]/g, '_').slice(0, 256);
}

function maskEmail(email: string): string {
    const at = email.indexOf('@');
    if (at <= 1) return email;
    const local = email.slice(0, at);
    const domain = email.slice(at);
    const visible = local.slice(0, Math.min(2, local.length));
    return `${visible}***${domain}`;
}

function messageIdOf(out: SendEmailCommandOutput): string {
    return out.MessageId ?? '';
}
