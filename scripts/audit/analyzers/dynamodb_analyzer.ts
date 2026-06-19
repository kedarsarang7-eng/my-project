/**
 * DynamoDB Access Pattern Analyzer
 *
 * Scans Lambda handler files for DynamoDB operations and detects:
 * - Operation type (get, put, query, scan, update, delete)
 * - Table name, key conditions, filter expressions
 * - Dynamically constructed table names or keys (P1 audit-incomplete)
 *
 * Requirements: 4.1, 4.5
 */

import * as fs from 'fs';
import * as path from 'path';
import { DynamoDbOperation } from '../types';

// ─── Patterns for DynamoDB SDK v3 command usage ─────────────────────────────

/**
 * Maps DynamoDB command class names to their operation type.
 * Covers both @aws-sdk/client-dynamodb and @aws-sdk/lib-dynamodb variants.
 */
const COMMAND_TO_OPERATION: Record<string, DynamoDbOperation['type']> = {
  GetItemCommand: 'get',
  GetCommand: 'get',
  PutItemCommand: 'put',
  PutCommand: 'put',
  QueryCommand: 'query',
  QueryItemCommand: 'query',
  ScanCommand: 'scan',
  UpdateItemCommand: 'update',
  UpdateCommand: 'update',
  DeleteItemCommand: 'delete',
  DeleteCommand: 'delete',
};

/**
 * Maps helper function names to their operation type.
 * These are project-specific utility wrappers around DynamoDB operations.
 */
const HELPER_TO_OPERATION: Record<string, DynamoDbOperation['type']> = {
  getItem: 'get',
  putItem: 'put',
  queryItems: 'query',
  queryAllItems: 'query',
  scanTable: 'scan',
  scanItems: 'scan',
  updateItem: 'update',
  deleteItem: 'delete',
  batchGetItems: 'get',
  batchWriteItems: 'put',
  transactWrite: 'put',
  transactGet: 'get',
};

/**
 * Patterns that indicate dynamic table name or key construction.
 * Template literals, string concatenation, or variable references
 * that can't be resolved statically.
 */
const DYNAMIC_PATTERNS = [
  /`[^`]*\$\{[^}]+\}[^`]*`/,              // Template literals: `${var}Table`
  /\w+\s*\+\s*['"`]/,                       // Concatenation: varName + "suffix"
  /['"`]\s*\+\s*\w+/,                       // Concatenation: "prefix" + varName
  /\[\s*\w+\s*\]/,                           // Bracket notation: obj[varName]
  /process\.env\.\w+/,                       // Environment variable reference
  /config\.\w+\.\w+/,                        // Config object reference
];

// ─── Public Interface ───────────────────────────────────────────────────────

/**
 * Scans handler files in the given directory for DynamoDB operations.
 * Extracts operation type, table name, key conditions, filter expressions,
 * source file, and line number for each operation found.
 */
export function scanOperations(handlersDir: string): DynamoDbOperation[] {
  const operations: DynamoDbOperation[] = [];
  const files = collectTypeScriptFiles(handlersDir);

  for (const filePath of files) {
    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');

    // Find operations via SDK command instantiation
    const commandOps = findCommandOperations(lines, filePath);
    operations.push(...commandOps);

    // Find operations via helper function calls
    const helperOps = findHelperOperations(lines, filePath);
    operations.push(...helperOps);

    // Find operations via TransactWriteItems / TransactGetItems / BatchWriteItem
    const transactOps = findTransactOperations(lines, filePath);
    operations.push(...transactOps);
  }

  return operations;
}

/**
 * Detects whether a DynamoDB operation uses dynamically constructed
 * table names or key conditions that cannot be statically resolved.
 *
 * Returns true if the operation has dynamic construction (flag as P1).
 */
export function isDynamicConstruction(op: DynamoDbOperation): boolean {
  // If already flagged during scan
  if (op.isDynamic) {
    return true;
  }

  // Check table name for dynamic patterns
  if (hasDynamicPattern(op.tableName)) {
    return true;
  }

  // Check key condition for dynamic patterns
  if (op.keyCondition && hasDynamicPattern(op.keyCondition)) {
    return true;
  }

  return false;
}

// ─── Internal Helpers ───────────────────────────────────────────────────────

/**
 * Recursively collects all .ts files from a directory, excluding
 * test files, declaration files, and node_modules.
 */
function collectTypeScriptFiles(dir: string): string[] {
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
      files.push(...collectTypeScriptFiles(fullPath));
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
 * Finds DynamoDB operations via SDK Command instantiation patterns:
 * e.g., `new GetItemCommand({...})`, `new QueryCommand({...})`
 */
function findCommandOperations(lines: string[], filePath: string): DynamoDbOperation[] {
  const operations: DynamoDbOperation[] = [];
  const commandNames = Object.keys(COMMAND_TO_OPERATION);

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    for (const cmdName of commandNames) {
      // Match `new CommandName(` pattern
      const cmdPattern = new RegExp(`new\\s+${cmdName}\\s*\\(`);
      if (!cmdPattern.test(line)) {
        continue;
      }

      const opType = COMMAND_TO_OPERATION[cmdName];
      // Extract the params block (may span multiple lines)
      const paramsBlock = extractParamsBlock(lines, i);

      const tableName = extractTableName(paramsBlock);
      const keyCondition = extractKeyCondition(paramsBlock);
      const filterExpression = extractFilterExpression(paramsBlock);
      const isDynamic = hasDynamicPattern(tableName) || hasDynamicPattern(keyCondition);

      operations.push({
        type: opType,
        tableName,
        keyCondition,
        filterExpression,
        handlerFile: filePath,
        lineNumber: i + 1, // 1-indexed
        isDynamic,
      });
    }
  }

  return operations;
}

/**
 * Finds DynamoDB operations via helper/utility function calls:
 * e.g., `queryItems(pk, 'PRODUCT#', { ... })`, `updateItem(pk, sk, { ... })`
 */
function findHelperOperations(lines: string[], filePath: string): DynamoDbOperation[] {
  const operations: DynamoDbOperation[] = [];
  const helperNames = Object.keys(HELPER_TO_OPERATION);

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    for (const helperName of helperNames) {
      // Match function call pattern: `helperName(` or `await helperName(`
      const helperPattern = new RegExp(`(?:await\\s+)?${helperName}\\s*[<(]`);
      if (!helperPattern.test(line)) {
        continue;
      }

      // Avoid matching imports or declarations
      if (isImportOrDeclaration(line, helperName)) {
        continue;
      }

      const opType = HELPER_TO_OPERATION[helperName];
      const paramsBlock = extractParamsBlock(lines, i);

      const tableName = extractTableNameFromHelper(paramsBlock, lines, i);
      const keyCondition = extractKeyConditionFromHelper(paramsBlock);
      const filterExpression = extractFilterExpressionFromHelper(paramsBlock);
      const isDynamic = hasDynamicPattern(tableName) || hasDynamicPattern(keyCondition);

      operations.push({
        type: opType,
        tableName,
        keyCondition,
        filterExpression,
        handlerFile: filePath,
        lineNumber: i + 1,
        isDynamic,
      });
    }
  }

  return operations;
}

/**
 * Finds DynamoDB operations within TransactWriteItems or BatchWriteItem blocks.
 * These contain inline Put/Update/Delete/Get operations with TableName.
 */
function findTransactOperations(lines: string[], filePath: string): DynamoDbOperation[] {
  const operations: DynamoDbOperation[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Match transact item patterns: `Put: {`, `Update: {`, `Delete: {`, `Get: {`
    const transactItemMatch = line.match(/\b(Put|Update|Delete|Get)\s*:\s*\{/);
    if (!transactItemMatch) {
      continue;
    }

    // Verify this is inside a TransactItems or RequestItems block
    // by checking preceding lines for transactItems/TransactItems/RequestItems context
    const contextWindow = lines.slice(Math.max(0, i - 10), i).join('\n');
    if (
      !contextWindow.match(/transactItems|TransactItems|RequestItems|BatchWrite/i)
    ) {
      continue;
    }

    const itemType = transactItemMatch[1].toLowerCase() as DynamoDbOperation['type'];
    const opType = itemType === 'put' ? 'put' : itemType;

    const paramsBlock = extractParamsBlock(lines, i);
    const tableName = extractTableName(paramsBlock);
    const keyCondition = extractKeyCondition(paramsBlock);
    const filterExpression = extractFilterExpression(paramsBlock);
    const isDynamic = hasDynamicPattern(tableName);

    operations.push({
      type: opType,
      tableName,
      keyCondition,
      filterExpression,
      handlerFile: filePath,
      lineNumber: i + 1,
      isDynamic,
    });
  }

  return operations;
}

/**
 * Extracts a block of code starting from a given line until the matching
 * closing brace/paren, or up to a max lookahead of 30 lines.
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
 * Extracts TableName from a DynamoDB command params block.
 * Handles: TableName: 'literal', TableName: TABLE_NAME, TableName: variable
 */
function extractTableName(block: string): string {
  // Match TableName in command params
  const tableMatch = block.match(
    /TableName\s*:\s*(?:['"`]([^'"`]+)['"`]|(\w+(?:\.\w+)*))/
  );

  if (tableMatch) {
    return tableMatch[1] || tableMatch[2] || '';
  }

  return '';
}

/**
 * Extracts table name from helper function calls.
 * Helpers typically use a shared TABLE_NAME constant, so we look
 * for it in the params or in surrounding context.
 */
function extractTableNameFromHelper(
  paramsBlock: string,
  lines: string[],
  lineIndex: number
): string {
  // Check if table name is in the params block
  const tableInParams = extractTableName(paramsBlock);
  if (tableInParams) {
    return tableInParams;
  }

  // Look for TABLE_NAME or tableName constant in the file context
  // (helpers usually use a module-level constant)
  const contextRange = lines.slice(0, Math.min(30, lines.length)).join('\n');
  const tableConstMatch = contextRange.match(
    /(?:const|let)\s+(?:TABLE_NAME|tableName)\s*=\s*(?:['"`]([^'"`]+)['"`]|(\w+(?:\.\w+)*))/
  );

  if (tableConstMatch) {
    return tableConstMatch[1] || tableConstMatch[2] || '';
  }

  // Check for imports that suggest a table constant
  const importMatch = contextRange.match(
    /import\s+\{[^}]*TABLE_NAME[^}]*\}\s+from\s+['"`]([^'"`]+)['"`]/
  );

  if (importMatch) {
    return 'TABLE_NAME'; // reference to imported constant
  }

  return '';
}

/**
 * Extracts KeyConditionExpression from a params block.
 */
function extractKeyCondition(block: string): string {
  const match = block.match(
    /KeyConditionExpression\s*:\s*['"`]([^'"`]+)['"`]/
  );
  return match ? match[1] : '';
}

/**
 * Extracts key condition patterns from helper function call parameters.
 * Helpers like queryItems(pk, skPrefix, options) use positional params.
 */
function extractKeyConditionFromHelper(block: string): string {
  // Check for explicit KeyConditionExpression in options
  const explicit = extractKeyCondition(block);
  if (explicit) {
    return explicit;
  }

  // For helper functions like queryItems(pk, skPrefix, ...) the
  // key condition is implicit in the positional args
  const argMatch = block.match(
    /(?:queryItems|queryAllItems)\s*(?:<[^>]*>)?\s*\(\s*([^,]+),\s*['"`]([^'"`]+)['"`]/
  );

  if (argMatch) {
    return `PK = ${argMatch[1].trim()} AND begins_with(SK, '${argMatch[2]}')`;
  }

  return '';
}

/**
 * Extracts FilterExpression from a params block.
 */
function extractFilterExpression(block: string): string {
  const match = block.match(
    /FilterExpression\s*:\s*['"`]([^'"`]+)['"`]/
  );
  return match ? match[1] : '';
}

/**
 * Extracts filter expression from helper function options.
 */
function extractFilterExpressionFromHelper(block: string): string {
  // Match filterExpression in options object (lowercase property name used by helpers)
  const match = block.match(
    /filterExpression\s*:\s*['"`]([^'"`]+)['"`]/
  );

  if (match) {
    return match[1];
  }

  // Also check capitalized version
  return extractFilterExpression(block);
}

/**
 * Checks whether a given value contains dynamic construction patterns
 * that prevent static resolution.
 */
function hasDynamicPattern(value: string): boolean {
  if (!value) {
    return false;
  }

  for (const pattern of DYNAMIC_PATTERNS) {
    if (pattern.test(value)) {
      return true;
    }
  }

  return false;
}

/**
 * Checks if a line is an import statement or function declaration
 * rather than an actual function call.
 */
function isImportOrDeclaration(line: string, functionName: string): boolean {
  const trimmed = line.trim();

  // Import statements
  if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
    return true;
  }

  // Function declarations
  if (
    trimmed.match(
      new RegExp(
        `(?:function|const|let|var|async\\s+function)\\s+${functionName}\\s*[=(]`
      )
    )
  ) {
    return true;
  }

  // Type annotations or interface definitions
  if (trimmed.match(/:\s*\(/) || trimmed.match(/interface\s+/)) {
    return true;
  }

  return false;
}
