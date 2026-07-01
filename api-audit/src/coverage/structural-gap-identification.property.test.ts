/**
 * Property-based test for structural gap identification (Task 15.4).
 *
 * Feature: api-audit-testing-automation, Property 23: Structural gap
 * identification.
 *
 * Validates: Requirements 12.4
 *
 * For any API_Inventory and API_Catalog, the Coverage_Analyzer's
 * duplicate-route, unreferenced-route, and missing-documentation lists equal
 * exactly the sets defined by those conditions:
 *
 *   - duplicateRoutes    — every inventory endpoint whose route signature
 *                          (normalized method + path + operation name, surface
 *                          kind excluded) is shared by at least one other
 *                          entry.
 *   - unreferencedRoutes — every inventory endpoint with no referencing code,
 *                          i.e. no `artifactType: 'code'` source (including an
 *                          entry with no sources at all).
 *   - missingDocs        — every catalog endpoint missing documented
 *                          validation, authorization, or error handling, in
 *                          canonical aspect order.
 *
 * The expected sets are recomputed independently from a reference model so the
 * test pins the *defined* conditions rather than echoing the implementation.
 */

import fc from 'fast-check';

import { analyzeCoverage } from './coverage-analyzer';
import {
  ApiInventory,
  CatalogEntry,
  EndpointIdentity,
  EndpointKind,
  InventoryEntry,
  RunResult,
  SourceRef,
} from '../types';

// Small component pools so identical route signatures (and therefore
// duplicates) arise naturally. `method` and `path` include case/whitespace
// variants so the reference and the analyzer must agree on normalization.
const KIND_POOL: EndpointKind[] = ['rest', 'graphql-query', 'ws-route'];
const METHOD_POOL: (string | undefined)[] = [undefined, 'GET', 'POST', 'get'];
const PATH_POOL: (string | undefined)[] = [undefined, '/a', '/b', ' /a '];
const OPERATION_POOL: (string | undefined)[] = [undefined, 'op1', 'op2'];

// The artifact types a source may carry; only `code` makes a route referenced.
const ARTIFACT_POOL: SourceRef['artifactType'][] = ['code', 'configuration'];

// The reasons keys under which a stage records undetermined authorization, plus
// an unrelated key ('other') that must NOT count as a missing authorization.
const REASON_POOL = [
  'security',
  'authorization',
  'requiredRole',
  'requiredPermission',
  'other',
] as const;

// A spec for one inventory entry; ids are assigned by index so they stay unique.
const entrySpecArb = fc.record({
  kind: fc.constantFrom(...KIND_POOL),
  method: fc.constantFrom(...METHOD_POOL),
  path: fc.constantFrom(...PATH_POOL),
  operationName: fc.constantFrom(...OPERATION_POOL),
  sources: fc.array(
    fc.record({
      filePath: fc.string({ minLength: 1, maxLength: 8 }),
      artifactType: fc.constantFrom(...ARTIFACT_POOL),
    }),
    { maxLength: 3 }
  ),
});

// A spec for one catalog entry; each missing-doc condition is toggled
// independently, and the security reason key is optional (undefined => none).
const catalogSpecArb = fc.record({
  missingValidation: fc.boolean(),
  missingErrorHandling: fc.boolean(),
  reasonKey: fc.option(fc.constantFrom(...REASON_POOL), { nil: undefined }),
});

const modelArb = fc
  .record({
    entrySpecs: fc.array(entrySpecArb, { maxLength: 8 }),
    catalogSpecs: fc.array(catalogSpecArb, { maxLength: 8 }),
  })
  .map(({ entrySpecs, catalogSpecs }) => {
    const inventory: ApiInventory = {
      entries: entrySpecs.map((spec, i) => ({
        id: `e${i}`,
        identity: {
          kind: spec.kind,
          method: spec.method,
          path: spec.path,
          operationName: spec.operationName,
        },
        domain: 'Users',
        sources: spec.sources,
      })),
      issues: [],
    };

    const catalog: CatalogEntry[] = catalogSpecs.map((spec, i) =>
      buildCatalogEntry(`c${i}`, spec)
    );

    return { inventory, catalog };
  });

// Builds a catalog entry whose validation / authorization / error-handling
// documentation presence is driven by the spec; all other fields are concrete
// filler that never triggers a missing-doc aspect.
function buildCatalogEntry(
  id: string,
  spec: {
    missingValidation: boolean;
    missingErrorHandling: boolean;
    reasonKey: string | undefined;
  }
): CatalogEntry {
  return {
    id,
    urlPath: `/${id}`,
    methodOrOperation: 'GET',
    module: 'm',
    controllerOrHandler: 'h',
    requestBodyParams: [],
    queryParams: [],
    pathParams: [],
    headers: [],
    security: { enforcement: 'public' },
    requestSchema: { type: 'object' },
    responseSchema: { type: 'object' },
    errorResponses: spec.missingErrorHandling ? 'undetermined' : [],
    validationRules: spec.missingValidation ? 'undetermined' : [],
    businessRules: [],
    undeterminedReasons: spec.reasonKey ? { [spec.reasonKey]: 'reason' } : {},
  };
}

// ---------------------------------------------------------------------------
// Independent reference computations of the three defined gap sets.
// ---------------------------------------------------------------------------

// Mirrors the defined route signature: normalized method (upper-cased) + path +
// operation name, surface kind excluded, joined by a NUL that cannot occur in a
// route component.
function referenceSignature(identity: EndpointIdentity): string {
  const method = (identity.method ?? '').trim().toUpperCase();
  const path = (identity.path ?? '').trim();
  const operation = (identity.operationName ?? '').trim();
  return `${method}\u0000${path}\u0000${operation}`;
}

function expectedDuplicateRoutes(inventory: ApiInventory): string[] {
  const bySignature = new Map<string, InventoryEntry[]>();
  for (const entry of inventory.entries) {
    const sig = referenceSignature(entry.identity);
    const group = bySignature.get(sig) ?? [];
    group.push(entry);
    bySignature.set(sig, group);
  }
  const ids: string[] = [];
  for (const group of bySignature.values()) {
    if (group.length > 1) {
      ids.push(...group.map((e) => e.id));
    }
  }
  return ids.sort((a, b) => a.localeCompare(b));
}

function expectedUnreferencedRoutes(inventory: ApiInventory): string[] {
  return inventory.entries
    .filter((e) => !e.sources.some((s) => s.artifactType === 'code'))
    .map((e) => e.id)
    .sort((a, b) => a.localeCompare(b));
}

const SECURITY_REASON_KEYS = new Set([
  'security',
  'authorization',
  'requiredRole',
  'requiredPermission',
]);

function expectedMissingDocs(
  catalog: CatalogEntry[]
): { endpointId: string; missing: string[] }[] {
  return catalog
    .map((entry) => {
      const missing: string[] = [];
      if (entry.validationRules === 'undetermined') {
        missing.push('validation');
      }
      if (
        Object.keys(entry.undeterminedReasons).some((k) =>
          SECURITY_REASON_KEYS.has(k)
        )
      ) {
        missing.push('authorization');
      }
      if (entry.errorResponses === 'undetermined') {
        missing.push('error-handling');
      }
      return { endpointId: entry.id, missing };
    })
    .filter((r) => r.missing.length > 0)
    .sort((a, b) => a.endpointId.localeCompare(b.endpointId));
}

describe('Feature: api-audit-testing-automation, Property 23: Structural gap identification', () => {
  it('duplicate-route, unreferenced-route, and missing-doc lists equal exactly the defined sets (12.4)', () => {
    fc.assert(
      fc.property(modelArb, ({ inventory, catalog }) => {
        // Structural gaps are independent of the run; a trivial run suffices.
        const runResult: RunResult = {
          environment: 'Local',
          outcomes: [],
          allPassed: true,
        };

        const report = analyzeCoverage(inventory, catalog, runResult);

        expect(report.duplicateRoutes).toEqual(
          expectedDuplicateRoutes(inventory)
        );
        expect(report.unreferencedRoutes).toEqual(
          expectedUnreferencedRoutes(inventory)
        );
        expect(report.missingDocs).toEqual(expectedMissingDocs(catalog));
      }),
      { numRuns: 100 }
    );
  });
});
