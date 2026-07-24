/**
 * IMEI Validator Shared Test Fixtures
 *
 * Provides known-good and known-bad IMEI values for testing both
 * TypeScript and Dart implementations. The Dart fixtures mirror these exactly.
 *
 * All "valid" IMEIs pass the Luhn algorithm. Invalid entries cover each
 * documented error code and precedence level.
 */

// ─── Valid IMEIs (all pass Luhn checksum) ────────────────────────────────────

/** Valid 15-digit IMEIs with correct Luhn check digit */
export const VALID_IMEIS = [
  '490154203237518', // Standard valid IMEI
  '356938035643809', // Samsung-style TAC
  '353201080003103', // Nokia-style TAC
  '861536030196001', // Xiaomi-style TAC
  '352099001761481', // Apple-style TAC
] as const;

/** Valid IMEIs with configured separators that should normalize correctly */
export const VALID_IMEIS_WITH_SEPARATORS = [
  { raw: '49-0154-203237-518', normalized: '490154203237518' },
  { raw: '356 938 035 643 809', normalized: '356938035643809' },
  { raw: '353.201.080.003.103', normalized: '353201080003103' },
  { raw: '86-15 36.030196001', normalized: '861536030196001' }, // Mixed separators
  { raw: '35-2099-0017-6148-1', normalized: '352099001761481' },
] as const;

// ─── Invalid: Empty/Required ─────────────────────────────────────────────────

/** Inputs that should produce IMEI_REQUIRED */
export const INVALID_REQUIRED = [
  { raw: '', description: 'empty string' },
  { raw: '   ', description: 'whitespace only' },
  { raw: null, description: 'null' },
  { raw: undefined, description: 'undefined' },
] as const;

// ─── Invalid: Non-digit characters ──────────────────────────────────────────

/** Inputs that should produce IMEI_INVALID_CHARACTERS after separator removal */
export const INVALID_CHARACTERS = [
  { raw: '49015420323751X', description: 'letter at end' },
  { raw: 'ABCDEFGHIJKLMNO', description: 'all letters' },
  { raw: '49015420323+518', description: 'plus sign' },
  { raw: '490154203237#18', description: 'hash character' },
  { raw: '4901542032375!8', description: 'exclamation mark' },
  { raw: '49015420323751²', description: 'non-ASCII digit (superscript 2)' },
] as const;

// ─── Invalid: Wrong length ───────────────────────────────────────────────────

/** Inputs that should produce IMEI_INVALID_LENGTH (all ASCII digits, wrong count) */
export const INVALID_LENGTH = [
  { raw: '49015420323751', description: 'too short (14 digits)' },
  { raw: '4901542032375180', description: 'too long (16 digits)' },
  { raw: '490154', description: 'way too short (6 digits)' },
  { raw: '4', description: 'single digit' },
  { raw: '49015420323751849015', description: 'way too long (20 digits)' },
] as const;

// ─── Invalid: Bad Luhn checksum ──────────────────────────────────────────────

/** 15-digit all-ASCII inputs that fail Luhn (check digit is wrong) */
export const INVALID_CHECKSUM = [
  { raw: '490154203237519', description: 'last digit off by 1 from valid' },
  { raw: '356938035643800', description: 'zero instead of correct check' },
  { raw: '123456789012345', description: 'sequential digits (fails Luhn)' },
  { raw: '111111111111111', description: 'all ones (fails Luhn)' },
] as const;

// ─── Edge cases ──────────────────────────────────────────────────────────────

/** Edge-case valid IMEIs */
export const EDGE_CASE_VALID = [
  { raw: '000000000000000', description: 'all zeros (Luhn sum is 0, passes)' },
] as const;

/** Edge-case invalid scenarios */
export const EDGE_CASE_INVALID = [
  { raw: '---', expected: 'IMEI_REQUIRED', description: 'only separators (empty after normalization)' },
  { raw: '- . -', expected: 'IMEI_REQUIRED', description: 'separators and spaces only' },
] as const;
