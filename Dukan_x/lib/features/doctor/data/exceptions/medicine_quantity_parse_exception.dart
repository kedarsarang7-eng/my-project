/// Thrown when `_calculateMedicineQuantity` cannot parse a medicine's dosage
/// or duration string into a computable quantity.
///
/// Callers should surface this to the user so they can manually specify a
/// quantity or correct the dosage/duration input. The exception carries the
/// raw field values that failed to parse.
class MedicineQuantityParseException implements Exception {
  /// The medicine name for which parsing failed.
  final String medicineName;

  /// The raw dosage string that failed to parse (e.g. "abc-xyz").
  final String? dosage;

  /// The raw duration string that failed to parse (e.g. "some days").
  final String? duration;

  /// Describes which field(s) were unparseable.
  final String reason;

  const MedicineQuantityParseException({
    required this.medicineName,
    this.dosage,
    this.duration,
    required this.reason,
  });

  @override
  String toString() =>
      'MedicineQuantityParseException: Could not compute quantity for '
      '"$medicineName" — $reason. '
      'Dosage: "${dosage ?? "(null)"}", Duration: "${duration ?? "(null)"}". '
      'Please specify the quantity manually.';
}
