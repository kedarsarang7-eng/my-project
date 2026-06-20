/**
 * CI Pipeline Integration — Audit Entry Point
 *
 * Orchestrates all audit checks for the CI pipeline and returns pass/fail:
 * 1. Mock data detection on non-test Dart files (fail if new patterns found)
 * 2. TypeScript strict check for `any` usage (blocking for new code per diff)
 * 3. Flutter analysis violations (blocking/non-blocking per diff)
 * 4. Repository bypass deployment gate (fail if bypasses detected)
 *
 * Requirements: 6.5, 13.1, 13.6, 13.7, 13.8, 9.6
 */

import * as fs from 'fs';
import * as path from 'path';
import {
  checkTypeScriptStrict,
  checkFlutterAnalysis,
  classifyViolations,
  QualityViolation,
} from '../analyzers/code_quality';
import {
  enforceDeploymentGate,
  TenantBypassViolation,
} from '../remediation/tenant_enforcer';

// ─── Public Interfaces ──────────────────────────────────────────────────────

export interface CiResult {
  /** Whether the overall CI audit passed (no blocking violations) */
  passed: boolean;
  /** Violations that block the pipeline */
  blockingViolations: CiViolation[];
  /** Violations logged for backlog but don't block */
  nonBlockingViolations: CiViolation[];
  /** Human-readable summary of the audit run */
  summary: string;
}

export interface CiViolation {
  /** Rule or check that was violated */
  rule: string;
  /** File where the violation occurred */
  file: string;
  /** Line number (1-indexed) if available */
  line?: number;
  /** Description of the violation */
  description: string;
  /** Whether this violation blocks the pipeline */
  isBlocking: boolean;
}

// ─── Mock Data Detection (Dart) ─────────────────────────────────────────────

/** Directories excluded from mock data CI checks */
const MOCK_EXCLUDED_DIRECTORIES = [
  'test',
  'test_driver',
  'integration_test',
  'mocks',
];

/** File suffixes excluded from mock data CI checks */
const MOCK_EXCLUDED_SUFFIXES = ['_test.dart', '_mock.dart', '_fake.dart'];

/** Patterns indicating mock data in Dart files */
const MOCK_DATA_PATTERNS: Array<{ pattern: RegExp; label: string }> = [
  {
    pattern: /\[\s*\{[^}]+\}\s*,\s*\{/,
    label: 'Hardcoded data array with 2+ object entries',
  },
  {
    pattern: /\[\s*'[^']+',\s*'[^']+'/,
    label: 'Hardcoded string array with 2+ entries',
  },
  {
    pattern: /\[\s*"[^"]+",\s*"[^"]+"/,
    label: 'Hardcoded string array with 2+ entries',
  },
  {
    pattern:
      /\/\/\s*(?:TODO|FIXME|HACK).*(?:fake|mock|dummy|placeholder|sample|hardcode)/i,
    label: 'TODO/placeholder comment indicating fake data',
  },
  {
    pattern: /\/\/\s*(?:placeholder|dummy data|sample data)/i,
    label: 'Placeholder comment indicating mock data',
  },
  {
    pattern: /import\s+['"].*(?:mock|dummy|fake|sample).*['"]/,
    label: 'Import from mock/dummy/fake/sample path',
  },
  {
    pattern: /import\s+['"].*\/mocks\/.*['"]/,
    label: 'Import from mocks directory',
  },
  {
    pattern: /return\s+\[\s*\{/,
    label: 'Inline literal object array return',
  },
  {
    pattern: /return\s+\[\s*['"]/,
    label: 'Inline literal string array return',
  },
];

/**
 * Checks if a file path is excluded from CI mock data checks.
 * Excludes test directories and test file suffixes.
 */
function isExcludedFromMockCheck(filePath: string): boolean {
  const normalized = filePath.replace(/\\/g, '/');

  for (const dir of MOCK_EXCLUDED_DIRECTORIES) {
    if (normalized.includes(`/${dir}/`) || normalized.startsWith(`${dir}/`)) {
      return true;
    }
  }

  for (const suffix of MOCK_EXCLUDED_SUFFIXES) {
    if (normalized.endsWith(suffix)) {
      return true;
    }
  }

  return false;
}

/**
 * Recursively collects all Dart files under a directory.
 * Excludes build, .dart_tool, and test directories.
 */
function collectDartFilesForMockCheck(dir: string): string[] {
  const files: string[] = [];

  if (!fs.existsSync(dir)) {
    return files;
  }

  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      if (
        entry.name === 'build' ||
        entry.name === '.dart_tool' ||
        entry.name === 'node_modules' ||
        entry.name.startsWith('.')
      ) {
        continue;
      }
      files.push(...collectDartFilesForMockCheck(fullPath));
    } else if (entry.isFile() && entry.name.endsWith('.dart')) {
      files.push(fullPath);
    }
  }

  return files;
}

/**
 * Detects mock data patterns in non-test Dart files.
 * Returns violations for any new mock patterns found in production code.
 *
 * Requirement 6.5: CI assertion that fails pipeline if any new mock data
 * pattern is introduced in files outside test directories.
 */
function detectMockDataViolations(flutterRoot: string): CiViolation[] {
  const violations: CiViolation[] = [];

  if (!flutterRoot || !fs.existsSync(flutterRoot)) {
    return violations;
  }

  const libDir = path.join(flutterRoot, 'lib');
  if (!fs.existsSync(libDir)) {
    return violations;
  }

  const dartFiles = collectDartFilesForMockCheck(libDir);

  for (const filePath of dartFiles) {
    if (isExcludedFromMockCheck(filePath)) {
      continue;
    }

    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Skip comment-only lines for array/return patterns
      const trimmed = line.trim();
      if (trimmed.startsWith('//') && !MOCK_DATA_PATTERNS.some(
        (p) => p.label.includes('TODO') || p.label.includes('placeholder')
      )) {
        // Allow TODO/placeholder detection on comment lines
      }

      for (const { pattern, label } of MOCK_DATA_PATTERNS) {
        if (pattern.test(line)) {
          violations.push({
            rule: 'mock-data-free',
            file: filePath,
            line: i + 1,
            description: label,
            isBlocking: true,
          });
          break; // One violation per line
        }
      }
    }
  }

  return violations;
}

// ─── TypeScript `any` Detection ─────────────────────────────────────────────

/**
 * Detects TypeScript `any` usage and classifies as blocking/non-blocking
 * based on diff content.
 *
 * - New code (in diff added lines): blocking — must be fixed before merge
 * - Existing code (unchanged): non-blocking — added to remediation backlog
 * - Indeterminate: treated as blocking (Req 13.8)
 *
 * Requirements: 13.1, 13.6, 13.7, 13.8
 */
function detectTypeScriptAnyViolations(
  handlersDir: string,
  diffContent?: string
): CiViolation[] {
  if (!handlersDir || !fs.existsSync(handlersDir)) {
    return [];
  }

  const rawViolations = checkTypeScriptStrict(handlersDir);

  if (!diffContent || diffContent.trim().length === 0) {
    // No diff available — all violations are blocking (Req 13.8)
    return rawViolations.map((v) => ({
      rule: v.rule,
      file: v.file,
      line: v.line,
      description: v.description,
      isBlocking: true,
    }));
  }

  // Classify violations based on diff
  const classified = classifyViolations(rawViolations, diffContent);

  return classified.map((c) => ({
    rule: c.violation.rule,
    file: c.violation.file,
    line: c.violation.line,
    description: `${c.violation.description} (${c.reason})`,
    isBlocking: c.classification === 'blocking',
  }));
}

// ─── Flutter Analysis Violations ────────────────────────────────────────────

/**
 * Runs Flutter analysis violation checks and classifies as blocking/non-blocking
 * based on diff content.
 *
 * - Violations in new code (diff added lines): blocking
 * - Violations in existing code (unchanged): non-blocking (backlog)
 * - Indeterminate: blocking (Req 13.8)
 *
 * Requirements: 13.6, 13.7, 13.8
 */
function detectFlutterAnalysisViolations(
  flutterRoot: string,
  diffContent?: string
): CiViolation[] {
  if (!flutterRoot || !fs.existsSync(flutterRoot)) {
    return [];
  }

  const rawViolations = checkFlutterAnalysis(flutterRoot);

  if (!diffContent || diffContent.trim().length === 0) {
    // No diff available — all violations are blocking (Req 13.8)
    return rawViolations.map((v) => ({
      rule: v.rule,
      file: v.file,
      line: v.line,
      description: v.description,
      isBlocking: true,
    }));
  }

  // Classify violations based on diff
  const classified = classifyViolations(rawViolations, diffContent);

  return classified.map((c) => ({
    rule: c.violation.rule,
    file: c.violation.file,
    line: c.violation.line,
    description: `${c.violation.description} (${c.reason})`,
    isBlocking: c.classification === 'blocking',
  }));
}

// ─── Deployment Gate: Repository Bypass Detection ───────────────────────────

/**
 * Runs the deployment gate to detect repository bypasses.
 * Any bypass detection results in a blocking violation that fails the pipeline.
 *
 * Requirement 9.6: Deployment-time static analysis that verifies no raw
 * DynamoDB client call bypasses the tenant-scoped repository methods.
 */
function detectRepositoryBypassViolations(handlersDir: string): CiViolation[] {
  if (!handlersDir || !fs.existsSync(handlersDir)) {
    return [];
  }

  const gateResult = enforceDeploymentGate(handlersDir);

  return gateResult.violations.map((v: TenantBypassViolation) => ({
    rule: 'repository-bypass-deployment-gate',
    file: v.handlerFile,
    line: v.lineNumber,
    description: `${v.description} — ${v.callLocation}`,
    isBlocking: true,
  }));
}

// ─── Main CI Audit Orchestrator ─────────────────────────────────────────────

/**
 * Runs the full CI audit pipeline orchestrating all checks.
 *
 * The function:
 * 1. Runs mock data detection on non-test Dart files (fail if new patterns)
 * 2. Runs TypeScript strict check for `any` usage (blocking for new code per diff)
 * 3. Runs Flutter analysis violations (blocking/non-blocking per diff)
 * 4. Runs repository bypass deployment gate (fail if bypasses detected)
 * 5. Aggregates results and returns pass/fail
 *
 * @param options - Configuration for the CI audit run
 * @returns CiResult with pass/fail status and all violations
 */
export function runCiAudit(options: {
  projectRoot: string;
  diffContent?: string;
  handlersDir?: string;
  flutterRoot?: string;
}): CiResult {
  const {
    projectRoot,
    diffContent,
    handlersDir = path.join(projectRoot, 'my-backend', 'src', 'handlers'),
    flutterRoot = path.join(projectRoot, 'Dukan_x'),
  } = options;

  const allViolations: CiViolation[] = [];

  // Step 1: Mock data detection in non-test Dart files (Req 6.5)
  const mockViolations = detectMockDataViolations(flutterRoot);
  allViolations.push(...mockViolations);

  // Step 2: TypeScript `any` detection (Req 13.1, 13.6, 13.7, 13.8)
  const anyViolations = detectTypeScriptAnyViolations(handlersDir, diffContent);
  allViolations.push(...anyViolations);

  // Step 3: Flutter analysis violations (Req 13.6, 13.7, 13.8)
  const flutterViolations = detectFlutterAnalysisViolations(
    flutterRoot,
    diffContent
  );
  allViolations.push(...flutterViolations);

  // Step 4: Repository bypass deployment gate (Req 9.6)
  const bypassViolations = detectRepositoryBypassViolations(handlersDir);
  allViolations.push(...bypassViolations);

  // Separate blocking from non-blocking
  const blockingViolations = allViolations.filter((v) => v.isBlocking);
  const nonBlockingViolations = allViolations.filter((v) => !v.isBlocking);

  // Pipeline passes only if there are zero blocking violations
  const passed = blockingViolations.length === 0;

  // Build summary
  const summary = buildSummary(
    passed,
    mockViolations,
    anyViolations,
    flutterViolations,
    bypassViolations,
    blockingViolations,
    nonBlockingViolations
  );

  return {
    passed,
    blockingViolations,
    nonBlockingViolations,
    summary,
  };
}

// ─── Summary Builder ────────────────────────────────────────────────────────

function buildSummary(
  passed: boolean,
  mockViolations: CiViolation[],
  anyViolations: CiViolation[],
  flutterViolations: CiViolation[],
  bypassViolations: CiViolation[],
  blockingViolations: CiViolation[],
  nonBlockingViolations: CiViolation[]
): string {
  const lines: string[] = [];

  lines.push(`CI Audit ${passed ? 'PASSED ✓' : 'FAILED ✗'}`);
  lines.push('─'.repeat(50));
  lines.push('');
  lines.push('Check Results:');
  lines.push(
    `  Mock Data Detection:       ${mockViolations.length === 0 ? '✓ pass' : `✗ ${mockViolations.length} violation(s)`}`
  );
  lines.push(
    `  TypeScript any Detection:  ${anyViolations.filter((v) => v.isBlocking).length === 0 ? '✓ pass' : `✗ ${anyViolations.filter((v) => v.isBlocking).length} blocking`}${anyViolations.filter((v) => !v.isBlocking).length > 0 ? ` (${anyViolations.filter((v) => !v.isBlocking).length} backlog)` : ''}`
  );
  lines.push(
    `  Flutter Analysis:          ${flutterViolations.filter((v) => v.isBlocking).length === 0 ? '✓ pass' : `✗ ${flutterViolations.filter((v) => v.isBlocking).length} blocking`}${flutterViolations.filter((v) => !v.isBlocking).length > 0 ? ` (${flutterViolations.filter((v) => !v.isBlocking).length} backlog)` : ''}`
  );
  lines.push(
    `  Repository Bypass Gate:    ${bypassViolations.length === 0 ? '✓ pass' : `✗ ${bypassViolations.length} bypass(es)`}`
  );
  lines.push('');
  lines.push(
    `Total: ${blockingViolations.length} blocking, ${nonBlockingViolations.length} non-blocking`
  );

  if (!passed) {
    lines.push('');
    lines.push('Blocking violations must be resolved before merge.');
  }

  return lines.join('\n');
}

// ─── Exported Utilities (for testing) ───────────────────────────────────────

export {
  detectMockDataViolations,
  detectTypeScriptAnyViolations,
  detectFlutterAnalysisViolations,
  detectRepositoryBypassViolations,
  isExcludedFromMockCheck,
};
