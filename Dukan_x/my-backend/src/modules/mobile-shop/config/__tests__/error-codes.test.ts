/**
 * Error Code Contract Tests
 *
 * Verifies the deterministic error code catalog:
 * - Every error code has a unique code value
 * - Every error code has category, retryable flag, and description
 * - Deterministic outcomes include field association when applicable
 * - Validation errors include precedence ordering
 *
 * Requirements: 12.4, 14.1
 */

import { ERROR_CODES, type ErrorCode } from '../error-codes.config';
import { VALIDATION_CONFIG } from '../validation.config';

describe('Error Code Contracts', () => {
  const errorEntries = Object.entries(ERROR_CODES);

  describe('unique code values', () => {
    it('every error code has a unique code value', () => {
      const codes = errorEntries.map(([, entry]) => entry.code);
      const uniqueCodes = new Set(codes);
      expect(uniqueCodes.size).toBe(codes.length);
    });

    it('every key matches its own code field', () => {
      for (const [key, entry] of errorEntries) {
        expect(entry.code).toBe(key);
      }
    });
  });

  describe('required fields on every error code', () => {
    it.each(errorEntries)('%s has category', (_key, entry) => {
      expect(entry.category).toBeDefined();
      expect(typeof entry.category).toBe('string');
      expect(entry.category.length).toBeGreaterThan(0);
    });

    it.each(errorEntries)('%s has retryable flag', (_key, entry) => {
      expect(typeof entry.retryable).toBe('boolean');
    });

    it.each(errorEntries)('%s has description', (_key, entry) => {
      expect(entry.description).toBeDefined();
      expect(typeof entry.description).toBe('string');
      expect(entry.description.length).toBeGreaterThan(0);
    });

    it.each(errorEntries)('%s has httpStatus', (_key, entry) => {
      expect(typeof entry.httpStatus).toBe('number');
      expect(entry.httpStatus).toBeGreaterThanOrEqual(200);
      expect(entry.httpStatus).toBeLessThan(600);
    });

    it.each(errorEntries)('%s has recoveryAction', (_key, entry) => {
      expect(entry.recoveryAction).toBeDefined();
      expect(typeof entry.recoveryAction).toBe('string');
      expect(entry.recoveryAction.length).toBeGreaterThan(0);
    });
  });

  describe('field association for deterministic outcomes', () => {
    it('every error code has a fields array', () => {
      for (const [, entry] of errorEntries) {
        expect(Array.isArray(entry.fields)).toBe(true);
      }
    });

    it('validation errors with field association have non-empty fields', () => {
      const fieldSpecificErrors = errorEntries.filter(
        ([, entry]) => entry.category === 'validation' && entry.fields.length > 0,
      );
      expect(fieldSpecificErrors.length).toBeGreaterThan(0);
      for (const [, entry] of fieldSpecificErrors) {
        for (const field of entry.fields) {
          expect(typeof field).toBe('string');
          expect(field.length).toBeGreaterThan(0);
        }
      }
    });

    it('disclosesExistence is defined on every code', () => {
      for (const [, entry] of errorEntries) {
        expect(typeof entry.disclosesExistence).toBe('boolean');
      }
    });
  });

  describe('validation errors include precedence ordering', () => {
    it('IMEI validation rules have ascending priority', () => {
      const rules = VALIDATION_CONFIG.imeiValidation;
      expect(rules.length).toBeGreaterThan(0);
      for (let i = 1; i < rules.length; i++) {
        expect(rules[i].priority).toBeGreaterThan(rules[i - 1].priority);
      }
    });

    it('sale mutation rules have ascending priority', () => {
      const rules = VALIDATION_CONFIG.saleMutation;
      expect(rules.length).toBeGreaterThan(0);
      for (let i = 1; i < rules.length; i++) {
        expect(rules[i].priority).toBeGreaterThan(rules[i - 1].priority);
      }
    });

    it('second-hand intake rules have ascending priority', () => {
      const rules = VALIDATION_CONFIG.secondHandIntake;
      expect(rules.length).toBeGreaterThan(0);
      for (let i = 1; i < rules.length; i++) {
        expect(rules[i].priority).toBeGreaterThan(rules[i - 1].priority);
      }
    });

    it('service job rules have ascending priority', () => {
      const rules = VALIDATION_CONFIG.serviceJob;
      expect(rules.length).toBeGreaterThan(0);
      for (let i = 1; i < rules.length; i++) {
        expect(rules[i].priority).toBeGreaterThan(rules[i - 1].priority);
      }
    });

    it('every precedence rule has code, priority, description, and fields', () => {
      const allRules = [
        ...VALIDATION_CONFIG.imeiValidation,
        ...VALIDATION_CONFIG.saleMutation,
        ...VALIDATION_CONFIG.secondHandIntake,
        ...VALIDATION_CONFIG.serviceJob,
      ];
      for (const rule of allRules) {
        expect(typeof rule.code).toBe('string');
        expect(rule.code.length).toBeGreaterThan(0);
        expect(typeof rule.priority).toBe('number');
        expect(typeof rule.description).toBe('string');
        expect(rule.description.length).toBeGreaterThan(0);
        expect(Array.isArray(rule.fields)).toBe(true);
      }
    });
  });
});
