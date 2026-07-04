// ============================================================================
// Template Selection Service — Unit Tests (Task 7.4)
// ============================================================================
// Validates the selection logic:
// 1. Exact match (BusinessType + locale) is preferred
// 2. Default-locale fallback when exact locale unavailable
// 3. Fail-closed (null) when no match at all
// 4. Only active templates are considered
// 5. Never returns a template from a different BusinessType
//
// Requirements: 4.5, 6.7
// ============================================================================

import {
  selectTemplate,
  selectFullTemplate,
  DEFAULT_LOCALE,
  type TemplateSelectionCriteria,
} from './template-selection.service';

// ── Test Helpers ──────────────────────────────────────────────────────────────

type PartialTemplate = { businessType: string; locale: string; status: 'active' | 'inactive' };

function makeTemplate(
  businessType: string,
  locale: string,
  status: 'active' | 'inactive' = 'active',
): PartialTemplate {
  return { businessType, locale, status };
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('selectTemplate', () => {
  describe('exact match (BusinessType + locale)', () => {
    it('returns the template matching both businessType and locale', () => {
      const templates = [
        makeTemplate('grocery', 'en'),
        makeTemplate('grocery', 'hi'),
        makeTemplate('mobile_store', 'en'),
      ];

      const result = selectTemplate(templates, { businessType: 'grocery', locale: 'hi' });

      expect(result).toEqual(makeTemplate('grocery', 'hi'));
    });

    it('prefers exact locale over default locale', () => {
      const templates = [
        makeTemplate('clinic', 'en'),
        makeTemplate('clinic', 'mr'),
      ];

      const result = selectTemplate(templates, { businessType: 'clinic', locale: 'mr' });

      expect(result).toEqual(makeTemplate('clinic', 'mr'));
    });
  });

  describe('default-locale fallback', () => {
    it('falls back to default locale when exact locale is unavailable', () => {
      const templates = [
        makeTemplate('grocery', 'en'),
        makeTemplate('grocery', 'hi'),
      ];

      // Request 'mr' which doesn't exist — should fallback to 'en'
      const result = selectTemplate(templates, { businessType: 'grocery', locale: 'mr' });

      expect(result).toEqual(makeTemplate('grocery', 'en'));
    });

    it('uses a custom default locale when provided', () => {
      const templates = [
        makeTemplate('grocery', 'hi'),
        makeTemplate('grocery', 'en'),
      ];

      // Request 'mr', custom default 'hi'
      const result = selectTemplate(
        templates,
        { businessType: 'grocery', locale: 'mr' },
        'hi',
      );

      expect(result).toEqual(makeTemplate('grocery', 'hi'));
    });
  });

  describe('fail-closed (returns null)', () => {
    it('returns null when no templates exist', () => {
      const result = selectTemplate([], { businessType: 'grocery', locale: 'en' });

      expect(result).toBeNull();
    });

    it('returns null when no templates match the businessType', () => {
      const templates = [
        makeTemplate('mobile_store', 'en'),
        makeTemplate('clinic', 'hi'),
      ];

      const result = selectTemplate(templates, { businessType: 'grocery', locale: 'en' });

      expect(result).toBeNull();
    });

    it('returns null when businessType matches but neither exact nor default locale exists', () => {
      const templates = [
        makeTemplate('grocery', 'hi'),
        makeTemplate('grocery', 'mr'),
      ];

      // Request 'ta' (Tamil), default is 'en' which also doesn't exist
      const result = selectTemplate(templates, { businessType: 'grocery', locale: 'ta' });

      expect(result).toBeNull();
    });

    it('returns null when only inactive templates match', () => {
      const templates = [
        makeTemplate('grocery', 'en', 'inactive'),
        makeTemplate('grocery', 'hi', 'inactive'),
      ];

      const result = selectTemplate(templates, { businessType: 'grocery', locale: 'en' });

      expect(result).toBeNull();
    });
  });

  describe('active-only filtering', () => {
    it('ignores inactive templates even when they match exactly', () => {
      const templates = [
        makeTemplate('grocery', 'hi', 'inactive'), // exact match but inactive
        makeTemplate('grocery', 'en', 'active'),   // fallback — active
      ];

      const result = selectTemplate(templates, { businessType: 'grocery', locale: 'hi' });

      // Should fallback to the active 'en' template
      expect(result).toEqual(makeTemplate('grocery', 'en'));
    });

    it('returns null when exact match is inactive and no default-locale template exists', () => {
      const templates = [
        makeTemplate('grocery', 'hi', 'inactive'),
        makeTemplate('grocery', 'mr', 'active'),
      ];

      // Request 'hi' (inactive), fallback 'en' (doesn't exist)
      const result = selectTemplate(templates, { businessType: 'grocery', locale: 'hi' });

      expect(result).toBeNull();
    });
  });

  describe('cross-business-type isolation', () => {
    it('never returns a template from a different businessType', () => {
      const templates = [
        makeTemplate('mobile_store', 'en'),
        makeTemplate('mobile_store', 'hi'),
        makeTemplate('clinic', 'en'),
      ];

      const result = selectTemplate(templates, { businessType: 'grocery', locale: 'en' });

      expect(result).toBeNull();
    });
  });

  describe('edge cases', () => {
    it('handles request where locale equals the default locale', () => {
      const templates = [
        makeTemplate('grocery', 'en'),
      ];

      const result = selectTemplate(templates, { businessType: 'grocery', locale: 'en' });

      expect(result).toEqual(makeTemplate('grocery', 'en'));
    });

    it('handles request where locale equals the default locale and template is missing', () => {
      const templates = [
        makeTemplate('grocery', 'hi'),
      ];

      // Request 'en' which IS the default locale — no double-lookup
      const result = selectTemplate(templates, { businessType: 'grocery', locale: 'en' });

      expect(result).toBeNull();
    });
  });
});

describe('selectFullTemplate', () => {
  it('returns the full MessageTemplate object on match', () => {
    const now = '2025-01-01T00:00:00.000Z';
    const fullTemplate = {
      id: 'tmpl-1',
      businessId: 'biz-1',
      tenantId: 'tenant-1',
      name: 'Invoice Template',
      businessType: 'grocery',
      locale: 'hi',
      body: 'Hello {{customer.name}}, your invoice is ready.',
      placeholders: ['customer.name'],
      currentVersion: 1,
      status: 'active' as const,
      createdAt: now,
      updatedAt: now,
    };

    const result = selectFullTemplate(
      [fullTemplate],
      { businessType: 'grocery', locale: 'hi' },
    );

    expect(result).toBe(fullTemplate);
  });

  it('returns null when no match (same fail-closed behavior)', () => {
    const result = selectFullTemplate([], { businessType: 'grocery', locale: 'en' });

    expect(result).toBeNull();
  });
});

describe('DEFAULT_LOCALE constant', () => {
  it('is "en"', () => {
    expect(DEFAULT_LOCALE).toBe('en');
  });
});
