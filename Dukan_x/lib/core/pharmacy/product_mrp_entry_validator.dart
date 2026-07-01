// ============================================================================
// PRODUCT MRP ENTRY VALIDATOR — pharmacy vertical (Add_Product_Sheet)
// ============================================================================
// Validates the MRP value entered in the pharmacy product sheet. The field
// displays rupees (e.g. "10.50") but MRP is stored as integer paise, so a valid
// entry must map cleanly to a whole number of paise (at most two decimal
// places) within the inclusive range [1, 99,999,999] paise — i.e. ₹0.01 to
// ₹999,999.99 (Requirements 8.5, 8.6).
//
// This pure helper centralizes the rule so it can be unit/property tested
// without driving the widget. `AddProductSheet` calls it from its pharmacy
// branch; the other 18 verticals are unaffected (Requirement 5.3).
//
// Validates: Requirements 8.5, 8.6.
// ============================================================================

import 'package:dukanx/core/pharmacy/paise.dart';

/// Pure validation for the pharmacy product-sheet MRP field.
///
/// Static-only utility: there is nothing to instantiate.
class ProductMrpEntryValidator {
  const ProductMrpEntryValidator._();

  /// Smallest accepted MRP, in integer paise (₹0.01).
  static const int minMrpPaise = 1;

  /// Largest accepted MRP, in integer paise (₹999,999.99).
  static const int maxMrpPaise = 99999999;

  /// Matches a non-negative number with no sign, no thousands separators, and
  /// at most two decimal places — the only shape that maps cleanly to whole
  /// paise.
  static final RegExp _wholePaiseShape = RegExp(r'^\d+(\.\d{1,2})?$');

  /// Convert a rupee MRP string into a whole number of integer paise.
  ///
  /// Returns `null` when [text] is empty or is not a non-negative number with
  /// up to two decimal places, so a finer-than-paise or otherwise malformed
  /// entry is rejected (Requirements 8.5, 8.6).
  static int? rupeesToWholePaise(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    if (!_wholePaiseShape.hasMatch(t)) return null;
    return Paise.fromRupees(double.parse(t));
  }

  /// Whether an entered MRP string is accepted: it must map to an integer
  /// paise value in the inclusive range [1, 99,999,999]. Any non-integer-paise,
  /// out-of-range, or malformed entry is rejected (and the product is not
  /// saved by the caller).
  static bool isAccepted(String text) {
    final paise = rupeesToWholePaise(text);
    if (paise == null) return false;
    return paise >= minMrpPaise && paise <= maxMrpPaise;
  }
}
