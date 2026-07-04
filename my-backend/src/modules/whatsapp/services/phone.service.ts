// ============================================================================
// WhatsApp Automation Module — Phone Number Validation Service (Task 5.1)
// ============================================================================
// Validates phone numbers against the E.164 international format.
// This is a critical safety component: incorrect validation could cause
// invoices, payment confirmations, and other business documents to be
// delivered to the wrong recipients.
//
// E.164 format: a leading "+" followed by 8 to 15 digits (no spaces,
// dashes, parentheses, or other formatting characters).
//
// Requirements: 2.1, 2.2, 11.4, 11.11
// ============================================================================

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

/** Result of an E.164 phone number validation. */
export interface E164ValidationResult {
  /** Whether the number is a valid E.164 phone number. */
  valid: boolean;
  /** The normalized (trimmed) phone number if valid; undefined if invalid. */
  normalized?: string;
  /** Human-readable error message explaining why validation failed. */
  error?: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

/**
 * E.164 regex: leading "+" followed by exactly 8 to 15 digits.
 * - No spaces, dashes, parentheses, or other characters allowed.
 * - Minimum 8 digits covers the shortest valid international numbers.
 * - Maximum 15 digits is the ITU-T E.164 upper bound.
 */
const E164_REGEX = /^\+\d{8,15}$/;

/** Minimum digit count (excluding the leading "+"). */
const MIN_DIGITS = 8;

/** Maximum digit count (excluding the leading "+"). */
const MAX_DIGITS = 15;

// ────────────────────────────────────────────────────────────────────────────
// Validation
// ────────────────────────────────────────────────────────────────────────────

/**
 * Validates that a phone number conforms to E.164 format.
 *
 * E.164 requires:
 * - A leading "+" character
 * - Followed by 8 to 15 digits (no spaces, dashes, or formatting)
 *
 * The input is trimmed of leading/trailing whitespace before validation.
 *
 * @param number - The phone number string to validate.
 * @returns An E164ValidationResult indicating validity, the normalized number,
 *          or a descriptive error message.
 *
 * @example
 * ```ts
 * validateE164('+919876543210')  // { valid: true, normalized: '+919876543210' }
 * validateE164('919876543210')   // { valid: false, error: '...' }
 * validateE164('+123')           // { valid: false, error: '...' }
 * ```
 */
export function validateE164(number: string): E164ValidationResult {
  // Handle null/undefined/non-string defensively
  if (number === null || number === undefined || typeof number !== 'string') {
    return {
      valid: false,
      error: 'Phone number must be a non-empty string.',
    };
  }

  // Trim leading/trailing whitespace
  const trimmed = number.trim();

  // Check for empty input after trimming
  if (trimmed.length === 0) {
    return {
      valid: false,
      error: 'Phone number must not be empty.',
    };
  }

  // Must start with "+"
  if (!trimmed.startsWith('+')) {
    return {
      valid: false,
      error:
        'Phone number must start with "+" followed by the country code and number. ' +
        `Received: "${trimmed}".`,
    };
  }

  // Extract the digit portion (everything after "+")
  const digitPortion = trimmed.slice(1);

  // Check for non-digit characters in the digit portion
  if (!/^\d*$/.test(digitPortion)) {
    // Identify the offending characters for a helpful error message
    const invalidChars = digitPortion.replace(/\d/g, '');
    const uniqueInvalid = [...new Set(invalidChars)].join(', ');
    return {
      valid: false,
      error:
        `Phone number must contain only digits after the leading "+". ` +
        `Found invalid character(s): ${uniqueInvalid}.`,
    };
  }

  // Check minimum digit length
  if (digitPortion.length < MIN_DIGITS) {
    return {
      valid: false,
      error:
        `Phone number is too short. E.164 requires at least ${MIN_DIGITS} digits ` +
        `after "+", but received ${digitPortion.length}.`,
    };
  }

  // Check maximum digit length
  if (digitPortion.length > MAX_DIGITS) {
    return {
      valid: false,
      error:
        `Phone number is too long. E.164 allows at most ${MAX_DIGITS} digits ` +
        `after "+", but received ${digitPortion.length}.`,
    };
  }

  // Final regex guard (should always pass if the above checks pass,
  // but provides defense-in-depth)
  if (!E164_REGEX.test(trimmed)) {
    return {
      valid: false,
      error: 'Phone number does not conform to E.164 format (+[8-15 digits]).',
    };
  }

  return {
    valid: true,
    normalized: trimmed,
  };
}

/**
 * Strict boolean check for E.164 validity. Convenience wrapper around
 * `validateE164` when only the pass/fail result is needed.
 *
 * @param number - The phone number string to validate.
 * @returns `true` if the number is valid E.164; `false` otherwise.
 */
export function isValidE164(number: string): boolean {
  return validateE164(number).valid;
}

/**
 * Normalizes a phone number by trimming whitespace and validating E.164.
 * Returns the normalized number or throws an error if invalid.
 *
 * Use this when you need the validated number and want to reject invalid
 * input with an exception (e.g., in save/persist paths).
 *
 * @param number - The phone number to normalize and validate.
 * @returns The trimmed, validated E.164 phone number.
 * @throws Error with a descriptive message if validation fails.
 */
export function normalizeE164OrThrow(number: string): string {
  const result = validateE164(number);
  if (!result.valid) {
    throw new Error(result.error);
  }
  return result.normalized!;
}
