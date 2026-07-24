/**
 * IMEI Validator — One Authoritative Validation Path
 *
 * Applies configured separator normalization, 15 ASCII digits, Luhn checksum,
 * required-field behavior, and field-associated errors.
 *
 * This is the ONLY IMEI validation path used by UI, repository, sync, and backend.
 * Uniqueness and lifecycle state are NOT validated here — those require DynamoDB
 * conditional writes (reserved for persistence layer).
 *
 * Requirements: 2.5–2.6, 3.1–3.2, 3.12, 4.2–4.4, 12.1–12.3
 * Replaces: AF-42 weak `_guessIMEIType` heuristic
 */

import { VALIDATION_CONFIG } from '../config/validation.config';
import { BOUNDS_CONFIG } from '../config/bounds.config';

// ─── Branded Type ────────────────────────────────────────────────────────────

/** A normalized 15-digit IMEI that has passed all local validation checks. */
export type NormalizedImei = string & { readonly __brand: 'NormalizedImei' };

// ─── Error Types ─────────────────────────────────────────────────────────────

/** IMEI validation error codes (local checks only, no uniqueness/lifecycle). */
export type ImeiValidationErrorCode =
  | 'IMEI_REQUIRED'
  | 'IMEI_INVALID_CHARACTERS'
  | 'IMEI_INVALID_LENGTH'
  | 'IMEI_INVALID_CHECKSUM';

/** Field-associated IMEI validation error. */
export interface ImeiValidationError {
  /** The error code */
  readonly code: ImeiValidationErrorCode;
  /** Associated field name */
  readonly field: string;
  /** Human-readable message */
  readonly message: string;
}

// ─── Result Type ─────────────────────────────────────────────────────────────

export type ImeiValidationResult =
  | { readonly ok: true; readonly value: NormalizedImei }
  | { readonly ok: false; readonly error: ImeiValidationError };

// ─── Luhn Algorithm ──────────────────────────────────────────────────────────

/**
 * Validates the Luhn checksum for a 15-digit IMEI string.
 *
 * For digits d1..d15 (1-indexed from left):
 * - Double every second digit from the right (positions 2,4,6,8,10,12,14 from right,
 *   which are positions 2,4,6,8,10,12,14 from left in a 15-digit string — i.e. even indices 0-based: 1,3,5,7,9,11,13).
 * - Sum the digits of doubled values.
 * - Total mod 10 must equal 0.
 */
export function isValidLuhn(digits: string): boolean {
  if (digits.length !== 15) return false;

  let sum = 0;
  for (let i = 0; i < 15; i++) {
    let digit = parseInt(digits[i], 10);
    // From the rightmost digit (index 14), odd positions (0-indexed from right: 1,3,5...)
    // are doubled. Position from right = 14 - i. If (14 - i) is odd => double.
    // Simplified: if i is even (0,2,4,...14) => position from right is even => no double
    //             if i is odd (1,3,5,...13) => position from right is odd => double
    if (i % 2 === 1) {
      digit *= 2;
      if (digit > 9) {
        digit -= 9; // equivalent to summing digits of a two-digit number (max 18)
      }
    }
    sum += digit;
  }

  return sum % 10 === 0;
}

// ─── Validator ───────────────────────────────────────────────────────────────

/**
 * Validates and normalizes a raw IMEI input string.
 *
 * Validation precedence (from VALIDATION_CONFIG):
 *  1. Required check (priority 10)
 *  2. Separator normalization + ASCII-digit-only check (priority 20)
 *  3. Length check — exactly 15 digits (priority 30)
 *  4. Luhn checksum (priority 40)
 *
 * Does NOT check uniqueness (priority 50) or lifecycle (priority 60) —
 * those are DynamoDB conditional write concerns.
 */
export function validateImei(raw: string | null | undefined): ImeiValidationResult {
  // 1. Required check
  if (raw == null || raw.trim() === '') {
    return {
      ok: false,
      error: {
        code: 'IMEI_REQUIRED',
        field: 'imei',
        message: 'IMEI is required',
      },
    };
  }

  // 2. Separator normalization: remove configured separators
  let normalized = raw;
  for (const sep of VALIDATION_CONFIG.imeiSeparators) {
    normalized = normalized.split(sep).join('');
  }

  // If normalization produced an empty string, treat as required violation
  if (normalized.trim() === '') {
    return {
      ok: false,
      error: {
        code: 'IMEI_REQUIRED',
        field: 'imei',
        message: 'IMEI is required',
      },
    };
  }

  // ASCII-digit-only check
  if (!/^[0-9]+$/.test(normalized)) {
    return {
      ok: false,
      error: {
        code: 'IMEI_INVALID_CHARACTERS',
        field: 'imei',
        message: 'IMEI must contain only ASCII digits (0-9)',
      },
    };
  }

  // 3. Length check — exactly 15 digits
  if (normalized.length !== BOUNDS_CONFIG.imei.length) {
    return {
      ok: false,
      error: {
        code: 'IMEI_INVALID_LENGTH',
        field: 'imei',
        message: `IMEI must be exactly ${BOUNDS_CONFIG.imei.length} digits`,
      },
    };
  }

  // 4. Luhn checksum
  if (!isValidLuhn(normalized)) {
    return {
      ok: false,
      error: {
        code: 'IMEI_INVALID_CHECKSUM',
        field: 'imei',
        message: 'IMEI fails Luhn checksum validation',
      },
    };
  }

  return {
    ok: true,
    value: normalized as NormalizedImei,
  };
}
