// ============================================================================
// UNS — Structured Lifecycle Logger tests (Task 17.1, REQ 14.1)
// ============================================================================
//
// Coverage map (the four cases called out by the task brief):
//
//   1. Each stage emits the expected shape
//      (event_published, notification_created, channel_dispatched,
//       channel_delivered, channel_failed, user_read).
//   2. Sensitive metadata keys are redacted at the logger boundary
//      (`token`, `password`, `secret`, `otp`, `pan`, plus common variants).
//   3. Custom sink injection — `setLogSink` swaps the destination cleanly
//      and `setLogSink(null)` restores the default.
//   4. Timestamp format — every emitted line carries an ISO8601 / RFC 3339
//      UTC timestamp ending in `Z`.
//
// Plus a handful of small guard tests for input validation so a
// regression in `requireString` cannot silently start emitting half-broken
// log lines.
// ============================================================================

import { describe, test, expect, beforeEach, afterEach } from '@jest/globals';
import {
    LIFECYCLE_STAGE,
    LogSink,
    getLogSink,
    logChannelDelivered,
    logChannelDispatched,
    logChannelFailed,
    logEventPublished,
    logNotificationCreated,
    logUserRead,
    setLogSink,
} from '../logger';

// ---------------------------------------------------------------------------
//                              Test helpers
// ---------------------------------------------------------------------------

interface CapturingSink {
    readonly sink: LogSink;
    readonly lines: string[];
    readonly records: Array<Record<string, unknown>>;
}

/**
 * Build a capturing sink that records both the raw JSON line and the parsed
 * record. Tests then assert against the parsed record (typed access) without
 * losing the ability to verify wire shape (one JSON object per line).
 */
function makeCapturingSink(): CapturingSink {
    const lines: string[] = [];
    const records: Array<Record<string, unknown>> = [];
    const sink: LogSink = (line) => {
        lines.push(line);
        records.push(JSON.parse(line) as Record<string, unknown>);
    };
    return { sink, lines, records };
}

// ISO8601 with millisecond precision and trailing `Z`. Matches `toISOString()`
// output format exactly. `\d{3}` enforces millisecond precision; the literal
// `Z` enforces UTC.
const ISO_8601_REGEX = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

let capture: CapturingSink;
let previousSink: LogSink;

beforeEach(() => {
    capture = makeCapturingSink();
    previousSink = setLogSink(capture.sink);
});

afterEach(() => {
    setLogSink(previousSink);
});

// ---------------------------------------------------------------------------
//                       1. Each stage emits expected shape
// ---------------------------------------------------------------------------

describe('lifecycle logger — stage shapes (REQ 14.1)', () => {
    test('logEventPublished emits stage=event_published with eventId', () => {
        logEventPublished({
            eventId: 'evt_abc',
            producer: 'billing.invoice.publisher',
            correlationId: 'corr_1',
            traceId: 'trace_1',
        });

        expect(capture.records).toHaveLength(1);
        const r = capture.records[0];
        expect(r.stage).toBe(LIFECYCLE_STAGE.EVENT_PUBLISHED);
        expect(r.stage).toBe('event_published');
        expect(r.eventId).toBe('evt_abc');
        expect(r.producer).toBe('billing.invoice.publisher');
        expect(r.correlationId).toBe('corr_1');
        expect(r.traceId).toBe('trace_1');
        // Per-stage absent fields stay absent (no null pollution).
        expect('notificationId' in r).toBe(false);
        expect('userId' in r).toBe(false);
        expect('channel' in r).toBe(false);
    });

    test('logNotificationCreated includes notificationId and userId', () => {
        logNotificationCreated({
            eventId: 'evt_abc',
            notificationId: 'ntf_1',
            userId: 'usr_1',
        });

        const r = capture.records[0];
        expect(r.stage).toBe('notification_created');
        expect(r.eventId).toBe('evt_abc');
        expect(r.notificationId).toBe('ntf_1');
        expect(r.userId).toBe('usr_1');
        expect('channel' in r).toBe(false);
    });

    test('logChannelDispatched includes channel', () => {
        logChannelDispatched({
            eventId: 'evt_abc',
            notificationId: 'ntf_1',
            userId: 'usr_1',
            channel: 'push',
        });

        const r = capture.records[0];
        expect(r.stage).toBe('channel_dispatched');
        expect(r.channel).toBe('push');
    });

    test('logChannelDelivered carries optional durationMs', () => {
        logChannelDelivered({
            eventId: 'evt_abc',
            notificationId: 'ntf_1',
            userId: 'usr_1',
            channel: 'in_app',
            durationMs: 42,
        });

        const r = capture.records[0];
        expect(r.stage).toBe('channel_delivered');
        expect(r.channel).toBe('in_app');
        expect(r.durationMs).toBe(42);
    });

    test('logChannelDelivered omits durationMs when not finite', () => {
        logChannelDelivered({
            eventId: 'evt_abc',
            notificationId: 'ntf_1',
            userId: 'usr_1',
            channel: 'in_app',
            durationMs: Number.NaN,
        });

        const r = capture.records[0];
        expect('durationMs' in r).toBe(false);
    });

    test('logChannelFailed carries reason and durationMs', () => {
        logChannelFailed({
            eventId: 'evt_abc',
            notificationId: 'ntf_1',
            userId: 'usr_1',
            channel: 'sms',
            reason: 'twilio_5xx',
            durationMs: 1200,
        });

        const r = capture.records[0];
        expect(r.stage).toBe('channel_failed');
        expect(r.reason).toBe('twilio_5xx');
        expect(r.durationMs).toBe(1200);
    });

    test('logUserRead emits stage=user_read with notification + user ids', () => {
        logUserRead({
            eventId: 'evt_abc',
            notificationId: 'ntf_1',
            userId: 'usr_1',
        });

        const r = capture.records[0];
        expect(r.stage).toBe('user_read');
        expect(r.notificationId).toBe('ntf_1');
        expect(r.userId).toBe('usr_1');
        expect('channel' in r).toBe(false);
    });

    test('every stage produces exactly one JSON line per call', () => {
        logEventPublished({ eventId: 'e' });
        logNotificationCreated({
            eventId: 'e',
            notificationId: 'n',
            userId: 'u',
        });
        logChannelDispatched({
            eventId: 'e',
            notificationId: 'n',
            userId: 'u',
            channel: 'email',
        });
        logChannelDelivered({
            eventId: 'e',
            notificationId: 'n',
            userId: 'u',
            channel: 'email',
        });
        logChannelFailed({
            eventId: 'e',
            notificationId: 'n',
            userId: 'u',
            channel: 'email',
        });
        logUserRead({
            eventId: 'e',
            notificationId: 'n',
            userId: 'u',
        });

        expect(capture.lines).toHaveLength(6);
        // Each line MUST parse as a single JSON object — no trailing
        // newlines, no concatenation.
        for (const line of capture.lines) {
            expect(() => JSON.parse(line)).not.toThrow();
            expect(line.includes('\n')).toBe(false);
        }
        const stages = capture.records.map((r) => r.stage);
        expect(stages).toEqual([
            'event_published',
            'notification_created',
            'channel_dispatched',
            'channel_delivered',
            'channel_failed',
            'user_read',
        ]);
    });
});

// ---------------------------------------------------------------------------
//                       2. Sensitive-key redaction
// ---------------------------------------------------------------------------

describe('lifecycle logger — sensitive-key redaction (REQ 12.8 defence-in-depth)', () => {
    test('redacts top-level token / password / secret / otp / pan', () => {
        logNotificationCreated({
            eventId: 'evt',
            notificationId: 'ntf',
            userId: 'usr',
            metadata: {
                token: 'tok_should_not_leak',
                password: 'hunter2',
                secret: 'shh',
                otp: '123456',
                pan: 'ABCDE1234F',
                harmless: 'keep-me',
            },
        });

        const meta = capture.records[0].metadata as Record<string, unknown>;
        expect(meta.token).toBe('[REDACTED]');
        expect(meta.password).toBe('[REDACTED]');
        expect(meta.secret).toBe('[REDACTED]');
        expect(meta.otp).toBe('[REDACTED]');
        expect(meta.pan).toBe('[REDACTED]');
        expect(meta.harmless).toBe('keep-me');
    });

    test('redacts common variants (accessToken, apiKey, cardNumber, cvv)', () => {
        logChannelFailed({
            eventId: 'evt',
            notificationId: 'ntf',
            userId: 'usr',
            channel: 'webhook',
            metadata: {
                accessToken: 'at_x',
                refreshToken: 'rt_x',
                apiKey: 'ak_x',
                cardNumber: '4111111111111111',
                cvv: '123',
                panNumber: 'ABCDE1234F',
                clientSecret: 'cs_x',
            },
        });

        const meta = capture.records[0].metadata as Record<string, unknown>;
        expect(meta.accessToken).toBe('[REDACTED]');
        expect(meta.refreshToken).toBe('[REDACTED]');
        expect(meta.apiKey).toBe('[REDACTED]');
        expect(meta.cardNumber).toBe('[REDACTED]');
        expect(meta.cvv).toBe('[REDACTED]');
        expect(meta.panNumber).toBe('[REDACTED]');
        expect(meta.clientSecret).toBe('[REDACTED]');
    });

    test('redacts nested keys recursively', () => {
        logChannelDispatched({
            eventId: 'evt',
            notificationId: 'ntf',
            userId: 'usr',
            channel: 'sms',
            metadata: {
                payload: {
                    user: {
                        password: 'p',
                        name: 'Alice',
                    },
                    items: [
                        { otp: '999000', label: 'a' },
                        { label: 'b' },
                    ],
                },
            },
        });

        const meta = capture.records[0].metadata as Record<string, unknown>;
        const payload = meta.payload as Record<string, unknown>;
        const user = payload.user as Record<string, unknown>;
        expect(user.password).toBe('[REDACTED]');
        expect(user.name).toBe('Alice');
        const items = payload.items as Array<Record<string, unknown>>;
        expect(items[0].otp).toBe('[REDACTED]');
        expect(items[0].label).toBe('a');
        expect(items[1].label).toBe('b');
    });

    test('redaction is case-insensitive', () => {
        logUserRead({
            eventId: 'evt',
            notificationId: 'ntf',
            userId: 'usr',
            metadata: {
                TOKEN: 't',
                Password: 'p',
                Secret: 's',
                OTP: 'o',
                PAN: 'PANEXAMPLE',
            },
        });

        const meta = capture.records[0].metadata as Record<string, unknown>;
        expect(meta.TOKEN).toBe('[REDACTED]');
        expect(meta.Password).toBe('[REDACTED]');
        expect(meta.Secret).toBe('[REDACTED]');
        expect(meta.OTP).toBe('[REDACTED]');
        expect(meta.PAN).toBe('[REDACTED]');
    });

    test('non-sensitive ids (eventId, notificationId, userId) are never redacted', () => {
        // Id field names contain no sensitive substrings — sanity-check
        // they survive the redaction pass intact.
        logChannelDelivered({
            eventId: 'evt_abc',
            notificationId: 'ntf_xyz',
            userId: 'usr_001',
            channel: 'push',
        });

        const r = capture.records[0];
        expect(r.eventId).toBe('evt_abc');
        expect(r.notificationId).toBe('ntf_xyz');
        expect(r.userId).toBe('usr_001');
    });

    test('empty metadata is omitted from the line', () => {
        logEventPublished({ eventId: 'evt', metadata: {} });
        const r = capture.records[0];
        expect('metadata' in r).toBe(false);
    });
});

// ---------------------------------------------------------------------------
//                       3. Custom sink injection
// ---------------------------------------------------------------------------

describe('lifecycle logger — pluggable sink', () => {
    test('setLogSink swaps the destination', () => {
        // Replace our default capturing sink with a counting sink.
        const seen: string[] = [];
        const previous = setLogSink((line) => seen.push(line));

        logEventPublished({ eventId: 'evt' });

        // The counting sink received the line; the global capturing sink
        // installed in beforeEach did NOT receive it.
        expect(seen).toHaveLength(1);
        expect(capture.lines).toHaveLength(0);

        // Restore for cleanliness.
        setLogSink(previous);
    });

    test('setLogSink returns the previous sink so callers can restore', () => {
        const a: LogSink = () => {};
        const b: LogSink = () => {};

        const original = setLogSink(a);
        expect(getLogSink()).toBe(a);

        const back = setLogSink(b);
        expect(back).toBe(a);
        expect(getLogSink()).toBe(b);

        // Restore for cleanliness.
        setLogSink(original);
    });

    test('setLogSink(null) restores the default console.log sink', () => {
        // Replace with a memory sink, then ask to reset.
        setLogSink(() => {});
        const restored = setLogSink(null);
        expect(typeof restored).toBe('function');

        // The new active sink is NOT our beforeEach capturing sink anymore —
        // it's the module default. We assert that by spying on console.log.
        const consoleSpy = jest
            .spyOn(console, 'log')
            .mockImplementation(() => {});
        try {
            logEventPublished({ eventId: 'evt' });
            expect(consoleSpy).toHaveBeenCalledTimes(1);
            const arg = consoleSpy.mock.calls[0][0] as string;
            expect(typeof arg).toBe('string');
            const parsed = JSON.parse(arg) as Record<string, unknown>;
            expect(parsed.stage).toBe('event_published');
            expect(parsed.eventId).toBe('evt');
        } finally {
            consoleSpy.mockRestore();
        }
    });
});

// ---------------------------------------------------------------------------
//                       4. Timestamp format
// ---------------------------------------------------------------------------

describe('lifecycle logger — timestamp format (REQ 14.1)', () => {
    test('every line carries an ISO8601 UTC timestamp', () => {
        logEventPublished({ eventId: 'e' });
        logNotificationCreated({
            eventId: 'e',
            notificationId: 'n',
            userId: 'u',
        });
        logChannelDispatched({
            eventId: 'e',
            notificationId: 'n',
            userId: 'u',
            channel: 'email',
        });
        logChannelDelivered({
            eventId: 'e',
            notificationId: 'n',
            userId: 'u',
            channel: 'email',
        });
        logChannelFailed({
            eventId: 'e',
            notificationId: 'n',
            userId: 'u',
            channel: 'email',
        });
        logUserRead({
            eventId: 'e',
            notificationId: 'n',
            userId: 'u',
        });

        for (const r of capture.records) {
            const ts = r.timestamp as string;
            expect(typeof ts).toBe('string');
            expect(ts).toMatch(ISO_8601_REGEX);
            // Sanity: round-tripping the ISO string yields the same string.
            expect(new Date(ts).toISOString()).toBe(ts);
        }
    });

    test('timestamp reflects the current wall-clock at emit time', () => {
        const before = Date.now();
        logEventPublished({ eventId: 'e' });
        const after = Date.now();

        const ts = capture.records[0].timestamp as string;
        const tsMs = new Date(ts).getTime();
        expect(tsMs).toBeGreaterThanOrEqual(before);
        expect(tsMs).toBeLessThanOrEqual(after);
    });
});

// ---------------------------------------------------------------------------
//                       5. Input validation guards
// ---------------------------------------------------------------------------

describe('lifecycle logger — input validation', () => {
    test('throws on empty-string eventId', () => {
        // Empty string is a valid TS `string` but invalid at runtime —
        // exercises the `requireString` guard.
        expect(() => logEventPublished({ eventId: '' })).toThrow(/eventId/);
    });

    test('throws on empty notificationId for stages that require it', () => {
        expect(() =>
            logNotificationCreated({
                eventId: 'e',
                notificationId: '',
                userId: 'u',
            }),
        ).toThrow(/notificationId/);
    });

    test('throws on empty channel for channel stages', () => {
        expect(() =>
            logChannelDispatched({
                eventId: 'e',
                notificationId: 'n',
                userId: 'u',
                channel: '',
            }),
        ).toThrow(/channel/);
    });

    test('throws on whitespace-only required ids', () => {
        expect(() =>
            logUserRead({
                eventId: '   ',
                notificationId: 'n',
                userId: 'u',
            }),
        ).toThrow(/eventId/);
    });
});
