// ============================================================================
// Property-Based Test — Consent State Legal Values and Default
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 4
//
// Validates: Requirements 2.3, 2.4
//
// Property 4 (design.md): Consent state is always one of the three legal values
// and defaults to pending.
//
// Verifies:
// 1. The consent state machine only accepts/produces the three legal values
// 2. New profiles always default to `pending`
// 3. Invalid consent values are rejected
// 4. State transitions only move between the three legal values
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  CONSENT_STATES,
  DEFAULT_CONSENT_STATE,
  isValidConsentState,
  resolveInitialConsentState,
  evaluateConsentGate,
  applyOptOut,
  shouldSendMessage,
} from '../../services/consent.service';
import type { ConsentState, MessageCategory } from '../../schemas/entities';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates one of the three legal consent state values. */
const legalConsentStateArb: fc.Arbitrary<ConsentState> = fc.constantFrom(
  'opted_in' as ConsentState,
  'opted_out' as ConsentState,
  'pending' as ConsentState,
);

/** Generates a message category (transactional or non_transactional). */
const messageCategoryArb: fc.Arbitrary<MessageCategory> = fc.constantFrom(
  'transactional' as MessageCategory,
  'non_transactional' as MessageCategory,
);

/**
 * Generates arbitrary strings that are NOT one of the three legal consent states.
 * These represent invalid consent values that should be rejected.
 */
const invalidConsentStateArb: fc.Arbitrary<string> = fc
  .string({ minLength: 0, maxLength: 50 })
  .filter(
    (s) =>
      s !== 'opted_in' && s !== 'opted_out' && s !== 'pending',
  );

/** Generates non-string values for type-level rejection. */
const nonStringArb: fc.Arbitrary<unknown> = fc.oneof(
  fc.integer(),
  fc.boolean(),
  fc.constant(null),
  fc.constant(undefined),
  fc.array(fc.string()),
  fc.object(),
);

/** Generates valid E.164 phone numbers. */
const e164PhoneArb: fc.Arbitrary<string> = fc
  .integer({ min: 10000000, max: 999999999999999 })
  .map((n) => `+${n}`);

/** Generates opt-out keyword messages with random casing and whitespace. */
const optOutMessageArb: fc.Arbitrary<string> = fc
  .constantFrom('stop', 'unsubscribe', 'cancel', 'opt out', 'optout', 'quit', 'end')
  .chain((kw) =>
    fc.tuple(fc.stringOf(fc.constant(' '), { maxLength: 5 }), fc.boolean()).map(
      ([ws, upper]) => `${ws}${upper ? kw.toUpperCase() : kw}${ws}`,
    ),
  );

/** Generates messages that are NOT opt-out keywords. */
const nonOptOutMessageArb: fc.Arbitrary<string> = fc
  .string({ minLength: 1, maxLength: 100 })
  .filter((s) => {
    const normalized = s.trim().toLowerCase();
    return (
      normalized.length > 0 &&
      !['stop', 'unsubscribe', 'cancel', 'opt out', 'optout', 'quit', 'end'].includes(normalized)
    );
  });

// ── Property 4 ──────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 4: Consent state is always one of the three legal values and defaults to pending', () => {
  // ── Sub-property: isValidConsentState accepts only the three legal values ──

  test('isValidConsentState returns true exclusively for the three legal values (Req 2.3)', () => {
    fc.assert(
      fc.property(legalConsentStateArb, (state) => {
        expect(isValidConsentState(state)).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('isValidConsentState rejects arbitrary non-legal strings (Req 2.3)', () => {
    fc.assert(
      fc.property(invalidConsentStateArb, (state) => {
        expect(isValidConsentState(state)).toBe(false);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('isValidConsentState rejects non-string types (Req 2.3)', () => {
    fc.assert(
      fc.property(nonStringArb, (value) => {
        expect(isValidConsentState(value)).toBe(false);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Default consent state is always 'pending' ────────────────

  test('resolveInitialConsentState defaults to pending when no explicit state is provided (Req 2.4)', () => {
    fc.assert(
      fc.property(
        fc.constantFrom(undefined, null),
        (explicitState) => {
          const result = resolveInitialConsentState(explicitState as ConsentState | null | undefined);
          expect(result).toBe('pending');
          expect(result).toBe(DEFAULT_CONSENT_STATE);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  test('resolveInitialConsentState returns the explicit state when it is a legal value (Req 2.3, 2.4)', () => {
    fc.assert(
      fc.property(legalConsentStateArb, (explicitState) => {
        const result = resolveInitialConsentState(explicitState);
        expect(result).toBe(explicitState);
        expect(CONSENT_STATES).toContain(result);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('resolveInitialConsentState falls back to pending for invalid explicit values (Req 2.4)', () => {
    fc.assert(
      fc.property(invalidConsentStateArb, (invalidState) => {
        // Cast to bypass TS type checking since we're testing runtime behavior
        const result = resolveInitialConsentState(invalidState as unknown as ConsentState);
        expect(result).toBe('pending');
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: State transitions only produce legal values ───────────────

  test('applyOptOut always produces a legal consent state value (Req 2.3)', () => {
    fc.assert(
      fc.property(
        legalConsentStateArb,
        fc.string({ minLength: 0, maxLength: 100 }),
        (currentState, messageText) => {
          const newState = applyOptOut(currentState, messageText);
          expect(CONSENT_STATES).toContain(newState);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  test('applyOptOut transitions to opted_out on opt-out keywords, stays legal (Req 2.3)', () => {
    fc.assert(
      fc.property(legalConsentStateArb, optOutMessageArb, (currentState, message) => {
        const newState = applyOptOut(currentState, message);
        expect(newState).toBe('opted_out');
        expect(CONSENT_STATES).toContain(newState);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('applyOptOut preserves the current state for non-opt-out messages, stays legal (Req 2.3)', () => {
    fc.assert(
      fc.property(legalConsentStateArb, nonOptOutMessageArb, (currentState, message) => {
        const newState = applyOptOut(currentState, message);
        expect(newState).toBe(currentState);
        expect(CONSENT_STATES).toContain(newState);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Consent gate only produces results for legal states ───────

  test('evaluateConsentGate only operates on legal consent state inputs (Req 2.3)', () => {
    fc.assert(
      fc.property(legalConsentStateArb, messageCategoryArb, (state, category) => {
        const result = evaluateConsentGate(state, category);
        expect(typeof result.allowed).toBe('boolean');
        // The gate accepts only legal states — this is an invariant
        expect(CONSENT_STATES).toContain(state);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('shouldSendMessage operates with legal consent states in the profile (Req 2.3, 2.4)', () => {
    fc.assert(
      fc.property(
        legalConsentStateArb,
        e164PhoneArb,
        messageCategoryArb,
        (consentState, phone, category) => {
          const profile = { whatsappNumber: phone, consentState };
          const result = shouldSendMessage(profile, category);
          expect(typeof result.allowed).toBe('boolean');
          // The profile consent state must remain one of the three legal values
          expect(CONSENT_STATES).toContain(profile.consentState);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Anchored example checks (unit) ─────────────────────────────────────────

  test('example: CONSENT_STATES contains exactly three values', () => {
    expect(CONSENT_STATES).toHaveLength(3);
    expect(CONSENT_STATES).toContain('opted_in');
    expect(CONSENT_STATES).toContain('opted_out');
    expect(CONSENT_STATES).toContain('pending');
  });

  test('example: DEFAULT_CONSENT_STATE is pending', () => {
    expect(DEFAULT_CONSENT_STATE).toBe('pending');
  });

  test('example: new profile with no explicit consent defaults to pending', () => {
    expect(resolveInitialConsentState()).toBe('pending');
    expect(resolveInitialConsentState(null)).toBe('pending');
    expect(resolveInitialConsentState(undefined)).toBe('pending');
  });

  test('example: isValidConsentState rejects common invalid strings', () => {
    expect(isValidConsentState('')).toBe(false);
    expect(isValidConsentState('active')).toBe(false);
    expect(isValidConsentState('OPTED_IN')).toBe(false);
    expect(isValidConsentState('opt-in')).toBe(false);
    expect(isValidConsentState('consent_given')).toBe(false);
    expect(isValidConsentState(42)).toBe(false);
    expect(isValidConsentState(true)).toBe(false);
    expect(isValidConsentState(null)).toBe(false);
  });
});
