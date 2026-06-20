/**
 * Unit tests for ProgressTracker
 *
 * Verifies state machine transitions, reason validation,
 * summary generation, and readiness percentage calculation.
 */

import { ProgressTracker } from './progress_tracker';
import { ScreenStatus, VALID_TRANSITIONS } from '../types';

describe('ProgressTracker', () => {
  let tracker: ProgressTracker;

  beforeEach(() => {
    tracker = new ProgressTracker();
  });

  describe('registerScreen', () => {
    it('should register a screen with Not Started status', () => {
      tracker.registerScreen('screen-1', 'restaurant');
      expect(tracker.getStatus('screen-1')).toBe('Not Started');
    });

    it('should not overwrite an already registered screen', () => {
      tracker.registerScreen('screen-1', 'restaurant');
      tracker.transition('screen-1', 'In Progress', 'Starting work');
      tracker.registerScreen('screen-1', 'restaurant');
      expect(tracker.getStatus('screen-1')).toBe('In Progress');
    });
  });

  describe('transition()', () => {
    beforeEach(() => {
      tracker.registerScreen('screen-1', 'restaurant');
    });

    it('should allow valid transition: Not Started → In Progress', () => {
      const result = tracker.transition('screen-1', 'In Progress', 'Starting remediation');
      expect(result.success).toBe(true);
      expect(result.previousStatus).toBe('Not Started');
      expect(result.newStatus).toBe('In Progress');
      expect(result.timestamp).toBeDefined();
      expect(tracker.getStatus('screen-1')).toBe('In Progress');
    });

    it('should allow valid transition: In Progress → Remediated', () => {
      tracker.transition('screen-1', 'In Progress', 'Starting');
      const result = tracker.transition('screen-1', 'Remediated', 'All fixes applied');
      expect(result.success).toBe(true);
      expect(result.previousStatus).toBe('In Progress');
      expect(result.newStatus).toBe('Remediated');
    });

    it('should allow valid transition: In Progress → Blocked', () => {
      tracker.transition('screen-1', 'In Progress', 'Starting');
      const result = tracker.transition('screen-1', 'Blocked', 'Missing API endpoint');
      expect(result.success).toBe(true);
      expect(result.newStatus).toBe('Blocked');
    });

    it('should allow valid transition: Blocked → In Progress', () => {
      tracker.transition('screen-1', 'In Progress', 'Starting');
      tracker.transition('screen-1', 'Blocked', 'Waiting for API');
      const result = tracker.transition('screen-1', 'In Progress', 'API now available');
      expect(result.success).toBe(true);
      expect(result.previousStatus).toBe('Blocked');
      expect(result.newStatus).toBe('In Progress');
    });

    it('should allow valid transition: Remediated → Validated', () => {
      tracker.transition('screen-1', 'In Progress', 'Starting');
      tracker.transition('screen-1', 'Remediated', 'Fixes done');
      const result = tracker.transition('screen-1', 'Validated', 'E2E passed');
      expect(result.success).toBe(true);
      expect(result.newStatus).toBe('Validated');
    });

    it('should allow valid transition: Validated → Remediated (regression)', () => {
      tracker.transition('screen-1', 'In Progress', 'Starting');
      tracker.transition('screen-1', 'Remediated', 'Fixed');
      tracker.transition('screen-1', 'Validated', 'Passed E2E');
      const result = tracker.transition('screen-1', 'Remediated', 'Regression detected');
      expect(result.success).toBe(true);
      expect(result.previousStatus).toBe('Validated');
      expect(result.newStatus).toBe('Remediated');
    });

    it('should reject invalid transition: Not Started → Remediated', () => {
      const result = tracker.transition('screen-1', 'Remediated', 'Skipping steps');
      expect(result.success).toBe(false);
      expect(result.error).toContain('Invalid transition');
      expect(tracker.getStatus('screen-1')).toBe('Not Started');
    });

    it('should reject invalid transition: Not Started → Validated', () => {
      const result = tracker.transition('screen-1', 'Validated', 'Direct validate');
      expect(result.success).toBe(false);
      expect(result.error).toContain('Invalid transition');
    });

    it('should reject invalid transition: Blocked → Remediated', () => {
      tracker.transition('screen-1', 'In Progress', 'Starting');
      tracker.transition('screen-1', 'Blocked', 'Waiting');
      const result = tracker.transition('screen-1', 'Remediated', 'Trying to skip');
      expect(result.success).toBe(false);
      expect(result.error).toContain('Invalid transition');
      expect(tracker.getStatus('screen-1')).toBe('Blocked');
    });

    it('should reject empty reason', () => {
      const result = tracker.transition('screen-1', 'In Progress', '');
      expect(result.success).toBe(false);
      expect(result.error).toContain('non-empty');
      expect(tracker.getStatus('screen-1')).toBe('Not Started');
    });

    it('should reject whitespace-only reason', () => {
      const result = tracker.transition('screen-1', 'In Progress', '   ');
      expect(result.success).toBe(false);
      expect(result.error).toContain('non-empty');
    });

    it('should reject reason exceeding 500 characters', () => {
      const longReason = 'a'.repeat(501);
      const result = tracker.transition('screen-1', 'In Progress', longReason);
      expect(result.success).toBe(false);
      expect(result.error).toContain('500');
    });

    it('should accept reason exactly 500 characters', () => {
      const reason = 'a'.repeat(500);
      const result = tracker.transition('screen-1', 'In Progress', reason);
      expect(result.success).toBe(true);
    });

    it('should reject transition for unregistered screen', () => {
      const result = tracker.transition('unknown-screen', 'In Progress', 'Valid reason');
      expect(result.success).toBe(false);
      expect(result.error).toContain('not registered');
    });
  });

  describe('getSummary()', () => {
    it('should return empty summary when no screens are registered', () => {
      const summary = tracker.getSummary();
      expect(summary.totalScreens).toBe(0);
      expect(summary.readinessPercentage).toBe(0.0);
      expect(summary.byStatus['Not Started']).toBe(0);
      expect(summary.byStatus['Validated']).toBe(0);
    });

    it('should count screens by status correctly', () => {
      tracker.registerScreen('s1', 'restaurant');
      tracker.registerScreen('s2', 'restaurant');
      tracker.registerScreen('s3', 'pharmacy');
      tracker.registerScreen('s4', 'pharmacy');

      tracker.transition('s1', 'In Progress', 'Working');
      tracker.transition('s1', 'Remediated', 'Done');
      tracker.transition('s1', 'Validated', 'Passed E2E');

      tracker.transition('s2', 'In Progress', 'Working');
      tracker.transition('s2', 'Blocked', 'Missing API');

      tracker.transition('s3', 'In Progress', 'Starting');
      tracker.transition('s3', 'Remediated', 'Fixed');

      const summary = tracker.getSummary();
      expect(summary.totalScreens).toBe(4);
      expect(summary.byStatus['Not Started']).toBe(1);    // s4
      expect(summary.byStatus['In Progress']).toBe(0);
      expect(summary.byStatus['Remediated']).toBe(1);     // s3
      expect(summary.byStatus['Validated']).toBe(1);      // s1
      expect(summary.byStatus['Blocked']).toBe(1);        // s2
    });

    it('should group counts per vertical', () => {
      tracker.registerScreen('s1', 'restaurant');
      tracker.registerScreen('s2', 'restaurant');
      tracker.registerScreen('s3', 'pharmacy');

      tracker.transition('s1', 'In Progress', 'Working');
      tracker.transition('s1', 'Remediated', 'Done');
      tracker.transition('s1', 'Validated', 'Passed');

      const summary = tracker.getSummary();
      expect(summary.byVertical['restaurant'].total).toBe(2);
      expect(summary.byVertical['restaurant'].byStatus['Validated']).toBe(1);
      expect(summary.byVertical['restaurant'].byStatus['Not Started']).toBe(1);
      expect(summary.byVertical['pharmacy'].total).toBe(1);
      expect(summary.byVertical['pharmacy'].byStatus['Not Started']).toBe(1);
    });
  });

  describe('getReadinessPercentage()', () => {
    it('should return 0.0 when no screens are registered', () => {
      expect(tracker.getReadinessPercentage()).toBe(0.0);
    });

    it('should return 0.0 when no screens are validated', () => {
      tracker.registerScreen('s1', 'restaurant');
      tracker.registerScreen('s2', 'pharmacy');
      expect(tracker.getReadinessPercentage()).toBe(0.0);
    });

    it('should return 100.0 when all screens are validated', () => {
      tracker.registerScreen('s1', 'restaurant');
      tracker.registerScreen('s2', 'pharmacy');

      tracker.transition('s1', 'In Progress', 'Work');
      tracker.transition('s1', 'Remediated', 'Done');
      tracker.transition('s1', 'Validated', 'OK');

      tracker.transition('s2', 'In Progress', 'Work');
      tracker.transition('s2', 'Remediated', 'Done');
      tracker.transition('s2', 'Validated', 'OK');

      expect(tracker.getReadinessPercentage()).toBe(100.0);
    });

    it('should calculate percentage rounded to 1 decimal', () => {
      // 1 validated out of 3 = 33.333...% → 33.3
      tracker.registerScreen('s1', 'restaurant');
      tracker.registerScreen('s2', 'restaurant');
      tracker.registerScreen('s3', 'restaurant');

      tracker.transition('s1', 'In Progress', 'Work');
      tracker.transition('s1', 'Remediated', 'Done');
      tracker.transition('s1', 'Validated', 'OK');

      expect(tracker.getReadinessPercentage()).toBe(33.3);
    });

    it('should handle 2/3 validated = 66.7%', () => {
      tracker.registerScreen('s1', 'restaurant');
      tracker.registerScreen('s2', 'restaurant');
      tracker.registerScreen('s3', 'restaurant');

      tracker.transition('s1', 'In Progress', 'Work');
      tracker.transition('s1', 'Remediated', 'Done');
      tracker.transition('s1', 'Validated', 'OK');

      tracker.transition('s2', 'In Progress', 'Work');
      tracker.transition('s2', 'Remediated', 'Done');
      tracker.transition('s2', 'Validated', 'OK');

      expect(tracker.getReadinessPercentage()).toBe(66.7);
    });
  });

  describe('getBlockingReasons()', () => {
    it('should return empty object when no screens are blocked', () => {
      tracker.registerScreen('s1', 'restaurant');
      expect(tracker.getBlockingReasons()).toEqual({});
    });

    it('should return blocking reasons grouped by vertical', () => {
      tracker.registerScreen('s1', 'restaurant');
      tracker.registerScreen('s2', 'pharmacy');

      tracker.transition('s1', 'In Progress', 'Working');
      tracker.transition('s1', 'Blocked', 'Missing menu API');

      tracker.transition('s2', 'In Progress', 'Working');
      tracker.transition('s2', 'Blocked', 'Drug schedule endpoint missing');

      const reasons = tracker.getBlockingReasons();
      expect(reasons['restaurant']).toHaveLength(1);
      expect(reasons['restaurant'][0]).toEqual({
        screenId: 's1',
        reason: 'Missing menu API',
      });
      expect(reasons['pharmacy']).toHaveLength(1);
      expect(reasons['pharmacy'][0]).toEqual({
        screenId: 's2',
        reason: 'Drug schedule endpoint missing',
      });
    });
  });
});
