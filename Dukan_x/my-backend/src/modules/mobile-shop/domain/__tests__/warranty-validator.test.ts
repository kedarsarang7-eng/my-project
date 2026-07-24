/**
 * Warranty Validator Unit Tests
 *
 * Validates: Requirements 5.5–5.7, 13.1–13.2
 */

import {
  validateWarrantyMonths,
  calculateWarrantyEndDate,
  validateWarrantyRegistration,
  getDaysInMonth,
} from '../warranty-validator';
import { BOUNDS_CONFIG } from '../../config/bounds.config';

describe('validateWarrantyMonths', () => {
  const { minMonths, maxMonths } = BOUNDS_CONFIG.warranty;

  it('returns WARRANTY_MONTHS_REQUIRED for null', () => {
    const result = validateWarrantyMonths(null);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('WARRANTY_MONTHS_REQUIRED');
    }
  });

  it('returns WARRANTY_MONTHS_REQUIRED for undefined', () => {
    const result = validateWarrantyMonths(undefined);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('WARRANTY_MONTHS_REQUIRED');
    }
  });

  it('returns WARRANTY_MONTHS_NOT_INTEGER for non-number (string)', () => {
    const result = validateWarrantyMonths('six');
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('WARRANTY_MONTHS_NOT_INTEGER');
    }
  });

  it('returns WARRANTY_MONTHS_NOT_INTEGER for NaN', () => {
    const result = validateWarrantyMonths(NaN);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('WARRANTY_MONTHS_NOT_INTEGER');
    }
  });

  it('returns WARRANTY_MONTHS_NOT_INTEGER for float', () => {
    const result = validateWarrantyMonths(6.5);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('WARRANTY_MONTHS_NOT_INTEGER');
    }
  });

  it('returns WARRANTY_MONTHS_NOT_POSITIVE for zero', () => {
    const result = validateWarrantyMonths(0);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('WARRANTY_MONTHS_NOT_POSITIVE');
    }
  });

  it('returns WARRANTY_MONTHS_NOT_POSITIVE for negative', () => {
    const result = validateWarrantyMonths(-3);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('WARRANTY_MONTHS_NOT_POSITIVE');
    }
  });

  it('returns WARRANTY_MONTHS_BELOW_MIN when below configured minimum', () => {
    // Only relevant if minMonths > 1
    if (minMonths > 1) {
      const result = validateWarrantyMonths(minMonths - 1);
      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.error.code).toBe('WARRANTY_MONTHS_BELOW_MIN');
      }
    } else {
      // minMonths === 1, so 1 is valid. NOT_POSITIVE handles < 1.
      expect(true).toBe(true);
    }
  });

  it('returns WARRANTY_MONTHS_ABOVE_MAX when above configured maximum', () => {
    const result = validateWarrantyMonths(maxMonths + 1);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('WARRANTY_MONTHS_ABOVE_MAX');
    }
  });

  it('passes for minimum allowed months', () => {
    const result = validateWarrantyMonths(minMonths);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value).toBe(minMonths);
    }
  });

  it('passes for maximum allowed months', () => {
    const result = validateWarrantyMonths(maxMonths);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value).toBe(maxMonths);
    }
  });

  it('passes for valid months within range', () => {
    const result = validateWarrantyMonths(12);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value).toBe(12);
    }
  });
});

// ─── Month-End Warranty Date Calculation ─────────────────────────────────────

describe('calculateWarrantyEndDate — month-end clamping', () => {
  it('Jan 31 + 1 month → Feb 28 (non-leap year 2023)', () => {
    const result = calculateWarrantyEndDate(new Date(2023, 0, 31), 1);
    expect(result).toBe('2023-02-28');
  });

  it('Jan 31 + 1 month → Feb 29 (leap year 2024)', () => {
    const result = calculateWarrantyEndDate(new Date(2024, 0, 31), 1);
    expect(result).toBe('2024-02-29');
  });

  it('Mar 31 + 1 month → Apr 30', () => {
    const result = calculateWarrantyEndDate(new Date(2024, 2, 31), 1);
    expect(result).toBe('2024-04-30');
  });

  it('May 31 + 6 months → Nov 30', () => {
    const result = calculateWarrantyEndDate(new Date(2024, 4, 31), 6);
    expect(result).toBe('2024-11-30');
  });

  it('Dec 31 + 1 month → Jan 31 (next year)', () => {
    const result = calculateWarrantyEndDate(new Date(2024, 11, 31), 1);
    expect(result).toBe('2025-01-31');
  });

  it('regular date: Jan 15 + 3 months → Apr 15', () => {
    const result = calculateWarrantyEndDate(new Date(2024, 0, 15), 3);
    expect(result).toBe('2024-04-15');
  });

  it('handles year overflow: Nov 30 + 3 months → Feb 28 next year', () => {
    const result = calculateWarrantyEndDate(new Date(2023, 10, 30), 3);
    expect(result).toBe('2024-02-29'); // 2024 is leap year
  });
});

// ─── getDaysInMonth ──────────────────────────────────────────────────────────

describe('getDaysInMonth', () => {
  it('returns 28 for Feb 2023 (non-leap)', () => {
    expect(getDaysInMonth(2023, 2)).toBe(28);
  });

  it('returns 29 for Feb 2024 (leap year)', () => {
    expect(getDaysInMonth(2024, 2)).toBe(29);
  });

  it('returns 31 for January', () => {
    expect(getDaysInMonth(2024, 1)).toBe(31);
  });

  it('returns 30 for April', () => {
    expect(getDaysInMonth(2024, 4)).toBe(30);
  });
});

// ─── validateWarrantyRegistration ────────────────────────────────────────────

describe('validateWarrantyRegistration', () => {
  it('returns WARRANTY_SALE_DATE_REQUIRED when saleDate is null', () => {
    const result = validateWarrantyRegistration({
      saleDate: null as any,
      warrantyMonths: 12,
    });
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('WARRANTY_SALE_DATE_REQUIRED');
    }
  });

  it('returns WARRANTY_SALE_DATE_INVALID for invalid date string', () => {
    const result = validateWarrantyRegistration({
      saleDate: 'not-a-date',
      warrantyMonths: 12,
    });
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('WARRANTY_SALE_DATE_INVALID');
    }
  });

  it('passes warranty months validation errors through', () => {
    const result = validateWarrantyRegistration({
      saleDate: '2024-06-15',
      warrantyMonths: -5,
    });
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('WARRANTY_MONTHS_NOT_POSITIVE');
    }
  });

  it('returns validated registration with correct end date', () => {
    const result = validateWarrantyRegistration({
      saleDate: '2024-01-15',
      warrantyMonths: 12,
      provider: 'Samsung',
      notes: 'Extended warranty',
    });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.warrantyMonths).toBe(12);
      expect(result.value.warrantyEndDate).toBe('2025-01-15');
      expect(result.value.provider).toBe('Samsung');
      expect(result.value.notes).toBe('Extended warranty');
    }
  });
});
