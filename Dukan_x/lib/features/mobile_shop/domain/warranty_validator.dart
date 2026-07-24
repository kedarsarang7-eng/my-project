/// Warranty Validator — Domain Logic (Dart)
///
/// Validates warranty month ranges against configured bounds and calculates
/// warranty end dates using the last valid day of the target month.
///
/// Fixes:
/// - AF-43: Current code uses DateTime(year, month+N, day) which overflows month-end days.
/// - AF-44: No range/negative guard on warranty months input.
///
/// Requirements: 5.5–5.7, 12.1–12.2, 12.6; GR-2.1
library;

import 'package:flutter/foundation.dart';
import '../config/bounds_config.dart';

// ─── Error Types ─────────────────────────────────────────────────────────────

/// Warranty validation error codes.
enum WarrantyValidationErrorCode {
  warrantyMonthsRequired,
  warrantyMonthsNotInteger,
  warrantyMonthsNotPositive,
  warrantyMonthsBelowMin,
  warrantyMonthsAboveMax,
  warrantySaleDateRequired,
  warrantySaleDateInvalid,
}

/// Field-associated warranty validation error.
@immutable
class WarrantyValidationError {
  /// The error code enum.
  final WarrantyValidationErrorCode code;

  /// Stable string code matching the backend contract.
  final String codeString;

  /// Associated field name.
  final String field;

  /// Human-readable message.
  final String message;

  const WarrantyValidationError({
    required this.code,
    required this.codeString,
    required this.field,
    required this.message,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WarrantyValidationError &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'WarrantyValidationError($codeString: $message)';
}

// ─── Result Types ────────────────────────────────────────────────────────────

/// Sealed result for warranty month validation.
sealed class WarrantyMonthsResult {
  const WarrantyMonthsResult();
}

@immutable
class WarrantyMonthsSuccess extends WarrantyMonthsResult {
  final int value;
  const WarrantyMonthsSuccess(this.value);
}

@immutable
class WarrantyMonthsFailure extends WarrantyMonthsResult {
  final WarrantyValidationError error;
  const WarrantyMonthsFailure(this.error);
}

/// Sealed result for full warranty registration validation.
sealed class WarrantyRegistrationResult {
  const WarrantyRegistrationResult();
}

@immutable
class WarrantyRegistrationSuccess extends WarrantyRegistrationResult {
  final int warrantyMonths;
  final String warrantyEndDate;
  final String? provider;
  final String? notes;

  const WarrantyRegistrationSuccess({
    required this.warrantyMonths,
    required this.warrantyEndDate,
    this.provider,
    this.notes,
  });
}

@immutable
class WarrantyRegistrationFailure extends WarrantyRegistrationResult {
  final WarrantyValidationError error;
  const WarrantyRegistrationFailure(this.error);
}

// ─── Month Utility ───────────────────────────────────────────────────────────

/// Returns the number of days in a given month (1-indexed) for a given year.
/// Handles leap years correctly.
int getDaysInMonth(int year, int month) {
  // DateTime(year, month + 1, 0) gives the last day of `month`.
  return DateTime(year, month + 1, 0).day;
}

// ─── Warranty Months Validation ──────────────────────────────────────────────

/// Validates warranty months against configured bounds.
///
/// Rejects:
/// - null
/// - Non-positive (zero or negative)
/// - Values below configured minimum
/// - Values above configured maximum
///
/// Note: Dart's type system handles the "must be integer" requirement since
/// this function accepts `int?`, but we still guard against logical issues.
WarrantyMonthsResult validateWarrantyMonths(int? months) {
  // Null check
  if (months == null) {
    return const WarrantyMonthsFailure(
      WarrantyValidationError(
        code: WarrantyValidationErrorCode.warrantyMonthsRequired,
        codeString: 'WARRANTY_MONTHS_REQUIRED',
        field: 'warrantyMonths',
        message: 'Warranty months is required',
      ),
    );
  }

  // Positive check (zero and negative)
  if (months <= 0) {
    return const WarrantyMonthsFailure(
      WarrantyValidationError(
        code: WarrantyValidationErrorCode.warrantyMonthsNotPositive,
        codeString: 'WARRANTY_MONTHS_NOT_POSITIVE',
        field: 'warrantyMonths',
        message: 'Warranty months must be a positive integer',
      ),
    );
  }

  // Configured range check
  final minMonths = kBoundsConfig.warranty.minMonths;
  final maxMonths = kBoundsConfig.warranty.maxMonths;

  if (months < minMonths) {
    return WarrantyMonthsFailure(
      WarrantyValidationError(
        code: WarrantyValidationErrorCode.warrantyMonthsBelowMin,
        codeString: 'WARRANTY_MONTHS_BELOW_MIN',
        field: 'warrantyMonths',
        message: 'Warranty months must be at least $minMonths',
      ),
    );
  }

  if (months > maxMonths) {
    return WarrantyMonthsFailure(
      WarrantyValidationError(
        code: WarrantyValidationErrorCode.warrantyMonthsAboveMax,
        codeString: 'WARRANTY_MONTHS_ABOVE_MAX',
        field: 'warrantyMonths',
        message: 'Warranty months must not exceed $maxMonths',
      ),
    );
  }

  return WarrantyMonthsSuccess(months);
}

// ─── Warranty End Date Calculation ───────────────────────────────────────────

/// Calculates warranty end date from a sale date plus warranty months.
///
/// Correctly handles month-end dates: if saleDate is Jan 31 and months is 1,
/// the result is Feb 28 (or Feb 29 in a leap year).
///
/// Algorithm:
///   1. Extract year, month, day from saleDate
///   2. Add months to get targetMonth; normalize year overflow
///   3. Get last day of target month
///   4. Clamp sale day to target month's last day
///   5. Return ISO 8601 date string (YYYY-MM-DD)
///
/// Fixes AF-43: replaces naive DateTime(year, month+N, day) overflow.
String calculateWarrantyEndDate(DateTime saleDate, int months) {
  final saleYear = saleDate.year;
  final saleMonth = saleDate.month; // 1-indexed in Dart
  final saleDay = saleDate.day;

  // Add months and normalize
  int targetMonth = saleMonth + months;
  int targetYear = saleYear + ((targetMonth - 1) ~/ 12);
  targetMonth = ((targetMonth - 1) % 12) + 1;

  // Get last day of target month
  final lastDay = getDaysInMonth(targetYear, targetMonth);

  // Clamp sale day to target month's last day
  final day = saleDay < lastDay ? saleDay : lastDay;

  // Format as ISO date string (YYYY-MM-DD)
  final yyyy = targetYear.toString().padLeft(4, '0');
  final mm = targetMonth.toString().padLeft(2, '0');
  final dd = day.toString().padLeft(2, '0');

  return '$yyyy-$mm-$dd';
}

// ─── Full Warranty Registration Validation ───────────────────────────────────

/// Validates all warranty registration fields together.
///
/// Preserves valid sibling fields: if warrantyMonths fails, other fields
/// (provider, notes) remain available in the error context.
WarrantyRegistrationResult validateWarrantyRegistration({
  required DateTime? saleDate,
  required int? warrantyMonths,
  String? provider,
  String? notes,
}) {
  // Validate sale date
  if (saleDate == null) {
    return const WarrantyRegistrationFailure(
      WarrantyValidationError(
        code: WarrantyValidationErrorCode.warrantySaleDateRequired,
        codeString: 'WARRANTY_SALE_DATE_REQUIRED',
        field: 'saleDate',
        message: 'Sale date is required for warranty registration',
      ),
    );
  }

  // Validate warranty months
  final monthsResult = validateWarrantyMonths(warrantyMonths);
  if (monthsResult is WarrantyMonthsFailure) {
    return WarrantyRegistrationFailure(monthsResult.error);
  }

  final validMonths = (monthsResult as WarrantyMonthsSuccess).value;

  // Calculate end date
  final warrantyEndDate = calculateWarrantyEndDate(saleDate, validMonths);

  return WarrantyRegistrationSuccess(
    warrantyMonths: validMonths,
    warrantyEndDate: warrantyEndDate,
    provider: provider,
    notes: notes,
  );
}
