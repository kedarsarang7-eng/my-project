// ============================================================================
// Preference_Engine — Channel Resolver
// ============================================================================
// Pure, stateless resolver that, given a notification + recipient + the
// recipient's UserPreference record + the current instant, returns the
// allowed channel set for that recipient.
//
// Resolution order (REQ 7.1, 7.2, 7.2a, design.md §"Preference Resolution
// Order", phase3-architecture.md §9.4):
//
//   1. Self-suppression                         — actor == recipient → []
//   2. Mute on `target_id` (or `event_name`)    — un-mutable critical bypasses
//   3. Resolve requested channel set:
//        a. UserPreference.per_event_channels[event_name]
//        b. UserPreference.per_category_channels[category]
//        c. ROLE_DEFAULT_CHANNELS[role]
//        d. SYSTEM_DEFAULT_CHANNELS
//   4. Intersect with the notification's declared channels
//      (the resolver MUST NOT add channels the producer never opted in to)
//   5. Quiet-hours suppression of `push`/`sms`/`email` for non-`critical`
//   6. `priority == critical` bypasses quiet-hours suppression
//
// The output is a fresh `Channel[]` (deduplicated, ordering preserved
// from the requested set). An empty array means "deliver nothing on any
// channel" — Notification_Service treats it as a silent suppression and
// records a `skipped` audit entry rather than a failure.
//
// This module is INTENTIONALLY decoupled from the Notification_Store: it
// reads its inputs from the caller. Notification_Service is responsible
// for loading the `UserPreferenceRecord` once per dispatch and handing it
// in. That keeps the resolver well under the <10 ms p95 budget (REQ 7.8)
// because the only work performed here is in-memory comparisons.
//
// Validates: REQ 7.1, 7.2, 7.2a, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8.
// ============================================================================

import type {
    NotificationCategory,
    NotificationChannel,
    NotificationPriority,
    UserPreferenceRecord,
} from '../store/types';
import { isInQuietHours } from './quiet-hours';
import {
    getRoleDefaultChannels,
    ROLE_DEFAULT_CHANNELS,
} from './role-defaults';

// ---- Resolver inputs / outputs -------------------------------------------

/**
 * Minimal notification view required by the resolver. We deliberately do
 * NOT take the full `NotificationRecord` so callers can short-circuit the
 * resolver before persistence is complete (e.g. dry-run preference
 * inspection from the Sub_App preferences page).
 */
export interface ResolverNotification {
    readonly event_name: string;
    readonly category: NotificationCategory;
    readonly priority: NotificationPriority;
    /** The actor performing the event (REQ 7.5 self-suppression). */
    readonly actor_id: string;
    /** The entity the event relates to (REQ 7.6 mute on target_id). */
    readonly target_id?: string | null;
    /**
     * Channels the producer declared on the notification. The resolver
     * intersects the recipient's preferences with this set so it can
     * never grow the channel surface.
     */
    readonly channels: readonly NotificationChannel[];
    /**
     * Per-event flags supplied from the Notification_Event_Registry
     * (Phase 2). The Notification_Service is responsible for populating
     * this object from the registry; the resolver only reads it.
     *
     * `unmutable` — when `true` AND `priority == 'critical'`, this event
     * bypasses the recipient's mute list. Per REQ 7.6 + glossary `Mute`,
     * mutes are overridable only by un-mutable critical events.
     */
    readonly flags?: ResolverNotificationFlags;
}

export interface ResolverNotificationFlags {
    readonly unmutable?: boolean;
}

/**
 * The recipient view passed to the resolver.
 */
export interface ResolverRecipient {
    readonly user_id: string;
    readonly role: string;
}

/**
 * Resolver input bundle. Keeping every field on a single object makes the
 * call site self-documenting and lets us add new fields without churning
 * call sites.
 */
export interface ResolverInput {
    readonly notification: ResolverNotification;
    readonly recipient: ResolverRecipient;
    /**
     * The recipient's UserPreference record, if any. `null` is the
     * "no preferences set" case — every level of the resolution order
     * after `per_event_channels`/`per_category_channels` still applies.
     */
    readonly preferences: UserPreferenceRecord | null;
    /** The instant used for quiet-hours evaluation. Defaults to `new Date()`. */
    readonly now?: Date;
}

/**
 * Why a particular channel set was chosen — surfaced for observability /
 * tests / debug logging. Not required by Notification_Service to dispatch.
 */
export type ResolutionReason =
    | 'self_suppressed'
    | 'muted'
    | 'per_event_channels'
    | 'per_category_channels'
    | 'role_default'
    | 'system_default';

export interface ResolverResult {
    /**
     * The allowed channel set after every rule has been applied.
     * Order is preserved from the requested set.
     */
    readonly channels: readonly NotificationChannel[];
    /** Why this particular base channel set was chosen. */
    readonly reason: ResolutionReason;
    /** Whether quiet-hours suppression actually fired for this evaluation. */
    readonly quietHoursApplied: boolean;
    /** Channels removed from the requested set (for audit / debugging). */
    readonly suppressedChannels: readonly NotificationChannel[];
}

// ---- Constants -----------------------------------------------------------

/**
 * Channels that quiet-hours suppression targets for non-`critical`
 * notifications (REQ 7.3). `in_app` and `webhook` are NEVER suppressed by
 * quiet hours — quiet hours protect the human from being interrupted on
 * personal devices, not from receiving messages in their workstation
 * inbox or from reaching downstream systems.
 */
const QUIET_HOURS_CHANNELS: ReadonlySet<NotificationChannel> = new Set([
    'push',
    'sms',
    'email',
]);

// ---- Helpers -------------------------------------------------------------

/**
 * Return whether the recipient has muted this notification.
 *
 * Per the task description and Phase 4 simplification, mutes are matched
 * against `mute_targets` using either:
 *   - the literal `target_id` (e.g. an order id, customer id), OR
 *   - the literal `event_name` (e.g. `inventory.stock.low`), OR
 *   - the compound `event_name:target_id` form for finer-grained mutes.
 *
 * The compound form lets a recipient mute "inventory.stock.low for
 * SKU-123" without muting every stock-low notification across the
 * catalogue.
 */
function isMuted(
    notification: ResolverNotification,
    preferences: UserPreferenceRecord | null,
): boolean {
    if (!preferences || preferences.mute_targets.length === 0) return false;
    const target = notification.target_id ?? '';
    const compound = target ? `${notification.event_name}:${target}` : null;
    for (const muted of preferences.mute_targets) {
        if (!muted) continue;
        if (target && muted === target) return true;
        if (muted === notification.event_name) return true;
        if (compound && muted === compound) return true;
    }
    return false;
}

/**
 * Resolve the *requested* channel set: the highest level of the
 * resolution order that yields a non-empty value wins. We deliberately
 * treat an explicitly-empty array at any level as "no preference at this
 * level" so a user can clear an override and fall through to the role
 * default without having to delete the key.
 */
function resolveRequestedChannels(
    notification: ResolverNotification,
    recipient: ResolverRecipient,
    preferences: UserPreferenceRecord | null,
): { channels: readonly NotificationChannel[]; reason: ResolutionReason } {
    if (preferences) {
        // 1) per_event_channels (REQ 7.2)
        const perEvent =
            preferences.per_event_channels?.[notification.event_name];
        if (perEvent && perEvent.length > 0) {
            return { channels: perEvent, reason: 'per_event_channels' };
        }

        // 2) per_category_channels (REQ 7.2a)
        const perCategory =
            preferences.per_category_channels?.[notification.category];
        if (perCategory && perCategory.length > 0) {
            return { channels: perCategory, reason: 'per_category_channels' };
        }
    }

    // 3) Role-level default. `getRoleDefaultChannels` falls through to
    //    the system default for unknown roles, so we always get a
    //    non-null answer here. We still report `role_default` vs
    //    `system_default` honestly so audits can tell which level fired.
    const roleEntryExists = Object.prototype.hasOwnProperty.call(
        ROLE_DEFAULT_CHANNELS,
        recipient.role,
    );
    return {
        channels: getRoleDefaultChannels(recipient.role),
        reason: roleEntryExists ? 'role_default' : 'system_default',
    };
}

/**
 * Deduplicate while preserving first-seen ordering. The resolver returns
 * the channels in the order they were requested so callers can rely on
 * deterministic output for tests and audits. A `Set` alone would lose the
 * order; using `Set` for the membership check + an `Array` for output keeps
 * both invariants.
 */
function dedupePreserveOrder(
    channels: readonly NotificationChannel[],
): NotificationChannel[] {
    const seen = new Set<NotificationChannel>();
    const out: NotificationChannel[] = [];
    for (const c of channels) {
        if (!seen.has(c)) {
            seen.add(c);
            out.push(c);
        }
    }
    return out;
}

// ---- Public API ----------------------------------------------------------

/**
 * Pure resolution function. The single entry point of the
 * Preference_Engine.
 *
 * Stateless: no I/O, no DynamoDB call. Notification_Service is
 * responsible for fetching the `UserPreferenceRecord` once per dispatch
 * (typically once per recipient) before invoking this function.
 *
 * The implementation walks each rule in documented order and exits as
 * soon as a rule produces a definitive answer (`[]` for suppression
 * cases). Worst-case work is bounded by:
 *   - one `Set` membership check per `mute_targets` entry,
 *   - one timezone conversion in `isInQuietHours`,
 *   - one O(channels) loop for the final intersection.
 *
 * Empirically this runs well under the <10 ms p95 budget (REQ 7.8).
 */
export function resolveChannels(input: ResolverInput): ResolverResult {
    const { notification, recipient, preferences } = input;
    const now = input.now ?? new Date();

    // ---- 1. Self-suppression (REQ 7.5) -------------------------------
    if (notification.actor_id && notification.actor_id === recipient.user_id) {
        return {
            channels: [],
            reason: 'self_suppressed',
            quietHoursApplied: false,
            suppressedChannels: [...notification.channels],
        };
    }

    // ---- 2. Mute (REQ 7.6) -------------------------------------------
    // Mutes apply to every channel; only an un-mutable critical event
    // overrides them. The `unmutable` flag is supplied by the registry
    // through `notification.flags.unmutable` and is meaningful only when
    // priority is `critical` (per the glossary `Mute` definition).
    if (isMuted(notification, preferences)) {
        const isUnmutableCritical =
            notification.priority === 'critical' &&
            notification.flags?.unmutable === true;
        if (!isUnmutableCritical) {
            return {
                channels: [],
                reason: 'muted',
                quietHoursApplied: false,
                suppressedChannels: [...notification.channels],
            };
        }
    }

    // ---- 3. Resolve requested channel set ---------------------------
    const { channels: requested, reason } = resolveRequestedChannels(
        notification,
        recipient,
        preferences,
    );

    // ---- 4. Intersect with the producer's declared channels ---------
    // The resolver MUST NOT widen the channel surface beyond what the
    // producer already declared on the notification. If a recipient has
    // `email` in their preferences but the producer never sent the
    // notification on `email`, we still cannot deliver via email — there
    // is no email payload to send.
    const producerChannels = new Set<NotificationChannel>(notification.channels);
    const allowed: NotificationChannel[] = [];
    for (const channel of dedupePreserveOrder(requested)) {
        if (producerChannels.has(channel)) {
            allowed.push(channel);
        }
    }

    // ---- 5. Quiet-hours suppression for non-`critical` --------------
    // Critical events bypass quiet hours unconditionally (REQ 7.4).
    let quietHoursApplied = false;
    let postQuietHours: NotificationChannel[] = allowed;
    if (notification.priority !== 'critical' && preferences) {
        const evaluation = isInQuietHours(now, preferences);
        if (evaluation.inQuietHours) {
            quietHoursApplied = true;
            postQuietHours = allowed.filter(
                (c) => !QUIET_HOURS_CHANNELS.has(c),
            );
        }
    }

    // ---- 6. Compute suppression diff for observability --------------
    const finalSet = new Set<NotificationChannel>(postQuietHours);
    const suppressed: NotificationChannel[] = [];
    for (const c of notification.channels) {
        if (!finalSet.has(c)) suppressed.push(c);
    }

    return {
        channels: postQuietHours,
        reason,
        quietHoursApplied,
        suppressedChannels: suppressed,
    };
}

/**
 * Convenience wrapper that returns only the allowed channel array — the
 * shape Notification_Service.dispatch typically wants. Equivalent to
 * `resolveChannels(input).channels`.
 */
export function resolveAllowedChannels(
    input: ResolverInput,
): readonly NotificationChannel[] {
    return resolveChannels(input).channels;
}
