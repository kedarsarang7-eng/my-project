// ============================================================================
// CAPTURED PRESCRIPTION IDENTIFIER — bounds (Requirement 7.2)
// ============================================================================
// Pharmacy-scoped, pure-logic validator for the prescription identifier
// captured through the Prescription_Gate before a scheduled drug (H/H1/X) is
// added to a bill.
//
//   R7.2 : a valid prescription requires a non-empty prescription identifier
//          of 1 to 100 characters.
//
// The identifier is trimmed before evaluation (leading/trailing whitespace is
// not significant), and is accepted if and only if the trimmed value has a
// length in the inclusive range [1, 100]. This mirrors exactly the bound check
// previously inlined in `BillCreationScreenV2._ensurePrescriptionForProduct`,
// extracted here so the POS, any other caller, and tests share one rule.
//
// Only pharmacy code paths use it; the other 18 verticals are untouched
// (Requirement 5.3). The helper is free of UI/storage dependencies.
// ============================================================================

/// Validation rules for a captured prescription identifier (R7.2 / Property 10).
class PrescriptionId {
  PrescriptionId._();

  /// Minimum permitted length (inclusive).
  static const int minLength = 1;

  /// Maximum permitted length (inclusive).
  static const int maxLength = 100;

  /// True iff [raw], after trimming, has a length in `[minLength, maxLength]`.
  ///
  /// This is a total, side-effect-free predicate: `null` and whitespace-only
  /// inputs trim to the empty string and are rejected; any trimmed value of
  /// length 1..100 is accepted (R7.2).
  static bool accepts(String? raw) {
    final id = raw?.trim() ?? '';
    return id.length >= minLength && id.length <= maxLength;
  }

  /// Returns the trimmed identifier when [accepts] holds, otherwise `null` so
  /// the caller does not assign an out-of-bounds value to the bill.
  static String? normalize(String? raw) {
    final id = raw?.trim() ?? '';
    return accepts(id) ? id : null;
  }
}
