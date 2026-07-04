/**
 * Property-Based Tests: Event Processing is Idempotent per (eventId, recipient)
 *
 * Feature: openwa-whatsapp-automation, Property 12
 *
 * **Validates: Requirements 3.4, 9.3**
 *
 * Property 12: Event processing is idempotent per (eventId, recipientId).
 *
 * The Automation_Engine SHALL process a Business_Event idempotently by comparing
 * the event identifier and recipient against prior processing records, and SHALL
 * NOT create a duplicate Outbound_Message for the same event identifier and
 * recipient (Req 3.4). Offline-created Outbound_Messages reconciled through the
 * Sync_Engine SHALL NOT create more than one Outbound_Message for the same event
 * and recipient (Req 9.3).
 *
 * This test verifies:
 *  1. First processing of (eventId, recipientId) succeeds (status: 'firstTime')
 *  2. Second processing of same pair is rejected (status: 'duplicate')
 *  3. Different (eventId, recipientId) pairs are independent
 *
 * Strategy: Mock DynamoDB putItem to simulate conditional write behavior
 * (`attribute_not_exists(PK)` — succeeds first time, throws
 * ConditionalCheckFailedException on subsequent calls with the same key).
 */

import * as fc from 'fast-check';

// ── Mock DynamoDB operations ─────────────────────────────────────────────────

/**
 * In-memory store simulating DynamoDB conditional writes.
 * Keyed by `PK#SK` compound key; putItem with `attribute_not_exists(PK)`
 * throws ConditionalCheckFailedException if the key already exists.
 */
const inMemoryStore = new Map<string, Record<string, unknown>>();

const mockPutItem = jest.fn(
  async (item: Record<string, unknown>, conditionExpression?: string) => {
    const compoundKey = `${item.PK}#${item.SK}`;

    if (
      conditionExpression === 'attribute_not_exists(PK)' &&
      inMemoryStore.has(compoundKey)
    ) {
      const err = new Error('The conditional request failed');
      err.name = 'ConditionalCheckFailedException';
      throw err;
    }

    inMemoryStore.set(compoundKey, { ...item });
  },
);

const mockGetItem = jest.fn(
  async (pk: string, sk: string) => {
    const compoundKey = `${pk}#${sk}`;
    return inMemoryStore.get(compoundKey) ?? null;
  },
);

jest.mock('../../../../config/dynamodb.config', () => ({
  putItem: (...args: unknown[]) => mockPutItem(...(args as [Record<string, unknown>, string?])),
  getItem: (...args: unknown[]) => mockGetItem(...(args as [string, string])),
}));

import { checkAndMarkProcessed, isAlreadyProcessed } from '../../services/idempotency.service';

// ── Generators ───────────────────────────────────────────────────────────────

/** Characters safe for DynamoDB key segments (excludes '#') */
const SAFE_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';

/** Generate a valid ID segment: non-empty, no '#', no whitespace-only */
const safeIdArb = fc.stringOf(
  fc.constantFrom(...SAFE_CHARS.split('')),
  { minLength: 1, maxLength: 24 },
);

/** Generate a context tuple (tenantId, businessId) */
const contextArb = fc.tuple(safeIdArb, safeIdArb);

/** Generate an (eventId, recipientId) pair */
const eventRecipientArb = fc.tuple(safeIdArb, safeIdArb);

// ── Helpers ──────────────────────────────────────────────────────────────────

function clearStore() {
  inMemoryStore.clear();
  mockPutItem.mockClear();
  mockGetItem.mockClear();
}

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 12 — Event processing is idempotent per (eventId, recipient)', () => {
  beforeEach(() => {
    clearStore();
  });

  describe('1. First processing of (eventId, recipientId) succeeds', () => {
    it('checkAndMarkProcessed returns firstTime for any new (eventId, recipientId) pair', async () => {
      await fc.assert(
        fc.asyncProperty(
          contextArb,
          eventRecipientArb,
          async ([tenantId, businessId], [eventId, recipientId]) => {
            clearStore();

            const result = await checkAndMarkProcessed(
              tenantId,
              businessId,
              eventId,
              recipientId,
            );

            expect(result.status).toBe('firstTime');
          },
        ),
        { numRuns: 100 },
      );
    });

    it('first processing writes a marker to the store via conditional putItem', async () => {
      await fc.assert(
        fc.asyncProperty(
          contextArb,
          eventRecipientArb,
          async ([tenantId, businessId], [eventId, recipientId]) => {
            clearStore();

            await checkAndMarkProcessed(tenantId, businessId, eventId, recipientId);

            // putItem called exactly once with attribute_not_exists condition
            expect(mockPutItem).toHaveBeenCalledTimes(1);
            const [item, condition] = mockPutItem.mock.calls[0];
            expect(condition).toBe('attribute_not_exists(PK)');

            // The stored item contains the identifying fields
            expect(item.eventId).toBe(eventId);
            expect(item.recipientId).toBe(recipientId);
            expect(item.tenantId).toBe(tenantId);
            expect(item.businessId).toBe(businessId);
            expect(item.createdAt).toBeDefined();
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('2. Second processing of same pair is rejected (already processed)', () => {
    it('checkAndMarkProcessed returns duplicate on second call with same (eventId, recipientId)', async () => {
      await fc.assert(
        fc.asyncProperty(
          contextArb,
          eventRecipientArb,
          async ([tenantId, businessId], [eventId, recipientId]) => {
            clearStore();

            // First call: succeeds
            const first = await checkAndMarkProcessed(
              tenantId,
              businessId,
              eventId,
              recipientId,
            );
            expect(first.status).toBe('firstTime');

            // Second call: duplicate
            const second = await checkAndMarkProcessed(
              tenantId,
              businessId,
              eventId,
              recipientId,
            );
            expect(second.status).toBe('duplicate');
          },
        ),
        { numRuns: 100 },
      );
    });

    it('repeated calls (N>1) for the same pair always return duplicate after the first', async () => {
      await fc.assert(
        fc.asyncProperty(
          contextArb,
          eventRecipientArb,
          fc.integer({ min: 2, max: 5 }),
          async ([tenantId, businessId], [eventId, recipientId], repeatCount) => {
            clearStore();

            // First call succeeds
            const first = await checkAndMarkProcessed(
              tenantId,
              businessId,
              eventId,
              recipientId,
            );
            expect(first.status).toBe('firstTime');

            // All subsequent calls return duplicate
            for (let i = 0; i < repeatCount; i++) {
              const result = await checkAndMarkProcessed(
                tenantId,
                businessId,
                eventId,
                recipientId,
              );
              expect(result.status).toBe('duplicate');
            }
          },
        ),
        { numRuns: 100 },
      );
    });

    it('isAlreadyProcessed returns true after checkAndMarkProcessed succeeds', async () => {
      await fc.assert(
        fc.asyncProperty(
          contextArb,
          eventRecipientArb,
          async ([tenantId, businessId], [eventId, recipientId]) => {
            clearStore();

            // Before marking: not processed
            const before = await isAlreadyProcessed(
              tenantId,
              businessId,
              eventId,
              recipientId,
            );
            expect(before).toBe(false);

            // Mark it
            await checkAndMarkProcessed(tenantId, businessId, eventId, recipientId);

            // After marking: processed
            const after = await isAlreadyProcessed(
              tenantId,
              businessId,
              eventId,
              recipientId,
            );
            expect(after).toBe(true);
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('3. Different (eventId, recipientId) pairs are independent', () => {
    it('distinct eventIds with same recipientId are independently deduplicated', async () => {
      await fc.assert(
        fc.asyncProperty(
          contextArb,
          safeIdArb, // eventId1
          safeIdArb, // eventId2
          safeIdArb, // shared recipientId
          async ([tenantId, businessId], eventId1, eventId2, recipientId) => {
            // Skip when eventIds happen to collide
            fc.pre(eventId1 !== eventId2);
            clearStore();

            // Process first (eventId1, recipientId) → firstTime
            const r1 = await checkAndMarkProcessed(
              tenantId,
              businessId,
              eventId1,
              recipientId,
            );
            expect(r1.status).toBe('firstTime');

            // Process different (eventId2, recipientId) → still firstTime
            const r2 = await checkAndMarkProcessed(
              tenantId,
              businessId,
              eventId2,
              recipientId,
            );
            expect(r2.status).toBe('firstTime');

            // Duplicate of first → duplicate
            const r1Dup = await checkAndMarkProcessed(
              tenantId,
              businessId,
              eventId1,
              recipientId,
            );
            expect(r1Dup.status).toBe('duplicate');
          },
        ),
        { numRuns: 100 },
      );
    });

    it('same eventId with distinct recipientIds are independently deduplicated', async () => {
      await fc.assert(
        fc.asyncProperty(
          contextArb,
          safeIdArb, // shared eventId
          safeIdArb, // recipientId1
          safeIdArb, // recipientId2
          async ([tenantId, businessId], eventId, recipientId1, recipientId2) => {
            // Skip when recipientIds happen to collide
            fc.pre(recipientId1 !== recipientId2);
            clearStore();

            // Process (eventId, recipientId1) → firstTime
            const r1 = await checkAndMarkProcessed(
              tenantId,
              businessId,
              eventId,
              recipientId1,
            );
            expect(r1.status).toBe('firstTime');

            // Process (eventId, recipientId2) → firstTime (independent)
            const r2 = await checkAndMarkProcessed(
              tenantId,
              businessId,
              eventId,
              recipientId2,
            );
            expect(r2.status).toBe('firstTime');

            // Duplicate of first pair → duplicate
            const r1Dup = await checkAndMarkProcessed(
              tenantId,
              businessId,
              eventId,
              recipientId1,
            );
            expect(r1Dup.status).toBe('duplicate');
          },
        ),
        { numRuns: 100 },
      );
    });

    it('completely distinct (eventId, recipientId) pairs never interfere', async () => {
      await fc.assert(
        fc.asyncProperty(
          contextArb,
          fc.array(eventRecipientArb, { minLength: 2, maxLength: 8 }),
          async ([tenantId, businessId], pairs) => {
            clearStore();

            // Deduplicate pairs (use string key) to get a unique set
            const seen = new Set<string>();
            const uniquePairs = pairs.filter(([eid, rid]) => {
              const key = `${eid}|${rid}`;
              if (seen.has(key)) return false;
              seen.add(key);
              return true;
            });

            // Skip if fewer than 2 unique pairs after dedup
            fc.pre(uniquePairs.length >= 2);

            // First pass: all unique pairs should succeed
            for (const [eventId, recipientId] of uniquePairs) {
              const result = await checkAndMarkProcessed(
                tenantId,
                businessId,
                eventId,
                recipientId,
              );
              expect(result.status).toBe('firstTime');
            }

            // Second pass: all should be duplicates
            for (const [eventId, recipientId] of uniquePairs) {
              const result = await checkAndMarkProcessed(
                tenantId,
                businessId,
                eventId,
                recipientId,
              );
              expect(result.status).toBe('duplicate');
            }
          },
        ),
        { numRuns: 100 },
      );
    });
  });
});
