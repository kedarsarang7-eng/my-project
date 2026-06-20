/**
 * Property Test: Diff-Based Violation Classification
 *
 * Feature: full-stack-audit-remediation, Property 18: Diff-Based Violation Classification
 *
 * Validates: Requirements 13.6, 13.7, 13.8
 *
 * For any code violation and for any commit diff context:
 * - If the violation's file + line appears in the diff's added lines → blocking
 * - If the violation's file is in the diff but the line is unchanged → non-blocking
 * - If the classification cannot be determined (file not in diff, no line info) → blocking (default)
 */

import * as fc from 'fast-check';
import { classifyViolations, QualityViolation } from './code_quality';

// ─── Generators ──────────────────────────────────────────────────────────────

/** Generates a realistic file path */
const filePathArb = fc.tuple(
  fc.constantFrom('src/handlers/', 'src/services/', 'src/utils/', 'lib/features/'),
  fc.stringMatching(/^[a-z][a-z0-9_-]{2,15}$/),
  fc.constantFrom('.ts', '.js')
).map(([dir, name, ext]) => `${dir}${name}${ext}`);

/** Generates a violation rule name */
const ruleArb = fc.constantFrom(
  'typescript-strict-no-any',
  'performance-sync-dynamodb',
  'performance-unbounded-scan',
  'performance-loop-db-call',
  'flutter-unused-import',
  'flutter-prefer-const'
);

/** Generates a violation description */
const descriptionArb = fc.constantFrom(
  '`any` type usage without justification comment',
  'Synchronous DynamoDB call detected',
  'Scan without Limit parameter',
  'Database call inside loop',
  'Unused import detected',
  'Prefer const constructor'
);

/** Generates a positive line number */
const lineNumberArb = fc.integer({ min: 1, max: 500 });

/** Generates a QualityViolation with a specific file and line */
function violationArb(file: string, line: number): fc.Arbitrary<QualityViolation> {
  return fc.tuple(ruleArb, descriptionArb).map(([rule, description]) => ({
    rule,
    file,
    line,
    description,
    isBlocking: true, // initial classification (will be reclassified by diff analysis)
  }));
}

/**
 * Builds a unified diff string where the specified file has certain lines added.
 * This simulates `git diff` output format.
 */
function buildUnifiedDiff(file: string, addedLines: number[], contextStartLine: number): string {
  if (addedLines.length === 0) {
    // File is in diff but no added lines (e.g., only deletions or context)
    const lines = [
      `diff --git a/${file} b/${file}`,
      `--- a/${file}`,
      `+++ b/${file}`,
      `@@ -${contextStartLine},5 +${contextStartLine},5 @@`,
      ` unchanged context line 1`,
      ` unchanged context line 2`,
      ` unchanged context line 3`,
      ` unchanged context line 4`,
      ` unchanged context line 5`,
    ];
    return lines.join('\n');
  }

  // Build diff with added lines at the specified positions
  const sortedLines = [...addedLines].sort((a, b) => a - b);
  const minLine = sortedLines[0];

  const diffLines = [
    `diff --git a/${file} b/${file}`,
    `--- a/${file}`,
    `+++ b/${file}`,
    `@@ -${minLine},3 +${minLine},${sortedLines.length + 3} @@`,
  ];

  let currentNewLine = minLine;
  for (const addedLine of sortedLines) {
    // Add context lines before the added line
    while (currentNewLine < addedLine) {
      diffLines.push(` context line at ${currentNewLine}`);
      currentNewLine++;
    }
    // Add the added line
    diffLines.push(`+added content at line ${addedLine}`);
    currentNewLine++;
  }

  // Add trailing context
  diffLines.push(` trailing context`);

  return diffLines.join('\n');
}

// ─── Property Tests ──────────────────────────────────────────────────────────

describe('Feature: full-stack-audit-remediation, Property 18: Diff-Based Violation Classification', () => {
  describe('Violations in added lines are blocking', () => {
    it('should classify as blocking when violation line is in diff added lines', () => {
      fc.assert(
        fc.property(
          filePathArb,
          lineNumberArb,
          ruleArb,
          descriptionArb,
          (file, line, rule, description) => {
            const violation: QualityViolation = {
              rule,
              file,
              line,
              description,
              isBlocking: true,
            };

            // Build diff where the violation's line is explicitly added
            const diff = buildUnifiedDiff(file, [line], line);

            const results = classifyViolations([violation], diff);

            expect(results).toHaveLength(1);
            expect(results[0].classification).toBe('blocking');
            expect(results[0].reason).toContain('added');
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Violations in unchanged lines are non-blocking', () => {
    it('should classify as non-blocking when file is in diff but line is unchanged', () => {
      fc.assert(
        fc.property(
          filePathArb,
          fc.integer({ min: 50, max: 200 }),
          fc.integer({ min: 250, max: 400 }),
          ruleArb,
          descriptionArb,
          (file, violationLine, addedLine, rule, description) => {
            // Ensure violation line and added line are different
            const violation: QualityViolation = {
              rule,
              file,
              line: violationLine,
              description,
              isBlocking: true,
            };

            // Build diff where OTHER lines are added, but not the violation's line
            const diff = buildUnifiedDiff(file, [addedLine], addedLine);

            const results = classifyViolations([violation], diff);

            expect(results).toHaveLength(1);
            expect(results[0].classification).toBe('non-blocking');
            expect(results[0].reason).toContain('unchanged');
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Violations in files not in diff default to blocking', () => {
    it('should classify as blocking when file is not present in diff at all', () => {
      fc.assert(
        fc.property(
          filePathArb,
          lineNumberArb,
          ruleArb,
          descriptionArb,
          (file, line, rule, description) => {
            const violation: QualityViolation = {
              rule,
              file,
              line,
              description,
              isBlocking: true,
            };

            // Build diff for a DIFFERENT file
            const differentFile = 'src/completely/different-file.ts';
            const diff = buildUnifiedDiff(differentFile, [10, 20], 10);

            const results = classifyViolations([violation], diff);

            expect(results).toHaveLength(1);
            expect(results[0].classification).toBe('blocking');
            expect(results[0].reason).toContain('indeterminate');
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Violations without line numbers default to blocking', () => {
    it('should classify as blocking when violation has no line number', () => {
      fc.assert(
        fc.property(
          filePathArb,
          ruleArb,
          descriptionArb,
          fc.integer({ min: 1, max: 100 }),
          (file, rule, description, addedLine) => {
            const violation: QualityViolation = {
              rule,
              file,
              line: undefined,
              description,
              isBlocking: true,
            };

            // File IS in the diff, but violation has no line → indeterminate → blocking
            const diff = buildUnifiedDiff(file, [addedLine], addedLine);

            const results = classifyViolations([violation], diff);

            expect(results).toHaveLength(1);
            expect(results[0].classification).toBe('blocking');
            expect(results[0].reason).toContain('indeterminate');
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Empty diff classifies all violations as blocking', () => {
    it('should treat all violations as blocking when diff is empty', () => {
      fc.assert(
        fc.property(
          filePathArb,
          lineNumberArb,
          ruleArb,
          descriptionArb,
          (file, line, rule, description) => {
            const violation: QualityViolation = {
              rule,
              file,
              line,
              description,
              isBlocking: true,
            };

            const results = classifyViolations([violation], '');

            expect(results).toHaveLength(1);
            expect(results[0].classification).toBe('blocking');
          }
        ),
        { numRuns: 100 }
      );
    });
  });
});
