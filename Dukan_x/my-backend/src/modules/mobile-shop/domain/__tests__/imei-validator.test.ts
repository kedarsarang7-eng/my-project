/**
 * IMEI Validator Unit Tests
 *
 * Validates: Requirements 3.1–3.2, 3.12, 4.2–4.4
 */

import { validateImei } from '../imei-validator';
import {
  VALID_IMEIS,
  VALID_IMEIS_WITH_SEPARATORS,
  INVALID_REQUIRED,
  INVALID_CHARACTERS,
  INVALID_LENGTH,
  INVALID_CHECKSUM,
  EDGE_CASE_VALID,
  EDGE_CASE_INVALID,
} from '../imei-validator.fixtures';

describe('validateImei', () => {
  // ─── Valid IMEIs ─────────────────────────────────────────────────────────

  describe('valid IMEIs', () => {
    it.each(VALID_IMEIS)('passes for valid IMEI %s', (imei) => {
      const result = validateImei(imei);
      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.value).toBe(imei);
      }
    });
  });

  describe('separator normalization', () => {
    it.each(VALID_IMEIS_WITH_SEPARATORS)(
      'normalizes "$raw" to "$normalized"',
      ({ raw, normalized }) => {
        const result = validateImei(raw);
        expect(result.ok).toBe(true);
        if (result.ok) {
          expect(result.value).toBe(normalized);
        }
      },
    );
  });

  // ─── IMEI_REQUIRED ──────────────────────────────────────────────────────

  describe('IMEI_REQUIRED', () => {
    it.each(INVALID_REQUIRED)(
      'returns IMEI_REQUIRED for $description',
      ({ raw }) => {
        const result = validateImei(raw as any);
        expect(result.ok).toBe(false);
        if (!result.ok) {
          expect(result.error.code).toBe('IMEI_REQUIRED');
        }
      },
    );
  });

  // ─── IMEI_INVALID_CHARACTERS ────────────────────────────────────────────

  describe('IMEI_INVALID_CHARACTERS', () => {
    it.each(INVALID_CHARACTERS)(
      'returns IMEI_INVALID_CHARACTERS for $description',
      ({ raw }) => {
        const result = validateImei(raw);
        expect(result.ok).toBe(false);
        if (!result.ok) {
          expect(result.error.code).toBe('IMEI_INVALID_CHARACTERS');
        }
      },
    );
  });

  // ─── IMEI_INVALID_LENGTH ────────────────────────────────────────────────

  describe('IMEI_INVALID_LENGTH', () => {
    it.each(INVALID_LENGTH)(
      'returns IMEI_INVALID_LENGTH for $description',
      ({ raw }) => {
        const result = validateImei(raw);
        expect(result.ok).toBe(false);
        if (!result.ok) {
          expect(result.error.code).toBe('IMEI_INVALID_LENGTH');
        }
      },
    );
  });

  // ─── IMEI_INVALID_CHECKSUM ──────────────────────────────────────────────

  describe('IMEI_INVALID_CHECKSUM', () => {
    it.each(INVALID_CHECKSUM)(
      'returns IMEI_INVALID_CHECKSUM for $description',
      ({ raw }) => {
        const result = validateImei(raw);
        expect(result.ok).toBe(false);
        if (!result.ok) {
          expect(result.error.code).toBe('IMEI_INVALID_CHECKSUM');
        }
      },
    );
  });

  // ─── Edge Cases ─────────────────────────────────────────────────────────

  describe('edge cases', () => {
    it.each(EDGE_CASE_VALID)('passes for $description', ({ raw }) => {
      const result = validateImei(raw);
      expect(result.ok).toBe(true);
    });

    it.each(EDGE_CASE_INVALID)(
      'returns $expected for $description',
      ({ raw, expected }) => {
        const result = validateImei(raw);
        expect(result.ok).toBe(false);
        if (!result.ok) {
          expect(result.error.code).toBe(expected);
        }
      },
    );
  });

  // ─── Validation Precedence ──────────────────────────────────────────────

  describe('validation precedence', () => {
    it('checks required before characters (empty → IMEI_REQUIRED, not INVALID_CHARACTERS)', () => {
      const result = validateImei('');
      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.error.code).toBe('IMEI_REQUIRED');
      }
    });

    it('checks characters before length (non-digit short → IMEI_INVALID_CHARACTERS)', () => {
      // 5 chars with letters — should fail on characters, not length
      const result = validateImei('ABCDE');
      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.error.code).toBe('IMEI_INVALID_CHARACTERS');
      }
    });

    it('checks length before Luhn (14-digit number → IMEI_INVALID_LENGTH, not checksum)', () => {
      const result = validateImei('49015420323751'); // 14 digits
      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.error.code).toBe('IMEI_INVALID_LENGTH');
      }
    });
  });

  // ─── Field Association ──────────────────────────────────────────────────

  describe('field association', () => {
    it('always associates errors with "imei" field', () => {
      const cases = [
        validateImei(null),
        validateImei('ABCDE'),
        validateImei('1234'),
        validateImei('490154203237519'), // bad checksum
      ];
      for (const result of cases) {
        expect(result.ok).toBe(false);
        if (!result.ok) {
          expect(result.error.field).toBe('imei');
        }
      }
    });
  });
});
