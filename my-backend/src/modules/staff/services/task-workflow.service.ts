// ============================================================================
// Staff Module — Task Workflow Service (Task 7.1)
// ============================================================================
// Pure, deterministic, side-effect-free functions that implement the three
// testable behaviours of task workflow. Keeping them pure makes them trivially
// unit- and property-testable and lets handlers/repositories compose them
// without any DynamoDB coupling.
//
//   • generateOccurrences  — recurring tasks (Property 16, Req 5.3)
//   • canCompleteTask       — dependency gating   (Property 17, Req 5.4)
//   • evaluateEscalation    — escalation trigger  (Property 18, Req 5.5)
//
// DATE HANDLING: recurrence works on calendar dates ('YYYY-MM-DD') interpreted
// at UTC midnight to stay free of timezone drift. Weekly recurrence groups by a
// Sunday-anchored week (weekday 0 = Sunday), which is the convention documented
// on RecurrenceRule.byWeekday.
// ============================================================================

import {
    RecurrenceRule,
    TaskStatus,
    TASK_DONE_STATUS,
    TaskEscalation,
} from '../schemas/task.schema';

// ── Date helpers (UTC, calendar-date granularity) ────────────────────────────

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** Parse 'YYYY-MM-DD' to a UTC-midnight epoch (ms). */
function parseDate(date: string): number {
    const [y, m, d] = date.split('-').map(Number);
    return Date.UTC(y, m - 1, d);
}

/** Format a UTC-midnight epoch (ms) back to 'YYYY-MM-DD'. */
function formatDate(epochMs: number): string {
    const dt = new Date(epochMs);
    const y = dt.getUTCFullYear().toString().padStart(4, '0');
    const m = (dt.getUTCMonth() + 1).toString().padStart(2, '0');
    const d = dt.getUTCDate().toString().padStart(2, '0');
    return `${y}-${m}-${d}`;
}

function addDays(epochMs: number, days: number): number {
    return epochMs + days * MS_PER_DAY;
}

/** Add `months` calendar months, returning null if the day-of-month overflows. */
function addMonthsExact(epochMs: number, months: number): number | null {
    const dt = new Date(epochMs);
    const day = dt.getUTCDate();
    const targetMonthIndex = dt.getUTCMonth() + months;
    const targetYear = dt.getUTCFullYear() + Math.floor(targetMonthIndex / 12);
    const normalizedMonth = ((targetMonthIndex % 12) + 12) % 12;
    const candidate = Date.UTC(targetYear, normalizedMonth, day);
    // If the day rolled into the next month (e.g. Jan 31 + 1mo), the rule does
    // not prescribe an occurrence for that month — skip it (standard behaviour).
    if (new Date(candidate).getUTCMonth() !== normalizedMonth) return null;
    return candidate;
}

/** UTC weekday, 0 = Sunday .. 6 = Saturday. */
function weekday(epochMs: number): number {
    return new Date(epochMs).getUTCDay();
}

// ── Property 16 — recurrence generation ───────────────────────────────────────

export interface DateWindow {
    /** Inclusive window start 'YYYY-MM-DD'. */
    from: string;
    /** Inclusive window end 'YYYY-MM-DD'. */
    to: string;
}

// Safety cap so a malformed rule can never produce an unbounded sequence.
const MAX_OCCURRENCES = 10000;

/**
 * Produce the prescribed occurrence dates (epoch ms) in strict chronological
 * order, up to `limit` items. This is the single source of truth for what a
 * rule prescribes; window/count/until bounds are applied by the caller.
 */
function prescribedSequence(rule: RecurrenceRule, limit: number): number[] {
    const start = parseDate(rule.startDate);
    const out: number[] = [];

    if (rule.frequency === 'daily') {
        for (let i = 0; i < limit; i++) out.push(addDays(start, i * rule.interval));
        return out;
    }

    if (rule.frequency === 'weekly') {
        // Anchor to the Sunday of the week containing startDate (weekday 0 = Sun).
        const weekStart = addDays(start, -weekday(start));
        const weekdays = (
            rule.byWeekday && rule.byWeekday.length > 0
                ? [...new Set(rule.byWeekday)]
                : [weekday(start)]
        ).sort((a, b) => a - b);

        for (let w = 0; out.length < limit; w++) {
            for (const wd of weekdays) {
                const day = addDays(weekStart, w * rule.interval * 7 + wd);
                // Occurrences before the anchor date are not prescribed.
                if (day < start) continue;
                out.push(day);
                if (out.length >= limit) break;
            }
            // Safety: bail out if the block index grows absurdly large.
            if (w > MAX_OCCURRENCES) break;
        }
        return out;
    }

    // monthly — skip months where the day-of-month overflows (e.g. Feb 30).
    for (let i = 0; out.length < limit && i < MAX_OCCURRENCES; i++) {
        const day = addMonthsExact(start, i * rule.interval);
        if (day !== null) out.push(day);
    }
    return out;
}

/**
 * Generate the set of occurrence dates ('YYYY-MM-DD') a recurrence rule
 * prescribes that also fall within the (inclusive) window.
 *
 * The prescribed sequence is walked from `startDate` in chronological order so
 * that `count` (total occurrences from the start) is honoured even for
 * occurrences that precede the window. The returned list is sorted ascending,
 * contains no duplicates, and is empty when the window excludes every
 * occurrence.
 *
 * Property 16: the result equals exactly the dates the rule prescribes within
 * the window.
 */
export function generateOccurrences(rule: RecurrenceRule, window: DateWindow): string[] {
    const windowFrom = parseDate(window.from);
    const windowTo = parseDate(window.to);
    if (windowTo < windowFrom) return [];

    const untilBound = rule.until ? parseDate(rule.until) : undefined;
    // The chronological sequence stops at min(until, windowTo); count caps its length.
    const upperBound = untilBound !== undefined ? Math.min(untilBound, windowTo) : windowTo;

    const limit = rule.count ?? MAX_OCCURRENCES;
    const sequence = prescribedSequence(rule, limit);

    const result = new Set<string>();
    for (const day of sequence) {
        // `sequence` is chronological, so once we pass the upper bound we can stop.
        if (day > upperBound) break;
        if (day >= windowFrom) result.add(formatDate(day));
    }
    return [...result].sort();
}

// ── Property 17 — dependency gating ───────────────────────────────────────────

/** True iff `status` is the terminal/complete status. */
export function isComplete(status: TaskStatus | undefined): boolean {
    return status === TASK_DONE_STATUS;
}

export interface DependencyGateResult {
    /** True iff the task may be marked complete now. */
    allowed: boolean;
    /** Prerequisite ids that are not complete (empty when allowed). */
    blockedBy: string[];
}

/**
 * Decide whether a task with the given prerequisites may transition to
 * complete. A dependent task can be completed IFF every prerequisite is already
 * complete (Property 17, Req 5.4).
 *
 * @param dependsOn        prerequisite task ids (undefined/empty ⇒ no gate).
 * @param prerequisiteStatus  status of each prerequisite by id. A prerequisite
 *   that is absent from the map is treated as NOT complete (fail-closed) and is
 *   reported in `blockedBy`.
 */
export function canCompleteTask(
    dependsOn: string[] | undefined,
    prerequisiteStatus: Readonly<Record<string, TaskStatus>>,
): DependencyGateResult {
    if (!dependsOn || dependsOn.length === 0) {
        return { allowed: true, blockedBy: [] };
    }
    const blockedBy = dependsOn.filter((id) => !isComplete(prerequisiteStatus[id]));
    return { allowed: blockedBy.length === 0, blockedBy };
}

// ── Property 18 — escalation trigger ──────────────────────────────────────────

export interface EscalationDecision {
    /** True iff the escalation action must be triggered now. */
    shouldEscalate: boolean;
    /** The configured action to trigger (present only when shouldEscalate). */
    action?: string;
}

/**
 * Decide whether a task's escalation action should fire. The action triggers
 * IFF an escalation policy is configured, the task has NOT progressed to
 * completion, and the elapsed time-without-progress has reached/passed the
 * configured threshold (Property 18, Req 5.5).
 *
 * `alreadyEscalated` guarantees at-most-once triggering: a task that has
 * already escalated does not escalate again.
 *
 * @param escalation       the task's escalation policy (undefined ⇒ never fires).
 * @param status           the task's current status.
 * @param elapsedHours     hours since the task last progressed.
 * @param alreadyEscalated whether the escalation action has already fired.
 */
export function evaluateEscalation(
    escalation: TaskEscalation | undefined,
    status: TaskStatus,
    elapsedHours: number,
    alreadyEscalated = false,
): EscalationDecision {
    if (!escalation || alreadyEscalated || isComplete(status)) {
        return { shouldEscalate: false };
    }
    if (elapsedHours >= escalation.thresholdHours) {
        return { shouldEscalate: true, action: escalation.action };
    }
    return { shouldEscalate: false };
}

/** Elapsed whole/fractional hours between an ISO timestamp and `now`. */
export function elapsedHoursSince(isoTimestamp: string, now: Date = new Date()): number {
    const then = new Date(isoTimestamp).getTime();
    return (now.getTime() - then) / (60 * 60 * 1000);
}
