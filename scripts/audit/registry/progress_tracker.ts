/**
 * Progress Tracker - Screen Remediation Status State Machine
 *
 * Manages per-screen remediation status with validated transitions,
 * generates progress summaries per vertical, and calculates overall
 * platform readiness percentage.
 *
 * State Machine:
 *   Not Started → In Progress
 *   In Progress → Remediated | Blocked
 *   Blocked → In Progress
 *   Remediated → Validated
 *   Validated → Remediated (regression)
 *
 * Requirements: 15.1, 15.2, 15.3, 15.4, 15.5
 */

import {
  VALID_TRANSITIONS,
  ScreenStatus,
  TransitionResult,
  ProgressSummary,
} from '../types';

/** Maximum allowed reason length in characters */
const MAX_REASON_LENGTH = 500;

/** Internal record for a tracked screen */
interface ScreenRecord {
  screenId: string;
  vertical: string;
  status: ScreenStatus;
  reason: string;
  timestamp: string;
}

/**
 * ProgressTracker manages screen status transitions and generates
 * progress reports across the platform.
 */
export class ProgressTracker {
  /** Map of screenId → ScreenRecord */
  private screens: Map<string, ScreenRecord> = new Map();

  /**
   * Register a screen for tracking. Screens start at 'Not Started'.
   */
  registerScreen(screenId: string, vertical: string): void {
    if (!this.screens.has(screenId)) {
      this.screens.set(screenId, {
        screenId,
        vertical,
        status: 'Not Started',
        reason: 'Initial registration',
        timestamp: new Date().toISOString(),
      });
    }
  }

  /**
   * Get the current status for a screen.
   * Returns undefined if the screen is not registered.
   */
  getStatus(screenId: string): ScreenStatus | undefined {
    return this.screens.get(screenId)?.status;
  }

  /**
   * Attempt a status transition for a screen.
   *
   * Validates:
   * 1. Screen exists in the registry
   * 2. Reason is a non-empty string of at most 500 characters
   * 3. Transition is valid per the VALID_TRANSITIONS map
   *
   * Returns a TransitionResult indicating success or failure with error details.
   */
  transition(screenId: string, targetStatus: ScreenStatus, reason: string): TransitionResult {
    // Validate reason is non-empty and within length limit
    if (!reason || reason.trim().length === 0) {
      return {
        success: false,
        error: 'Reason must be a non-empty string',
      };
    }

    if (reason.length > MAX_REASON_LENGTH) {
      return {
        success: false,
        error: `Reason must be at most ${MAX_REASON_LENGTH} characters (got ${reason.length})`,
      };
    }

    // Check screen exists
    const record = this.screens.get(screenId);
    if (!record) {
      return {
        success: false,
        error: `Screen '${screenId}' is not registered in the tracker`,
      };
    }

    // Validate transition against state machine
    const currentStatus = record.status;
    const allowedTargets = VALID_TRANSITIONS[currentStatus];

    if (!allowedTargets || !allowedTargets.includes(targetStatus)) {
      return {
        success: false,
        error: `Invalid transition: '${currentStatus}' → '${targetStatus}'. Allowed transitions from '${currentStatus}': [${allowedTargets?.join(', ') ?? 'none'}]`,
        previousStatus: currentStatus,
      };
    }

    // Perform the transition
    const timestamp = new Date().toISOString();
    const previousStatus = record.status;

    record.status = targetStatus;
    record.reason = reason;
    record.timestamp = timestamp;

    return {
      success: true,
      previousStatus,
      newStatus: targetStatus,
      timestamp,
    };
  }

  /**
   * Generate a progress summary across all tracked screens.
   *
   * Returns per-vertical breakdown with totals, status counts,
   * and blocking reasons for blocked screens.
   */
  getSummary(): ProgressSummary {
    const allStatuses: ScreenStatus[] = [
      'Not Started',
      'In Progress',
      'Remediated',
      'Validated',
      'Blocked',
    ];

    // Initialize overall counters
    const byStatus: Record<ScreenStatus, number> = {
      'Not Started': 0,
      'In Progress': 0,
      'Remediated': 0,
      'Validated': 0,
      'Blocked': 0,
    };

    const byVertical: Record<string, { total: number; byStatus: Record<ScreenStatus, number> }> = {};

    // Aggregate counts
    for (const record of this.screens.values()) {
      byStatus[record.status]++;

      if (!byVertical[record.vertical]) {
        byVertical[record.vertical] = {
          total: 0,
          byStatus: {
            'Not Started': 0,
            'In Progress': 0,
            'Remediated': 0,
            'Validated': 0,
            'Blocked': 0,
          },
        };
      }

      byVertical[record.vertical].total++;
      byVertical[record.vertical].byStatus[record.status]++;
    }

    const totalScreens = this.screens.size;
    const readinessPercentage = this.getReadinessPercentage();

    return {
      totalScreens,
      byStatus,
      byVertical,
      readinessPercentage,
    };
  }

  /**
   * Calculate overall platform readiness as (Validated / Total) × 100
   * rounded to 1 decimal place.
   *
   * Returns 0.0 if there are no screens registered.
   */
  getReadinessPercentage(): number {
    const totalScreens = this.screens.size;
    if (totalScreens === 0) {
      return 0.0;
    }

    let validatedCount = 0;
    for (const record of this.screens.values()) {
      if (record.status === 'Validated') {
        validatedCount++;
      }
    }

    const percentage = (validatedCount / totalScreens) * 100;
    return Math.round(percentage * 10) / 10;
  }

  /**
   * Get blocking reasons for all blocked screens, grouped by vertical.
   * Useful for progress reporting alongside getSummary().
   */
  getBlockingReasons(): Record<string, Array<{ screenId: string; reason: string }>> {
    const result: Record<string, Array<{ screenId: string; reason: string }>> = {};

    for (const record of this.screens.values()) {
      if (record.status === 'Blocked') {
        if (!result[record.vertical]) {
          result[record.vertical] = [];
        }
        result[record.vertical].push({
          screenId: record.screenId,
          reason: record.reason,
        });
      }
    }

    return result;
  }

  /**
   * Get all registered screen IDs.
   */
  getScreenIds(): string[] {
    return Array.from(this.screens.keys());
  }

  /**
   * Get the total number of registered screens.
   */
  get totalScreens(): number {
    return this.screens.size;
  }
}
