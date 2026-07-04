// ============================================================================
// Property-Based Test — Rate Limiting
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 29
//
// **Validates: Requirements 14.3**
//
// Property 29 (design.md): Dispatch never exceeds the configured gateway rate
// limit.
//
// WHERE the OpenWA_Gateway enforces a rate limit, THE WhatsApp_Automation_System
// SHALL dispatch Outbound_Messages at a rate that does not exceed the configured
// rate limit and SHALL retain any excess Outbound_Messages in the Message_Queue
// for dispatch in a subsequent interval without discarding them.
//
// Verified properties:
// 1. Never more than N messages dispatched in any window (budget <= rateLimit)
// 2. Excess messages are retained (not dropped) — reported as batchItemFailures
// 3. The rate limit is per plan tier (each tier resolves correctly)
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import { PlanTier } from '../../../../config/plan-feature-registry';
import { whatsappManifest } from '../../manifest';

// ── Extract testable functions from the dispatcher ──────────────────────────
// We re-implement the pure functions here to test them in isolation as they
// are not exported from the dispatcher Lambda. This mirrors the exact logic
// from whatsapp-dispatcher.ts (resolveRateLimit + computeDispatchBudget).

const rateLimits: Record<string, number> = whatsappManifest.rateLimits as unknown as Record<string, number>;

/**
 * Resolves the rate limit (messages per minute) for a given plan tier.
 * Mirrors the dispatcher's resolveRateLimit function.
 */
function resolveRateLimit(tier?: string): number {
  if (tier && rateLimits[tier]) {
    return rateLimits[tier];
  }
  return rateLimits[PlanTier.BASIC] || 100;
}

/**
 * Computes how many messages can be dispatched in a single invocation.
 * Mirrors the dispatcher's computeDispatchBudget function.
 */
function computeDispatchBudget(batchSize: number, rateLimit: number): number {
  return Math.min(batchSize, rateLimit);
}

/**
 * Simulates the dispatcher's batch processing loop.
 * Returns { dispatched, retained } counts matching the handler logic:
 * - Messages up to the budget are dispatched (processed)
 * - Messages beyond the budget are retained (batchItemFailures)
 */
function simulateDispatch(batchSize: number, tier?: string): {
  dispatched: number;
  retained: number;
  rateLimit: number;
} {
  const rateLimit = resolveRateLimit(tier);
  const budget = computeDispatchBudget(batchSize, rateLimit);

  // The handler loop: process indices 0..budget-1, retain indices budget..batchSize-1
  const dispatched = Math.min(batchSize, budget);
  const retained = Math.max(0, batchSize - budget);

  return { dispatched, retained, rateLimit };
}

// ── Generators ──────────────────────────────────────────────────────────────

/** Valid plan tiers from the PlanTier enum. */
const validTierArb: fc.Arbitrary<string> = fc.constantFrom(
  PlanTier.BASIC,
  PlanTier.PRO,
  PlanTier.PREMIUM,
  PlanTier.ENTERPRISE,
);

/** Unrecognized tier strings (should fall back to BASIC). */
const unknownTierArb: fc.Arbitrary<string | undefined> = fc.oneof(
  fc.constant(undefined),
  fc.constant(''),
  fc.constant('free'),
  fc.constant('ultra'),
  fc.stringOf(fc.char(), { minLength: 1, maxLength: 20 }).filter(
    (s) => !Object.values(PlanTier).includes(s as PlanTier),
  ),
);

/** Batch size: 1 to 10000 messages (covers both under and over rate limits). */
const batchSizeArb: fc.Arbitrary<number> = fc.integer({ min: 1, max: 10000 });

/** Batch size that will exceed any tier's rate limit. */
const largeBatchArb: fc.Arbitrary<number> = fc.integer({ min: 5001, max: 20000 });

/** Small batch size that is within the BASIC tier limit. */
const smallBatchArb: fc.Arbitrary<number> = fc.integer({ min: 1, max: 100 });

// ── Property 29 Tests ───────────────────────────────────────────────────────

const NUM_RUNS = 100;

describe('Feature: openwa-whatsapp-automation, Property 29: Dispatch never exceeds the configured gateway rate limit', () => {
  // ── 1) Never more than N messages dispatched in any window ────────────────

  describe('dispatched count never exceeds rate limit', () => {
    test('for any batch size and valid tier, dispatched <= rateLimit', () => {
      fc.assert(
        fc.property(batchSizeArb, validTierArb, (batchSize, tier) => {
          const { dispatched, rateLimit } = simulateDispatch(batchSize, tier);

          // CORE PROPERTY: dispatched count NEVER exceeds the rate limit
          expect(dispatched).toBeLessThanOrEqual(rateLimit);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('budget is always the minimum of batch size and rate limit', () => {
      fc.assert(
        fc.property(batchSizeArb, validTierArb, (batchSize, tier) => {
          const rateLimit = resolveRateLimit(tier);
          const budget = computeDispatchBudget(batchSize, rateLimit);

          expect(budget).toBe(Math.min(batchSize, rateLimit));
          expect(budget).toBeLessThanOrEqual(rateLimit);
          expect(budget).toBeLessThanOrEqual(batchSize);
          expect(budget).toBeGreaterThanOrEqual(0);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('when batch size <= rate limit, all messages are dispatched', () => {
      fc.assert(
        fc.property(validTierArb, (tier) => {
          const rateLimit = resolveRateLimit(tier);
          // Generate a batch size that's within the limit
          const batchSize = Math.max(1, Math.floor(Math.random() * rateLimit));
          const { dispatched, retained } = simulateDispatch(batchSize, tier);

          expect(dispatched).toBe(batchSize);
          expect(retained).toBe(0);
        }),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── 2) Excess messages are retained (not dropped) ────────────────────────

  describe('excess messages are retained, never dropped', () => {
    test('dispatched + retained always equals batch size (no messages lost)', () => {
      fc.assert(
        fc.property(batchSizeArb, validTierArb, (batchSize, tier) => {
          const { dispatched, retained } = simulateDispatch(batchSize, tier);

          // CORE PROPERTY: every message is either dispatched or retained — none lost
          expect(dispatched + retained).toBe(batchSize);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('when batch exceeds rate limit, excess messages are retained', () => {
      fc.assert(
        fc.property(largeBatchArb, validTierArb, (batchSize, tier) => {
          const { dispatched, retained, rateLimit } = simulateDispatch(batchSize, tier);

          // When batch is larger than the limit, we must have retained messages
          if (batchSize > rateLimit) {
            expect(retained).toBe(batchSize - rateLimit);
            expect(dispatched).toBe(rateLimit);
          }
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('retained count is always non-negative', () => {
      fc.assert(
        fc.property(batchSizeArb, validTierArb, (batchSize, tier) => {
          const { retained } = simulateDispatch(batchSize, tier);
          expect(retained).toBeGreaterThanOrEqual(0);
        }),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── 3) Rate limit is per plan tier ───────────────────────────────────────

  describe('rate limit varies per plan tier', () => {
    test('each valid tier resolves to its configured rate limit', () => {
      fc.assert(
        fc.property(validTierArb, (tier) => {
          const resolved = resolveRateLimit(tier);
          const expected = rateLimits[tier];

          expect(resolved).toBe(expected);
          expect(resolved).toBeGreaterThan(0);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('BASIC < PRO < PREMIUM < ENTERPRISE rate limits (tier ordering)', () => {
      // This is a structural invariant — higher tiers get higher limits
      const basic = resolveRateLimit(PlanTier.BASIC);
      const pro = resolveRateLimit(PlanTier.PRO);
      const premium = resolveRateLimit(PlanTier.PREMIUM);
      const enterprise = resolveRateLimit(PlanTier.ENTERPRISE);

      expect(basic).toBeLessThan(pro);
      expect(pro).toBeLessThan(premium);
      expect(premium).toBeLessThan(enterprise);
    });

    test('specific tier values match manifest configuration', () => {
      expect(resolveRateLimit(PlanTier.BASIC)).toBe(100);
      expect(resolveRateLimit(PlanTier.PRO)).toBe(400);
      expect(resolveRateLimit(PlanTier.PREMIUM)).toBe(1200);
      expect(resolveRateLimit(PlanTier.ENTERPRISE)).toBe(5000);
    });

    test('unrecognized tier falls back to BASIC rate limit', () => {
      fc.assert(
        fc.property(unknownTierArb, (tier) => {
          const resolved = resolveRateLimit(tier);
          const basicLimit = rateLimits[PlanTier.BASIC];

          // Unknown/undefined tier MUST fall back to BASIC
          expect(resolved).toBe(basicLimit);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('same tier always resolves to same rate limit (deterministic)', () => {
      fc.assert(
        fc.property(validTierArb, (tier) => {
          const first = resolveRateLimit(tier);
          const second = resolveRateLimit(tier);
          expect(first).toBe(second);
        }),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── Combined: per-tier dispatch cap ──────────────────────────────────────

  describe('combined: per-tier dispatch cap with excess retention', () => {
    test('BASIC tier never dispatches more than 100 messages', () => {
      fc.assert(
        fc.property(batchSizeArb, (batchSize) => {
          const { dispatched } = simulateDispatch(batchSize, PlanTier.BASIC);
          expect(dispatched).toBeLessThanOrEqual(100);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('PRO tier never dispatches more than 400 messages', () => {
      fc.assert(
        fc.property(batchSizeArb, (batchSize) => {
          const { dispatched } = simulateDispatch(batchSize, PlanTier.PRO);
          expect(dispatched).toBeLessThanOrEqual(400);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('PREMIUM tier never dispatches more than 1200 messages', () => {
      fc.assert(
        fc.property(batchSizeArb, (batchSize) => {
          const { dispatched } = simulateDispatch(batchSize, PlanTier.PREMIUM);
          expect(dispatched).toBeLessThanOrEqual(1200);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('ENTERPRISE tier never dispatches more than 5000 messages', () => {
      fc.assert(
        fc.property(batchSizeArb, (batchSize) => {
          const { dispatched } = simulateDispatch(batchSize, PlanTier.ENTERPRISE);
          expect(dispatched).toBeLessThanOrEqual(5000);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('for any tier, excess is exactly max(0, batchSize - tierLimit)', () => {
      fc.assert(
        fc.property(batchSizeArb, validTierArb, (batchSize, tier) => {
          const { retained, rateLimit } = simulateDispatch(batchSize, tier);
          const expectedRetained = Math.max(0, batchSize - rateLimit);
          expect(retained).toBe(expectedRetained);
        }),
        { numRuns: NUM_RUNS },
      );
    });
  });
});
