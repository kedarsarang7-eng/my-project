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
