class GstValidator {
  static final _pattern = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
  );

  static bool isValid(String gstin) => _pattern.hasMatch(gstin.toUpperCase().trim());

  static String? validate(String? gstin) {
    if (gstin == null || gstin.trim().isEmpty) return null; // GST is optional
    if (!isValid(gstin)) return 'Enter a valid GSTIN (15 characters)';
    return null;
  }
}
