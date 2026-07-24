/**
 * Monetary Validator Unit Tests
 *
 * Validates: Requirements 5.5–5.7, 13.1–13.2
 */

import { validateMoney, validateSalePrice } from '../monetary-validator';
import { BOUNDS_CONFIG } from '../../config/bounds.config';

describe('validateMoney', () => {
  it('returns MONEY_REQUIRED for null', () => {
    const result = validateMoney(null, 'amount');
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('MONEY_REQUIRED');
      expect(result.error.field).toBe('amount');
    }
  });

  it('returns MONEY_REQUIRED for undefined', () => {
    const result = validateMoney(undefined, 'amount');
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('MONEY_REQUIRED');
    }
  });

  it('returns MONEY_NOT_NUMBER for string', () => {
    const result = validateMoney('five hundred', 'price');
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('MONEY_NOT_NUMBER');
      expect(result.error.field).toBe('price');
    }
  });

  it('returns MONEY_NOT_NUMBER for NaN', () => {
    const result = validateMoney(NaN, 'cost');
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('MONEY_NOT_NUMBER');
    }
  });

  it('returns MONEY_NOT_INTEGER for float', () => {
    const result = validateMoney(99.99, 'price');
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('MONEY_NOT_INTEGER');
    }
  });

  it('returns MONEY_NEGATIVE for negative value', () => {
    const result = validateMoney(-100, 'price');
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('MONEY_NEGATIVE');
    }
  });

  it('returns MONEY_EXCEEDS_MAX when exceeding configured maximum', () => {
    const result = validateMoney(
      BOUNDS_CONFIG.money.maxMinorUnits + 1,
      'price',
    );
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('MONEY_EXCEEDS_MAX');
    }
  });

  it('passes for valid amount and returns Money with correct minorUnitsPerMajor', () => {
    const result = validateMoney(500000, 'salePrice');
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.amountMinorUnits).toBe(500000);
      expect(result.value.minorUnitsPerMajor).toBe(
        BOUNDS_CONFIG.money.minorUnitsPerMajor,
      );
    }
  });

  it('passes for zero amount (valid for demo/damaged units)', () => {
    const result = validateMoney(0, 'salePrice');
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.amountMinorUnits).toBe(0);
    }
  });

  it('passes for maximum allowed amount', () => {
    const result = validateMoney(BOUNDS_CONFIG.money.maxMinorUnits, 'price');
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.amountMinorUnits).toBe(
        BOUNDS_CONFIG.money.maxMinorUnits,
      );
    }
  });
});

// ─── validateSalePrice ───────────────────────────────────────────────────────

describe('validateSalePrice', () => {
  it('validates both salePrice and acquisitionCost independently (preserves valid sibling)', () => {
    // salePrice is invalid (string), acquisitionCost is valid
    const result = validateSalePrice({
      salePrice: 'invalid',
      acquisitionCost: 300000,
    });
    expect(result.ok).toBe(false);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0].code).toBe('MONEY_NOT_NUMBER');
    expect(result.errors[0].field).toBe('salePrice');
    // acquisitionCost should still be validated and preserved
    expect(result.acquisitionCost).toBeDefined();
    expect(result.acquisitionCost!.amountMinorUnits).toBe(300000);
  });

  it('returns both errors when both fields are invalid', () => {
    const result = validateSalePrice({
      salePrice: null,
      acquisitionCost: null,
    });
    expect(result.ok).toBe(false);
    expect(result.errors).toHaveLength(2);
    expect(result.errors[0].field).toBe('salePrice');
    expect(result.errors[1].field).toBe('acquisitionCost');
  });

  it('returns ok=true with both Money values when both are valid', () => {
    const result = validateSalePrice({
      salePrice: 600000,
      acquisitionCost: 500000,
    });
    expect(result.ok).toBe(true);
    expect(result.errors).toHaveLength(0);
    expect(result.salePrice).toBeDefined();
    expect(result.salePrice!.amountMinorUnits).toBe(600000);
    expect(result.acquisitionCost).toBeDefined();
    expect(result.acquisitionCost!.amountMinorUnits).toBe(500000);
  });

  it('preserves acquisitionCost validation even when salePrice fails', () => {
    const result = validateSalePrice({
      salePrice: -100,
      acquisitionCost: 200000,
    });
    expect(result.ok).toBe(false);
    expect(result.errors[0].code).toBe('MONEY_NEGATIVE');
    expect(result.errors[0].field).toBe('salePrice');
    expect(result.acquisitionCost).toBeDefined();
    expect(result.acquisitionCost!.amountMinorUnits).toBe(200000);
  });
});
