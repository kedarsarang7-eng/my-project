// ============================================================================
// Preference_Engine — Role-Level Default Channel Mapping
// ============================================================================
// The third level in the resolution order documented in
//   .kiro/specs/unified-notification-system/design.md
//   §"Preference Resolution Order"
// and pinned in
//   .kiro/specs/unified-notification-system/phase3-architecture.md §9.4
//
// Resolution order (REQ 7.2, 7.2a):
//   1. UserPreference.per_event_channels[event_name]
//   2. UserPreference.per_category_channels[category]
//   3. role-level default (this file)
//   4. system default (this file — `SYSTEM_DEFAULT_CHANNELS`)
//
// Every value below is superseded by any value the user has set via
// `setUserPreferences` for that level. The mapping captures the *minimum
// viable* default channel set per role: enough for the role to do its
// job, nothing that would surprise a user who never opened the
// preferences page.
//
// Roles taken from `event-bus/types.ts::RecipientRole` (the canonical
// inventory derived from Phase 2 §3 — 22 roles).
//
// Validates: REQ 7.1, 7.2, 7.2a.
// ============================================================================

import type {
    NotificationChannel,
} from '../store/types';
import type { RecipientRole } from '../event-bus/types';

/**
 * The system-wide default channel set used when no role default is
 * declared. `in_app` only — every recipient with a connected client gets
 * the notification, no out-of-band noise on push/email/sms.
 */
export const SYSTEM_DEFAULT_CHANNELS: readonly NotificationChannel[] = [
    'in_app',
];

/**
 * Sensible per-role default channels. Keys are the canonical role
 * identifiers from `event-bus/types.ts::RecipientRole`. Any role not
 * listed here falls through to `SYSTEM_DEFAULT_CHANNELS`.
 *
 * Notes on the mapping:
 *   - Operators (`super_admin`, `admin`, `shop_owner`) get `in_app + push`
 *     so they receive operational alerts on their devices even when not
 *     actively in the desktop app.
 *   - Customer-facing roles get `in_app + push + email` so transactional
 *     receipts (invoice paid, order ready) reach them outside the app.
 *   - Field/floor roles (`cashier`, `chef`, `kitchen_staff`, `waiter`,
 *     `pump_attendant`) stay on `in_app` — they work on a single
 *     terminal during their shift.
 *   - Specialist roles (`teacher`, `student`, `parent`, etc.) get
 *     `in_app + push` so the sub-app's push channel is the primary
 *     reach.
 */
export const ROLE_DEFAULT_CHANNELS: Readonly<
    Partial<Record<RecipientRole, readonly NotificationChannel[]>>
> = {
    // ---- Operators -------------------------------------------------------
    super_admin: ['in_app', 'push', 'email'],
    admin: ['in_app', 'push'],
    shop_owner: ['in_app', 'push'],
    accountant: ['in_app', 'email'],

    // ---- Floor / shift-bound roles --------------------------------------
    cashier: ['in_app'],
    staff: ['in_app'],
    chef: ['in_app'],
    kitchen_staff: ['in_app'],
    waiter: ['in_app'],
    pump_attendant: ['in_app'],
    dc_staff: ['in_app'],

    // ---- Field roles -----------------------------------------------------
    delivery_agent: ['in_app', 'push'],
    service_technician: ['in_app', 'push'],
    jewellery_artisan: ['in_app'],

    // ---- External counterparties ----------------------------------------
    vendor: ['in_app', 'email'],
    customer: ['in_app', 'push', 'email'],
    farmer: ['in_app', 'push'],

    // ---- School sub-app roles -------------------------------------------
    school_admin: ['in_app', 'push', 'email'],
    teacher: ['in_app', 'push'],
    student: ['in_app', 'push'],
    parent: ['in_app', 'push'],

    // ---- Clinic / pharmacy -----------------------------------------------
    clinic_doctor: ['in_app', 'push'],
    pharmacist: ['in_app', 'push'],
};

/**
 * Resolve the role-level default channel set for `role`. Falls through to
 * `SYSTEM_DEFAULT_CHANNELS` for unknown or unmapped roles.
 *
 * Returned as a fresh array so callers can safely mutate it without
 * leaking back into the constants above.
 */
export function getRoleDefaultChannels(
    role: string,
): readonly NotificationChannel[] {
    const mapped =
        ROLE_DEFAULT_CHANNELS[role as RecipientRole] ?? SYSTEM_DEFAULT_CHANNELS;
    return [...mapped];
}
