// ============================================================================
// Property-Based Test — Template Selection Fallback
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 14
//
// Validates: Requirements 4.5, 6.7
//
// Property 14 (design.md): Template selection prefers BusinessType+locale
// then falls back to default locale.
//
// Selection logic:
// 1. Exact match: active template with matching BusinessType AND locale → selected
// 2. Fallback: active template with matching BusinessType AND default locale → used
// 3. No match: returns null (fail-closed, no message sent)
//
// Additional invariants:
// - Only active templates are considered
// - Locale-specific match takes priority over default-locale match
// - Never returns a template for a different BusinessType
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  selectTemplate,
  DEFAULT_LOCALE,
  type TemplateSelectionCriteria,
} from '../../services/template-selection.service';
import type { MessageTemplate } from '../../schemas/entities';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates short, unique business type identifiers. */
const businessTypeArb: fc.Arbitrary<string> = fc.stringOf(
  fc.constantFrom('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'),
  { minLength: 3, maxLength: 12 },
);

/** Generates locale codes (2-5 chars, lowercase alpha). */
const localeArb: fc.Arbitrary<string> = fc.stringOf(
  fc.constantFrom('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'),
  { minLength: 2, maxLength: 5 },
);

/** Generates a locale guaranteed to differ from both the requested and default locales. */
function otherLocaleArb(exclude: string[]): fc.Arbitrary<string> {
  return localeArb.filter((l) => !exclude.includes(l));
}

/** Template status values. */
const statusArb: fc.Arbitrary<'active' | 'inactive'> = fc.constantFrom('active', 'inactive');

/** Builds a minimal template record for selection testing. */
function makeTemplate(
  businessType: string,
  locale: string,
  status: 'active' | 'inactive' = 'active',
): Pick<MessageTemplate, 'businessType' | 'locale' | 'status'> {
  return { businessType, locale, status };
}

// ── Property 14: Template selection prefers BusinessType+locale then falls back to default locale ──

describe('Feature: openwa-whatsapp-automation, Property 14: Template selection prefers BusinessType+locale then falls back to default locale', () => {
  /**
   * **Validates: Requirements 4.5, 6.7**
   */

  // ── Sub-property 1: Exact match selected when both BusinessType AND locale match ──

  test('selects the template matching both BusinessType AND locale when it exists', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        localeArb,
        // Generate additional "noise" templates that should NOT be selected
        fc.array(
          fc.tuple(businessTypeArb, localeArb, statusArb),
          { minLength: 0, maxLength: 5 },
        ),
        (businessType, locale, noise) => {
          // Ensure the locale differs from DEFAULT_LOCALE so fallback is testable
          // (if locale === DEFAULT_LOCALE, the test still holds — exact match is found first)

          // Build the exact-match template
          const exactMatch = makeTemplate(businessType, locale, 'active');

          // Also add a default-locale template for the same BusinessType
          const defaultFallback = makeTemplate(businessType, DEFAULT_LOCALE, 'active');

          // Build noise templates (different businessTypes or locales)
          const noiseTemplates = noise.map(([bt, loc, st]) => makeTemplate(bt, loc, st));

          // Combine all templates (shuffle order shouldn't matter)
          const templates = [...noiseTemplates, defaultFallback, exactMatch];

          const criteria: TemplateSelectionCriteria = { businessType, locale };
          const result = selectTemplate(templates, criteria);

          // The exact match should be selected
          expect(result).not.toBeNull();
          expect(result!.businessType).toBe(businessType);
          expect(result!.locale).toBe(locale);
          expect(result!.status).toBe('active');
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 2: Default-locale fallback used when no exact locale match exists ──

  test('falls back to default-locale template when no exact locale match exists for the BusinessType', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        localeArb.filter((l) => l !== DEFAULT_LOCALE), // Requested locale must differ from default
        fc.array(
          fc.tuple(businessTypeArb, localeArb, statusArb),
          { minLength: 0, maxLength: 5 },
        ),
        (businessType, requestedLocale, noise) => {
          // Only the default-locale template exists for this BusinessType
          const defaultTemplate = makeTemplate(businessType, DEFAULT_LOCALE, 'active');

          // Build noise — filter out any noise that accidentally matches
          // (businessType + requestedLocale) to avoid false positives
          const noiseTemplates = noise
            .map(([bt, loc, st]) => makeTemplate(bt, loc, st))
            .filter(
              (t) => !(t.businessType === businessType && t.locale === requestedLocale && t.status === 'active'),
            );

          const templates = [...noiseTemplates, defaultTemplate];

          const criteria: TemplateSelectionCriteria = { businessType, locale: requestedLocale };
          const result = selectTemplate(templates, criteria);

          // Should fall back to the default-locale template
          expect(result).not.toBeNull();
          expect(result!.businessType).toBe(businessType);
          expect(result!.locale).toBe(DEFAULT_LOCALE);
          expect(result!.status).toBe('active');
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 3: Returns null when no template matches at all ──

  test('returns null when no active template matches the BusinessType (fail-closed)', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        localeArb,
        fc.array(
          fc.tuple(businessTypeArb, localeArb, statusArb),
          { minLength: 0, maxLength: 5 },
        ),
        (businessType, locale, noise) => {
          // Ensure NO noise template matches the requested businessType with active status
          const templates = noise
            .map(([bt, loc, st]) => makeTemplate(bt, loc, st))
            .filter(
              (t) => !(t.businessType === businessType && t.status === 'active'),
            );

          const criteria: TemplateSelectionCriteria = { businessType, locale };
          const result = selectTemplate(templates, criteria);

          // No matching template → null
          expect(result).toBeNull();
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 4: Locale-specific match takes priority over default-locale match ──

  test('locale-specific match takes priority over the default-locale match', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        localeArb.filter((l) => l !== DEFAULT_LOCALE), // Ensure locale differs from default
        (businessType, requestedLocale) => {
          // Both an exact-locale template and a default-locale template exist
          const exactLocaleTemplate = makeTemplate(businessType, requestedLocale, 'active');
          const defaultLocaleTemplate = makeTemplate(businessType, DEFAULT_LOCALE, 'active');

          // Put default first to ensure order doesn't trick the selection
          const templates = [defaultLocaleTemplate, exactLocaleTemplate];

          const criteria: TemplateSelectionCriteria = { businessType, locale: requestedLocale };
          const result = selectTemplate(templates, criteria);

          // The locale-specific template must be chosen over the default
          expect(result).not.toBeNull();
          expect(result!.locale).toBe(requestedLocale);
          expect(result!.businessType).toBe(businessType);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Invariant: Inactive templates are never selected ──

  test('inactive templates are never selected even when they match BusinessType and locale', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        localeArb,
        (businessType, locale) => {
          // Only inactive templates for this BusinessType
          const inactiveExact = makeTemplate(businessType, locale, 'inactive');
          const inactiveDefault = makeTemplate(businessType, DEFAULT_LOCALE, 'inactive');

          const templates = [inactiveExact, inactiveDefault];

          const criteria: TemplateSelectionCriteria = { businessType, locale };
          const result = selectTemplate(templates, criteria);

          // Should return null — inactive templates are excluded
          expect(result).toBeNull();
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Invariant: Never returns a template from a different BusinessType ──

  test('never returns a template belonging to a different BusinessType', () => {
    fc.assert(
      fc.property(
        businessTypeArb,
        businessTypeArb.filter((bt) => bt.length > 3), // Ensure they can differ
        localeArb,
        (requestedBt, otherBt, locale) => {
          // Skip if they happen to be the same
          fc.pre(requestedBt !== otherBt);

          // Templates only exist for a DIFFERENT businessType
          const wrongBtExact = makeTemplate(otherBt, locale, 'active');
          const wrongBtDefault = makeTemplate(otherBt, DEFAULT_LOCALE, 'active');

          const templates = [wrongBtExact, wrongBtDefault];

          const criteria: TemplateSelectionCriteria = { businessType: requestedBt, locale };
          const result = selectTemplate(templates, criteria);

          // Must return null — the templates are for a different BusinessType
          expect(result).toBeNull();
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });
});
