/**
 * Unit tests for Code Quality Score Calculation and Diff-Based Classification
 *
 * Tests calculateQualityScore() and classifyViolations() functions.
 * Requirements: 13.5, 13.6, 13.7, 13.8
 */

import {
  calculateQualityScore,
  classifyViolations,
  QualityViolation,
  QualityScore,
  ViolationClassification,
} from './code_quality';

// ─── calculateQualityScore() Tests ──────────────────────────────────────────

describe('calculateQualityScore', () => {
  it('should calculate equally-weighted average of three metrics', () => {
    const result = calculateQualityScore({
      testCoverage: 60,
      validation: 80,
      responsive: 100,
      module: 'billing',
    });

    expect(result.module).toBe('billing');
    expect(result.testCoveragePercent).toBe(60);
    expect(result.validationPercent).toBe(80);
    expect(result.responsivePercent).toBe(100);
    expect(result.overallScore).toBe(80); // (60 + 80 + 100) / 3 = 80
  });

  it('should return 0 when all metrics are 0', () => {
    const result = calculateQualityScore({
      testCoverage: 0,
      validation: 0,
      responsive: 0,
      module: 'empty',
    });

    expect(result.overallScore).toBe(0);
  });

  it('should return 100 when all metrics are 100', () => {
    const result = calculateQualityScore({
      testCoverage: 100,
      validation: 100,
      responsive: 100,
      module: 'perfect',
    });

    expect(result.overallScore).toBe(100);
  });

  it('should clamp metrics above 100 to 100', () => {
    const result = calculateQualityScore({
      testCoverage: 150,
      validation: 200,
      responsive: 100,
      module: 'overflow',
    });

    expect(result.testCoveragePercent).toBe(100);
    expect(result.validationPercent).toBe(100);
    expect(result.responsivePercent).toBe(100);
    expect(result.overallScore).toBe(100);
  });

  it('should clamp metrics below 0 to 0', () => {
    const result = calculateQualityScore({
      testCoverage: -10,
      validation: -20,
      responsive: 0,
      module: 'underflow',
    });

    expect(result.testCoveragePercent).toBe(0);
    expect(result.validationPercent).toBe(0);
    expect(result.responsivePercent).toBe(0);
    expect(result.overallScore).toBe(0);
  });

  it('should handle fractional percentages', () => {
    const result = calculateQualityScore({
      testCoverage: 33.33,
      validation: 66.66,
      responsive: 50,
      module: 'restaurant',
    });

    expect(result.testCoveragePercent).toBe(33.33);
    expect(result.validationPercent).toBe(66.66);
    expect(result.responsivePercent).toBe(50);
    // (33.33 + 66.66 + 50) / 3 = 49.996666...
    expect(result.overallScore).toBeCloseTo(49.997, 2);
  });
});

// ─── classifyViolations() Tests ─────────────────────────────────────────────

describe('classifyViolations', () => {
  const sampleDiff = `diff --git a/src/handlers/billing.ts b/src/handlers/billing.ts
index abc1234..def5678 100644
--- a/src/handlers/billing.ts
+++ b/src/handlers/billing.ts
@@ -10,6 +10,8 @@ import { z } from 'zod';
 
 const schema = z.object({
   name: z.string(),
+  email: z.string().email(),
+  phone: z.any(),
   amount: z.number(),
 });
 
@@ -25,3 +27,5 @@ export async function handler(event: any) {
   const result = await repo.create(data);
   return { statusCode: 200, body: JSON.stringify(result) };
 }
+
+export const helper: any = {};
`;

  it('should classify violations on added lines as blocking', () => {
    const violations: QualityViolation[] = [
      {
        rule: 'typescript-strict-no-any',
        file: 'src/handlers/billing.ts',
        line: 14, // phone: z.any() — added line at new line 14
        description: '`any` type usage',
        isBlocking: true,
      },
    ];

    const result = classifyViolations(violations, sampleDiff);

    expect(result).toHaveLength(1);
    expect(result[0].classification).toBe('blocking');
    expect(result[0].reason).toContain('added');
  });

  it('should classify violations on unchanged lines as non-blocking', () => {
    const violations: QualityViolation[] = [
      {
        rule: 'typescript-strict-no-any',
        file: 'src/handlers/billing.ts',
        line: 12, // name: z.string() — context line
        description: '`any` type usage',
        isBlocking: true,
      },
    ];

    const result = classifyViolations(violations, sampleDiff);

    expect(result).toHaveLength(1);
    expect(result[0].classification).toBe('non-blocking');
    expect(result[0].reason).toContain('unchanged');
  });

  it('should classify violations in files not in diff as blocking (indeterminate)', () => {
    const violations: QualityViolation[] = [
      {
        rule: 'typescript-strict-no-any',
        file: 'src/handlers/other.ts',
        line: 5,
        description: '`any` type usage',
        isBlocking: true,
      },
    ];

    const result = classifyViolations(violations, sampleDiff);

    expect(result).toHaveLength(1);
    expect(result[0].classification).toBe('blocking');
    expect(result[0].reason).toContain('indeterminate');
  });

  it('should classify violations without line numbers as blocking (indeterminate)', () => {
    const violations: QualityViolation[] = [
      {
        rule: 'test-coverage-repository',
        file: 'src/handlers/billing.ts',
        description: 'Missing test file',
        isBlocking: true,
      },
    ];

    const result = classifyViolations(violations, sampleDiff);

    expect(result).toHaveLength(1);
    expect(result[0].classification).toBe('blocking');
    expect(result[0].reason).toContain('no line number');
  });

  it('should handle empty diff content — all violations are blocking', () => {
    const violations: QualityViolation[] = [
      {
        rule: 'typescript-strict-no-any',
        file: 'src/handlers/billing.ts',
        line: 5,
        description: '`any` type usage',
        isBlocking: true,
      },
    ];

    const result = classifyViolations(violations, '');

    expect(result).toHaveLength(1);
    expect(result[0].classification).toBe('blocking');
  });

  it('should handle multiple violations across different files', () => {
    const multiFileDiff = `diff --git a/src/a.ts b/src/a.ts
--- a/src/a.ts
+++ b/src/a.ts
@@ -1,3 +1,4 @@
 const x = 1;
+const y: any = 2;
 const z = 3;
 export {};
diff --git a/src/b.ts b/src/b.ts
--- a/src/b.ts
+++ b/src/b.ts
@@ -5,3 +5,4 @@
 function old() {}
+function added() {}
 export {};
`;

    const violations: QualityViolation[] = [
      { rule: 'r1', file: 'src/a.ts', line: 2, description: 'in added', isBlocking: true },
      { rule: 'r2', file: 'src/a.ts', line: 1, description: 'in context', isBlocking: true },
      { rule: 'r3', file: 'src/b.ts', line: 6, description: 'in added', isBlocking: true },
      { rule: 'r4', file: 'src/c.ts', line: 1, description: 'not in diff', isBlocking: true },
    ];

    const result = classifyViolations(violations, multiFileDiff);

    expect(result[0].classification).toBe('blocking');  // added line
    expect(result[1].classification).toBe('non-blocking');  // context line
    expect(result[2].classification).toBe('blocking');  // added line
    expect(result[3].classification).toBe('blocking');  // file not in diff
  });

  it('should handle Windows-style paths in violations vs Unix in diff', () => {
    const violations: QualityViolation[] = [
      {
        rule: 'typescript-strict-no-any',
        file: 'src\\handlers\\billing.ts',
        line: 14,
        description: '`any` type usage',
        isBlocking: true,
      },
    ];

    const result = classifyViolations(violations, sampleDiff);

    expect(result).toHaveLength(1);
    expect(result[0].classification).toBe('blocking');
    expect(result[0].reason).toContain('added');
  });

  it('should return empty array for empty violations list', () => {
    const result = classifyViolations([], sampleDiff);
    expect(result).toHaveLength(0);
  });
});
