/**
 * Triage Classifier - Priority Classification for Audit Issues
 *
 * Assigns priority levels (P0–P3) to discovered audit issues based on
 * issue type and severity rules. Implements highest-priority-wins logic
 * when multiple criteria could apply.
 *
 * Priority Rules:
 *   P0: tenant_leak (security/data-leak)
 *   P1: mock_data_production, broken_navigation, broken_api_dependency,
 *       dynamic_construction, repository_bypass (blocking user flow)
 *   P2: missing_offline_write, orphaned_route, scan_instead_of_query,
 *       inadequate_error_handling (degraded experience)
 *   P3: ui_inconsistency, missing_validation (cosmetic/enhancement)
 *   Default: P3 for unrecognized issue types
 */

import {
  AuditIssue,
  IssueType,
  PriorityLevel,
  TriageReport,
} from '../types';

/** Maps issue types to their assigned priority level */
const PRIORITY_MAP: Record<IssueType, PriorityLevel> = {
  tenant_leak: 'P0',
  mock_data_production: 'P1',
  broken_navigation: 'P1',
  broken_api_dependency: 'P1',
  dynamic_construction: 'P1',
  repository_bypass: 'P1',
  missing_offline_write: 'P2',
  orphaned_route: 'P2',
  scan_instead_of_query: 'P2',
  inadequate_error_handling: 'P2',
  ui_inconsistency: 'P3',
  missing_validation: 'P3',
};

/** Default priority for issues that don't match any specific criteria */
const DEFAULT_PRIORITY: PriorityLevel = 'P3';

/**
 * Classifies a single audit issue and returns the appropriate priority level.
 *
 * Lookup is based on the issue's `type` field against the priority map.
 * If the type is recognized, the mapped priority is returned.
 * If the type is not recognized, P3 is returned as the default.
 *
 * When an issue could conceptually match multiple criteria (e.g., a tenant_leak
 * that also involves broken_navigation), the issue's primary `type` determines
 * classification. The highest-priority-wins rule applies at the report level
 * when aggregating multiple issues for the same screen or handler.
 */
export function classify(issue: AuditIssue): PriorityLevel {
  const mapped = PRIORITY_MAP[issue.type];
  return mapped ?? DEFAULT_PRIORITY;
}

/**
 * Generates a triage summary report grouped by priority and vertical.
 *
 * For each issue:
 * 1. Calls classify() to assign/confirm the priority level
 * 2. Aggregates counts by priority and by vertical
 *
 * Returns a TriageReport with ISO8601 timestamp, totals, and the
 * classified issues array.
 */
export function generateReport(issues: AuditIssue[]): TriageReport {
  const byPriority: Record<PriorityLevel, number> = { P0: 0, P1: 0, P2: 0, P3: 0 };
  const byVertical: Record<string, Record<PriorityLevel, number>> = {};

  const classifiedIssues: AuditIssue[] = issues.map((issue) => {
    const priority = classify(issue);
    return { ...issue, priority };
  });

  for (const issue of classifiedIssues) {
    // Increment overall priority count
    byPriority[issue.priority]++;

    // Ensure vertical entry exists
    if (!byVertical[issue.vertical]) {
      byVertical[issue.vertical] = { P0: 0, P1: 0, P2: 0, P3: 0 };
    }

    // Increment per-vertical priority count
    byVertical[issue.vertical][issue.priority]++;
  }

  return {
    generatedAt: new Date().toISOString(),
    totalIssues: classifiedIssues.length,
    byPriority,
    byVertical,
    issues: classifiedIssues,
  };
}

/** Exported classifier object matching the TriageClassifier interface */
export const triageClassifier = {
  classify,
  generateReport,
};

export { PRIORITY_MAP, DEFAULT_PRIORITY };
