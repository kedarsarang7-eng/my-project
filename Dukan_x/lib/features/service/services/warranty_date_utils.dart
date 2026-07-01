/// Warranty date utilities
/// Pure helpers for computing warranty end dates with last-day clamping.
library;

import 'dart:math' show min;

/// Computes the warranty end date exactly [warrantyMonths] months after
/// [saleDate], clamping the day to the target month's last day rather than
/// rolling into the following month.
///
/// For example, a sale on Jan 31 with +1 month yields Feb 28 (or Feb 29 in a
/// leap year), not March 3.
///
/// [warrantyMonths] must be in the inclusive range 0–120.
/// If [warrantyMonths] is 0, returns [saleDate] unchanged.
DateTime warrantyEndDate(DateTime saleDate, int warrantyMonths) {
  assert(
    warrantyMonths >= 0 && warrantyMonths <= 120,
    'warrantyMonths must be in range 0–120, got $warrantyMonths',
  );

  if (warrantyMonths == 0) return saleDate;

  // Compute target year and month, handling month overflow beyond 12.
  final totalMonths = saleDate.month + warrantyMonths;
  // (totalMonths - 1) ~/ 12 gives how many full years to add.
  final targetYear = saleDate.year + (totalMonths - 1) ~/ 12;
  // ((totalMonths - 1) % 12) + 1 maps to 1..12.
  final targetMonth = ((totalMonths - 1) % 12) + 1;

  // Last day of the target month: day 0 of the next month == last day of
  // targetMonth.
  final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;

  final clampedDay = min(saleDate.day, lastDayOfTargetMonth);

  return DateTime(targetYear, targetMonth, clampedDay);
}
