// ============================================================================
// Timezone Utilities — IST/UTC Normalization for Reports
// ============================================================================
// Provides helpers for converting report date ranges from tenant timezone
// (default IST/Asia/Kolkata) to UTC for DynamoDB queries.
//
// Problem: Users expect April 1-30 report to include 00:00 IST to 23:59 IST,
// but naive UTC conversion gives 00:00 UTC to 23:59 UTC (wrong boundaries).
// ============================================================================

import dayjs, { Dayjs } from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';

dayjs.extend(utc);
dayjs.extend(timezone);

/**
 * Normalize a date range from tenant timezone to UTC boundaries for DynamoDB queries.
 *
 * Example:
 *   Input: fromDateIST="2026-04-01", toDateIST="2026-04-30", tenantTimezone="Asia/Kolkata"
 *   Output: {
 *     fromUTC: "2026-03-31T18:30:00.000Z",  (April 1 00:00 IST = March 31 18:30 UTC)
 *     toUTC: "2026-04-30T18:29:59.999Z"     (April 30 23:59 IST = April 30 18:29 UTC)
 *   }
 */
export interface DateRangeBoundaries {
  fromUTC: string;
  toUTC: string;
  fromDateIST: string;  // Original date (YYYY-MM-DD)
  toDateIST: string;    // Original date (YYYY-MM-DD)
  tenantTimezone: string;
}

export function normalizeDateRangeForQuery(
  fromDate: string,  // YYYY-MM-DD format (user's local date)
  toDate: string,    // YYYY-MM-DD format (user's local date)
  tenantTimezone = 'Asia/Kolkata'  // Default to IST
): DateRangeBoundaries {
  // Parse dates in tenant's timezone
  const fromIST = dayjs(fromDate)
    .tz(tenantTimezone)
    .startOf('day');  // 2026-04-01 00:00:00 IST

  const toIST = dayjs(toDate)
    .tz(tenantTimezone)
    .endOf('day');  // 2026-04-30 23:59:59.999 IST

  // Convert to UTC for DynamoDB
  const fromUTC = fromIST.utc().toISOString();
  const toUTC = toIST.utc().toISOString();

  return {
    fromUTC,
    toUTC,
    fromDateIST: fromDate,
    toDateIST: toDate,
    tenantTimezone,
  };
}

/**
 * Get current date in a specific timezone (useful for default date ranges).
 */
export function getDateInTimezone(timezone = 'Asia/Kolkata'): string {
  return dayjs().tz(timezone).format('YYYY-MM-DD');
}

/**
 * Get start of month in a specific timezone.
 */
export function getMonthStartInTimezone(timezone = 'Asia/Kolkata'): string {
  return dayjs().tz(timezone).startOf('month').format('YYYY-MM-DD');
}

/**
 * Convert a UTC ISO string to tenant timezone and format as date.
 */
export function formatDateInTimezone(
  isoDate: string,
  tenantTimezone = 'Asia/Kolkata',
  format = 'YYYY-MM-DD'
): string {
  return dayjs(isoDate).tz(tenantTimezone).format(format);
}

/**
 * Parse a date range string (e.g., "2026-04-01 to 2026-04-30") and return UTC boundaries.
 */
export function parseAndNormalizeDateRange(
  dateRangeString: string,
  tenantTimezone = 'Asia/Kolkata'
): DateRangeBoundaries | null {
  const match = dateRangeString.match(
    /^(\d{4}-\d{2}-\d{2})\s+(?:to|through)\s+(\d{4}-\d{2}-\d{2})$/i
  );
  if (!match) return null;

  const [, fromDate, toDate] = match;
  return normalizeDateRangeForQuery(fromDate, toDate, tenantTimezone);
}

/**
 * Validate that a date string is in YYYY-MM-DD format.
 */
export function isValidDateFormat(dateStr: string): boolean {
  const regex = /^\d{4}-\d{2}-\d{2}$/;
  if (!regex.test(dateStr)) return false;

  const date = dayjs(dateStr);
  return date.isValid();
}
