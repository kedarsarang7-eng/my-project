/// IMEI Validator — One Authoritative Validation Path (Dart)
///
/// Applies configured separator normalization, 15 ASCII digits, Luhn checksum,
/// required-field behavior, and field-associated errors.
///
/// This is the ONLY IMEI validation path used by UI, repository, sync, and backend.
/// Uniqueness and lifecycle state are NOT validated here — those require DynamoDB
/// conditional writes (reserved for persistence layer).
///
/// Requirements: 2.5–2.6, 3.1–3.2, 3.12, 4.2–4.4, 12.1–12.3
/// Replaces: AF-42 weak `_guessIMEIType` heuristic
library;

import 'package:flutter/foundation.dart';
import '../config/validation_config.dart';

// ─── Branded value type ──────────────────────────────────────────────────────

/// A normalized 15-digit IMEI that has passed all local validation checks.
@immutable
class NormalizedImei {
  /// The validated 15-digit string (ASCII digits only).
  final String value;

  const NormalizedImei._(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalizedImei &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

// ─── Error types ─────────────────────────────────────────────────────────────

/// IMEI validation error codes (local checks only, no uniqueness/lifecycle).
enum ImeiValidationErrorCode {
  imeiRequired,
  imeiInvalidCharacters,
  imeiInvalidLength,
  imeiInvalidChecksum,
}

/// Field-associated IMEI validation error.
@immutable
class ImeiValidationError {
  /// The error code.
  final ImeiValidationErrorCode code;

  /// The stable string code matching the backend contract.
  final String codeString;

  /// Associated field name.
  final String field;

  /// Human-readable message.
  final String message;

  const ImeiValidationError({
    required this.code,
    required this.codeString,
    required this.field,
    required this.message,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImeiValidationError &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'ImeiValidationError($codeString: $message)';
}

// ─── Result type ─────────────────────────────────────────────────────────────

/// Sealed result for IMEI validation.
sealed class ImeiValidationResult {
  const ImeiValidationResult();
}

/// Successful validation result containing the normalized IMEI.
@immutable
class ImeiValidationSuccess extends ImeiValidationResult {
  final NormalizedImei value;
  const ImeiValidationSuccess(this.value);
}

/// Failed validation result containing the error.
@immutable
class ImeiValidationFailure extends ImeiValidationResult {
  final ImeiValidationError error;
  const ImeiValidationFailure(this.error);
}

// ─── Luhn algorithm ──────────────────────────────────────────────────────────

/// Validates the Luhn checksum for a 15-digit IMEI string.
///
/// For a 15-digit string, doubling applies to digits at odd indices (0-based)
/// counting from the left — equivalent to even positions from the right.
bool isValidLuhn(String digits) {
  if (digits.length != 15) return false;

  int sum = 0;
  for (int i = 0; i < 15; i++) {
    int digit = digits.codeUnitAt(i) - 48; // '0' = 48
    // Double digits at odd indices (1,3,5,...13)
    if (i % 2 == 1) {
      digit *= 2;
      if (digit > 9) {
        digit -= 9;
      }
    }
    sum += digit;
  }

  return sum % 10 == 0;
}

// ─── Validator ───────────────────────────────────────────────────────────────

/// Validates and normalizes a raw IMEI input string.
///
/// Validation precedence (from kValidationConfig):
///  1. Required check (priority 10)
///  2. Separator normalization + ASCII-digit-only check (priority 20)
///  3. Length check — exactly 15 digits (priority 30)
///  4. Luhn checksum (priority 40)
///
/// Does NOT check uniqueness (priority 50) or lifecycle (priority 60) —
/// those are DynamoDB conditional write concerns.
ImeiValidationResult validateImei(String? raw) {
  // 1. Required check
  if (raw == null || raw.trim().isEmpty) {
    return const ImeiValidationFailure(
      ImeiValidationError(
        code: ImeiValidationErrorCode.imeiRequired,
        codeString: 'IMEI_REQUIRED',
        field: 'imei',
        message: 'IMEI is required',
      ),
    );
  }

  // 2. Separator normalization: remove configured separators
  String normalized = raw;
  for (final sep in kValidationConfig.imeiSeparators) {
    normalized = normalized.replaceAll(sep, '');
  }

  // Check if normalization resulted in empty string (e.g. input was only separators)
  if (normalized.trim().isEmpty) {
    return const ImeiValidationFailure(
      ImeiValidationError(
        code: ImeiValidationErrorCode.imeiRequired,
        codeString: 'IMEI_REQUIRED',
        field: 'imei',
        message: 'IMEI is required',
      ),
    );
  }

  // ASCII-digit-only check
  final digitPattern = RegExp(r'^[0-9]+$');
  if (!digitPattern.hasMatch(normalized)) {
    return const ImeiValidationFailure(
      ImeiValidationError(
        code: ImeiValidationErrorCode.imeiInvalidCharacters,
        codeString: 'IMEI_INVALID_CHARACTERS',
        field: 'imei',
        message: 'IMEI must contain only ASCII digits (0-9)',
      ),
    );
  }

  // 3. Length check — exactly 15 digits
  if (normalized.length != kValidationConfig.imeiLength) {
    return ImeiValidationFailure(
      ImeiValidationError(
        code: ImeiValidationErrorCode.imeiInvalidLength,
        codeString: 'IMEI_INVALID_LENGTH',
        field: 'imei',
        message: 'IMEI must be exactly ${kValidationConfig.imeiLength} digits',
      ),
    );
  }

  // 4. Luhn checksum
  if (!isValidLuhn(normalized)) {
    return const ImeiValidationFailure(
      ImeiValidationError(
        code: ImeiValidationErrorCode.imeiInvalidChecksum,
        codeString: 'IMEI_INVALID_CHECKSUM',
        field: 'imei',
        message: 'IMEI fails Luhn checksum validation',
      ),
    );
  }

  return ImeiValidationSuccess(NormalizedImei._(normalized));
}
