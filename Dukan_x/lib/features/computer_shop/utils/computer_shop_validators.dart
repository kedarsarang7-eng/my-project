// Centralized field validators for the ComputerShop module.
//
// Each validator returns `null` when the input is valid, or a non-null
// error-message string when the input is invalid. This convention matches
// Flutter's `FormField.validator` signature.

/// Centralized field validators for the ComputerShop module.
class ComputerShopValidators {
  ComputerShopValidators._();

  // ─── Phone ───────────────────────────────────────────────────────────

  /// Validates that [phone] consists of exactly 10 numeric digits.
  /// No separators, spaces, or country code prefix are allowed.
  static String? validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      return 'Phone number must be exactly 10 digits';
    }
    return null;
  }

  // ─── Email ───────────────────────────────────────────────────────────

  /// Validates that [email] contains exactly one `@`, at least one `.` in the
  /// domain portion, no whitespace, and a total length between 5 and 254.
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    if (email.length < 5 || email.length > 254) {
      return 'Email must be between 5 and 254 characters';
    }
    if (email.contains(RegExp(r'\s'))) {
      return 'Email must not contain whitespace';
    }
    final atCount = '@'.allMatches(email).length;
    if (atCount != 1) {
      return 'Email must contain exactly one @ symbol';
    }
    final atIndex = email.indexOf('@');
    final localPart = email.substring(0, atIndex);
    final domainPart = email.substring(atIndex + 1);
    if (localPart.isEmpty) {
      return 'Email local part must not be empty';
    }
    if (domainPart.isEmpty || !domainPart.contains('.')) {
      return 'Email domain must contain at least one dot';
    }
    return null;
  }

  // ─── Serial ──────────────────────────────────────────────────────────

  /// Validates that [serial] is non-empty after trimming, at most 64 characters,
  /// and matches the alphanumeric/dash/underscore format.
  static String? validateSerial(String? serial) {
    if (serial == null || serial.trim().isEmpty) {
      return 'Serial number is required';
    }
    final trimmed = serial.trim();
    if (trimmed.length > 64) {
      return 'Serial number must be at most 64 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9\-_]+$').hasMatch(trimmed)) {
      return 'Serial number must contain only letters, digits, dashes, or underscores';
    }
    return null;
  }

  // ─── Purchase Date ───────────────────────────────────────────────────

  /// Validates that [date] is not in the future relative to [now].
  /// If [now] is omitted, `DateTime.now()` is used.
  static String? validatePurchaseDate(DateTime? date, {DateTime? now}) {
    if (date == null) {
      return 'Purchase date is required';
    }
    final today = now ?? DateTime.now();
    // Compare date-only (ignore time component).
    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (dateOnly.isAfter(todayOnly)) {
      return 'Purchase date cannot be in the future';
    }
    return null;
  }

  // ─── Multi-Unit ──────────────────────────────────────────────────────

  /// Validates that [primary] and [alternate] units differ.
  static String? validateUnitPair(String? primary, String? alternate) {
    if (primary == null || primary.isEmpty) {
      return 'Primary unit is required';
    }
    if (alternate == null || alternate.isEmpty) {
      return 'Alternate unit is required';
    }
    if (primary == alternate) {
      return 'Primary and alternate units must differ';
    }
    return null;
  }

  /// Validates that [source] and [target] conversion units differ.
  static String? validateConversionPair(String? source, String? target) {
    if (source == null || source.isEmpty) {
      return 'Source unit is required';
    }
    if (target == null || target.isEmpty) {
      return 'Target unit is required';
    }
    if (source == target) {
      return 'Source and target units must differ';
    }
    return null;
  }

  /// Validates that [rate] is a numeric value greater than 0, at most
  /// 999,999,999.99, and has at most 4 decimal places.
  static String? validateConversionRate(String? rate) {
    if (rate == null || rate.trim().isEmpty) {
      return 'Conversion rate is required';
    }
    final trimmed = rate.trim();
    final value = double.tryParse(trimmed);
    if (value == null) {
      return 'Conversion rate must be a valid number';
    }
    if (value <= 0) {
      return 'Conversion rate must be greater than zero';
    }
    if (value > 999999999.99) {
      return 'Conversion rate must not exceed 999,999,999.99';
    }
    // Check decimal places: at most 4.
    if (trimmed.contains('.')) {
      final decimalPart = trimmed.split('.').last;
      if (decimalPart.length > 4) {
        return 'Conversion rate must have at most 4 decimal places';
      }
    }
    return null;
  }
}
