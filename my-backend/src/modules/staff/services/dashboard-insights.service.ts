// ============================================================================
// Staff Module — Dashboard Insights Service (Task 13.1)
// ============================================================================
// Pure, deterministic, side-effect-free functions for rule-based insights:
//
//   • Attendance anomaly detection via statistical variance thresholds (Req 9.3)
//   • Top/bottom performer ranking by deterministic ordering (Req 9.4)
//   • Leave pattern flagging per configured thresholds (Req 9.5)
//
// NO machine-learning or predictive models are used (Req 9.2). All insight
// logic is rule-based and statistical only. Functions are pure so that
// Properties 29–32 can test them in isolation.
//
// PROPERTY 30: Attendance anomalies flag exactly the out-of-threshold points.
// PROPERTY 31: Performer ranking is a deterministic total order of scores.
// PROPERTY 32: Leave patterns are flagged exactly per configured thresholds.
//
// Requirements: 9.1, 9.2, 9.3, 9.4, 9.5.
// ============================================================================

// ── Types ─────────────────────────────────────────────────────────────────────

/** A single attendance data point for anomaly analysis. */
export interface AttendanceDataPoint {
    employeeId: string;
    date: string;         // ISO date YYYY-MM-DD
    minutesWorked: number;
}

/** Result of attendance anomaly detection for a single data point. */
export interface AttendanceAnomaly {
    employeeId: string;
    date: string;
    minutesWorked: number;
    deviation: number;     // how many stddevs from mean
    direction: 'above' | 'below';
}

/** Configuration for attendance anomaly detection. */
export interface AnomalyThresholdConfig {
    /** Number of standard deviations beyond which a point is anomalous. */
    stdDevThreshold: number;
}

/** A performance score entry for ranking. */
export interface PerformerEntry {
    employeeId: string;
    score: number;
    period?: string;
}

/** Ranked performer result. */
export interface RankedPerformer {
    rank: number;
    employeeId: string;
    score: number;
}

/** A leave history entry for pattern analysis. */
export interface LeaveHistoryEntry {
    employeeId: string;
    from: string;        // ISO date YYYY-MM-DD
    to: string;          // ISO date YYYY-MM-DD
    leaveTypeId: string;
    dayOfWeek?: number;  // 0=Sun, 1=Mon, ..., 6=Sat (of `from` date)
}

/** Configuration for leave pattern detection thresholds. */
export interface LeavePatternConfig {
    /** Max total leave days before flagging "excessive leave". */
    maxLeaveDaysPerPeriod: number;
    /** Max occurrences of same day-of-week leaves before flagging "day pattern". */
    maxSameDayOfWeekOccurrences: number;
    /** Max consecutive short leave requests (1-day) before flagging "frequent short leave". */
    maxFrequentShortLeaves: number;
}

/** Types of leave patterns that can be flagged. */
export type LeavePatternType =
    | 'excessive_leave'
    | 'day_of_week_pattern'
    | 'frequent_short_leave';

/** A flagged leave pattern for a specific employee. */
export interface FlaggedLeavePattern {
    employeeId: string;
    patternType: LeavePatternType;
    detail: string;
    value: number;       // the actual metric that triggered the flag
    threshold: number;   // the configured threshold that was exceeded/met
}

// ── Dashboard Summary Types ───────────────────────────────────────────────────

/** Aggregated counts for the dashboard overview (Req 9.1). */
export interface DashboardSummary {
    totalEmployees: number;
    activeEmployees: number;
    totalDepartments: number;
    presentToday: number;
    absentToday: number;
    onLeaveToday: number;
    pendingLeaveRequests: number;
    openTasks: number;
    overdueTaskCount: number;
}

// ── Attendance Anomaly Detection (Req 9.3) ────────────────────────────────────

/**
 * Compute the mean of a numeric array. Returns 0 for empty arrays.
 */
export function computeMean(values: number[]): number {
    if (values.length === 0) return 0;
    const sum = values.reduce((acc, v) => acc + v, 0);
    return sum / values.length;
}

/**
 * Compute the population standard deviation of a numeric array. Returns 0 for
 * empty arrays or when all values are identical.
 */
export function computeStdDev(values: number[]): number {
    if (values.length === 0) return 0;
    const mean = computeMean(values);
    const squaredDiffs = values.map((v) => (v - mean) ** 2);
    const variance = squaredDiffs.reduce((acc, v) => acc + v, 0) / values.length;
    return Math.sqrt(variance);
}

/**
 * Detect attendance anomalies using statistical variance thresholds.
 *
 * PROPERTY 30: A data point is flagged as an anomaly IF AND ONLY IF its
 * statistical deviation (|value - mean| / stdDev) exceeds the configured
 * threshold. When stdDev is 0 (all values identical), no point is anomalous.
 *
 * This is a PURE function — no I/O, no randomness, no ML (Req 9.2).
 *
 * @param dataPoints  - attendance time series (minutesWorked per employee per day)
 * @param config      - threshold configuration (stdDevThreshold)
 * @returns           - list of flagged anomalies
 */
export function detectAttendanceAnomalies(
    dataPoints: AttendanceDataPoint[],
    config: AnomalyThresholdConfig,
): AttendanceAnomaly[] {
    if (dataPoints.length === 0) return [];

    const values = dataPoints.map((dp) => dp.minutesWorked);
    const mean = computeMean(values);
    const stdDev = computeStdDev(values);

    // If stdDev is 0, all values are the same — no anomalies possible.
    if (stdDev === 0) return [];

    const anomalies: AttendanceAnomaly[] = [];

    for (const dp of dataPoints) {
        const deviation = Math.abs(dp.minutesWorked - mean) / stdDev;
        if (deviation > config.stdDevThreshold) {
            anomalies.push({
                employeeId: dp.employeeId,
                date: dp.date,
                minutesWorked: dp.minutesWorked,
                deviation,
                direction: dp.minutesWorked > mean ? 'above' : 'below',
            });
        }
    }

    return anomalies;
}

// ── Performer Ranking (Req 9.4) ──────────────────────────────────────────────

/**
 * Rank performers by score using a deterministic total order.
 *
 * PROPERTY 31: The ranking is a deterministic ordering by score (descending),
 * with a stable tie-break by employeeId (ascending lexicographic). Equal inputs
 * ALWAYS produce the same ranking.
 *
 * This is a PURE function — no I/O, no randomness (Req 9.2).
 *
 * @param entries - the performance score entries to rank
 * @returns       - sorted array with rank numbers (1-based)
 */
export function rankPerformers(entries: PerformerEntry[]): RankedPerformer[] {
    if (entries.length === 0) return [];

    // Sort by score descending; break ties by employeeId ascending (deterministic).
    const sorted = [...entries].sort((a, b) => {
        if (b.score !== a.score) return b.score - a.score;
        return a.employeeId.localeCompare(b.employeeId);
    });

    return sorted.map((entry, index) => ({
        rank: index + 1,
        employeeId: entry.employeeId,
        score: entry.score,
    }));
}

/**
 * Get the top N performers from a ranked list.
 */
export function topPerformers(entries: PerformerEntry[], n: number): RankedPerformer[] {
    return rankPerformers(entries).slice(0, Math.max(0, n));
}

/**
 * Get the bottom N performers from a ranked list.
 */
export function bottomPerformers(entries: PerformerEntry[], n: number): RankedPerformer[] {
    const ranked = rankPerformers(entries);
    return ranked.slice(Math.max(0, ranked.length - n));
}

// ── Leave Pattern Flagging (Req 9.5) ─────────────────────────────────────────

/**
 * Compute inclusive whole-day duration between two ISO date strings.
 */
function leaveDurationDays(from: string, to: string): number {
    const MS_PER_DAY = 24 * 60 * 60 * 1000;
    const fromMs = Date.parse(`${from}T00:00:00.000Z`);
    const toMs = Date.parse(`${to}T00:00:00.000Z`);
    if (Number.isNaN(fromMs) || Number.isNaN(toMs) || fromMs > toMs) return 0;
    return Math.round((toMs - fromMs) / MS_PER_DAY) + 1;
}

/**
 * Get the day of week (0=Sun…6=Sat) for an ISO date string.
 */
function dayOfWeekFromDate(isoDate: string): number {
    return new Date(`${isoDate}T00:00:00.000Z`).getUTCDay();
}

/**
 * Detect leave patterns per configured rule thresholds.
 *
 * PROPERTY 32: A pattern is flagged IF AND ONLY IF the employee's leave history
 * meets or exceeds the configured threshold. This is a PURE function — no I/O,
 * no ML (Req 9.2).
 *
 * Patterns detected:
 *  1. "excessive_leave" — total leave days in the period >= maxLeaveDaysPerPeriod
 *  2. "day_of_week_pattern" — same day-of-week >= maxSameDayOfWeekOccurrences
 *  3. "frequent_short_leave" — number of 1-day leaves >= maxFrequentShortLeaves
 *
 * @param history  - leave history entries (approved leaves for analysis)
 * @param config   - threshold configuration
 * @returns        - list of flagged patterns grouped per employee
 */
export function detectLeavePatterns(
    history: LeaveHistoryEntry[],
    config: LeavePatternConfig,
): FlaggedLeavePattern[] {
    if (history.length === 0) return [];

    const flagged: FlaggedLeavePattern[] = [];

    // Group by employee
    const byEmployee = new Map<string, LeaveHistoryEntry[]>();
    for (const entry of history) {
        const existing = byEmployee.get(entry.employeeId) || [];
        existing.push(entry);
        byEmployee.set(entry.employeeId, existing);
    }

    for (const [employeeId, entries] of byEmployee) {
        // 1. Excessive leave: total days taken
        const totalDays = entries.reduce(
            (sum, e) => sum + leaveDurationDays(e.from, e.to),
            0,
        );
        if (totalDays >= config.maxLeaveDaysPerPeriod) {
            flagged.push({
                employeeId,
                patternType: 'excessive_leave',
                detail: `Total ${totalDays} leave days (threshold: ${config.maxLeaveDaysPerPeriod})`,
                value: totalDays,
                threshold: config.maxLeaveDaysPerPeriod,
            });
        }

        // 2. Day-of-week pattern: count occurrences of each start-day-of-week
        const dayOfWeekCounts = new Map<number, number>();
        for (const entry of entries) {
            const dow = entry.dayOfWeek ?? dayOfWeekFromDate(entry.from);
            dayOfWeekCounts.set(dow, (dayOfWeekCounts.get(dow) ?? 0) + 1);
        }
        for (const [dow, count] of dayOfWeekCounts) {
            if (count >= config.maxSameDayOfWeekOccurrences) {
                const dayName = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][dow] ?? `day${dow}`;
                flagged.push({
                    employeeId,
                    patternType: 'day_of_week_pattern',
                    detail: `Leave on ${dayName} occurred ${count} times (threshold: ${config.maxSameDayOfWeekOccurrences})`,
                    value: count,
                    threshold: config.maxSameDayOfWeekOccurrences,
                });
            }
        }

        // 3. Frequent short leaves: count 1-day leave requests
        const shortLeaveCount = entries.filter(
            (e) => leaveDurationDays(e.from, e.to) === 1,
        ).length;
        if (shortLeaveCount >= config.maxFrequentShortLeaves) {
            flagged.push({
                employeeId,
                patternType: 'frequent_short_leave',
                detail: `${shortLeaveCount} single-day leaves (threshold: ${config.maxFrequentShortLeaves})`,
                value: shortLeaveCount,
                threshold: config.maxFrequentShortLeaves,
            });
        }
    }

    return flagged;
}
