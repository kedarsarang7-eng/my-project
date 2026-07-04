// ============================================================================
// WhatsApp Automation Module — Template Selection Service (Task 7.4)
// ============================================================================
// Pure function that selects the correct MessageTemplate for a given
// BusinessType and locale combination.
//
// SELECTION LOGIC (fail-closed):
// 1. Try exact match: active template with matching BusinessType AND locale
// 2. Fallback: active template with matching BusinessType AND the default locale
// 3. No match: return null — never send with the wrong template
//
// This is critical for ensuring the correct template goes to the correct
// customer. Wrong template = wrong invoice to wrong person.
//
// DESIGN CONTRACTS:
// - Pure function: no side effects, deterministic
// - Only considers active templates (status === 'active')
// - Fail-closed: returns null when no suitable template is found
// - Never returns a template belonging to a different BusinessType
//
// Requirements: 4.5, 6.7
// ============================================================================

import type { MessageTemplate } from '../schemas/entities';

// ── Configuration ─────────────────────────────────────────────────────────────

/** The fallback locale used when no exact locale match is found. */
export const DEFAULT_LOCALE = 'en';

// ── Input Types ───────────────────────────────────────────────────────────────

export interface TemplateSelectionCriteria {
  /** The business type to match (e.g. 'grocery', 'mobile_store', 'clinic'). */
  readonly businessType: string;
  /** The preferred locale (e.g. 'hi', 'en', 'mr'). */
  readonly locale: string;
}

// ── Core Selection Function ───────────────────────────────────────────────────

/**
 * Selects the most appropriate active MessageTemplate for the given
 * BusinessType and locale from a list of candidate templates.
 *
 * Selection priority:
 * 1. Exact match — template where businessType AND locale both match
 * 2. Default-locale fallback — template where businessType matches AND
 *    locale equals the default locale ('en')
 * 3. No match — returns null (fail-closed, no message sent)
 *
 * Only templates with status 'active' are considered. Inactive templates
 * are excluded regardless of match quality.
 *
 * @param templates - Array of candidate MessageTemplates (typically all
 *   templates for the business, pre-filtered by name/eventType if needed)
 * @param criteria - The BusinessType and locale to match against
 * @param defaultLocale - Override for the default fallback locale (default: 'en')
 * @returns The best-matching MessageTemplate, or null if none qualifies
 */
export function selectTemplate(
  templates: readonly Pick<MessageTemplate, 'businessType' | 'locale' | 'status'>[],
  criteria: TemplateSelectionCriteria,
  defaultLocale: string = DEFAULT_LOCALE,
): Pick<MessageTemplate, 'businessType' | 'locale' | 'status'> | null {
  const { businessType, locale } = criteria;

  // Filter to only active templates for the correct BusinessType
  const activeForBusinessType = templates.filter(
    (t) => t.status === 'active' && t.businessType === businessType,
  );

  // 1. Try exact match: BusinessType + requested locale
  const exactMatch = activeForBusinessType.find((t) => t.locale === locale);
  if (exactMatch) {
    return exactMatch;
  }

  // 2. Fallback: BusinessType + default locale
  // Skip this step if the requested locale IS the default locale (already tried above)
  if (locale !== defaultLocale) {
    const defaultMatch = activeForBusinessType.find((t) => t.locale === defaultLocale);
    if (defaultMatch) {
      return defaultMatch;
    }
  }

  // 3. Fail-closed: no suitable template found
  return null;
}

/**
 * Convenience overload that operates on full MessageTemplate objects and
 * returns the full object (preserving all fields for downstream use).
 *
 * Same selection logic as `selectTemplate` but with full type preservation.
 */
export function selectFullTemplate(
  templates: readonly MessageTemplate[],
  criteria: TemplateSelectionCriteria,
  defaultLocale: string = DEFAULT_LOCALE,
): MessageTemplate | null {
  const { businessType, locale } = criteria;

  // Filter to only active templates for the correct BusinessType
  const activeForBusinessType = templates.filter(
    (t) => t.status === 'active' && t.businessType === businessType,
  );

  // 1. Try exact match: BusinessType + requested locale
  const exactMatch = activeForBusinessType.find((t) => t.locale === locale);
  if (exactMatch) {
    return exactMatch;
  }

  // 2. Fallback: BusinessType + default locale
  if (locale !== defaultLocale) {
    const defaultMatch = activeForBusinessType.find((t) => t.locale === defaultLocale);
    if (defaultMatch) {
      return defaultMatch;
    }
  }

  // 3. Fail-closed
  return null;
}
