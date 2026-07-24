/**
 * Warranty Validator — Domain Logic
 *
 * Validates warranty month ranges against configured bounds and calculates
 * warranty end dates using the last valid day of the target month.
 *
 * Fixes:
 * - AF-43: Current code uses DateTime(year, month+N, day) which overflows month-end days.
 * - AF-44: No range/negative guard on warranty months input.
 *
 * Requirements: 5.5–5.7, 12.1–12.2, 12.6; GR-2.1
 */

import { BOUNDS_CONFIG } from '../config/bounds.config';
import type { Result } from './device-lifecycle';

// ─── Error Types ─────────────────────────────────────────────────────────────

export type WarrantyValidationErrorCode =
  | 'WARRANTY_MONTHS_REQUIRED'
  | 'WARRANTY_MONTHS_NOT_INTEGER'
  | 'WARRANTY_MONTHS_NOT_POSITIVE'
  | 'WARRANTY_MONTHS_BELOW_MIN'
  | 'WARRANTY_MONTHS_ABOVE_MAX'
  | 'WARRANTY_SALE_DATE_REQUIRED'
  | 'WARRANTY_SALE_DATE_INVALID';

export interface WarrantyValidationError {
  readonly code: WarrantyValidationErrorCode;
  readonly field: string;
  readonly message: string;
}

// ─── Warranty Registration Params ────────────────────────────────────────────

export interface WarrantyRegistrationParams {
  readonly saleDate: Date | string;
  readonly warrantyMonths: number;
  readonly provider?: string;
  readonly notes?: string;
}

export interface ValidatedWarrantyRegistration {
  readonly warrantyMonths: number;
  readonly warrantyEndDate: string;
  readonly provider?: string;
  readonly notes?: string;
}

// ─── Month Utility ───────────────────────────────────────────────────────────

/**
 * Returns the number of days in a given month (1-indexed) for a given year.
 * Handles leap years correctly.
 */
export function getDaysInMonth(year: number, month: number): number {
  // Date(year, month, 0) gives the last day of the previous month in JS,
  // so Date(year, month, 0).getDate() gives last day of month `month - 1`.
  // We want the last day of `month`, so use month + 1 day 0.
  return new Date(year, month, 0).getDate();
}

// ─── Warranty Months Validation ──────────────────────────────────────────────

/**
 * Validates warranty months against configured bounds.
 *
 * Rejects:
 * - null/undefined
 * - Non-number values
 * - Non-integer values (fractional)
 * - Zero or negative
 * - Values below configured minimum
 * - Values above configured maximum
 */
export function validateWarrantyMonths(
  months: unknown,
): Result<number, WarrantyValidationError> {
  // Null/undefined check
  if (months == null) {
    return {
      ok: false,
      error: {
        code: 'WARRANTY_MONTHS_REQUIRED',
        field: 'warrantyMonths',
        message: 'Warranty months is required',
      },
    };
  }

  // Type check
  if (typeof months !== 'number' || isNaN(months)) {
    return {
      ok: false,
      error: {
        code: 'WARRANTY_MONTHS_NOT_INTEGER',
        field: 'warrantyMonths',
        message: 'Warranty months must be a number',
      },
    };
  }

  // Integer check
  if (!Number.isInteger(months)) {
    return {
      ok: false,
      error: {
        code: 'WARRANTY_MONTHS_NOT_INTEGER',
        field: 'warrantyMonths',
        message: 'Warranty months must be a whole number',
      },
    };
  }

  // Positive check (zero and negative)
  if (months <= 0) {
    return {
      ok: false,
      error: {
        code: 'WARRANTY_MONTHS_NOT_POSITIVE',
        field: 'warrantyMonths',
        message: 'Warranty months must be a positive integer',
      },
    };
  }

  // Configured range check
  const { minMonths, maxMonths } = BOUNDS_CONFIG.warranty;

  if (months < minMonths) {
    return {
      ok: false,
      error: {
        code: 'WARRANTY_MONTHS_BELOW_MIN',
        field: 'warrantyMonths',
        message: `Warranty months must be at least ${minMonths}`,
      },
    };
  }

  if (months > maxMonths) {
    return {
      ok: false,
      error: {
        code: 'WARRANTY_MONTHS_ABOVE_MAX',
        field: 'warrantyMonths',
        message: `Warranty months must not exceed ${maxMonths}`,
      },
    };
  }

  return { ok: true, value: months };
}

// ─── Warranty End Date Calculation ───────────────────────────────────────────

/**
 * Calculates warranty end date from a sale date plus warranty months.
 *
 * Correctly handles month-end dates: if saleDate is Jan 31 and months is 1,
 * the result is Feb 28 (or Feb 29 in a leap year).
 *
 * Algorithm:
 *   1. Parse saleDate to get year, month, day
 *   2. Add months to get targetMonth; normalize year overflow
 *   3. Get last day of target month
 *   4. Clamp sale day to target month's last day
 *   5. Return ISO 8601 date string (YYYY-MM-DD)
 *
 * Fixes AF-43: replaces naive DateTime(year, month+N, day) overflow.
 */
export function calculateWarrantyEndDate(
  saleDate: Date | string,
  months: number,
): string {
  const date = typeof saleDate === 'string' ? new Date(saleDate) : saleDate;

  const saleYear = date.getFullYear();
  const saleMonth = date.getMonth() + 1; // 1-indexed
  const saleDay = date.getDate();

  // Add months and normalize
  let targetMonth = saleMonth + months;
  let targetYear = saleYear + Math.floor((targetMonth - 1) / 12);
  targetMonth = ((targetMonth - 1) % 12) + 1;

  // Get last day of target month
  const lastDay = getDaysInMonth(targetYear, targetMonth);

  // Clamp sale day to target month's last day
  const day = Math.min(saleDay, lastDay);

  // Format as ISO date string (YYYY-MM-DD)
  const yyyy = String(targetYear).padStart(4, '0');
  const mm = String(targetMonth).padStart(2, '0');
  const dd = String(day).padStart(2, '0');

  return `${yyyy}-${mm}-${dd}`;
}

// ─── Full Warranty Registration Validation ───────────────────────────────────

/**
 * Validates all warranty registration fields together.
 * Preserves valid sibling fields: if warrantyMonths fails, other fields
 * (provider, notes) remain available in the error context.
 */
export function validateWarrantyRegistration(
  params: WarrantyRegistrationParams,
): Result<ValidatedWarrantyRegistration, WarrantyValidationError> {
  // Validate sale date
  if (params.saleDate == null) {
    return {
      ok: false,
      error: {
        code: 'WARRANTY_SALE_DATE_REQUIRED',
        field: 'saleDate',
        message: 'Sale date is required for warranty registration',
      },
    };
  }

  const date =
    typeof params.saleDate === 'string'
      ? new Date(params.saleDate)
      : params.saleDate;

  if (isNaN(date.getTime())) {
    return {
      ok: false,
      error: {
        code: 'WARRANTY_SALE_DATE_INVALID',
        field: 'saleDate',
        message: 'Sale date is not a valid date',
      },
    };
  }

  // Validate warranty months
  const monthsResult = validateWarrantyMonths(params.warrantyMonths);
  if (!monthsResult.ok) {
    return monthsResult;
  }

  // Calculate end date
  const warrantyEndDate = calculateWarrantyEndDate(date, monthsResult.value);

  return {
    ok: true,
    value: {
      warrantyMonths: monthsResult.value,
      warrantyEndDate,
      provider: params.provider,
      notes: params.notes,
    },
  };
}
