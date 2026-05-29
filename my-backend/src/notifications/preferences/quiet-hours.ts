// ============================================================================
// Preference_Engine — Quiet_Hours Evaluation
// ============================================================================
// Evaluates whether a given timestamp falls within a recipient's
// configured quiet-hours window in the recipient's local timezone.
//
// Quiet-hours config lives on `UserPreferenceRecord` (REQ 6.2):
//   - `quiet_hours_start`    — `HH:MM` (24-hour, local)
//   - `quiet_hours_end`      — `HH:MM` (24-hour, local)
//   - `quiet_hours_timezone` — IANA name (e.g. `Asia/Kolkata`)
//
// Wrap-around is supported (e.g. 22:00 → 06:00 spans midnight). The
// boundary semantics are:
//   - start time is INCLUSIVE
//   - end time is EXCLUSIVE
// so a 22:00→06:00 window suppresses 22:00 through 05:59 inclusive but
// allows 06:00. This matches the way "do not disturb" UIs typically
// describe the range to users.
//
// Validates: REQ 7.3, 7.8.
// ============================================================================

import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { logger } from '../../utils/logger';
import type { QuietHours } from '../store/types';

// dayjs plugins are idempotent — extending more than once is a no-op.
dayjs.extend(utc);
dayjs.extend(timezone);

// ---- Public types --------------------------------------------------------

/**
 * Result of a quiet-hours evaluation. The `reason` field is present only
 * when the input was malformed or incomplete; callers can log it for
 * operator triage but the boolean `inQuietHours` is what drives the
 * resolver.
 */
export interface QuietHoursEvaluation {
    readonly inQuietHours: boolean;
    readonly reason?: 'no_config' | 'invalid_time' | 'invalid_timezone';
}

// ---- HH:MM parsing -------------------------------------------------------

/**
 * Strict `HH:MM` parser. Returns the minute-of-day index (0..1439) on
 * success or `null` on failure.
 */
export function parseHHMM(value: string): number | null {
    // Match HH:MM with HH in [0, 23] and MM in [0, 59]. We avoid permissive
    // parsing (e.g. `dayjs(value, 'HH:mm')`) because the registry-driven
    // tests need predictable rejection of garbage input.
    const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(value);
    if (!m) return null;
    const hours = Number.parseInt(m[1], 10);
    const minutes = Number.parseInt(m[2], 10);
    return hours * 60 + minutes;
}

// ---- Core evaluation -----------------------------------------------------

/**
 * Returns whether `now` falls inside the recipient's quiet-hours window.
 *
 * Semantics:
 *   - If any of `quiet_hours_start`, `quiet_hours_end`,
 *     `quiet_hours_timezone` is missing, returns `inQuietHours: false`
 *     with `reason: 'no_config'` — the recipient simply has no quiet
 *     hours configured.
 *   - If the timezone is unknown to the runtime ICU data, returns
 *     `inQuietHours: false` with `reason: 'invalid_timezone'`. We err on
 *     the side of delivering rather than silently suppressing on bad
 *     config.
 *   - If `start === end`, the window is empty (no quiet hours). This
 *     matches the way most UIs render an "off" state.
 *   - If `start < end` (same calendar day window), the recipient is in
 *     quiet hours when `start <= localMinute < end`.
 *   - If `start > end` (wrap-around past midnight), the recipient is in
 *     quiet hours when `localMinute >= start OR localMinute < end`.
 */
export function isInQuietHours(
    now: Date,
    prefs: Pick<
        QuietHours,
        'quiet_hours_start' | 'quiet_hours_end' | 'quiet_hours_timezone'
    >,
): QuietHoursEvaluation {
    const { quiet_hours_start, quiet_hours_end, quiet_hours_timezone } = prefs;

    // 1) Configuration completeness check.
    if (!quiet_hours_start || !quiet_hours_end || !quiet_hours_timezone) {
        return { inQuietHours: false, reason: 'no_config' };
    }

    // 2) HH:MM parsing.
    const startMin = parseHHMM(quiet_hours_start);
    const endMin = parseHHMM(quiet_hours_end);
    if (startMin === null || endMin === null) {
        return { inQuietHours: false, reason: 'invalid_time' };
    }

    // 3) Empty window — `start === end` means quiet hours are effectively
    //    disabled.
    if (startMin === endMin) {
        return { inQuietHours: false };
    }

    // 4) Compute the local minute-of-day at the recipient's timezone.
    let localMinute: number;
    try {
        const local = dayjs(now).tz(quiet_hours_timezone);
        // dayjs `.tz()` returns an `Invalid Date` Dayjs when the tz is
        // unknown to the runtime; guard against that.
        if (!local.isValid()) {
            return { inQuietHours: false, reason: 'invalid_timezone' };
        }
        localMinute = local.hour() * 60 + local.minute();
    } catch (err) {
        // Some Node builds throw `RangeError` for unknown IANA names.
        logger.debug(
            '[Preference_Engine] quiet-hours timezone evaluation failed',
            {
                quiet_hours_timezone,
                error: err instanceof Error ? err.message : String(err),
            },
        );
        return { inQuietHours: false, reason: 'invalid_timezone' };
    }

    // 5) Window membership — same-day vs wrap-around.
    // The wrap-around case is the common one for "do not disturb" windows
    // that cross midnight (22:00 -> 06:00) and is the reason we cannot use
    // a simple `start <= t < end` predicate.
    const inWindow =
        startMin < endMin
            ? localMinute >= startMin && localMinute < endMin
            : // wrap-around: e.g. 22:00 -> 06:00
              localMinute >= startMin || localMinute < endMin;

    return { inQuietHours: inWindow };
}
