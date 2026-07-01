/**
 * Collection_Generator — collection structure (Task 7.1).
 *
 * Emits a Postman Collection Format v2.1 collection organized into `Domain`
 * folders, where every endpoint recorded in the API_Catalog is represented by
 * at least one request (Requirements 3.1, 3.2, 3.6).
 *
 * Design contract (design.md → Collection_Generator):
 *   generate(catalog: CatalogEntry[]):
 *     { collection: PostmanCollection; environments: PostmanEnvironment[]; issues: StageIssue[] }
 *
 * This file implements the collection structure only. The five Postman
 * environments (Task 7.2) and explicit non-representable-endpoint failure
 * handling (Task 7.3) are layered on top of the composable building blocks
 * exported here (`buildRequest`, `buildCollection`, `resolveDomain`).
 */

import {
  ApiInventory,
  CatalogEntry,
  Determinable,
  Domain,
  EndpointKind,
  EnvironmentConfig,
  InventoryEntry,
  PostmanCollection,
  PostmanEnvironment,
  PostmanFolder,
  PostmanRequest,
  StageIssue,
} from '../types';

/** Stage name recorded on every generation StageIssue (design → StageIssue). */
const STAGE_NAME = 'generation';

/**
 * Raised when one or more endpoints cannot be represented as a valid Postman
 * request (Requirement 3.7).
 *
 * Per design.md → Error Handling, a non-representable endpoint is a *hard
 * generation failure*: it fails the whole run rather than degrading a single
 * artifact, because downstream stages cannot proceed with an invalid
 * collection. Throwing (instead of returning `issues`) is what signals that
 * hard failure — the carried `issues` record each offending endpoint together
 * with its failure reason so the orchestrator/report layer can surface them
 * (Property 10).
 */
export class CollectionGenerationError extends Error {
  /** One issue per offending endpoint, each carrying `endpointId` + reason. */
  readonly issues: StageIssue[];

  constructor(issues: StageIssue[]) {
    const count = issues.length;
    super(
      `Collection generation failed: ${count} endpoint${
        count === 1 ? '' : 's'
      } cannot be represented as a valid Postman request.`
    );
    this.name = 'CollectionGenerationError';
    this.issues = issues;
    // Restore the prototype chain for instanceof across transpilation targets.
    Object.setPrototypeOf(this, CollectionGenerationError.prototype);
  }
}

/** Postman variable name that resolves to the per-environment base URL (3.4). */
export const BASE_URL_VARIABLE_NAME = 'baseUrl';

/** Postman variable name that resolves to the per-environment auth token (3.4). */
export const AUTH_TOKEN_VARIABLE_NAME = 'authToken';

/** Postman variable reference that resolves to the per-environment base URL (3.4). */
export const BASE_URL_VARIABLE = `{{${BASE_URL_VARIABLE_NAME}}}`;

/** Postman variable reference that resolves to the per-environment auth token (3.4). */
export const AUTH_TOKEN_VARIABLE = `{{${AUTH_TOKEN_VARIABLE_NAME}}}`;

/**
 * Canonical ordering of domain folders. Used to lay out folders
 * deterministically so repeated generation over an unchanged catalog produces
 * an equivalent collection (Requirement 3.8 / Property 26). The set mirrors the
 * domains required by Requirement 3.2 (RBAC, AWS Services, etc. are carried by
 * their `Domain` enum spellings: `Authorization/RBAC`, `AWS-Integrated`).
 */
const DOMAIN_ORDER: Domain[] = [
  'Authentication',
  'Authorization/RBAC',
  'Users',
  'Customers',
  'Products',
  'Inventory',
  'Billing',
  'Invoices',
  'Reports',
  'Search',
  'Settings',
  'License',
  'Subscription',
  'File-Transfer',
  'GraphQL',
  'WebSocket',
  'Admin',
  'AWS-Integrated',
  'Internal-Service',
];

/** HTTP methods recognised for REST requests. */
const HTTP_METHODS = new Set([
  'GET',
  'POST',
  'PUT',
  'PATCH',
  'DELETE',
  'HEAD',
  'OPTIONS',
]);

/**
 * The Collection_Generator turns an API_Catalog into a Postman v2.1 collection
 * (and, in later tasks, the environment set). It is a pure transformation: the
 * same catalog always yields the same collection, keeping runs reproducible.
 */
export interface CollectionGenerator {
  generate(
    catalog: CatalogEntry[],
    inventory?: ApiInventory
  ): {
    collection: PostmanCollection;
    environments: PostmanEnvironment[];
    issues: StageIssue[];
  };
}

/**
 * Generates the Postman collection structure from the API_Catalog.
 *
 * Every catalog entry is mapped to exactly one request, and requests are
 * grouped under folders named after their resolved `Domain` (Requirements 3.1,
 * 3.2, 3.6). When an `ApiInventory` is supplied its authoritative domain
 * classification is used; otherwise the domain is inferred from the catalog
 * entry itself.
 *
 * Before building, every catalog entry is checked for representability
 * (Requirement 3.7). If any endpoint cannot be represented as a valid Postman
 * request, generation fails the run by throwing a {@link CollectionGenerationError}
 * that records one issue per offending endpoint with its failure reason —
 * downstream stages cannot proceed with an invalid collection.
 *
 * @throws {CollectionGenerationError} when one or more endpoints are
 *   non-representable.
 */
export function generateCollection(
  catalog: CatalogEntry[],
  inventory?: ApiInventory
): {
  collection: PostmanCollection;
  environments: PostmanEnvironment[];
  issues: StageIssue[];
} {
  const inventoryById = indexInventory(inventory);

  // Requirement 3.7 — fail the run and record each offending endpoint when any
  // endpoint cannot be represented as a valid Postman request. This runs before
  // any building so a single non-representable endpoint never yields a partial
  // or invalid collection.
  const failures = collectNonRepresentableIssues(catalog, inventoryById);
  if (failures.length > 0) {
    throw new CollectionGenerationError(failures);
  }

  const collection = buildCollection(catalog, inventoryById);

  return {
    collection,
    // Exactly the five required environments, each holding named Postman
    // variables that reference env vars by name (Task 7.2).
    environments: buildEnvironments(),
    // No non-fatal issues arise here: representability is a hard failure
    // (thrown above), and every representable endpoint is emitted as a request.
    issues: [],
  };
}

/** Default implementation of the CollectionGenerator interface. */
export class DefaultCollectionGenerator implements CollectionGenerator {
  generate(
    catalog: CatalogEntry[],
    inventory?: ApiInventory
  ): {
    collection: PostmanCollection;
    environments: PostmanEnvironment[];
    issues: StageIssue[];
  } {
    return generateCollection(catalog, inventory);
  }
}

// ---------------------------------------------------------------------------
// Collection assembly
// ---------------------------------------------------------------------------

/**
 * Builds the domain-organized collection from the catalog. Each entry becomes
 * one request, requests are bucketed by domain, and folders are emitted in the
 * canonical domain order. Within a folder, requests are sorted by endpoint id
 * so the output is fully deterministic (Requirement 3.8).
 */
export function buildCollection(
  catalog: CatalogEntry[],
  inventoryById: Map<string, InventoryEntry>
): PostmanCollection {
  const requestsByDomain = new Map<Domain, PostmanRequest[]>();

  for (const entry of catalog) {
    const inventoryEntry = inventoryById.get(entry.id);
    const domain = resolveDomain(entry, inventoryEntry);
    const request = buildRequest(entry, inventoryEntry);

    const bucket = requestsByDomain.get(domain);
    if (bucket) {
      bucket.push(request);
    } else {
      requestsByDomain.set(domain, [request]);
    }
  }

  const folders: PostmanFolder[] = [];
  for (const domain of DOMAIN_ORDER) {
    const items = requestsByDomain.get(domain);
    if (!items || items.length === 0) {
      continue;
    }
    items.sort((a, b) => a.endpointId.localeCompare(b.endpointId));
    folders.push({ name: domain, items });
  }

  return {
    info: { schema: 'v2.1.0' },
    folders,
  };
}

// ---------------------------------------------------------------------------
// Environment generation (Task 7.2)
// ---------------------------------------------------------------------------

/**
 * Maps each of the five required environments to the env-var *names* that
 * supply its base URL and auth token. These are the same variable names the
 * Config Loader reads from `process.env`, so the generated environments and
 * the runtime configuration stay in lock-step.
 *
 * Only variable *names* live here — never secret values. The generated
 * environment references them through Postman variable syntax so the actual
 * credentials are injected at run time and never written into any artifact
 * (Requirements 3.5, 14.2).
 */
interface EnvironmentVariableSpec {
  name: EnvironmentConfig['name'];
  baseUrlVar: string;
  authTokenVar: string;
}

/**
 * The five environments required by Requirement 3.3, in deterministic order so
 * repeated generation produces an equivalent environment set (Requirement 3.8).
 */
const ENVIRONMENT_VARIABLE_SPECS: readonly EnvironmentVariableSpec[] = [
  { name: 'Development', baseUrlVar: 'DEV_BASE_URL', authTokenVar: 'DEV_AUTH_TOKEN' },
  { name: 'Local', baseUrlVar: 'LOCAL_BASE_URL', authTokenVar: 'LOCAL_AUTH_TOKEN' },
  { name: 'Staging', baseUrlVar: 'STAGING_BASE_URL', authTokenVar: 'STAGING_AUTH_TOKEN' },
  { name: 'AWS', baseUrlVar: 'AWS_BASE_URL', authTokenVar: 'AWS_AUTH_TOKEN' },
  { name: 'Production', baseUrlVar: 'PROD_BASE_URL', authTokenVar: 'PROD_AUTH_TOKEN' },
] as const;

/**
 * Builds exactly the five required Postman environments: Development, Local,
 * Staging, AWS, and Production (Requirement 3.3).
 *
 * Each environment exposes the `baseUrl` and `authToken` Postman variables the
 * collection's requests reference. Their values are *named references* to
 * environment variables (e.g. `{{DEV_AUTH_TOKEN}}`), never the literal secret
 * or connection value, so no credential is ever written into an environment
 * file (Requirements 3.4, 3.5, 14.2).
 */
export function buildEnvironments(): PostmanEnvironment[] {
  return ENVIRONMENT_VARIABLE_SPECS.map(buildEnvironment);
}

/**
 * Builds a single Postman environment from its variable spec. The `baseUrl`
 * and `authToken` variable values are Postman references to the corresponding
 * env-var names, keeping secret values out of the artifact (Requirement 3.5).
 */
function buildEnvironment(spec: EnvironmentVariableSpec): PostmanEnvironment {
  return {
    name: spec.name,
    values: [
      { key: BASE_URL_VARIABLE_NAME, value: toVariableReference(spec.baseUrlVar) },
      { key: AUTH_TOKEN_VARIABLE_NAME, value: toVariableReference(spec.authTokenVar) },
    ],
  };
}

/** Wraps an env-var name in Postman `{{...}}` reference syntax. */
function toVariableReference(envVarName: string): string {
  return `{{${envVarName}}}`;
}

// ---------------------------------------------------------------------------
// Representability (Task 7.3 / Requirement 3.7)
// ---------------------------------------------------------------------------

/**
 * Endpoint kinds whose request path is a fixed, always-valid constant
 * (`/graphql` for GraphQL operations, `/` for WebSocket surfaces). These can
 * always form a valid Postman request and are therefore never
 * non-representable.
 */
const FIXED_PATH_KINDS = new Set<EndpointKind>([
  'graphql-query',
  'graphql-mutation',
  'graphql-subscription',
  'ws-route',
  'ws-event',
]);

/** Control characters that cannot appear in a valid URL. */
const CONTROL_CHARACTERS = /[\u0000-\u001F\u007F]/;

/** Any whitespace character (space, tab, newline, ...). */
const WHITESPACE = /\s/;

/**
 * Scans the catalog and returns one {@link StageIssue} per endpoint that cannot
 * be represented as a valid Postman request (Requirement 3.7). An empty result
 * means every endpoint is representable and generation may proceed.
 */
function collectNonRepresentableIssues(
  catalog: CatalogEntry[],
  inventoryById: Map<string, InventoryEntry>
): StageIssue[] {
  const issues: StageIssue[] = [];

  for (const entry of catalog) {
    const reason = findNonRepresentableReason(entry, inventoryById.get(entry.id));
    if (reason) {
      issues.push({ stage: STAGE_NAME, endpointId: entry.id, reason });
    }
  }

  // Deterministic ordering by endpoint id so a failing run records its issues
  // in a stable order across repeated runs (consistent with Requirement 3.8).
  issues.sort((a, b) => (a.endpointId ?? '').localeCompare(b.endpointId ?? ''));
  return issues;
}

/**
 * Determines whether a single endpoint can be represented as a valid Postman
 * request. Returns a human-readable failure reason when it cannot, or `null`
 * when it can.
 *
 * The contract is deliberately narrow so it does not regress Task 7.1's
 * fallbacks: an *undetermined* URL path is still representable (it resolves to a
 * stable id-based placeholder), and an undetermined/unknown method still
 * resolves to a safe `GET`. An endpoint is non-representable only when its
 * addressing information is *present but fundamentally invalid/contradictory*
 * such that no valid request URL can be formed — for example a concrete URL
 * path containing control characters or embedded whitespace.
 */
export function findNonRepresentableReason(
  entry: CatalogEntry,
  inventoryEntry?: InventoryEntry
): string | null {
  const kind = inventoryEntry?.identity.kind;

  // GraphQL and WebSocket endpoints always target a fixed, valid path, so they
  // can always form a valid Postman request.
  if (kind && FIXED_PATH_KINDS.has(kind)) {
    return null;
  }

  // REST (and kind-less catalog entries): an undetermined URL path is handled
  // by the stable id-based fallback (Task 7.1) and remains representable. Only
  // a determined-but-malformed path is non-representable.
  if (typeof entry.urlPath === 'string' && entry.urlPath !== 'undetermined') {
    return invalidUrlPathReason(entry.urlPath);
  }

  return null;
}

/**
 * Returns a failure reason when a concrete (determined) URL path cannot form a
 * valid Postman request URL, or `null` when it is usable.
 *
 * A determined-but-empty/whitespace-only path is NOT a failure: it normalizes
 * to the root path `/`, which is a valid request URL. A path is only rejected
 * when it carries characters that cannot appear in a valid URL — control
 * characters or embedded whitespace — i.e. genuinely contradictory addressing.
 */
function invalidUrlPathReason(rawPath: string): string | null {
  const trimmed = rawPath.trim();

  // Empty / whitespace-only resolves to '/', which is representable.
  if (trimmed.length === 0) {
    return null;
  }

  if (CONTROL_CHARACTERS.test(trimmed)) {
    return `URL path contains control characters and cannot form a valid Postman request URL: ${JSON.stringify(
      rawPath
    )}`;
  }

  if (WHITESPACE.test(trimmed)) {
    return `URL path contains embedded whitespace and cannot form a valid Postman request URL: ${JSON.stringify(
      rawPath
    )}`;
  }

  return null;
}

// ---------------------------------------------------------------------------
// Request building
// ---------------------------------------------------------------------------

/**
 * Builds a single Postman v2.1 request from a catalog entry.
 *
 * The request URL is expressed with the `{{baseUrl}}` Postman variable so the
 * per-environment base URL is substituted at run time and no concrete host is
 * baked into the collection (Requirement 3.4). Path parameters keep their
 * source spelling (`:id` or `{id}`); request bodies and auth headers are added
 * later by the Test_Generator and the environment/auth wiring.
 */
export function buildRequest(
  entry: CatalogEntry,
  inventoryEntry?: InventoryEntry
): PostmanRequest {
  const kind = inventoryEntry?.identity.kind;
  const method = resolveMethod(entry.methodOrOperation, kind);
  const path = resolvePath(entry, inventoryEntry);

  return {
    name: buildRequestName(method, path, entry, inventoryEntry),
    endpointId: entry.id,
    method,
    url: joinUrl(BASE_URL_VARIABLE, path),
  };
}

/**
 * Resolves the HTTP method for a request. REST endpoints use their documented
 * method (defaulting to GET when undetermined); GraphQL operations are issued
 * over POST; WebSocket surfaces are represented with GET as a stable default.
 */
function resolveMethod(
  methodOrOperation: Determinable<string>,
  kind?: EndpointKind
): string {
  if (kind === 'graphql-query' || kind === 'graphql-mutation' || kind === 'graphql-subscription') {
    return 'POST';
  }
  if (kind === 'ws-route' || kind === 'ws-event') {
    return 'GET';
  }

  if (typeof methodOrOperation === 'string' && methodOrOperation !== 'undetermined') {
    const upper = methodOrOperation.toUpperCase();
    if (HTTP_METHODS.has(upper)) {
      return upper;
    }
  }

  // REST endpoint with an undetermined/unknown method: GET is the safe,
  // side-effect-free default for a representable request.
  return 'GET';
}

/**
 * Resolves the request path. GraphQL operations target a `/graphql` path and
 * WebSocket surfaces target the root; REST endpoints use their documented URL
 * path, falling back to a stable id-based path when the URL is undetermined so
 * the endpoint is still represented (Requirement 3.6).
 */
function resolvePath(entry: CatalogEntry, inventoryEntry?: InventoryEntry): string {
  const kind = inventoryEntry?.identity.kind;

  if (kind === 'graphql-query' || kind === 'graphql-mutation' || kind === 'graphql-subscription') {
    return '/graphql';
  }
  if (kind === 'ws-route' || kind === 'ws-event') {
    return '/';
  }

  if (typeof entry.urlPath === 'string' && entry.urlPath !== 'undetermined') {
    return normalizePath(entry.urlPath);
  }

  // The URL path is undetermined but the endpoint must still be representable;
  // derive a stable placeholder path from the endpoint id.
  return `/undetermined/${entry.id}`;
}

/**
 * Builds a human-readable request name. Prefers the operation name for
 * GraphQL/WebSocket surfaces, otherwise uses `METHOD path`.
 */
function buildRequestName(
  method: string,
  path: string,
  entry: CatalogEntry,
  inventoryEntry?: InventoryEntry
): string {
  const operationName = inventoryEntry?.identity.operationName;
  if (operationName && operationName.length > 0) {
    return operationName;
  }
  return `${method} ${path}`;
}

// ---------------------------------------------------------------------------
// Domain resolution
// ---------------------------------------------------------------------------

/**
 * Resolves the `Domain` folder an entry belongs to. The inventory's
 * authoritative classification is used when available; otherwise the domain is
 * inferred from the catalog entry's operation type and URL path. The result is
 * always a valid `Domain` (Property 7).
 */
export function resolveDomain(
  entry: CatalogEntry,
  inventoryEntry?: InventoryEntry
): Domain {
  if (inventoryEntry) {
    return inventoryEntry.domain;
  }
  return inferDomain(entry);
}

/**
 * Best-effort domain inference from catalog metadata when no inventory entry is
 * available. Falls back to `Internal-Service` so the result is always a valid
 * `Domain`.
 */
function inferDomain(entry: CatalogEntry): Domain {
  const operation =
    typeof entry.methodOrOperation === 'string' ? entry.methodOrOperation.toLowerCase() : '';

  if (operation === 'query' || operation === 'mutation' || operation === 'subscription') {
    return 'GraphQL';
  }
  if (operation === 'ws-route' || operation === 'ws-event') {
    return 'WebSocket';
  }

  const haystack = [
    typeof entry.urlPath === 'string' ? entry.urlPath : '',
    typeof entry.module === 'string' ? entry.module : '',
    typeof entry.controllerOrHandler === 'string' ? entry.controllerOrHandler : '',
  ]
    .join(' ')
    .toLowerCase();

  for (const [keyword, domain] of DOMAIN_KEYWORDS) {
    if (haystack.includes(keyword)) {
      return domain;
    }
  }

  return 'Internal-Service';
}

/**
 * Keyword → Domain table for catalog-only inference. Ordered most-specific
 * first so the earliest match wins deterministically.
 */
const DOMAIN_KEYWORDS: ReadonlyArray<readonly [string, Domain]> = [
  ['auth', 'Authentication'],
  ['login', 'Authentication'],
  ['rbac', 'Authorization/RBAC'],
  ['role', 'Authorization/RBAC'],
  ['permission', 'Authorization/RBAC'],
  ['user', 'Users'],
  ['customer', 'Customers'],
  ['product', 'Products'],
  ['inventory', 'Inventory'],
  ['stock', 'Inventory'],
  ['billing', 'Billing'],
  ['invoice', 'Invoices'],
  ['report', 'Reports'],
  ['search', 'Search'],
  ['setting', 'Settings'],
  ['license', 'License'],
  ['subscription', 'Subscription'],
  ['upload', 'File-Transfer'],
  ['file', 'File-Transfer'],
  ['download', 'File-Transfer'],
  ['admin', 'Admin'],
  ['cognito', 'AWS-Integrated'],
  ['dynamo', 'AWS-Integrated'],
  ['s3', 'AWS-Integrated'],
  ['lambda', 'AWS-Integrated'],
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Builds a per-id lookup of inventory entries for domain/kind resolution. */
function indexInventory(inventory?: ApiInventory): Map<string, InventoryEntry> {
  const map = new Map<string, InventoryEntry>();
  if (!inventory) {
    return map;
  }
  for (const entry of inventory.entries) {
    map.set(entry.id, entry);
  }
  return map;
}

/** Ensures a path begins with a single leading slash. */
function normalizePath(path: string): string {
  const trimmed = path.trim();
  if (trimmed.length === 0) {
    return '/';
  }
  return trimmed.startsWith('/') ? trimmed : `/${trimmed}`;
}

/** Joins the base-URL variable with a path, avoiding a doubled slash. */
function joinUrl(baseUrlVariable: string, path: string): string {
  if (path === '/') {
    return baseUrlVariable;
  }
  return `${baseUrlVariable}${path.startsWith('/') ? path : `/${path}`}`;
}
