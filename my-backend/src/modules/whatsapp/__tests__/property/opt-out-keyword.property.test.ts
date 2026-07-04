// ============================================================================
// Property-Based Test — Opt-Out Keyword Detection
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 7
//
// Validates: Requirements 2.6
//
// Property 7 (design.md): Opt-out keyword detection is case-insensitive and
// whitespace-insensitive.
//
// Verifies:
// 1. Known keywords (stop, unsubscribe, cancel, opt out, optout, quit, end)
//    in ANY case → detected as opt-out
// 2. Leading/trailing whitespace doesn't affect detection
// 3. Non-keyword messages are NOT detected as opt-out
// 4. Random case variations of keywords still trigger opt-out
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  isOptOutKeyword,
  detectOptOutKeyword,
  OPT_OUT_KEYWORDS,
} from '../../services/consent.service';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** The canonical list of opt-out keywords. */
const KEYWORDS = ['stop', 'unsubscribe', 'cancel', 'opt out', 'optout', 'quit', 'end'];

/** Generates one of the recognized opt-out keywords in lowercase. */
const keywordArb: fc.Arbitrary<string> = fc.constantFrom(...KEYWORDS);

/**
 * Generates a random case variation of a string.
 * Each character is independently uppercased or lowercased.
 */
function randomCaseArb(base: fc.Arbitrary<string>): fc.Arbitrary<string> {
  return base.chain((s) =>
    fc
      .array(fc.boolean(), { minLength: s.length, maxLength: s.length })
      .map((flags) =>
        s
          .split('')
          .map((ch, i) => (flags[i] ? ch.toUpperCase() : ch.toLowerCase()))
          .join(''),
      ),
  );
}

/** Generates an opt-out keyword with random case. */
const randomCaseKeywordArb: fc.Arbitrary<string> = randomCaseArb(keywordArb);

/**
 * Generates whitespace strings (spaces, tabs, newlines) for
 * leading/trailing padding.
 */
const whitespaceArb: fc.Arbitrary<string> = fc.stringOf(
  fc.constantFrom(' ', '\t', '\n', '\r', ' '),
  { minLength: 0, maxLength: 10 },
);

/**
 * Generates an opt-out keyword with random case AND leading/trailing whitespace.
 * This tests both case-insensitivity and whitespace-trimming together.
 */
const paddedRandomCaseKeywordArb: fc.Arbitrary<string> = fc
  .tuple(whitespaceArb, randomCaseKeywordArb, whitespaceArb)
  .map(([leading, kw, trailing]) => `${leading}${kw}${trailing}`);

/**
 * Generates messages that are definitively NOT opt-out keywords.
 * Filters out anything that would trim+lowercase to a keyword.
 */
const nonKeywordMessageArb: fc.Arbitrary<string> = fc
  .string({ minLength: 1, maxLength: 100 })
  .filter((s) => {
    const normalized = s.trim().toLowerCase();
    return normalized.length > 0 && !KEYWORDS.includes(normalized);
  });

/**
 * Generates completely unrelated messages (sentences, random words).
 * These should never trigger opt-out detection.
 */
const unrelatedMessageArb: fc.Arbitrary<string> = fc.oneof(
  fc.constant('Hello, how are you?'),
  fc.constant('I need help with my order'),
  fc.constant('What is the price?'),
  fc.constant('stopping by later'),
  fc.constant('I cancelled my other subscription'),
  fc.constant('please send invoice'),
  fc.constant('thanks for the update'),
  // Random alphanumeric that won't accidentally match keywords
  fc
    .stringOf(fc.constantFrom('a', 'b', 'x', 'y', 'z', '1', '2', '3', '!', '?'), {
      minLength: 8,
      maxLength: 50,
    })
    .filter((s) => !KEYWORDS.includes(s.trim().toLowerCase())),
);

// ── Property 7: Opt-out keyword detection ───────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 7: Opt-out keyword detection is case-insensitive and whitespace-insensitive', () => {
  // ── Sub-property 1: Known keywords in ANY case → detected as opt-out ──────

  describe('Known keywords in any case are detected as opt-out', () => {
    test('any recognized keyword with random case variation is detected (Req 2.6)', () => {
      fc.assert(
        fc.property(randomCaseKeywordArb, (message) => {
          expect(isOptOutKeyword(message)).toBe(true);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('detectOptOutKeyword returns the matched keyword for any case variation (Req 2.6)', () => {
      fc.assert(
        fc.property(randomCaseKeywordArb, (message) => {
          const detected = detectOptOutKeyword(message);
          expect(detected).not.toBeNull();
          expect(KEYWORDS).toContain(detected);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('every keyword in the OPT_OUT_KEYWORDS constant is recognized (Req 2.6)', () => {
      fc.assert(
        fc.property(keywordArb, (keyword) => {
          expect(isOptOutKeyword(keyword)).toBe(true);
          expect(detectOptOutKeyword(keyword)).toBe(keyword);
          expect(OPT_OUT_KEYWORDS).toContain(keyword);
        }),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── Sub-property 2: Leading/trailing whitespace doesn't affect detection ──

  describe('Leading/trailing whitespace does not affect detection', () => {
    test('keywords padded with arbitrary whitespace are still detected (Req 2.6)', () => {
      fc.assert(
        fc.property(paddedRandomCaseKeywordArb, (message) => {
          expect(isOptOutKeyword(message)).toBe(true);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('detectOptOutKeyword returns the correct keyword despite whitespace padding (Req 2.6)', () => {
      fc.assert(
        fc.property(
          fc.tuple(whitespaceArb, keywordArb, whitespaceArb),
          ([leading, keyword, trailing]) => {
            const padded = `${leading}${keyword}${trailing}`;
            const detected = detectOptOutKeyword(padded);
            expect(detected).toBe(keyword);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('whitespace-only messages are NOT detected as opt-out (Req 2.6)', () => {
      fc.assert(
        fc.property(
          fc.stringOf(fc.constantFrom(' ', '\t', '\n', '\r'), { minLength: 1, maxLength: 20 }),
          (whitespaceOnly) => {
            expect(isOptOutKeyword(whitespaceOnly)).toBe(false);
            expect(detectOptOutKeyword(whitespaceOnly)).toBeNull();
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── Sub-property 3: Non-keyword messages are NOT detected as opt-out ──────

  describe('Non-keyword messages are not detected as opt-out', () => {
    test('arbitrary non-keyword strings are not detected (Req 2.6)', () => {
      fc.assert(
        fc.property(nonKeywordMessageArb, (message) => {
          expect(isOptOutKeyword(message)).toBe(false);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('detectOptOutKeyword returns null for non-keyword messages (Req 2.6)', () => {
      fc.assert(
        fc.property(nonKeywordMessageArb, (message) => {
          expect(detectOptOutKeyword(message)).toBeNull();
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('unrelated conversational messages are not detected (Req 2.6)', () => {
      fc.assert(
        fc.property(unrelatedMessageArb, (message) => {
          expect(isOptOutKeyword(message)).toBe(false);
          expect(detectOptOutKeyword(message)).toBeNull();
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('empty string is not detected as opt-out (Req 2.6)', () => {
      expect(isOptOutKeyword('')).toBe(false);
      expect(detectOptOutKeyword('')).toBeNull();
    });
  });

  // ── Sub-property 4: Random case variations of keywords still trigger ───────

  describe('Random case variations of keywords still trigger opt-out', () => {
    test('ALL CAPS keywords are detected (Req 2.6)', () => {
      fc.assert(
        fc.property(keywordArb, (keyword) => {
          expect(isOptOutKeyword(keyword.toUpperCase())).toBe(true);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('Mixed case keywords are detected (Req 2.6)', () => {
      fc.assert(
        fc.property(
          keywordArb.chain((kw) =>
            fc
              .array(fc.boolean(), { minLength: kw.length, maxLength: kw.length })
              .map((flags) =>
                kw
                  .split('')
                  .map((ch, i) => (flags[i] ? ch.toUpperCase() : ch.toLowerCase()))
                  .join(''),
              ),
          ),
          (mixedCaseKeyword) => {
            expect(isOptOutKeyword(mixedCaseKeyword)).toBe(true);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('case-insensitivity combined with whitespace for all keywords (Req 2.6)', () => {
      fc.assert(
        fc.property(
          fc.tuple(
            whitespaceArb,
            randomCaseKeywordArb,
            whitespaceArb,
          ),
          ([leading, keyword, trailing]) => {
            const input = `${leading}${keyword}${trailing}`;
            expect(isOptOutKeyword(input)).toBe(true);
            const detected = detectOptOutKeyword(input);
            expect(detected).not.toBeNull();
            expect(KEYWORDS).toContain(detected);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── Anchored example checks (unit) ─────────────────────────────────────────

  describe('Anchored examples', () => {
    test('example: all known keywords are detected in lowercase', () => {
      for (const kw of KEYWORDS) {
        expect(isOptOutKeyword(kw)).toBe(true);
        expect(detectOptOutKeyword(kw)).toBe(kw);
      }
    });

    test('example: keywords with varied case/whitespace', () => {
      expect(isOptOutKeyword('STOP')).toBe(true);
      expect(isOptOutKeyword('  Stop  ')).toBe(true);
      expect(isOptOutKeyword('\tUNSUBSCRIBE\n')).toBe(true);
      expect(isOptOutKeyword('OPT OUT')).toBe(true);
      expect(isOptOutKeyword(' Opt Out ')).toBe(true);
      expect(isOptOutKeyword('  OPTOUT  ')).toBe(true);
      expect(isOptOutKeyword('QuIt')).toBe(true);
      expect(isOptOutKeyword(' CaNcEl ')).toBe(true);
      expect(isOptOutKeyword('END')).toBe(true);
    });

    test('example: partial keyword matches do NOT trigger', () => {
      expect(isOptOutKeyword('stoppage')).toBe(false);
      expect(isOptOutKeyword('unsubscribed')).toBe(false);
      expect(isOptOutKeyword('cancellation')).toBe(false);
      expect(isOptOutKeyword('opt outing')).toBe(false);
      expect(isOptOutKeyword('quitter')).toBe(false);
      expect(isOptOutKeyword('ending')).toBe(false);
      expect(isOptOutKeyword('please stop')).toBe(false);
    });

    test('example: OPT_OUT_KEYWORDS matches the expected set', () => {
      expect([...OPT_OUT_KEYWORDS].sort()).toEqual(
        ['cancel', 'end', 'opt out', 'optout', 'quit', 'stop', 'unsubscribe'].sort(),
      );
    });
  });
});
