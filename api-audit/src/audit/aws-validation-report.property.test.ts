/**
 * Property-based test for the AWS_Validator's complete, failure-resilient
 * validation report.
 *
 * Feature: api-audit-testing-automation, Property 18: AWS validation report is
 * complete and failure-resilient.
 *
 * Validates: Requirements 9.3, 9.4
 *
 * For any set of AWS service validation results — including an arbitrary
 * subset of unreachable services (and probes that reject outright) — the
 * report produced by `validateAwsServices`:
 *
 *   1. (9.3) contains exactly one entry per validated service, with the full
 *      service set present and no duplicates, and each entry records a valid
 *      outcome (`ok` or `failed`);
 *   2. (9.4) records, for every unreachable service, a `failed` outcome whose
 *      configIssues carry the failure detail — and validation always continues
 *      to the remaining services, so a broken (or rejecting) service never
 *      drops entries for the others.
 */

import fc from 'fast-check';

import {
  AWS_SERVICES,
  ProbeResult,
  ServiceProbes,
  validateAwsServices,
} from './aws-validator';
import type { AwsService, EnvironmentConfig } from '../types';

// A minimal environment config; the probes under test ignore it here because
// each service's behaviour is supplied directly by the generated probe set.
const ENV: EnvironmentConfig = {
  name: 'AWS',
  baseUrl: 'https://example.invalid',
  requiredVars: [],
  variableValues: new Map(),
};

/**
 * How a single service's probe behaves on a given run:
 *  - 'reachable'   -> resolves reachable (outcome should be `ok`)
 *  - 'unreachable' -> resolves reachable:false with a failure detail (failed)
 *  - 'throws'      -> the probe rejects, exercising failure-resilience (failed)
 */
type Behavior =
  | { kind: 'reachable'; loggingConfigured: boolean; configIssues: string[] }
  | { kind: 'unreachable'; failureDetail: string }
  | { kind: 'throws'; message: string };

const behaviorArb: fc.Arbitrary<Behavior> = fc.oneof(
  fc.record({
    kind: fc.constant<'reachable'>('reachable'),
    loggingConfigured: fc.boolean(),
    configIssues: fc.array(fc.string({ maxLength: 20 }), { maxLength: 3 }),
  }),
  fc.record({
    kind: fc.constant<'unreachable'>('unreachable'),
    // Non-empty, recognisable failure detail so we can assert it is recorded.
    failureDetail: fc
      .string({ minLength: 1, maxLength: 30 })
      .map((s) => `unreachable: ${s}`),
  }),
  fc.record({
    kind: fc.constant<'throws'>('throws'),
    message: fc.string({ minLength: 1, maxLength: 30 }).map((s) => `boom: ${s}`),
  }),
);

/** Builds a probe that realises the given behaviour. */
function probeFor(behavior: Behavior) {
  return async (): Promise<ProbeResult> => {
    switch (behavior.kind) {
      case 'reachable':
        return {
          reachable: true,
          loggingConfigured: behavior.loggingConfigured,
          configIssues: behavior.configIssues,
        };
      case 'unreachable':
        return {
          reachable: false,
          failureDetail: behavior.failureDetail,
          loggingConfigured: false,
          configIssues: [],
        };
      case 'throws':
        throw new Error(behavior.message);
    }
  };
}

// One behaviour per AWS service. Using a fixed-shape record keyed by the
// canonical service list keeps every service present in the generated input.
const behaviorsArb: fc.Arbitrary<Record<AwsService, Behavior>> = fc.record(
  AWS_SERVICES.reduce(
    (acc, service) => {
      acc[service] = behaviorArb;
      return acc;
    },
    {} as Record<AwsService, fc.Arbitrary<Behavior>>,
  ),
);

describe('Feature: api-audit-testing-automation, Property 18: AWS validation report is complete and failure-resilient', () => {
  it('produces exactly one entry per service and records failure detail for every unreachable service (9.3, 9.4)', async () => {
    await fc.assert(
      fc.asyncProperty(behaviorsArb, async (behaviors) => {
        const probes = AWS_SERVICES.reduce((acc, service) => {
          acc[service] = probeFor(behaviors[service]);
          return acc;
        }, {} as ServiceProbes);

        const { validations } = await validateAwsServices(ENV, probes);

        // (9.3) Exactly one entry per validated service: the full set, no dups.
        const reportedServices = validations.map((v) => v.service);
        expect(validations.length).toBe(AWS_SERVICES.length);
        expect(new Set(reportedServices).size).toBe(reportedServices.length);
        expect(new Set(reportedServices)).toEqual(new Set(AWS_SERVICES));

        for (const service of AWS_SERVICES) {
          const entry = validations.find((v) => v.service === service);
          // Validation continued to this service regardless of others.
          expect(entry).toBeDefined();
          if (!entry) continue;

          // (9.3) Each entry records a valid outcome.
          expect(['ok', 'failed']).toContain(entry.outcome);

          const behavior = behaviors[service];
          if (behavior.kind === 'reachable') {
            expect(entry.outcome).toBe('ok');
          } else if (behavior.kind === 'unreachable') {
            // (9.4) Unreachable service -> failed, with the failure detail
            // recorded in the entry.
            expect(entry.outcome).toBe('failed');
            expect(entry.configIssues).toContain(behavior.failureDetail);
          } else {
            // A rejecting probe is also recorded as failed with detail, proving
            // validation is resilient and continues past the failure.
            expect(entry.outcome).toBe('failed');
            expect(
              entry.configIssues.some((issue) =>
                issue.includes(behavior.message),
              ),
            ).toBe(true);
          }
        }
      }),
      { numRuns: 100 },
    );
  });
});
