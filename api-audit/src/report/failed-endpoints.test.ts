/**
 * Property test for the failed endpoint report and recommended-fix derivation.
 *
 * Feature: api-audit-testing-automation, Property 19: Failed endpoint report
 * and recommended fixes mirror failures.
 *
 * Validates: Requirements 10.2, 10.3
 *
 * Strategy: build an arbitrary `RunResult` whose outcomes are a free mix of
 * passing and failing requests (with arbitrary assertion-failure detail and
 * status codes), feed it through `buildFailedEndpointReport`, and assert the
 * report mirrors exactly the failed outcomes: the `failures` list equals the
 * `passed === false` outcomes (in order) carrying their assertion-failure
 * detail (Requirement 10.2), and `recommendedFixes` has exactly one non-empty
 * entry per failed request keyed to the same endpoint/request (Requirement
 * 10.3) — and never lists or recommends fixes for passing requests.
 */
import fc from 'fast-check';

import type { RequestOutcome, RunResult } from '../types';
import { buildFailedEndpointReport } from './failed-endpoints';

const MIN_RUNS = 100;

/** A single assertion-failure message; spans known and unknown signal text. */
const assertionFailureArb: fc.Arbitrary<string> = fc.oneof(
  fc.constantFrom(
    'Status code is 200',
    'Response time is below threshold',
    'Response body matches schema: missing required field',
    'Unauthorized: token rejected',
    'Forbidden: missing permission',
    'Input validation: value must not be empty',
    'Unexpected assertion failure'
  ),
  fc.string({ minLength: 0, maxLength: 20 })
);

/** An arbitrary request outcome with an explicit pass/fail flag. */
const outcomeArb: fc.Arbitrary<RequestOutcome> = fc.record({
  endpointId: fc.string({ minLength: 1, maxLength: 12 }),
  requestName: fc.string({ minLength: 1, maxLength: 12 }),
  passed: fc.boolean(),
  assertionFailures: fc.array(assertionFailureArb, { minLength: 0, maxLength: 5 }),
  responseTimeMs: fc.integer({ min: 0, max: 10_000 }),
  statusCode: fc.option(fc.integer({ min: 100, max: 599 }), { nil: undefined }),
});

const runResultArb: fc.Arbitrary<RunResult> = fc
  .record({
    environment: fc.constantFrom(
      'Development',
      'Local',
      'Staging',
      'AWS',
      'Production'
    ) as fc.Arbitrary<RunResult['environment']>,
    outcomes: fc.array(outcomeArb, { minLength: 0, maxLength: 12 }),
  })
  .map((partial) => ({
    ...partial,
    allPassed: partial.outcomes.every((o) => o.passed),
  }));

describe('Property 19: Failed endpoint report and recommended fixes mirror failures', () => {
  it('lists exactly the failed outcomes with their detail and one fix each', () => {
    fc.assert(
      fc.property(runResultArb, (run) => {
        const report = buildFailedEndpointReport(run);

        const failedOutcomes = run.outcomes.filter((o) => !o.passed);

        // 1. The failures list mirrors exactly the failed outcomes, in order,
        //    carrying each one's assertion-failure detail (Requirement 10.2).
        expect(report.failures).toHaveLength(failedOutcomes.length);
        report.failures.forEach((entry, i) => {
          const source = failedOutcomes[i];
          expect(entry.endpointId).toBe(source.endpointId);
          expect(entry.requestName).toBe(source.requestName);
          expect(entry.assertionFailures).toEqual(source.assertionFailures);
          expect(entry.responseTimeMs).toBe(source.responseTimeMs);
          expect(entry.statusCode).toBe(source.statusCode);
        });

        // The number of failures equals the number of failing outcomes, so no
        // passing request can appear: the index-aligned checks above already
        // bind every listed entry to a `passed === false` source outcome.

        // 2. Exactly one recommended-fix entry per failed request, keyed to the
        //    same endpoint/request, and never empty (Requirement 10.3).
        expect(report.recommendedFixes).toHaveLength(failedOutcomes.length);
        report.recommendedFixes.forEach((fix, i) => {
          const source = failedOutcomes[i];
          expect(fix.endpointId).toBe(source.endpointId);
          expect(fix.requestName).toBe(source.requestName);
          expect(fix.suggestions.length).toBeGreaterThan(0);
        });
      }),
      { numRuns: MIN_RUNS }
    );
  });
});
