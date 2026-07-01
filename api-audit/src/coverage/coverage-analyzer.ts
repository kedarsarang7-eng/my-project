/**
 * Coverage_Analyzer — coverage metric computation (Task 15.1).
 *
 * Computes the five coverage metrics — endpoint, response-validation,
 * security, authentication, and authorization — each as a percentage in
 * [0,100] measured against a 100% Coverage_Target. A metric is marked `met`
 * if and only if its value is at least its target. The analyzer also lists the
 * inventory endpoints that no executed request exercised and, for any metric
 * below target, the endpoints contributing to that gap (including the all-zero
 * case where no requests were executed at all).
 *
 * Design contract (design.md → Coverage_Analyzer):
 *   analyze(inventory: ApiInventory, catalog: CatalogEntry[], runResult: RunResult):
 *     CoverageReport
 *
 * This module owns coverage metric computation (Requirements 12.1, 12.2,
 * 12.3, 12.5, 12.6) and structural gap identification — duplicate routes,
 * unreferenced routes, and endpoints missing documented
 * validation/authorization/error handling (Requirement 12.4). The metric,
 * unexercised, and structural-gap computations are each exported as standalone
 * pure functions so they stay independently testable and composable.
 *
 * The transformation is pure and deterministic: the same inputs always yield
 * the same report, and every emitted list is sorted by endpoint id so repeated
 * runs produce an equivalent report (Requirement 14.3).
 */

import {
  ApiInventory,
  CatalogEntry,
  CoverageMetric,
  CoverageReport,
  InventoryEntry,
  RunResult,
} from '../types';

/**
 * The Coverage_Target applied to every coverage dimension: 100 percent for
 * endpoint, response-validation, security, authentication, and authorization
 * coverage (Requirement 12.5).
 */
export const COVERAGE_TARGET = 100;

/** The five coverage metric names, in their canonical report order. */
export const COVERAGE_METRIC_NAMES = [
  'endpoint',
  'response-validation',
  'security',
  'authentication',
  'authorization',
] as const;

/** The name of one of the five computed coverage metrics. */
export type CoverageMetricName = (typeof COVERAGE_METRIC_NAMES)[number];

/**
 * The Coverage_Analyzer computes coverage metrics and gap lists from the
 * inventory, the catalog, and a test run result, measuring them against the
 * 100% Coverage_Targets (Requirement 12).
 */
export interface CoverageAnalyzer {
  analyze(
    inventory: ApiInventory,
    catalog: CatalogEntry[],
    runResult: RunResult
  ): CoverageReport;
}

/**
 * Builds the coverage report for a run.
 *
 * The metrics and the unexercised-endpoint list are computed by the Task 15.1
 * helpers; the structural-gap fields (`duplicateRoutes`, `unreferencedRoutes`,
 * `missingDocs`) are computed by the Task 15.2 helpers below. Every part is a
 * standalone pure function, so the two tasks stay composable.
 */
export function analyzeCoverage(
  inventory: ApiInventory,
  catalog: CatalogEntry[],
  runResult: RunResult
): CoverageReport {
  return {
    metrics: computeCoverageMetrics(inventory, catalog, runResult),
    unexercisedEndpoints: listUnexercisedEndpoints(inventory, runResult),
    // Structural gap identification (Task 15.2, Requirement 12.4).
    duplicateRoutes: listDuplicateRoutes(inventory),
    unreferencedRoutes: listUnreferencedRoutes(inventory),
    missingDocs: listMissingDocs(catalog),
  };
}

/** Default implementation of the CoverageAnalyzer interface. */
export class DefaultCoverageAnalyzer implements CoverageAnalyzer {
  analyze(
    inventory: ApiInventory,
    catalog: CatalogEntry[],
    runResult: RunResult
  ): CoverageReport {
    return analyzeCoverage(inventory, catalog, runResult);
  }
}

// ---------------------------------------------------------------------------
// Metric computation (Requirements 12.1, 12.2, 12.5, 12.6)
// ---------------------------------------------------------------------------

/**
 * Computes the five coverage metrics in their canonical order.
 *
 * Each metric is the proportion of the inventory endpoints to which the
 * dimension *applies* that were exercised by at least one executed request:
 *
 *   - endpoint            — applies to every inventory endpoint (12.1).
 *   - response-validation — applies to endpoints with a recorded response
 *                           schema, i.e. whose responses can be validated.
 *   - security            — applies to every inventory endpoint (security
 *                           probing targets the whole surface).
 *   - authentication      — applies to endpoints that enforce authentication
 *                           (enforcement `authenticated` or `authorized`).
 *   - authorization       — applies to endpoints that enforce authorization
 *                           (enforcement `authorized`).
 *
 * An empty applicable set is treated as fully covered (value 100), since there
 * is nothing in that dimension left to exercise. When at least one applicable
 * endpoint exists and any of them is unexercised the metric falls below its
 * 100% target, so its `contributingGaps` lists exactly those unexercised
 * applicable endpoints — including the all-zero case where no requests ran
 * (Requirement 12.6).
 */
export function computeCoverageMetrics(
  inventory: ApiInventory,
  catalog: CatalogEntry[],
  runResult: RunResult
): CoverageMetric[] {
  const exercised = exercisedEndpointIds(runResult);
  const catalogById = indexCatalogById(catalog);
  const entries = inventory.entries;

  return [
    buildMetric(
      'endpoint',
      entries.filter(() => true),
      exercised
    ),
    buildMetric(
      'response-validation',
      entries.filter((entry) => requiresResponseValidation(catalogById.get(entry.id))),
      exercised
    ),
    buildMetric(
      'security',
      entries.filter(() => true),
      exercised
    ),
    buildMetric(
      'authentication',
      entries.filter((entry) => requiresAuthentication(catalogById.get(entry.id))),
      exercised
    ),
    buildMetric(
      'authorization',
      entries.filter((entry) => requiresAuthorization(catalogById.get(entry.id))),
      exercised
    ),
  ];
}

/**
 * Builds a single coverage metric over its applicable endpoint set.
 *
 * `value` is the percentage of applicable endpoints exercised by at least one
 * executed request, clamped to [0,100]; an empty applicable set is vacuously
 * 100%. `met` is true iff `value >= target`. `contributingGaps` lists the
 * applicable endpoints that were not exercised, sorted by id — empty exactly
 * when the metric is met.
 */
function buildMetric(
  name: CoverageMetricName,
  applicable: InventoryEntry[],
  exercised: Set<string>
): CoverageMetric {
  const uncovered = applicable
    .filter((entry) => !exercised.has(entry.id))
    .map((entry) => entry.id)
    .sort((a, b) => a.localeCompare(b));

  const coveredCount = applicable.length - uncovered.length;
  const value =
    applicable.length === 0 ? 100 : (coveredCount / applicable.length) * 100;
  const met = value >= COVERAGE_TARGET;

  return {
    name,
    value,
    target: COVERAGE_TARGET,
    met,
    // A met metric has no gaps; an unmet one lists every uncovered applicable
    // endpoint (non-empty whenever applicable endpoints exist) (Requirement 12.6).
    contributingGaps: met ? [] : uncovered,
  };
}

// ---------------------------------------------------------------------------
// Unexercised endpoints (Requirement 12.3)
// ---------------------------------------------------------------------------

/**
 * Lists the inventory endpoints that no executed request exercised — exactly
 * the inventory ids with no matching outcome — sorted by id for deterministic
 * output (Requirement 12.3).
 */
export function listUnexercisedEndpoints(
  inventory: ApiInventory,
  runResult: RunResult
): string[] {
  const exercised = exercisedEndpointIds(runResult);
  return inventory.entries
    .filter((entry) => !exercised.has(entry.id))
    .map((entry) => entry.id)
    .sort((a, b) => a.localeCompare(b));
}

// ---------------------------------------------------------------------------
// Structural gap identification (Requirement 12.4)
// ---------------------------------------------------------------------------

/**
 * Documentation aspects whose absence makes an endpoint structurally
 * under-documented. Each label is what the report records in a `missingDocs`
 * entry's `missing` array, in this canonical order.
 */
export const MISSING_DOC_ASPECTS = [
  'validation',
  'authorization',
  'error-handling',
] as const;

/** One of the documentation aspects tracked by `missingDocs`. */
export type MissingDocAspect = (typeof MISSING_DOC_ASPECTS)[number];

/**
 * Lists the inventory endpoints that resolve to a duplicate route.
 *
 * Two entries are duplicates when they share the same *route signature* — the
 * normalized method, path, and operation name that define the externally
 * observable route (see {@link routeSignature}). Entries that differ only in
 * surface kind, or that carry an identical endpoint identity, therefore collide
 * on the same signature. An endpoint id is returned when its signature is
 * shared by at least one other entry; ids are de-duplicated and sorted for
 * deterministic output (Requirements 12.4, 14.3).
 */
export function listDuplicateRoutes(inventory: ApiInventory): string[] {
  const entriesBySignature = new Map<string, InventoryEntry[]>();
  for (const entry of inventory.entries) {
    const signature = routeSignature(entry);
    const group = entriesBySignature.get(signature);
    if (group) {
      group.push(entry);
    } else {
      entriesBySignature.set(signature, [entry]);
    }
  }

  const duplicateIds = new Set<string>();
  for (const group of entriesBySignature.values()) {
    if (group.length > 1) {
      for (const entry of group) {
        duplicateIds.add(entry.id);
      }
    }
  }

  return [...duplicateIds].sort((a, b) => a.localeCompare(b));
}

/**
 * Lists the inventory endpoints that have no referencing code — routes that
 * were declared (typically only in configuration) but that no application-code
 * source contributes to. An entry is unreferenced when none of its sources is
 * an `artifactType: 'code'` source (including the degenerate case of an entry
 * with no sources at all). Ids are sorted for deterministic output
 * (Requirements 12.4, 14.3).
 */
export function listUnreferencedRoutes(inventory: ApiInventory): string[] {
  return inventory.entries
    .filter((entry) => !entry.sources.some((source) => source.artifactType === 'code'))
    .map((entry) => entry.id)
    .sort((a, b) => a.localeCompare(b));
}

/**
 * Lists the catalog endpoints missing documented validation, authorization, or
 * error handling.
 *
 * For each catalog entry, the undetermined documentation aspects are collected
 * in canonical order ({@link MISSING_DOC_ASPECTS}): `validation` when the
 * validation rules are undetermined, `authorization` when the security
 * enforcement could not be determined, and `error-handling` when the error
 * responses are undetermined. Only endpoints with at least one missing aspect
 * are reported, and the result is sorted by endpoint id for deterministic
 * output (Requirements 12.4, 14.3).
 */
export function listMissingDocs(
  catalog: CatalogEntry[]
): { endpointId: string; missing: string[] }[] {
  return catalog
    .map((entry) => ({ endpointId: entry.id, missing: missingDocAspects(entry) }))
    .filter((record) => record.missing.length > 0)
    .sort((a, b) => a.endpointId.localeCompare(b.endpointId));
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * The route signature of an inventory entry: a stable, normalized key built
 * from the route-defining parts of its identity (method, path, operation
 * name). The method is upper-cased because HTTP methods are case-insensitive;
 * path and operation name are trimmed but otherwise preserved. The surface
 * `kind` is intentionally excluded so that endpoints resolving to the same
 * observable route are recognized as duplicates. Components are joined with a
 * NUL separator that cannot occur inside a route, so distinct component tuples
 * never collide.
 */
function routeSignature(entry: InventoryEntry): string {
  const { method, path, operationName } = entry.identity;
  const normalizedMethod = (method ?? '').trim().toUpperCase();
  const normalizedPath = (path ?? '').trim();
  const normalizedOperation = (operationName ?? '').trim();
  return `${normalizedMethod}\u0000${normalizedPath}\u0000${normalizedOperation}`;
}

/**
 * The undetermined documentation aspects of a catalog entry, in canonical
 * order. Validation and error handling are undetermined when their catalog
 * fields carry the `'undetermined'` sentinel; authorization is undetermined
 * when the security enforcement was recorded as undetermined.
 */
function missingDocAspects(entry: CatalogEntry): MissingDocAspect[] {
  const missing: MissingDocAspect[] = [];
  if (entry.validationRules === 'undetermined') {
    missing.push('validation');
  }
  if (isAuthorizationUndetermined(entry)) {
    missing.push('authorization');
  }
  if (entry.errorResponses === 'undetermined') {
    missing.push('error-handling');
  }
  return missing;
}

/**
 * True when an endpoint's authorization is undocumented — i.e. the security
 * enforcement could not be determined. Security metadata is never the
 * `'undetermined'` sentinel (it defaults to a concrete `public`), so an
 * undetermined determination is signalled by a recorded reason for the
 * security/authorization field instead.
 */
function isAuthorizationUndetermined(entry: CatalogEntry): boolean {
  return SECURITY_REASON_KEYS.some((key) => key in entry.undeterminedReasons);
}

/**
 * The `undeterminedReasons` keys under which a stage may record that an
 * endpoint's authorization/security could not be determined.
 */
const SECURITY_REASON_KEYS = [
  'security',
  'authorization',
  'requiredRole',
  'requiredPermission',
] as const;

/**
 * The set of endpoint ids exercised by at least one executed request. Every
 * outcome represents an executed request regardless of whether its assertions
 * passed, so an endpoint counts as exercised once it has any outcome.
 */
function exercisedEndpointIds(runResult: RunResult): Set<string> {
  const ids = new Set<string>();
  for (const outcome of runResult.outcomes) {
    ids.add(outcome.endpointId);
  }
  return ids;
}

/** Indexes catalog entries by their endpoint id for O(1) lookup. */
function indexCatalogById(catalog: CatalogEntry[]): Map<string, CatalogEntry> {
  const map = new Map<string, CatalogEntry>();
  for (const entry of catalog) {
    map.set(entry.id, entry);
  }
  return map;
}

/**
 * True when an endpoint's responses can be validated — i.e. its catalog entry
 * records a concrete (determined) response schema. Such endpoints make up the
 * applicable set for response-validation coverage.
 */
function requiresResponseValidation(entry: CatalogEntry | undefined): boolean {
  if (!entry) {
    return false;
  }
  const schema = entry.responseSchema;
  return schema !== 'undetermined' && typeof schema === 'object' && schema !== null;
}

/**
 * True when an endpoint enforces authentication — enforcement `authenticated`
 * or `authorized`. These make up the applicable set for authentication
 * coverage.
 */
function requiresAuthentication(entry: CatalogEntry | undefined): boolean {
  if (!entry) {
    return false;
  }
  return (
    entry.security.enforcement === 'authenticated' ||
    entry.security.enforcement === 'authorized'
  );
}

/**
 * True when an endpoint enforces authorization — enforcement `authorized`.
 * These make up the applicable set for authorization coverage.
 */
function requiresAuthorization(entry: CatalogEntry | undefined): boolean {
  if (!entry) {
    return false;
  }
  return entry.security.enforcement === 'authorized';
}
