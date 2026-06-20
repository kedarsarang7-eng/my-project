/**
 * Property-Based Test: Code Quality Score Calculation
 *
 * Feature: full-stack-audit-remediation, Property 17: Code Quality Score Calculation
 *
 * Validates: Requirements 13.5
 *
 * For any set of feature module metrics (test coverage %, validation %,
 * responsive %), the quality score SHALL equal the equally-weighted average
 * of the three percentages, producing a value on the 0–100 scale.
 */

import * as fc from 'fast-check';
import { calculateQualityScore } from './code_quality';

// ── Generators ───────────────────────────────────────────────────────────────

/** Generate a percentage value in valid 0–100 range */
const validPercentArb = fc.double({ min: 0, max: 100, noNaN: true });

/** Generate a percentage value potentially outside 0–100 (for clamping test) */
const anyPercentArb = fc.double({ min: -50, max: 200, noNaN: true });

/** Generate a module name */
const moduleNameArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz-_'.split('')),
  { minLength: 3, maxLength: 20 }
);

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Property 17: Code Quality Score Calculation', () => {
  it('score equals equally-weighted average of three metrics (0–100 inputs)', () => {
    fc.assert(
      fc.property(
        validPercentArb,
        validPercentArb,
        validPercentArb,
        moduleNameArb,
        (testCoverage, validation, responsive, module) => {
          const result = calculateQualityScore({
            testCoverage,
            validation,
            responsive,
            module,
          });

          const expectedScore = (testCoverage + validation + responsive) / 3;

          // Allow floating point tolerance
          expect(result.overallScore).toBeCloseTo(expectedScore, 10);
          expect(result.module).toBe(module);
          expect(result.testCoveragePercent).toBeCloseTo(testCoverage, 10);
          expect(result.validationPercent).toBeCloseTo(validation, 10);
          expect(result.responsivePercent).toBeCloseTo(responsive, 10);
        }
      ),
      { numRuns: 100 }
    );
  });

  it('score is always within 0–100 range regardless of input values', () => {
    fc.assert(
      fc.property(
        anyPercentArb,
        anyPercentArb,
        anyPercentArb,
        moduleNameArb,
        (testCoverage, validation, responsive, module) => {
          const result = calculateQualityScore({
            testCoverage,
            validation,
            responsive,
            module,
          });

          // Overall score must be within [0, 100]
          expect(result.overallScore).toBeGreaterThanOrEqual(0);
          expect(result.overallScore).toBeLessThanOrEqual(100);
          // Individual percentages must be clamped to [0, 100]
          expect(result.testCoveragePercent).toBeGreaterThanOrEqual(0);
          expect(result.testCoveragePercent).toBeLessThanOrEqual(100);
          expect(result.validationPercent).toBeGreaterThanOrEqual(0);
          expect(result.validationPercent).toBeLessThanOrEqual(100);
          expect(result.responsivePercent).toBeGreaterThanOrEqual(0);
          expect(result.responsivePercent).toBeLessThanOrEqual(100);
        }
      ),
      { numRuns: 100 }
    );
  });

  it('score equals clamped average when inputs exceed valid range', () => {
    fc.assert(
      fc.property(
        anyPercentArb,
        anyPercentArb,
        anyPercentArb,
        moduleNameArb,
        (testCoverage, validation, responsive, module) => {
          const result = calculateQualityScore({
            testCoverage,
            validation,
            responsive,
            module,
          });

          // Manually clamp to compute expected
          const clamp = (v: number) => Math.max(0, Math.min(100, v));
          const clamped1 = clamp(testCoverage);
          const clamped2 = clamp(validation);
          const clamped3 = clamp(responsive);
          const expectedScore = (clamped1 + clamped2 + clamped3) / 3;

          expect(result.overallScore).toBeCloseTo(expectedScore, 10);
        }
      ),
      { numRuns: 100 }
    );
  });

  it('equal metrics produce score equal to any single metric', () => {
    fc.assert(
      fc.property(validPercentArb, moduleNameArb, (pct, module) => {
        const result = calculateQualityScore({
          testCoverage: pct,
          validation: pct,
          responsive: pct,
          module,
        });

        // If all three metrics are equal, the average is the same value
        expect(result.overallScore).toBeCloseTo(pct, 10);
      }),
      { numRuns: 100 }
    );
  });
});
