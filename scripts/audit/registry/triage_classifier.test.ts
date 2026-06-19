import { classify, generateReport, PRIORITY_MAP, DEFAULT_PRIORITY } from './triage_classifier';
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


describe('TriageClassifier.generateReport()', () => {
  it('returns a valid TriageReport for an empty issues array', () => {
    const report = generateReport([]);

    expect(report.totalIssues).toBe(0);
    expect(report.byPriority).toEqual({ P0: 0, P1: 0, P2: 0, P3: 0 });
    expect(report.byVertical).toEqual({});
    expect(report.issues).toEqual([]);
    expect(report.generatedAt).toBeDefined();
    // Should be valid ISO8601
    expect(new Date(report.generatedAt).toISOString()).toBe(report.generatedAt);
  });

  it('correctly counts total issues', () => {
    const issues = [
      makeIssue('tenant_leak', { vertical: 'restaurant' }),
      makeIssue('broken_navigation', { vertical: 'pharmacy' }),
      makeIssue('ui_inconsistency', { vertical: 'restaurant' }),
    ];

    const report = generateReport(issues);
    expect(report.totalIssues).toBe(3);
  });

  it('groups issues by priority level with correct counts', () => {
    const issues = [
      makeIssue('tenant_leak'),           // P0
      makeIssue('mock_data_production'),   // P1
      makeIssue('broken_navigation'),      // P1
      makeIssue('missing_offline_write'),  // P2
      makeIssue('ui_inconsistency'),       // P3
      makeIssue('missing_validation'),     // P3
    ];

    const report = generateReport(issues);

    expect(report.byPriority.P0).toBe(1);
    expect(report.byPriority.P1).toBe(2);
    expect(report.byPriority.P2).toBe(1);
    expect(report.byPriority.P3).toBe(2);
  });

  it('groups issues by vertical with per-priority counts', () => {
    const issues = [
      makeIssue('tenant_leak', { vertical: 'restaurant' }),         // P0
      makeIssue('broken_navigation', { vertical: 'restaurant' }),   // P1
      makeIssue('ui_inconsistency', { vertical: 'restaurant' }),    // P3
      makeIssue('mock_data_production', { vertical: 'pharmacy' }),   // P1
      makeIssue('missing_offline_write', { vertical: 'pharmacy' }), // P2
    ];

    const report = generateReport(issues);

    expect(report.byVertical['restaurant']).toEqual({ P0: 1, P1: 1, P2: 0, P3: 1 });
    expect(report.byVertical['pharmacy']).toEqual({ P0: 0, P1: 1, P2: 1, P3: 0 });
  });

  it('calls classify() on each issue to assign priority', () => {
    // Issue has incorrect priority initially; generateReport should re-classify
    const issue = makeIssue('tenant_leak', { priority: 'P3' as PriorityLevel });

    const report = generateReport([issue]);

    // After classification, tenant_leak should be P0
    expect(report.issues[0].priority).toBe('P0');
    expect(report.byPriority.P0).toBe(1);
    expect(report.byPriority.P3).toBe(0);
  });

  it('returns all issues in the report issues array', () => {
    const issues = [
      makeIssue('tenant_leak', { vertical: 'clinic', id: 'issue-1' }),
      makeIssue('orphaned_route', { vertical: 'jewellery', id: 'issue-2' }),
    ];

    const report = generateReport(issues);

    expect(report.issues).toHaveLength(2);
    expect(report.issues[0].id).toBe('issue-1');
    expect(report.issues[1].id).toBe('issue-2');
  });

  it('handles multiple verticals correctly', () => {
    const verticals = ['restaurant', 'pharmacy', 'clinic', 'jewellery', 'clothing'];
    const issues = verticals.map((v) => makeIssue('ui_inconsistency', { vertical: v }));

    const report = generateReport(issues);

    expect(Object.keys(report.byVertical)).toHaveLength(5);
    for (const v of verticals) {
      expect(report.byVertical[v]).toEqual({ P0: 0, P1: 0, P2: 0, P3: 1 });
    }
  });

  it('generatedAt is a valid ISO8601 timestamp', () => {
    const report = generateReport([makeIssue('tenant_leak')]);
    const parsed = new Date(report.generatedAt);

    expect(parsed.getTime()).not.toBeNaN();
    expect(report.generatedAt).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
  });
});
