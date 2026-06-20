/**
 * Property-Based Test: Tenant ID Format Validation
 *
 * Feature: full-stack-audit-remediation, Property 12: Tenant ID Format Validation
 *
 * Validates: Requirements 9.2
 *
 * For any string presented as a tenant ID, the validation function SHALL
 * accept it if and only if it is non-empty, at most 128 characters, and
 * contains only characters matching [a-zA-Z0-9_-]. Strings failing
 * validation SHALL result in HTTP 403 rejection.
 */

import * as fc from 'fast-check';
import { validateTenantIdFormat, extractTenantId } from '../tenant-isolation';

// Mock the logger to prevent console output during tests
jest.mock('../../utils/logger', () => ({
  logger: {
    debug: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

// ── Generators ───────────────────────────────────────────────────────────────

/** Characters allowed in tenant IDs */
const VALID_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';

/** Generate a valid tenant ID: non-empty, 1–128 chars, only [a-zA-Z0-9_-] */
const validTenantIdArb = fc.stringOf(
  fc.constantFrom(...VALID_CHARS.split('')),
  { minLength: 1, maxLength: 128 }
);

/** Generate a string that is too long (>128 chars) but uses valid characters */
const tooLongTenantIdArb = fc.stringOf(
  fc.constantFrom(...VALID_CHARS.split('')),
  { minLength: 129, maxLength: 200 }
);

/** Generate a non-empty string that contains at least one invalid character */
const invalidCharTenantIdArb = fc
  .tuple(
    fc.stringOf(fc.constantFrom(...VALID_CHARS.split('')), { minLength: 0, maxLength: 50 }),
    fc.constantFrom(
      ' ', '.', '@', '/', '\\', '#', '$', '%', '^', '&', '*', '(', ')',
      '+', '=', '[', ']', '{', '}', '|', '~', '`', '<', '>', ',', ';',
      ':', '!', '?', '"', "'", '\n', '\t', '\r'
    ),
    fc.stringOf(fc.constantFrom(...VALID_CHARS.split('')), { minLength: 0, maxLength: 50 }),
  )
  .map(([prefix, invalidChar, suffix]) => prefix + invalidChar + suffix)
  .filter((s) => s.length > 0 && s.length <= 128);

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Property 12: Tenant ID Format Validation', () => {
  describe('validateTenantIdFormat', () => {
    it('accepts valid tenant IDs (non-empty, ≤128, [a-zA-Z0-9_-]+)', () => {
      fc.assert(
        fc.property(validTenantIdArb, (tenantId) => {
          expect(validateTenantIdFormat(tenantId)).toBe(true);
        }),
        { numRuns: 100 }
      );
    });

    it('rejects empty strings', () => {
      expect(validateTenantIdFormat('')).toBe(false);
    });

    it('rejects strings longer than 128 characters', () => {
      fc.assert(
        fc.property(tooLongTenantIdArb, (tenantId) => {
          expect(validateTenantIdFormat(tenantId)).toBe(false);
        }),
        { numRuns: 100 }
      );
    });

    it('rejects strings containing invalid characters', () => {
      fc.assert(
        fc.property(invalidCharTenantIdArb, (tenantId) => {
          expect(validateTenantIdFormat(tenantId)).toBe(false);
        }),
        { numRuns: 100 }
      );
    });

    it('acceptance IFF non-empty AND ≤128 AND matches [a-zA-Z0-9_-]+', () => {
      fc.assert(
        fc.property(
          fc.string({ minLength: 0, maxLength: 200 }),
          (input) => {
            const isValid = validateTenantIdFormat(input);
            const pattern = /^[a-zA-Z0-9_-]{1,128}$/;
            const shouldBeValid = pattern.test(input);

            expect(isValid).toBe(shouldBeValid);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('extractTenantId — 403 rejection for invalid formats', () => {
    it('valid tenant IDs in JWT claims result in successful extraction', () => {
      fc.assert(
        fc.property(validTenantIdArb, (tenantId) => {
          const event = {
            requestContext: {
              authorizer: {
                claims: { 'custom:tenantId': tenantId },
              },
            },
          };

          const result = extractTenantId(event);
          expect(result.valid).toBe(true);
          expect(result.tenantId).toBe(tenantId);
        }),
        { numRuns: 100 }
      );
    });

    it('invalid tenant IDs in JWT claims result in rejection (403)', () => {
      fc.assert(
        fc.property(invalidCharTenantIdArb, (tenantId) => {
          const event = {
            requestContext: {
              authorizer: {
                claims: { 'custom:tenantId': tenantId },
              },
            },
          };

          const result = extractTenantId(event);
          expect(result.valid).toBe(false);
          expect(result.error).toBeDefined();
        }),
        { numRuns: 100 }
      );
    });

    it('too-long tenant IDs result in rejection (403)', () => {
      fc.assert(
        fc.property(tooLongTenantIdArb, (tenantId) => {
          const event = {
            requestContext: {
              authorizer: {
                claims: { 'custom:tenantId': tenantId },
              },
            },
          };

          const result = extractTenantId(event);
          expect(result.valid).toBe(false);
          expect(result.error).toBeDefined();
        }),
        { numRuns: 100 }
      );
    });

    it('absent authorizer results in rejection (403)', () => {
      const result = extractTenantId({});
      expect(result.valid).toBe(false);
      expect(result.error).toBeDefined();
    });
  });
});
