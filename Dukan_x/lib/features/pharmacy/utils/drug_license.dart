// ============================================================================
// DRUG LICENSE NUMBER — validation (Requirement 14)
// ============================================================================
// Pharmacy-scoped, pure-logic validator for the tenant-level Drug License
// Number that appears on the pharmacy invoice header.
//
//   R14.1 : the field accepts an alphanumeric value of 1 to 50 characters.
//   R14.4 : an empty value or a value longer than 50 characters is rejected
//           with a length-constraint indication so the caller can retain the
//           previously saved value.
//
// The validator is deliberately free of any storage or UI dependency so it can
// be reused by the settings UI, the persistence service, and tests alike.
// Only pharmacy code paths use it; the other 18 verticals are untouched
// (Requirement 5.3).
// ============================================================================

/// Outcome of validating a candidate Drug License Number.
class DrugLicenseValidation {
  /// True when the candidate is an acceptable Drug License Number.
  final bool isValid;

  /// The trimmed value when [isValid]; otherwise `null`.
  final String? value;

  /// A human-readable length-constraint message when invalid; otherwise `null`.
  final String? error;

  const DrugLicenseValidation.valid(String this.value)
    : isValid = true,
      error = null;

  const DrugLicenseValidation.invalid(String this.error)
    : isValid = false,
      value = null;
}

/// Validation rules for the tenant-level Drug License Number (R14.1, R14.4).
class DrugLicense {
  DrugLicense._();

  /// Maximum permitted length (inclusive).
  static const int maxLength = 50;

  /// Minimum permitted length (inclusive).
  static const int minLength = 1;

  /// The length-constraint message surfaced to the user on rejection (R14.4).
  static const String lengthConstraintMessage =
      'Drug License Number must be 1 to 50 alphanumeric characters.';

  /// Alphanumeric only, per R14.1 / Property 17.
  static final RegExp _alphanumeric = RegExp(r'^[A-Za-z0-9]+$');

  /// Validates [raw] as a Drug License Number.
  ///
  /// Leading/trailing whitespace is trimmed before evaluation. The value is
  /// accepted if and only if, after trimming, it is alphanumeric with a length
  /// in the inclusive range [[minLength], [maxLength]] (R14.1). Otherwise it is
  /// rejected with [lengthConstraintMessage] so the caller can retain the prior
  /// value (R14.4).
  static DrugLicenseValidation validate(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.length < minLength ||
        value.length > maxLength ||
        !_alphanumeric.hasMatch(value)) {
      return const DrugLicenseValidation.invalid(lengthConstraintMessage);
    }
    return DrugLicenseValidation.valid(value);
  }

  /// Convenience predicate mirroring [validate].
  static bool isValid(String? raw) => validate(raw).isValid;

  // --------------------------------------------------------------------------
  // Invoice header rendering decision (Requirement 14.2, 14.3)
  // --------------------------------------------------------------------------
  // The print/PDF header renders the Drug License Number only when a value is
  // configured for the tenant, and omits it otherwise without raising an error.
  // The decision is centralized here so the PDF template and its tests agree on
  // exactly one rule (R14.2 / R14.3 / Property 18).

  /// Label prefix shown before the Drug License Number in the invoice header.
  static const String headerLabelPrefix = 'D.L. No: ';

  /// Builds the Drug License header line for the pharmacy invoice header, or
  /// returns `null` when the line must be omitted.
  ///
  /// Returns the rendered line `"D.L. No: <value>"` if and only if [configured]
  /// is non-null and non-empty (R14.2); otherwise returns `null` so the header
  /// is rendered without the Drug License field and the print/PDF export
  /// completes without error (R14.3). This is a total, side-effect-free
  /// function: every input maps to a defined output and it never throws.
  static String? headerLine(String? configured) {
    if (configured == null || configured.isEmpty) return null;
    return '$headerLabelPrefix$configured';
  }
}
