/**
 * Property Test: Progress Aggregation and Readiness Percentage
 *
 * Feature: full-stack-audit-remediation, Property 20: Progress Aggregation and Readiness Percentage
 *
 * Validates: Requirements 15.4, 15.5
 *
 * For any set of screen statuses, the progress summary SHALL correctly count
 * screens in each status per vertical, and the overall readiness percentage
 * SHALL equal (Validated screens / Total screens) × 100 rounded to 1 decimal place.
 */

import * as fc from 'fast-check';
import { ProgressTracker } from './progress_tracker';
import { ScreenStatus, VALID_TRANSITIONS } from '../types';

// ─── Constants ───────────────────────────────────────────────────────────────

const ALL_STATUSES: ScreenStatus[] = [
  'Not Started',
  'In Progress',
  'Remediated',
  'Validated',
  'Blocked',
];

const VERTICALS = [
  'restaurant',
  'school',
  'clinic',
  'jewellery',
  'hardware',
  'clothing',
  'pharmacy',
  'general_store',
  'auto_parts',
  'computer_shop',
];

/**
 * Transition sequences from 'Not Started' to reach a given status.
 */
const PATHS_TO_STATUS: Record<ScreenStatus, Array<{ target: ScreenStatus; reason: string }>> = {
  'Not Started': [],
  'In Progress': [{ target: 'In Progress', reason: 'Starting' }],
  'Remediated': [
    { target: 'In Progress', reason: 'Starting' },
    { target: 'Remediated', reason: 'Fixed' },
  ],
  'Validated': [
    { target: 'In Progress', reason: 'Starting' },
    { target: 'Remediated', reason: 'Fixed' },
    { target: 'Validated', reason: 'Passed E2E' },
  ],
  'Blocked': [
    { target: 'In Progress', reason: 'Starting' },
    { target: 'Blocked', reason: 'Blocked by dependency' },
  ],
};

// ─── Generators ──────────────────────────────────────────────────────────────

/** Generates a screen entry with vertical and target status */
const screenEntryArb = fc.record({
  vertical: fc.constantFrom(...VERTICALS),
  status: fc.constantFrom(...ALL_STATUSES),
});

/** Generates a non-empty array of screen entries (1-30 screens) */
const screenSetArb = fc.array(screenEntryArb, { minLength: 1, maxLength: 30 });

// ─── Helper ──────────────────────────────────────────────────────────────────

/**
 * Sets up a ProgressTracker with screens at their desired statuses.
 */
function setupTracker(
  screens: Array<{ vertical: string; status: ScreenStatus }>
): ProgressTracker {
  const tracker = new ProgressTracker();

  screens.forEach((screen, index) => {
    const screenId = `screen_${index}_${screen.vertical}`;
    tracker.registerScreen(screenId, screen.vertical);

    // Transition to the target status
    const path = PATHS_TO_STATUS[screen.status];
    for (const step of path) {
      tracker.transition(screenId, step.target, step.reason);
    }
  });

  return tracker;
}

// ─── Property Tests ──────────────────────────────────────────────────────────

describe('Feature: full-stack-audit-remediation, Property 20: Progress Aggregation and Readiness Percentage', () => {
  describe('Per-vertical counts are correct', () => {
    it('should correctly count screens per status per vertical', () => {
      fc.assert(
        fc.property(screenSetArb, (screens) => {
          const tracker = setupTracker(screens);
          const summary = tracker.getSummary();

          // Verify total screens matches input
          expect(summary.totalScreens).toBe(screens.length);

          // Calculate expected counts per vertical per status
          const expectedByVertical: Record<string, Record<ScreenStatus, number>> = {};

          for (const screen of screens) {
            if (!expectedByVertical[screen.vertical]) {
              expectedByVertical[screen.vertical] = {
                'Not Started': 0,
                'In Progress': 0,
                'Remediated': 0,
                'Validated': 0,
                'Blocked': 0,
              };
            }
            expectedByVertical[screen.vertical][screen.status]++;
          }

          // Verify each vertical's counts match
          for (const [vertical, expectedCounts] of Object.entries(expectedByVertical)) {
            const actualVertical = summary.byVertical[vertical];
            expect(actualVertical).toBeDefined();

            let expectedTotal = 0;
            for (const status of ALL_STATUSES) {
              expect(actualVertical.byStatus[status]).toBe(expectedCounts[status]);
              expectedTotal += expectedCounts[status];
            }
            expect(actualVertical.total).toBe(expectedTotal);
          }
        }),
        { numRuns: 100 }
      );
    });
  });

  describe('Overall status counts are correct', () => {
    it('should correctly count total screens per status across all verticals', () => {
      fc.assert(
        fc.property(screenSetArb, (screens) => {
          const tracker = setupTracker(screens);
          const summary = tracker.getSummary();

          // Calculate expected global counts
          const expectedByStatus: Record<ScreenStatus, number> = {
            'Not Started': 0,
            'In Progress': 0,
            'Remediated': 0,
            'Validated': 0,
            'Blocked': 0,
          };

          for (const screen of screens) {
            expectedByStatus[screen.status]++;
          }

          // Verify global counts
          for (const status of ALL_STATUSES) {
            expect(summary.byStatus[status]).toBe(expectedByStatus[status]);
          }

          // Verify sum of all status counts equals total
          const totalFromCounts = Object.values(summary.byStatus).reduce(
            (sum, count) => sum + count,
            0
          );
          expect(totalFromCounts).toBe(summary.totalScreens);
        }),
        { numRuns: 100 }
      );
    });
  });

  describe('Readiness percentage calculation', () => {
    it('should equal (Validated / Total) × 100 rounded to 1 decimal', () => {
      fc.assert(
        fc.property(screenSetArb, (screens) => {
          const tracker = setupTracker(screens);
          const summary = tracker.getSummary();

          const validatedCount = screens.filter((s) => s.status === 'Validated').length;
          const total = screens.length;

          const expectedPercentage =
            total === 0 ? 0.0 : Math.round((validatedCount / total) * 1000) / 10;

          expect(summary.readinessPercentage).toBe(expectedPercentage);
        }),
        { numRuns: 100 }
      );
    });

    it('should return 0.0 when no screens are validated', () => {
      fc.assert(
        fc.property(
          fc.array(
            fc.record({
              vertical: fc.constantFrom(...VERTICALS),
              status: fc.constantFrom('Not Started', 'In Progress', 'Blocked') as fc.Arbitrary<ScreenStatus>,
            }),
            { minLength: 1, maxLength: 20 }
          ),
          (screens) => {
            const tracker = setupTracker(screens);
            const percentage = tracker.getReadinessPercentage();

            expect(percentage).toBe(0.0);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('should return 100.0 when all screens are validated', () => {
      fc.assert(
        fc.property(
          fc.integer({ min: 1, max: 20 }),
          fc.constantFrom(...VERTICALS),
          (count, vertical) => {
            const screens = Array.from({ length: count }, () => ({
              vertical,
              status: 'Validated' as ScreenStatus,
            }));

            const tracker = setupTracker(screens);
            const percentage = tracker.getReadinessPercentage();

            expect(percentage).toBe(100.0);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('should be bounded between 0 and 100 inclusive', () => {
      fc.assert(
        fc.property(screenSetArb, (screens) => {
          const tracker = setupTracker(screens);
          const percentage = tracker.getReadinessPercentage();

          expect(percentage).toBeGreaterThanOrEqual(0.0);
          expect(percentage).toBeLessThanOrEqual(100.0);
        }),
        { numRuns: 100 }
      );
    });
  });

  describe('Empty tracker edge case', () => {
    it('should return 0 readiness for empty tracker', () => {
      const tracker = new ProgressTracker();
      const summary = tracker.getSummary();

      expect(summary.totalScreens).toBe(0);
      expect(summary.readinessPercentage).toBe(0.0);
    });
  });
});
