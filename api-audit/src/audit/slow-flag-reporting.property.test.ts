/**
 * Property-based test for the Performance_Auditor's slow-flag rule and
 * per-endpoint Performance_Report.
 *
 * Feature: api-audit-testing-automation, Property 17: Slow-flag rule and
 * per-endpoint performance reporting.
 *
 * Validates: Requirements 8.3, 8.4
 *
 * Two behaviours are asserted across arbitrary per-endpoint samples and an
 * arbitrary configured threshold:
 *
 *   1. (8.3) An endpoint is flagged slow if and only if its measured response
 *      time strictly exceeds the configured response-time threshold. The
 *      measured response time is the value `buildMeasurement` derives from the
 *      samples, so the iff is checked against `measurement.responseTimeMs`.
 *   2. (8.4) `aggregateMeasurements` emits exactly one `PerfMeasurement` per
 *      measured endpoint, and every measurement is well-formed: response time,
 *      throughput, and latency are all finite and non-negative.
 */

import fc from 'fast-check';

import {
  aggregateMeasurements,
  buildMeasurement,
  DEFAULT_PERF_THRESHOLDS,
  EndpointSamples,
  PerfThresholds,
} from './performance-auditor';

// A finite, non-negative response-time sample (milliseconds). Spans both sides
// of typical thresholds so the slow / not-slow branches are both exercised.
const responseTimeArb: fc.Arbitrary<number> = fc.double({
  min: 0,
  max: 5000,
  noNaN: true,
});

// An endpoint's raw samples. At least one sample so a response time is always
// measurable; ids are kept to a small alphabet so collisions (and thus the
// dedup-to-one-entry behaviour) occur naturally.
const samplesArb: fc.Arbitrary<EndpointSamples> = fc.record({
  endpointId: fc.string({ minLength: 1, maxLength: 6 }),
  responseTimesMs: fc.array(responseTimeArb, { minLength: 1, maxLength: 8 }),
});

// An arbitrary configured threshold, plus the remaining default knobs. Spans a
// wide range so the iff is checked against thresholds both below and above the
// sampled response times.
const thresholdsArb: fc.Arbitrary<PerfThresholds> = fc
  .double({ min: 0, max: 5000, noNaN: true })
  .map(
    (responseTimeThresholdMs) =>
      ({
        ...DEFAULT_PERF_THRESHOLDS,
        responseTimeThresholdMs,
      }) as PerfThresholds,
  );

describe('Feature: api-audit-testing-automation, Property 17: Slow-flag rule and per-endpoint performance reporting', () => {
  it('flags an endpoint slow iff its measured response time strictly exceeds the threshold (8.3)', () => {
    fc.assert(
      fc.property(samplesArb, thresholdsArb, (samples, thresholds) => {
        const measurement = buildMeasurement(samples, thresholds);

        const expectedSlow =
          measurement.responseTimeMs > thresholds.responseTimeThresholdMs;

        expect(measurement.flaggedSlow).toBe(expectedSlow);
      }),
      { numRuns: 100 },
    );
  });

  it('emits exactly one well-formed measurement per measured endpoint (8.4)', () => {
    fc.assert(
      fc.property(
        // Distinct endpoint ids: aggregateMeasurements consumes the output of
        // collectSamples, which is already deduplicated per endpoint.
        fc.uniqueArray(samplesArb, {
          minLength: 0,
          maxLength: 12,
          selector: (s) => s.endpointId,
        }),
        thresholdsArb,
        (samplesByEndpoint, thresholds) => {
          const measurements = aggregateMeasurements(
            samplesByEndpoint,
            thresholds,
          );

          // Exactly one PerfMeasurement per measured endpoint id.
          const inputIds = new Set(
            samplesByEndpoint.map((s) => s.endpointId),
          );
          const outputIds = measurements.map((m) => m.endpointId);

          expect(measurements.length).toBe(inputIds.size);
          expect(new Set(outputIds).size).toBe(outputIds.length);
          expect(new Set(outputIds)).toEqual(inputIds);

          // Each measurement is well-formed: response time / throughput /
          // latency are finite and non-negative.
          for (const m of measurements) {
            expect(Number.isFinite(m.responseTimeMs)).toBe(true);
            expect(m.responseTimeMs).toBeGreaterThanOrEqual(0);
            expect(Number.isFinite(m.throughput)).toBe(true);
            expect(m.throughput).toBeGreaterThanOrEqual(0);
            expect(Number.isFinite(m.latencyMs)).toBe(true);
            expect(m.latencyMs).toBeGreaterThanOrEqual(0);
          }
        },
      ),
      { numRuns: 100 },
    );
  });
});
