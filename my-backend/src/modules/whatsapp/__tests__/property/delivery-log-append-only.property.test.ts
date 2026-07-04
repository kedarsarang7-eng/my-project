/**
 * Property-Based Tests: Delivery_Log is Append-Only Across Lifecycle Transitions
 *
 * Feature: openwa-whatsapp-automation, Property 24
 *
 * **Validates: Requirements 8.3**
 *
 * Property 24: Delivery_Log is append-only across lifecycle transitions.
 *
 * For any sequence of lifecycle state transitions for an Outbound_Message,
 * each transition appends a new immutable Delivery_Log entry (message id, state,
 * UTC timestamp) and leaves every previously recorded entry unchanged.
 *
 * This test verifies:
 *  1. DeliveryLogRepository only exposes a create method (no update, no delete)
 *  2. Each log entry records state transitions as new append-only items (not modifications)
 *  3. Multiple state transitions for the same outboundMessageId produce multiple entries
 *  4. The repository never allows deletion of existing log entries
 *
 * Strategy: Mock DynamoDB, verify putItem is used (never updateItem/deleteItem for the log).
 */

import * as fc from 'fast-check';

// ── Mock DynamoDB operations ─────────────────────────────────────────────────

const mockPutItem = jest.fn().mockResolvedValue(undefined);
const mockGetItem = jest.fn().mockResolvedValue(null);
const mockQueryItems = jest.fn().mockResolvedValue({ items: [], lastKey: undefined });
const mockUpdateItem = jest.fn().mockResolvedValue(null);
const mockDeleteItem = jest.fn().mockResolvedValue(undefined);

jest.mock('../../../../config/dynamodb.config', () => ({
  putItem: (...args: unknown[]) => mockPutItem(...args),
  getItem: (...args: unknown[]) => mockGetItem(...args),
  queryItems: (...args: unknown[]) => mockQueryItems(...args),
  updateItem: (...args: unknown[]) => mockUpdateItem(...args),
  deleteItem: (...args: unknown[]) => mockDeleteItem(...args),
}));

import { DeliveryLogRepository } from '../../repositories/delivery-log.repository';

// ── Generators ───────────────────────────────────────────────────────────────

/** Characters safe for DynamoDB key segments (excludes '#') */
const SAFE_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';

/** Generate a valid ID segment: non-empty, no '#', no whitespace-only */
const safeIdArb = fc.stringOf(
  fc.constantFrom(...SAFE_CHARS.split('')),
  { minLength: 1, maxLength: 32 },
);

/** All valid delivery log states from the schema */
const DELIVERY_LOG_STATES = [
  'queued', 'sent', 'delivered', 'read', 'failed', 'expired', 'suppressed',
] as const;

type DeliveryLogState = typeof DELIVERY_LOG_STATES[number];

/** Arbitrary for a single delivery log state */
const deliveryLogStateArb = fc.constantFrom(...DELIVERY_LOG_STATES);

/** Arbitrary for a non-empty sequence of state transitions (1..7 states) */
const stateSequenceArb = fc.array(deliveryLogStateArb, { minLength: 1, maxLength: 7 });

/** Optional reason string */
const optionalReasonArb = fc.option(
  fc.string({ minLength: 1, maxLength: 100 }),
  { nil: undefined },
);

// ── Helpers ──────────────────────────────────────────────────────────────────

function clearMocks() {
  mockPutItem.mockClear();
  mockGetItem.mockClear();
  mockQueryItems.mockClear();
  mockUpdateItem.mockClear();
  mockDeleteItem.mockClear();
}

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 24 — Delivery_Log is append-only across lifecycle transitions', () => {
  const repo = new DeliveryLogRepository();

  beforeEach(() => {
    clearMocks();
  });

  describe('1. DeliveryLogRepository only exposes create (no update, no delete)', () => {
    it('the repository class has no update method', () => {
      expect((repo as any).update).toBeUndefined();
      expect((repo as any).updateItem).toBeUndefined();
      expect((repo as any).modify).toBeUndefined();
      expect((repo as any).patch).toBeUndefined();
      expect((repo as any).edit).toBeUndefined();
    });

    it('the repository class has no delete method', () => {
      expect((repo as any).delete).toBeUndefined();
      expect((repo as any).deleteItem).toBeUndefined();
      expect((repo as any).remove).toBeUndefined();
      expect((repo as any).destroy).toBeUndefined();
      expect((repo as any).deactivate).toBeUndefined();
      expect((repo as any).softDelete).toBeUndefined();
    });

    it('the repository exposes only read and create operations', () => {
      const publicMethods = Object.getOwnPropertyNames(
        Object.getPrototypeOf(repo),
      ).filter((name) => name !== 'constructor');

      // Only allowed methods: create, get, listByWindow, listByMessageId
      const allowedMethods = ['create', 'get', 'listByWindow', 'listByMessageId'];
      for (const method of publicMethods) {
        expect(allowedMethods).toContain(method);
      }
    });
  });

  describe('2. Each state transition appends a new entry via putItem (not updateItem)', () => {
    it('create() always calls putItem with attribute_not_exists condition', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          safeIdArb, // outboundMessageId
          deliveryLogStateArb, // state
          optionalReasonArb, // reason
          async (tenantId, businessId, outboundMessageId, state, reason) => {
            clearMocks();
            mockPutItem.mockResolvedValue(undefined);

            await repo.create(tenantId, businessId, {
              outboundMessageId,
              state,
              reason,
            });

            // putItem is the ONLY write operation used
            expect(mockPutItem).toHaveBeenCalledTimes(1);
            // updateItem and deleteItem are NEVER called
            expect(mockUpdateItem).not.toHaveBeenCalled();
            expect(mockDeleteItem).not.toHaveBeenCalled();

            // Verify putItem was called with the conditional expression
            // to prevent overwriting (append-only guarantee)
            const conditionExpr = mockPutItem.mock.calls[0][1];
            expect(conditionExpr).toBe('attribute_not_exists(SK)');
          },
        ),
        { numRuns: 100 },
      );
    });

    it('each entry contains the outboundMessageId, state, and UTC timestamp', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          safeIdArb, // outboundMessageId
          deliveryLogStateArb, // state
          async (tenantId, businessId, outboundMessageId, state) => {
            clearMocks();
            mockPutItem.mockResolvedValue(undefined);

            const result = await repo.create(tenantId, businessId, {
              outboundMessageId,
              state,
            });

            // Returned entry contains the correct fields
            expect(result.outboundMessageId).toBe(outboundMessageId);
            expect(result.state).toBe(state);
            expect(result.timestamp).toBeDefined();
            // Timestamp is a valid ISO-8601 UTC string
            expect(new Date(result.timestamp).toISOString()).toBe(result.timestamp);
            // ID is assigned
            expect(result.id).toBeDefined();
            expect(result.id.length).toBeGreaterThan(0);
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('3. Multiple state transitions for the same outboundMessageId produce multiple entries', () => {
    it('N state transitions create N distinct putItem calls with unique SKs', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          safeIdArb, // outboundMessageId
          stateSequenceArb, // sequence of states
          async (tenantId, businessId, outboundMessageId, states) => {
            clearMocks();
            mockPutItem.mockResolvedValue(undefined);

            const results = [];
            for (const state of states) {
              const entry = await repo.create(tenantId, businessId, {
                outboundMessageId,
                state,
              });
              results.push(entry);
            }

            // putItem called exactly N times (one per state transition)
            expect(mockPutItem).toHaveBeenCalledTimes(states.length);

            // Each call uses putItem (append), never updateItem or deleteItem
            expect(mockUpdateItem).not.toHaveBeenCalled();
            expect(mockDeleteItem).not.toHaveBeenCalled();

            // Each entry gets a unique ID (no overwrites)
            const ids = results.map((r) => r.id);
            const uniqueIds = new Set(ids);
            expect(uniqueIds.size).toBe(states.length);

            // Each putItem call has a unique SK (timestamp+logId)
            const sks = mockPutItem.mock.calls.map(
              ([item]: [Record<string, unknown>]) => item.SK,
            );
            const uniqueSKs = new Set(sks);
            expect(uniqueSKs.size).toBe(states.length);

            // All entries reference the same outboundMessageId
            for (const [item] of mockPutItem.mock.calls) {
              expect((item as Record<string, unknown>).outboundMessageId).toBe(
                outboundMessageId,
              );
            }
          },
        ),
        { numRuns: 100 },
      );
    });

    it('entries for the same message have different timestamps or IDs (never overwritten)', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          safeIdArb, // outboundMessageId
          fc.array(deliveryLogStateArb, { minLength: 2, maxLength: 5 }),
          async (tenantId, businessId, outboundMessageId, states) => {
            clearMocks();
            mockPutItem.mockResolvedValue(undefined);

            const results = [];
            for (const state of states) {
              const entry = await repo.create(tenantId, businessId, {
                outboundMessageId,
                state,
              });
              results.push(entry);
            }

            // Verify no two entries share the same id
            for (let i = 0; i < results.length; i++) {
              for (let j = i + 1; j < results.length; j++) {
                expect(results[i].id).not.toBe(results[j].id);
              }
            }
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('4. The repository never allows deletion of existing log entries', () => {
    it('no repository method invokes deleteItem regardless of inputs', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          safeIdArb, // outboundMessageId
          deliveryLogStateArb, // state
          async (tenantId, businessId, outboundMessageId, state) => {
            clearMocks();
            mockPutItem.mockResolvedValue(undefined);
            mockGetItem.mockResolvedValue(null);
            mockQueryItems.mockResolvedValue({ items: [] });

            // Exercise every public method
            await repo.create(tenantId, businessId, { outboundMessageId, state });
            await repo.get(tenantId, businessId, '2024-01-01T00:00:00.000Z', 'some-id');
            await repo.listByWindow(tenantId, businessId);
            await repo.listByMessageId(tenantId, businessId, outboundMessageId);

            // deleteItem must NEVER have been called
            expect(mockDeleteItem).not.toHaveBeenCalled();
            // updateItem must NEVER have been called
            expect(mockUpdateItem).not.toHaveBeenCalled();
          },
        ),
        { numRuns: 100 },
      );
    });

    it('putItem uses attribute_not_exists to prevent overwriting existing entries', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          safeIdArb, // outboundMessageId
          stateSequenceArb, // states
          async (tenantId, businessId, outboundMessageId, states) => {
            clearMocks();
            mockPutItem.mockResolvedValue(undefined);

            for (const state of states) {
              await repo.create(tenantId, businessId, { outboundMessageId, state });
            }

            // Every single putItem call carries the immutability condition
            for (const call of mockPutItem.mock.calls) {
              expect(call[1]).toBe('attribute_not_exists(SK)');
            }
          },
        ),
        { numRuns: 100 },
      );
    });
  });
});
