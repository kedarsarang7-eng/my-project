// ============================================================================
// Property-Based Test — Eligibility Derivation
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 5
//
// Validates: Requirements 2.9, 2.10, 4.6, 6.8, 11.11
//
// Property 5 (design.md): Eligibility equals valid-number-and-opted-in.
//
// A customer is eligible for event-driven automations IFF their WhatsApp
// number is valid E.164 AND their consent state is opted_in.
// - Invalid number → not eligible (regardless of consent)
// - Non-opted-in consent → not eligible for non-transactional (regardless of number)
// - Missing/empty number → not eligible
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  isEligible,
  shouldSendMessage,
} from '../../services/consent.service';
import type { ConsentState, MessageCategory } from '../../schemas/entities';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates valid E.164 phone numbers: '+' followed by 8-15 digits. */
const validE164Arb: fc.Arbitrary<string> = fc
  .integer({ min: 10000000, max: 999999999999999 })
  .map((n) => `+${n}`);

/** Generates invalid phone numbers that will NOT pass E.164 validation. */
const invalidPhoneArb: fc.Arbitrary<string> = fc.oneof(
  // Missing leading '+'
  fc.integer({ min: 10000000, max: 999999999999999 }).map((n) => `${n}`),
  // Too short (fewer than 8 digits after +)
  fc.integer({ min: 1, max: 9999999 }).map((n) => `+${n}`),
  // Too long (more than 15 digits after +)
  fc.stringOf(fc.constantFrom('0', '1', '2', '3', '4', '5', '6', '7', '8', '9'), { minLength: 16, maxLength: 20 }).map((d) => `+${d}`),
  // Contains non-digit characters after +
  fc.tuple(
    fc.integer({ min: 1000, max: 9999 }),
    fc.constantFrom('-', ' ', '(', ')', '.', 'a', 'x'),
    fc.integer({ min: 1000, max: 9999 }),
  ).map(([a, sep, b]) => `+${a}${sep}${b}`),
  // Just a '+'
  fc.constant('+'),
);

/** Generates empty or whitespace-only strings (missing numbers). */
const emptyOrMissingPhoneArb: fc.Arbitrary<string> = fc.oneof(
  fc.constant(''),
  fc.constant('   '),
  fc.constant('\t'),
  fc.constant('\n'),
);

/** Generates consent states that are NOT 'opted_in'. */
const nonOptedInConsentArb: fc.Arbitrary<ConsentState> = fc.constantFrom(
  'opted_out' as ConsentState,
  'pending' as ConsentState,
);

/** All three legal consent states. */
const consentStateArb: fc.Arbitrary<ConsentState> = fc.constantFrom(
  'opted_in' as ConsentState,
  'opted_out' as ConsentState,
  'pending' as ConsentState,
);

/** Message category: transactional or non_transactional. */
const messageCategoryArb: fc.Arbitrary<MessageCategory> = fc.constantFrom(
  'transactional' as MessageCategory,
  'non_transactional' as MessageCategory,
);

// ── Property 5: Eligibility equals valid-number-and-opted-in ────────────────

describe('Feature: openwa-whatsapp-automation, Property 5: Eligibility equals valid-number-and-opted-in', () => {
  // ── Core property: eligible IFF valid E.164 AND opted_in ───────────────────

  test('isEligible returns true when number is valid E.164 AND consent is opted_in (Req 2.9)', () => {
    fc.assert(
      fc.property(validE164Arb, (phone) => {
        const profile = { whatsappNumber: phone, consentState: 'opted_in' as ConsentState };
        expect(isEligible(profile)).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('isEligible returns false when number is valid E.164 but consent is NOT opted_in (Req 2.10)', () => {
    fc.assert(
      fc.property(validE164Arb, nonOptedInConsentArb, (phone, consent) => {
        const profile = { whatsappNumber: phone, consentState: consent };
        expect(isEligible(profile)).toBe(false);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('isEligible returns false when number is invalid regardless of consent state (Req 2.10, 11.11)', () => {
    fc.assert(
      fc.property(invalidPhoneArb, consentStateArb, (phone, consent) => {
        const profile = { whatsappNumber: phone, consentState: consent };
        expect(isEligible(profile)).toBe(false);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('isEligible returns false when number is empty/missing regardless of consent state (Req 2.10)', () => {
    fc.assert(
      fc.property(emptyOrMissingPhoneArb, consentStateArb, (phone, consent) => {
        const profile = { whatsappNumber: phone, consentState: consent };
        expect(isEligible(profile)).toBe(false);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Biconditional property: eligible ↔ (valid E.164 ∧ opted_in) ────────────

  test('isEligible is true if and only if the number is valid E.164 AND consent is opted_in (Req 2.9, 2.10)', () => {
    fc.assert(
      fc.property(
        fc.oneof(validE164Arb, invalidPhoneArb, emptyOrMissingPhoneArb),
        consentStateArb,
        (phone, consent) => {
          const profile = { whatsappNumber: phone, consentState: consent };
          const result = isEligible(profile);

          // The E.164 regex used internally: /^\+\d{8,15}$/
          const isValidNumber = /^\+\d{8,15}$/.test(phone);
          const isOptedIn = consent === 'opted_in';

          // Eligibility holds iff both conditions are true
          expect(result).toBe(isValidNumber && isOptedIn);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── shouldSendMessage: invalid number blocks ALL messages ──────────────────

  test('shouldSendMessage blocks all messages (transactional and non-transactional) when number is invalid (Req 4.6, 6.8, 11.11)', () => {
    fc.assert(
      fc.property(invalidPhoneArb, consentStateArb, messageCategoryArb, (phone, consent, category) => {
        const profile = { whatsappNumber: phone, consentState: consent };
        const result = shouldSendMessage(profile, category);
        expect(result.allowed).toBe(false);
        expect(result.reason).toBeDefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('shouldSendMessage blocks all messages when number is empty/missing (Req 2.10, 11.11)', () => {
    fc.assert(
      fc.property(emptyOrMissingPhoneArb, consentStateArb, messageCategoryArb, (phone, consent, category) => {
        const profile = { whatsappNumber: phone, consentState: consent };
        const result = shouldSendMessage(profile, category);
        expect(result.allowed).toBe(false);
        expect(result.reason).toBeDefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── shouldSendMessage: non-opted-in blocks non-transactional ───────────────

  test('shouldSendMessage blocks non-transactional messages when consent is not opted_in (Req 2.10, 6.8)', () => {
    fc.assert(
      fc.property(validE164Arb, nonOptedInConsentArb, (phone, consent) => {
        const profile = { whatsappNumber: phone, consentState: consent };
        const result = shouldSendMessage(profile, 'non_transactional' as MessageCategory);
        expect(result.allowed).toBe(false);
        expect(result.reason).toBeDefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── shouldSendMessage: valid number + opted_in allows everything ───────────

  test('shouldSendMessage allows all message categories when number is valid AND consent is opted_in (Req 2.9)', () => {
    fc.assert(
      fc.property(validE164Arb, messageCategoryArb, (phone, category) => {
        const profile = { whatsappNumber: phone, consentState: 'opted_in' as ConsentState };
        const result = shouldSendMessage(profile, category);
        expect(result.allowed).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── shouldSendMessage: transactional allowed with valid number even without opt-in ──

  test('shouldSendMessage allows transactional messages with valid number even if consent is not opted_in (Req 2.5 transactional bypass)', () => {
    fc.assert(
      fc.property(validE164Arb, nonOptedInConsentArb, (phone, consent) => {
        const profile = { whatsappNumber: phone, consentState: consent };
        const result = shouldSendMessage(profile, 'transactional' as MessageCategory);
        expect(result.allowed).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });
});
