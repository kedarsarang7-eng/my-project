/**
 * Property-based test for the Local-vs-AWS comparison (Task 16.1).
 *
 * Feature: api-audit-testing-automation, Property 21: Local-vs-AWS comparison
 * and environment-specific classification.
 *
 * Validates: Requirements 11.4, 11.5
 *
 * For any pair of local and AWS run results, two behaviours are asserted across
 * arbitrary outcome sets:
 *
 *   1. (11.4) The comparison contains exactly one row per request appearing in
 *      either run, keyed on `endpointId`. The set of row endpoint ids equals
 *      the union of the endpoint ids appearing in the local and AWS runs, and
 *      each row carries the correct local and AWS outcome (the first reported
 *      outcome for that endpoint id within each run, or absent when the request
 *      only appears in the other run).
 *   2. (11.5) A request is classified as an environment-specific issue if and
 *      only if it passed locally and failed on AWS. The `environmentSpecific`
 *      flag and the `environmentSpecificIssues` list both reflect this iff.
 */

import fc from 'fast-check';

import { compareRuns } from './local-vs-aws';
import { RequestOutcome, RunResult } from '../types';

// A single request outcome. Endpoint ids are drawn from a small alphabet so
// the same id naturally appears in both runs (exercising the merge) and more
// than once within a run (exercising the first-wins indexing).
const outcomeArb: fc.Arbitrary<RequestOutcome> = fc.record({
  endpointId: fc.constantFrom('a', 'b', 'c', 'd', 'e'),
  requestName: fc.string({ minLength: 1, maxLength: 8 }),
  passed: fc.boolean(),
  assertionFailures: fc.array(fc.string({ maxLength: 12 }), { maxLength: 3 }),
  responseTimeMs: fc.double({ min: 0, max: 5000, noNaN: true }),
  statusCode: fc.option(fc.integer({ min: 100, max: 599 }), { nil: undefined }),
});

// A run result for a given environment built from arbitrary outcomes.
function runResultArb(
  environment: RunResult['environment']
): fc.Arbitrary<RunResult> {
  return fc
    .array(outcomeArb, { minLength: 0, maxLength: 10 })
    .map((outcomes) => ({
      environment,
      outcomes,
      allPassed: outcomes.every((o) => o.passed),
    }));
}

// The first outcome reported for an endpoint id within a run, mirroring the
// implementation's first-wins indexing.
function firstByEndpoint(
  outcomes: RequestOutcome[]
): Map<string, RequestOutcome> {
  const byEndpoint = new Map<string, RequestOutcome>();
  for (const outcome of outcomes) {
    if (!byEndpoint.has(outcome.endpointId)) {
      byEndpoint.set(outcome.endpointId, outcome);
    }
  }
  return byEndpoint;
}

describe('Feature: api-audit-testing-automation, Property 21: Local-vs-AWS comparison and environment-specific classification', () => {
  it('produces one row per request appearing in either run, carrying both outcomes (11.4)', () => {
    fc.assert(
      fc.property(
        runResultArb('Local'),
        runResultArb('AWS'),
        (local, aws) => {
          const comparison = compareRuns(local, aws);

          const localByEndpoint = firstByEndpoint(local.outcomes);
          const awsByEndpoint = firstByEndpoint(aws.outcomes);
          const expectedIds = new Set([
            ...localByEndpoint.keys(),
            ...awsByEndpoint.keys(),
          ]);

          const rowIds = comparison.rows.map((r) => r.endpointId);

          // Exactly one row per distinct endpoint id appearing in either run.
          expect(rowIds.length).toBe(expectedIds.size);
          expect(new Set(rowIds).size).toBe(rowIds.length);
          expect(new Set(rowIds)).toEqual(expectedIds);

          // Each row carries the matching local and AWS outcomes (first-wins),
          // and absent when the request only appears in the other run.
          for (const row of comparison.rows) {
            expect(row.local).toEqual(localByEndpoint.get(row.endpointId));
            expect(row.aws).toEqual(awsByEndpoint.get(row.endpointId));
            // At least one of the two outcomes must be present.
            expect(row.local !== undefined || row.aws !== undefined).toBe(true);
          }
        }
      ),
      { numRuns: 100 }
    );
  });

  it('classifies a request environment-specific iff it passed locally and failed on AWS (11.5)', () => {
    fc.assert(
      fc.property(
        runResultArb('Local'),
        runResultArb('AWS'),
        (local, aws) => {
          const comparison = compareRuns(local, aws);

          const localByEndpoint = firstByEndpoint(local.outcomes);
          const awsByEndpoint = firstByEndpoint(aws.outcomes);

          // Per-row iff check.
          for (const row of comparison.rows) {
            const localOutcome = localByEndpoint.get(row.endpointId);
            const awsOutcome = awsByEndpoint.get(row.endpointId);
            const expected =
              localOutcome?.passed === true && awsOutcome?.passed === false;

            expect(row.environmentSpecific).toBe(expected);
          }

          // The issues list equals exactly the environment-specific rows.
          const expectedIssues = comparison.rows
            .filter((r) => r.environmentSpecific)
            .map((r) => r.endpointId);

          expect(new Set(comparison.environmentSpecificIssues)).toEqual(
            new Set(expectedIssues)
          );
          expect(comparison.environmentSpecificIssues.length).toBe(
            expectedIssues.length
          );
        }
      ),
      { numRuns: 100 }
    );
  });
});
