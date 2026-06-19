/**
 * Shared TypeScript interfaces and types for the Full-Stack Audit and Remediation System.
 *
 * This module defines all shared types used across the audit pipeline:
 * Discover → Analyze → Triage → Remediate → Validate → Track
 */

// ─── Enums & Literal Types ────────────────────────────────────────────────────

/** Priority levels for triaged issues (P0 = most severe) */
export type PriorityLevel = 'P0' | 'P1' | 'P2' | 'P3';

/** Screen remediation status in the progress tracker state machine */
export type ScreenStatus =
  | 'Not Started'
  | 'In Progress'
  | 'Remediated'
  | 'Validated'
  | 'Blocked';

/** Classification of audit issue types across the platform */
export type IssueType =
  | 'tenant_leak'
  | 'mock_data_production'
  | 'broken_navigation'
  | 'missing_offline_write'
  | 'ui_inconsistency'
  | 'orphaned_route'
  | 'broken_api_dependency'
  | 'missing_validation'
  | 'inadequate_error_handling'
  | 'scan_instead_of_query'
  | 'dynamic_construction'
  | 'repository_bypass';

// ─── Status State Machine ─────────────────────────────────────────────────────

/**
 * Valid status transitions for the remediation progress tracker.
 *
 * Transitions:
 * - Not Started → In Progress
 * - In Progress → Remediated | Blocked
 * - Blocked → In Progress
 * - Remediated → Validated
 * - Validated → Remediated (regression detected)
 */
export const VALID_TRANSITIONS: Record<ScreenStatus, ScreenStatus[]> = {
  'Not Started': ['In Progress'],
  'In Progress': ['Remediated', 'Blocked'],
  'Blocked': ['In Progress'],
  'Remediated': ['Validated'],
  'Validated': ['Remediated'],
};

// ─── Core Audit Interfaces ────────────────────────────────────────────────────

/** A single audit issue discovered by the Audit Engine */
export interface AuditIssue {
  /** Unique issue identifier */
  id: string;
  /** Classification of the issue */
  type: IssueType;
  /** Assigned severity level */
  priority: PriorityLevel;
  /** Business vertical this issue belongs to */
  vertical: string;
  /** Screen name if the issue is screen-specific */
  screenName?: string;
  /** Handler name if the issue is handler-specific */
  handlerName?: string;
  /** Human-readable description of the issue */
  description: string;
  /** Source code location where the issue was detected */
  location: {
    file: string;
    line?: number;
    column?: number;
  };
  /** ISO8601 timestamp when the issue was first detected */
  detectedAt: string;
  /** ISO8601 timestamp when the issue was resolved */
  resolvedAt?: string;
  /** Whether this issue blocks new code from merging */
  isBlocking: boolean;
  /** Additional context-specific metadata */
  metadata?: Record<string, unknown>;
}

// ─── API Surface Mapper Interfaces ────────────────────────────────────────────

/** A backend API route parsed from serverless.yml or template.yaml */
export interface Route {
  /** HTTP method (GET, POST, PUT, DELETE, PATCH) */
  method: string;
  /** Original route path as defined in config */
  path: string;
  /** Path with parameters replaced by wildcards for matching */
  normalizedPath: string;
  /** File path of the Lambda handler */
  handlerFile: string;
  /** Whether the route requires authentication */
  authenticated: boolean;
  /** Source configuration file */
  source: 'serverless.yml' | 'template.yaml';
}

/** An HTTP request call site found in Flutter code */
export interface CallSite {
  /** Flutter source file containing the HTTP call */
  screenFile: string;
  /** The request path used in the HTTP call */
  requestPath: string;
  /** Path with parameters replaced by wildcards for matching */
  normalizedPath: string;
  /** HTTP method used in the call */
  httpMethod: string;
  /** Line number in the source file */
  lineNumber: number;
}

/** Result of matching call sites to backend routes */
export interface MatchResult {
  /** Successfully matched call site → route pairs */
  matched: Array<{ callSite: CallSite; route: Route }>;
  /** Call sites with no matching backend route (P1) */
  brokenDependencies: CallSite[];
  /** Routes with no matching call site (P2) */
  orphanedRoutes: Route[];
}

// ─── DynamoDB Analyzer Interfaces ─────────────────────────────────────────────

/** A DynamoDB operation extracted from a Lambda handler */
export interface DynamoDbOperation {
  /** Type of DynamoDB operation */
  type: 'get' | 'put' | 'query' | 'scan' | 'update' | 'delete';
  /** Target DynamoDB table name */
  tableName: string;
  /** Key condition expression (for query operations) */
  keyCondition: string;
  /** Filter expression applied to results */
  filterExpression: string;
  /** Source handler file path */
  handlerFile: string;
  /** Line number where the operation is defined */
  lineNumber: number;
  /** Whether table name or key is dynamically constructed */
  isDynamic: boolean;
}

// ─── Progress Tracker Interfaces ──────────────────────────────────────────────

/** Result of a status transition attempt */
export interface TransitionResult {
  /** Whether the transition was successful */
  success: boolean;
  /** Error message if the transition was rejected */
  error?: string;
  /** Status before the transition attempt */
  previousStatus?: ScreenStatus;
  /** New status after a successful transition */
  newStatus?: ScreenStatus;
  /** ISO8601 timestamp of the transition */
  timestamp?: string;
}

/** Summary of remediation progress across the platform */
export interface ProgressSummary {
  /** Total number of screens in the registry */
  totalScreens: number;
  /** Count of screens per status */
  byStatus: Record<ScreenStatus, number>;
  /** Per-vertical breakdown with totals and status counts */
  byVertical: Record<string, { total: number; byStatus: Record<ScreenStatus, number> }>;
  /** Overall platform readiness: (Validated / Total) × 100, rounded to 1 decimal */
  readinessPercentage: number;
}

// ─── Triage Report Interfaces ─────────────────────────────────────────────────

/** Summary report generated after triage classification */
export interface TriageReport {
  /** ISO8601 timestamp when the report was generated */
  generatedAt: string;
  /** Total number of issues in this report */
  totalIssues: number;
  /** Count of issues per priority level */
  byPriority: Record<PriorityLevel, number>;
  /** Per-vertical breakdown by priority */
  byVertical: Record<string, Record<PriorityLevel, number>>;
  /** All issues included in this report */
  issues: AuditIssue[];
}
