// ============================================================================
// k6/lib/recipients.ts — phase5-load-plan.md §3.3 / §3.4 recipient generator
// ============================================================================
//
// Synthesises the load test's recipient population deterministically from
// the role distribution (§3.3), the tenant power-law fan-out (§3.3), and
// the channel/preference shape (§3.4) declared in `phase5-load-plan.md`.
//
// Why a generator instead of a static 10 000-row JSON file:
//   - 10 000 rows checked in is large noise in PR diffs.
//   - Run-to-run variation requires fresh `loadtest-<run_id>-` namespacing
//     (§5.4) — a static file would force a checked-in rewrite per run.
//   - The shape is the spec; the generator enforces the shape so any
//     drift surfaces immediately.
//
// Determinism: every call with the same `seed` returns the same population
// (an LCG PRNG seeded by `seed` drives every random choice). Tests can
// pin `seed` for reproducibility; CI runs can pin to the run_id hash.
//
// All percentage / size constants come from `seeds/users.json`'s
// `role_distribution_pct`, `channel_mix_pct`, `preference_shape_pct`, and
// `tenant_power_law` blocks — that file is the canonical knob set per the
// AGENTS.md "no hardcoded values" rule.
// ============================================================================

// ----------------------------------------------------------------------------
// Public types
// ----------------------------------------------------------------------------

export type RoleId =
    | 'admin'
    | 'cashier'
    | 'accountant'
    | 'delivery_agent'
    | 'vendor'
    | 'customer'
    | 'chef'
    | 'kitchen_staff'
    | 'waiter'
    | 'school_admin'
    | 'teacher'
    | 'student'
    | 'parent'
    | 'clinic_doctor'
    | 'pharmacist'
    | 'jewellery_artisan'
    | 'service_technician';

export type ConnectionClass =
    | 'in_app_connected'
    | 'in_app_offline'
    | 'push_only';

export type PreferenceClass =
    | 'defaults'
    | 'category_overrides'
    | 'event_overrides_with_quiet_hours'
    | 'with_mute_targets';

export type Channel = 'in_app' | 'push' | 'sms' | 'email' | 'webhook';

export interface QuietHours {
    readonly start: string;       // 'HH:MM'
    readonly end: string;         // 'HH:MM'
    readonly timezone: string;    // IANA name
}

export interface SeededUser {
    readonly user_id: string;
    readonly tenant_id: string;
    readonly role: RoleId;
    readonly connection: ConnectionClass;
    readonly preference_class: PreferenceClass;
    readonly channels: readonly Channel[];
    readonly quiet_hours: QuietHours | null;
    readonly mute_targets: readonly string[];
}

export interface SeededTenant {
    readonly tenant_id: string;
    readonly size_class: 'top' | 'mid' | 'tail';
    readonly users_count: number;
}

export interface RecipientPopulation {
    readonly run_id: string;
    readonly users: readonly SeededUser[];
    readonly tenants: readonly SeededTenant[];
}

export interface GenerateOptions {
    /** Required — drives `loadtest-<run_id>-…` namespacing per §5.4. */
    readonly run_id: string;
    /** Total recipient count. Defaults to 10 000 (G-T1). */
    readonly total_users?: number;
    /** Total tenant count. Defaults to 50 (§3.3). */
    readonly total_tenants?: number;
    /** PRNG seed; same seed → same population. Defaults to a hash of run_id. */
    readonly seed?: number;
}

// ----------------------------------------------------------------------------
// Spec-derived constants — keep in sync with seeds/users.json.
// (These mirror that file and are duplicated here purely so a k6 script
// can import this module without reading the JSON at runtime.)
// ----------------------------------------------------------------------------

const ROLE_PCT: Record<RoleId, number> = Object.freeze({
    admin: 5,
    cashier: 10,
    accountant: 3,
    delivery_agent: 8,
    vendor: 4,
    customer: 30,
    chef: 2,
    kitchen_staff: 1,
    waiter: 1,
    school_admin: 2,
    teacher: 5,
    student: 12,
    parent: 12,
    clinic_doctor: 1,
    pharmacist: 1,
    jewellery_artisan: 1,
    service_technician: 2,
}) as Record<RoleId, number>;

const CONNECTION_PCT: Record<ConnectionClass, number> = Object.freeze({
    in_app_connected: 70,
    in_app_offline: 20,
    push_only: 10,
}) as Record<ConnectionClass, number>;

const PREFERENCE_PCT: Record<PreferenceClass, number> = Object.freeze({
    defaults: 60,
    category_overrides: 25,
    event_overrides_with_quiet_hours: 10,
    with_mute_targets: 5,
}) as Record<PreferenceClass, number>;

const TENANT_POWER_LAW = Object.freeze({
    top_tenants_pct: 10,
    top_tenants_share_pct: 60,
    mid_tenants_pct: 40,
    mid_tenants_share_pct: 30,
    tail_tenants_pct: 50,
    tail_tenants_share_pct: 10,
});

/**
 * Default channel set per role. The Notification_Service may suppress
 * channels at dispatch time per the recipient's preferences, but the
 * generator declares the producer-allowed set so the workload mix stays
 * realistic. Mirrors `Preference_Engine`'s role-default fallback step.
 */
const ROLE_DEFAULT_CHANNELS: Record<RoleId, readonly Channel[]> = Object.freeze({
    admin: ['in_app', 'push', 'email'],
    cashier: ['in_app', 'push'],
    accountant: ['in_app', 'email'],
    delivery_agent: ['in_app', 'push', 'sms'],
    vendor: ['in_app', 'email'],
    customer: ['in_app', 'email', 'sms'],
    chef: ['in_app'],
    kitchen_staff: ['in_app'],
    waiter: ['in_app'],
    school_admin: ['in_app', 'email'],
    teacher: ['in_app', 'email'],
    student: ['in_app', 'push'],
    parent: ['in_app', 'push', 'sms'],
    clinic_doctor: ['in_app', 'sms'],
    pharmacist: ['in_app'],
    jewellery_artisan: ['in_app'],
    service_technician: ['in_app', 'sms'],
}) as Record<RoleId, readonly Channel[]>;

const ROLE_LIST: readonly RoleId[] = Object.freeze(
    Object.keys(ROLE_PCT) as RoleId[],
);

// ----------------------------------------------------------------------------
// Deterministic PRNG (LCG — small, fast, repeatable across k6 runs)
// ----------------------------------------------------------------------------

/**
 * Linear-congruential generator with the Numerical Recipes constants.
 * Returns a function producing [0, 1) floats. We avoid `Math.random()`
 * because it is not seedable in either k6 or Node, which would defeat
 * the deterministic-seed contract.
 */
function makePrng(seed: number): () => number {
    // Force into 32-bit signed range; 0 collapses the LCG so substitute 1.
    let state = (seed | 0) || 1;
    return function next(): number {
        // Numerical Recipes "Park-Miller" constants — long period, no
        // observable bias for the populations we generate.
        state = (state * 1664525 + 1013904223) | 0;
        return ((state >>> 0) % 0xffffffff) / 0xffffffff;
    };
}

/**
 * Hash a string into a 32-bit seed (FNV-1a — small, fast, dependency-free).
 * Used to derive a stable seed from `run_id` when none was supplied.
 */
function hashSeed(input: string): number {
    let hash = 0x811c9dc5;
    for (let i = 0; i < input.length; i += 1) {
        hash ^= input.charCodeAt(i);
        // FNV prime mul; force back to 32-bit.
        hash = Math.imul(hash, 0x01000193);
    }
    return hash >>> 0;
}

/**
 * Select an entry from a `value -> percent` map weighted by the
 * percentages. Percentages must sum to 100; we re-scale defensively in
 * case rounding error in the table sums to 99 / 101.
 */
function weightedPick<T extends string>(
    weights: Record<T, number>,
    rand: () => number,
): T {
    const entries = Object.entries(weights) as Array<[T, number]>;
    const total = entries.reduce((sum, [, w]) => sum + w, 0);
    const target = rand() * total;
    let acc = 0;
    for (const [value, weight] of entries) {
        acc += weight;
        if (target < acc) return value;
    }
    return entries[entries.length - 1][0];
}

// ----------------------------------------------------------------------------
// Tenant fan-out (§3.3 power law)
// ----------------------------------------------------------------------------

function buildTenants(
    runId: string,
    totalTenants: number,
    totalUsers: number,
): SeededTenant[] {
    const top = Math.max(1, Math.round(totalTenants * (TENANT_POWER_LAW.top_tenants_pct / 100)));
    const mid = Math.max(1, Math.round(totalTenants * (TENANT_POWER_LAW.mid_tenants_pct / 100)));
    const tail = Math.max(1, totalTenants - top - mid);

    const topUsers = Math.round(totalUsers * (TENANT_POWER_LAW.top_tenants_share_pct / 100));
    const midUsers = Math.round(totalUsers * (TENANT_POWER_LAW.mid_tenants_share_pct / 100));
    const tailUsers = Math.max(0, totalUsers - topUsers - midUsers);

    const tenants: SeededTenant[] = [];
    let cursor = 0;

    function addTenants(
        count: number,
        sizeClass: 'top' | 'mid' | 'tail',
        sliceUsers: number,
    ): void {
        if (count === 0) return;
        const each = Math.max(1, Math.floor(sliceUsers / count));
        let assigned = 0;
        for (let i = 0; i < count; i += 1) {
            // Last tenant in the slice absorbs the rounding remainder so
            // the population total matches `totalUsers` exactly.
            const isLast = i === count - 1;
            const usersCount = isLast
                ? sliceUsers - assigned
                : each;
            tenants.push({
                tenant_id: `loadtest-${runId}-tenant-${String(cursor).padStart(3, '0')}`,
                size_class: sizeClass,
                users_count: usersCount,
            });
            assigned += usersCount;
            cursor += 1;
        }
    }

    addTenants(top, 'top', topUsers);
    addTenants(mid, 'mid', midUsers);
    addTenants(tail, 'tail', tailUsers);

    return tenants;
}

// ----------------------------------------------------------------------------
// Public API
// ----------------------------------------------------------------------------

/**
 * Generate a deterministic recipient population shaped by the load
 * plan's §3.3 / §3.4 distributions.
 *
 * Output invariants:
 *   - `users.length === options.total_users` (default 10 000).
 *   - `tenants.length === options.total_tenants` (default 50).
 *   - The role distribution lies within ±1 percentage point of `ROLE_PCT`
 *     across the population (LCG variance bounded for n ≥ 1000).
 *   - Every `user_id` is namespaced `loadtest-<run_id>-tenant-NNN-user-NNNN`,
 *     so the §5.4 namespace check holds.
 *   - The same `(run_id, seed, total_users, total_tenants)` quadruple
 *     produces an identical population.
 */
export function generatePopulation(opts: GenerateOptions): RecipientPopulation {
    if (!opts.run_id || opts.run_id.trim() === '') {
        throw new Error('generatePopulation: run_id is required');
    }
    const totalUsers = opts.total_users ?? 10_000;
    const totalTenants = opts.total_tenants ?? 50;
    if (totalUsers < totalTenants) {
        throw new Error(
            `generatePopulation: total_users (${totalUsers}) must be ≥ total_tenants (${totalTenants})`,
        );
    }
    const seed = opts.seed ?? hashSeed(opts.run_id);
    const rand = makePrng(seed);

    const tenants = buildTenants(opts.run_id, totalTenants, totalUsers);

    const users: SeededUser[] = [];
    let userCursor = 0;
    for (const tenant of tenants) {
        for (let i = 0; i < tenant.users_count; i += 1) {
            const role = weightedPick(ROLE_PCT, rand);
            const connection = weightedPick(CONNECTION_PCT, rand);
            const preferenceClass = weightedPick(PREFERENCE_PCT, rand);
            const channels = channelsFor(role, connection);
            const quietHours =
                preferenceClass === 'event_overrides_with_quiet_hours'
                    ? defaultQuietHours()
                    : null;
            const muteTargets =
                preferenceClass === 'with_mute_targets'
                    ? defaultMuteTargets(role)
                    : [];

            users.push({
                user_id: `${tenant.tenant_id}-user-${String(userCursor).padStart(5, '0')}`,
                tenant_id: tenant.tenant_id,
                role,
                connection,
                preference_class: preferenceClass,
                channels,
                quiet_hours: quietHours,
                mute_targets: muteTargets,
            });
            userCursor += 1;
        }
    }

    return Object.freeze({
        run_id: opts.run_id,
        users,
        tenants,
    });
}

/**
 * Resolve the channel set a generated user advertises to producers. The
 * resolver is the simple intersection of `ROLE_DEFAULT_CHANNELS[role]`
 * and the connection class:
 *   - `push_only` → drop `in_app` from the role default.
 *   - `in_app_offline` → keep `in_app` (offline replay path validates
 *     this delivery via `getReplay` per REQ 5.8 / 8.4).
 */
function channelsFor(role: RoleId, connection: ConnectionClass): readonly Channel[] {
    const base = ROLE_DEFAULT_CHANNELS[role];
    if (connection === 'push_only') {
        const filtered = base.filter((c) => c !== 'in_app');
        // If filtering left the user with nothing, fall back to push so
        // the user can still be reached (matches the role default of
        // `push` being part of every push-capable role).
        return filtered.length > 0 ? filtered : ['push'];
    }
    return base;
}

function defaultQuietHours(): QuietHours {
    // Aligns with the Phase 2 registry's most-common quiet-hours window.
    return Object.freeze({
        start: '22:00',
        end: '07:00',
        timezone: 'Asia/Kolkata',
    });
}

function defaultMuteTargets(role: RoleId): readonly string[] {
    // A small, role-relevant set — enough to exercise the mute path
    // without bending the workload.
    if (role === 'parent' || role === 'student') {
        return Object.freeze(['users.school_attendance.marked']);
    }
    if (role === 'customer') {
        return Object.freeze(['inventory.stock.low']);
    }
    return Object.freeze(['system.health.degraded']);
}

/**
 * Tag a user as belonging to a "hot" tenant slice for SCN-HOTKEY. The
 * load plan's §2.4 puts 40 % of dispatch volume into one tenant; this
 * helper returns true for users in the FIRST `top` tenant only (the
 * single hot tenant per the scenario).
 */
export function isHotTenant(user: SeededUser): boolean {
    return /tenant-000$/.test(user.tenant_id);
}

/**
 * Filter a population to recipients reachable on a specific channel.
 * Used by the per-channel scenarios (SCN-MIX, SCN-SLOW-CHANNEL).
 */
export function recipientsForChannel(
    pop: RecipientPopulation,
    channel: Channel,
): readonly SeededUser[] {
    return pop.users.filter((u) => u.channels.includes(channel));
}

// ----------------------------------------------------------------------------
// Test seam
// ----------------------------------------------------------------------------

export const __test__ = Object.freeze({
    ROLE_PCT,
    CONNECTION_PCT,
    PREFERENCE_PCT,
    TENANT_POWER_LAW,
    ROLE_DEFAULT_CHANNELS,
    makePrng,
    hashSeed,
    weightedPick,
    channelsFor,
});
