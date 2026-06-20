/**
 * Tenant Enforcer — Repository-Layer Enforcement and Deployment Gate
 *
 * Ensures all DynamoDB operations are accessible only through tenant-scoped
 * repository methods. Implements deployment-time static analysis to detect
 * raw DynamoDB client calls bypassing the repository layer.
 *
 * When a bypass is detected, deployment is failed and the violating handler
 * name and call location are reported.
 *
 * Requirements: 9.5, 9.6
 */

import * as fs from 'fs';
import * as path from 'path';

// ─── Interfaces ─────────────────────────────────────────────────────────────

export interface TenantBypassViolation {
  /** Path to the handler file containing the violation */
  handlerFile: string;
  /** Line number where the bypass was detected (1-indexed) */
  lineNumber: number;
  /** Description of the call location (e.g., function name or context) */
  callLocation: string;
  /** Human-readable description of the violation */
  description: string;
}

export interface DeploymentGateResult {
  /** Whether the deployment gate passed (no violations) */
  pass: boolean;
  /** List of detected violations */
  violations: TenantBypassViolation[];
}

// ─── Detection Patterns ─────────────────────────────────────────────────────

/** Patterns indicating direct DynamoDB client usage (bypassing repository) */
const DIRECT_DYNAMODB_PATTERNS: Array<{ pattern: RegExp; label: string }> = [
  { pattern: /new\s+DynamoDBClient\s*\(/, label: 'DynamoDBClient instantiation' },
  { pattern: /new\s+DynamoDB\s*\(/, label: 'DynamoDB instantiation' },
  { pattern: /new\s+DynamoDB\.DocumentClient\s*\(/, label: 'DynamoDB.DocumentClient instantiation' },
  { pattern: /DynamoDBDocumentClient\.from\s*\(/, label: 'DynamoDBDocumentClient.from() call' },
  { pattern: /docClient\.send\s*\(/, label: 'docClient.send() call' },
  { pattern: /dynamoClient\.send\s*\(/, label: 'dynamoClient.send() call' },
  { pattern: /ddbClient\.send\s*\(/, label: 'ddbClient.send() call' },
  { pattern: /client\.send\s*\(/, label: 'client.send() call' },
  { pattern: /new\s+GetItemCommand\s*\(/, label: 'GetItemCommand usage' },
  { pattern: /new\s+PutItemCommand\s*\(/, label: 'PutItemCommand usage' },
  { pattern: /new\s+QueryCommand\s*\(/, label: 'QueryCommand usage' },
  { pattern: /new\s+ScanCommand\s*\(/, label: 'ScanCommand usage' },
  { pattern: /new\s+UpdateItemCommand\s*\(/, label: 'UpdateItemCommand usage' },
  { pattern: /new\s+DeleteItemCommand\s*\(/, label: 'DeleteItemCommand usage' },
  { pattern: /new\s+GetCommand\s*\(/, label: 'GetCommand usage' },
  { pattern: /new\s+PutCommand\s*\(/, label: 'PutCommand usage' },
  { pattern: /new\s+UpdateCommand\s*\(/, label: 'UpdateCommand usage' },
  { pattern: /new\s+DeleteCommand\s*\(/, label: 'DeleteCommand usage' },
  { pattern: /new\s+BatchGetItemCommand\s*\(/, label: 'BatchGetItemCommand usage' },
  { pattern: /new\s+BatchWriteItemCommand\s*\(/, label: 'BatchWriteItemCommand usage' },
];

/** Patterns indicating this file IS a repository (exempt from bypass detection) */
const REPOSITORY_FILE_PATTERNS = [
  /class\s+\w+Repository\b/,
  /export\s+(?:class|const|function)\s+\w*[Rr]epository\b/,
  /\/\*\*[\s\S]*?[Rr]epository[\s\S]*?\*\//,
];

// ─── Public API ─────────────────────────────────────────────────────────────

/**
 * Scans handler files for direct DynamoDB client usage that bypasses
 * the tenant-scoped repository layer. Logs each detected bypass with
 * the handler name and call location.
 *
 * @param handlersDir - Path to the handlers directory to scan
 * @returns Array of violations detected across all handler files
 */
export function detectRepositoryBypasses(handlersDir: string): TenantBypassViolation[] {
  const violations: TenantBypassViolation[] = [];
  const files = collectHandlerFiles(handlersDir);

  for (const filePath of files) {
    const content = fs.readFileSync(filePath, 'utf-8');

    // Skip repository implementation files — they are allowed direct access
    if (isRepositoryFile(content)) {
      continue;
    }

    const lines = content.split('\n');
    const fileViolations = scanFileForBypasses(filePath, content, lines);

    // Log all detected bypasses with handler name and call location (Req 9.6)
    for (const violation of fileViolations) {
      console.warn(
        `[tenant_enforcer] BYPASS DETECTED: ${violation.description} — handler: ${path.basename(violation.handlerFile)}, location: ${violation.callLocation}`
      );
    }

    violations.push(...fileViolations);
  }

  return violations;
}

/**
 * Deployment gate that fails if any repository bypass is detected.
 * Intended to be called during CI/CD pipeline before deployment.
 * Logs a summary of all violations before returning the result.
 *
 * @param handlersDir - Path to the handlers directory to scan
 * @returns Object with pass/fail status and any detected violations
 */
export function enforceDeploymentGate(handlersDir: string): DeploymentGateResult {
  const violations = detectRepositoryBypasses(handlersDir);

  if (violations.length > 0) {
    console.error(
      `[tenant_enforcer] DEPLOYMENT GATE FAILED: ${violations.length} repository bypass violation(s) detected`
    );
    for (const v of violations) {
      console.error(
        `[tenant_enforcer]   ✗ ${path.basename(v.handlerFile)}:${v.lineNumber} — ${v.callLocation} — ${v.description}`
      );
    }
  }

  return {
    pass: violations.length === 0,
    violations,
  };
}

// ─── Internal Helpers ───────────────────────────────────────────────────────

/**
 * Scans a single file for DynamoDB bypass violations.
 */
function scanFileForBypasses(
  filePath: string,
  content: string,
  lines: string[],
): TenantBypassViolation[] {
  const violations: TenantBypassViolation[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Skip import/require lines — they declare dependencies, not operations
    if (isImportLine(line)) {
      continue;
    }

    // Skip comment lines
    if (isCommentLine(line)) {
      continue;
    }

    for (const { pattern, label } of DIRECT_DYNAMODB_PATTERNS) {
      if (!pattern.test(line)) {
        continue;
      }

      const callLocation = resolveCallLocation(lines, i, filePath);

      violations.push({
        handlerFile: filePath,
        lineNumber: i + 1,
        callLocation,
        description: `Direct DynamoDB access detected (${label}) — must use tenant-scoped repository methods`,
      });

      // One violation per line to avoid duplicates
      break;
    }
  }

  return violations;
}

/**
 * Recursively collects all TypeScript handler files from a directory.
 * Excludes test files, declaration files, and node_modules.
 */
function collectHandlerFiles(dir: string): string[] {
  const files: string[] = [];

  if (!fs.existsSync(dir)) {
    return files;
  }

  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      if (entry.name === 'node_modules' || entry.name === '__tests__') {
        continue;
      }
      files.push(...collectHandlerFiles(fullPath));
    } else if (
      entry.isFile() &&
      entry.name.endsWith('.ts') &&
      !entry.name.endsWith('.test.ts') &&
      !entry.name.endsWith('.spec.ts') &&
      !entry.name.endsWith('.d.ts')
    ) {
      files.push(fullPath);
    }
  }

  return files;
}

/**
 * Checks if the file is a repository implementation file.
 * Repository files are allowed direct DynamoDB access since they
 * are the authorized layer for tenant-scoped operations.
 */
function isRepositoryFile(content: string): boolean {
  // Check the first 500 chars for doc comment mentioning repository
  const header = content.slice(0, 500);

  return REPOSITORY_FILE_PATTERNS.some((pattern) => pattern.test(content)) ||
    /\/\*\*[\s\S]*?[Rr]epository[\s\S]*?\*\//.test(header);
}

/**
 * Checks if a line is an import or require statement.
 */
function isImportLine(line: string): boolean {
  const trimmed = line.trim();
  return (
    trimmed.startsWith('import ') ||
    trimmed.startsWith('import{') ||
    (trimmed.startsWith('const ') && /require\s*\(/.test(trimmed)) ||
    trimmed.startsWith('export { ') ||
    trimmed.startsWith('export {')
  );
}

/**
 * Checks if a line is a comment (single-line or part of multi-line).
 */
function isCommentLine(line: string): boolean {
  const trimmed = line.trim();
  return (
    trimmed.startsWith('//') ||
    trimmed.startsWith('*') ||
    trimmed.startsWith('/*')
  );
}

/**
 * Resolves the call location context for a violation by finding the
 * enclosing function or handler name.
 *
 * Searches backwards from the violation line to find the closest
 * function/method/handler declaration.
 */
function resolveCallLocation(lines: string[], violationLine: number, filePath: string): string {
  // Search backwards for the enclosing function/handler declaration
  for (let i = violationLine; i >= 0; i--) {
    const line = lines[i];

    // Match common handler/function declaration patterns
    const functionMatch = line.match(
      /(?:export\s+)?(?:async\s+)?function\s+(\w+)/
    );
    if (functionMatch) {
      return `${functionMatch[1]}() in ${path.basename(filePath)}:${violationLine + 1}`;
    }

    // Match arrow function assignments: export const handler = async (...) =>
    const arrowMatch = line.match(
      /(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\(/
    );
    if (arrowMatch) {
      return `${arrowMatch[1]}() in ${path.basename(filePath)}:${violationLine + 1}`;
    }

    // Match class method declarations
    const methodMatch = line.match(
      /(?:async\s+)?(\w+)\s*\([^)]*\)\s*(?::\s*\w+)?\s*\{/
    );
    if (methodMatch && !line.includes('if') && !line.includes('for') && !line.includes('while')) {
      return `${methodMatch[1]}() in ${path.basename(filePath)}:${violationLine + 1}`;
    }
  }

  // Fallback: use file name and line number
  return `${path.basename(filePath)}:${violationLine + 1}`;
}
