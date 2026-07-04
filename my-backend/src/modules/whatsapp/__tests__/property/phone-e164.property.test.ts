// ============================================================================
// Property Test: E.164 Persistence Rule (Task 5.2, Property 3)
// ============================================================================
// WhatsApp number is persisted if and only if it is valid E.164.
//
// **Validates: Requirements 2.1, 2.2**
//
// Tag: Feature: openwa-whatsapp-automation, Property 3
// ============================================================================

import * as fc from 'fast-check';
import { validateE164, isValidE164 } from '../../services/phone.service';

// ────────────────────────────────────────────────────────────────────────────
// Generators
// ────────────────────────────────────────────────────────────────────────────

/** Generate a valid E.164 number: "+" followed by 8–15 digits. */
const validE164Arb = fc
  .integer({ min: 8, max: 15 })
  .chain((len) =>
    fc.stringOf(fc.constantFrom('0', '1', '2', '3', '4', '5', '6', '7', '8', '9'), {
      minLength: len,
      maxLength: len,
    })
  )
  .map((digits) => `+${digits}`);

/** Generate a valid E.164 with optional leading/trailing whitespace (should still pass after trim). */
const validE164WithWhitespaceArb = fc
  .tuple(
    fc.stringOf(fc.constant(' '), { minLength: 0, maxLength: 3 }),
    validE164Arb,
    fc.stringOf(fc.constant(' '), { minLength: 0, maxLength: 3 })
  )
  .map(([leading, number, trailing]) => `${leading}${number}${trailing}`);

/** Generate strings missing the leading "+". */
const missingPlusArb = fc
  .integer({ min: 8, max: 15 })
  .chain((len) =>
    fc.stringOf(fc.constantFrom('0', '1', '2', '3', '4', '5', '6', '7', '8', '9'), {
      minLength: len,
      maxLength: len,
    })
  );

/** Generate "+" followed by too few digits (1–7). */
const tooShortArb = fc
  .integer({ min: 1, max: 7 })
  .chain((len) =>
    fc.stringOf(fc.constantFrom('0', '1', '2', '3', '4', '5', '6', '7', '8', '9'), {
      minLength: len,
      maxLength: len,
    })
  )
  .map((digits) => `+${digits}`);

/** Generate "+" followed by too many digits (16–25). */
const tooLongArb = fc
  .integer({ min: 16, max: 25 })
  .chain((len) =>
    fc.stringOf(fc.constantFrom('0', '1', '2', '3', '4', '5', '6', '7', '8', '9'), {
      minLength: len,
      maxLength: len,
    })
  )
  .map((digits) => `+${digits}`);

/** Generate "+" followed by digits mixed with non-digit characters (letters, symbols). */
const containsLettersArb = fc
  .tuple(
    fc.integer({ min: 1, max: 10 }),
    fc.integer({ min: 1, max: 5 })
  )
  .chain(([digitCount, letterCount]) =>
    fc.tuple(
      fc.stringOf(fc.constantFrom('0', '1', '2', '3', '4', '5', '6', '7', '8', '9'), {
        minLength: digitCount,
        maxLength: digitCount,
      }),
      fc.stringOf(fc.constantFrom('a', 'b', 'c', 'x', 'y', 'z', 'A', 'B', 'Z'), {
        minLength: letterCount,
        maxLength: letterCount,
      })
    )
  )
  .map(([digits, letters]) => `+${digits}${letters}`);

/** Generate strings with formatting characters (spaces, dashes, parens) mixed in. */
const formattedNumberArb = fc
  .tuple(
    fc.constantFrom('+1', '+44', '+91', '+880'),
    fc.array(
      fc.tuple(
        fc.stringOf(fc.constantFrom('0', '1', '2', '3', '4', '5', '6', '7', '8', '9'), {
          minLength: 1,
          maxLength: 4,
        }),
        fc.constantFrom(' ', '-', '(', ')', '.')
      ),
      { minLength: 2, maxLength: 4 }
    )
  )
  .map(([prefix, parts]) => prefix + parts.map(([d, sep]) => sep + d).join(''));

/** Aggregate of all invalid patterns. */
const invalidE164Arb = fc.oneof(
  missingPlusArb,
  tooShortArb,
  tooLongArb,
  containsLettersArb,
  formattedNumberArb
);

// ────────────────────────────────────────────────────────────────────────────
// Property Tests
// ────────────────────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 3', () => {
  describe('Property 3: WhatsApp number is persisted if and only if it is valid E.164', () => {
    /**
     * **Validates: Requirements 2.1**
     *
     * Numbers matching ^\+\d{8,15}$ always pass validation.
     * A valid E.164 number would be persisted (the function returns valid: true).
     */
    it('valid E.164 numbers always pass validation (would be persisted)', () => {
      fc.assert(
        fc.property(validE164WithWhitespaceArb, (number) => {
          const result = validateE164(number);
          expect(result.valid).toBe(true);
          expect(result.normalized).toBeDefined();
          expect(result.error).toBeUndefined();
          // The normalized number must match the E.164 regex
          expect(result.normalized).toMatch(/^\+\d{8,15}$/);
        }),
        { numRuns: 100 }
      );
    });

    /**
     * **Validates: Requirements 2.2**
     *
     * Numbers NOT matching the E.164 pattern always fail validation.
     * An invalid number would NOT be persisted (the function returns valid: false).
     */
    it('invalid numbers always fail validation (would not be persisted)', () => {
      fc.assert(
        fc.property(invalidE164Arb, (number) => {
          const result = validateE164(number);
          expect(result.valid).toBe(false);
          expect(result.normalized).toBeUndefined();
          expect(result.error).toBeDefined();
        }),
        { numRuns: 100 }
      );
    });

    /**
     * **Validates: Requirements 2.1, 2.2**
     *
     * The validation function is the sole gatekeeper for persistence:
     * - If validateE164 returns valid: true, the number would be persisted
     * - If validateE164 returns valid: false, the number would NOT be persisted
     * - isValidE164 agrees with validateE164 in all cases
     */
    it('isValidE164 agrees with validateE164 for all inputs (sole gatekeeper)', () => {
      fc.assert(
        fc.property(fc.oneof(validE164Arb, invalidE164Arb, fc.string()), (number) => {
          const detailed = validateE164(number);
          const quick = isValidE164(number);
          expect(quick).toBe(detailed.valid);
        }),
        { numRuns: 100 }
      );
    });

    /**
     * **Validates: Requirements 2.1**
     *
     * Normalization preserves the original digits — trimming whitespace is the only
     * transformation applied. The normalized output must exactly match the E.164 regex.
     */
    it('normalized output matches the E.164 regex for all valid inputs', () => {
      fc.assert(
        fc.property(validE164Arb, (number) => {
          const result = validateE164(number);
          expect(result.valid).toBe(true);
          // The normalized value is the trimmed input
          expect(result.normalized).toBe(number.trim());
          // And it matches the regex
          expect(/^\+\d{8,15}$/.test(result.normalized!)).toBe(true);
        }),
        { numRuns: 100 }
      );
    });
  });
});
