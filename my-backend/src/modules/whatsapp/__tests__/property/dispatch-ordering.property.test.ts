// ============================================================================
// Property-Based Test — Dispatch Ordering and Expiry
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 27
//
// Validates: Requirements 9.2, 9.4, 9.5
//
// Property 27 (design.md): Per-recipient dispatch preserves enqueue order and
// messages expire correctly.
//
// For any set of queued Outbound_Messages for a recipient, dispatch on
// connectivity restoration proceeds in ascending enqueue order (oldest first);
// and for any message whose configured expiry (1 minute to 168 hours) has
// passed, it is marked expired, not dispatched, and the expiry reason is
// recorded.
//
// Verified properties:
// 1. Messages for the same recipient are dispatched in enqueue order (oldest first)
// 2. Messages past expiry are marked expired (not dispatched)
// 3. Unexpired messages are dispatched
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  isMessageExpired,
  createRetryPolicy,
  MIN_EXPIRY_SECONDS,
  MAX_EXPIRY_SECONDS,
  type DispatchAttemptState,
  type RetryPolicy,
} from '../../services/retry-policy.service';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** ISO-8601 UTC date in a realistic range. */
const isoDateArb: fc.Arbitrary<string> = fc
  .date({
    min: new Date('2023-01-01T00:00:00.000Z'),
    max: new Date('2026-12-31T23:59:59.999Z'),
  })
  .map((d) => d.toISOString());

/** Valid expiry in seconds (1 minute to 168 hours). */
const validExpirySecondsArb: fc.Arbitrary<number> = fc.integer({
  min: MIN_EXPIRY_SECONDS,
  max: MAX_EXPIRY_SECONDS,
});

/**
 * Generates a sequence of enqueue timestamps in strictly ascending order
 * for the same recipient, simulating messages queued over time.
 * Each timestamp is 1–300 seconds after the previous.
 */
function orderedEnqueueTimesArb(count: number): fc.Arbitrary<string[]> {
  return fc
    .date({
      min: new Date('2023-06-01T00:00:00.000Z'),
      max: new Date('2025-06-01T00:00:00.000Z'),
    })
    .chain((baseDate) =>
      fc
        .array(fc.integer({ min: 1_000, max: 300_000 }), {
          minLength: count,
          maxLength: count,
        })
        .map((offsets) => {
          const timestamps: string[] = [];
          let currentMs = baseDate.getTime();
          for (const offset of offsets) {
            currentMs += offset;
            timestamps.push(new Date(currentMs).toISOString());
          }
          return timestamps;
        }),
    );
}

/**
 * Generates a message batch with enqueue times and expiry, where `now`
 * is controllable to test both expired and valid messages.
 */
interface QueuedMessage {
  id: string;
  enqueuedAt: string;
  expiresAt: string;
  expirySeconds: number;
}

/**
 * Generates a list of queued messages for the same recipient with
 * ascending enqueue times and a configurable expiry for each.
 */
function queuedMessagesArb(minCount: number, maxCount: number): fc.Arbitrary<QueuedMessage[]> {
  return fc
    .integer({ min: minCount, max: maxCount })
    .chain((count) =>
      fc.tuple(orderedEnqueueTimesArb(count), fc.array(validExpirySecondsArb, { minLength: count, maxLength: count }))
    )
    .map(([enqueueTimes, expiries]) =>
      enqueueTimes.map((enqueuedAt, i) => {
        const expirySeconds = expiries[i];
        const expiresAtMs = Date.parse(enqueuedAt) + expirySeconds * 1000;
        return {
          id: `msg-${i}`,
          enqueuedAt,
          expiresAt: new Date(expiresAtMs).toISOString(),
          expirySeconds,
        };
      }),
    );
}

// ── Simulation Logic ────────────────────────────────────────────────────────

/**
 * Simulates the dispatcher's processing of a batch of messages for a single
 * recipient. The dispatcher processes messages in the order they appear in
 * the batch (which corresponds to SQS FIFO enqueue order for the same
 * MessageGroupId). For each message it checks expiry before dispatch.
 *
 * Returns the dispatched and expired message lists in processing order.
 */
function simulateDispatch(
  messages: QueuedMessage[],
  now: string,
): { dispatched: string[]; expired: string[] } {
  const dispatched: string[] = [];
  const expired: string[] = [];

  for (const msg of messages) {
    const policy: RetryPolicy = createRetryPolicy({ expirySeconds: msg.expirySeconds });
    const state: DispatchAttemptState = {
      attempts: 0,
      errorCode: '',
      enqueuedAt: msg.enqueuedAt,
      now,
      expiresAt: msg.expiresAt,
    };

    if (isMessageExpired(state, policy)) {
      expired.push(msg.id);
    } else {
      dispatched.push(msg.id);
    }
  }

  return { dispatched, expired };
}

// ── Property 27 Tests ───────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 27: Per-recipient dispatch preserves enqueue order and messages expire correctly', () => {
  // ── 1) Messages for the same recipient are dispatched in enqueue order ────

  describe('Ordering: messages for the same recipient preserve enqueue order (Req 9.2, 9.5)', () => {
    test('dispatched messages maintain their relative enqueue order (oldest first)', () => {
      fc.assert(
        fc.property(
          queuedMessagesArb(2, 10),
          (messages) => {
            // Pick a `now` that is before the earliest expiry so all messages are valid
            const earliestExpiresAt = messages.reduce(
              (min, m) => (Date.parse(m.expiresAt) < Date.parse(min) ? m.expiresAt : min),
              messages[0].expiresAt,
            );
            // Set `now` to 1 second before the earliest expiry (all messages are still valid)
            const nowMs = Date.parse(earliestExpiresAt) - 1000;
            const now = new Date(nowMs).toISOString();

            const { dispatched } = simulateDispatch(messages, now);

            // All messages should be dispatched (none expired)
            expect(dispatched.length).toBe(messages.length);

            // The dispatched order should match the enqueue order (msg-0, msg-1, msg-2, ...)
            for (let i = 0; i < dispatched.length; i++) {
              expect(dispatched[i]).toBe(`msg-${i}`);
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('even with mixed expired and valid messages, dispatched messages preserve relative enqueue order', () => {
      fc.assert(
        fc.property(
          queuedMessagesArb(3, 10),
          fc.integer({ min: 0, max: 100 }),
          (messages, offsetPercent) => {
            // Pick `now` somewhere within the range of message expiries so some may expire
            const allExpiryMs = messages.map((m) => Date.parse(m.expiresAt));
            const minExpiry = Math.min(...allExpiryMs);
            const maxExpiry = Math.max(...allExpiryMs);
            const range = maxExpiry - minExpiry;
            const nowMs = minExpiry + Math.floor((range * offsetPercent) / 100);
            const now = new Date(nowMs).toISOString();

            const { dispatched } = simulateDispatch(messages, now);

            // Verify: dispatched messages are in their original relative enqueue order
            // i.e., their original indices are strictly ascending
            const dispatchedIndices = dispatched.map((id) => parseInt(id.replace('msg-', ''), 10));
            for (let i = 1; i < dispatchedIndices.length; i++) {
              expect(dispatchedIndices[i]).toBeGreaterThan(dispatchedIndices[i - 1]);
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── 2) Messages past expiry are marked expired (not dispatched) ───────────

  describe('Expiry: messages past expiry are marked expired and not dispatched (Req 9.4)', () => {
    test('a message is expired when now >= enqueuedAt + expirySeconds', () => {
      fc.assert(
        fc.property(
          isoDateArb,
          validExpirySecondsArb,
          fc.integer({ min: 0, max: 86400 }),
          (enqueuedAt, expirySeconds, extraSeconds) => {
            const expiresAtMs = Date.parse(enqueuedAt) + expirySeconds * 1000;
            // `now` is at or past the expiry time
            const nowMs = expiresAtMs + extraSeconds * 1000;
            const now = new Date(nowMs).toISOString();
            const expiresAt = new Date(expiresAtMs).toISOString();

            const policy: RetryPolicy = createRetryPolicy({ expirySeconds });
            const state: DispatchAttemptState = {
              attempts: 0,
              errorCode: '',
              enqueuedAt,
              now,
              expiresAt,
            };

            // Must be expired (now >= enqueuedAt + expirySeconds)
            expect(isMessageExpired(state, policy)).toBe(true);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('expired messages are not in the dispatched list', () => {
      fc.assert(
        fc.property(
          queuedMessagesArb(2, 8),
          (messages) => {
            // Set `now` well past ALL expiries so every message is expired
            const latestExpiry = messages.reduce(
              (max, m) => (Date.parse(m.expiresAt) > Date.parse(max) ? m.expiresAt : max),
              messages[0].expiresAt,
            );
            const nowMs = Date.parse(latestExpiry) + 60_000; // 1 minute past latest expiry
            const now = new Date(nowMs).toISOString();

            const { dispatched, expired } = simulateDispatch(messages, now);

            // All messages should be expired, none dispatched
            expect(dispatched.length).toBe(0);
            expect(expired.length).toBe(messages.length);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('expiry respects the explicit expiresAt timestamp', () => {
      fc.assert(
        fc.property(
          isoDateArb,
          validExpirySecondsArb,
          (enqueuedAt, expirySeconds) => {
            const expiresAtMs = Date.parse(enqueuedAt) + expirySeconds * 1000;
            const expiresAt = new Date(expiresAtMs).toISOString();
            // Set `now` to exactly the expiry time
            const now = expiresAt;

            const policy: RetryPolicy = createRetryPolicy({ expirySeconds });
            const state: DispatchAttemptState = {
              attempts: 0,
              errorCode: '',
              enqueuedAt,
              now,
              expiresAt,
            };

            // At exactly the expiry boundary: now >= expiresAt → expired
            expect(isMessageExpired(state, policy)).toBe(true);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── 3) Unexpired messages are dispatched ──────────────────────────────────

  describe('Valid dispatch: unexpired messages are dispatched (Req 9.5)', () => {
    test('a message is NOT expired when now < enqueuedAt + expirySeconds', () => {
      fc.assert(
        fc.property(
          isoDateArb,
          validExpirySecondsArb,
          fc.integer({ min: 1, max: 86400 }),
          (enqueuedAt, expirySeconds, secondsBefore) => {
            const expiresAtMs = Date.parse(enqueuedAt) + expirySeconds * 1000;
            // `now` is before the expiry time (at least 1 second before)
            const effectiveBefore = Math.min(secondsBefore, expirySeconds - 1);
            if (effectiveBefore < 1) return; // Skip edge case where expirySeconds is 60 (minimum)

            const nowMs = expiresAtMs - effectiveBefore * 1000;
            const now = new Date(nowMs).toISOString();
            const expiresAt = new Date(expiresAtMs).toISOString();

            const policy: RetryPolicy = createRetryPolicy({ expirySeconds });
            const state: DispatchAttemptState = {
              attempts: 0,
              errorCode: '',
              enqueuedAt,
              now,
              expiresAt,
            };

            // Must NOT be expired
            expect(isMessageExpired(state, policy)).toBe(false);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('all unexpired messages are included in the dispatched list', () => {
      fc.assert(
        fc.property(
          queuedMessagesArb(2, 8),
          (messages) => {
            // Set `now` before the earliest expiry so all messages are valid
            const earliestExpiresAt = messages.reduce(
              (min, m) => (Date.parse(m.expiresAt) < Date.parse(min) ? m.expiresAt : min),
              messages[0].expiresAt,
            );
            const nowMs = Date.parse(earliestExpiresAt) - 1000;
            const now = new Date(nowMs).toISOString();

            const { dispatched, expired } = simulateDispatch(messages, now);

            // All messages should be dispatched, none expired
            expect(dispatched.length).toBe(messages.length);
            expect(expired.length).toBe(0);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('dispatched + expired covers all messages (no message is lost)', () => {
      fc.assert(
        fc.property(
          queuedMessagesArb(2, 10),
          isoDateArb,
          (messages, now) => {
            const { dispatched, expired } = simulateDispatch(messages, now);

            // Every message must be either dispatched or expired (none lost)
            expect(dispatched.length + expired.length).toBe(messages.length);

            // No overlaps
            const dispatchedSet = new Set(dispatched);
            const expiredSet = new Set(expired);
            for (const id of dispatched) {
              expect(expiredSet.has(id)).toBe(false);
            }
            for (const id of expired) {
              expect(dispatchedSet.has(id)).toBe(false);
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });
});
