// ============================================================================
// Property-Based Test — Consent Gate Suppression
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 6
//
// Validates: Requirements 2.5, 3.5, 6.9, 13.5
//
// Property 6 (design.md): Consent gate suppresses non-transactional messages
// while allowing transactional ones.
//
// Verifies:
// 1. opted_in allows both transactional and non-transactional messages
// 2. opted_out/pending suppress non-transactional messages
// 3. opted_out/pending still allow transactional messages
// 4. The gate is purely a function of (consentState, category) — deterministic
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import { evaluateConsentGate } from '../../services/consent.service';
import type { ConsentState, MessageCategory } from '../../schemas/entities';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** All three legal consent state values. */
const consentStateArb: fc.Arbitrary<ConsentState> = fc.constantFrom(
  'opted_in' as ConsentState,
  'opted_out' as ConsentState,
  'pending' as ConsentState,
);

/** Consent states that block non-transactional messages. */
const nonOptedInStateArb: fc.Arbitrary<ConsentState> = fc.constantFrom(
  'opted_out' as ConsentState,
  'pending' as ConsentState,
);

/** Both message categories. */
const messageCategoryArb: fc.Arbitrary<MessageCategory> = fc.constantFrom(
  'transactional' as MessageCategory,
  'non_transactional' as MessageCategory,
);

// ── Property 6 ──────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 6: Consent gate suppresses non-transactional messages while allowing transactional ones', () => {
  // ── Sub-property 1: opted_in allows BOTH transactional and non-transactional ──

  test('opted_in allows both transactional and non-transactional messages (Req 2.5, 6.9)', () => {
    fc.assert(
      fc.property(messageCategoryArb, (category) => {
        const result = evaluateConsentGate('opted_in', category);
        expect(result.allowed).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 2: opted_out/pending SUPPRESS non-transactional messages ──

  test('opted_out suppresses non-transactional messages (Req 2.5, 13.5)', () => {
    fc.assert(
      fc.property(fc.constant('non_transactional' as MessageCategory), (category) => {
        const result = evaluateConsentGate('opted_out', category);
        expect(result.allowed).toBe(false);
        expect(result.reason).toBeDefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('pending suppresses non-transactional messages (Req 2.5, 13.5)', () => {
    fc.assert(
      fc.property(fc.constant('non_transactional' as MessageCategory), (category) => {
        const result = evaluateConsentGate('pending', category);
        expect(result.allowed).toBe(false);
        expect(result.reason).toBeDefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('non-opted-in states always block non-transactional messages (Req 2.5, 3.5, 13.5)', () => {
    fc.assert(
      fc.property(nonOptedInStateArb, (state) => {
        const result = evaluateConsentGate(state, 'non_transactional');
        expect(result.allowed).toBe(false);
        expect(result.reason).toBeDefined();
        expect(typeof result.reason).toBe('string');
        expect(result.reason!.length).toBeGreaterThan(0);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 3: opted_out/pending ALLOW transactional messages ──

  test('opted_out still allows transactional messages (Req 6.9)', () => {
    fc.assert(
      fc.property(fc.constant('transactional' as MessageCategory), (category) => {
        const result = evaluateConsentGate('opted_out', category);
        expect(result.allowed).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('pending still allows transactional messages (Req 6.9)', () => {
    fc.assert(
      fc.property(fc.constant('transactional' as MessageCategory), (category) => {
        const result = evaluateConsentGate('pending', category);
        expect(result.allowed).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('transactional messages are always allowed regardless of consent state (Req 6.9, 13.5)', () => {
    fc.assert(
      fc.property(consentStateArb, (state) => {
        const result = evaluateConsentGate(state, 'transactional');
        expect(result.allowed).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 4: Determinism — same inputs always produce same output ──

  test('evaluateConsentGate is deterministic: same (consentState, category) always yields the same result (Req 2.5)', () => {
    fc.assert(
      fc.property(consentStateArb, messageCategoryArb, (state, category) => {
        const result1 = evaluateConsentGate(state, category);
        const result2 = evaluateConsentGate(state, category);
        const result3 = evaluateConsentGate(state, category);

        // Same allowed value
        expect(result1.allowed).toBe(result2.allowed);
        expect(result2.allowed).toBe(result3.allowed);

        // Same reason (or both undefined)
        expect(result1.reason).toBe(result2.reason);
        expect(result2.reason).toBe(result3.reason);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Composite property: the consent gate is purely a function of its inputs ──

  test('the gate result is fully determined by (consentState, category) pair with no side effects', () => {
    fc.assert(
      fc.property(
        consentStateArb,
        messageCategoryArb,
        fc.integer({ min: 1, max: 10 }),
        (state, category, repeatCount) => {
          // Call multiple times with various repeat counts to confirm no state leaks
          const results = Array.from({ length: repeatCount }, () =>
            evaluateConsentGate(state, category),
          );

          // All results are identical — no hidden state, no side effects
          const first = results[0];
          for (const r of results) {
            expect(r.allowed).toBe(first.allowed);
            expect(r.reason).toBe(first.reason);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Complete coverage: all (state, category) combinations obey the rule ──

  test('for all (state, category) combinations: allowed iff transactional OR opted_in (Req 2.5, 6.9, 13.5)', () => {
    fc.assert(
      fc.property(consentStateArb, messageCategoryArb, (state, category) => {
        const result = evaluateConsentGate(state, category);

        const expectedAllowed =
          category === 'transactional' || state === 'opted_in';

        expect(result.allowed).toBe(expectedAllowed);

        // When blocked, a reason must be provided
        if (!result.allowed) {
          expect(result.reason).toBeDefined();
          expect(typeof result.reason).toBe('string');
          expect(result.reason!.length).toBeGreaterThan(0);
        }
      }),
      { numRuns: NUM_RUNS },
    );
  });
});
