/**
 * Lambda Handler Auditor
 *
 * Reviews Lambda handler files for production-readiness compliance:
 * - Input validation (Zod/schema library usage)
 * - Structured error responses with correlation IDs
 * - Correct HTTP status codes
 * - Request/response logging
 * - Batch operation opportunities (2+ DynamoDB ops on same table)
 * - Inadequate catch blocks (neither re-throw, error response, nor logging)
 * - Direct DynamoDB client usage bypassing repository layer
 * - Sensitive data in log statements
 *
 * Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7
 */

import * as fs from 'fs';
import * as path from 'path';

// ─── Interfaces ─────────────────────────────────────────────────────────────

export interface LambdaViolation {
  /** Violation type identifier */
  type:
    | 'missing_validation'
    | 'missing_correlation_id'
    | 'incorrect_status_code'
    | 'missing_logging'
    | 'inadequate_catch'
    | 'batch_opportunity'
    | 'repository_bypass'
    | 'sensitive_data_logged';
  /** Human-readable description of the violation */
  description: string;
  /** Line number where the violation occurs (1-indexed) */
  lineNumber: number;
  /** Severity level */
  severity: 'P1' | 'P2';
}

export interface LambdaAuditResult {
  /** Path to the handler file */
  handlerFile: string;
  /** List of violations detected */
  violations: LambdaViolation[];
}

// ─── Detection Patterns ─────────────────────────────────────────────────────

/** Patterns indicating input validation library usage */
const VALIDATION_PATTERNS = [
  /\bz\.object\b/,
  /\bz\.string\b/,
  /\bz\.number\b/,
  /\bz\.array\b/,
  /\bz\.enum\b/,
  /\bz\.union\b/,
  /\bz\.intersection\b/,
  /\bz\.parse\b/,
  /\bz\.safeParse\b/,
  /from\s+['"]zod['"]/,
  /require\s*\(\s*['"]zod['"]\s*\)/,
  /\bschema\b.*\bvalidate\b/i,
  /\bvalidate\b.*\bschema\b/i,
  /\bJoi\b/,
  /from\s+['"]joi['"]/,
  /from\s+['"]yup['"]/,
  /\w+Schema\.validate\s*\(/,
  /\w+Schema\.parse\s*\(/,
  /schema\.parse\s*\(/,
  /schema\.validate\s*\(/,
];

/** Patterns indicating logging library usage */
const LOGGING_PATTERNS = [
  /\bconsole\.log\b/,
  /\bconsole\.info\b/,
  /\bconsole\.warn\b/,
  /\bconsole\.error\b/,
  /\blogger\.\w+\b/,
  /\blog\.\w+\b/,
  /from\s+['"].*logger['"]/,
  /from\s+['"].*logging['"]/,
  /from\s+['"]pino['"]/,
  /from\s+['"]winston['"]/,
  /from\s+['"]bunyan['"]/,
];

/** Patterns indicating correlation ID in error responses */
const CORRELATION_ID_PATTERNS = [
  /correlationId/,
  /correlation_id/,
  /requestId/,
  /request_id/,
  /traceId/,
  /trace_id/,
];

/** Patterns indicating direct DynamoDB client usage (bypassing repository) */
const DIRECT_DYNAMODB_PATTERNS = [
  /new\s+DynamoDBClient\s*\(/,
  /new\s+DynamoDB\s*\(/,
  /new\s+DynamoDB\.DocumentClient\s*\(/,
  /DynamoDBDocumentClient\.from\s*\(/,
  /docClient\.send\s*\(/,
  /dynamoClient\.send\s*\(/,
  /ddbClient\.send\s*\(/,
  /client\.send\s*\(/,
  /new\s+GetItemCommand\s*\(/,
  /new\s+PutItemCommand\s*\(/,
  /new\s+QueryCommand\s*\(/,
  /new\s+ScanCommand\s*\(/,
  /new\s+UpdateItemCommand\s*\(/,
  /new\s+DeleteItemCommand\s*\(/,
  /new\s+GetCommand\s*\(/,
  /new\s+PutCommand\s*\(/,
  /new\s+UpdateCommand\s*\(/,
  /new\s+DeleteCommand\s*\(/,
  /new\s+BatchGetItemCommand\s*\(/,
  /new\s+BatchWriteItemCommand\s*\(/,
];

/** Patterns indicating repository layer usage (safe DynamoDB access) */
const REPOSITORY_PATTERNS = [
  /from\s+['"].*repository['"]/i,
  /from\s+['"].*repo['"]/i,
  /Repository\b/,
  /repository\./,
  /repo\./,
];

/** Sensitive data patterns in log statements */
const SENSITIVE_DATA_PATTERNS = [
  { pattern: /password/i, label: 'password' },
  { pattern: /passwd/i, label: 'password' },
  { pattern: /secret/i, label: 'secret' },
  { pattern: /token/i, label: 'token' },
  { pattern: /refreshToken/i, label: 'refresh token' },
  { pattern: /refresh_token/i, label: 'refresh token' },
  { pattern: /accessToken/i, label: 'access token' },
  { pattern: /access_token/i, label: 'access token' },
  { pattern: /apiKey/i, label: 'API key' },
  { pattern: /api_key/i, label: 'API key' },
  { pattern: /email/i, label: 'email address' },
  { pattern: /phone/i, label: 'phone number' },
  { pattern: /phoneNumber/i, label: 'phone number' },
  { pattern: /phone_number/i, label: 'phone number' },
  { pattern: /\bssn\b/i, label: 'government ID (SSN)' },
  { pattern: /\baadhaar\b/i, label: 'government ID (Aadhaar)' },
  { pattern: /\bpan\b/i, label: 'government ID (PAN)' },
  { pattern: /socialSecurity/i, label: 'government ID' },
  { pattern: /social_security/i, label: 'government ID' },
  { pattern: /governmentId/i, label: 'government ID' },
  { pattern: /government_id/i, label: 'government ID' },
];

/** DynamoDB operation command names for batch opportunity detection */
const DYNAMODB_OPS_FOR_BATCH: Record<string, string> = {
  GetItemCommand: 'read',
  GetCommand: 'read',
  PutItemCommand: 'write',
  PutCommand: 'write',
  QueryCommand: 'read',
  UpdateItemCommand: 'write',
  UpdateCommand: 'write',
  DeleteItemCommand: 'write',
  DeleteCommand: 'write',
};

// ─── Public Interface ───────────────────────────────────────────────────────

/**
 * Audits a single Lambda handler file for compliance violations.
 *
 * @param filePath - Path to the handler file
 * @param content - File content as string
 * @returns Audit result with detected violations
 */
export function auditHandler(filePath: string, content: string): LambdaAuditResult {
  const violations: LambdaViolation[] = [];
  const lines = content.split('\n');

  // Check for missing validation (Req 11.1, 11.6)
  const validationViolations = detectMissingValidation(content, lines);
  violations.push(...validationViolations);

  // Check for missing correlation ID in error responses (Req 11.1, 11.6)
  const correlationViolations = detectMissingCorrelationId(content, lines);
  violations.push(...correlationViolations);

  // Check for missing logging (Req 11.1, 11.6)
  const loggingViolations = detectMissingLogging(content, lines);
  violations.push(...loggingViolations);

  // Check for inadequate catch blocks (Req 11.3)
  const catchViolations = detectInadequateCatchBlocks(lines);
  violations.push(...catchViolations);

  // Check for batch operation opportunities (Req 11.2, 11.7)
  const batchViolations = detectBatchOpportunities(lines);
  violations.push(...batchViolations);

  // Check for repository bypass (Req 11.4)
  const bypassViolations = detectRepositoryBypass(content, lines);
  violations.push(...bypassViolations);

  // Check for sensitive data in logs (Req 11.5)
  const sensitiveViolations = detectSensitiveDataInLogs(lines);
  violations.push(...sensitiveViolations);

  return {
    handlerFile: filePath,
    violations,
  };
}

/**
 * Audits all Lambda handler files in a directory.
 *
 * @param handlersDir - Path to the handlers directory
 * @returns Array of audit results for each handler file
 */
export function auditHandlersDirectory(handlersDir: string): LambdaAuditResult[] {
  const results: LambdaAuditResult[] = [];
  const files = collectHandlerFiles(handlersDir);

  for (const filePath of files) {
    const content = fs.readFileSync(filePath, 'utf-8');
    const result = auditHandler(filePath, content);
    results.push(result);
  }

  return results;
}

// ─── Detection Functions ────────────────────────────────────────────────────

/**
 * Detects missing input validation in a handler.
 * A handler should use Zod or equivalent schema validation.
 */
function detectMissingValidation(content: string, lines: string[]): LambdaViolation[] {
  const hasValidation = VALIDATION_PATTERNS.some((pattern) => pattern.test(content));

  if (hasValidation) {
    return [];
  }

  // Find the handler export line to report the violation location
  const handlerLine = findHandlerDeclarationLine(lines);

  return [
    {
      type: 'missing_validation',
      description:
        'Handler does not use Zod or equivalent schema library for input validation',
      lineNumber: handlerLine,
      severity: 'P1',
    },
  ];
}

/**
 * Detects error responses without correlation ID fields.
 * Error responses (4xx, 5xx) should include correlationId or requestId.
 */
function detectMissingCorrelationId(content: string, lines: string[]): LambdaViolation[] {
  const violations: LambdaViolation[] = [];

  // Check if the file has any correlation ID reference at all
  const hasGlobalCorrelationId = CORRELATION_ID_PATTERNS.some((pattern) =>
    pattern.test(content)
  );

  if (hasGlobalCorrelationId) {
    return [];
  }

  // Find error response patterns (statusCode: 4xx or 5xx)
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (isErrorResponseLine(line)) {
      // Check surrounding context (±5 lines) for correlation ID
      const context = lines
        .slice(Math.max(0, i - 5), Math.min(lines.length, i + 6))
        .join('\n');

      const hasCorrelationInContext = CORRELATION_ID_PATTERNS.some((pattern) =>
        pattern.test(context)
      );

      if (!hasCorrelationInContext) {
        violations.push({
          type: 'missing_correlation_id',
          description:
            'Error response does not include correlationId or requestId field',
          lineNumber: i + 1,
          severity: 'P1',
        });
      }
    }
  }

  // If no error responses found but handler exists, report at handler level
  if (violations.length === 0) {
    const hasErrorResponse = lines.some((line) => isErrorResponseLine(line));
    if (!hasErrorResponse && isHandlerFile(content)) {
      const handlerLine = findHandlerDeclarationLine(lines);
      violations.push({
        type: 'missing_correlation_id',
        description:
          'Handler has no error responses with correlation ID — structured error responses required',
        lineNumber: handlerLine,
        severity: 'P1',
      });
    }
  }

  return violations;
}

/**
 * Detects missing request/response logging.
 * Handlers should log method, path, status code, and duration.
 */
function detectMissingLogging(content: string, lines: string[]): LambdaViolation[] {
  const hasLogging = LOGGING_PATTERNS.some((pattern) => pattern.test(content));

  if (hasLogging) {
    return [];
  }

  const handlerLine = findHandlerDeclarationLine(lines);

  return [
    {
      type: 'missing_logging',
      description:
        'Handler does not have request/response logging (no console.log, logger, or logging library detected)',
      lineNumber: handlerLine,
      severity: 'P1',
    },
  ];
}

/**
 * Detects inadequate catch blocks that neither re-throw, return error response,
 * nor log the error.
 */
function detectInadequateCatchBlocks(lines: string[]): LambdaViolation[] {
  const violations: LambdaViolation[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Find catch block openings
    const catchMatch = line.match(/\bcatch\s*\(/);
    if (!catchMatch) {
      continue;
    }

    // Extract the catch block body
    const catchBody = extractBlockBody(lines, i);

    if (catchBody === null) {
      continue;
    }

    const isAdequate = isCatchBlockAdequate(catchBody);

    if (!isAdequate) {
      violations.push({
        type: 'inadequate_catch',
        description:
          'Catch block does not re-throw, return an error response, or log the error',
        lineNumber: i + 1,
        severity: 'P2',
      });
    }
  }

  return violations;
}

/**
 * Detects batch operation opportunities where 2+ DynamoDB operations
 * target the same table within a single handler.
 */
function detectBatchOpportunities(lines: string[]): LambdaViolation[] {
  const violations: LambdaViolation[] = [];

  // Track operations by table name
  const tableOps: Map<string, Array<{ line: number; opType: string }>> = new Map();

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    for (const [cmdName, opCategory] of Object.entries(DYNAMODB_OPS_FOR_BATCH)) {
      const cmdPattern = new RegExp(`new\\s+${cmdName}\\s*\\(`);
      if (!cmdPattern.test(line)) {
        continue;
      }

      // Extract table name from the surrounding params block
      const paramsBlock = extractParamsBlockSimple(lines, i);
      const tableName = extractTableNameFromBlock(paramsBlock);

      if (tableName) {
        if (!tableOps.has(tableName)) {
          tableOps.set(tableName, []);
        }
        tableOps.get(tableName)!.push({ line: i + 1, opType: opCategory });
      }
    }
  }

  // Flag tables with 2+ operations
  for (const [tableName, ops] of tableOps.entries()) {
    if (ops.length >= 2) {
      const readOps = ops.filter((op) => op.opType === 'read');
      const writeOps = ops.filter((op) => op.opType === 'write');

      if (readOps.length >= 2 || writeOps.length >= 2) {
        const firstOp = ops[0];
        const opTypeLabel = readOps.length >= 2 ? 'read' : 'write';
        violations.push({
          type: 'batch_opportunity',
          description: `${ops.length} DynamoDB ${opTypeLabel} operations on table "${tableName}" could use Batch${readOps.length >= 2 ? 'GetItem' : 'WriteItem'}`,
          lineNumber: firstOp.line,
          severity: 'P2',
        });
      }
    }
  }

  return violations;
}

/**
 * Detects direct DynamoDB client usage that bypasses the repository layer.
 * Handlers should use the shared repository for tenant isolation.
 */
function detectRepositoryBypass(content: string, lines: string[]): LambdaViolation[] {
  const violations: LambdaViolation[] = [];

  // If the file imports from a repository, direct usage might be intentional
  // (e.g., repository implementation files themselves)
  const hasRepositoryImport = REPOSITORY_PATTERNS.some((pattern) =>
    pattern.test(content)
  );

  // If this IS a repository file, skip bypass detection
  if (isRepositoryFile(content)) {
    return [];
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Skip import/require lines
    if (isImportLine(line)) {
      continue;
    }

    for (const pattern of DIRECT_DYNAMODB_PATTERNS) {
      if (pattern.test(line)) {
        // If there's a repository import, only flag if pattern is direct client creation
        if (hasRepositoryImport && !isDirectClientCreation(line)) {
          continue;
        }

        violations.push({
          type: 'repository_bypass',
          description:
            'Direct DynamoDB client usage detected — use the repository layer for tenant isolation',
          lineNumber: i + 1,
          severity: 'P1',
        });
        break; // One violation per line
      }
    }
  }

  return violations;
}

/**
 * Detects sensitive data patterns in log statements.
 * Passwords, tokens, emails, phone numbers, and government IDs
 * should never be logged in plaintext.
 */
function detectSensitiveDataInLogs(lines: string[]): LambdaViolation[] {
  const violations: LambdaViolation[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Only check lines that contain logging calls
    if (!isLogStatement(line)) {
      continue;
    }

    // Check for sensitive data patterns in the log content
    for (const { pattern, label } of SENSITIVE_DATA_PATTERNS) {
      if (pattern.test(line)) {
        // Skip if the log line is just logging an error type/message (not the value)
        if (isSafeLoggingContext(line, pattern)) {
          continue;
        }

        violations.push({
          type: 'sensitive_data_logged',
          description: `Potential sensitive data (${label}) found in log statement`,
          lineNumber: i + 1,
          severity: 'P1',
        });
        break; // One violation per log line
      }
    }
  }

  return violations;
}

// ─── Internal Helpers ───────────────────────────────────────────────────────

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
 * Finds the line number of the handler export or main function declaration.
 * Used as the violation location when no specific line can be identified.
 */
function findHandlerDeclarationLine(lines: string[]): number {
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    // Match common handler patterns
    if (
      /export\s+(?:const|async\s+function|function)\s+\w*[Hh]andler/.test(line) ||
      /export\s+(?:const|async\s+function|function)\s+\w+/.test(line) ||
      /module\.exports/.test(line) ||
      /exports\.\w+\s*=/.test(line)
    ) {
      return i + 1;
    }
  }
  // Default to line 1 if no handler declaration found
  return 1;
}

/**
 * Checks if a line contains an error response pattern (4xx or 5xx status).
 */
function isErrorResponseLine(line: string): boolean {
  return /statusCode\s*:\s*[45]\d{2}/.test(line);
}

/**
 * Checks if the file content looks like a handler file (has exports and handler-like structure).
 */
function isHandlerFile(content: string): boolean {
  return (
    /export\s+(const|async\s+function|function)/.test(content) ||
    /module\.exports/.test(content)
  );
}

/**
 * Extracts the body of a catch block starting from the line where `catch` is found.
 * Returns the content between the catch block's opening `{` and closing `}`.
 * For empty blocks like `catch (err) { }`, returns an empty string.
 *
 * This handles the common pattern: `} catch (err) {` where there's a closing
 * brace from the try block on the same line as the catch opening brace.
 */
function extractBlockBody(lines: string[], startLine: number): string | null {
  const maxLookahead = 30;

  // Step 1: Find the catch block's opening brace.
  // We need to skip past `catch (...)` to find the `{` that opens the catch body.
  const catchLine = lines[startLine];
  const catchIdx = catchLine.indexOf('catch');
  if (catchIdx === -1) {
    return null;
  }

  // Scan forward from `catch` to find `(`, match closing `)`, then find `{`
  let parenDepth = 0;
  let insideParens = false;
  let pastParens = false;
  let braceOpenLine = -1;
  let braceOpenCharIdx = -1;

  outer:
  for (let i = startLine; i < Math.min(lines.length, startLine + maxLookahead); i++) {
    const startIdx = i === startLine ? catchIdx + 5 : 0; // skip past "catch"
    const line = lines[i];

    for (let ci = startIdx; ci < line.length; ci++) {
      const char = line[ci];
      if (!pastParens) {
        if (char === '(') {
          parenDepth++;
          insideParens = true;
        } else if (char === ')') {
          parenDepth--;
          if (insideParens && parenDepth === 0) {
            pastParens = true;
          }
        }
      } else {
        if (char === '{') {
          braceOpenLine = i;
          braceOpenCharIdx = ci;
          break outer;
        }
      }
    }
  }

  if (braceOpenLine === -1) {
    return null;
  }

  // Step 2: Extract content between opening `{` and matching closing `}`
  let depth = 1;
  const bodyLines: string[] = [];

  for (let i = braceOpenLine; i < Math.min(lines.length, startLine + maxLookahead); i++) {
    const line = lines[i];
    const startIdx = i === braceOpenLine ? braceOpenCharIdx + 1 : 0;

    for (let ci = startIdx; ci < line.length; ci++) {
      const char = line[ci];
      if (char === '{') {
        depth++;
      } else if (char === '}') {
        depth--;
        if (depth === 0) {
          // Found the matching closing brace
          if (i === braceOpenLine) {
            // Single line: catch (err) { content }
            return line.substring(braceOpenCharIdx + 1, ci).trim();
          }
          // Multi-line: add partial content of closing line
          const closingContent = line.substring(0, ci).trim();
          if (closingContent) {
            bodyLines.push(line.substring(0, ci));
          }
          return bodyLines.join('\n');
        }
      }
    }

    // Collect lines after the opening brace line
    if (i > braceOpenLine) {
      bodyLines.push(line);
    } else if (i === braceOpenLine && startIdx < line.length) {
      // Remainder of the opening brace line after `{`
      const remainder = line.substring(startIdx).trim();
      if (remainder && remainder !== '}') {
        bodyLines.push(line.substring(startIdx));
      }
    }
  }

  return bodyLines.length > 0 ? bodyLines.join('\n') : '';
}

/**
 * Determines if a catch block is adequate.
 * A catch block is adequate if it does at least one of:
 * - Re-throws the error (throw)
 * - Returns an error response (return with statusCode)
 * - Logs the error (console.log/error/warn, logger.*)
 *
 * An empty catch block is always inadequate.
 */
function isCatchBlockAdequate(catchBody: string): boolean {
  // Empty catch blocks are always inadequate
  if (!catchBody || catchBody.trim().length === 0) {
    return false;
  }

  // Check for re-throw
  if (/\bthrow\b/.test(catchBody)) {
    return true;
  }

  // Check for error response return
  if (/\breturn\b/.test(catchBody) && /statusCode/.test(catchBody)) {
    return true;
  }

  // Check for logging
  if (/\bconsole\.(log|error|warn|info)\b/.test(catchBody)) {
    return true;
  }

  if (/\blogger\.\w+\b/.test(catchBody)) {
    return true;
  }

  if (/\blog\.\w+\b/.test(catchBody)) {
    return true;
  }

  return false;
}

/**
 * Extracts a params block (up to 30 lines) for batch opportunity detection.
 */
function extractParamsBlockSimple(lines: string[], startLine: number): string {
  const maxLookahead = 20;
  let depth = 0;
  let started = false;
  const result: string[] = [];

  for (let i = startLine; i < Math.min(lines.length, startLine + maxLookahead); i++) {
    const line = lines[i];
    result.push(line);

    for (const char of line) {
      if (char === '(' || char === '{') {
        depth++;
        started = true;
      } else if (char === ')' || char === '}') {
        depth--;
        if (started && depth <= 0) {
          return result.join('\n');
        }
      }
    }
  }

  return result.join('\n');
}

/**
 * Extracts TableName from a DynamoDB command params block.
 */
function extractTableNameFromBlock(block: string): string {
  const tableMatch = block.match(
    /TableName\s*:\s*(?:['"`]([^'"`]+)['"`]|(\w+(?:\.\w+)*))/
  );

  if (tableMatch) {
    return tableMatch[1] || tableMatch[2] || '';
  }

  return '';
}

/**
 * Checks if a line is an import or require statement.
 */
function isImportLine(line: string): boolean {
  const trimmed = line.trim();
  return (
    trimmed.startsWith('import ') ||
    trimmed.startsWith('import{') ||
    /require\s*\(/.test(trimmed) && trimmed.startsWith('const ') ||
    trimmed.startsWith('export { ') ||
    trimmed.startsWith('export {')
  );
}

/**
 * Checks if a line represents direct DynamoDB client creation
 * (as opposed to using a command from a repository).
 */
function isDirectClientCreation(line: string): boolean {
  return (
    /new\s+DynamoDBClient\s*\(/.test(line) ||
    /new\s+DynamoDB\s*\(/.test(line) ||
    /new\s+DynamoDB\.DocumentClient\s*\(/.test(line) ||
    /DynamoDBDocumentClient\.from\s*\(/.test(line)
  );
}

/**
 * Checks if the file is a repository implementation file.
 * Repository files themselves are allowed direct DynamoDB access.
 */
function isRepositoryFile(content: string): boolean {
  // Check if filename/content suggests this IS a repository
  return (
    /class\s+\w+Repository\b/.test(content) ||
    /export\s+(?:class|const|function)\s+\w*[Rr]epository\b/.test(content) ||
    /\/\*\*[\s\S]*?[Rr]epository[\s\S]*?\*\//.test(content.slice(0, 500))
  );
}

/**
 * Checks if a line contains a log statement.
 */
function isLogStatement(line: string): boolean {
  return (
    /\bconsole\.(log|info|warn|error|debug)\s*\(/.test(line) ||
    /\blogger\.(log|info|warn|error|debug)\s*\(/.test(line) ||
    /\blog\.(log|info|warn|error|debug)\s*\(/.test(line)
  );
}

/**
 * Checks if a sensitive data pattern match is in a safe logging context.
 * Safe contexts include:
 * - Logging error messages that mention the field name without the value
 * - Logging validation error messages
 * - Comments
 */
function isSafeLoggingContext(line: string, pattern: RegExp): boolean {
  const trimmed = line.trim();

  // If this is a comment line, it's safe
  if (trimmed.startsWith('//') || trimmed.startsWith('*')) {
    return true;
  }

  // If the sensitive word appears in a string literal describing an error
  // (e.g., 'Invalid email format'), it's typically safe
  const errorDescriptionPatterns = [
    /['"`].*(?:invalid|missing|required|format|validation).*['"`]/i,
    /['"`].*(?:error|failed|failure).*['"`]/i,
  ];

  // Check if the pattern match is within a descriptive string about the field
  // rather than logging the actual value
  for (const errPattern of errorDescriptionPatterns) {
    if (errPattern.test(line)) {
      // Only safe if the sensitive data word is inside the descriptive string
      const stringMatches = line.match(/['"`][^'"`]*['"`]/g);
      if (stringMatches) {
        const sensitiveInString = stringMatches.some((str) => pattern.test(str));
        const valueRefOutside = line.replace(/['"`][^'"`]*['"`]/g, '').match(pattern);
        if (sensitiveInString && !valueRefOutside) {
          return true;
        }
      }
    }
  }

  return false;
}
