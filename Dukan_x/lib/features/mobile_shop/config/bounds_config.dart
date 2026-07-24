/// Operational Bounds Configuration (Flutter)
///
/// Defines input sizes, value ranges, precision, debounce, and query limits.
/// All monetary values use integer minor units (paise/cents) — no floating point.
library;

import 'package:flutter/foundation.dart';

/// Typed bounds configuration for the MobileShop domain.
@immutable
class BoundsConfig {
  /// IMEI / device identity bounds.
  final ImeiBounds imei;

  /// Monetary value bounds (integer minor units).
  final MoneyBounds money;

  /// Warranty bounds.
  final WarrantyBounds warranty;

  /// Invoice/sale bounds.
  final InvoiceBounds invoice;

  /// Input string length limits.
  final StringBounds strings;

  /// Search and filter bounds.
  final SearchBounds search;

  const BoundsConfig({
    required this.imei,
    required this.money,
    required this.warranty,
    required this.invoice,
    required this.strings,
    required this.search,
  });
}

@immutable
class ImeiBounds {
  /// Required digit length after normalization.
  final int length;

  /// Minimum prefix length for catalogue/search.
  final int minSearchPrefix;

  const ImeiBounds({required this.length, required this.minSearchPrefix});
}

@immutable
class MoneyBounds {
  /// Minimum allowed minor-unit value (inclusive, usually 0).
  final int minMinorUnits;

  /// Maximum allowed minor-unit value (inclusive).
  final int maxMinorUnits;

  /// Minor units per major unit (e.g. 100 for INR paise).
  final int minorUnitsPerMajor;

  const MoneyBounds({
    required this.minMinorUnits,
    required this.maxMinorUnits,
    required this.minorUnitsPerMajor,
  });
}

@immutable
class WarrantyBounds {
  /// Minimum warranty months (inclusive).
  final int minMonths;

  /// Maximum warranty months (inclusive).
  final int maxMonths;

  const WarrantyBounds({required this.minMonths, required this.maxMonths});
}

@immutable
class InvoiceBounds {
  /// Maximum device lines per invoice.
  final int maxDeviceLines;

  /// Maximum accessory lines per invoice.
  final int maxAccessoryLines;

  /// Maximum total line items (device + accessory).
  final int maxTotalLines;

  const InvoiceBounds({
    required this.maxDeviceLines,
    required this.maxAccessoryLines,
    required this.maxTotalLines,
  });
}

@immutable
class StringBounds {
  final int maxOperationIdLength;
  final int maxEntityIdLength;
  final int maxReasonLength;
  final int maxFaultLength;
  final int maxNotesLength;
  final int maxCorrelationIdLength;

  const StringBounds({
    required this.maxOperationIdLength,
    required this.maxEntityIdLength,
    required this.maxReasonLength,
    required this.maxFaultLength,
    required this.maxNotesLength,
    required this.maxCorrelationIdLength,
  });
}

@immutable
class SearchBounds {
  /// Minimum query length to execute search.
  final int minQueryLength;

  /// Maximum query length.
  final int maxQueryLength;

  /// Debounce interval in milliseconds.
  final int debounceMs;

  const SearchBounds({
    required this.minQueryLength,
    required this.maxQueryLength,
    required this.debounceMs,
  });
}

/// Default bounds configuration.
const kBoundsConfig = BoundsConfig(
  imei: ImeiBounds(length: 15, minSearchPrefix: 4),
  money: MoneyBounds(
    minMinorUnits: 0,
    maxMinorUnits: 99999999999, // 9,99,99,999.99 INR paise
    minorUnitsPerMajor: 100,
  ),
  warranty: WarrantyBounds(minMonths: 1, maxMonths: 120),
  invoice: InvoiceBounds(
    maxDeviceLines: 50,
    maxAccessoryLines: 100,
    maxTotalLines: 100,
  ),
  strings: StringBounds(
    maxOperationIdLength: 64,
    maxEntityIdLength: 64,
    maxReasonLength: 500,
    maxFaultLength: 1000,
    maxNotesLength: 2000,
    maxCorrelationIdLength: 64,
  ),
  search: SearchBounds(minQueryLength: 3, maxQueryLength: 200, debounceMs: 300),
);
