// Parses dynamic Firestore number fields into doubles without throwing.
double parseDouble(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    return double.tryParse(trimmed.replaceAll(',', '')) ?? fallback;
  }
  if (value is bool) {
    return value ? 1.0 : 0.0;
  }
  return fallback;
}
