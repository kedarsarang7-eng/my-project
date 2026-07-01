/**
 * Documentation_Engine stage.
 *
 * Enriches each inventory entry into an API_Catalog entry, marking
 * undeterminable fields as "undetermined" with a recorded reason
 * (Requirement 2).
 *
 * Design contract (design.md → Documentation_Engine):
 *   document(inventory: ApiInventory): { catalog: CatalogEntry[]; issues: StageIssue[] }
 *
 * Guarantees implemented here:
 *  - Exactly one CatalogEntry per InventoryEntry, including entries whose
 *    source processing failed (Requirement 2.1).
 *  - URL/method/module/handler, params, schemas, errors, validation and
 *    business rules are recorded when derivable from the inventory entry
 *    (Requirements 2.2, 2.3, 2.5, 2.6).
 *  - Security metadata is always present and defaults to `public` when no
 *    enforcement is recorded (Requirement 2.4).
 *  - Any field that cannot be determined is set to the literal
 *    "undetermined" and a matching reason is recorded (Requirement 2.7).
 */

import {
  ApiInventory,
  BusinessRule,
  CatalogEntry,
  Determinable,
  EndpointIdentity,
  ErrorResponse,
  InventoryEntry,
  JsonSchema,
  ParamSpec,
  SecurityMeta,
  SourceRef,
  StageIssue,
  ValidationRule,
} from '../types';

/** The stage name recorded on any StageIssue this engine emits. */
const STAGE_NAME = 'documentation';

/**
 * The Documentation_Engine turns a deduplicated API_Inventory into a
 * per-endpoint API_Catalog. It is a pure transformation: the same inventory
 * always yields the same catalog, which keeps audit runs reproducible
 * (Requirement 14.3).
 */
export interface DocumentationEngine {
  document(inventory: ApiInventory): {
    catalog: CatalogEntry[];
    issues: StageIssue[];
  };
}

/**
 * Builds the API_Catalog from an API_Inventory.
 *
 * Every inventory entry produces exactly one catalog entry. Inventory entries
 * referenced by a discovery `StageIssue` (i.e. their source could not be fully
 * processed) still produce a catalog entry whose unresolved fields are marked
 * "undetermined" (Requirement 2.1).
 */
export function documentInventory(inventory: ApiInventory): {
  catalog: CatalogEntry[];
  issues: StageIssue[];
} {
  const issues: StageIssue[] = [];

  // Pre-index discovery issues by endpoint id so a failed-source entry can
  // explain *why* its fields are undetermined rather than giving a generic
  // reason.
  const issuesByEndpoint = indexIssuesByEndpoint(inventory.issues);

  const catalog = inventory.entries.map((entry) =>
    documentEntry(entry, issuesByEndpoint.get(entry.id), issues)
  );

  return { catalog, issues };
}

/** Default implementation of the DocumentationEngine interface. */
export class DefaultDocumentationEngine implements DocumentationEngine {
  document(inventory: ApiInventory): {
    catalog: CatalogEntry[];
    issues: StageIssue[];
  } {
    return documentInventory(inventory);
  }
}

// ---------------------------------------------------------------------------
// Per-entry enrichment
// ---------------------------------------------------------------------------

/**
 * Enriches a single inventory entry into a catalog entry.
 *
 * `sourceIssues` are any discovery-stage issues attached to this endpoint id;
 * when present they signal a failed-source entry and are folded into the
 * undetermined reasons.
 */
function documentEntry(
  entry: InventoryEntry,
  sourceIssues: StageIssue[] | undefined,
  issues: StageIssue[]
): CatalogEntry {
  const identity = entry.identity;
  const reasons: Record<string, string> = {};

  // A failed-source entry: discovery recorded a problem for this endpoint, so
  // most derived fields are inherently unreliable. We still emit the entry.
  const failedReason =
    sourceIssues && sourceIssues.length > 0
      ? `source processing failed: ${sourceIssues
          .map((i) => i.reason)
          .join('; ')}`
      : undefined;

  if (failedReason) {
    issues.push({
      stage: STAGE_NAME,
      endpointId: entry.id,
      reason: `documented endpoint with failed source; affected fields marked undetermined`,
    });
  }

  const codeSource = pickPrimaryCodeSource(entry.sources);

  const urlPath = resolveUrlPath(identity, reasons, failedReason);
  const methodOrOperation = resolveMethodOrOperation(
    identity,
    reasons,
    failedReason
  );
  const module = resolveModule(codeSource, reasons, failedReason);
  const controllerOrHandler = resolveControllerOrHandler(
    codeSource,
    reasons,
    failedReason
  );
  const pathParams = resolvePathParams(urlPath, reasons, failedReason);

  // The following fields require deeper per-source body/schema analysis that
  // the inventory does not carry. They are explicitly undetermined until a
  // richer discovery stage supplies them (Requirement 2.7).
  const requestBodyParams = undetermined<ParamSpec[]>(
    'requestBodyParams',
    reasons,
    failedReason ?? 'request body parameters require source body analysis'
  );
  const queryParams = undetermined<ParamSpec[]>(
    'queryParams',
    reasons,
    failedReason ?? 'query parameters require source body analysis'
  );
  const headers = undetermined<ParamSpec[]>(
    'headers',
    reasons,
    failedReason ?? 'request headers require source body analysis'
  );
  const requestSchema = undetermined<JsonSchema>(
    'requestSchema',
    reasons,
    failedReason ?? 'request schema is not recorded in the inventory'
  );
  const responseSchema = undetermined<JsonSchema>(
    'responseSchema',
    reasons,
    failedReason ?? 'response schema is not recorded in the inventory'
  );
  const errorResponses = undetermined<ErrorResponse[]>(
    'errorResponses',
    reasons,
    failedReason ?? 'error responses require source/handler analysis'
  );
  const validationRules = undetermined<ValidationRule[]>(
    'validationRules',
    reasons,
    failedReason ?? 'validation rules require source/schema analysis'
  );
  const businessRules = undetermined<BusinessRule[]>(
    'businessRules',
    reasons,
    failedReason ?? 'business rules require source/handler analysis'
  );

  // Security metadata is never empty. The inventory carries no enforcement
  // signal, so we default to `public` per Requirement 2.4. (This is a concrete
  // value, not "undetermined".)
  const security: SecurityMeta = { enforcement: 'public' };

  return {
    id: entry.id,
    urlPath,
    methodOrOperation,
    module,
    controllerOrHandler,
    requestBodyParams,
    queryParams,
    pathParams,
    headers,
    security,
    requestSchema,
    responseSchema,
    errorResponses,
    validationRules,
    businessRules,
    undeterminedReasons: reasons,
  };
}

// ---------------------------------------------------------------------------
// Field resolvers
// ---------------------------------------------------------------------------

/** Resolves the URL path from the endpoint identity when one is recorded. */
function resolveUrlPath(
  identity: EndpointIdentity,
  reasons: Record<string, string>,
  failedReason?: string
): Determinable<string> {
  if (!failedReason && typeof identity.path === 'string' && identity.path.length > 0) {
    return identity.path;
  }

  if (failedReason) {
    return undetermined('urlPath', reasons, failedReason);
  }

  // GraphQL operations and WebSocket events are addressed by operation/event
  // name rather than a URL path, so an absent path is expected for them.
  const isOperationAddressed =
    identity.kind === 'graphql-query' ||
    identity.kind === 'graphql-mutation' ||
    identity.kind === 'graphql-subscription' ||
    identity.kind === 'ws-event';

  const reason = isOperationAddressed
    ? `${identity.kind} endpoints are addressed by operation name, not a URL path`
    : 'no URL path recorded in the inventory identity';

  return undetermined('urlPath', reasons, reason);
}

/**
 * Resolves the HTTP method (REST) or operation type (GraphQL/WebSocket).
 *
 * The operation type is always derivable from the endpoint kind; only a REST
 * entry missing its method is undetermined.
 */
function resolveMethodOrOperation(
  identity: EndpointIdentity,
  reasons: Record<string, string>,
  failedReason?: string
): Determinable<string> {
  if (failedReason) {
    return undetermined('methodOrOperation', reasons, failedReason);
  }

  if (identity.kind === 'rest') {
    if (typeof identity.method === 'string' && identity.method.length > 0) {
      return identity.method.toUpperCase();
    }
    return undetermined(
      'methodOrOperation',
      reasons,
      'REST endpoint has no HTTP method recorded in the inventory identity'
    );
  }

  // Non-REST kinds map directly to a human-readable operation type.
  const operationTypeByKind: Record<EndpointIdentity['kind'], string> = {
    rest: 'rest',
    'graphql-query': 'query',
    'graphql-mutation': 'mutation',
    'graphql-subscription': 'subscription',
    'ws-route': 'ws-route',
    'ws-event': 'ws-event',
  };

  return operationTypeByKind[identity.kind];
}

/** Resolves the owning module from the primary code source file path. */
function resolveModule(
  codeSource: SourceRef | undefined,
  reasons: Record<string, string>,
  failedReason?: string
): Determinable<string> {
  if (failedReason) {
    return undetermined('module', reasons, failedReason);
  }
  if (!codeSource) {
    return undetermined(
      'module',
      reasons,
      'no code source available to infer the owning module'
    );
  }

  const moduleName = inferModuleName(codeSource.filePath);
  if (moduleName) {
    return moduleName;
  }
  return undetermined(
    'module',
    reasons,
    `could not infer an owning module from source path "${codeSource.filePath}"`
  );
}

/** Resolves the owning controller/handler from the primary code source. */
function resolveControllerOrHandler(
  codeSource: SourceRef | undefined,
  reasons: Record<string, string>,
  failedReason?: string
): Determinable<string> {
  if (failedReason) {
    return undetermined('controllerOrHandler', reasons, failedReason);
  }
  if (!codeSource) {
    return undetermined(
      'controllerOrHandler',
      reasons,
      'no code source available to infer the owning controller or handler'
    );
  }

  const handler = inferHandlerName(codeSource.filePath);
  if (handler) {
    return handler;
  }
  return undetermined(
    'controllerOrHandler',
    reasons,
    `could not infer a controller or handler from source path "${codeSource.filePath}"`
  );
}

/**
 * Resolves path parameters by parsing the URL path. Supports both Express
 * (`:id`) and OpenAPI/API Gateway (`{id}`) styles. When the URL path itself is
 * undetermined, path parameters are undetermined too.
 */
function resolvePathParams(
  urlPath: Determinable<string>,
  reasons: Record<string, string>,
  failedReason?: string
): Determinable<ParamSpec[]> {
  if (failedReason) {
    return undetermined('pathParams', reasons, failedReason);
  }
  if (urlPath === 'undetermined') {
    return undetermined(
      'pathParams',
      reasons,
      'path parameters cannot be derived because the URL path is undetermined'
    );
  }
  // A concrete path with no parameters yields an empty (but determined) list.
  return extractPathParams(urlPath);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Marks a field undetermined: records the reason and returns the literal
 * "undetermined" value. Centralizing this keeps the
 * "undetermined ⇒ reason recorded" invariant (Property 6) impossible to break.
 */
function undetermined<T>(
  field: string,
  reasons: Record<string, string>,
  reason: string
): Determinable<T> {
  reasons[field] = reason;
  return 'undetermined';
}

/** Groups discovery issues by the endpoint id they reference. */
function indexIssuesByEndpoint(issues: StageIssue[]): Map<string, StageIssue[]> {
  const map = new Map<string, StageIssue[]>();
  for (const issue of issues) {
    if (!issue.endpointId) {
      continue;
    }
    const existing = map.get(issue.endpointId);
    if (existing) {
      existing.push(issue);
    } else {
      map.set(issue.endpointId, [issue]);
    }
  }
  return map;
}

/**
 * Picks a single, deterministic code source from an entry's sources. When an
 * endpoint is attributed to several code files we choose the lexicographically
 * smallest path so repeated runs document the same owning file.
 */
function pickPrimaryCodeSource(sources: SourceRef[]): SourceRef | undefined {
  const codeSources = sources
    .filter((s) => s.artifactType === 'code')
    .sort((a, b) => a.filePath.localeCompare(b.filePath));
  return codeSources[0];
}

/** Normalizes a path to use forward slashes and splits into non-empty parts. */
function pathSegments(filePath: string): string[] {
  return filePath
    .replace(/\\/g, '/')
    .split('/')
    .filter((s) => s.length > 0);
}

/**
 * Infers an owning module name from a source file path using the project's
 * known layout (`my-backend/src/...` and top-level `lambda/`).
 */
function inferModuleName(filePath: string): string | undefined {
  const segments = pathSegments(filePath);
  if (segments.length === 0) {
    return undefined;
  }

  // `.../src/modules/<module>/...` → the module sub-folder is the best signal.
  const modulesIdx = segments.indexOf('modules');
  if (modulesIdx >= 0 && segments[modulesIdx + 1]) {
    return segments[modulesIdx + 1];
  }

  // `.../src/<group>/...` → the directory directly under `src` (routes,
  // controllers, services, websocket, handlers, ...).
  const srcIdx = segments.lastIndexOf('src');
  if (srcIdx >= 0 && segments[srcIdx + 1]) {
    return segments[srcIdx + 1];
  }

  // Top-level `lambda/...` handlers.
  const lambdaIdx = segments.indexOf('lambda');
  if (lambdaIdx >= 0) {
    return segments[lambdaIdx + 1] ? segments[lambdaIdx + 1] : 'lambda';
  }

  return undefined;
}

/**
 * Infers the controller/handler name from a source file: the file's base name
 * without its extension (e.g. `customer.controller.ts` → `customer.controller`).
 */
function inferHandlerName(filePath: string): string | undefined {
  const segments = pathSegments(filePath);
  const fileName = segments[segments.length - 1];
  if (!fileName) {
    return undefined;
  }
  const dotIdx = fileName.lastIndexOf('.');
  const base = dotIdx > 0 ? fileName.slice(0, dotIdx) : fileName;
  return base.length > 0 ? base : undefined;
}

/**
 * Extracts path parameters from a URL path, supporting Express (`:name`) and
 * OpenAPI/API Gateway (`{name}`) styles. The result is deduplicated and sorted
 * by name for deterministic output.
 */
function extractPathParams(path: string): ParamSpec[] {
  const names = new Set<string>();

  const colonStyle = /:([A-Za-z0-9_]+)/g;
  const braceStyle = /\{([A-Za-z0-9_]+)\}/g;

  let match: RegExpExecArray | null;
  while ((match = colonStyle.exec(path)) !== null) {
    names.add(match[1]);
  }
  while ((match = braceStyle.exec(path)) !== null) {
    names.add(match[1]);
  }

  return Array.from(names)
    .sort((a, b) => a.localeCompare(b))
    .map((name) => ({ name, in: 'path', required: true } as ParamSpec));
}
