// ============================================================================
// Property-Based Test — Low-Stock Alert Hysteresis
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 21
//
// Validates: Requirements 11.3
//
// Property 21 (design.md): Low-stock alerts fire once per below-threshold
// crossing with hysteresis.
//
// Verifies:
// 1. First drop below threshold fires alert
// 2. Subsequent drops (without returning above) do NOT re-fire
// 3. After returning above threshold, next drop fires again
// 4. Threshold range 0..999,999
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  evaluateLowStockAlert,
  isValidThreshold,
  isValidInventoryLevel,
  MIN_THRESHOLD,
  MAX_THRESHOLD,
  type StockLevelEvent,
  type LowStockAlertDecision,
} from '../../services/lowstock-alert.service';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates a valid threshold in [0, 999_999]. */
const thresholdArb: fc.Arbitrary<number> = fc.integer({
  min: MIN_THRESHOLD,
  max: MAX_THRESHOLD,
});

/** Generates a valid inventory level (non-negative integer). */
const inventoryLevelArb: fc.Arbitrary<number> = fc.integer({
  min: 0,
  max: 2_000_000, // allow above max threshold for recovery scenarios
});

/** Generates a businessId string. */
const businessIdArb: fc.Arbitrary<string> = fc
  .stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789'), {
    minLength: 4,
    maxLength: 16,
  })
  .map((s) => `biz_${s}`);

/** Generates a productId string. */
const productIdArb: fc.Arbitrary<string> = fc
  .stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789'), {
    minLength: 4,
    maxLength: 16,
  })
  .map((s) => `prod_${s}`);

/** Generates a StockLevelEvent with a level strictly below the threshold (requires threshold > 0). */
const belowThresholdEventArb: fc.Arbitrary<StockLevelEvent> = fc
  .tuple(businessIdArb, productIdArb, fc.integer({ min: 1, max: MAX_THRESHOLD }))
  .chain(([businessId, productId, threshold]) =>
    fc.integer({ min: 0, max: threshold - 1 }).map((currentLevel) => ({
      businessId,
      productId,
      currentLevel,
      threshold,
    })),
  );

/** Generates a StockLevelEvent with a level at or above the threshold. */
const atOrAboveThresholdEventArb: fc.Arbitrary<StockLevelEvent> = fc
  .tuple(businessIdArb, productIdArb, thresholdArb)
  .chain(([businessId, productId, threshold]) =>
    fc.integer({ min: threshold, max: threshold + 100_000 }).map((currentLevel) => ({
      businessId,
      productId,
      currentLevel,
      threshold,
    })),
  );

// ── Property 21: Low-stock alerts fire once per below-threshold crossing ─────

describe('Feature: openwa-whatsapp-automation, Property 21: Low-stock alerts fire once per below-threshold crossing with hysteresis', () => {
  // ── Sub-property 1: First drop below threshold fires alert ─────────────────

  test('first drop below threshold fires alert when no prior marker is active (Req 11.3)', () => {
    fc.assert(
      fc.property(belowThresholdEventArb, (event) => {
        const decision = evaluateLowStockAlert(event, false);

        // Should fire alert
        expect(decision.shouldAlert).toBe(true);
        // Should set marker to true (alert is now active)
        expect(decision.newMarkerState).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 2: Subsequent drops without recovery do NOT re-fire ───────

  test('subsequent drops below threshold with active marker do NOT re-fire (Req 11.3)', () => {
    fc.assert(
      fc.property(belowThresholdEventArb, (event) => {
        // Marker is already active (alert was previously fired)
        const decision = evaluateLowStockAlert(event, true);

        // Should NOT fire another alert (hysteresis suppression)
        expect(decision.shouldAlert).toBe(false);
        // Marker stays active
        expect(decision.newMarkerState).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 3: After returning above threshold, next drop fires again ──

  test('after recovery to/above threshold, next drop below fires a new alert (Req 11.3)', () => {
    fc.assert(
      fc.property(
        // Generate a threshold > 0 so we can have a valid below-threshold level
        fc.integer({ min: 1, max: MAX_THRESHOLD }),
        businessIdArb,
        productIdArb,
        (threshold, businessId, productId) => {
          // Step 1: First drop below threshold — fires alert
          const belowLevel = fc.sample(
            fc.integer({ min: 0, max: threshold - 1 }),
            1,
          )[0];
          const firstDrop: StockLevelEvent = {
            businessId,
            productId,
            currentLevel: belowLevel,
            threshold,
          };
          const firstDecision = evaluateLowStockAlert(firstDrop, false);
          expect(firstDecision.shouldAlert).toBe(true);
          expect(firstDecision.newMarkerState).toBe(true);

          // Step 2: Recovery to at/above threshold — clears marker
          const recoveryLevel = fc.sample(
            fc.integer({ min: threshold, max: threshold + 100_000 }),
            1,
          )[0];
          const recovery: StockLevelEvent = {
            businessId,
            productId,
            currentLevel: recoveryLevel,
            threshold,
          };
          const recoveryDecision = evaluateLowStockAlert(
            recovery,
            firstDecision.newMarkerState,
          );
          expect(recoveryDecision.shouldAlert).toBe(false);
          expect(recoveryDecision.newMarkerState).toBe(false);

          // Step 3: Second drop below threshold — fires again
          const secondBelow = fc.sample(
            fc.integer({ min: 0, max: threshold - 1 }),
            1,
          )[0];
          const secondDrop: StockLevelEvent = {
            businessId,
            productId,
            currentLevel: secondBelow,
            threshold,
          };
          const secondDecision = evaluateLowStockAlert(
            secondDrop,
            recoveryDecision.newMarkerState,
          );
          expect(secondDecision.shouldAlert).toBe(true);
          expect(secondDecision.newMarkerState).toBe(true);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 4: Threshold range [0, 999_999] validation ────────────────

  test('isValidThreshold accepts all integers in [0, 999_999] (Req 11.3)', () => {
    fc.assert(
      fc.property(thresholdArb, (threshold) => {
        expect(isValidThreshold(threshold)).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('isValidThreshold rejects integers outside [0, 999_999]', () => {
    fc.assert(
      fc.property(
        fc.oneof(
          fc.integer({ min: -1_000_000, max: -1 }),
          fc.integer({ min: 1_000_000, max: 10_000_000 }),
        ),
        (outOfRange) => {
          expect(isValidThreshold(outOfRange)).toBe(false);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  test('isValidThreshold rejects non-integer and non-finite values', () => {
    fc.assert(
      fc.property(
        fc.oneof(
          fc.double({ min: 0.01, max: 999_998.99, noNaN: true, noDefaultInfinity: true }),
          fc.constant(NaN),
          fc.constant(Infinity),
          fc.constant(-Infinity),
        ),
        (invalid) => {
          expect(isValidThreshold(invalid)).toBe(false);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Recovery clears marker regardless of prior state ─────────

  test('at-or-above threshold always clears the hysteresis marker (Req 11.3)', () => {
    fc.assert(
      fc.property(
        atOrAboveThresholdEventArb,
        fc.boolean(), // currentMarker can be true or false
        (event, currentMarker) => {
          const decision = evaluateLowStockAlert(event, currentMarker);

          // Never fire when at or above threshold
          expect(decision.shouldAlert).toBe(false);
          // Always clear the marker on recovery
          expect(decision.newMarkerState).toBe(false);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Multiple consecutive below-threshold events only fire once ─

  test('a sequence of below-threshold events only fires on the first one (Req 11.3)', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: MAX_THRESHOLD }),
        businessIdArb,
        productIdArb,
        fc.integer({ min: 2, max: 10 }), // number of consecutive below-threshold events
        (threshold, businessId, productId, count) => {
          let marker = false;
          let alertCount = 0;

          for (let i = 0; i < count; i++) {
            const level = fc.sample(
              fc.integer({ min: 0, max: threshold - 1 }),
              1,
            )[0];
            const event: StockLevelEvent = {
              businessId,
              productId,
              currentLevel: level,
              threshold,
            };
            const decision = evaluateLowStockAlert(event, marker);
            if (decision.shouldAlert) alertCount++;
            marker = decision.newMarkerState;
          }

          // Only the first event in the sequence should have fired
          expect(alertCount).toBe(1);
          // Marker should be active after the sequence
          expect(marker).toBe(true);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Each recovery+drop cycle fires exactly once ──────────────

  test('each recovery-then-drop cycle fires exactly one alert (Req 11.3)', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: MAX_THRESHOLD }),
        businessIdArb,
        productIdArb,
        fc.integer({ min: 1, max: 5 }), // number of cycles
        (threshold, businessId, productId, cycles) => {
          let marker = false;
          let totalAlerts = 0;

          for (let c = 0; c < cycles; c++) {
            // Drop below
            const belowLevel = fc.sample(
              fc.integer({ min: 0, max: threshold - 1 }),
              1,
            )[0];
            const dropEvent: StockLevelEvent = {
              businessId,
              productId,
              currentLevel: belowLevel,
              threshold,
            };
            const dropDecision = evaluateLowStockAlert(dropEvent, marker);
            if (dropDecision.shouldAlert) totalAlerts++;
            marker = dropDecision.newMarkerState;

            // Recover
            const aboveLevel = fc.sample(
              fc.integer({ min: threshold, max: threshold + 100_000 }),
              1,
            )[0];
            const recoverEvent: StockLevelEvent = {
              businessId,
              productId,
              currentLevel: aboveLevel,
              threshold,
            };
            const recoverDecision = evaluateLowStockAlert(recoverEvent, marker);
            if (recoverDecision.shouldAlert) totalAlerts++;
            marker = recoverDecision.newMarkerState;
          }

          // Exactly one alert per cycle
          expect(totalAlerts).toBe(cycles);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Anchored example checks (unit) ─────────────────────────────────────────

  test('example: threshold 0 means no level can be below threshold', () => {
    const event: StockLevelEvent = {
      businessId: 'biz_test',
      productId: 'prod_test',
      currentLevel: 0,
      threshold: 0,
    };
    // Level 0 is AT threshold 0, so no alert
    const decision = evaluateLowStockAlert(event, false);
    expect(decision.shouldAlert).toBe(false);
    expect(decision.newMarkerState).toBe(false);
  });

  test('example: classic single drop-then-suppress-then-recover-then-fire cycle', () => {
    const base: Omit<StockLevelEvent, 'currentLevel'> = {
      businessId: 'biz_example',
      productId: 'prod_widget',
      threshold: 10,
    };

    // Step 1: Drop to 5 (below 10) — should fire
    const d1 = evaluateLowStockAlert({ ...base, currentLevel: 5 }, false);
    expect(d1.shouldAlert).toBe(true);
    expect(d1.newMarkerState).toBe(true);

    // Step 2: Drop further to 2 — should NOT fire (hysteresis active)
    const d2 = evaluateLowStockAlert({ ...base, currentLevel: 2 }, d1.newMarkerState);
    expect(d2.shouldAlert).toBe(false);
    expect(d2.newMarkerState).toBe(true);

    // Step 3: Recover to 10 (at threshold) — clears marker
    const d3 = evaluateLowStockAlert({ ...base, currentLevel: 10 }, d2.newMarkerState);
    expect(d3.shouldAlert).toBe(false);
    expect(d3.newMarkerState).toBe(false);

    // Step 4: Drop to 7 again — should fire again
    const d4 = evaluateLowStockAlert({ ...base, currentLevel: 7 }, d3.newMarkerState);
    expect(d4.shouldAlert).toBe(true);
    expect(d4.newMarkerState).toBe(true);
  });

  test('example: threshold at MAX_THRESHOLD boundary', () => {
    expect(isValidThreshold(MAX_THRESHOLD)).toBe(true);
    expect(isValidThreshold(MAX_THRESHOLD + 1)).toBe(false);
  });

  test('example: inventory level validation', () => {
    expect(isValidInventoryLevel(0)).toBe(true);
    expect(isValidInventoryLevel(999_999)).toBe(true);
    expect(isValidInventoryLevel(-1)).toBe(false);
    expect(isValidInventoryLevel(1.5)).toBe(false);
    expect(isValidInventoryLevel(NaN)).toBe(false);
  });
});
