// ============================================================================
// Property-Based Test — Template Render Completeness / Fail-Closed
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 15
//
// Validates: Requirements 7.2, 7.3, 7.4, 7.8
//
// Property 15 (design.md): Rendering resolves every placeholder or fails closed.
//
// Verifies:
// 1. When all placeholders have matching payload values, the output contains
//    no unresolved placeholder tokens (Req 7.3)
// 2. When any placeholder lacks a value in the payload, the render fails closed
//    — returns error, no outbound message (Req 7.4, 7.8)
// 3. Body length 1..4096 and placeholders 0..50 are respected (Req 7.2)
// 4. The render is deterministic: same (template, payload) → same output
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  render,
  type TemplateInput,
  type RenderPayload,
  type RenderSuccess,
  type RenderFailure,
} from '../../services/template-render.service';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/**
 * Reserved JS prototype property names that could interfere with object traversal.
 */
const RESERVED_NAMES = new Set([
  '__proto__', 'constructor', 'prototype', 'toString', 'valueOf',
  'hasOwnProperty', 'isPrototypeOf', 'propertyIsEnumerable',
  'toLocaleString', '__defineGetter__', '__defineSetter__',
  '__lookupGetter__', '__lookupSetter__',
]);

/**
 * Generates a valid placeholder name: alphanumeric and underscores only (no dots).
 * Dots are handled separately for nested paths.
 * Excludes JS reserved prototype names that break object traversal.
 */
const simplePlaceholderNameArb: fc.Arbitrary<string> = fc
  .stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789_'.split('')), {
    minLength: 1,
    maxLength: 15,
  })
  .filter((s) => s.length >= 1 && !RESERVED_NAMES.has(s) && !/^[0-9]/.test(s));

/**
 * Generates a set of unique placeholder names (0..50).
 * Uses only simple (non-dotted) names to avoid payload conflicts where
 * a flat key "a" and a nested path "a.x" would require "a" to be both
 * a string and an object simultaneously.
 */
const placeholderSetArb = (min = 0, max = 10): fc.Arbitrary<string[]> =>
  fc
    .uniqueArray(simplePlaceholderNameArb, { minLength: min, maxLength: max })
    .filter((arr) => arr.length >= min);

/**
 * Generates a safe substitution value (string, no nested objects).
 * Avoids generating {{ }} patterns that could look like placeholders.
 */
const safeValueArb: fc.Arbitrary<string> = fc
  .string({ minLength: 0, maxLength: 50 })
  .filter((s) => !s.includes('{{') && !s.includes('}}'));

/**
 * Generates a template body containing the given placeholders embedded within text.
 * Ensures the body is 1..4096 characters.
 */
function templateBodyArb(placeholders: string[]): fc.Arbitrary<string> {
  if (placeholders.length === 0) {
    // Body with no placeholders — just literal text
    return fc.string({ minLength: 1, maxLength: 200 }).filter(
      (s) => s.trim().length > 0 && !s.includes('{{') && !s.includes('}}'),
    );
  }

  // Build body by interleaving text segments with placeholder tokens
  return fc
    .array(
      fc.string({ minLength: 0, maxLength: 30 }).map((s) => s.replace(/\{\{/g, '').replace(/\}\}/g, '')),
      { minLength: placeholders.length + 1, maxLength: placeholders.length + 1 },
    )
    .map((segments) => {
      let body = segments[0] || 'Hello ';
      for (let i = 0; i < placeholders.length; i++) {
        body += `{{${placeholders[i]}}}`;
        body += segments[i + 1] || ' ';
      }
      // Ensure body length is within 1..4096
      if (body.length > 4096) {
        body = body.slice(0, 4096);
      }
      if (body.length < 1) {
        body = 'X';
      }
      return body;
    });
}

/**
 * Generates a full payload that provides values for ALL given placeholders.
 * Since all placeholder names are simple (non-dotted), each maps to a flat key.
 */
function fullPayloadArb(placeholders: string[]): fc.Arbitrary<RenderPayload> {
  if (placeholders.length === 0) {
    return fc.constant({});
  }
  return fc
    .tuple(...placeholders.map(() => safeValueArb))
    .map((values) => {
      const payload: Record<string, unknown> = {};
      for (let i = 0; i < placeholders.length; i++) {
        payload[placeholders[i]] = values[i];
      }
      return payload as RenderPayload;
    });
}

/**
 * Generates a partial payload that is MISSING at least one placeholder value.
 */
function partialPayloadArb(placeholders: string[]): fc.Arbitrary<{ payload: RenderPayload; missing: string[] }> {
  if (placeholders.length === 0) {
    // Can't have missing placeholders if there are none
    return fc.constant({ payload: {}, missing: [] });
  }

  // Pick at least 1 placeholder to omit
  return fc
    .subarray(placeholders, { minLength: 1, maxLength: placeholders.length })
    .chain((omitted) => {
      const included = placeholders.filter((p) => !omitted.includes(p));
      return fullPayloadArb(included).map((payload) => ({
        payload,
        missing: omitted,
      }));
    });
}

/**
 * Generates a complete test case: template + full payload (all resolved).
 */
const fullResolvedCaseArb: fc.Arbitrary<{ template: TemplateInput; payload: RenderPayload }> =
  placeholderSetArb(1, 10).chain((placeholders) =>
    fc.tuple(templateBodyArb(placeholders), fullPayloadArb(placeholders)).map(([body, payload]) => ({
      template: { body, placeholders },
      payload,
    })),
  );

/**
 * Generates a test case with missing placeholders (should fail closed).
 */
const missingPlaceholderCaseArb: fc.Arbitrary<{
  template: TemplateInput;
  payload: RenderPayload;
  missing: string[];
}> = placeholderSetArb(1, 10).chain((placeholders) =>
  fc
    .tuple(templateBodyArb(placeholders), partialPayloadArb(placeholders))
    .map(([body, { payload, missing }]) => ({
      template: { body, placeholders },
      payload,
      missing,
    })),
);

// ── Placeholder token detection regex (mirrors the service) ─────────────────

const PLACEHOLDER_TOKEN_REGEX = /\{\{[a-zA-Z0-9_./-]+\}\}/g;

// ── Property 15: Rendering resolves every placeholder or fails closed ───────

describe('Feature: openwa-whatsapp-automation, Property 15: Rendering resolves every placeholder or fails closed', () => {
  // ── Sub-property 1: All placeholders resolved → no unresolved tokens ──────

  describe('When all placeholders have matching payload values, the output contains no unresolved placeholder tokens', () => {
    /**
     * **Validates: Requirements 7.2, 7.3**
     */
    test('fully-resolved payload produces output with zero unresolved placeholder tokens', () => {
      fc.assert(
        fc.property(fullResolvedCaseArb, ({ template, payload }) => {
          const result = render(template, payload);

          // Must succeed
          expect(result.success).toBe(true);

          // Output must contain no unresolved placeholder tokens
          const output = (result as RenderSuccess).text;
          const unresolvedTokens = output.match(PLACEHOLDER_TOKEN_REGEX);
          expect(unresolvedTokens).toBeNull();
        }),
        { numRuns: NUM_RUNS },
      );
    });

    /**
     * **Validates: Requirements 7.3**
     */
    test('each placeholder is replaced with its corresponding payload value (sanitized)', () => {
      fc.assert(
        fc.property(fullResolvedCaseArb, ({ template, payload }) => {
          const result = render(template, payload);
          expect(result.success).toBe(true);

          const output = (result as RenderSuccess).text;
          // The output must not contain the raw {{placeholder}} pattern
          for (const ph of template.placeholders) {
            expect(output).not.toContain(`{{${ph}}}`);
          }
        }),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── Sub-property 2: Missing placeholder → fail closed ─────────────────────

  describe('When any placeholder lacks a value in the payload, render fails closed', () => {
    /**
     * **Validates: Requirements 7.4, 7.8**
     */
    test('missing payload values produce a failure result with no rendered text', () => {
      fc.assert(
        fc.property(missingPlaceholderCaseArb, ({ template, payload, missing }) => {
          const result = render(template, payload);

          // Must fail
          expect(result.success).toBe(false);

          // Failure result has error and missing placeholders
          const failure = result as RenderFailure;
          expect(failure.error).toBeDefined();
          expect(failure.error.length).toBeGreaterThan(0);
          expect(failure.missingPlaceholders).toBeDefined();
          expect(failure.missingPlaceholders.length).toBeGreaterThan(0);

          // The missing placeholders must include at least one we omitted
          const missingSet = new Set(failure.missingPlaceholders);
          const atLeastOneOmittedIsReported = missing.some((m) => missingSet.has(m));
          expect(atLeastOneOmittedIsReported).toBe(true);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    /**
     * **Validates: Requirements 7.4**
     */
    test('failure result does not contain a text property (no partial render)', () => {
      fc.assert(
        fc.property(missingPlaceholderCaseArb, ({ template, payload }) => {
          const result = render(template, payload);

          expect(result.success).toBe(false);
          // A failed result must not expose any rendered text
          expect('text' in result).toBe(false);
        }),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── Sub-property 3: Body length 1..4096 and placeholders 0..50 ────────────

  describe('Body length 1..4096 and placeholders 0..50 are respected', () => {
    /**
     * **Validates: Requirements 7.2**
     */
    test('templates with 0 placeholders and body 1..4096 render successfully', () => {
      const noPlaceholderBodyArb = fc
        .string({ minLength: 1, maxLength: 200 })
        .filter((s) => s.trim().length > 0 && !s.includes('{{') && !s.includes('}}'));

      fc.assert(
        fc.property(noPlaceholderBodyArb, (body) => {
          const template: TemplateInput = { body, placeholders: [] };
          const result = render(template, {});

          expect(result.success).toBe(true);
          expect((result as RenderSuccess).text).toBe(body);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    /**
     * **Validates: Requirements 7.2**
     */
    test('templates with up to 50 placeholders render when payload is complete', () => {
      const manyPlaceholdersArb = placeholderSetArb(10, 50).chain((placeholders) =>
        fc.tuple(templateBodyArb(placeholders), fullPayloadArb(placeholders)).map(([body, payload]) => ({
          template: { body, placeholders } as TemplateInput,
          payload,
          count: placeholders.length,
        })),
      );

      fc.assert(
        fc.property(manyPlaceholdersArb, ({ template, payload, count }) => {
          expect(count).toBeGreaterThanOrEqual(10);
          expect(count).toBeLessThanOrEqual(50);
          expect(template.body.length).toBeGreaterThanOrEqual(1);
          expect(template.body.length).toBeLessThanOrEqual(4096);

          const result = render(template, payload);
          expect(result.success).toBe(true);

          const output = (result as RenderSuccess).text;
          const unresolvedTokens = output.match(PLACEHOLDER_TOKEN_REGEX);
          expect(unresolvedTokens).toBeNull();
        }),
        { numRuns: NUM_RUNS },
      );
    });

    /**
     * **Validates: Requirements 7.2**
     */
    test('body at maximum length (4096 chars) still renders correctly', () => {
      // Create a body that's exactly 4096 chars with one placeholder
      const placeholder = 'name';
      const token = `{{${placeholder}}}`;
      const padding = 'A'.repeat(4096 - token.length);
      const body = `${padding}${token}`;

      expect(body.length).toBe(4096);

      const template: TemplateInput = { body, placeholders: [placeholder] };
      const payload: RenderPayload = { name: 'Test' };
      const result = render(template, payload);

      expect(result.success).toBe(true);
      expect((result as RenderSuccess).text).not.toContain(`{{${placeholder}}}`);
    });
  });

  // ── Sub-property 4: Determinism ───────────────────────────────────────────

  describe('Render is deterministic: same (template, payload) → same output', () => {
    /**
     * **Validates: Requirements 7.3**
     */
    test('calling render twice with identical inputs produces identical outputs', () => {
      fc.assert(
        fc.property(fullResolvedCaseArb, ({ template, payload }) => {
          const result1 = render(template, payload);
          const result2 = render(template, payload);

          // Both must be equal
          expect(result1).toEqual(result2);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    /**
     * **Validates: Requirements 7.4**
     */
    test('calling render twice with missing values produces identical failure', () => {
      fc.assert(
        fc.property(missingPlaceholderCaseArb, ({ template, payload }) => {
          const result1 = render(template, payload);
          const result2 = render(template, payload);

          expect(result1).toEqual(result2);
          expect(result1.success).toBe(false);
          expect(result2.success).toBe(false);
        }),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── Anchored examples ─────────────────────────────────────────────────────

  describe('Anchored examples', () => {
    test('example: simple template with all values resolved', () => {
      const template: TemplateInput = {
        body: 'Hello {{name}}, your invoice #{{invoice_id}} is ready.',
        placeholders: ['name', 'invoice_id'],
      };
      const payload: RenderPayload = { name: 'Ravi', invoice_id: 'INV-001' };
      const result = render(template, payload);

      expect(result.success).toBe(true);
      const output = (result as RenderSuccess).text;
      expect(output).not.toContain('{{');
      expect(output).not.toContain('}}');
    });

    test('example: missing placeholder causes fail-closed', () => {
      const template: TemplateInput = {
        body: 'Hello {{name}}, your balance is {{amount}}',
        placeholders: ['name', 'amount'],
      };
      const payload: RenderPayload = { name: 'Ravi' }; // amount missing
      const result = render(template, payload);

      expect(result.success).toBe(false);
      const failure = result as RenderFailure;
      expect(failure.missingPlaceholders).toContain('amount');
    });

    test('example: zero-placeholder template renders as-is', () => {
      const template: TemplateInput = {
        body: 'Thank you for your purchase!',
        placeholders: [],
      };
      const result = render(template, {});

      expect(result.success).toBe(true);
      expect((result as RenderSuccess).text).toBe('Thank you for your purchase!');
    });

    test('example: declared placeholder not in body still requires payload value', () => {
      const template: TemplateInput = {
        body: 'Hello there!',
        placeholders: ['name'], // declared but not in body
      };
      const payload: RenderPayload = {}; // name missing from payload
      const result = render(template, payload);

      expect(result.success).toBe(false);
      expect((result as RenderFailure).missingPlaceholders).toContain('name');
    });

    test('example: nested dotted placeholder resolves from nested payload', () => {
      const template: TemplateInput = {
        body: 'Hi {{customer.name}}, order {{order.id}} confirmed.',
        placeholders: ['customer.name', 'order.id'],
      };
      const payload: RenderPayload = {
        customer: { name: 'Priya' },
        order: { id: 'ORD-500' },
      };
      const result = render(template, payload);

      expect(result.success).toBe(true);
      const output = (result as RenderSuccess).text;
      expect(output).not.toContain('{{');
    });
  });
});
