/**
 * Code Quality Scorer and Enforcement
 *
 * Enforces code quality standards across the platform:
 * - TypeScript strict mode with zero unannotated `any` usage
 * - Flutter analysis rules: no unused imports/variables, prefer const, explicit type annotations
 * - Test file existence for each repository class (success + error path tests)
 * - Performance requirements: no sync DynamoDB calls, no unbounded list/scan, no per-iteration DB calls
 *
 * Requirements: 13.1, 13.2, 13.3, 13.4
 */

import * as fs from 'fs';
import * as path from 'path';

// ─── Interfaces ─────────────────────────────────────────────────────────────

export interface QualityViolation {
  /** Rule identifier */
  rule: string;
  /** File where the violation was detected */
  file: string;
  /** Line number (1-indexed) */
  line?: number;
  /** Human-readable description */
  description: string;
  /** Whether this violation blocks merge */
  isBlocking: boolean;
}

// ─── TypeScript Strict Mode Enforcement (Req 13.1) ──────────────────────────

/** Pattern to match `any` type usage in TypeScript code */
const ANY_TYPE_PATTERNS = [
  /:\s*any\b/,                  // : any
  /as\s+any\b/,                 // as any
  /<any>/,                      // <any>
  /:\s*any\s*\[/,               // : any[
  /:\s*any\s*\|/,               // : any |
  /\|\s*any\b/,                 // | any
  /Record<[^,]+,\s*any\s*>/,    // Record<string, any>
  /Array<any>/,                 // Array<any>
  /Promise<any>/,               // Promise<any>
];

/** Allowlist comment pattern: // @allow-any: <justification> */
const ALLOW_ANY_PATTERN = /\/\/\s*@allow-any:\s*\S+/;

/**
 * Checks TypeScript files for unannotated `any` usage.
 * Any usage of `any` without a `// @allow-any: <justification>` comment is a violation.
 */
export function checkTypeScriptStrict(handlersDir: string): QualityViolation[] {
  const violations: QualityViolation[] = [];
  const files = collectTsFiles(handlersDir);

  for (const filePath of files) {
    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Skip comment-only lines
      const trimmed = line.trim();
      if (trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('/*')) {
        continue;
      }

      // Check if line contains any `any` type usage
      const hasAny = ANY_TYPE_PATTERNS.some((pattern) => pattern.test(line));
      if (!hasAny) {
        continue;
      }

      // Check if line has the allowlist comment
      if (ALLOW_ANY_PATTERN.test(line)) {
        continue;
      }

      violations.push({
        rule: 'typescript-strict-no-any',
        file: filePath,
        line: i + 1,
        description: '`any` type usage without `// @allow-any: <justification>` comment',
        isBlocking: true,
      });
    }
  }

  return violations;
}

// ─── Flutter Analysis Rules (Req 13.2) ──────────────────────────────────────

/** Patterns for unused imports (import with `show` keyword) */
const DART_IMPORT_SHOW_PATTERN = /^import\s+['"]([^'"]+)['"]\s+show\s+(.+);$/;

/** Pattern for non-const constructor where const is possible */
const NON_CONST_CONSTRUCTOR_PATTERN = /(?<!\bconst\s)\b(new\s+)?([A-Z]\w+)\s*\(/;

/** Pattern to match const constructor usage */
const CONST_CONSTRUCTOR_PATTERN = /\bconst\s+[A-Z]\w+\s*\(/;

/** Pattern for public member without type annotation */
const PUBLIC_MEMBER_NO_TYPE = /^\s+(?!\/\/)(\w+)\s*[=;]/;

/** Pattern for public method without return type */
const PUBLIC_METHOD_NO_RETURN_TYPE = /^\s+(?:Future|void|static\s+)?(\w+)\s*\([^)]*\)\s*(?:async\s*)?\{/;

/**
 * Checks Flutter/Dart files for analysis rule violations.
 * Detects: unused imports, unused variables, non-const constructors, missing type annotations.
 */
export function checkFlutterAnalysis(flutterRoot: string): QualityViolation[] {
  const violations: QualityViolation[] = [];
  const files = collectDartFiles(flutterRoot);

  for (const filePath of files) {
    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');

    // Check unused imports (import show X where X is never used in the file)
    const importViolations = detectUnusedImports(lines, content, filePath);
    violations.push(...importViolations);

    // Check unused variables
    const unusedVarViolations = detectUnusedVariables(lines, content, filePath);
    violations.push(...unusedVarViolations);

    // Check prefer const constructors
    const constViolations = detectNonConstConstructors(lines, filePath);
    violations.push(...constViolations);

    // Check explicit type annotations on public members
    const typeViolations = detectMissingTypeAnnotations(lines, filePath);
    violations.push(...typeViolations);
  }

  return violations;
}

// ─── Test Coverage Verification (Req 13.3) ──────────────────────────────────

/**
 * Verifies that each repository class has a corresponding test file
 * with success and error path tests.
 */
export function checkTestCoverage(handlersDir: string): QualityViolation[] {
  const violations: QualityViolation[] = [];
  const files = collectTsFiles(handlersDir);

  // Find all repository files
  const repoFiles = files.filter(
    (f) => /[Rr]epository\.ts$/.test(f) && !f.endsWith('.test.ts') && !f.endsWith('.spec.ts')
  );

  for (const repoFile of repoFiles) {
    const baseName = path.basename(repoFile, '.ts');
    const dir = path.dirname(repoFile);

    // Look for corresponding test file
    const testFileName = `${baseName}.test.ts`;
    const testFilePath = path.join(dir, testFileName);
    const altTestPath = path.join(dir, '__tests__', testFileName);

    let testFileExists = fs.existsSync(testFilePath) || fs.existsSync(altTestPath);
    let actualTestPath = fs.existsSync(testFilePath) ? testFilePath : altTestPath;

    if (!testFileExists) {
      violations.push({
        rule: 'test-coverage-repository',
        file: repoFile,
        description: `Repository file has no corresponding test file (expected: ${testFileName})`,
        isBlocking: true,
      });
      continue;
    }

    // Verify test content has success + error path tests
    const testContent = fs.readFileSync(actualTestPath, 'utf-8');

    const hasSuccessTest = /(?:it|test)\s*\(\s*['"`].*(?:success|should\s+return|should\s+create|should\s+get|should\s+update|should\s+delete|resolves|returns)/i.test(testContent);
    const hasErrorTest = /(?:it|test)\s*\(\s*['"`].*(?:error|fail|throw|reject|invalid|not\s+found|exception|should\s+throw)/i.test(testContent);

    if (!hasSuccessTest) {
      violations.push({
        rule: 'test-coverage-success-path',
        file: repoFile,
        description: `Repository test file missing success path test case`,
        isBlocking: true,
      });
    }

    if (!hasErrorTest) {
      violations.push({
        rule: 'test-coverage-error-path',
        file: repoFile,
        description: `Repository test file missing error/exception path test case`,
        isBlocking: true,
      });
    }
  }

  return violations;
}

// ─── Performance Requirements (Req 13.4) ────────────────────────────────────

/** Patterns for synchronous DynamoDB calls */
const SYNC_DYNAMODB_PATTERNS = [
  /\.getItem\s*\(/,         // Synchronous-style getItem
  /\.putItem\s*\(/,         // Synchronous-style putItem
  /\.query\s*\(/,           // Synchronous-style query (without await)
  /\.scan\s*\(/,            // Synchronous-style scan (without await)
  /\.updateItem\s*\(/,      // Synchronous-style updateItem
  /\.deleteItem\s*\(/,      // Synchronous-style deleteItem
];

/** Patterns for scan/list without Limit */
const UNBOUNDED_SCAN_PATTERNS = [
  /new\s+ScanCommand\s*\(/,
  /new\s+ListTablesCommand\s*\(/,
  /scanTable\s*\(/,
  /scanItems\s*\(/,
  /\.scan\s*\(/,
];

/** Loop patterns that may contain DB calls */
const LOOP_PATTERNS = [
  /\bfor\s*\(/,
  /\bfor\s+of\b/,
  /\bfor\s+in\b/,
  /\.forEach\s*\(/,
  /\.map\s*\(/,
  /\bwhile\s*\(/,
];

/** DB call patterns inside loops */
const DB_CALL_PATTERNS = [
  /await\s+.*(?:send|getItem|putItem|query|scan|updateItem|deleteItem)\s*\(/,
  /await\s+.*(?:repository|repo)\.\w+\s*\(/i,
  /await\s+.*(?:client|docClient|ddbClient)\.send\s*\(/,
];

/**
 * Checks for performance violations in handler code:
 * - Synchronous DynamoDB calls
 * - Unbounded scan/list operations (no Limit parameter)
 * - Database calls inside loops without batching
 */
export function checkPerformance(handlersDir: string): QualityViolation[] {
  const violations: QualityViolation[] = [];
  const files = collectTsFiles(handlersDir);

  for (const filePath of files) {
    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');

    // Check for synchronous DynamoDB calls (not using await)
    const syncViolations = detectSyncDynamoDbCalls(lines, filePath);
    violations.push(...syncViolations);

    // Check for unbounded scan/list without Limit
    const unboundedViolations = detectUnboundedScans(lines, content, filePath);
    violations.push(...unboundedViolations);

    // Check for DB calls inside loops
    const loopViolations = detectLoopDbCalls(lines, filePath);
    violations.push(...loopViolations);
  }

  return violations;
}

// ─── Internal Helpers: File Collection ──────────────────────────────────────

/**
 * Recursively collects TypeScript files from a directory.
 * Excludes test files, declaration files, and node_modules.
 */
function collectTsFiles(dir: string): string[] {
  const files: string[] = [];

  if (!fs.existsSync(dir)) {
    return files;
  }

  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      if (entry.name === 'node_modules' || entry.name === 'dist') {
        continue;
      }
      files.push(...collectTsFiles(fullPath));
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
 * Recursively collects Dart files from a directory.
 * Excludes test files, generated files, and build directories.
 */
function collectDartFiles(dir: string): string[] {
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
        entry.name === 'test' ||
        entry.name === 'test_driver' ||
        entry.name.startsWith('.')
      ) {
        continue;
      }
      files.push(...collectDartFiles(fullPath));
    } else if (
      entry.isFile() &&
      entry.name.endsWith('.dart') &&
      !entry.name.endsWith('_test.dart') &&
      !entry.name.endsWith('.g.dart') &&
      !entry.name.endsWith('.freezed.dart')
    ) {
      files.push(fullPath);
    }
  }

  return files;
}

// ─── Internal Helpers: Flutter Analysis ─────────────────────────────────────

/**
 * Detects unused imports in Dart files.
 * An import with `show` directive is unused if none of the shown identifiers
 * appear elsewhere in the file body.
 */
function detectUnusedImports(
  lines: string[],
  content: string,
  filePath: string
): QualityViolation[] {
  const violations: QualityViolation[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    const match = line.match(DART_IMPORT_SHOW_PATTERN);

    if (!match) {
      continue;
    }

    const identifiers = match[2].split(',').map((id) => id.trim());
    // Check if any shown identifier is used in the rest of the file (excluding imports)
    const bodyContent = lines
      .filter((l, idx) => idx !== i && !l.trim().startsWith('import'))
      .join('\n');

    const allUnused = identifiers.every((id) => {
      const usagePattern = new RegExp(`\\b${escapeRegex(id)}\\b`);
      return !usagePattern.test(bodyContent);
    });

    if (allUnused) {
      violations.push({
        rule: 'flutter-unused-import',
        file: filePath,
        line: i + 1,
        description: `Unused import: ${identifiers.join(', ')} from '${match[1]}'`,
        isBlocking: false,
      });
    }
  }

  return violations;
}

/**
 * Detects unused local variables in Dart files.
 * A variable declared with `final`, `var`, or a type annotation that is never
 * referenced after declaration.
 */
function detectUnusedVariables(
  lines: string[],
  content: string,
  filePath: string
): QualityViolation[] {
  const violations: QualityViolation[] = [];
  const varDeclPattern = /^\s+(?:final|var|int|double|String|bool|List|Map|Set|dynamic)\s+(\w+)\s*[=;]/;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const match = line.match(varDeclPattern);

    if (!match) {
      continue;
    }

    const varName = match[1];

    // Skip commonly-used patterns (e.g., _ prefix for intentionally unused)
    if (varName.startsWith('_')) {
      continue;
    }

    // Check if variable is used elsewhere in the file after declaration
    const afterDeclaration = lines.slice(i + 1).join('\n');
    const usagePattern = new RegExp(`\\b${escapeRegex(varName)}\\b`);

    if (!usagePattern.test(afterDeclaration)) {
      violations.push({
        rule: 'flutter-unused-variable',
        file: filePath,
        line: i + 1,
        description: `Unused variable: '${varName}'`,
        isBlocking: false,
      });
    }
  }

  return violations;
}

/**
 * Detects non-const constructors where const is possible.
 * Widget constructors that use only const parameters should use `const`.
 */
function detectNonConstConstructors(
  lines: string[],
  filePath: string
): QualityViolation[] {
  const violations: QualityViolation[] = [];

  // Common Flutter widget names that should prefer const
  const constWidgets = [
    'SizedBox', 'Padding', 'EdgeInsets', 'Text', 'Icon',
    'Divider', 'Spacer', 'Center', 'Align',
  ];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // Skip lines that already use const
    if (/\bconst\b/.test(trimmed)) {
      continue;
    }

    // Skip comment lines
    if (trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('/*')) {
      continue;
    }

    for (const widget of constWidgets) {
      // Match `WidgetName(` without preceding `const`
      const widgetPattern = new RegExp(`(?<!const\\s)\\b${widget}\\s*\\(`);
      if (widgetPattern.test(line)) {
        // Check if the constructor args are const-compatible (only literals)
        const argsStart = line.indexOf(`${widget}(`);
        if (argsStart === -1) continue;

        violations.push({
          rule: 'flutter-prefer-const',
          file: filePath,
          line: i + 1,
          description: `Prefer const constructor for '${widget}'`,
          isBlocking: false,
        });
        break;
      }
    }
  }

  return violations;
}

/**
 * Detects public class members without explicit type annotations.
 * Public methods, properties, and top-level functions must have type annotations.
 */
function detectMissingTypeAnnotations(
  lines: string[],
  filePath: string
): QualityViolation[] {
  const violations: QualityViolation[] = [];
  let inClass = false;
  let braceDepth = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // Track class scope
    if (/\bclass\s+\w+/.test(trimmed)) {
      inClass = true;
    }

    // Track brace depth
    for (const char of line) {
      if (char === '{') braceDepth++;
      if (char === '}') braceDepth--;
    }

    if (braceDepth === 0 && inClass) {
      inClass = false;
    }

    // Skip private members (start with _), comments, and empty lines
    if (!inClass || trimmed.startsWith('//') || trimmed.startsWith('_') || !trimmed) {
      continue;
    }

    // Detect public method without return type annotation
    // Pattern: methodName(params) { or methodName(params) async {
    const methodMatch = trimmed.match(
      /^(\w+)\s*\([^)]*\)\s*(?:async\s*)?\{/
    );
    if (methodMatch && !isPrivate(methodMatch[1])) {
      // Check if it has a return type before the method name
      const hasReturnType = /^(?:Future|void|String|int|double|bool|List|Map|Set|Widget|dynamic|Stream|[\w<>]+)\s+\w+\s*\(/.test(trimmed);
      if (!hasReturnType && methodMatch[1] !== 'build') {
        violations.push({
          rule: 'flutter-explicit-type-annotation',
          file: filePath,
          line: i + 1,
          description: `Public method '${methodMatch[1]}' missing return type annotation`,
          isBlocking: false,
        });
      }
    }
  }

  return violations;
}

// ─── Internal Helpers: Performance Checks ───────────────────────────────────

/**
 * Detects synchronous DynamoDB calls (without await) in handler code.
 */
function detectSyncDynamoDbCalls(
  lines: string[],
  filePath: string
): QualityViolation[] {
  const violations: QualityViolation[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // Skip comments and imports
    if (trimmed.startsWith('//') || trimmed.startsWith('import') || trimmed.startsWith('*')) {
      continue;
    }

    // Check for DynamoDB method calls without await
    for (const pattern of SYNC_DYNAMODB_PATTERNS) {
      if (!pattern.test(line)) {
        continue;
      }

      // Check if this line or the previous line has `await`
      const hasAwait = /\bawait\b/.test(line);
      const prevLine = i > 0 ? lines[i - 1] : '';
      const prevHasAwait = /\bawait\b/.test(prevLine);

      // Also check if it's inside a return statement with await
      const isReturnAwait = /return\s+await\b/.test(line);

      if (!hasAwait && !prevHasAwait && !isReturnAwait) {
        // Skip if it's a type definition or interface
        if (/(?:interface|type|class)\s/.test(line)) {
          continue;
        }

        violations.push({
          rule: 'performance-sync-dynamodb',
          file: filePath,
          line: i + 1,
          description: 'Synchronous DynamoDB call detected — use async/await',
          isBlocking: true,
        });
      }
    }
  }

  return violations;
}

/**
 * Detects scan/list operations without a Limit parameter or pagination token.
 */
function detectUnboundedScans(
  lines: string[],
  content: string,
  filePath: string
): QualityViolation[] {
  const violations: QualityViolation[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Check if line contains a scan/list command
    const hasScanOp = UNBOUNDED_SCAN_PATTERNS.some((pattern) => pattern.test(line));
    if (!hasScanOp) {
      continue;
    }

    // Extract the params block to check for Limit
    const paramsBlock = extractParamsBlock(lines, i);

    const hasLimit = /\bLimit\s*:/i.test(paramsBlock) || /\blimit\s*:/i.test(paramsBlock);
    const hasPaginationToken =
      /\bExclusiveStartKey\s*:/i.test(paramsBlock) ||
      /\bLastEvaluatedKey\b/i.test(paramsBlock) ||
      /\bpaginat/i.test(paramsBlock) ||
      /\bnextToken\b/i.test(paramsBlock);

    if (!hasLimit && !hasPaginationToken) {
      violations.push({
        rule: 'performance-unbounded-scan',
        file: filePath,
        line: i + 1,
        description: 'Scan/list operation without Limit parameter or pagination token',
        isBlocking: true,
      });
    }
  }

  return violations;
}

/**
 * Detects database calls inside loops (potential N+1 query problem).
 * Loops containing await DB calls should use batching instead.
 */
function detectLoopDbCalls(
  lines: string[],
  filePath: string
): QualityViolation[] {
  const violations: QualityViolation[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Check if this line starts a loop
    const isLoop = LOOP_PATTERNS.some((pattern) => pattern.test(line));
    if (!isLoop) {
      continue;
    }

    // Extract the loop body
    const loopBody = extractLoopBody(lines, i);
    if (!loopBody) {
      continue;
    }

    // Check if loop body contains a DB call
    const hasDbCall = DB_CALL_PATTERNS.some((pattern) => pattern.test(loopBody));
    if (hasDbCall) {
      violations.push({
        rule: 'performance-loop-db-call',
        file: filePath,
        line: i + 1,
        description: 'Database call inside loop — use batch operations instead',
        isBlocking: true,
      });
    }
  }

  return violations;
}

// ─── Internal Helpers: Utility ──────────────────────────────────────────────

/**
 * Extracts a params block (object literal or function args) from a starting line.
 * Looks ahead up to 30 lines for the matching closing brace/paren.
 */
function extractParamsBlock(lines: string[], startLine: number): string {
  const maxLookahead = 30;
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
 * Extracts the body of a loop construct (for, while, forEach, map).
 * Returns the content between the opening and closing braces.
 */
function extractLoopBody(lines: string[], startLine: number): string | null {
  const maxLookahead = 50;
  let depth = 0;
  let foundOpen = false;
  const bodyLines: string[] = [];

  for (let i = startLine; i < Math.min(lines.length, startLine + maxLookahead); i++) {
    const line = lines[i];

    for (const char of line) {
      if (char === '{') {
        depth++;
        foundOpen = true;
      } else if (char === '}') {
        depth--;
        if (foundOpen && depth === 0) {
          return bodyLines.join('\n');
        }
      }
    }

    if (foundOpen && depth > 0) {
      bodyLines.push(line);
    }
  }

  return bodyLines.length > 0 ? bodyLines.join('\n') : null;
}

/**
 * Escapes special regex characters in a string for safe use in RegExp.
 */
function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Checks if a Dart member name is private (starts with _).
 */
function isPrivate(name: string): boolean {
  return name.startsWith('_');
}

// ─── Quality Score Calculation (Req 13.5) ───────────────────────────────────

export interface QualityScore {
  /** Feature module name */
  module: string;
  /** Percentage of screens with at least one widget test */
  testCoveragePercent: number;
  /** Percentage of handlers with input validation on all required parameters */
  validationPercent: number;
  /** Percentage of screens passing the responsive layout checklist */
  responsivePercent: number;
  /** Equally-weighted average of the three metrics (0–100) */
  overallScore: number;
}

/**
 * Calculates the quality score for a feature module.
 *
 * The overall score is the equally-weighted average of:
 * - Widget test coverage percentage
 * - Handler validation percentage
 * - Responsive layout compliance percentage
 *
 * Each input percentage is clamped to [0, 100] before averaging.
 * The result is a value on the 0–100 scale.
 */
export function calculateQualityScore(metrics: {
  testCoverage: number;
  validation: number;
  responsive: number;
  module: string;
}): QualityScore {
  // Clamp each metric to valid 0–100 range
  const testCoverage = clampPercent(metrics.testCoverage);
  const validation = clampPercent(metrics.validation);
  const responsive = clampPercent(metrics.responsive);

  // Equally-weighted average of the three percentages
  const overallScore = (testCoverage + validation + responsive) / 3;

  return {
    module: metrics.module,
    testCoveragePercent: testCoverage,
    validationPercent: validation,
    responsivePercent: responsive,
    overallScore,
  };
}

// ─── Diff-Based Violation Classification (Req 13.6, 13.7, 13.8) ────────────

export interface ViolationClassification {
  /** The original violation */
  violation: QualityViolation;
  /** Whether the violation blocks merge */
  classification: 'blocking' | 'non-blocking';
  /** Human-readable reason for the classification */
  reason: string;
}

/**
 * Represents a parsed hunk from a unified diff showing added lines.
 */
interface DiffHunk {
  /** File path affected by this hunk */
  file: string;
  /** Set of line numbers that are newly added in this diff */
  addedLines: Set<number>;
}

/**
 * Classifies violations as blocking or non-blocking based on git diff content.
 *
 * Rules:
 * - If the violation's file + line appears in the diff's added lines → blocking
 * - If the violation's file is in the diff but the line is unchanged → non-blocking
 * - If the classification cannot be determined (file not in diff, no line info) → blocking (default)
 */
export function classifyViolations(
  violations: QualityViolation[],
  diffContent: string
): ViolationClassification[] {
  const hunks = parseDiff(diffContent);

  return violations.map((violation) => {
    const classification = classifySingleViolation(violation, hunks);
    return classification;
  });
}

/**
 * Classifies a single violation against parsed diff hunks.
 */
function classifySingleViolation(
  violation: QualityViolation,
  hunks: DiffHunk[]
): ViolationClassification {
  // Normalize the violation's file path for comparison
  const violationFile = normalizePath(violation.file);

  // Find hunks matching the violation's file
  const matchingHunks = hunks.filter(
    (hunk) => normalizePath(hunk.file) === violationFile
  );

  // If file is not in the diff at all, classification is indeterminate → blocking
  if (matchingHunks.length === 0) {
    return {
      violation,
      classification: 'blocking',
      reason: 'File not found in diff; treating as blocking (indeterminate)',
    };
  }

  // If no line number on the violation, we can't determine position → blocking
  if (violation.line === undefined || violation.line === null) {
    return {
      violation,
      classification: 'blocking',
      reason: 'Violation has no line number; treating as blocking (indeterminate)',
    };
  }

  // Check if the violation's line is in the added lines of any matching hunk
  const isInAddedLines = matchingHunks.some(
    (hunk) => hunk.addedLines.has(violation.line!)
  );

  if (isInAddedLines) {
    return {
      violation,
      classification: 'blocking',
      reason: 'Violation is in newly added code (diff added lines)',
    };
  }

  // File is in diff but the specific line is not in added lines → unchanged code → non-blocking
  return {
    violation,
    classification: 'non-blocking',
    reason: 'Violation is in existing unchanged code',
  };
}

/**
 * Parses unified diff content into structured hunks with added line tracking.
 *
 * Supports standard `git diff` unified format:
 * - `diff --git a/file b/file` or `--- a/file` / `+++ b/file` headers
 * - `@@ -old,count +new,count @@` hunk headers
 * - Lines starting with `+` (excluding `+++`) are added lines
 */
function parseDiff(diffContent: string): DiffHunk[] {
  const hunks: DiffHunk[] = [];

  if (!diffContent || diffContent.trim().length === 0) {
    return hunks;
  }

  const lines = diffContent.split('\n');
  let currentFile: string | null = null;
  let currentAddedLines: Set<number> = new Set();
  let newLineNumber = 0;

  for (const line of lines) {
    // Detect file change: +++ b/path/to/file
    const filePlusMatch = line.match(/^\+\+\+\s+b\/(.+)$/);
    if (filePlusMatch) {
      // Save previous hunk if any
      if (currentFile !== null && currentAddedLines.size > 0) {
        // Merge with existing hunk for same file or create new
        const existing = hunks.find((h) => h.file === currentFile);
        if (existing) {
          for (const ln of currentAddedLines) {
            existing.addedLines.add(ln);
          }
        } else {
          hunks.push({ file: currentFile, addedLines: new Set(currentAddedLines) });
        }
      }
      currentFile = filePlusMatch[1];
      currentAddedLines = new Set();
      newLineNumber = 0;
      continue;
    }

    // Detect hunk header: @@ -old,count +new,count @@
    const hunkHeaderMatch = line.match(/^@@\s+-\d+(?:,\d+)?\s+\+(\d+)(?:,\d+)?\s+@@/);
    if (hunkHeaderMatch) {
      newLineNumber = parseInt(hunkHeaderMatch[1], 10);
      continue;
    }

    // Skip if we haven't found a file yet
    if (currentFile === null || newLineNumber === 0) {
      continue;
    }

    // Process diff lines
    if (line.startsWith('+') && !line.startsWith('+++')) {
      // Added line
      currentAddedLines.add(newLineNumber);
      newLineNumber++;
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      // Removed line — does not advance new line number
    } else if (line.startsWith('\\')) {
      // "No newline at end of file" marker — skip
    } else {
      // Context line (unchanged) — advances new line number
      newLineNumber++;
    }
  }

  // Save final hunk
  if (currentFile !== null && currentAddedLines.size > 0) {
    const existing = hunks.find((h) => h.file === currentFile);
    if (existing) {
      for (const ln of currentAddedLines) {
        existing.addedLines.add(ln);
      }
    } else {
      hunks.push({ file: currentFile, addedLines: new Set(currentAddedLines) });
    }
  }

  return hunks;
}

// ─── Shared Utility ─────────────────────────────────────────────────────────

/**
 * Clamps a number to the [0, 100] range.
 */
function clampPercent(value: number): number {
  if (value < 0) return 0;
  if (value > 100) return 100;
  return value;
}

/**
 * Normalizes a file path for comparison by:
 * - Converting backslashes to forward slashes
 * - Removing leading ./ or ./
 * - Converting to lowercase for case-insensitive matching
 */
function normalizePath(filePath: string): string {
  return filePath
    .replace(/\\/g, '/')
    .replace(/^\.\//, '')
    .toLowerCase();
}
