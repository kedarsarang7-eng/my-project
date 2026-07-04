// ============================================================================
// Property-Based Test — Substitution Sanitization
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 16
//
// Validates: Requirements 13.6
//
// Property 16 (design.md): Substituted data is sanitized to literal text.
//
// For any Business_Event value substituted into a Message_Template, the
// rendered output contains no active template control characters or
// markup/executable content derived from that value — the value appears
// only as literal text.
//
// Verifies:
// 1. Substituted values containing control characters are neutralized
//    (rendered as literal text)
// 2. Substituted values containing HTML/XML markup are escaped/neutralized
// 3. Substituted values with WhatsApp formatting (*bold*, _italic_, ~strike~)
//    are escaped
// 4. The output text is safe to send as a WhatsApp message without injection risk
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import { render, sanitize, RenderResult } from '../../services/template-render.service';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/**
 * Generates strings containing C0/C1 control characters (excluding safe
 * whitespace \t, \n, \r which are preserved).
 */
const controlCharArb: fc.Arbitrary<string> = fc
  .array(
    fc.oneof(
      // C0 control chars (unsafe range: 0x00-0x08, 0x0B-0x0C, 0x0E-0x1F)
      fc.integer({ min: 0x00, max: 0x08 }).map((c) => String.fromCharCode(c)),
      fc.integer({ min: 0x0b, max: 0x0c }).map((c) => String.fromCharCode(c)),
      fc.integer({ min: 0x0e, max: 0x1f }).map((c) => String.fromCharCode(c)),
      // DEL
      fc.constant(String.fromCharCode(0x7f)),
      // C1 control chars (0x80-0x9F)
      fc.integer({ min: 0x80, max: 0x9f }).map((c) => String.fromCharCode(c)),
    ),
    { minLength: 1, maxLength: 10 },
  )
  .map((chars) => chars.join(''));

/**
 * Generates strings with control characters mixed with normal text.
 */
const textWithControlCharsArb: fc.Arbitrary<string> = fc
  .tuple(
    fc.string({ minLength: 1, maxLength: 20 }),
    controlCharArb,
    fc.string({ minLength: 0, maxLength: 20 }),
  )
  .map(([prefix, ctrl, suffix]) => `${prefix}${ctrl}${suffix}`);

/**
 * Generates HTML/XML markup strings that should be neutralized.
 */
const htmlMarkupArb: fc.Arbitrary<string> = fc.oneof(
  fc.string({ minLength: 1, maxLength: 20 }).map((tag) => `<${tag}>`),
  fc.string({ minLength: 1, maxLength: 20 }).map((tag) => `</${tag}>`),
  fc.constant('<script>alert("xss")</script>'),
  fc.constant('<img src=x onerror=alert(1)>'),
  fc.constant('<a href="javascript:void(0)">click</a>'),
  fc.constant('<!DOCTYPE html>'),
  fc.constant('<div class="inject">payload</div>'),
  fc.constant('&lt;already&gt;escaped&amp;'),
  fc.string({ minLength: 1, maxLength: 10 }).map((s) => `<b>${s}</b>`),
  fc.string({ minLength: 1, maxLength: 10 }).map((s) => `<i>${s}</i>`),
);

/**
 * Generates strings with HTML entities (ampersand-based).
 */
const htmlEntityArb: fc.Arbitrary<string> = fc.oneof(
  fc.constant('&amp;'),
  fc.constant('&lt;'),
  fc.constant('&gt;'),
  fc.constant('&quot;'),
  fc.constant('&#x27;'),
  fc.constant('&#60;'),
  fc.string({ minLength: 1, maxLength: 8 }).map((s) => `&${s};`),
);

/**
 * Generates strings containing WhatsApp formatting markers.
 */
const waFormattingArb: fc.Arbitrary<string> = fc.oneof(
  fc.string({ minLength: 1, maxLength: 15 }).map((s) => `*${s}*`),
  fc.string({ minLength: 1, maxLength: 15 }).map((s) => `_${s}_`),
  fc.string({ minLength: 1, maxLength: 15 }).map((s) => `~${s}~`),
  fc.string({ minLength: 1, maxLength: 15 }).map((s) => `\`\`\`${s}\`\`\``),
  fc.constant('*bold text*'),
  fc.constant('_italic text_'),
  fc.constant('~strikethrough~'),
  fc.constant('`monospace`'),
);

/**
 * Generates strings with bidirectional override characters used for spoofing.
 */
const bidiOverrideArb: fc.Arbitrary<string> = fc
  .array(
    fc.oneof(
      fc.constant('\u202A'), // LRE
      fc.constant('\u202B'), // RLE
      fc.constant('\u202C'), // PDF
      fc.constant('\u202D'), // LRO
      fc.constant('\u202E'), // RLO
      fc.constant('\u2066'), // LRI
      fc.constant('\u2067'), // RLI
      fc.constant('\u2068'), // FSI
      fc.constant('\u2069'), // PDI
      fc.constant('\u200E'), // LRM
      fc.constant('\u200F'), // RLM
    ),
    { minLength: 1, maxLength: 5 },
  )
  .map((chars) => chars.join(''));

/**
 * Generates strings with zero-width characters used for obfuscation.
 */
const zeroWidthArb: fc.Arbitrary<string> = fc
  .array(
    fc.oneof(
      fc.constant('\u200B'), // zero-width space
      fc.constant('\u200C'), // ZWNJ
      fc.constant('\u200D'), // ZWJ
      fc.constant('\uFEFF'), // BOM / zero-width no-break space
    ),
    { minLength: 1, maxLength: 5 },
  )
  .map((chars) => chars.join(''));

/**
 * Generates arbitrary strings (the full adversarial space) to substitute.
 */
const arbitraryValueArb: fc.Arbitrary<string> = fc.oneof(
  textWithControlCharsArb,
  htmlMarkupArb,
  htmlEntityArb,
  waFormattingArb,
  fc.tuple(bidiOverrideArb, fc.string({ minLength: 1, maxLength: 10 })).map(
    ([bidi, text]) => `${bidi}${text}${bidi}`,
  ),
  fc.tuple(zeroWidthArb, fc.string({ minLength: 1, maxLength: 10 })).map(
    ([zw, text]) => `${zw}${text}`,
  ),
  fc.string({ minLength: 1, maxLength: 50 }),
);

// ── Regex patterns for detecting dangerous content in output ─────────────────

/** Control characters that should have been stripped (excluding \t, \n, \r). */
const UNSAFE_CONTROL_REGEX = /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\x80-\x9F]/;

/** Raw HTML/XML angle brackets (< >) that should have been escaped. */
const RAW_ANGLE_BRACKETS_REGEX = /[<>]/;

/** Raw ampersand that should have been escaped. */
const RAW_AMPERSAND_REGEX = /&/;

/** Bidirectional override characters that should have been removed. */
const BIDI_REGEX = /[\u202A-\u202E\u2066-\u2069\u200E\u200F]/;

/** Zero-width characters that should have been removed (not counting our escape ZWNJ). */
const ZERO_WIDTH_SOURCE_REGEX = /[\u200B\u200D\uFEFF]/;

/**
 * Checks that a WhatsApp formatting marker is escaped (preceded by ZWNJ U+200C).
 * An unescaped formatting marker would trigger WhatsApp formatting.
 */
function hasUnescapedFormattingMarker(text: string): boolean {
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (ch === '*' || ch === '_' || ch === '~' || ch === '`') {
      // Check if preceded by ZWNJ (our escape character)
      if (i === 0 || text[i - 1] !== '\u200C') {
        return true;
      }
    }
  }
  return false;
}

// ── Helper: render with a single placeholder ─────────────────────────────────

function renderSinglePlaceholder(value: string): RenderResult {
  return render(
    { body: 'Message: {{data}}', placeholders: ['data'] },
    { data: value },
  );
}

// ── Property 16: Substituted data is sanitized to literal text ──────────────

describe('Feature: openwa-whatsapp-automation, Property 16: Substituted data is sanitized to literal text', () => {
  // ── Sub-property 1: Control characters are neutralized ────────────────────

  describe('Substituted values containing control characters are neutralized', () => {
    test('control characters in substituted values are stripped from render output (Req 13.6)', () => {
      fc.assert(
        fc.property(textWithControlCharsArb, (value) => {
          const result = renderSinglePlaceholder(value);
          expect(result.success).toBe(true);
          if (result.success) {
            // The substituted portion should have no unsafe control characters
            const substituted = result.text.replace('Message: ', '');
            expect(UNSAFE_CONTROL_REGEX.test(substituted)).toBe(false);
          }
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('sanitize function strips all C0/C1 control characters except safe whitespace (Req 13.6)', () => {
      fc.assert(
        fc.property(controlCharArb, (ctrlChars) => {
          const sanitized = sanitize(ctrlChars);
          expect(UNSAFE_CONTROL_REGEX.test(sanitized)).toBe(false);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('safe whitespace (tab, newline, CR) is preserved in sanitized output (Req 13.6)', () => {
      fc.assert(
        fc.property(
          fc.constantFrom('\t', '\n', '\r'),
          fc.string({ minLength: 1, maxLength: 20 }),
          (ws, text) => {
            const input = `${text}${ws}${text}`;
            const sanitized = sanitize(input);
            expect(sanitized).toContain(ws);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── Sub-property 2: HTML/XML markup is escaped/neutralized ────────────────

  describe('Substituted values containing HTML/XML markup are escaped/neutralized', () => {
    test('angle brackets in substituted values are neutralized in output (Req 13.6)', () => {
      fc.assert(
        fc.property(htmlMarkupArb, (markup) => {
          const result = renderSinglePlaceholder(markup);
          expect(result.success).toBe(true);
          if (result.success) {
            const substituted = result.text.replace('Message: ', '');
            // No raw < or > should appear — they should be fullwidth equivalents
            expect(RAW_ANGLE_BRACKETS_REGEX.test(substituted)).toBe(false);
          }
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('ampersands in substituted values are neutralized (Req 13.6)', () => {
      fc.assert(
        fc.property(htmlEntityArb, (entity) => {
          const result = renderSinglePlaceholder(entity);
          expect(result.success).toBe(true);
          if (result.success) {
            const substituted = result.text.replace('Message: ', '');
            // No raw & should appear — should be fullwidth equivalent
            expect(RAW_AMPERSAND_REGEX.test(substituted)).toBe(false);
          }
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('script injection attempts are completely neutralized (Req 13.6)', () => {
      fc.assert(
        fc.property(
          fc.string({ minLength: 1, maxLength: 30 }),
          (payload) => {
            const xss = `<script>${payload}</script>`;
            const result = renderSinglePlaceholder(xss);
            expect(result.success).toBe(true);
            if (result.success) {
              const substituted = result.text.replace('Message: ', '');
              expect(substituted).not.toContain('<script>');
              expect(substituted).not.toContain('</script>');
              expect(RAW_ANGLE_BRACKETS_REGEX.test(substituted)).toBe(false);
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── Sub-property 3: WhatsApp formatting markers are escaped ───────────────

  describe('Substituted values with WhatsApp formatting are escaped', () => {
    test('WhatsApp formatting markers in substituted values do not render as formatting (Req 13.6)', () => {
      fc.assert(
        fc.property(waFormattingArb, (formatted) => {
          const result = renderSinglePlaceholder(formatted);
          expect(result.success).toBe(true);
          if (result.success) {
            const substituted = result.text.replace('Message: ', '');
            // Every formatting marker (* _ ~ `) should be preceded by ZWNJ
            expect(hasUnescapedFormattingMarker(substituted)).toBe(false);
          }
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('bold markers (*) in values are prefixed with ZWNJ escape (Req 13.6)', () => {
      fc.assert(
        fc.property(
          fc.string({ minLength: 1, maxLength: 20 }),
          (content) => {
            const input = `*${content}*`;
            const sanitized = sanitize(input);
            // Every * should have ZWNJ before it
            for (let i = 0; i < sanitized.length; i++) {
              if (sanitized[i] === '*') {
                expect(i).toBeGreaterThan(0);
                expect(sanitized[i - 1]).toBe('\u200C');
              }
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('italic markers (_) in values are prefixed with ZWNJ escape (Req 13.6)', () => {
      fc.assert(
        fc.property(
          fc.string({ minLength: 1, maxLength: 20 }),
          (content) => {
            const input = `_${content}_`;
            const sanitized = sanitize(input);
            for (let i = 0; i < sanitized.length; i++) {
              if (sanitized[i] === '_') {
                expect(i).toBeGreaterThan(0);
                expect(sanitized[i - 1]).toBe('\u200C');
              }
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('strikethrough markers (~) in values are prefixed with ZWNJ escape (Req 13.6)', () => {
      fc.assert(
        fc.property(
          fc.string({ minLength: 1, maxLength: 20 }),
          (content) => {
            const input = `~${content}~`;
            const sanitized = sanitize(input);
            for (let i = 0; i < sanitized.length; i++) {
              if (sanitized[i] === '~') {
                expect(i).toBeGreaterThan(0);
                expect(sanitized[i - 1]).toBe('\u200C');
              }
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── Sub-property 4: Output is safe for WhatsApp (no injection risk) ───────

  describe('Output text is safe to send as a WhatsApp message without injection risk', () => {
    test('arbitrary adversarial values produce safe output with no injection vectors (Req 13.6)', () => {
      fc.assert(
        fc.property(arbitraryValueArb, (value) => {
          const result = renderSinglePlaceholder(value);
          expect(result.success).toBe(true);
          if (result.success) {
            const substituted = result.text.replace('Message: ', '');
            // No unsafe control characters
            expect(UNSAFE_CONTROL_REGEX.test(substituted)).toBe(false);
            // No raw angle brackets
            expect(RAW_ANGLE_BRACKETS_REGEX.test(substituted)).toBe(false);
            // No raw ampersands
            expect(RAW_AMPERSAND_REGEX.test(substituted)).toBe(false);
            // No bidirectional overrides
            expect(BIDI_REGEX.test(substituted)).toBe(false);
            // No source zero-width chars (ZWNJ U+200C is allowed as our escape)
            expect(ZERO_WIDTH_SOURCE_REGEX.test(substituted)).toBe(false);
            // All formatting markers are escaped
            expect(hasUnescapedFormattingMarker(substituted)).toBe(false);
          }
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('bidirectional override characters are removed from substituted values (Req 13.6)', () => {
      fc.assert(
        fc.property(
          fc.tuple(bidiOverrideArb, fc.string({ minLength: 1, maxLength: 20 })),
          ([bidi, text]) => {
            const input = `${bidi}${text}`;
            const result = renderSinglePlaceholder(input);
            expect(result.success).toBe(true);
            if (result.success) {
              const substituted = result.text.replace('Message: ', '');
              expect(BIDI_REGEX.test(substituted)).toBe(false);
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('zero-width obfuscation characters are removed from substituted values (Req 13.6)', () => {
      fc.assert(
        fc.property(
          fc.tuple(zeroWidthArb, fc.string({ minLength: 1, maxLength: 20 })),
          ([zw, text]) => {
            const input = `${text}${zw}${text}`;
            const result = renderSinglePlaceholder(input);
            expect(result.success).toBe(true);
            if (result.success) {
              const substituted = result.text.replace('Message: ', '');
              expect(ZERO_WIDTH_SOURCE_REGEX.test(substituted)).toBe(false);
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('combined attack vectors (control + markup + formatting + bidi) are all neutralized (Req 13.6)', () => {
      fc.assert(
        fc.property(
          fc.tuple(controlCharArb, htmlMarkupArb, waFormattingArb, bidiOverrideArb),
          ([ctrl, html, waFmt, bidi]) => {
            const combined = `${ctrl}${html}${waFmt}${bidi}`;
            const result = renderSinglePlaceholder(combined);
            expect(result.success).toBe(true);
            if (result.success) {
              const substituted = result.text.replace('Message: ', '');
              expect(UNSAFE_CONTROL_REGEX.test(substituted)).toBe(false);
              expect(RAW_ANGLE_BRACKETS_REGEX.test(substituted)).toBe(false);
              expect(RAW_AMPERSAND_REGEX.test(substituted)).toBe(false);
              expect(BIDI_REGEX.test(substituted)).toBe(false);
              expect(ZERO_WIDTH_SOURCE_REGEX.test(substituted)).toBe(false);
              expect(hasUnescapedFormattingMarker(substituted)).toBe(false);
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── Anchored example checks (unit) ─────────────────────────────────────────

  describe('Anchored examples', () => {
    test('example: script tag injection is neutralized', () => {
      const result = renderSinglePlaceholder('<script>alert("xss")</script>');
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.text).not.toContain('<script>');
        expect(result.text).not.toContain('<');
        expect(result.text).not.toContain('>');
      }
    });

    test('example: WhatsApp bold is escaped', () => {
      const result = renderSinglePlaceholder('*fake bold*');
      expect(result.success).toBe(true);
      if (result.success) {
        // Should contain ZWNJ before each *
        expect(result.text).toContain('\u200C*');
        expect(hasUnescapedFormattingMarker(result.text.replace('Message: ', ''))).toBe(false);
      }
    });

    test('example: null bytes are stripped', () => {
      const result = renderSinglePlaceholder('hello\x00world');
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.text).not.toContain('\x00');
      }
    });

    test('example: RLO text spoofing attempt is neutralized', () => {
      // RLO (U+202E) can be used to display text in reverse to trick users
      const result = renderSinglePlaceholder('\u202Emalicious\u202C');
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.text).not.toContain('\u202E');
        expect(result.text).not.toContain('\u202C');
      }
    });

    test('example: normal text passes through without modification', () => {
      const result = renderSinglePlaceholder('Hello John, your invoice is ready.');
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.text).toBe('Message: Hello John, your invoice is ready.');
      }
    });

    test('example: numbers and currency pass through correctly', () => {
      const result = renderSinglePlaceholder('₹1,500.00');
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.text).toContain('₹1,500.00');
      }
    });
  });
});
