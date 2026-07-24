/**
 * Monetary Validator — Domain Logic
 *
 * Validates monetary values as integer minor units (paise/cents).
 * No floating-point money is permitted in the MobileShop domain.
 *
 * Preserves valid sibling fields: if one monetary field fails validation,
 * other validated fields remain available (not cleared).
 *
 * Requirements: 5.5–5.7, 12.1–12.2, 12.6; GR-2.1
 */

import { BOUNDS_CONFIG } from '../config/bounds.config';
import type { Result } from './device-lifecycle';

// ─── Types ───────────────────────────────────────────────────────────────────

/** Validated money value in integer minor units. */
export interface Money {
  /** Amount in minor units (e.g. paise for INR) */
  readonly amountMinorUnits: number;
  /** Minor units per major unit (e.g. 100 for INR) */
  readonly minorUnitsPerMajor: number;
}

export type MonetaryValidationErrorCode =
  | 'MONEY_REQUIRED'
  | 'MONEY_NOT_NUMBER'
  | 'MONEY_NOT_INTEGER'
  | 'MONEY_NEGATIVE'
  | 'MONEY_EXCEEDS_MAX';

export interface MonetaryValidationError {
  readonly code: MonetaryValidationErrorCode;
  readonly field: string;
  readonly message: string;
}

// ─── Sale Price Validation Params ────────────────────────────────────────────

export interface SalePriceParams {
  /** Sale price in minor units. Can be 0 for demo/damaged units. */
  readonly salePrice: unknown;
  /** Acquisition cost in minor units. */
  readonly acquisitionCost: unknown;
}

export interface ValidatedSalePrice {
  readonly salePrice: Money;
  readonly acquisitionCost: Money;
}

/**
 * Result of sale price validation that preserves valid siblings.
 * If one field fails, the other may still be valid and accessible.
 */
export interface SalePriceValidationResult {
  readonly ok: boolean;
  readonly salePrice?: Money;
  readonly acquisitionCost?: Money;
  readonly errors: readonly MonetaryValidationError[];
}

// ─── Money Validation ────────────────────────────────────────────────────────

/**
 * Validates a monetary amount as integer minor units.
 *
 * Rejects:
 * - null / undefined
 * - Non-number types
 * - Non-integer values (must be integer minor units)
 * - Negative amounts (for prices/costs)
 * - Amounts exceeding configured maximum
 *
 * @param amount - The value to validate
 * @param field - Field name for error association
 */
export function validateMoney(
  amount: unknown,
  field: string,
): Result<Money, MonetaryValidationError> {
  // Null/undefined check
  if (amount == null) {
    return {
      ok: false,
      error: {
        code: 'MONEY_REQUIRED',
        field,
        message: `${field} is required`,
      },
    };
  }

  // Type check
  if (typeof amount !== 'number' || isNaN(amount)) {
    return {
      ok: false,
      error: {
        code: 'MONEY_NOT_NUMBER',
        field,
        message: `${field} must be a number`,
      },
    };
  }

  // Integer check — must be integer minor units, no fractions
  if (!Number.isInteger(amount)) {
    return {
      ok: false,
      error: {
        code: 'MONEY_NOT_INTEGER',
        field,
        message: `${field} must be an integer (minor units, no fractions)`,
      },
    };
  }

  // Negative check
  if (amount < 0) {
    return {
      ok: false,
      error: {
        code: 'MONEY_NEGATIVE',
        field,
        message: `${field} must not be negative`,
      },
    };
  }

  // Max check
  if (amount > BOUNDS_CONFIG.money.maxMinorUnits) {
    return {
      ok: false,
      error: {
        code: 'MONEY_EXCEEDS_MAX',
        field,
        message: `${field} exceeds maximum allowed value`,
      },
    };
  }

  return {
    ok: true,
    value: {
      amountMinorUnits: amount,
      minorUnitsPerMajor: BOUNDS_CONFIG.money.minorUnitsPerMajor,
    },
  };
}

// ─── Sale Price Validation ───────────────────────────────────────────────────

/**
 * Validates sale price and acquisition cost together.
 *
 * Rules:
 * - Sale price can be 0 (for demo/damaged units) but not negative
 * - Acquisition cost must be non-negative
 * - Both must be integer minor units within configured bounds
 *
 * Preserves valid sibling fields: if salePrice validation fails,
 * acquisitionCost validation still runs and its result is preserved.
 */
export function validateSalePrice(
  params: SalePriceParams,
): SalePriceValidationResult {
  const errors: MonetaryValidationError[] = [];
  let validSalePrice: Money | undefined;
  let validAcquisitionCost: Money | undefined;

  // Validate sale price
  const salePriceResult = validateMoney(params.salePrice, 'salePrice');
  if (salePriceResult.ok) {
    validSalePrice = salePriceResult.value;
  } else {
    errors.push(salePriceResult.error);
  }

  // Validate acquisition cost — always validate even if salePrice failed
  const acquisitionResult = validateMoney(
    params.acquisitionCost,
    'acquisitionCost',
  );
  if (acquisitionResult.ok) {
    validAcquisitionCost = acquisitionResult.value;
  } else {
    errors.push(acquisitionResult.error);
  }

  return {
    ok: errors.length === 0,
    salePrice: validSalePrice,
    acquisitionCost: validAcquisitionCost,
    errors,
  };
}
