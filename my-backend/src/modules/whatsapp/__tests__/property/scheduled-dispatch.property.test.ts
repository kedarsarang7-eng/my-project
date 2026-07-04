// ============================================================================
// Property-Based Test — Scheduled Dispatch Time
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 20
//
// Validates: Requirements 3.3, 11.2
//
// Property 20 (design.md): Scheduled/delayed dispatch time equals event time
// plus configured delay.
//
// For any Automation_Rule with a delay or scheduled time in the range 1 second
// to 365 days, the computed dispatch time equals the Business_Event time plus
// the configured delay (or the configured absolute time), and the scheduler
// selects the message for dispatch once that time is reached.
//
// Verified properties:
// 1. dispatchTime = eventTime + delaySeconds
// 2. Delay range 1s..365d is respected (out-of-range rejected)
// 3. Absolute time scheduling works
// 4. No-delay produces immediate dispatch failure (neither delay nor absolute)
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  computeDispatchTime,
  MIN_DELAY_SECONDS,
  MAX_DELAY_SECONDS,
  ScheduleConfig,
} from '../../services/schedule.service';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** ISO-8601 UTC date string generator (valid dates in reasonable range). */
const isoDateArb: fc.Arbitrary<string> = fc
  .date({
    min: new Date('2020-01-01T00:00:00.000Z'),
    max: new Date('2030-12-31T23:59:59.999Z'),
  })
  .map((d) => d.toISOString());

/** Valid delay in seconds (1 to 31,536,000 = 365 days). */
const validDelayArb: fc.Arbitrary<number> = fc.integer({
  min: MIN_DELAY_SECONDS,
  max: MAX_DELAY_SECONDS,
});

/** Delay below the minimum (0 or negative). */
const belowMinDelayArb: fc.Arbitrary<number> = fc.integer({
  min: -1_000_000,
  max: MIN_DELAY_SECONDS - 1,
});

/** Delay above the maximum (> 365 days). */
const aboveMaxDelayArb: fc.Arbitrary<number> = fc.integer({
  min: MAX_DELAY_SECONDS + 1,
  max: MAX_DELAY_SECONDS * 2,
});

/**
 * Generates an absolute dispatch time that is at or after the given event time.
 * Uses an offset of 1s to 365d from the event time.
 */
function futureAbsoluteTimeArb(eventTime: string): fc.Arbitrary<string> {
  const eventMs = Date.parse(eventTime);
  return fc
    .integer({ min: 1_000, max: MAX_DELAY_SECONDS * 1000 })
    .map((offsetMs) => new Date(eventMs + offsetMs).toISOString());
}

/**
 * Generates an absolute dispatch time that is before the given event time.
 */
function pastAbsoluteTimeArb(eventTime: string): fc.Arbitrary<string> {
  const eventMs = Date.parse(eventTime);
  return fc
    .integer({ min: 1_000, max: 365 * 24 * 60 * 60 * 1000 })
    .map((offsetMs) => new Date(eventMs - offsetMs).toISOString());
}

// ── Property 20 Tests ───────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 20: Scheduled/delayed dispatch time equals event time plus configured delay', () => {
  // ── 1) dispatchTime = eventTime + delaySeconds ────────────────────────────

  test('dispatch time equals event time plus delaySeconds (Req 3.3)', () => {
    fc.assert(
      fc.property(isoDateArb, validDelayArb, (eventTime, delaySeconds) => {
        const schedule: ScheduleConfig = { delaySeconds };
        const result = computeDispatchTime(eventTime, schedule);

        expect(result.valid).toBe(true);
        expect(result.dueTime).toBeDefined();

        // Verify: dueTime = eventTime + delaySeconds
        const expectedMs = Date.parse(eventTime) + delaySeconds * 1000;
        const expectedIso = new Date(expectedMs).toISOString();
        expect(result.dueTime).toBe(expectedIso);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 2a) Delay below minimum (< 1s) is rejected ───────────────────────────

  test('delay below minimum (< 1 second) is rejected (Req 3.3)', () => {
    fc.assert(
      fc.property(isoDateArb, belowMinDelayArb, (eventTime, delaySeconds) => {
        const schedule: ScheduleConfig = { delaySeconds };
        const result = computeDispatchTime(eventTime, schedule);

        expect(result.valid).toBe(false);
        expect(result.dueTime).toBeUndefined();
        expect(result.reason).toBeDefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 2b) Delay above maximum (> 365 days) is rejected ─────────────────────

  test('delay above maximum (> 365 days) is rejected (Req 3.3)', () => {
    fc.assert(
      fc.property(isoDateArb, aboveMaxDelayArb, (eventTime, delaySeconds) => {
        const schedule: ScheduleConfig = { delaySeconds };
        const result = computeDispatchTime(eventTime, schedule);

        expect(result.valid).toBe(false);
        expect(result.dueTime).toBeUndefined();
        expect(result.reason).toBeDefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 2c) Boundary: exactly 1 second delay is accepted ─────────────────────

  test('boundary: exactly 1 second delay is accepted (Req 3.3)', () => {
    fc.assert(
      fc.property(isoDateArb, (eventTime) => {
        const schedule: ScheduleConfig = { delaySeconds: MIN_DELAY_SECONDS };
        const result = computeDispatchTime(eventTime, schedule);

        expect(result.valid).toBe(true);
        const expectedMs = Date.parse(eventTime) + MIN_DELAY_SECONDS * 1000;
        expect(result.dueTime).toBe(new Date(expectedMs).toISOString());
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 2d) Boundary: exactly 365 days delay is accepted ─────────────────────

  test('boundary: exactly 365 days delay is accepted (Req 3.3)', () => {
    fc.assert(
      fc.property(isoDateArb, (eventTime) => {
        const schedule: ScheduleConfig = { delaySeconds: MAX_DELAY_SECONDS };
        const result = computeDispatchTime(eventTime, schedule);

        expect(result.valid).toBe(true);
        const expectedMs = Date.parse(eventTime) + MAX_DELAY_SECONDS * 1000;
        expect(result.dueTime).toBe(new Date(expectedMs).toISOString());
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 3) Absolute time scheduling works ─────────────────────────────────────

  test('absolute time scheduling returns the configured time (Req 3.3, 11.2)', () => {
    fc.assert(
      fc.property(
        isoDateArb.chain((eventTime) =>
          futureAbsoluteTimeArb(eventTime).map((absTime) => ({ eventTime, absTime })),
        ),
        ({ eventTime, absTime }) => {
          const schedule: ScheduleConfig = { at: absTime };
          const result = computeDispatchTime(eventTime, schedule);

          expect(result.valid).toBe(true);
          expect(result.dueTime).toBe(new Date(Date.parse(absTime)).toISOString());
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 3b) Absolute time before event time is rejected ───────────────────────

  test('absolute time before event time is rejected (Req 3.3)', () => {
    fc.assert(
      fc.property(
        isoDateArb.chain((eventTime) =>
          pastAbsoluteTimeArb(eventTime).map((pastTime) => ({ eventTime, pastTime })),
        ),
        ({ eventTime, pastTime }) => {
          const schedule: ScheduleConfig = { at: pastTime };
          const result = computeDispatchTime(eventTime, schedule);

          expect(result.valid).toBe(false);
          expect(result.reason).toBeDefined();
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 4) No-delay (empty schedule) produces invalid result ──────────────────

  test('empty schedule (neither delaySeconds nor at) is rejected (Req 3.3)', () => {
    fc.assert(
      fc.property(isoDateArb, (eventTime) => {
        const schedule: ScheduleConfig = {};
        const result = computeDispatchTime(eventTime, schedule);

        expect(result.valid).toBe(false);
        expect(result.dueTime).toBeUndefined();
        expect(result.reason).toBeDefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Additional: non-integer delaySeconds is rejected ──────────────────────

  test('non-integer delaySeconds is rejected (Req 3.3)', () => {
    fc.assert(
      fc.property(
        isoDateArb,
        fc.double({ min: 0.01, max: MAX_DELAY_SECONDS, noNaN: true }).filter((d) => !Number.isInteger(d)),
        (eventTime, delaySeconds) => {
          const schedule: ScheduleConfig = { delaySeconds };
          const result = computeDispatchTime(eventTime, schedule);

          expect(result.valid).toBe(false);
          expect(result.reason).toBeDefined();
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Additional: invalid eventTime is rejected ─────────────────────────────

  test('invalid eventTime (non-ISO string) is rejected', () => {
    fc.assert(
      fc.property(
        fc.string().filter((s) => isNaN(Date.parse(s))),
        validDelayArb,
        (eventTime, delaySeconds) => {
          const schedule: ScheduleConfig = { delaySeconds };
          const result = computeDispatchTime(eventTime, schedule);

          expect(result.valid).toBe(false);
          expect(result.reason).toContain('eventTime');
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Additional: invalid schedule.at is rejected ───────────────────────────

  test('invalid schedule.at (non-ISO string) is rejected', () => {
    fc.assert(
      fc.property(
        isoDateArb,
        fc.string().filter((s) => isNaN(Date.parse(s)) && s.length > 0),
        (eventTime, invalidAt) => {
          const schedule: ScheduleConfig = { at: invalidAt };
          const result = computeDispatchTime(eventTime, schedule);

          expect(result.valid).toBe(false);
          expect(result.reason).toBeDefined();
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });
});
