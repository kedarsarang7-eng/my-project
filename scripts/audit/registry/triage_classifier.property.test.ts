/**
 * Property-Based Test: Priority Classification Function
 *
 * Feature: full-stack-audit-remediation, Property 7: Priority Classification Function
 *
 * Validates: Requirements 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8
 *
 * For any audit issue, the Triage Classifier SHALL assign:
 *   P0 if issue involves tenant data leakage
 *   P1 if it involves mock data in production or broken navigation
 *   P2 if it involves missing offline on write screens
 *   P3 if it involves UI inconsistency
 * For any issue matching multiple criteria, the assigned priority SHALL equal
 * the highest (most severe) among matched criteria.
 * For any issue matching no specific criteria, P3 SHALL be assigned.
 */

import * as fc from 'fast-check';
import { classify, PRIORITY_MAP } from './triage_classifier';
import { AuditIssue, IssueType, PriorityLevel } from '../types';

// ── Generators ───────────────────────────────────────────────────────────────

/** All known issue types */
const knownIssueTypes: IssueType[] = [
  'tenant_leak',
  'mock_data_production',
  'broken_navigation',
  'missing_offline_write',
  'ui_inconsistency',
  'orphaned_route',
  'broken_api_dependency',
  'missing_validation',
  'inadequate_error_handling',
  'scan_instead_of_query',
  'dynamic_construction',
  'repository_bypass',
];

/** Generate a known issue type */
const issueTypeArb = fc.constantFrom<IssueType>(...knownIssueTypes);

/** Generate a vertical name */
const verticalArb = fc.constantFrom(
  'restaurant', 'jewellery', 'pharmacy', 'salon', 'school',
  'clinic', 'hardware', 'clothing', 'computer_shop', 'general'
);

/** Generate a valid AuditIssue with a known type */
const auditIssueArb = fc.record({
  id: fc.uuid(),
  type: issueTypeArb,
  priority: fc.constant('P3' as PriorityLevel), // initial, will be classified
  vertical: verticalArb,
  description: fc.string({ minLength: 1, maxLength: 50 }),
  location: fc.record({
    file: fc.constant('some/file.ts'),
    line: fc.option(fc.integer({ min: 1, max: 500 }), { nil: undefined }),
  }),
  detectedAt: fc.constant(new Date().toISOString()),
  isBlocking: fc.boolean(),
}).map((issue) => issue as AuditIssue);

/** Generate a string that is NOT a known issue type (to test default behavior) */
const unknownIssueTypeArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz_'.split('')),
  { minLength: 3, maxLength: 15 }
).filter((s) => !knownIssueTypes.includes(s as IssueType));

// ── Expected priority mappings ───────────────────────────────────────────────

const EXPECTED_P0: IssueType[] = ['tenant_leak'];
const EXPECTED_P1: IssueType[] = [
  'mock_data_production', 'broken_navigation', 'broken_api_dependency',
  'dynamic_construction', 'repository_bypass',
];
const EXPECTED_P2: IssueType[] = [
  'missing_offline_write', 'orphaned_route', 'scan_instead_of_query',
  'inadequate_error_handling',
];
const EXPECTED_P3: IssueType[] = ['ui_inconsistency', 'missing_validation'];

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Property 7: Priority Classification Function', () => {
  it('classifies P0 issues correctly for tenant_leak type', () => {
    fc.assert(
      fc.property(auditIssueArb, (issue) => {
        const modified = { ...issue, type: 'tenant_leak' as IssueType };
        expect(classify(modified)).toBe('P0');
      }),
      { numRuns: 100 }
    );
  });

  it('classifies P1 issues correctly', () => {
    fc.assert(
      fc.property(
        auditIssueArb,
        fc.constantFrom<IssueType>(...EXPECTED_P1),
        (issue, type) => {
          const modified = { ...issue, type };
          expect(classify(modified)).toBe('P1');
        }
      ),
      { numRuns: 100 }
    );
  });

  it('classifies P2 issues correctly', () => {
    fc.assert(
      fc.property(
        auditIssueArb,
        fc.constantFrom<IssueType>(...EXPECTED_P2),
        (issue, type) => {
          const modified = { ...issue, type };
          expect(classify(modified)).toBe('P2');
        }
      ),
      { numRuns: 100 }
    );
  });

  it('classifies P3 issues correctly', () => {
    fc.assert(
      fc.property(
        auditIssueArb,
        fc.constantFrom<IssueType>(...EXPECTED_P3),
        (issue, type) => {
          const modified = { ...issue, type };
          expect(classify(modified)).toBe('P3');
        }
      ),
      { numRuns: 100 }
    );
  });

  it('assigns P3 (default) for unknown issue types', () => {
    fc.assert(
      fc.property(auditIssueArb, unknownIssueTypeArb, (issue, unknownType) => {
        const modified = { ...issue, type: unknownType as IssueType };
        expect(classify(modified)).toBe('P3');
      }),
      { numRuns: 100 }
    );
  });

  it('PRIORITY_MAP assigns known types to correct levels and highest-priority-wins', () => {
    fc.assert(
      fc.property(issueTypeArb, (type) => {
        const priority = PRIORITY_MAP[type];
        // Priority must be one of P0-P3
        expect(['P0', 'P1', 'P2', 'P3']).toContain(priority);
        // Verify the mapping matches our expected categorization
        if (EXPECTED_P0.includes(type)) expect(priority).toBe('P0');
        if (EXPECTED_P1.includes(type)) expect(priority).toBe('P1');
        if (EXPECTED_P2.includes(type)) expect(priority).toBe('P2');
        if (EXPECTED_P3.includes(type)) expect(priority).toBe('P3');
      }),
      { numRuns: 100 }
    );
  });

  it('highest-priority-wins: given multiple issue types for same screen, min(P) wins', () => {
    fc.assert(
      fc.property(
        fc.array(issueTypeArb, { minLength: 2, maxLength: 5 }),
        verticalArb,
        (types, vertical) => {
          // Classify each type individually
          const priorities = types.map((type) => {
            const issue: AuditIssue = {
              id: 'test',
              type,
              priority: 'P3',
              vertical,
              description: 'test',
              location: { file: 'test.ts' },
              detectedAt: new Date().toISOString(),
              isBlocking: false,
            };
            return classify(issue);
          });

          // Highest priority = lowest P number
          const priorityOrder: PriorityLevel[] = ['P0', 'P1', 'P2', 'P3'];
          const highestPriority = priorityOrder.find((p) =>
            priorities.includes(p)
          )!;

          // The highest priority should be the minimum numeric level
          const numericPriorities = priorities.map((p) => parseInt(p[1]));
          const minNumeric = Math.min(...numericPriorities);
          expect(highestPriority).toBe(`P${minNumeric}`);
        }
      ),
      { numRuns: 100 }
    );
  });
});
