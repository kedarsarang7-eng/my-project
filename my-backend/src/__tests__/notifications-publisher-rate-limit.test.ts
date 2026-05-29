// ============================================================================
// Unit Tests — UNS Event_Bus Per-Producer Publish Rate Limit (REQ 12.4)
// ============================================================================
// Covers:
//   - under-limit publishes pass
//   - over-limit publishes reject with ProducerRateLimitExceededError
//   - separate Producers have independent budgets
//   - the time window rolls over (refill restores capacity)
//   - rate-limit is evaluated BEFORE schema validation (a malformed payload
//     still consumes a token, REQ 12.4 "applied to every publish attempt")
//   - publishBatch reports rate-limit rejections per-entry
//   - emit-helper degrades gracefully on rate-limit (fire-and-forget)
//
// Run with: npx jest src/__tests__/notifications-publisher-rate-limit.test.ts
// ============================================================================

// ── Mock SNS so no AWS call is ever made ─────────────────────────────────────
const mockSnsSend = jest.fn();

jest.mock('@aws-sdk/client-sns', () => ({
    SNSClient: jest.fn().mockImplementation(() => ({ send: mockSnsSend })),
    PublishCommand: jest.fn().mockImplementation((input: any) => ({ input, _type: 'Publish' })),
}));

// Mock the logger so test output stays clean and we can assert on the
// structured warn line emitted on rate-limit rejection.
const mockLoggerWarn = jest.fn();
const mockLoggerInfo = jest.fn();
const mockLoggerError = jest.fn();
const mockLoggerDebug = jest.fn();
jest.mock('../utils/logger', () => ({
    logger: {
        info: (...args: unknown[]) => mockLoggerInfo(...args),
        warn: (...args: unknown[]) => mockLoggerWarn(...args),
        error: (...args: unknown[]) => mockLoggerError(...args),
        debug: (...args: unknown[]) => mockLoggerDebug(...args),
    },
}));

// ── Required env vars for publisher ─────────────────────────────────────────
process.env.UNS_SNS_TOPIC_ARN = 'arn:aws:sns:ap-south-1:000000000000:uns-events-test';

// ── Imports after mocks ─────────────────────────────────────────────────────
import {
    publishEvent,
    publishBatch,
    ProducerRateLimitExceededError,
    ProducerRateLimiter,
    _setSharedRateLimiterForTests,
    UNKNOWN_PRODUCER_ID,
} from '../notifications/event-bus';
import { emitUnsEvent } from '../notifications/event-bus/emit-helper';
import { _setSnsClientForTests } from '../notifications/event-bus/publisher';
import type { EventContract, Recipient } from '../notifications/event-bus';

// ============================================================================
// Helpers
// ============================================================================

const VALID_RECIPIENT: Recipient = {
    user_id: 'user-1',
    role: 'admin',
};

/** Build a known-valid Event_Contract envelope for a given producer. */
function buildEvent(overrides: Partial<EventContract> = {}): EventContract {
    return {
        id: '11111111-2222-4333-8444-555555555555',
        event_name: 'billing.invoice.created',
        category: 'billing',
        sub_category: 'invoice',
        priority: 'normal',
        actor_id: 'actor-1',
        target_id: 'invoice-1',
        recipients: [VALID_RECIPIENT],
        payload: { invoiceId: 'invoice-1' },
        channels: ['in_app'],
        source_module: 'my-backend/src/__tests__/producer-A.ts',
        source_app: 'dukanx_backend',
        created_at: new Date().toISOString(),
        dedup_key: 'dedup-key-test-1',
        ...overrides,
    };
}

/**
 * Reusable controllable clock for deterministic time-window tests. The
 * limiter is stateful; using `jest.useFakeTimers()` would also need to
 * intercept Date.now. A dedicated clock injected into the limiter is
 * simpler and lets us reason about exact tokens.
 */
function makeManualClock(initial = 1_700_000_000_000) {
    let nowMs = initial;
    return {
        now: () => nowMs,
        advance: (deltaMs: number) => { nowMs += deltaMs; },
        reset: (toMs: number = initial) => { nowMs = toMs; },
    };
}

// ============================================================================
// Tests
// ============================================================================

describe('UNS Event_Bus — per-Producer publish rate limit (REQ 12.4)', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        // Default: SNS happily accepts every publish.
        mockSnsSend.mockResolvedValue({ MessageId: 'sns-msg-id' });
        // Each test installs its own limiter to control limit / window / clock.
        _setSharedRateLimiterForTests(null);
        _setSnsClientForTests(null);
    });

    afterEach(() => {
        _setSharedRateLimiterForTests(null);
        _setSnsClientForTests(null);
    });

    // -- ProducerRateLimiter unit invariants --------------------------------

    describe('ProducerRateLimiter token bucket', () => {
        test('starts with full capacity and decrements one token per consume', () => {
            const clock = makeManualClock();
            const limiter = new ProducerRateLimiter({ limit: 3, windowMs: 1000 }, clock.now);

            const a = limiter.consume('p1');
            const b = limiter.consume('p1');
            const c = limiter.consume('p1');

            expect(a.allowed).toBe(true);
            expect(b.allowed).toBe(true);
            expect(c.allowed).toBe(true);
            expect(a.remaining).toBe(2);
            expect(b.remaining).toBe(1);
            expect(c.remaining).toBe(0);
        });

        test('rejects the (limit+1)-th consume within the window', () => {
            const clock = makeManualClock();
            const limiter = new ProducerRateLimiter({ limit: 2, windowMs: 1000 }, clock.now);

            limiter.consume('p1');
            limiter.consume('p1');
            const overflow = limiter.consume('p1');

            expect(overflow.allowed).toBe(false);
            expect(overflow.remaining).toBe(0);
            expect(overflow.retryAfterMs).toBeGreaterThan(0);
            expect(overflow.producerId).toBe('p1');
        });

        test('separate Producers have independent budgets', () => {
            const clock = makeManualClock();
            const limiter = new ProducerRateLimiter({ limit: 2, windowMs: 1000 }, clock.now);

            // Drain Producer A.
            expect(limiter.consume('producer-A').allowed).toBe(true);
            expect(limiter.consume('producer-A').allowed).toBe(true);
            expect(limiter.consume('producer-A').allowed).toBe(false);

            // Producer B is unaffected.
            expect(limiter.consume('producer-B').allowed).toBe(true);
            expect(limiter.consume('producer-B').allowed).toBe(true);
            expect(limiter.consume('producer-B').allowed).toBe(false);

            // Producer C also unaffected.
            expect(limiter.consume('producer-C').allowed).toBe(true);
        });

        test('time-window rolls over: tokens refill linearly', () => {
            const clock = makeManualClock();
            // 10 tokens per 1 000 ms ⇒ 0.01 tokens/ms.
            const limiter = new ProducerRateLimiter({ limit: 10, windowMs: 1000 }, clock.now);

            // Drain.
            for (let i = 0; i < 10; i++) limiter.consume('p1');
            expect(limiter.consume('p1').allowed).toBe(false);

            // Advance half a window — bucket refills 5 tokens.
            clock.advance(500);
            for (let i = 0; i < 5; i++) {
                expect(limiter.consume('p1').allowed).toBe(true);
            }
            expect(limiter.consume('p1').allowed).toBe(false);

            // Advance the rest of the window — bucket refills 5 MORE tokens
            // (capped at capacity = 10, but we drained to 0 again above).
            clock.advance(500);
            for (let i = 0; i < 5; i++) {
                expect(limiter.consume('p1').allowed).toBe(true);
            }
            expect(limiter.consume('p1').allowed).toBe(false);

            // Advance two full windows of inactivity — bucket refills to FULL
            // capacity (capped at 10).
            clock.advance(2000);
            for (let i = 0; i < 10; i++) {
                expect(limiter.consume('p1').allowed).toBe(true);
            }
            expect(limiter.consume('p1').allowed).toBe(false);
        });

        test('refill is capped at capacity (no token accumulation)', () => {
            const clock = makeManualClock();
            const limiter = new ProducerRateLimiter({ limit: 5, windowMs: 1000 }, clock.now);

            // Touch the bucket once to register lastRefillMs.
            limiter.consume('p1');
            // Sleep for 100 windows. Bucket must NOT exceed 5.
            clock.advance(1000 * 100);
            // We should be allowed exactly 5 publishes, not 5 + 100·5.
            for (let i = 0; i < 5; i++) {
                expect(limiter.consume('p1').allowed).toBe(true);
            }
            expect(limiter.consume('p1').allowed).toBe(false);
        });

        test('rejects construction with non-positive limit or window', () => {
            expect(() => new ProducerRateLimiter({ limit: 0, windowMs: 1000 })).toThrow();
            expect(() => new ProducerRateLimiter({ limit: 5, windowMs: 0 })).toThrow();
            expect(() => new ProducerRateLimiter({ limit: -1, windowMs: 1000 })).toThrow();
        });

        test('blank or empty producer id falls back to UNKNOWN_PRODUCER_ID', () => {
            const limiter = new ProducerRateLimiter({ limit: 1, windowMs: 1000 });
            const a = limiter.consume('');
            const b = limiter.consume('   ');

            expect(a.producerId).toBe(UNKNOWN_PRODUCER_ID);
            expect(b.producerId).toBe(UNKNOWN_PRODUCER_ID);
            // Both share the same bucket, so the second is rejected.
            expect(a.allowed).toBe(true);
            expect(b.allowed).toBe(false);
        });
    });

    // -- publishEvent integration -------------------------------------------

    describe('publishEvent integration', () => {
        test('under-limit publishes pass and reach SNS', async () => {
            const clock = makeManualClock();
            _setSharedRateLimiterForTests(
                new ProducerRateLimiter({ limit: 5, windowMs: 1000 }, clock.now),
            );

            const ev = buildEvent();
            const ack1 = await publishEvent(ev);
            const ack2 = await publishEvent(ev);

            expect(ack1.messageId).toBe('sns-msg-id');
            expect(ack2.messageId).toBe('sns-msg-id');
            expect(mockSnsSend).toHaveBeenCalledTimes(2);
        });

        test('over-limit publishes reject with ProducerRateLimitExceededError and never reach SNS', async () => {
            const clock = makeManualClock();
            _setSharedRateLimiterForTests(
                new ProducerRateLimiter({ limit: 2, windowMs: 1000 }, clock.now),
            );

            const ev = buildEvent();
            await publishEvent(ev);
            await publishEvent(ev);
            mockSnsSend.mockClear();

            await expect(publishEvent(ev)).rejects.toBeInstanceOf(ProducerRateLimitExceededError);
            expect(mockSnsSend).not.toHaveBeenCalled();

            // Structured warn log line must record the flood (observability hook).
            expect(mockLoggerWarn).toHaveBeenCalledWith(
                expect.stringContaining('rate-limit exceeded'),
                expect.objectContaining({
                    producerId: ev.source_module,
                    limit: 2,
                    windowMs: 1000,
                    retryAfterMs: expect.any(Number),
                }),
            );
        });

        test('separate Producers (different source_module) have separate budgets', async () => {
            const clock = makeManualClock();
            _setSharedRateLimiterForTests(
                new ProducerRateLimiter({ limit: 1, windowMs: 1000 }, clock.now),
            );

            const evA = buildEvent({ source_module: 'my-backend/src/handlers/A.ts' });
            const evB = buildEvent({ source_module: 'my-backend/src/handlers/B.ts' });

            // A's only token is consumed.
            await publishEvent(evA);
            await expect(publishEvent(evA)).rejects.toBeInstanceOf(ProducerRateLimitExceededError);
            // B is unaffected.
            await expect(publishEvent(evB)).resolves.toEqual({ messageId: 'sns-msg-id' });
        });

        test('window roll-over restores capacity', async () => {
            const clock = makeManualClock();
            _setSharedRateLimiterForTests(
                new ProducerRateLimiter({ limit: 1, windowMs: 1000 }, clock.now),
            );

            const ev = buildEvent();
            await publishEvent(ev);
            await expect(publishEvent(ev)).rejects.toBeInstanceOf(ProducerRateLimitExceededError);

            // Advance one full window.
            clock.advance(1000);
            await expect(publishEvent(ev)).resolves.toEqual({ messageId: 'sns-msg-id' });
        });

        test('rate-limit is evaluated BEFORE schema validation (REQ 12.4 "every publish attempt")', async () => {
            const clock = makeManualClock();
            _setSharedRateLimiterForTests(
                new ProducerRateLimiter({ limit: 1, windowMs: 1000 }, clock.now),
            );

            // First attempt: malformed payload BUT carries a source_module the
            // limiter can attribute. The limiter charges a token before the
            // schema check rejects the call.
            const malformed = {
                source_module: 'my-backend/src/__tests__/producer-flooder.ts',
                // ...everything else missing
            };

            await expect(publishEvent(malformed)).rejects.toThrow();

            // The valid event from the same producer should now be over-limit.
            const ev = buildEvent({
                source_module: 'my-backend/src/__tests__/producer-flooder.ts',
            });
            await expect(publishEvent(ev)).rejects.toBeInstanceOf(ProducerRateLimitExceededError);
            // SNS was never called for either attempt.
            expect(mockSnsSend).not.toHaveBeenCalled();
        });

        test('payloads without source_module are bucketed under UNKNOWN_PRODUCER_ID', async () => {
            const clock = makeManualClock();
            _setSharedRateLimiterForTests(
                new ProducerRateLimiter({ limit: 1, windowMs: 1000 }, clock.now),
            );

            // Two malformed payloads from "different" places — both fall into
            // the unknown bucket because they have no source_module/source_app.
            const garbage1 = { id: 'a' };
            const garbage2 = { id: 'b' };

            await expect(publishEvent(garbage1)).rejects.toThrow(); // validation fails
            // Second attempt is rate-limited because the unknown bucket is
            // already drained.
            await expect(publishEvent(garbage2)).rejects.toBeInstanceOf(ProducerRateLimitExceededError);
        });
    });

    // -- publishBatch integration -------------------------------------------

    describe('publishBatch integration', () => {
        test('reports rate-limited entries with code "rate_limited" and producerId', async () => {
            const clock = makeManualClock();
            _setSharedRateLimiterForTests(
                new ProducerRateLimiter({ limit: 1, windowMs: 1000 }, clock.now),
            );

            const ev1 = buildEvent({ id: '00000000-0000-4000-8000-000000000001' });
            const ev2 = buildEvent({ id: '00000000-0000-4000-8000-000000000002' });
            const ev3 = buildEvent({ id: '00000000-0000-4000-8000-000000000003' });

            const result = await publishBatch([ev1, ev2, ev3]);

            // Only ev1 should make it through; ev2 and ev3 are rate-limited.
            expect(result.messageIds).toHaveLength(1);
            expect(result.failed).toHaveLength(2);
            expect(result.failed[0]).toEqual(expect.objectContaining({
                index: 1,
                code: 'rate_limited',
                producerId: ev2.source_module,
                retryAfterMs: expect.any(Number),
            }));
            expect(result.failed[1]).toEqual(expect.objectContaining({
                index: 2,
                code: 'rate_limited',
                producerId: ev3.source_module,
            }));
            // SNS was called exactly once.
            expect(mockSnsSend).toHaveBeenCalledTimes(1);
        });
    });

    // -- emit-helper integration --------------------------------------------

    describe('emit-helper graceful degradation', () => {
        test('emitUnsEvent never throws on rate-limit (fire-and-forget contract)', async () => {
            const clock = makeManualClock();
            _setSharedRateLimiterForTests(
                new ProducerRateLimiter({ limit: 1, windowMs: 1000 }, clock.now),
            );

            const input = {
                eventName: 'billing.invoice.created',
                category: 'billing' as const,
                priority: 'normal' as const,
                actorId: 'actor-1',
                targetId: 'invoice-1',
                recipients: [VALID_RECIPIENT],
                payload: { invoiceId: 'invoice-1' },
                sourceModule: 'my-backend/src/__tests__/emit-helper-flooder.ts',
            };

            // First emit: passes.
            await expect(emitUnsEvent(input)).resolves.toBeUndefined();
            // Second emit: rate-limited but MUST NOT throw (caller's business
            // flow must not be broken).
            await expect(emitUnsEvent(input)).resolves.toBeUndefined();
            // The publisher emitted the structured rate-limit warn line on
            // the second emit. The emit-helper degrades to debug to avoid
            // duplicating the warn-stream noise from the same misbehaving
            // caller.
            const rateLimitWarn = mockLoggerWarn.mock.calls.find(([msg]) =>
                typeof msg === 'string' && msg.includes('rate-limit exceeded'),
            );
            expect(rateLimitWarn).toBeDefined();
        });
    });
});
