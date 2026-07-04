// ============================================================================
// WhatsApp Automation Module — Phone Service — Unit Tests (Task 5.1)
// ============================================================================
// Validates E.164 phone number validation logic including:
// - Valid numbers (8-15 digits after "+")
// - Rejection of invalid formats (missing "+", too short, too long, non-digits)
// - Whitespace trimming
// - Error messages indicating why validation failed
//
// Requirements: 2.1, 2.2, 11.4, 11.11
// ============================================================================

import {
  validateE164,
  isValidE164,
  normalizeE164OrThrow,
} from '../phone.service';

describe('phone.service', () => {
  // ── validateE164() ────────────────────────────────────────────────────────

  describe('validateE164()', () => {
    describe('valid numbers', () => {
      it('accepts a valid 10-digit number with country code (+91)', () => {
        const result = validateE164('+919876543210');
        expect(result.valid).toBe(true);
        expect(result.normalized).toBe('+919876543210');
        expect(result.error).toBeUndefined();
      });

      it('accepts minimum length (8 digits after "+")', () => {
        const result = validateE164('+12345678');
        expect(result.valid).toBe(true);
        expect(result.normalized).toBe('+12345678');
      });

      it('accepts maximum length (15 digits after "+")', () => {
        const result = validateE164('+123456789012345');
        expect(result.valid).toBe(true);
        expect(result.normalized).toBe('+123456789012345');
      });

      it('accepts a US number (+1 followed by 10 digits)', () => {
        const result = validateE164('+12025551234');
        expect(result.valid).toBe(true);
        expect(result.normalized).toBe('+12025551234');
      });

      it('accepts a UK number (+44)', () => {
        const result = validateE164('+447911123456');
        expect(result.valid).toBe(true);
        expect(result.normalized).toBe('+447911123456');
      });

      it('trims leading and trailing whitespace', () => {
        const result = validateE164('  +919876543210  ');
        expect(result.valid).toBe(true);
        expect(result.normalized).toBe('+919876543210');
      });
    });

    describe('invalid numbers', () => {
      it('rejects empty string', () => {
        const result = validateE164('');
        expect(result.valid).toBe(false);
        expect(result.error).toContain('must not be empty');
      });

      it('rejects whitespace-only string', () => {
        const result = validateE164('   ');
        expect(result.valid).toBe(false);
        expect(result.error).toContain('must not be empty');
      });

      it('rejects number without leading "+"', () => {
        const result = validateE164('919876543210');
        expect(result.valid).toBe(false);
        expect(result.error).toContain('must start with "+"');
      });

      it('rejects number that is too short (fewer than 8 digits)', () => {
        const result = validateE164('+1234567');
        expect(result.valid).toBe(false);
        expect(result.error).toContain('too short');
        expect(result.error).toContain('8');
      });

      it('rejects number that is too long (more than 15 digits)', () => {
        const result = validateE164('+1234567890123456');
        expect(result.valid).toBe(false);
        expect(result.error).toContain('too long');
        expect(result.error).toContain('15');
      });

      it('rejects number with spaces in between', () => {
        const result = validateE164('+91 987 654 3210');
        expect(result.valid).toBe(false);
        expect(result.error).toContain('invalid character');
      });

      it('rejects number with dashes', () => {
        const result = validateE164('+91-987-654-3210');
        expect(result.valid).toBe(false);
        expect(result.error).toContain('invalid character');
      });

      it('rejects number with parentheses', () => {
        const result = validateE164('+(91)9876543210');
        expect(result.valid).toBe(false);
        expect(result.error).toContain('invalid character');
      });

      it('rejects number with letters', () => {
        const result = validateE164('+91abc543210');
        expect(result.valid).toBe(false);
        expect(result.error).toContain('invalid character');
      });

      it('rejects "+" with no digits', () => {
        const result = validateE164('+');
        expect(result.valid).toBe(false);
        expect(result.error).toContain('too short');
      });

      it('rejects plain text', () => {
        const result = validateE164('not a number');
        expect(result.valid).toBe(false);
        expect(result.error).toContain('must start with "+"');
      });
    });
  });

  // ── isValidE164() ─────────────────────────────────────────────────────────

  describe('isValidE164()', () => {
    it('returns true for valid E.164 number', () => {
      expect(isValidE164('+919876543210')).toBe(true);
    });

    it('returns false for invalid number', () => {
      expect(isValidE164('919876543210')).toBe(false);
    });

    it('returns false for empty string', () => {
      expect(isValidE164('')).toBe(false);
    });
  });

  // ── normalizeE164OrThrow() ────────────────────────────────────────────────

  describe('normalizeE164OrThrow()', () => {
    it('returns normalized number for valid input', () => {
      expect(normalizeE164OrThrow('  +919876543210  ')).toBe('+919876543210');
    });

    it('throws with descriptive error for invalid input', () => {
      expect(() => normalizeE164OrThrow('919876543210')).toThrow(
        'must start with "+"',
      );
    });

    it('throws for too-short number', () => {
      expect(() => normalizeE164OrThrow('+123')).toThrow('too short');
    });

    it('throws for number with non-digit characters', () => {
      expect(() => normalizeE164OrThrow('+91-9876543210')).toThrow(
        'invalid character',
      );
    });
  });
});
