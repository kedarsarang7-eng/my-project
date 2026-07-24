/// Monetary Validator — Domain Logic (Dart)
///
/// Validates monetary values as integer minor units (paise/cents).
/// No floating-point money is permitted in the MobileShop domain.
///
/// Preserves valid sibling fields: if one monetary field fails validation,
/// other validated fields remain available (not cleared).
///
/// Requirements: 5.5–5.7, 12.1–12.2, 12.6; GR-2.1
library;

import 'package:flutter/foundation.dart';
import '../config/bounds_config.dart';

// ─── Types ───────────────────────────────────────────────────────────────────

/// Validated money value in integer minor units.
@immutable
class Money {
  /// Amount in minor units (e.g. paise for INR).
  final int amountMinorUnits;

  /// Minor units per major unit (e.g. 100 for INR).
  final int minorUnitsPerMajor;

  const Money({
    required this.amountMinorUnits,
    required this.minorUnitsPerMajor,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          amountMinorUnits == other.amountMinorUnits &&
          minorUnitsPerMajor == other.minorUnitsPerMajor;

  @override
  int get hashCode => Object.hash(amountMinorUnits, minorUnitsPerMajor);

  @override
  String toString() =>
      'Money($amountMinorUnits minor units, $minorUnitsPerMajor per major)';
}

/// Monetary validation error codes.
enum MonetaryValidationErrorCode {
  moneyRequired,
  moneyNotInteger,
  moneyNegative,
  moneyExceedsMax,
}

/// Field-associated monetary validation error.
@immutable
class MonetaryValidationError {
  /// The error code enum.
  final MonetaryValidationErrorCode code;

  /// Stable string code matching the backend contract.
  final String codeString;

  /// Associated field name.
  final String field;

  /// Human-readable message.
  final String message;

  const MonetaryValidationError({
    required this.code,
    required this.codeString,
    required this.field,
    required this.message,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonetaryValidationError &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          field == other.field;

  @override
  int get hashCode => Object.hash(code, field);

  @override
  String toString() =>
      'MonetaryValidationError($codeString on $field: $message)';
}

// ─── Result Types ────────────────────────────────────────────────────────────

/// Sealed result for money validation.
sealed class MoneyValidationResult {
  const MoneyValidationResult();
}

@immutable
class MoneyValidationSuccess extends MoneyValidationResult {
  final Money value;
  const MoneyValidationSuccess(this.value);
}

@immutable
class MoneyValidationFailure extends MoneyValidationResult {
  final MonetaryValidationError error;
  const MoneyValidationFailure(this.error);
}

/// Result of sale price validation that preserves valid siblings.
/// If one field fails, the other may still be valid and accessible.
@immutable
class SalePriceValidationResult {
  /// Whether all validations passed.
  final bool ok;

  /// Validated sale price, if it passed validation.
  final Money? salePrice;

  /// Validated acquisition cost, if it passed validation.
  final Money? acquisitionCost;

  /// All collected validation errors.
  final List<MonetaryValidationError> errors;

  const SalePriceValidationResult({
    required this.ok,
    this.salePrice,
    this.acquisitionCost,
    required this.errors,
  });
}

// ─── Money Validation ────────────────────────────────────────────────────────

/// Validates a monetary amount as integer minor units.
///
/// Rejects:
/// - null
/// - Negative amounts (for prices/costs)
/// - Amounts exceeding configured maximum
///
/// Note: Dart's type system ensures the value is an int, so no type/integer
/// checks are needed (unlike the TypeScript version which accepts `unknown`).
///
/// [amount] - The value to validate (null means missing).
/// [field] - Field name for error association.
MoneyValidationResult validateMoney(int? amount, String field) {
  // Null check
  if (amount == null) {
    return MoneyValidationFailure(
      MonetaryValidationError(
        code: MonetaryValidationErrorCode.moneyRequired,
        codeString: 'MONEY_REQUIRED',
        field: field,
        message: '$field is required',
      ),
    );
  }

  // Negative check
  if (amount < 0) {
    return MoneyValidationFailure(
      MonetaryValidationError(
        code: MonetaryValidationErrorCode.moneyNegative,
        codeString: 'MONEY_NEGATIVE',
        field: field,
        message: '$field must not be negative',
      ),
    );
  }

  // Max check
  if (amount > kBoundsConfig.money.maxMinorUnits) {
    return MoneyValidationFailure(
      MonetaryValidationError(
        code: MonetaryValidationErrorCode.moneyExceedsMax,
        codeString: 'MONEY_EXCEEDS_MAX',
        field: field,
        message: '$field exceeds maximum allowed value',
      ),
    );
  }

  return MoneyValidationSuccess(
    Money(
      amountMinorUnits: amount,
      minorUnitsPerMajor: kBoundsConfig.money.minorUnitsPerMajor,
    ),
  );
}

// ─── Sale Price Validation ───────────────────────────────────────────────────

/// Validates sale price and acquisition cost together.
///
/// Rules:
/// - Sale price can be 0 (for demo/damaged units) but not negative
/// - Acquisition cost must be non-negative
/// - Both must be integer minor units within configured bounds
///
/// Preserves valid sibling fields: if salePrice validation fails,
/// acquisitionCost validation still runs and its result is preserved.
SalePriceValidationResult validateSalePrice({
  required int? salePrice,
  required int? acquisitionCost,
}) {
  final errors = <MonetaryValidationError>[];
  Money? validSalePrice;
  Money? validAcquisitionCost;

  // Validate sale price
  final salePriceResult = validateMoney(salePrice, 'salePrice');
  if (salePriceResult is MoneyValidationSuccess) {
    validSalePrice = salePriceResult.value;
  } else {
    errors.add((salePriceResult as MoneyValidationFailure).error);
  }

  // Validate acquisition cost — always validate even if salePrice failed
  final acquisitionResult = validateMoney(acquisitionCost, 'acquisitionCost');
  if (acquisitionResult is MoneyValidationSuccess) {
    validAcquisitionCost = acquisitionResult.value;
  } else {
    errors.add((acquisitionResult as MoneyValidationFailure).error);
  }

  return SalePriceValidationResult(
    ok: errors.isEmpty,
    salePrice: validSalePrice,
    acquisitionCost: validAcquisitionCost,
    errors: errors,
  );
}
