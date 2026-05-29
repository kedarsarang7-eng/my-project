// ============================================================================
// Notification_Service — Core Implementation
// ============================================================================
// The brain (design.md §"Components" — Notification_Service): owns
// notification creation, recipient resolution, deduplication, persistence,
// and the dispatch decision. Wires together:
//
//   - Notification_Store    (../store)        — persistence
//   - Event_Bus             (../event-bus)    — schema validation surface
//   - Caller authorizer     (./authz.ts)      — REQ 4.10
//   - Recipient authorizer  (./authz.ts)      — REQ 4.11
//   - Deduplication         (./dedup.ts)      — REQ 4.4, 6.6
//   - Lifecycle transitions (./lifecycle.ts)  — REQ 6.7a, 4.6
//
// Validates: REQ 4.1 - 4.11.
//
// The Delivery_Layer is intentionally NOT imported here. Task 9 lands the
// channel adapters; this service exposes a `DispatchChannelAdapter`
// callback so it stays decoupled and can be unit-tested without spinning
// up FCM/SMTP/Twilio/WebSocket transports.
// ============================================================================

import { randomUUID } from 'crypto';
import { logger } from '../../utils/logger';
import {
    appendAuditLog,
    createNotification as createNotificationRecord,
    findByDedupKey,
    getNotification,
    getUserPreference,
    listByUserCategory,
    upsertUserPreference,
    type NotificationRepoOptions,
    type UserPreferenceRepoOptions,
    type AuditLogRepoOptions,
} from '../store';
import type {
    AuditLogRecord,
    NotificationCategory,
    NotificationRecipient,
    NotificationRecord,
    NotificationStatus,
    UserPreferenceRecord,
} from '../store/types';
import { tryValidateEventContract } from '../event-bus/schema-validator';
import type { Channel as EventBusChannel } from '../event-bus/types';
import {
    AllowAllRecipientAuthorizer,
    DefaultCallerAuthorizer,
    type CallerAuthorizer,
    type RecipientAuthorizer,
} from './authz';
import {
    computeDedupKey,
    DEFAULT_DEDUP_WINDOW_SECONDS,
    findDuplicateForRecipient,
} from './dedup';
import {
    AuthorizationError,
    NotificationNotFoundError,
    PreferenceValidationError,
    ReplayWindowExceededError,
} from './errors';
import {
    markAsRead as markAsReadInternal,
    transitionToDispatched,
} from './lifecycle';
import { sanitizePayload } from './sanitization';
import { redactPayload } from './redaction';
import {
    recordUnauthorizedAccessAttempt,
    type UnauthorizedAccessReason,
} from './unauthorized-audit';
import type {
    CreateNotificationCaller,
    CreateNotificationInput,
    CreateNotificationResult,
    DispatchChannelAdapter,
    DispatchOptions,
    DispatchRecipientOutcome,
    DispatchResult,
    MarkAsReadResult,
    ReplayResult,
    SetUserPreferencesInput,
} from './types';
import { REPLAY_WINDOW_DAYS } from './types';

// ---- Service options & wiring -------------------------------------------

/**
 * Wiring options for the Notification_Service. All fields are optional;
 * defaults are sufficient for unit tests and for the early service rollout.
 *
 * Production code (lambdas/handlers) supplies the production
 * `RecipientAuthorizer` and a real `dispatchChannelAdapter` (the
 * Delivery_Layer façade landing in task 9).
 */
export interface NotificationServiceOptions {
    readonly callerAuthorizer?: CallerAuthorizer;
    readonly recipientAuthorizer?: RecipientAuthorizer;
    readonly dispatchChannelAdapter?: DispatchChannelAdapter;
    /** Repo-layer overrides — typically a shared DynamoDBDocumentClient. */
    readonly storeOptions?: NotificationRepoOptions &
        UserPreferenceRepoOptions &
        AuditLogRepoOptions;
}

/**
 * Validation guard: every event_name in the registry follows
 * `<domain>.<entity>.<action>` (REQ 2.6). We re-check it here so the
 * service-layer surface fails fast even when callers bypass the
 * Event_Contract JSON Schema (e.g. internal Lambdas calling
 * `createNotification` directly).
 */
const EVENT_NAME_RE = /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){2,}$/;

/**
 * Authentication context for read/modify operations on user preferences.
 * Optional on every preferences method — when supplied, the service
 * enforces "owner or admin" and writes an `unauthorized_access_attempt`
 * audit entry on deny (REQ 12.7).
 */
export interface PreferencesCaller {
    readonly user_id: string;
    readonly role: string;
}

/**
 * Roles permitted to read or modify another user's preferences (REQ 12.7).
 * Mirrors `DefaultCallerAuthorizer.PRIVILEGED_EMIT_ROLES` so the two
 * surfaces stay aligned.
 */
const PRIVILEGED_PREFERENCE_ROLES = new Set<string>([
    'super_admin',
    'admin',
    'system',
]);

// ---- Default no-op channel adapter ---------------------------------------
//
// The default adapter logs and returns. Production callers MUST pass a real
// adapter that hands off to the Delivery_Layer. Logging at `info` keeps the
// dev experience: if you forget to wire the adapter you see exactly which
// notification was "delivered to nowhere" instead of silently swallowing it.

const noopChannelAdapter: DispatchChannelAdapter = async (args) => {
    logger.info(
        '[Notification_Service] dispatchChannelAdapter not configured — ' +
            'no-op delivery',
        {
            notification_id: args.notification.notification_id,
            event_name: args.notification.event_name,
            recipient_id: args.recipient.user_id,
            channel: args.channel,
        },
    );
};

// ============================================================================
// NotificationService class — single canonical instance per process
// ============================================================================

export class NotificationService {
    private readonly callerAuthorizer: CallerAuthorizer;
    private readonly recipientAuthorizer: RecipientAuthorizer;
    private readonly dispatchChannelAdapter: DispatchChannelAdapter;
    private readonly storeOptions: NotificationRepoOptions &
        UserPreferenceRepoOptions &
        AuditLogRepoOptions;

    constructor(options: NotificationServiceOptions = {}) {
        this.callerAuthorizer =
            options.callerAuthorizer ?? new DefaultCallerAuthorizer();
        this.recipientAuthorizer =
            options.recipientAuthorizer ?? new AllowAllRecipientAuthorizer();
        this.dispatchChannelAdapter =
            options.dispatchChannelAdapter ?? noopChannelAdapter;
        this.storeOptions = options.storeOptions ?? {};
    }

    // ------------------------------------------------------------------
    // createNotification (REQ 4.1, 4.2, 4.10)
    // ------------------------------------------------------------------

    /**
     * Validate the event, run caller authorization, persist the record at
     * status `emitted`, and return the new `notification_id` (REQ 4.1, 4.2).
     *
     * Throws `AuthorizationError` (REQ 4.10) before persistence if the
     * caller is not allowed to emit on behalf of `input.actor_id`.
     */
    public async createNotification(
        input: CreateNotificationInput,
        caller: CreateNotificationCaller,
    ): Promise<CreateNotificationResult> {
        // 1) Authorize caller FIRST — never persist on a denied call.
        //    REQ 12.7 — every denied access attempt MUST write an
        //    `unauthorized_access_attempt` Audit_Log entry. We catch the
        //    AuthorizationError, write the audit row best-effort, and
        //    re-throw so the user-visible 403 behaviour is unchanged.
        try {
            await this.callerAuthorizer.assertCanCreate({ caller, input });
        } catch (err) {
            if (err instanceof AuthorizationError) {
                await this.recordUnauthorized({
                    actorId: caller.user_id || 'anonymous',
                    reason: 'caller_not_authorized',
                    context: {
                        actor_id: input.actor_id,
                        event_name: input.event_name,
                        source_app: input.source_app,
                    },
                });
            }
            throw err;
        }

        // 2) Sanitize payload UNCONDITIONALLY before any downstream stage
        //    sees it (REQ 12.2 — strip scripting tags and control
        //    characters before persistence and before delivery). Done
        //    here so dedup_key computation, Event_Contract validation,
        //    and the persisted record all observe the cleaned payload.
        //    The sanitizer is pure and returns a fresh object — `input`
        //    itself is not mutated.
        //    REQ 12.2: channel adapters re-run the sanitizer at the
        //    transport boundary as defense-in-depth against payloads
        //    that arrive via paths bypassing this method.
        const sanitizedPayload = sanitizePayload(input.payload);

        // 2a) Defense-in-depth redaction (Task 16.4, REQ 12.8). The
        //    Event_Bus boundary REJECTS publishes that embed raw
        //    secrets / full PAN / full credit cards / full government
        //    IDs. This second pass exists because `createNotification`
        //    is also reachable via in-process callers that did not go
        //    through the bus (legacy producers, internal Lambdas, test
        //    seeds). Running the same redactor here means the persisted
        //    Notification record never carries a raw value even if a
        //    caller bypassed the bus boundary.
        //
        //    Like sanitization, this is pure and returns a fresh
        //    object; `input.payload` is not mutated. The redacted
        //    payload becomes the canonical payload from this point on
        //    (dedup_key computation, Event_Contract revalidation,
        //    persistence) so every observer sees the cleaned form.
        const redactedPayload = redactPayload(sanitizedPayload);

        // 3) Synthesize defaulted fields.
        const id = (input.id ?? randomUUID()).trim();
        const created_at = input.created_at ?? new Date().toISOString();
        const target_id = input.target_id ?? '';
        const dedup_scope_fields = input.dedup_scope_fields ?? [];
        const dedup_key =
            input.dedup_key ??
            computeDedupKey({
                event_name: input.event_name,
                actor_id: input.actor_id,
                target_id,
                dedup_scope_fields,
                payload: redactedPayload,
            });

        // 4) Surface-level validation — event_name shape.
        if (!EVENT_NAME_RE.test(input.event_name)) {
            // REQ 12.7 — denial path; record the unauthorized-access
            // attempt before raising. The shape check is functionally
            // an authorization failure (the caller is trying to emit
            // an event that does not match the canonical pattern).
            await this.recordUnauthorized({
                actorId: caller.user_id || 'anonymous',
                reason: 'caller_not_authorized',
                context: {
                    actor_id: input.actor_id,
                    event_name: input.event_name,
                    reason_detail: 'event_name_shape',
                },
            });
            throw new AuthorizationError(
                `event_name '${input.event_name}' does not match the canonical ` +
                    `<domain>.<entity>.<action> pattern.`,
                { caller_id: caller.user_id, actor_id: input.actor_id },
            );
        }

        // 5) Run the canonical Event_Contract validator so the service surface
        //    enforces the same shape as the Event_Bus publisher (REQ 8.1).
        const validation = tryValidateEventContract({
            id,
            event_name: input.event_name,
            category: input.category,
            sub_category: input.sub_category ?? undefined,
            priority: input.priority,
            actor_id: input.actor_id,
            target_id: target_id || null,
            recipients: [...input.recipients],
            payload: redactedPayload,
            channels: [...input.channels],
            source_module: input.source_module,
            source_app: input.source_app,
            created_at,
            dedup_key,
            dedup_scope_fields: [...dedup_scope_fields],
        });
        if (!validation.ok) {
            throw new PreferenceValidationError(
                'createNotification payload failed Event_Contract validation.',
                { issues: validation.issues },
            );
        }

        // 6) Build the persisted record (REQ 6.1 shape).
        const recipients: readonly NotificationRecipient[] =
            input.recipients.map((r) => ({
                user_id: r.user_id,
                role: r.role,
                channels: r.channels && r.channels.length > 0
                    ? (r.channels as NotificationRecipient['channels'])
                    : (input.channels as NotificationRecipient['channels']),
                status: 'emitted' as NotificationStatus,
                delivered_at: null,
                read_at: null,
            }));

        const record: NotificationRecord = {
            notification_id: id,
            event_name: input.event_name,
            category: input.category,
            sub_category: input.sub_category ?? '',
            priority: input.priority,
            actor_id: input.actor_id,
            target_id: target_id,
            recipients,
            payload: redactedPayload,
            channels: input.channels,
            status: 'emitted',
            created_at,
            dispatched_at: null,
            delivered_at: null,
            read_at: null,
            dedup_key,
            source_module: input.source_module,
            source_app: input.source_app,
        };

        // 7) Persist (REQ 4.2).
        await createNotificationRecord(record, this.storeOptions);

        // 8) Append audit-log entry — `emitted` lifecycle (REQ 14.1).
        await this.safeAppendAudit({
            audit_id: randomUUID(),
            notification_id: id,
            lifecycle_state: 'emitted',
            recipient_id: null,
            channel: null,
            attempt: 1,
            outcome: 'success',
            error_reason: null,
            timestamp: created_at,
        });

        logger.info('[Notification_Service] createNotification', {
            notification_id: id,
            event_name: input.event_name,
            priority: input.priority,
            recipients: recipients.length,
        });

        return { notification_id: id };
    }

    // ------------------------------------------------------------------
    // dispatch (REQ 4.3, 4.4, 4.11)
    // ------------------------------------------------------------------

    /**
     * Resolve recipients, run the per-recipient authorization check, run
     * the deduplication step, forward to the Delivery_Layer adapter for
     * each enabled channel, and transition the lifecycle to `dispatched`
     * (REQ 4.3, 4.4, 4.11).
     *
     * Per REQ 4.11, recipients that fail the authorization check are
     * SILENTLY OMITTED — no error is raised for the call as a whole, the
     * outcome appears in the per-recipient `outcome` array.
     *
     * Per REQ 4.4, a duplicate dispatch (within the Deduplication_Window
     * for the same dedup_key + recipient) records a `skipped_duplicate`
     * audit entry and skips that recipient.
     */
    public async dispatch(
        notificationId: string,
        options: DispatchOptions = {},
    ): Promise<DispatchResult> {
        const record = await getNotification(notificationId, this.storeOptions);
        if (!record) {
            throw new NotificationNotFoundError(notificationId);
        }

        const dedupWindowSeconds =
            options.dedupWindowSeconds ?? DEFAULT_DEDUP_WINDOW_SECONDS;
        const recipientAuthorizer =
            options.recipientAuthorizer ?? this.recipientAuthorizer;
        const deliver = options.deliver ?? this.dispatchChannelAdapter;

        const outcomes: DispatchRecipientOutcome[] = [];
        let anyDelivered = false;

        for (const recipient of record.recipients) {
            const channels = recipient.channels.length > 0
                ? recipient.channels
                : record.channels;

            // 1) Authorization (REQ 4.11) — silently omit on deny.
            let authorized = false;
            try {
                authorized = await recipientAuthorizer.canReceive({
                    user_id: recipient.user_id,
                    role: recipient.role,
                    event_name: record.event_name,
                    target_id: record.target_id || null,
                });
            } catch (err) {
                logger.warn(
                    '[Notification_Service] recipient authorizer threw — ' +
                        'treating as deny',
                    {
                        notification_id: notificationId,
                        user_id: recipient.user_id,
                        error: err instanceof Error ? err.message : String(err),
                    },
                );
                authorized = false;
            }

            if (!authorized) {
                outcomes.push({
                    user_id: recipient.user_id,
                    role: recipient.role,
                    channels,
                    outcome: 'denied_unauthorized',
                });
                // REQ 12.7 — write a dedicated `unauthorized_access_attempt`
                // entry rather than a `dispatched/denied` row so security
                // tooling can find every denial with a single
                // `lifecycle_state` filter. Note: REQ 4.11 also requires we
                // SILENTLY OMIT this recipient — no error propagates to the
                // overall dispatch result, the deny only shows up in the
                // per-recipient outcome array.
                await this.recordUnauthorized({
                    actorId: recipient.user_id,
                    reason: 'recipient_not_authorized',
                    notificationId,
                    context: {
                        event_name: record.event_name,
                        target_id: record.target_id || null,
                        role: recipient.role,
                    },
                });
                continue;
            }

            // 2) Deduplication (REQ 4.4) — skip + audit on duplicate.
            const dup = await findDuplicateForRecipient(
                {
                    dedup_key: record.dedup_key,
                    recipientId: recipient.user_id,
                    windowSeconds: dedupWindowSeconds,
                    excludeNotificationId: record.notification_id,
                    now: new Date(),
                },
                this.storeOptions,
            );

            if (dup) {
                outcomes.push({
                    user_id: recipient.user_id,
                    role: recipient.role,
                    channels,
                    outcome: 'skipped_duplicate',
                });
                await this.safeAppendAudit({
                    audit_id: randomUUID(),
                    notification_id: notificationId,
                    lifecycle_state: 'dispatched',
                    recipient_id: recipient.user_id,
                    channel: null,
                    attempt: 1,
                    outcome: 'skipped_duplicate',
                    error_reason: `prior_delivery=${dup.notification_id}`,
                    timestamp: new Date().toISOString(),
                });
                continue;
            }

            // 3) Forward to the Delivery_Layer for each enabled channel.
            //    Failure of one channel does NOT prevent attempts on the
            //    others (Phase 3 §"Delivery_Layer" — failure isolation).
            let recipientDelivered = false;
            const errors: string[] = [];
            for (const channel of channels) {
                try {
                    await deliver({
                        notification: record,
                        recipient: {
                            user_id: recipient.user_id,
                            role: recipient.role,
                        },
                        channel: channel as EventBusChannel,
                    });
                    recipientDelivered = true;
                    anyDelivered = true;
                    await this.safeAppendAudit({
                        audit_id: randomUUID(),
                        notification_id: notificationId,
                        lifecycle_state: 'dispatched',
                        recipient_id: recipient.user_id,
                        channel,
                        attempt: 1,
                        outcome: 'success',
                        error_reason: null,
                        timestamp: new Date().toISOString(),
                    });
                } catch (err) {
                    const message =
                        err instanceof Error ? err.message : String(err);
                    errors.push(`${channel}: ${message}`);
                    await this.safeAppendAudit({
                        audit_id: randomUUID(),
                        notification_id: notificationId,
                        lifecycle_state: 'failed',
                        recipient_id: recipient.user_id,
                        channel,
                        attempt: 1,
                        outcome: 'failure',
                        error_reason: message,
                        timestamp: new Date().toISOString(),
                    });
                }
            }

            if (recipientDelivered) {
                outcomes.push({
                    user_id: recipient.user_id,
                    role: recipient.role,
                    channels,
                    outcome: 'delivered',
                });
            } else {
                outcomes.push({
                    user_id: recipient.user_id,
                    role: recipient.role,
                    channels,
                    outcome: 'failed',
                    error_reason: errors.join('; ') || 'no_channel_succeeded',
                });
            }
        }

        // 4) Top-level lifecycle transition (REQ 6.7a, REQ 14.1).
        //    Only advance to `dispatched` if at least one recipient was
        //    successfully forwarded; otherwise the record stays at
        //    `emitted` so a retry can be triggered.
        let finalStatus: DispatchResult['status'] = record.status as
            | 'dispatched'
            | 'emitted'
            | 'failed';
        if (anyDelivered) {
            await transitionToDispatched(
                notificationId,
                undefined,
                this.storeOptions,
            );
            finalStatus = 'dispatched';
        }

        return {
            notification_id: notificationId,
            status: finalStatus,
            recipients: outcomes,
        };
    }

    // ------------------------------------------------------------------
    // markAsRead (REQ 4.5, 4.6 — idempotent)
    // ------------------------------------------------------------------

    public async markAsRead(
        notificationId: string,
        userId: string,
    ): Promise<MarkAsReadResult> {
        // REQ 12.7 — only a Recipient (or an authorized administrator,
        // wired via task 14.1) may mark a notification as read. We load
        // the record up front, check the recipient list, and on a deny
        // write an `unauthorized_access_attempt` audit entry before
        // raising. The check is intentionally minimal — task 14.1
        // injects the production RBAC layer for admin overrides.
        const record = await getNotification(notificationId, this.storeOptions);
        if (!record) {
            throw new NotificationNotFoundError(notificationId);
        }
        const isRecipient = record.recipients.some(
            (r) => r.user_id === userId,
        );
        if (!isRecipient) {
            await this.recordUnauthorized({
                actorId: userId || 'anonymous',
                reason: 'not_recipient',
                notificationId,
                context: {
                    event_name: record.event_name,
                    operation: 'markAsRead',
                },
            });
            throw new AuthorizationError(
                `User '${userId}' is not a recipient of notification ` +
                    `'${notificationId}' and cannot mark it as read.`,
                { caller_id: userId, reason: 'not_recipient' },
            );
        }

        const result = await markAsReadInternal(
            { notification_id: notificationId, user_id: userId },
            this.storeOptions,
        );

        // Audit entry only on the FIRST read so the trail does not bloat.
        if (result.first_read) {
            await this.safeAppendAudit({
                audit_id: randomUUID(),
                notification_id: notificationId,
                lifecycle_state: 'read',
                recipient_id: userId,
                channel: null,
                attempt: 1,
                outcome: 'success',
                error_reason: null,
                timestamp: result.notification.read_at ?? new Date().toISOString(),
            });
        }

        return {
            notification_id: notificationId,
            user_id: userId,
            read_at: result.notification.read_at as string,
            first_read: result.first_read,
        };
    }

    // ------------------------------------------------------------------
    // getUserPreferences / setUserPreferences (REQ 4.7, 4.8, 4.9)
    // ------------------------------------------------------------------

    /**
     * Read a user's stored preferences (REQ 4.7).
     *
     * REQ 12.7 — when an optional `caller` context is supplied, the
     * service verifies the caller is the owner of the requested
     * preferences (or holds an admin role). Production HTTP handlers
     * (lambdas) pass the JWT-derived caller; legacy in-process callers
     * that already hold the context can omit it.
     */
    public async getUserPreferences(
        userId: string,
        caller?: PreferencesCaller,
    ): Promise<UserPreferenceRecord | null> {
        if (caller && !this.isOwnerOrAdmin(caller, userId)) {
            await this.recordUnauthorized({
                actorId: caller.user_id || 'anonymous',
                reason: 'not_owner',
                context: {
                    target_user_id: userId,
                    operation: 'getUserPreferences',
                },
            });
            throw new AuthorizationError(
                `Caller '${caller.user_id}' is not authorized to read ` +
                    `preferences for user '${userId}'.`,
                { caller_id: caller.user_id, reason: 'not_owner' },
            );
        }
        return getUserPreference(userId, this.storeOptions);
    }

    /**
     * Validate, persist, and return the new `UserPreferenceRecord`
     * (REQ 4.8, 4.9). Idempotent at the service level: invoking with the
     * same payload more than once leaves the resolved preferences
     * unchanged (REQ 7.7), with a different `version`/`updated_at`
     * (acceptable per REQ 4.9 — same STORED STATE for resolution
     * purposes; the optimistic-lock counter is internal bookkeeping).
     *
     * REQ 12.7 — optional `caller` context enforces owner/admin access;
     * see `getUserPreferences` for the rationale.
     */
    public async setUserPreferences(
        userId: string,
        input: SetUserPreferencesInput,
        caller?: PreferencesCaller,
    ): Promise<UserPreferenceRecord> {
        if (!userId || userId.trim() === '') {
            throw new PreferenceValidationError(
                'setUserPreferences requires a non-empty user_id.',
            );
        }
        if (caller && !this.isOwnerOrAdmin(caller, userId)) {
            await this.recordUnauthorized({
                actorId: caller.user_id || 'anonymous',
                reason: 'not_owner',
                context: {
                    target_user_id: userId,
                    operation: 'setUserPreferences',
                },
            });
            throw new AuthorizationError(
                `Caller '${caller.user_id}' is not authorized to modify ` +
                    `preferences for user '${userId}'.`,
                { caller_id: caller.user_id, reason: 'not_owner' },
            );
        }
        validatePreferencePayload(input);

        const existing = await getUserPreference(userId, this.storeOptions);
        const expectedVersion = existing ? existing.version : 0;

        return upsertUserPreference(
            {
                user_id: userId,
                expectedVersion,
                role: input.role ?? existing?.role ?? '',
                per_category_channels: input.per_category_channels,
                per_event_channels: input.per_event_channels,
                quiet_hours_start: input.quiet_hours_start,
                quiet_hours_end: input.quiet_hours_end,
                quiet_hours_timezone: input.quiet_hours_timezone,
                mute_targets: input.mute_targets,
            },
            this.storeOptions,
        );
    }

    // ------------------------------------------------------------------
    // getReplay (REQ 8.4, 8.5, 8.5a — Sub_App_Sync_Layer entry)
    // ------------------------------------------------------------------

    /**
     * Return notifications targeted at users of the given Sub_App with
     * `created_at >= since`, in ascending order, bounded by the
     * Replay_Window default of 7 days (REQ 8.5). Out-of-window requests
     * fail with a structured `replay_window_exceeded` error (REQ 8.5a).
     *
     * The current implementation is intentionally simple: it delegates to
     * the per-recipient `by-user-category` GSI for each recipient role
     * the Sub_App represents. The full Sub_App→user resolution (which
     * users belong to which Sub_App) lands with task 10.1 — until then
     * callers MUST supply the recipient `user_ids` explicitly.
     *
     * Until that wiring lands the function exposes a stable signature:
     *
     *   await getReplay({ since, app, userIds, category? })
     *
     * `app` is currently used only for logging. `category` defaults to
     * iterating every category.
     */
    public async getReplay(input: GetReplayInput): Promise<ReplayResult> {
        const since = input.since;
        const sinceMs = Date.parse(since);
        if (!Number.isFinite(sinceMs)) {
            // REQ 12.7 — `replay_window_exceeded` is a security guard
            // (it caps how far back a Sub_App may pull missed events).
            // A malformed `since` is treated the same as out-of-window
            // and is audited as an unauthorized access attempt.
            await this.recordUnauthorized({
                actorId: this.replayActorId(input),
                reason: 'replay_window_exceeded',
                context: {
                    app: input.app,
                    since,
                    reason_detail: 'malformed_since',
                },
            });
            throw new ReplayWindowExceededError(since, REPLAY_WINDOW_DAYS);
        }
        const oldestAllowedMs =
            (input.now?.getTime() ?? Date.now()) -
            REPLAY_WINDOW_DAYS * 24 * 60 * 60 * 1000;
        if (sinceMs < oldestAllowedMs) {
            await this.recordUnauthorized({
                actorId: this.replayActorId(input),
                reason: 'replay_window_exceeded',
                context: {
                    app: input.app,
                    since,
                    replay_window_days: REPLAY_WINDOW_DAYS,
                },
            });
            throw new ReplayWindowExceededError(since, REPLAY_WINDOW_DAYS);
        }

        // Empty-result happy path (REQ 8.5a — in-window with no matches
        // returns HTTP 200 + empty list; the upstream sync layer maps
        // this to the empty `notifications` array.)
        if (input.userIds.length === 0) {
            return { notifications: [], next_cursor: null };
        }

        const categories: readonly NotificationCategory[] = input.category
            ? [input.category]
            : ([
                  'billing',
                  'orders',
                  'payments',
                  'inventory',
                  'users',
                  'system',
                  'delivery',
                  'reports',
              ] as const);

        const collected: NotificationRecord[] = [];
        for (const userId of input.userIds) {
            for (const category of categories) {
                let cursor: string | null | undefined = null;
                // Walk pages — `listByUserCategory` returns 50 per page by
                // default. The Replay_Window-bounded result set is
                // capped (~7 days × per-user volume), so this loop
                // terminates quickly.
                while (true) {
                    const page = await listByUserCategory(
                        {
                            user_id: userId,
                            category,
                            cursor,
                            scanForward: true,
                        },
                        this.storeOptions,
                    );
                    for (const item of page.items) {
                        if (Date.parse(item.created_at) >= sinceMs) {
                            collected.push(item);
                        }
                    }
                    if (!page.next_cursor) break;
                    cursor = page.next_cursor;
                }
            }
        }

        // Sort ascending by created_at (REQ 8.4).
        collected.sort((a, b) => a.created_at.localeCompare(b.created_at));

        logger.info('[Notification_Service] getReplay', {
            app: input.app,
            since,
            userIds: input.userIds.length,
            returned: collected.length,
        });

        return { notifications: collected, next_cursor: null };
    }

    // ------------------------------------------------------------------
    // Internal helpers
    // ------------------------------------------------------------------

    /**
     * Record an `unauthorized_access_attempt` Audit_Log entry (REQ 12.7).
     *
     * The class-level wrapper threads the constructor's storeOptions
     * through so the audit row lands in the same DynamoDB table as
     * every other audit entry.
     *
     * Best-effort: errors from the underlying append are swallowed by
     * `recordUnauthorizedAccessAttempt` so the calling denial path keeps
     * its user-visible behaviour even when the AuditLog is unavailable
     * (REQ 12.7 sentence: the entry is required, but blocking the
     * denial response on AuditLog availability would cascade outages
     * — the warn log triggers the CloudWatch alarm in task 17.x).
     */
    private async recordUnauthorized(
        input: {
            readonly actorId: string;
            readonly reason: UnauthorizedAccessReason;
            readonly notificationId?: string | null;
            readonly context?: Record<string, unknown>;
        },
    ): Promise<void> {
        await recordUnauthorizedAccessAttempt(
            {
                actorId: input.actorId,
                reason: input.reason,
                notificationId: input.notificationId ?? null,
                context: input.context,
            },
            this.storeOptions,
        );
    }

    /**
     * Owner-or-admin predicate for preferences read/write operations.
     * Mirrors the privileged-roles set used by `DefaultCallerAuthorizer`
     * so the two surfaces share one definition of administrator.
     */
    private isOwnerOrAdmin(caller: PreferencesCaller, userId: string): boolean {
        if (!caller.user_id || caller.user_id.trim() === '') return false;
        if (caller.user_id === userId) return true;
        return PRIVILEGED_PREFERENCE_ROLES.has(caller.role);
    }

    /**
     * Resolve the actor id for a getReplay denial. Replay calls do not
     * carry an explicit caller field; the convention used by the
     * lambda handler (sync/replay.handler.ts) is to pass the caller's
     * own user_id as the only entry in `userIds`. We surface that as
     * the actor on the audit row, falling back to `'anonymous'` if the
     * caller did not supply any id.
     */
    private replayActorId(input: GetReplayInput): string {
        const first = input.userIds[0];
        return first && first.trim() !== '' ? first : 'anonymous';
    }

    /**
     * Wrap `appendAuditLog` so a transient AuditLog write failure does
     * NOT abort the calling operation. The lifecycle write is the
     * primary durability boundary; the AuditLog is a secondary trail
     * (every transition is also reflected in the structured logs in
     * task 17.1). We log + swallow here and rely on CloudWatch alarms
     * to catch sustained AuditLog outages.
     *
     * Rationale: REQ 14.1 + 14.2 require structured logs and metrics;
     * those are emitted by `logger.info` calls above and by the
     * observability module landing in task 17. The AuditLog (REQ 6.3)
     * is the durable system of record — but blocking a `dispatch` on
     * AuditLog availability would cascade outages.
     */
    private async safeAppendAudit(
        record: AuditLogRecord,
    ): Promise<void> {
        try {
            await appendAuditLog(record, this.storeOptions);
        } catch (err) {
            logger.warn(
                '[Notification_Service] AuditLog append failed — ' +
                    'continuing without trail entry',
                {
                    notification_id: record.notification_id,
                    lifecycle_state: record.lifecycle_state,
                    error: err instanceof Error ? err.message : String(err),
                },
            );
        }
    }
}

// ---- getReplay input -----------------------------------------------------

export interface GetReplayInput {
    /** ISO-8601 `since` timestamp. Older than `REPLAY_WINDOW_DAYS` is rejected. */
    readonly since: string;
    /** Sub_App identifier (used for logging / observability). */
    readonly app: string;
    /**
     * User ids to fan the replay query out across. Once task 10.1 lands the
     * full Sub_App→user resolution this becomes optional.
     */
    readonly userIds: readonly string[];
    /** Optional category filter; default: every category. */
    readonly category?: NotificationCategory;
    /** Stable "now" for tests. */
    readonly now?: Date;
}

// ---- Preference payload validator ---------------------------------------
//
// REQ 4.8: `setUserPreferences` validates the supplied payload against the
// preferences schema. We do the type-level checks here; the structural
// shape (Partial<Record<NotificationCategory, ...>>) is enforced by
// TypeScript at compile time on backend callers. We only need to refuse
// values that TypeScript cannot reject (e.g. callers crossing the wire).

const VALID_CATEGORIES = new Set<string>([
    'billing',
    'orders',
    'payments',
    'inventory',
    'users',
    'system',
    'delivery',
    'reports',
]);
const VALID_CHANNELS = new Set<string>([
    'in_app',
    'push',
    'sms',
    'email',
    'webhook',
]);

function validatePreferencePayload(input: SetUserPreferencesInput): void {
    if (input.per_category_channels) {
        for (const [cat, channels] of Object.entries(input.per_category_channels)) {
            if (!VALID_CATEGORIES.has(cat)) {
                throw new PreferenceValidationError(
                    `Unknown category '${cat}' in per_category_channels.`,
                );
            }
            assertChannelArray(channels, `per_category_channels[${cat}]`);
        }
    }
    if (input.per_event_channels) {
        for (const [event, channels] of Object.entries(input.per_event_channels)) {
            if (!EVENT_NAME_RE.test(event)) {
                throw new PreferenceValidationError(
                    `Invalid event_name '${event}' in per_event_channels.`,
                );
            }
            assertChannelArray(channels, `per_event_channels[${event}]`);
        }
    }
    assertQuietHoursPair(
        input.quiet_hours_start ?? null,
        input.quiet_hours_end ?? null,
        input.quiet_hours_timezone ?? null,
    );
}

function assertChannelArray(
    value: readonly string[] | undefined,
    location: string,
): void {
    if (!value) return;
    for (const channel of value) {
        if (!VALID_CHANNELS.has(channel)) {
            throw new PreferenceValidationError(
                `Unknown channel '${channel}' at ${location}.`,
            );
        }
    }
}

function assertQuietHoursPair(
    start: string | null,
    end: string | null,
    tz: string | null,
): void {
    const allNull = start === null && end === null && tz === null;
    const allSet = start !== null && end !== null && tz !== null;
    if (!allNull && !allSet) {
        throw new PreferenceValidationError(
            'quiet_hours_start, quiet_hours_end, and quiet_hours_timezone ' +
                'must all be set or all be null.',
        );
    }
    if (allSet) {
        if (!/^\d{2}:\d{2}$/.test(start as string)) {
            throw new PreferenceValidationError(
                `quiet_hours_start must be HH:MM, received '${start}'.`,
            );
        }
        if (!/^\d{2}:\d{2}$/.test(end as string)) {
            throw new PreferenceValidationError(
                `quiet_hours_end must be HH:MM, received '${end}'.`,
            );
        }
        if ((tz as string).trim() === '') {
            throw new PreferenceValidationError(
                'quiet_hours_timezone must be a non-empty IANA timezone name.',
            );
        }
    }
}

// ---- Module-level convenience instance ----------------------------------
//
// A single shared instance with default wiring. Production callers in
// HTTP handlers (lambdas/handlers/notifications/*) construct their own
// instance with the production RecipientAuthorizer + Delivery_Layer
// adapter; this default exists so simple use cases (a producer Lambda
// emitting a critical event) can `import { notificationService }` and
// call `createNotification` without boilerplate.

let cachedDefaultService: NotificationService | null = null;

export function getDefaultNotificationService(): NotificationService {
    if (!cachedDefaultService) {
        cachedDefaultService = new NotificationService();
    }
    return cachedDefaultService;
}

/** Test seam: replace the cached default service. */
export function __setDefaultNotificationServiceForTesting(
    service: NotificationService | null,
): void {
    cachedDefaultService = service;
}

// Avoid unused-import warnings while keeping the tools available to
// future maintainers who can drop the underscore prefix when they need
// these store-level helpers.
void findByDedupKey;
