/**
 * Property-based test for coverage metric correctness (Task 15.3).
 *
 * Feature: api-audit-testing-automation, Property 22: Coverage metrics are
 * computed correctly against targets.
 *
 * Validates: Requirements 12.1, 12.2, 12.3, 12.5, 12.6
 *
 * For any API_Inventory, catalog, and run result, the following are asserted
 * across arbitrary inputs (including the degenerate all-zero case where no
 * requests were executed):
 *
 *   - (12.2) The report contains exactly the five named metrics, in canonical
 *     order: endpoint, response-validation, security, authentication,
 *     authorization.
 *   - (12.5) Every metric value is within [0,100] with a target of 100.
 *   - (12.5) Each metric is marked `met` if and only if its value is at least
 *     its target.
 *   - (12.6) When a metric is below target, its contributing-endpoint gap list
 *     is non-empty (and conversely a met metric has no gaps).
 *   - (12.1) Endpoint coverage equals the proportion of inventory endpoints
 *     exercised by at least one executed request, and its gaps equal exactly
 *     the unexercised endpoints.
 *   - (12.3) The unexercised-endpoint list equals exactly the inventory
 *     endpoints with no executed request.
 */

import fc from 'fast-check';

import {
  analyzeCoverage,
  COVERAGE_METRIC_NAMES,
  COVERAGE_TARGET,
} from './coverage-analyzer';
import {
  ApiInventory,
  CatalogEntry,
  InventoryEntry,
  RequestOutcome,
  RunResult,
  SecurityMeta,
} from '../types';

// Endpoint ids are drawn from a small pool so the same id naturally appears in
// the inventory, the catalog, and the run (exercising overlaps), while the run
// may also reference an id outside the inventory.
const ID_POOL = ['e1', 'e2', 'e3', 'e4', 'e5', 'e6'] as const;

// A minimal REST inventory entry for a given id. Only the id is significant for
// the coverage math; the rest is concrete, valid filler.
function buildEntry(id: string): InventoryEntry {
  return {
    id,
    identity: { kind: 'rest', method: 'GET', path: `/${id}` },
    domain: 'Users',
    sources: [{ filePath: `src/${id}.ts`, artifactType: 'code' }],
  };
}

// A catalog entry for an id whose security enforcement and response-schema
// presence vary, so the response-validation / authentication / authorization
// applicable sets differ across runs.
function buildCatalogEntry(
  id: string,
  enforcement: SecurityMeta['enforcement'],
  hasResponseSchema: boolean
): CatalogEntry {
  return {
    id,
    urlPath: `/${id}`,
    methodOrOperation: 'GET',
    module: 'undetermined',
    controllerOrHandler: 'undetermined',
    requestBodyParams: 'undetermined',
    queryParams: 'undetermined',
    pathParams: 'undetermined',
    headers: 'undetermined',
    security: { enforcement },
    requestSchema: 'undetermined',
    responseSchema: hasResponseSchema ? { type: 'object' } : 'undetermined',
    errorResponses: 'undetermined',
    validationRules: 'undetermined',
    businessRules: 'undetermined',
    undeterminedReasons: {},
  };
}

const enforcementArb: fc.Arbitrary<SecurityMeta['enforcement']> =
  fc.constantFrom('public', 'authenticated', 'authorized');

const outcomeArb = (endpointId: string): fc.Arbitrary<RequestOutcome> =>
  fc.record({
    endpointId: fc.constant(endpointId),
    requestName: fc.string({ minLength: 1, maxLength: 8 }),
    passed: fc.boolean(),
    assertionFailures: fc.array(fc.string({ maxLength: 8 }), { maxLength: 2 }),
    responseTimeMs: fc.double({ min: 0, max: 5000, noNaN: true }),
    statusCode: fc.option(fc.integer({ min: 100, max: 599 }), {
      nil: undefined,
    }),
  });

// A combined model: a unique set of inventory ids (possibly empty), a catalog
// keyed on those ids with varied security/schema, and an arbitrary run whose
// outcomes reference ids from the pool (so some may fall outside the inventory
// and the empty-outcomes all-zero case is reachable).
const modelArb = fc
  .uniqueArray(fc.constantFrom(...ID_POOL), { minLength: 0, maxLength: 6 })
  .chain((ids) =>
    fc.record({
      ids: fc.constant(ids),
      catalogSpec: fc.tuple(
        ...ids.map((id) =>
          fc.record({ enforcement: enforcementArb, hasSchema: fc.boolean() })
            .map((spec) => ({ id, ...spec }))
        )
      ),
      outcomes: fc
        .array(fc.constantFrom(...ID_POOL), { minLength: 0, maxLength: 10 })
        .chain((endpointIds) =>
          fc.tuple(...endpointIds.map((id) => outcomeArb(id)))
        ),
    })
  )
  .map(({ ids, catalogSpec, outcomes }) => {
    const inventory: ApiInventory = {
      entries: ids.map(buildEntry),
      issues: [],
    };
    const catalog: CatalogEntry[] = catalogSpec.map((s) =>
      buildCatalogEntry(s.id, s.enforcement, s.hasSchema)
    );
    const runResult: RunResult = {
      environment: 'Local',
      outcomes,
      allPassed: outcomes.every((o) => o.passed),
    };
    return { inventory, catalog, runResult };
  });

describe('Feature: api-audit-testing-automation, Property 22: Coverage metrics are computed correctly against targets', () => {
  it('computes the five metrics within [0,100] against 100% targets, with met and gaps consistent (12.1, 12.2, 12.3, 12.5, 12.6)', () => {
    fc.assert(
      fc.property(modelArb, ({ inventory, catalog, runResult }) => {
        const report = analyzeCoverage(inventory, catalog, runResult);

        // (12.2) Exactly the five named metrics, in canonical order.
        expect(report.metrics.map((m) => m.name)).toEqual([
          ...COVERAGE_METRIC_NAMES,
        ]);

        for (const metric of report.metrics) {
          // (12.5) Value within [0,100] against a 100% target.
          expect(metric.value).toBeGreaterThanOrEqual(0);
          expect(metric.value).toBeLessThanOrEqual(100);
          expect(metric.target).toBe(COVERAGE_TARGET);

          // (12.5) met iff value >= target.
          expect(metric.met).toBe(metric.value >= metric.target);

          // (12.6) A met metric has no gaps; an unmet one lists at least one.
          if (metric.met) {
            expect(metric.contributingGaps).toEqual([]);
          } else {
            expect(metric.contributingGaps.length).toBeGreaterThan(0);
          }
        }

        // Reference computation of exercised / unexercised endpoints.
        const exercised = new Set(runResult.outcomes.map((o) => o.endpointId));
        const entryIds = inventory.entries.map((e) => e.id);
        const expectedUnexercised = entryIds
          .filter((id) => !exercised.has(id))
          .sort((a, b) => a.localeCompare(b));

        // (12.3) Unexercised list equals exactly the inventory endpoints with
        // no executed request.
        expect(report.unexercisedEndpoints).toEqual(expectedUnexercised);

        // (12.1) Endpoint coverage equals the exercised proportion.
        const covered = entryIds.filter((id) => exercised.has(id)).length;
        const expectedEndpointValue =
          entryIds.length === 0 ? 100 : (covered / entryIds.length) * 100;

        const endpointMetric = report.metrics.find((m) => m.name === 'endpoint');
        expect(endpointMetric).toBeDefined();
        expect(endpointMetric!.value).toBeCloseTo(expectedEndpointValue, 10);

        // Endpoint metric gaps (when unmet) equal exactly the unexercised set.
        if (!endpointMetric!.met) {
          expect(endpointMetric!.contributingGaps).toEqual(expectedUnexercised);
        }
      }),
      { numRuns: 100 }
    );
  });
});
