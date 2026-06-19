/**
 * API Surface Mapper — Backend Route Parser
 *
 * Parses serverless.yml and template.yaml files to extract HTTP routes,
 * including method, path, handler file, and authentication status.
 *
 * Requirements: 2.1, 2.5
 */

import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';
import { Route, CallSite, MatchResult } from '../types';

// ─── Types for YAML Parsing ─────────────────────────────────────────────────

/** Serverless Framework function event shape */
interface ServerlessHttpEvent {
  httpApi?: {
    path?: string;
    method?: string;
    authorizer?: { name?: string } | string;
  };
}

interface ServerlessFunction {
  handler?: string;
  events?: Array<ServerlessHttpEvent | Record<string, unknown>>;
}

interface ServerlessConfig {
  functions?: Record<string, ServerlessFunction>;
}

/** SAM template resource shapes */
interface SamHttpEventProperties {
  Path?: string;
  Method?: string;
  Auth?: { Authorizer?: string } | Record<string, unknown>;
}

interface SamEvent {
  Type?: string;
  Properties?: SamHttpEventProperties;
}

interface SamFunctionProperties {
  Handler?: string;
  CodeUri?: string;
  Events?: Record<string, SamEvent>;
}

interface SamResource {
  Type?: string;
  Properties?: SamFunctionProperties;
}

interface SamTemplate {
  Resources?: Record<string, SamResource>;
}

// ─── Implementation ─────────────────────────────────────────────────────────

/**
 * Normalize a URL path by replacing path parameters with wildcards.
 * Path parameters are segments enclosed in curly braces, e.g., {id}, {tenantId}.
 *
 * Examples:
 *   /users/{userId}/orders/{orderId} → /users/{*}/orders/{*}
 *   /inventory → /inventory (unchanged)
 */
export function normalizePath(routePath: string): string {
  return routePath.replace(/\{[^}]+\}/g, '{*}');
}

/**
 * Parse routes from serverless.yml and/or template.yaml config files.
 *
 * - Handles YAML parse errors gracefully: skips the file, logs a warning, continues.
 * - Extracts HTTP method, path, handler file, and authentication status.
 *
 * @param configPaths - Array of file paths to parse (serverless.yml or template.yaml)
 * @returns Array of Route objects extracted from all parseable config files
 */
export function parseRoutes(configPaths: string[]): Route[] {
  const routes: Route[] = [];

  for (const configPath of configPaths) {
    try {
      const content = fs.readFileSync(configPath, 'utf-8');
      const parsed = yaml.load(content) as Record<string, unknown> | null;

      if (!parsed || typeof parsed !== 'object') {
        console.warn(`[api_mapper] Skipping ${configPath}: empty or invalid YAML`);
        continue;
      }

      const fileName = path.basename(configPath);
      const isServerless = fileName === 'serverless.yml';
      const isTemplate = fileName === 'template.yaml';

      if (isServerless) {
        const extracted = parseServerlessRoutes(parsed as ServerlessConfig, configPath);
        routes.push(...extracted);
      } else if (isTemplate) {
        const extracted = parseSamRoutes(parsed as SamTemplate, configPath);
        routes.push(...extracted);
      } else {
        // Attempt both formats — try serverless first, then SAM
        const slsRoutes = parseServerlessRoutes(parsed as ServerlessConfig, configPath);
        if (slsRoutes.length > 0) {
          routes.push(...slsRoutes);
        } else {
          const samRoutes = parseSamRoutes(parsed as SamTemplate, configPath);
          routes.push(...samRoutes);
        }
      }
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      console.warn(`[api_mapper] Skipping ${configPath}: YAML parse error — ${message}`);
      continue;
    }
  }

  return routes;
}

/**
 * Parse routes from a Serverless Framework configuration.
 * Functions are under the `functions` key, each with `handler` and `events`.
 */
function parseServerlessRoutes(config: ServerlessConfig, configPath: string): Route[] {
  const routes: Route[] = [];
  const functions = config.functions;

  if (!functions || typeof functions !== 'object') {
    return routes;
  }

  for (const [, fnDef] of Object.entries(functions)) {
    if (!fnDef || !fnDef.handler || !fnDef.events) continue;

    const handlerFile = fnDef.handler;

    for (const event of fnDef.events) {
      if (!event || typeof event !== 'object') continue;

      const httpApi = (event as ServerlessHttpEvent).httpApi;
      if (!httpApi || !httpApi.path || !httpApi.method) continue;

      const method = httpApi.method.toUpperCase();
      const routePath = httpApi.path;
      const authenticated = isServerlessRouteAuthenticated(httpApi.authorizer);

      routes.push({
        method,
        path: routePath,
        normalizedPath: normalizePath(routePath),
        handlerFile,
        authenticated,
        source: 'serverless.yml',
      });
    }
  }

  return routes;
}

/**
 * Determine if a Serverless Framework route is authenticated.
 * A route is unauthenticated if it has `authorizer: { name: none }` or `authorizer: none`.
 * Routes without an explicit authorizer config are considered authenticated (uses default).
 */
function isServerlessRouteAuthenticated(
  authorizer: { name?: string } | string | undefined
): boolean {
  if (!authorizer) return true; // No authorizer specified = uses default = authenticated

  if (typeof authorizer === 'string') {
    return authorizer.toLowerCase() !== 'none';
  }

  if (typeof authorizer === 'object' && authorizer.name) {
    return authorizer.name.toLowerCase() !== 'none';
  }

  return true;
}

/**
 * Parse routes from a SAM (AWS::Serverless) template.
 * Functions are under Resources with Type: AWS::Serverless::Function,
 * each containing Events with Type: HttpApi.
 */
function parseSamRoutes(template: SamTemplate, configPath: string): Route[] {
  const routes: Route[] = [];
  const resources = template.Resources;

  if (!resources || typeof resources !== 'object') {
    return routes;
  }

  for (const [, resource] of Object.entries(resources)) {
    if (!resource || resource.Type !== 'AWS::Serverless::Function') continue;

    const properties = resource.Properties;
    if (!properties) continue;

    const handlerFile = buildSamHandlerPath(properties.CodeUri, properties.Handler);
    const events = properties.Events;

    if (!events || typeof events !== 'object') continue;

    for (const [, event] of Object.entries(events)) {
      if (!event || event.Type !== 'HttpApi') continue;

      const props = event.Properties;
      if (!props || !props.Path || !props.Method) continue;

      const method = props.Method.toUpperCase();
      const routePath = props.Path;
      const authenticated = isSamRouteAuthenticated(props.Auth);

      routes.push({
        method,
        path: routePath,
        normalizedPath: normalizePath(routePath),
        handlerFile,
        authenticated,
        source: 'template.yaml',
      });
    }
  }

  return routes;
}

/**
 * Build the handler path from SAM CodeUri and Handler fields.
 * Example: CodeUri: "lambda/tenantHandler/", Handler: "index.handler"
 *   → "lambda/tenantHandler/index.handler"
 */
function buildSamHandlerPath(codeUri: string | undefined, handler: string | undefined): string {
  if (!handler) return '';
  if (!codeUri) return handler;

  // Remove trailing slash from CodeUri
  const normalizedUri = codeUri.replace(/\/+$/, '');
  return `${normalizedUri}/${handler}`;
}

/**
 * Determine if a SAM template route is authenticated.
 * A route is unauthenticated if Auth.Authorizer is "NONE" or similar.
 * Routes without Auth config are considered authenticated (uses default authorizer).
 */
function isSamRouteAuthenticated(
  auth: { Authorizer?: string } | Record<string, unknown> | undefined
): boolean {
  if (!auth) return true; // No Auth = uses default = authenticated

  if (typeof auth === 'object' && 'Authorizer' in auth) {
    const authorizer = (auth as { Authorizer?: string }).Authorizer;
    if (typeof authorizer === 'string') {
      return authorizer.toUpperCase() !== 'NONE';
    }
  }

  return true;
}

// ─── Flutter HTTP Call Site Scanner ─────────────────────────────────────────────

/**
 * Regex patterns for detecting HTTP call sites in Flutter/Dart code.
 *
 * Pattern 1: ApiClient calls — `_apiClient.get('/path')`, `apiClient.post('/path', ...)`
 * Pattern 2: Direct http calls — `http.get(Uri.parse('$baseUrl/path'))`, `http.post(Uri.parse(...))`
 * Pattern 3: Dio calls — `_dio.get('/path')`, `dio.post('/path', ...)`
 */

/** Matches _apiClient.method('/path' or apiClient.method('/path' */
const API_CLIENT_PATTERN =
  /(?:_?apiClient|_?api_client|_?client)\.(\w+)\(\s*['"`]([^'"`]+)['"`]/g;

/** Matches http.get(, http.post(, etc. followed by Uri.parse('...url...') */
const HTTP_DIRECT_PATTERN =
  /http\.(\w+)\(\s*\n?\s*Uri\.parse\(\s*['"`]([^'"`]+)['"`]\s*\)/g;

/** Matches http.method(\n  Uri.parse('...') on separate lines */
const HTTP_MULTILINE_PATTERN =
  /http\.(\w+)\([^)]*?Uri\.parse\(\s*['"`]([^'"`]+)['"`]\s*\)/gs;

/** Matches _dio.method('/path' or dio.method('/path' */
const DIO_PATTERN =
  /(?:_?dio)\.(\w+)\(\s*['"`]([^'"`]+)['"`]/g;

/** Matches ApiClient path strings on separate lines: .get(\n  '/path', */
const API_CLIENT_MULTILINE_PATTERN =
  /(?:_?apiClient|_?api_client|_?client)\.(\w+)\(\s*\n\s*['"`]([^'"`]+)['"`]/g;

/** HTTP methods we recognize */
const VALID_HTTP_METHODS = new Set(['get', 'post', 'put', 'delete', 'patch', 'head', 'options']);

/**
 * Extract the API path from a URL string that may include base URL prefixes.
 *
 * Examples:
 *   '$baseUrl/tenant/config' → '/tenant/config'
 *   '${ApiConfig.baseUrl}/admin/tenants' → '/admin/tenants'
 *   '/ac/students' → '/ac/students'
 *   '$_baseUrl/subscription/current' → '/subscription/current'
 */
function extractApiPath(rawPath: string): string | null {
  // Already a clean path starting with /
  if (rawPath.startsWith('/')) {
    return rawPath;
  }

  // Strip Dart string interpolation prefixes like $baseUrl, ${ApiConfig.baseUrl}, $_baseUrl, etc.
  const prefixStripped = rawPath.replace(
    /^(?:\$\{[^}]+\}|\$[a-zA-Z_][a-zA-Z0-9_]*)/, ''
  );

  if (prefixStripped.startsWith('/')) {
    return prefixStripped;
  }

  // Try to find the first path segment after any URL-like prefix
  const pathMatch = rawPath.match(/(?:https?:\/\/[^/]+)?(\/.+)/);
  if (pathMatch) {
    return pathMatch[1];
  }

  return null;
}

/**
 * Replace Dart string interpolation variables in paths with parameter wildcards.
 *
 * Examples:
 *   '/ac/students/$id' → '/ac/students/{id}'
 *   '/computer/job-cards/$jobCardId/parts' → '/computer/job-cards/{jobCardId}/parts'
 *   '/staff/$staffId/dashboard' → '/staff/{staffId}/dashboard'
 */
function replaceDartInterpolation(pathStr: string): string {
  // Replace ${expr} patterns
  let result = pathStr.replace(/\$\{([^}]+)\}/g, '{$1}');
  // Replace $variable patterns (simple identifiers after $)
  result = result.replace(/\$([a-zA-Z_][a-zA-Z0-9_]*)/g, '{$1}');
  return result;
}

/**
 * Scan Flutter code for all HTTP request call sites.
 *
 * Identifies three main patterns:
 * 1. ApiClient/service wrapper calls: `_apiClient.get('/path')`, `apiClient.post('/path')`
 * 2. Direct http package calls: `http.get(Uri.parse('$baseUrl/path'))`
 * 3. Dio client calls: `_dio.get('/path')`, `dio.post('/path')`
 *
 * @param flutterRoot - Root directory of the Flutter project (e.g., 'Dukan_x/')
 * @returns Array of CallSite objects with source file, path, method, and line number
 */
export function scanCallSites(flutterRoot: string): CallSite[] {
  const callSites: CallSite[] = [];
  const libDir = path.join(flutterRoot, 'lib');

  if (!fs.existsSync(libDir)) {
    console.warn(`[api_mapper] Flutter lib directory not found: ${libDir}`);
    return callSites;
  }

  const dartFiles = findDartFiles(libDir);

  for (const filePath of dartFiles) {
    try {
      const content = fs.readFileSync(filePath, 'utf-8');
      const relativePath = path.relative(flutterRoot, filePath).replace(/\\/g, '/');
      const sites = extractCallSitesFromFile(content, relativePath);
      callSites.push(...sites);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      console.warn(`[api_mapper] Skipping ${filePath}: read error — ${message}`);
      continue;
    }
  }

  return callSites;
}

/**
 * Recursively find all .dart files under a directory.
 */
function findDartFiles(dir: string): string[] {
  const files: string[] = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      // Skip build, generated, and test directories
      if (entry.name === '.dart_tool' || entry.name === 'build' || entry.name === '.symlinks') {
        continue;
      }
      files.push(...findDartFiles(fullPath));
    } else if (entry.name.endsWith('.dart')) {
      files.push(fullPath);
    }
  }

  return files;
}

/**
 * Extract HTTP call sites from a single Dart file's content.
 */
function extractCallSitesFromFile(content: string, filePath: string): CallSite[] {
  const sites: CallSite[] = [];
  const lines = content.split('\n');

  // Pattern 1: ApiClient calls — single-line and multi-line
  extractWithPattern(content, lines, filePath, API_CLIENT_PATTERN, sites);
  extractWithPattern(content, lines, filePath, API_CLIENT_MULTILINE_PATTERN, sites);

  // Pattern 2: Direct http package calls
  extractWithPattern(content, lines, filePath, HTTP_DIRECT_PATTERN, sites);
  extractWithPattern(content, lines, filePath, HTTP_MULTILINE_PATTERN, sites);

  // Pattern 3: Dio calls
  extractWithPattern(content, lines, filePath, DIO_PATTERN, sites);

  // Deduplicate by (filePath, lineNumber, normalizedPath)
  return deduplicateCallSites(sites);
}

/**
 * Apply a regex pattern to file content and extract call sites.
 */
function extractWithPattern(
  content: string,
  lines: string[],
  filePath: string,
  pattern: RegExp,
  results: CallSite[]
): void {
  // Reset regex state (global flag)
  const regex = new RegExp(pattern.source, pattern.flags);
  let match: RegExpExecArray | null;

  while ((match = regex.exec(content)) !== null) {
    const method = match[1].toLowerCase();
    const rawPath = match[2];

    // Only process recognized HTTP methods
    if (!VALID_HTTP_METHODS.has(method)) continue;

    // Extract clean API path
    const apiPath = extractApiPath(rawPath);
    if (!apiPath) continue;

    // Skip non-API paths (tel:, upi:, file:, data:, etc.)
    if (/^(tel|upi|file|data|mailto|sms|market):/.test(rawPath)) continue;

    // Replace Dart string interpolation with parameter placeholders
    const pathWithParams = replaceDartInterpolation(apiPath);

    // Calculate line number from match position
    const lineNumber = getLineNumber(content, match.index);

    results.push({
      screenFile: filePath,
      requestPath: pathWithParams,
      normalizedPath: normalizePath(pathWithParams),
      httpMethod: method.toUpperCase(),
      lineNumber,
    });
  }
}

/**
 * Get line number (1-indexed) from a character offset in a string.
 */
function getLineNumber(content: string, offset: number): number {
  let line = 1;
  for (let i = 0; i < offset && i < content.length; i++) {
    if (content[i] === '\n') line++;
  }
  return line;
}

/**
 * Remove duplicate call sites that may be matched by multiple patterns.
 * Deduplication key: (screenFile, lineNumber, normalizedPath, httpMethod)
 */
function deduplicateCallSites(sites: CallSite[]): CallSite[] {
  const seen = new Set<string>();
  const unique: CallSite[] = [];

  for (const site of sites) {
    const key = `${site.screenFile}:${site.lineNumber}:${site.normalizedPath}:${site.httpMethod}`;
    if (!seen.has(key)) {
      seen.add(key);
      unique.push(site);
    }
  }

  return unique;
}

// ─── Call Site to Route Matching ────────────────────────────────────────────────

/**
 * Match normalized call site paths to normalized route paths.
 *
 * Matching logic:
 * - For each call site, find a route where the normalized paths match
 *   (case-insensitive) AND HTTP methods match.
 * - A call site without any matching route is a broken dependency (P1).
 * - A route not matched by any call site is an orphaned route (P2).
 *
 * Requirements: 2.3, 2.4, 2.6
 *
 * @param callSites - Array of HTTP call sites found in Flutter code
 * @param routes - Array of backend routes parsed from config files
 * @returns MatchResult with matched pairs, broken dependencies, and orphaned routes
 */
export function matchCallSitesToRoutes(callSites: CallSite[], routes: Route[]): MatchResult {
  const matched: Array<{ callSite: CallSite; route: Route }> = [];
  const brokenDependencies: CallSite[] = [];
  const matchedRouteIndices = new Set<number>();

  for (const callSite of callSites) {
    const callNormalized = callSite.normalizedPath.toLowerCase();
    const callMethod = callSite.httpMethod.toUpperCase();
    let found = false;

    for (let i = 0; i < routes.length; i++) {
      const route = routes[i];
      const routeNormalized = route.normalizedPath.toLowerCase();
      const routeMethod = route.method.toUpperCase();

      if (callNormalized === routeNormalized && callMethod === routeMethod) {
        matched.push({ callSite, route });
        matchedRouteIndices.add(i);
        found = true;
        break;
      }
    }

    if (!found) {
      brokenDependencies.push(callSite);
    }
  }

  // Routes not matched by any call site are orphaned
  const orphanedRoutes: Route[] = routes.filter((_, index) => !matchedRouteIndices.has(index));

  return { matched, brokenDependencies, orphanedRoutes };
}

/**
 * Generate a human-readable summary of the match results.
 *
 * Prints totals for:
 * - Cataloged routes
 * - Mapped call sites
 * - Broken dependencies (P1)
 * - Orphaned routes (P2)
 *
 * Also lists specific broken dependencies and orphaned routes for debugging.
 *
 * @param result - The MatchResult from matchCallSitesToRoutes()
 * @param totalRoutes - Total number of routes that were cataloged
 * @param totalCallSites - Total number of call sites that were scanned
 * @returns A formatted summary string
 */
export function generateMatchSummary(
  result: MatchResult,
  totalRoutes: number,
  totalCallSites: number
): string {
  const lines: string[] = [];

  lines.push('═══════════════════════════════════════════════════════');
  lines.push('  API Mapping Summary');
  lines.push('═══════════════════════════════════════════════════════');
  lines.push('');
  lines.push(`  Cataloged routes:       ${totalRoutes}`);
  lines.push(`  Mapped call sites:      ${totalCallSites}`);
  lines.push(`  Matched pairs:          ${result.matched.length}`);
  lines.push(`  Broken dependencies:    ${result.brokenDependencies.length} (P1)`);
  lines.push(`  Orphaned routes:        ${result.orphanedRoutes.length} (P2)`);
  lines.push('');

  if (result.brokenDependencies.length > 0) {
    lines.push('───────────────────────────────────────────────────────');
    lines.push('  Broken Dependencies (P1) — Call sites with no matching route');
    lines.push('───────────────────────────────────────────────────────');
    for (const cs of result.brokenDependencies) {
      lines.push(`  [${cs.httpMethod}] ${cs.requestPath}`);
      lines.push(`       → ${cs.screenFile}:${cs.lineNumber}`);
    }
    lines.push('');
  }

  if (result.orphanedRoutes.length > 0) {
    lines.push('───────────────────────────────────────────────────────');
    lines.push('  Orphaned Routes (P2) — Routes with no matching call site');
    lines.push('───────────────────────────────────────────────────────');
    for (const route of result.orphanedRoutes) {
      lines.push(`  [${route.method}] ${route.path}`);
      lines.push(`       → ${route.handlerFile} (${route.source})`);
    }
    lines.push('');
  }

  lines.push('═══════════════════════════════════════════════════════');

  return lines.join('\n');
}
