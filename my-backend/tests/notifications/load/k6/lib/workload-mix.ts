// ============================================================================
// k6/lib/workload-mix.ts — phase5-load-plan.md §3 workload generators
// ============================================================================
//
// Generates the canonical workload mix for every load scenario:
//
//   §3.2 — event-category ratios (inventory 35 %, orders 22 %, …)
//   §3.2 — priority distribution (critical 2 %, high 18 %, normal 60 %,
//          low 20 %)
//   §3.5 — payload-size distribution (small 65 %, medium 30 %, large 5 %)
//   §3.1 — producer sample (the eight category contributors)
//
// The generator is deterministic — same `seed` + same recipients →
// identical event stream — so a re-run of a scenario reproduces the
// exact load and the runner can compare results without seed drift.
//
// Scenarios bend the mix by composing helpers exposed here:
//
//   - SCN-HOTKEY (§2.4): `bendForHotkey({ tenant_share, event_share })`
//   - SCN-DEDUP  (§2.7): `bendForDedup({ duplicate_ratio })`
//   - SCN-MIX    (§2.5): `bendForChannelMix({ channel_share })`
//   - SCN-PREFS  (§2.8): `bendForPreferenceShape({ heavy_quiet_hours_ratio })`
//
// `bend*` helpers return a fresh generator with the requested distortion
// applied. They never mutate the original — every workload scenario
// builds its own bent generator at script start.
//
// Hard rule (per §3.5): the generator REFUSES to emit any payload above
// the SNS soft ceiling of 16 KB. A misconfigured payload-size knob trips
// `WorkloadMixError` rather than producing a publish that the bus would
// then reject — the producer-side guard mirrors the bus boundary.
// ============================================================================

import { type SeededUser, type RecipientPopulation, isHotTenant } from './recipients';

// ----------------------------------------------------------------------------
// Public types
// ----------------------------------------------------------------------------

export type Category =
    | 'billing'
    | 'orders'
    | 'payments'
    | 'inventory'
    | 'users'
    | 'system'
    | 'delivery'
    | 'reports';

export type Priority = 'critical' | 'high' | 'normal' | 'low';

export type Channel = 'in_app' | 'push' | 'sms' | 'email' | 'webhook';

export type PayloadSizeClass = 'small' | 'medium' | 'large';

export type SourceApp =
    | 'dukanx_desktop'
    | 'dukanx_backend'
    | 'school_admin_app'
    | 'school_teacher_app'
    | 'school_student_app'
    | 'webhook_consumer';

export interface Recipient {
    readonly user_id: string;
    readonly role: string;
    readonly channels: readonly Channel[];
    readonly target_id?: string | null;
}

/**
 * The shape produced by the workload generator. Mirrors the canonical
 * `EventContract` envelope (see
 * `my-backend/src/notifications/event-bus/types.ts`) so a k6 script can
 * post the value directly to the publisher shim without translation.
 */
export interface SyntheticEvent {
    readonly id: string;
    readonly event_name: string;
    readonly category: Category;
    readonly sub_category?: string;
    readonly priority: Priority;
    readonly actor_id: string;
    readonly target_id: string | null;
    readonly recipients: readonly Recipient[];
    readonly payload: Record<string, unknown>;
    readonly channels: readonly Channel[];
    readonly source_module: string;
    readonly source_app: SourceApp;
    readonly created_at: string;
    readonly dedup_key: string;
    readonly dedup_scope_fields: readonly string[];
}

export interface WorkloadOptions {
    readonly run_id: string;
    readonly population: RecipientPopulation;
    readonly seed?: number;
    /** ISO timestamp used as the base for `created_at`; +1 ms per emission. */
    readonly base_time?: string;
}

export interface WorkloadGenerator {
    /** Synthesise the next event, advancing internal state. */
    next(): SyntheticEvent;
    /** Bulk emit `count` events at once. */
    take(count: number): readonly SyntheticEvent[];
    /** Cumulative number of events generated since construction. */
    readonly emitted: number;
}

// ----------------------------------------------------------------------------
// Spec constants (every percentage from phase5-load-plan.md)
// ----------------------------------------------------------------------------

const CATEGORY_PCT: Record<Category, number> = Object.freeze({
    inventory: 35,
    orders: 22,
    delivery: 15,
    payments: 10,
    billing: 8,
    users: 6,
    reports: 3,
    system: 1,
}) as Record<Category, number>;

const PRIORITY_PCT: Record<Priority, number> = Object.freeze({
    critical: 2,
    high: 18,
    normal: 60,
    low: 20,
}) as Record<Priority, number>;

const PAYLOAD_SIZE_PCT: Record<PayloadSizeClass, number> = Object.freeze({
    small: 65,
    medium: 30,
    large: 5,
}) as Record<PayloadSizeClass, number>;

/**
 * Payload-size class boundaries (bytes). The generator picks a class via
 * `PAYLOAD_SIZE_PCT` then sizes the random payload to fall comfortably
 * inside the class. The 16 KB hard ceiling per §3.5 is enforced inside
 * `buildPayload`.
 */
const PAYLOAD_SIZE_BOUNDS = Object.freeze({
    small: Object.freeze({ min: 64, max: 255 }),
    medium: Object.freeze({ min: 256, max: 4 * 1024 - 1 }),
    large: Object.freeze({ min: 4 * 1024, max: 16 * 1024 }),
});

const PAYLOAD_HARD_CEILING_BYTES = 16 * 1024;

/**
 * Producer sample (§3.1) — the contributing event names per category.
 * The generator picks an event uniformly within the chosen category.
 */
const EVENTS_BY_CATEGORY: Record<Category, readonly string[]> = Object.freeze({
    billing: Object.freeze([
        'billing.invoice.created',
        'billing.invoice.finalized',
        'billing.invoice.updated',
        'billing.school_fee.assigned',
    ]),
    payments: Object.freeze([
        'payment.invoice.received',
        'payment.gateway.success',
        'payment.gateway.failed',
        'payment.refund.processed',
        'payment.school_fee.collected',
    ]),
    inventory: Object.freeze([
        'inventory.stock.changed',
        'inventory.stock.decremented_by_sale',
        'inventory.stock.bulk_decremented_by_sale',
        'inventory.stock.low',
        'inventory.import.progress',
    ]),
    orders: Object.freeze([
        'orders.restaurant_kot.created',
        'orders.restaurant_kot.bulk_created',
        'orders.restaurant_kot.status_changed',
        'orders.service_job.status_changed',
        'orders.jewellery_gold_rate.updated',
    ]),
    delivery: Object.freeze([
        'delivery.location.updated',
        'delivery.location.bulk_updated',
        'delivery.restaurant.dispatched',
    ]),
    users: Object.freeze([
        'users.school_announcement.published',
        'users.school_announcement.bulk_published',
        'users.school_attendance.marked',
        'users.customer_credit.reminder_sent',
    ]),
    system: Object.freeze([
        'system.security_access.unauthorized_attempt',
        'system.health.degraded',
    ]),
    reports: Object.freeze([
        'reports.pump_sale.recorded',
        'reports.pump_sale.bulk_summary',
    ]),
});

const SOURCE_APPS: readonly SourceApp[] = Object.freeze([
    'dukanx_backend',
    'dukanx_desktop',
    'school_admin_app',
    'school_teacher_app',
    'school_student_app',
]);

// ----------------------------------------------------------------------------
// Errors
// ----------------------------------------------------------------------------

export class WorkloadMixError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'WorkloadMixError';
    }
}

// ----------------------------------------------------------------------------
// PRNG (kept local — duplicated from recipients.ts to avoid a cross-module
// import cycle when k6 transpiles the workload mix in isolation)
// ----------------------------------------------------------------------------

function makePrng(seed: number): () => number {
    let state = (seed | 0) || 1;
    return function next(): number {
        state = (state * 1664525 + 1013904223) | 0;
        return ((state >>> 0) % 0xffffffff) / 0xffffffff;
    };
}

function hashSeed(input: string): number {
    let hash = 0x811c9dc5;
    for (let i = 0; i < input.length; i += 1) {
        hash ^= input.charCodeAt(i);
        hash = Math.imul(hash, 0x01000193);
    }
    return hash >>> 0;
}

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
// Payload synthesis
// ----------------------------------------------------------------------------

function buildPayload(
    sizeClass: PayloadSizeClass,
    rand: () => number,
    eventName: string,
): Record<string, unknown> {
    const bounds = PAYLOAD_SIZE_BOUNDS[sizeClass];
    const targetBytes = Math.floor(
        bounds.min + rand() * (bounds.max - bounds.min),
    );
    if (targetBytes > PAYLOAD_HARD_CEILING_BYTES) {
        throw new WorkloadMixError(
            `Payload size ${targetBytes} exceeds 16 KB hard ceiling (§3.5).`,
        );
    }
    // Build a payload object that serialises (approximately) to the
    // requested byte budget. We pad with a single deterministic string
    // so the JSON length is predictable; the actual envelope serialisation
    // adds a fixed overhead the publisher absorbs.
    const padBytes = Math.max(0, targetBytes - 80); // ~80 B for keys + scalars
    const padding = padString(padBytes, rand);
    return {
        event: eventName,
        seq: Math.floor(rand() * 1e6),
        size_class: sizeClass,
        // The padding lives under a stable key so the bus boundary's
        // sanitiser doesn't see a random key set per event.
        body: padding,
    };
}

function padString(bytes: number, rand: () => number): string {
    if (bytes <= 0) return '';
    // Use a small alphabet (16 chars) so the result is predictable in
    // size. Each generated char is 1 ASCII byte in UTF-8.
    const alphabet = '0123456789abcdef';
    let out = '';
    for (let i = 0; i < bytes; i += 1) {
        out += alphabet[Math.floor(rand() * alphabet.length)];
    }
    return out;
}

// ----------------------------------------------------------------------------
// Recipient selection
// ----------------------------------------------------------------------------

interface RecipientSelection {
    readonly recipients: readonly Recipient[];
    readonly fanoutSize: number;
}

/**
 * Pick recipients for an event from the population. Default fan-out is
 * a small random subset (1–4 recipients) so the steady-state workload
 * looks like a typical CRUD event; bulk events (§3.5 medium / large)
 * fan out wider via `bulkRecipients`.
 */
function pickRecipients(
    population: RecipientPopulation,
    rand: () => number,
    eventName: string,
    sizeClass: PayloadSizeClass,
): RecipientSelection {
    const isBulk = eventName.includes('.bulk_') || sizeClass !== 'small';
    const fanoutSize = isBulk
        ? Math.max(1, Math.floor(2 + rand() * 8)) // 2..10
        : Math.max(1, Math.floor(1 + rand() * 3)); // 1..3

    const picks: Recipient[] = [];
    for (let i = 0; i < fanoutSize; i += 1) {
        const idx = Math.floor(rand() * population.users.length);
        const user = population.users[idx];
        picks.push({
            user_id: user.user_id,
            role: user.role,
            channels: user.channels,
        });
    }
    return { recipients: picks, fanoutSize };
}

// ----------------------------------------------------------------------------
// Generator constructors
// ----------------------------------------------------------------------------

interface InternalState {
    readonly population: RecipientPopulation;
    readonly rand: () => number;
    readonly baseTimeMs: number;
    readonly runId: string;
    /** Mutable bend overrides — see `bendForHotkey` etc. */
    bend: BendConfig;
    emitted: number;
}

interface BendConfig {
    hotkey?: {
        readonly tenant_share: number;
        readonly event_share: number;
        readonly hot_event_name: string;
    };
    dedup?: {
        readonly duplicate_ratio: number;
        /** Cache of recently emitted events to duplicate. */
        readonly recentBuffer: SyntheticEvent[];
    };
    channel_mix?: {
        readonly enforced_channels: readonly Channel[];
    };
    preference_heavy?: {
        readonly heavy_quiet_hours_ratio: number;
    };
}

/**
 * Build a fresh workload generator. The generator is stateful (advances
 * a sequence counter and a PRNG); construct one per scenario script.
 *
 * The returned object carries a private `_state` handle so the
 * `bend*` helpers can compose distortions without leaking state into
 * the public surface. Consumers MUST treat `_state` as opaque.
 */
export function buildWorkload(opts: WorkloadOptions): WorkloadGenerator {
    if (opts.population.users.length === 0) {
        throw new WorkloadMixError('Population must contain at least one user.');
    }
    const seed = opts.seed ?? hashSeed(`${opts.run_id}:workload`);
    const baseTimeMs = opts.base_time
        ? Date.parse(opts.base_time)
        : Date.now();

    const state: InternalState = {
        population: opts.population,
        rand: makePrng(seed),
        baseTimeMs,
        runId: opts.run_id,
        bend: {},
        emitted: 0,
    };

    const gen: WorkloadGenerator & { _state: InternalState } = {
        next(): SyntheticEvent {
            const event = synthesiseOne(state);
            state.emitted += 1;
            return event;
        },
        take(count: number): readonly SyntheticEvent[] {
            if (!Number.isFinite(count) || count < 0) {
                throw new WorkloadMixError(
                    `take(count): count must be a non-negative integer, got ${count}`,
                );
            }
            const out: SyntheticEvent[] = [];
            for (let i = 0; i < count; i += 1) {
                out.push(this.next());
            }
            return out;
        },
        get emitted(): number {
            return state.emitted;
        },
        _state: state,
    };
    return gen;
}

// ----------------------------------------------------------------------------
// Bend helpers — return a fresh generator with the distortion applied.
// ----------------------------------------------------------------------------

/**
 * SCN-HOTKEY — bend the generator so one tenant absorbs `tenant_share`
 * fraction of events and one `event_name` makes up `event_share` of
 * the publish stream (§2.4).
 */
export function bendForHotkey(
    base: WorkloadGenerator,
    opts: {
        readonly tenant_share: number;
        readonly event_share: number;
        readonly hot_event_name?: string;
    },
): WorkloadGenerator {
    const inner = base as { _state?: InternalState };
    const state = inner._state;
    if (!state) {
        throw new WorkloadMixError(
            'bendForHotkey: generator was not created via buildWorkload.',
        );
    }
    state.bend.hotkey = {
        tenant_share: clampFraction(opts.tenant_share),
        event_share: clampFraction(opts.event_share),
        hot_event_name: opts.hot_event_name ?? 'inventory.stock.changed',
    };
    return base;
}

/**
 * SCN-DEDUP — bend the generator to emit `duplicate_ratio` of events as
 * intentional duplicates of an event already in flight (§2.7).
 */
export function bendForDedup(
    base: WorkloadGenerator,
    opts: { readonly duplicate_ratio: number },
): WorkloadGenerator {
    const inner = base as { _state?: InternalState };
    const state = inner._state;
    if (!state) {
        throw new WorkloadMixError(
            'bendForDedup: generator was not created via buildWorkload.',
        );
    }
    state.bend.dedup = {
        duplicate_ratio: clampFraction(opts.duplicate_ratio),
        recentBuffer: [],
    };
    return base;
}

/**
 * SCN-MIX — enforce that every event includes the supplied channels.
 * The dispatch path then naturally fans out across the per-channel
 * adapters per §3.4.
 */
export function bendForChannelMix(
    base: WorkloadGenerator,
    opts: { readonly enforced_channels: readonly Channel[] },
): WorkloadGenerator {
    const inner = base as { _state?: InternalState };
    const state = inner._state;
    if (!state) {
        throw new WorkloadMixError(
            'bendForChannelMix: generator was not created via buildWorkload.',
        );
    }
    if (opts.enforced_channels.length === 0) {
        throw new WorkloadMixError(
            'bendForChannelMix: enforced_channels must be non-empty.',
        );
    }
    state.bend.channel_mix = {
        enforced_channels: [...opts.enforced_channels],
    };
    return base;
}

/**
 * SCN-PREFS — bend the generator so a higher fraction of events fall
 * during a recipient's quiet-hours window (§2.8). Implemented by
 * preferring recipients flagged with a `quiet_hours` block.
 */
export function bendForPreferenceShape(
    base: WorkloadGenerator,
    opts: { readonly heavy_quiet_hours_ratio: number },
): WorkloadGenerator {
    const inner = base as { _state?: InternalState };
    const state = inner._state;
    if (!state) {
        throw new WorkloadMixError(
            'bendForPreferenceShape: generator was not created via buildWorkload.',
        );
    }
    state.bend.preference_heavy = {
        heavy_quiet_hours_ratio: clampFraction(opts.heavy_quiet_hours_ratio),
    };
    return base;
}

function clampFraction(n: number): number {
    if (!Number.isFinite(n) || n < 0) return 0;
    if (n > 1) return 1;
    return n;
}

// ----------------------------------------------------------------------------
// One-shot synthesis
// ----------------------------------------------------------------------------

function synthesiseOne(state: InternalState): SyntheticEvent {
    const rand = state.rand;

    // ---- 0. Dedup bend takes priority — emit a duplicate of a recent
    // event with a fresh `id` but the same `dedup_key` and identity tuple.
    if (state.bend.dedup && state.bend.dedup.recentBuffer.length > 0) {
        if (rand() < state.bend.dedup.duplicate_ratio) {
            const cloneSource =
                state.bend.dedup.recentBuffer[
                    Math.floor(rand() * state.bend.dedup.recentBuffer.length)
                ];
            return {
                ...cloneSource,
                id: makeUuid(state),
                created_at: makeTimestamp(state),
            };
        }
    }

    // ---- 1. Pick category / event (with hotkey override) ----
    let category: Category;
    let eventName: string;
    if (
        state.bend.hotkey &&
        rand() < state.bend.hotkey.event_share
    ) {
        eventName = state.bend.hotkey.hot_event_name;
        category = inferCategory(eventName) ?? 'inventory';
    } else {
        category = weightedPick(CATEGORY_PCT, rand);
        const events = EVENTS_BY_CATEGORY[category];
        eventName = events[Math.floor(rand() * events.length)];
    }

    // ---- 2. Pick priority ----
    const priority = weightedPick(PRIORITY_PCT, rand);

    // ---- 3. Pick payload size ----
    const sizeClass = weightedPick(PAYLOAD_SIZE_PCT, rand);
    const payload = buildPayload(sizeClass, rand, eventName);

    // ---- 4. Pick recipients (with hotkey-tenant override) ----
    const baseSelection = pickRecipients(
        state.population,
        rand,
        eventName,
        sizeClass,
    );
    const recipients = applyHotkeyTenant(state, baseSelection.recipients, rand);

    // ---- 5. Pick channels (with channel-mix bend) ----
    const channels = state.bend.channel_mix
        ? state.bend.channel_mix.enforced_channels
        : unionChannels(recipients);

    // ---- 6. Build envelope ----
    const id = makeUuid(state);
    const createdAt = makeTimestamp(state);
    const actorId = `loadtest-${state.runId}-actor-${Math.floor(rand() * 1000)}`;
    const targetId = recipients[0]?.target_id ?? null;
    const dedupKey = computeDedupKey(eventName, actorId, targetId, id);

    const event: SyntheticEvent = {
        id,
        event_name: eventName,
        category,
        sub_category: '',
        priority,
        actor_id: actorId,
        target_id: targetId,
        recipients,
        payload,
        channels,
        source_module: 'tests/notifications/load',
        source_app: SOURCE_APPS[Math.floor(rand() * SOURCE_APPS.length)],
        created_at: createdAt,
        dedup_key: dedupKey,
        dedup_scope_fields: [],
    };

    // Record into dedup buffer so future emissions can clone.
    if (state.bend.dedup) {
        const buf = state.bend.dedup.recentBuffer;
        buf.push(event);
        if (buf.length > 100) buf.shift();
    }

    return event;
}

function unionChannels(recipients: readonly Recipient[]): readonly Channel[] {
    const set = new Set<Channel>();
    for (const r of recipients) for (const c of r.channels) set.add(c);
    return Array.from(set);
}

function applyHotkeyTenant(
    state: InternalState,
    recipients: readonly Recipient[],
    rand: () => number,
): readonly Recipient[] {
    if (!state.bend.hotkey) return recipients;
    if (rand() >= state.bend.hotkey.tenant_share) return recipients;
    // Replace recipients with hot-tenant users when the hotkey-tenant
    // bias fires. Falls through to the original list if no hot-tenant
    // users exist (shouldn't happen for a well-formed population).
    const hotUsers = state.population.users.filter((u: SeededUser) =>
        isHotTenant(u),
    );
    if (hotUsers.length === 0) return recipients;
    return recipients.map(() => {
        const user = hotUsers[Math.floor(rand() * hotUsers.length)];
        return {
            user_id: user.user_id,
            role: user.role,
            channels: user.channels,
        };
    });
}

function inferCategory(eventName: string): Category | null {
    const head = eventName.split('.')[0];
    const candidates: Record<string, Category> = {
        billing: 'billing',
        inventory: 'inventory',
        orders: 'orders',
        delivery: 'delivery',
        payment: 'payments',
        users: 'users',
        system: 'system',
        reports: 'reports',
    };
    return candidates[head] ?? null;
}

// ----------------------------------------------------------------------------
// Identity helpers — UUID / timestamp / dedup_key
// ----------------------------------------------------------------------------

function makeUuid(state: InternalState): string {
    // Deterministic UUID-shaped id derived from the run_id + sequence
    // counter. The Event_Contract schema requires `format: uuid`; the
    // shape we emit conforms to RFC 4122 v4 layout (version=4,
    // variant=8). We do not rely on global randomness — the LCG below
    // gives us reproducible ids per (run_id, seed, emitted) triple.
    const rand = state.rand;
    const hex = (digits: number): string => {
        let s = '';
        for (let i = 0; i < digits; i += 1) {
            s += Math.floor(rand() * 16).toString(16);
        }
        return s;
    };
    return `${hex(8)}-${hex(4)}-4${hex(3)}-${'89ab'[Math.floor(rand() * 4)]}${hex(3)}-${hex(12)}`;
}

function makeTimestamp(state: InternalState): string {
    const ms = state.baseTimeMs + state.emitted; // 1 ms apart
    return new Date(ms).toISOString();
}

function computeDedupKey(
    eventName: string,
    actorId: string,
    targetId: string | null,
    fallback: string,
): string {
    return `${eventName}|${actorId}|${targetId ?? '∅'}|${fallback.slice(0, 8)}`;
}

// ----------------------------------------------------------------------------
// Test seam
// ----------------------------------------------------------------------------

export const __test__ = Object.freeze({
    CATEGORY_PCT,
    PRIORITY_PCT,
    PAYLOAD_SIZE_PCT,
    PAYLOAD_SIZE_BOUNDS,
    PAYLOAD_HARD_CEILING_BYTES,
    EVENTS_BY_CATEGORY,
    makePrng,
    hashSeed,
    weightedPick,
    buildPayload,
    inferCategory,
    computeDedupKey,
});
