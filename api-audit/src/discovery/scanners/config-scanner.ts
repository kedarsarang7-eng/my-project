/**
 * Configuration scanner (task 4.2, Requirements 1.2, 1.5).
 *
 * Parses serverless / SAM / CloudFormation templates and emits `RawEndpoint`
 * sightings for the HTTP and WebSocket endpoints they declare. Four declaration
 * styles are recognized:
 *
 * - SAM function events of `Type: HttpApi` / `Type: Api` (`Path` + `Method`).
 * - `AWS::ApiGatewayV2::Route` resources whose `RouteKey` is either a
 *   `METHOD /path` REST route or a WebSocket route such as `$connect`.
 * - `AWS::ApiGateway::Method` resources joined with the `AWS::ApiGateway::Resource`
 *   tree (via `PathPart` / `ParentId`) to reconstruct the full REST path.
 * - Serverless Framework `functions[].events[]` of type `http` / `httpApi`
 *   (REST) and `websocket` (WebSocket).
 *
 * CloudFormation intrinsic tags (`!Ref`, `!GetAtt`, `!Sub`, ...) are handled so
 * the YAML parses cleanly; references needed for path reconstruction (`!Ref`,
 * `!GetAtt`) are preserved structurally. A genuinely unparseable file throws so
 * task 4.3 can record it and continue.
 */
import { parse as parseYaml } from 'yaml';
import type { RawEndpoint } from '../dedup';
import {
  HTTP_METHODS,
  dedupeWithinSource,
  restEndpoint,
  sourceRef,
  wsRouteEndpoint,
} from './scan-utils';

/** A `RouteKey`/route string shaped like `METHOD /path` (REST) vs a WS route. */
const REST_ROUTE_KEY = /^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|ANY|\*)\s+(\/\S*)$/i;

/** Minimal CloudFormation intrinsic tags so templates parse without warnings. */
const CFN_TAGS = [
  { tag: '!Ref', resolve: (value: string) => ({ Ref: String(value) }) },
  { tag: '!GetAtt', resolve: (value: string) => ({ 'Fn::GetAtt': String(value) }) },
];

/** Extract REST and WebSocket endpoints from a configuration template. */
export function scanConfigFile(filePath: string, content: string): RawEndpoint[] {
  const document = parseYaml(content, {
    customTags: CFN_TAGS,
    logLevel: 'silent',
    uniqueKeys: false,
  }) as unknown;

  if (!isRecord(document)) {
    return [];
  }

  const raw: RawEndpoint[] = [];

  if (isRecord(document.Resources)) {
    scanCloudFormation(document.Resources, filePath, raw);
  }
  if (isRecord(document.functions)) {
    scanServerless(document.functions, filePath, raw);
  }

  return dedupeWithinSource(raw);
}

// ---------------------------------------------------------------------------
// CloudFormation / SAM
// ---------------------------------------------------------------------------

function scanCloudFormation(
  resources: Record<string, unknown>,
  filePath: string,
  out: RawEndpoint[],
): void {
  // Pre-index API Gateway (v1) resource nodes so method paths can be rebuilt.
  const resourceTree = indexResourceTree(resources);

  for (const [logicalId, resource] of Object.entries(resources)) {
    if (!isRecord(resource) || typeof resource.Type !== 'string') {
      continue;
    }
    const props = isRecord(resource.Properties) ? resource.Properties : {};

    switch (resource.Type) {
      case 'AWS::Serverless::Function':
        scanSamFunctionEvents(props, filePath, out);
        break;
      case 'AWS::ApiGatewayV2::Route':
        scanV2Route(props, logicalId, filePath, out);
        break;
      case 'AWS::ApiGateway::Method':
        scanV1Method(props, resourceTree, logicalId, filePath, out);
        break;
      default:
        break;
    }
  }
}

/** SAM `Events` of type HttpApi/Api → REST endpoints. */
function scanSamFunctionEvents(
  props: Record<string, unknown>,
  filePath: string,
  out: RawEndpoint[],
): void {
  const events = props.Events;
  if (!isRecord(events)) {
    return;
  }

  for (const [eventName, event] of Object.entries(events)) {
    if (!isRecord(event) || (event.Type !== 'HttpApi' && event.Type !== 'Api')) {
      continue;
    }
    const eventProps = isRecord(event.Properties) ? event.Properties : {};
    const routePath = typeof eventProps.Path === 'string' ? eventProps.Path : undefined;
    if (!routePath) {
      continue;
    }
    const method =
      typeof eventProps.Method === 'string' ? eventProps.Method.toUpperCase() : 'ANY';
    out.push(restEndpoint(method, routePath, sourceRef(filePath, 'configuration', eventName)));
  }
}

/** `AWS::ApiGatewayV2::Route` → REST route or WebSocket route by RouteKey shape. */
function scanV2Route(
  props: Record<string, unknown>,
  logicalId: string,
  filePath: string,
  out: RawEndpoint[],
): void {
  const routeKey = typeof props.RouteKey === 'string' ? props.RouteKey.trim() : undefined;
  if (!routeKey) {
    return;
  }

  const restMatch = REST_ROUTE_KEY.exec(routeKey);
  if (restMatch) {
    const method = restMatch[1].toUpperCase() === '*' ? 'ANY' : restMatch[1].toUpperCase();
    out.push(restEndpoint(method, restMatch[2], sourceRef(filePath, 'configuration', logicalId)));
    return;
  }

  // Non REST-shaped route keys ($connect, $disconnect, $default, custom actions)
  // are WebSocket routes (Requirement 1.5).
  out.push(wsRouteEndpoint(routeKey, sourceRef(filePath, 'configuration', logicalId)));
}

/** `AWS::ApiGateway::Method` joined with the resource tree → REST endpoint. */
function scanV1Method(
  props: Record<string, unknown>,
  tree: ResourceTree,
  logicalId: string,
  filePath: string,
  out: RawEndpoint[],
): void {
  const httpMethod =
    typeof props.HttpMethod === 'string' ? props.HttpMethod.toUpperCase() : 'ANY';
  const resourceTarget = refTarget(props.ResourceId);
  const routePath = resolveResourcePath(resourceTarget, tree);
  out.push(restEndpoint(httpMethod, routePath, sourceRef(filePath, 'configuration', logicalId)));
}

interface ResourceNode {
  pathPart: string;
  parentTarget?: string;
}
type ResourceTree = Map<string, ResourceNode>;

/** Index every `AWS::ApiGateway::Resource` by logical id for path rebuilding. */
function indexResourceTree(resources: Record<string, unknown>): ResourceTree {
  const tree: ResourceTree = new Map();
  for (const [logicalId, resource] of Object.entries(resources)) {
    if (!isRecord(resource) || resource.Type !== 'AWS::ApiGateway::Resource') {
      continue;
    }
    const props = isRecord(resource.Properties) ? resource.Properties : {};
    const pathPart = typeof props.PathPart === 'string' ? props.PathPart : '';
    tree.set(logicalId, { pathPart, parentTarget: refTarget(props.ParentId) });
  }
  return tree;
}

/**
 * Reconstruct the full REST path for an API Gateway resource by walking up the
 * `ParentId` chain to the API root. Returns `/` for the root resource and
 * guards against reference cycles.
 */
function resolveResourcePath(
  target: string | undefined,
  tree: ResourceTree,
  visited: Set<string> = new Set(),
): string {
  if (!target || isRootReference(target) || !tree.has(target) || visited.has(target)) {
    return '/';
  }
  visited.add(target);

  const node = tree.get(target)!;
  const parentPath = resolveResourcePath(node.parentTarget, tree, visited);
  const base = parentPath === '/' ? '' : parentPath;
  return `${base}/${node.pathPart}`;
}

/** True when a reference points at the API's implicit root resource. */
function isRootReference(target: string): boolean {
  return target.endsWith('.RootResourceId') || target.endsWith('RootResourceId');
}

// ---------------------------------------------------------------------------
// Serverless Framework
// ---------------------------------------------------------------------------

function scanServerless(
  functions: Record<string, unknown>,
  filePath: string,
  out: RawEndpoint[],
): void {
  for (const [fnName, fn] of Object.entries(functions)) {
    if (!isRecord(fn) || !Array.isArray(fn.events)) {
      continue;
    }
    for (const event of fn.events) {
      if (!isRecord(event)) {
        continue;
      }
      const httpEvent = event.http ?? event.httpApi;
      if (httpEvent !== undefined) {
        scanServerlessHttpEvent(httpEvent, fnName, filePath, out);
      }
      if (event.websocket !== undefined) {
        scanServerlessWsEvent(event.websocket, fnName, filePath, out);
      }
    }
  }
}

/** A serverless `http`/`httpApi` event may be a `"GET /x"` string or an object. */
function scanServerlessHttpEvent(
  httpEvent: unknown,
  fnName: string,
  filePath: string,
  out: RawEndpoint[],
): void {
  let method: string | undefined;
  let routePath: string | undefined;

  if (typeof httpEvent === 'string') {
    const [rawMethod, rawPath] = httpEvent.trim().split(/\s+/);
    method = rawMethod;
    routePath = rawPath;
  } else if (isRecord(httpEvent)) {
    method = typeof httpEvent.method === 'string' ? httpEvent.method : undefined;
    routePath = typeof httpEvent.path === 'string' ? httpEvent.path : undefined;
  }

  if (!routePath) {
    return;
  }
  const normalizedPath = routePath.startsWith('/') ? routePath : `/${routePath}`;
  const normalizedMethod = (method ?? 'ANY').toUpperCase();
  const known = (HTTP_METHODS as readonly string[]).includes(normalizedMethod);
  out.push(
    restEndpoint(
      known ? normalizedMethod : 'ANY',
      normalizedPath,
      sourceRef(filePath, 'configuration', fnName),
    ),
  );
}

/** A serverless `websocket` event may be a route string or `{ route }` object. */
function scanServerlessWsEvent(
  wsEvent: unknown,
  fnName: string,
  filePath: string,
  out: RawEndpoint[],
): void {
  let route: string | undefined;
  if (typeof wsEvent === 'string') {
    route = wsEvent;
  } else if (isRecord(wsEvent) && typeof wsEvent.route === 'string') {
    route = wsEvent.route;
  }
  if (route) {
    out.push(wsRouteEndpoint(route, sourceRef(filePath, 'configuration', fnName)));
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/** Resolve a `!Ref` / `!GetAtt` / plain-string reference to its target id. */
function refTarget(value: unknown): string | undefined {
  if (typeof value === 'string') {
    return value;
  }
  if (isRecord(value)) {
    if (typeof value.Ref === 'string') {
      return value.Ref;
    }
    const getAtt = value['Fn::GetAtt'];
    if (typeof getAtt === 'string') {
      return getAtt;
    }
    if (Array.isArray(getAtt)) {
      return getAtt.map(String).join('.');
    }
  }
  return undefined;
}

/** Narrow an unknown value to a plain object record. */
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
