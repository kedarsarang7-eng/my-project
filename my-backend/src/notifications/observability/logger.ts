// ============================================================================
// UNS — Structured Lifecycle Logger (Task 17.1, REQ 14.1)
// ============================================================================
//
// One log line per notification lifecycle transition. Each line is a single
// JSON object emitted through a pluggable sink (defaults to `console.log`).
//
// Lifecycle stages covered (REQ 14.1 + design observability section):
//
//     event_published      → an event has been accepted onto the bus
//     notification_created → the service has persisted a Notification row
//     channel_dispatched   → an adapter has begun delivery on a channel
//     channel_delivered    → the recipient acknowledged receipt
//     channel_failed       → delivery exhausted retries / hit a hard error
//     user_read            → the recipient marked the notification as read
//
// Design choices (kept deliberately small):
//
//   * No new runtime dependencies. Defence-in-depth redaction is implemented
//     in this file so the logger boundary is self-contained and can run in
//     unit tests without booting the project-wide logger or its config /
//     AsyncLocalStorage stack.
//
//   * Pluggable sink (`LogSink`). The default writes a JSON line to
//     `console.log`. Tests inject a memory sink via `setLogSink`. Producers /
//     consumers in later wiring tasks (NOT this task) can plug in a
//     CloudWatch/EMF or buffered sink the same way.
//
//   * Named per-stage helpers (`logEventPublished`, `logNotificationCreated`,
//     `logChannelDispatched`, `logChannelDelivered`, `logChannelFailed`,
//     `logUserRead`). Each takes only the inputs that stage carries; required
//     fields per stage are enforced at the type level so a forgotten id
//     surfaces at compile time, not in production telemetry.
//
//   * Field redaction. Defence-in-depth strip of `token` / `password` /
//     `secret` / `otp` / `pan` (and common variants such as `accessToken`,
//     `apiKey`, `cardNumber`, `cvv`) from any optional `metadata` payload,
//     recursively. Required IDs (`eventId`, `notificationId`, `userId`) are
//     never redacted — they are the only way an operator can pivot.
//
// Constraint: this file is the only file this task creates / modifies under
// `my-backend/src/notifications/observability/`. The wiring of these helpers
// into producers (publisher / service / channels) is owned by other tasks.
//
// Validates: REQ 14.1.
// ============================================================================

// ---------------------------------------------------------------------------
//                              Lifecycle stages
// ---------------------------------------------------------------------------

/**
 * Canonical lifecycle stage strings. Frozen const map so callsites pick a
 * value rather than spelling magic strings — and so the union type below
 * stays in sync automatically.
 */
export const LIFECYCLE_STAGE = Object.freeze({
    EVENT_PUBLISHED: 'event_published',
    NOTIFICATION_CREATED: 'notification_created',
    CHANNEL_DISPATCHED: 'channel_dispatched',
    CHANNEL_DELIVERED: 'channel_delivered',
    CHANNEL_FAILED: 'channel_failed',
    USER_READ: 'user_read',
} as const);

export type LifecycleStage =
    (typeof LIFECYCLE_STAGE)[keyof typeof LIFECYCLE_STAGE];

// ---------------------------------------------------------------------------
//                              Sink contract
// ---------------------------------------------------------------------------

/**
 * A LogSink consumes one finished JSON line per call. The default sink wraps
 * `console.log` so CloudWatch (or any stdout-collecting runtime) picks the
 * line up automatically. Tests inject a memory sink to assert shape.
 */
export type LogSink = (jsonLine: string) => void;

const DEFAULT_SINK: LogSink = (line) => {
    // Single argument call so the runtime does not append the usual
    // `console.log` join-with-space padding — the line is already formatted.
    // eslint-disable-next-line no-console
    console.log(line);
};

let activeSink: LogSink = DEFAULT_SINK;

/**
 * Replace the active sink. Returns the previous sink so callers (typically
 * tests) can restore it without reaching back into the module.
 *
 * Pass `null` to reset to the default `console.log` sink.
 */
export function setLogSink(sink: LogSink | null): LogSink {
    const previous = activeSink;
    activeSink = sink ?? DEFAULT_SINK;
    return previous;
}

/** Read-only accessor for the current sink. Useful in test setup. */
export function getLogSink(): LogSink {
    return activeSink;
}

// ---------------------------------------------------------------------------
//                          Sensitive-key redaction
// ---------------------------------------------------------------------------

/**
 * Set of metadata keys we always replace with `[REDACTED]` before emit.
 * Compared case-insensitively. The list intentionally covers the brief's
 * "token / password / secret / otp / pan" plus the most common aliases that
 * would otherwise sneak through by spelling (e.g. `accessToken`,
 * `cardNumber`).
 *
 * REQ 12.8 forbids embedding raw secrets / PAN / government IDs anywhere in
 * the system; this redaction pass is defence-in-depth at the logger
 * boundary so that even a misuse upstream cannot leak the value into stdout.
 */
const SENSITIVE_KEY_TOKENS: readonly string[] = Object.freeze([
    'token',
    'password',
    'secret',
    'otp',
    'pan',
    'apikey',
    'authorization',
    'cardnumber',
    'cvv',
    'ssn',
    'aadhaar',
    'aadhar',
]);

const REDACTED = '[REDACTED]';

function isSensitiveKey(key: string): boolean {
    const lowered = key.toLowerCase();
    // Substring match so that `accessToken`, `refreshToken`, `clientSecret`,
    // `previousPassword`, `panNumber`, etc. are all caught. The list above
    // is short enough that a substring scan is cheap.
    for (const needle of SENSITIVE_KEY_TOKENS) {
        if (lowered.includes(needle)) return true;
    }
    return false;
}

/**
 * Redact recursively. Arrays preserve element order so debugging stays
 * useful. Non-plain objects (e.g. Error, Date) are stringified through
 * `String(value)` since they are unlikely targets for secret bearing
 * payloads and we never want to silently drop them either.
 */
function redact(value: unknown): unknown {
    if (value === null || value === undefined) return value;
    if (Array.isArray(value)) {
        return value.map((item) => redact(item));
    }
    if (typeof value !== 'object') return value;

    // Plain object path
    const obj = value as Record<string, unknown>;
    // Defensive: only recurse into object-shaped inputs. `Date` survives the
    // typeof check; serialise it to ISO before redacting so the JSON line
    // stays readable.
    if (value instanceof Date) {
        return value.toISOString();
    }

    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(obj)) {
        if (isSensitiveKey(k)) {
            out[k] = REDACTED;
            continue;
        }
        out[k] = redact(v);
    }
    return out;
}

// ---------------------------------------------------------------------------
//                            Field shape
// ---------------------------------------------------------------------------

/**
 * Optional context every stage may carry. Tracing identifiers are kept as
 * separate fields per the brief — `correlationId` (UNS-internal request id)
 * and `traceId` (external trace context such as W3C `traceparent`) — even
 * though many systems collapse them, because the design doc names both.
 */
export interface LifecycleLogContext {
    readonly correlationId?: string;
    readonly traceId?: string;
    /**
     * Open metadata bag for stage-specific small fields (e.g. `attempt`,
     * `errorCode`, `latencyMs` overrides). Redacted recursively before
     * emission. Producers MUST NOT pass full notification payloads here
     * (REQ 14.1 enumerates the only fields we promise; payload bodies are
     * not in that list).
     */
    readonly metadata?: Readonly<Record<string, unknown>>;
}

/**
 * Stage-specific input shapes. Required IDs are typed as `string` so a
 * forgotten id is a TypeScript error, not a runtime mystery. Optional
 * channel / userId / durationMs reflect that not every stage carries every
 * field (e.g. `event_published` has no channel; `user_read` has no
 * channel either).
 */
export interface EventPublishedInput extends LifecycleLogContext {
    readonly eventId: string;
    /** Optional — the producing module / app. */
    readonly producer?: string;
}

export interface NotificationCreatedInput extends LifecycleLogContext {
    readonly eventId: string;
    readonly notificationId: string;
    readonly userId: string;
}

export interface ChannelDispatchedInput extends LifecycleLogContext {
    readonly eventId: string;
    readonly notificationId: string;
    readonly userId: string;
    readonly channel: string;
}

export interface ChannelDeliveredInput extends LifecycleLogContext {
    readonly eventId: string;
    readonly notificationId: string;
    readonly userId: string;
    readonly channel: string;
    /** Wall-clock delta between dispatch and delivery, in milliseconds. */
    readonly durationMs?: number;
}

export interface ChannelFailedInput extends LifecycleLogContext {
    readonly eventId: string;
    readonly notificationId: string;
    readonly userId: string;
    readonly channel: string;
    /** Short, taxonomy-controlled reason (`smtp_5xx`, `auth_denied`, ...). */
    readonly reason?: string;
    readonly durationMs?: number;
}

export interface UserReadInput extends LifecycleLogContext {
    readonly eventId: string;
    readonly notificationId: string;
    readonly userId: string;
}

// ---------------------------------------------------------------------------
//                            Validation
// ---------------------------------------------------------------------------

/**
 * Required-field validation lives here so a misuse throws synchronously at
 * the call site instead of producing a silently-broken JSON line in
 * production. We treat empty / whitespace-only strings as missing — an
 * empty notification id is meaningless for traceability.
 */
function requireString(name: string, value: unknown): string {
    if (typeof value !== 'string' || value.trim() === '') {
        throw new TypeError(
            `[UNS][lifecycle] required field "${name}" must be a non-empty string`,
        );
    }
    return value;
}

function optionalString(value: unknown): string | undefined {
    if (value === undefined || value === null) return undefined;
    if (typeof value !== 'string' || value.trim() === '') return undefined;
    return value;
}

function optionalFiniteNumber(value: unknown): number | undefined {
    if (typeof value === 'number' && Number.isFinite(value)) return value;
    return undefined;
}

// ---------------------------------------------------------------------------
//                            Emission
// ---------------------------------------------------------------------------

interface BaseRecord {
    timestamp: string;
    stage: LifecycleStage;
    eventId: string;
    notificationId?: string;
    userId?: string;
    channel?: string;
    correlationId?: string;
    traceId?: string;
    durationMs?: number;
    [k: string]: unknown;
}

function buildRecord(
    stage: LifecycleStage,
    fields: Partial<BaseRecord>,
    ctx: LifecycleLogContext,
): BaseRecord {
    const record: BaseRecord = {
        // ISO8601 with millisecond precision and trailing Z. `toISOString`
        // is stable across Node runtimes and produces the same shape every
        // call — exactly what log consumers expect for time-series queries.
        timestamp: new Date().toISOString(),
        stage,
        // `eventId` is the only required id present at every stage.
        eventId: requireString('eventId', fields.eventId),
    };

    const notificationId = optionalString(fields.notificationId);
    if (notificationId !== undefined) record.notificationId = notificationId;

    const userId = optionalString(fields.userId);
    if (userId !== undefined) record.userId = userId;

    const channel = optionalString(fields.channel);
    if (channel !== undefined) record.channel = channel;

    const correlationId = optionalString(ctx.correlationId);
    if (correlationId !== undefined) record.correlationId = correlationId;

    const traceId = optionalString(ctx.traceId);
    if (traceId !== undefined) record.traceId = traceId;

    const durationMs = optionalFiniteNumber(fields.durationMs);
    if (durationMs !== undefined) record.durationMs = durationMs;

    // Stage-specific ad-hoc keys (e.g. `producer` on event_published,
    // `reason` on channel_failed) are passed via `fields` and copied across
    // verbatim after redaction.
    for (const [k, v] of Object.entries(fields)) {
        if (
            k === 'eventId' ||
            k === 'notificationId' ||
            k === 'userId' ||
            k === 'channel' ||
            k === 'durationMs' ||
            v === undefined
        ) {
            continue;
        }
        // Redact the value in place. Keys themselves may not be sensitive,
        // but their values might be (e.g. `metadata.token`).
        record[k] = redact(v);
    }

    if (ctx.metadata !== undefined) {
        const cleaned = redact(ctx.metadata) as Record<string, unknown>;
        // Skip the field entirely if redaction left an empty bag — keeps
        // log lines compact when no metadata was supplied.
        if (Object.keys(cleaned).length > 0) {
            record.metadata = cleaned;
        }
    }

    return record;
}

function emit(
    stage: LifecycleStage,
    fields: Partial<BaseRecord>,
    ctx: LifecycleLogContext,
): void {
    const record = buildRecord(stage, fields, ctx);
    let line: string;
    try {
        line = JSON.stringify(record);
    } catch (err) {
        // Circular metadata or similar — fall back to a minimal record so
        // we still get a trace, instead of crashing the producer.
        line = JSON.stringify({
            timestamp: record.timestamp,
            stage: record.stage,
            eventId: record.eventId,
            error: 'log_serialization_failed',
            errorMessage: err instanceof Error ? err.message : String(err),
        });
    }
    activeSink(line);
}

// ---------------------------------------------------------------------------
//                            Per-stage helpers
// ---------------------------------------------------------------------------

export function logEventPublished(input: EventPublishedInput): void {
    emit(
        LIFECYCLE_STAGE.EVENT_PUBLISHED,
        {
            eventId: input.eventId,
            producer: optionalString(input.producer),
        },
        input,
    );
}

export function logNotificationCreated(
    input: NotificationCreatedInput,
): void {
    emit(
        LIFECYCLE_STAGE.NOTIFICATION_CREATED,
        {
            eventId: input.eventId,
            notificationId: requireString(
                'notificationId',
                input.notificationId,
            ),
            userId: requireString('userId', input.userId),
        },
        input,
    );
}

export function logChannelDispatched(input: ChannelDispatchedInput): void {
    emit(
        LIFECYCLE_STAGE.CHANNEL_DISPATCHED,
        {
            eventId: input.eventId,
            notificationId: requireString(
                'notificationId',
                input.notificationId,
            ),
            userId: requireString('userId', input.userId),
            channel: requireString('channel', input.channel),
        },
        input,
    );
}

export function logChannelDelivered(input: ChannelDeliveredInput): void {
    emit(
        LIFECYCLE_STAGE.CHANNEL_DELIVERED,
        {
            eventId: input.eventId,
            notificationId: requireString(
                'notificationId',
                input.notificationId,
            ),
            userId: requireString('userId', input.userId),
            channel: requireString('channel', input.channel),
            durationMs: input.durationMs,
        },
        input,
    );
}

export function logChannelFailed(input: ChannelFailedInput): void {
    emit(
        LIFECYCLE_STAGE.CHANNEL_FAILED,
        {
            eventId: input.eventId,
            notificationId: requireString(
                'notificationId',
                input.notificationId,
            ),
            userId: requireString('userId', input.userId),
            channel: requireString('channel', input.channel),
            durationMs: input.durationMs,
            reason: optionalString(input.reason),
        },
        input,
    );
}

export function logUserRead(input: UserReadInput): void {
    emit(
        LIFECYCLE_STAGE.USER_READ,
        {
            eventId: input.eventId,
            notificationId: requireString(
                'notificationId',
                input.notificationId,
            ),
            userId: requireString('userId', input.userId),
        },
        input,
    );
}

// ---------------------------------------------------------------------------
//                            Test-only utilities
// ---------------------------------------------------------------------------

/**
 * Exposed strictly for tests. Keeps the hot path free of runtime detection
 * code while letting tests pin concrete behaviour.
 */
export const __test__ = Object.freeze({
    redact,
    isSensitiveKey,
    SENSITIVE_KEY_TOKENS,
    DEFAULT_SINK,
});
