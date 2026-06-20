/**
 * Property Test: Status State Machine Transitions
 *
 * Feature: full-stack-audit-remediation, Property 19: Status State Machine Transitions
 *
 * Validates: Requirements 15.1, 15.3
 *
 * For any screen with a current status, a transition attempt SHALL succeed if and only if
 * the (currentStatus → targetStatus) pair is in the valid transition set:
 *   { Not Started → In Progress, In Progress → Remediated, In Progress → Blocked,
 *     Blocked → In Progress, Remediated → Validated, Validated → Remediated }
 *
 * Invalid transitions SHALL be rejected with the current status preserved.
 * Transitions with empty reasons SHALL be rejected regardless of transition validity.
 */

import * as fc from 'fast-check';
import { ProgressTracker } from './progress_tracker';
import { VALID_TRANSITIONS, ScreenStatus } from '../types';

// ─── Constants ───────────────────────────────────────────────────────────────

const ALL_STATUSES: ScreenStatus[] = [
  'Not Started',
  'In Progress',
  'Remediated',
  'Validated',
  'Blocked',
];

/**
 * Transition sequences to bring a screen to a desired starting status.
 * Each path represents the transitions from 'Not Started' to reach the target status.
 */
const PATHS_TO_STATUS: Record<ScreenStatus, Array<{ target: ScreenStatus; reason: string }>> = {
  'Not Started': [],
  'In Progress': [{ target: 'In Progress', reason: 'Starting work' }],
  'Remediated': [
    { target: 'In Progress', reason: 'Starting work' },
    { target: 'Remediated', reason: 'Fix applied' },
  ],
  'Validated': [
    { target: 'In Progress', reason: 'Starting work' },
    { target: 'Remediated', reason: 'Fix applied' },
    { target: 'Validated', reason: 'E2E passed' },
  ],
  'Blocked': [
    { target: 'In Progress', reason: 'Starting work' },
    { target: 'Blocked', reason: 'External dependency' },
  ],
};

// ─── Generators ──────────────────────────────────────────────────────────────

/** Generates a random screen status */
const screenStatusArb = fc.constantFrom(...ALL_STATUSES);

/** Generates a non-empty reason string (1-500 chars) */
const validReasonArb = fc.stringMatching(/^[a-zA-Z0-9 .,!?:;'-]{1,100}$/).filter(
  (s) => s.trim().length > 0
);

/** Generates an empty or whitespace-only reason */
const emptyReasonArb = fc.constantFrom('', '   ', '\t', '\n', '  \n  ');

/** Generates a screen ID */
const screenIdArb = fc.stringMatching(/^[a-z][a-z0-9_-]{3,20}$/).map(
  (s) => `screen_${s}`
);

/** Generates a vertical name */
const verticalArb = fc.constantFrom(
  'restaurant',
  'school',
  'clinic',
  'jewellery',
  'hardware',
  'clothing',
  'pharmacy',
  'general_store'
);

// ─── Helper ──────────────────────────────────────────────────────────────────

/**
 * Sets up a ProgressTracker with a screen already in the desired starting status.
 */
function setupTrackerWithStatus(
  screenId: string,
  vertical: string,
  targetStatus: ScreenStatus
): ProgressTracker {
  const tracker = new ProgressTracker();
  tracker.registerScreen(screenId, vertical);

  const path = PATHS_TO_STATUS[targetStatus];
  for (const step of path) {
    const result = tracker.transition(screenId, step.target, step.reason);
    if (!result.success) {
      throw new Error(`Setup failed: could not transition to ${step.target}: ${result.error}`);
    }
  }

  return tracker;
}

// ─── Property Tests ──────────────────────────────────────────────────────────

describe('Feature: full-stack-audit-remediation, Property 19: Status State Machine Transitions', () => {
  describe('Valid transitions succeed', () => {
    it('should succeed when transition is in the valid set and reason is non-empty', () => {
      fc.assert(
        fc.property(
          screenIdArb,
          verticalArb,
          screenStatusArb,
          validReasonArb,
          (screenId, vertical, currentStatus, reason) => {
            const validTargets = VALID_TRANSITIONS[currentStatus];
            if (!validTargets || validTargets.length === 0) return; // skip statuses with no valid transitions

            // Pick a valid target for this current status
            const targetStatus = validTargets[0];

            const tracker = setupTrackerWithStatus(screenId, vertical, currentStatus);
            const result = tracker.transition(screenId, targetStatus, reason);

            expect(result.success).toBe(true);
            expect(result.newStatus).toBe(targetStatus);
            expect(result.previousStatus).toBe(currentStatus);

            // Verify the screen is now at the new status
            expect(tracker.getStatus(screenId)).toBe(targetStatus);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Invalid transitions are rejected', () => {
    it('should reject transitions not in the valid set and preserve current status', () => {
      fc.assert(
        fc.property(
          screenIdArb,
          verticalArb,
          screenStatusArb,
          screenStatusArb,
          validReasonArb,
          (screenId, vertical, currentStatus, targetStatus, reason) => {
            const validTargets = VALID_TRANSITIONS[currentStatus] || [];

            // Only test when the target is NOT a valid transition
            if (validTargets.includes(targetStatus)) return;

            const tracker = setupTrackerWithStatus(screenId, vertical, currentStatus);
            const result = tracker.transition(screenId, targetStatus, reason);

            // Transition must be rejected
            expect(result.success).toBe(false);
            expect(result.error).toBeDefined();

            // Current status must be preserved
            expect(tracker.getStatus(screenId)).toBe(currentStatus);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Empty reasons are always rejected', () => {
    it('should reject transitions with empty reasons regardless of validity', () => {
      fc.assert(
        fc.property(
          screenIdArb,
          verticalArb,
          screenStatusArb,
          screenStatusArb,
          emptyReasonArb,
          (screenId, vertical, currentStatus, targetStatus, emptyReason) => {
            const tracker = setupTrackerWithStatus(screenId, vertical, currentStatus);
            const result = tracker.transition(screenId, targetStatus, emptyReason);

            // Must be rejected regardless of whether the transition would be valid
            expect(result.success).toBe(false);
            expect(result.error).toBeDefined();

            // Status must remain unchanged
            expect(tracker.getStatus(screenId)).toBe(currentStatus);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Transition completeness', () => {
    it('should handle all valid transitions in the state machine', () => {
      fc.assert(
        fc.property(
          screenIdArb,
          verticalArb,
          validReasonArb,
          (screenId, vertical, reason) => {
            // Test each valid transition pair exhaustively
            for (const [fromStatus, targets] of Object.entries(VALID_TRANSITIONS)) {
              for (const toStatus of targets) {
                const tracker = setupTrackerWithStatus(
                  screenId,
                  vertical,
                  fromStatus as ScreenStatus
                );
                const result = tracker.transition(screenId, toStatus as ScreenStatus, reason);

                expect(result.success).toBe(true);
                expect(result.newStatus).toBe(toStatus);
              }
            }
          }
        ),
        { numRuns: 100 }
      );
    });
  });
});
