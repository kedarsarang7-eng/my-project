import { classify, PRIORITY_MAP, DEFAULT_PRIORITY } from './triage_classifier';
import { AuditIssue, IssueType, PriorityLevel } from '../types';

/** Helper to create a minimal AuditIssue for testing */
function makeIssue(type: IssueType, overrides?: Partial<AuditIssue>): AuditIssue {
  return {
    id: `test-${type}-001`,
    type,
    priority: 'P3', // will be overridden by classify
    vertical: 'restaurant',
    description: `Test issue of type ${type}`,
    location: { file: 'src/handlers/test.ts', line: 10 },
    detectedAt: new Date().toISOString(),
    isBlocking: false,
    ...overrides,
  };
}

describe('TriageClassifier.classify()', () => {
  describe('P0 classification', () => {
    it('classifies tenant_leak as P0', () => {
      const issue = makeIssue('tenant_leak');
      expect(classify(issue)).toBe('P0');
    });
  });

  describe('P1 classification', () => {
    const p1Types: IssueType[] = [
      'mock_data_production',
      'broken_navigation',
      'broken_api_dependency',
      'dynamic_construction',
      'repository_bypass',
    ];

    it.each(p1Types)('classifies %s as P1', (type) => {
      const issue = makeIssue(type);
      expect(classify(issue)).toBe('P1');
    });
  });

  describe('P2 classification', () => {
    const p2Types: IssueType[] = [
      'missing_offline_write',
      'orphaned_route',
      'scan_instead_of_query',
      'inadequate_error_handling',
    ];

    it.each(p2Types)('classifies %s as P2', (type) => {
      const issue = makeIssue(type);
      expect(classify(issue)).toBe('P2');
    });
  });

  describe('P3 classification', () => {
    const p3Types: IssueType[] = [
      'ui_inconsistency',
      'missing_validation',
    ];

    it.each(p3Types)('classifies %s as P3', (type) => {
      const issue = makeIssue(type);
      expect(classify(issue)).toBe('P3');
    });
  });

  describe('default classification', () => {
    it('defaults to P3 for an unrecognized issue type', () => {
      // Force an unknown type through type assertion for testing defaults
      const issue = makeIssue('ui_inconsistency');
      (issue as { type: string }).type = 'unknown_type';
      expect(classify(issue)).toBe('P3');
    });
  });

  describe('highest-priority-wins semantics', () => {
    it('PRIORITY_MAP covers all defined IssueType values', () => {
      const allTypes: IssueType[] = [
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

      for (const type of allTypes) {
        expect(PRIORITY_MAP[type]).toBeDefined();
      }
    });

    it('P0 is the highest priority in the map', () => {
      const priorities = Object.values(PRIORITY_MAP);
      const hasP0 = priorities.includes('P0');
      expect(hasP0).toBe(true);
    });

    it('when selecting the highest priority among multiple issues, P0 wins', () => {
      const issues = [
        makeIssue('ui_inconsistency'),    // P3
        makeIssue('broken_navigation'),    // P1
        makeIssue('tenant_leak'),          // P0
        makeIssue('missing_offline_write'),// P2
      ];

      const priorityOrder: PriorityLevel[] = ['P0', 'P1', 'P2', 'P3'];
      const classified = issues.map((i) => classify(i));
      const highestIdx = Math.min(...classified.map((p) => priorityOrder.indexOf(p)));
      const highest = priorityOrder[highestIdx];

      expect(highest).toBe('P0');
    });

    it('when selecting the highest priority among P1 and P2 issues, P1 wins', () => {
      const issues = [
        makeIssue('orphaned_route'),         // P2
        makeIssue('mock_data_production'),    // P1
        makeIssue('missing_offline_write'),   // P2
      ];

      const priorityOrder: PriorityLevel[] = ['P0', 'P1', 'P2', 'P3'];
      const classified = issues.map((i) => classify(i));
      const highestIdx = Math.min(...classified.map((p) => priorityOrder.indexOf(p)));
      const highest = priorityOrder[highestIdx];

      expect(highest).toBe('P1');
    });
  });
});
