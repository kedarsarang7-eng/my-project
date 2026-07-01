/**
 * Code AST scanner (task 4.2, Requirements 1.1, 1.4, 1.5).
 *
 * Parses a single JS/TS source file with the TypeScript compiler API and emits
 * `RawEndpoint` sightings for every endpoint signal it can recognize:
 *
 * - REST routes registered Express-style (`router.get('/x', ...)`, `app.post(...)`).
 * - REST routes annotated in doc comments as `METHOD /path` (the convention used
 *   by the Lambda handler files, e.g. `* GET /health`).
 * - WebSocket routes and events: the lifecycle routes `$connect` / `$disconnect`
 *   / `$default`, and dotted event names (e.g. `inventory.stock.updated`) found
 *   in WebSocket handler files.
 * - GraphQL operations embedded in `gql` / `graphql` tagged template literals.
 *
 * Parsing never type-checks; it only builds a syntax tree, so it is fast and
 * tolerant of unresolved imports. A genuinely malformed file will throw, which
 * task 4.3 catches and records as a `StageIssue`.
 */
import * as path from 'path';
import * as ts from 'typescript';
import type { SourceRef } from '../../types';
import type { RawEndpoint } from '../dedup';
import { scanGraphqlSource } from './graphql-scanner';
import {
  HTTP_METHOD_CALLS,
  dedupeWithinSource,
  restEndpoint,
  sourceRef,
  wsEventEndpoint,
  wsRouteEndpoint,
} from './scan-utils';

/** WebSocket lifecycle route keys recognized anywhere in code. */
const WS_LIFECYCLE_ROUTES = new Set(['$connect', '$disconnect', '$default']);

/** Matches a dotted WebSocket event name such as `inventory.stock.updated`. */
const WS_EVENT_NAME = /^[a-z][a-zA-Z0-9]*(?:\.[a-z][a-zA-Z0-9]+)+$/;

/** Matches a `METHOD /path` route annotation inside a doc comment. */
const COMMENT_ROUTE = /\b(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|ANY)\s+(\/[A-Za-z0-9_\-/{}:.]*)/g;

/** Tag names whose tagged-template bodies are treated as GraphQL documents. */
const GRAPHQL_TAGS = new Set(['gql', 'graphql']);

/**
 * Scan a single code file's contents for endpoint sightings.
 *
 * @param filePath absolute path of the file (used for source attribution and to
 *   decide whether WebSocket event extraction applies).
 * @param content the file's text.
 */
export function scanCodeFile(filePath: string, content: string): RawEndpoint[] {
  const scriptKind = scriptKindFor(filePath);
  const sourceFile = ts.createSourceFile(
    filePath,
    content,
    ts.ScriptTarget.Latest,
    /* setParentNodes */ true,
    scriptKind,
  );

  const raw: RawEndpoint[] = [];
  const wsContext = isWebSocketFile(filePath);

  const visit = (node: ts.Node): void => {
    collectExpressRoute(node, filePath, raw);
    collectStringLiteralSignals(node, filePath, wsContext, raw);
    collectGraphqlLiteral(node, filePath, raw);
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);

  collectCommentRoutes(content, filePath, raw);

  return dedupeWithinSource(raw);
}

/** Choose the right `ScriptKind` so `.js`/`.mjs` parse without JSX surprises. */
function scriptKindFor(filePath: string): ts.ScriptKind {
  const ext = path.extname(filePath).toLowerCase();
  switch (ext) {
    case '.ts':
      return ts.ScriptKind.TS;
    case '.tsx':
      return ts.ScriptKind.TSX;
    case '.js':
    case '.cjs':
    case '.mjs':
      return ts.ScriptKind.JS;
    default:
      return ts.ScriptKind.TS;
  }
}

/** True when a file participates in the WebSocket surface by path/name. */
function isWebSocketFile(filePath: string): boolean {
  const normalized = filePath.replace(/\\/g, '/').toLowerCase();
  const base = path.basename(normalized);
  return (
    normalized.includes('/websocket/') ||
    base.includes('websocket') ||
    base.startsWith('ws-') ||
    base.includes('.ws.')
  );
}

/**
 * Detect Express-style route registrations: a call whose callee is a property
 * access ending in an HTTP method name (`router.get`, `app.post`, ...) whose
 * first argument is a string-literal path beginning with `/`.
 */
function collectExpressRoute(node: ts.Node, filePath: string, out: RawEndpoint[]): void {
  if (!ts.isCallExpression(node) || !ts.isPropertyAccessExpression(node.expression)) {
    return;
  }

  const methodName = node.expression.name.text.toLowerCase();
  if (!HTTP_METHOD_CALLS.has(methodName)) {
    return;
  }

  const firstArg = node.arguments[0];
  if (!firstArg || !ts.isStringLiteralLike(firstArg)) {
    return;
  }

  const routePath = firstArg.text;
  if (!routePath.startsWith('/')) {
    return;
  }

  out.push(
    restEndpoint(methodName, routePath, sourceRef(filePath, 'code', 'route-registration')),
  );
}

/**
 * Inspect string literals for WebSocket signals: lifecycle routes anywhere, and
 * dotted event names within WebSocket handler files.
 */
function collectStringLiteralSignals(
  node: ts.Node,
  filePath: string,
  wsContext: boolean,
  out: RawEndpoint[],
): void {
  if (!ts.isStringLiteralLike(node)) {
    return;
  }
  const value = node.text;

  if (WS_LIFECYCLE_ROUTES.has(value)) {
    out.push(wsRouteEndpoint(value, sourceRef(filePath, 'code', 'ws-route')));
    return;
  }

  if (wsContext && WS_EVENT_NAME.test(value)) {
    out.push(wsEventEndpoint(value, sourceRef(filePath, 'code', 'ws-event')));
  }
}

/**
 * Parse GraphQL embedded in `gql` / `graphql` tagged template literals. Only
 * templates without `${}` substitutions are parsed, since interpolated schema
 * fragments cannot be parsed reliably in isolation.
 */
function collectGraphqlLiteral(node: ts.Node, filePath: string, out: RawEndpoint[]): void {
  if (!ts.isTaggedTemplateExpression(node)) {
    return;
  }
  if (!isGraphqlTag(node.tag)) {
    return;
  }
  if (!ts.isNoSubstitutionTemplateLiteral(node.template)) {
    return; // Interpolated GraphQL: skip rather than mis-parse.
  }

  const endpoints = scanGraphqlSource(
    node.template.text,
    sourceRef(filePath, 'code', 'graphql-literal'),
  );
  out.push(...endpoints);
}

/** True when a tagged-template tag is `gql` / `graphql` (optionally namespaced). */
function isGraphqlTag(tag: ts.Expression): boolean {
  if (ts.isIdentifier(tag)) {
    return GRAPHQL_TAGS.has(tag.text);
  }
  if (ts.isPropertyAccessExpression(tag)) {
    return GRAPHQL_TAGS.has(tag.name.text);
  }
  return false;
}

/**
 * Extract `METHOD /path` annotations from doc comments. Only comment lines are
 * considered (those whose trimmed start is `*`, `//`, or `/*`) so route-like
 * strings appearing in executable code are not misread as endpoints.
 */
function collectCommentRoutes(content: string, filePath: string, out: RawEndpoint[]): void {
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trimStart();
    const isComment =
      trimmed.startsWith('*') || trimmed.startsWith('//') || trimmed.startsWith('/*');
    if (!isComment) {
      continue;
    }

    COMMENT_ROUTE.lastIndex = 0;
    let match: RegExpExecArray | null;
    while ((match = COMMENT_ROUTE.exec(trimmed)) !== null) {
      const [, method, routePath] = match;
      out.push(
        restEndpoint(method, routePath, sourceRef(filePath, 'code', 'doc-comment')),
      );
    }
  }
}
