// ============================================================================
// ACADEMIC COACHING — INPUT VALIDATORS
// ============================================================================

class AcValidators {
  /// Validate student ID
  static String? validateStudentId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Student ID is required';
    }
    if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(value)) {
      return 'Only letters, numbers, and hyphens allowed';
    }
    if (value.length < 3 || value.length > 20) {
      return 'Must be 3-20 characters';
    }
    return null;
  }

  /// Validate name
  static String? validateName(String? value, {String field = 'Name'}) {
    if (value == null || value.isEmpty) {
      return '$field is required';
    }
    if (value.length < 2 || value.length > 50) {
      return '$field must be 2-50 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return '$field can only contain letters and spaces';
    }
    return null;
  }

  /// Validate phone number (Indian format)
  static String? validatePhone(String? value, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'Phone number is required' : null;
    }
    // Remove all non-digits
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 10) {
      return 'Phone number must be 10 digits';
    }
    if (!RegExp(r'^[6-9]').hasMatch(digitsOnly)) {
      return 'Invalid Indian mobile number';
    }
    return null;
  }

  /// Validate email
  static String? validateEmail(String? value, {bool required = false}) {
    if (value == null || value.isEmpty) {
      return required ? 'Email is required' : null;
    }
    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(value)) {
      return 'Invalid email format';
    }
    return null;
  }

  /// Validate date of birth
  static String? validateDateOfBirth(
    String? value, {
    int minAge = 5,
    int maxAge = 100,
  }) {
    if (value == null || value.isEmpty) {
      return 'Date of birth is required';
    }

    try {
      final dob = DateTime.parse(value);
      final now = DateTime.now();
      final age = now.year - dob.year;

      if (age < minAge) {
        return 'Must be at least $minAge years old';
      }
      if (age > maxAge) {
        return 'Age cannot exceed $maxAge years';
      }
      if (dob.isAfter(now)) {
        return 'Date of birth cannot be in the future';
      }
    } catch (e) {
      return 'Invalid date format (YYYY-MM-DD)';
    }
    return null;
  }

  /// Validate fee amount (legacy — accepts rupee string, permits zero).
  /// @deprecated Use [validateFeeAmountPaise] for all new write paths.
  static String? validateFeeAmount(
    String? value, {
    double min = 0,
    double max = 1000000,
  }) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }

    final amount = double.tryParse(value.replaceAll(',', ''));
    if (amount == null) {
      return 'Invalid amount';
    }
    if (amount < min) {
      return 'Amount must be at least ₹${min.toStringAsFixed(0)}';
    }
    if (amount > max) {
      return 'Amount cannot exceed ₹${max.toStringAsFixed(0)}';
    }
    return null;
  }

  // ==========================================================================
  // INTEGER-PAISE FEE VALIDATION (Phase 7 — Requirement 10.5)
  // ==========================================================================

  /// Validates a fee amount in integer Paise.
  ///
  /// Returns `null` when valid (strictly positive integer).
  /// Returns an error string when:
  /// - [amountPaise] is null (amount is required)
  /// - [amountPaise] is zero or negative (must be > 0)
  /// - [amountPaise] exceeds [maxPaise] (default 100_000_000 = ₹10,00,000)
  ///
  /// A rejected amount persists nothing, retains entered values, and shows
  /// an error on the amount field.
  static String? validateFeeAmountPaise(
    int? amountPaise, {
    int maxPaise = 100000000, // ₹10,00,000
  }) {
    if (amountPaise == null) {
      return 'Amount is required';
    }
    if (amountPaise <= 0) {
      return 'Amount must be greater than zero';
    }
    if (amountPaise > maxPaise) {
      return 'Amount cannot exceed ₹${(maxPaise / 100).toStringAsFixed(0)}';
    }
    return null;
  }

  /// Validates a fee amount entered as a string, parsing it as integer Paise.
  ///
  /// Accepts a raw text input (e.g. from a TextField) and validates that it
  /// represents a strictly positive integer amount in Paise.
  /// Non-numeric or empty input is rejected.
  static String? validateFeeAmountPaiseFromText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final parsed = int.tryParse(value.replaceAll(',', '').trim());
    if (parsed == null) {
      return 'Invalid amount — enter a whole number';
    }
    return validateFeeAmountPaise(parsed);
  }

  // ==========================================================================
  // FEE LINKAGE VALIDATION (Phase 7 — Requirement 10.3)
  // ==========================================================================

  /// Validates that a fee entry is linked to both a student and a class.
  ///
  /// A saved fee entry must link to an existing student record AND an existing
  /// class record (both must be non-null and non-empty for the validation to
  /// pass). Invalid linkage rejects the write.
  ///
  /// Returns `null` when both [studentId] and [classId] are non-null and
  /// non-empty. Returns an error string identifying the invalid linkage
  /// otherwise.
  static String? validateFeeLinkage({
    required String? studentId,
    required String? classId,
  }) {
    if (studentId == null || studentId.trim().isEmpty) {
      return 'Fee must be linked to a valid student';
    }
    if (classId == null || classId.trim().isEmpty) {
      return 'Fee must be linked to a valid class';
    }
    return null;
  }

  /// Validate batch capacity
  static String? validateCapacity(String? value, {int min = 1, int max = 500}) {
    if (value == null || value.isEmpty) {
      return 'Capacity is required';
    }

    final capacity = int.tryParse(value);
    if (capacity == null) {
      return 'Invalid number';
    }
    if (capacity < min) {
      return 'Minimum capacity is $min';
    }
    if (capacity > max) {
      return 'Maximum capacity is $max';
    }
    return null;
  }

  /// Validate batch dates
  static String? validateDateRange(String? startDate, String? endDate) {
    if (startDate == null || startDate.isEmpty) {
      return 'Start date is required';
    }
    if (endDate == null || endDate.isEmpty) {
      return 'End date is required';
    }

    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);

      if (end.isBefore(start)) {
        return 'End date must be after start date';
      }

      final duration = end.difference(start);
      if (duration.inDays > 365 * 5) {
        return 'Batch duration cannot exceed 5 years';
      }
    } catch (e) {
      return 'Invalid date format';
    }
    return null;
  }

  /// Validate exam duration
  static String? validateExamDuration(String? value) {
    if (value == null || value.isEmpty) {
      return 'Duration is required';
    }

    // Check format like "3 hours" or "90 minutes"
    final match = RegExp(
      r'^(\d+)\s*(hour|minute|min|hr)s?$',
    ).firstMatch(value.toLowerCase());
    if (match == null) {
      return 'Format: "3 hours" or "90 minutes"';
    }

    final amount = int.parse(match.group(1)!);
    final unit = match.group(2);

    final minutes = unit?.startsWith('hour') ?? false ? amount * 60 : amount;

    if (minutes < 15) {
      return 'Minimum duration is 15 minutes';
    }
    if (minutes > 480) {
      return 'Maximum duration is 8 hours';
    }

    return null;
  }

  /// Validate marks
  static String? validateMarks(String? value, {double maxMarks = 100}) {
    if (value == null || value.isEmpty) {
      return 'Marks are required';
    }

    final marks = double.tryParse(value);
    if (marks == null) {
      return 'Invalid number';
    }
    if (marks < 0) {
      return 'Marks cannot be negative';
    }
    if (marks > maxMarks) {
      return 'Marks cannot exceed $maxMarks';
    }
    return null;
  }

  /// Validate PIN code
  static String? validatePincode(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional
    }

    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 6) {
      return 'PIN code must be 6 digits';
    }
    return null;
  }

  /// Generic required field validator
  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  /// Validate unique ID (alphanumeric with underscore/hyphen)
  static String? validateUniqueId(String? value, {String field = 'ID'}) {
    if (value == null || value.isEmpty) {
      return '$field is required';
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value)) {
      return '$field can only contain letters, numbers, underscores, and hyphens';
    }
    if (value.length < 2 || value.length > 30) {
      return '$field must be 2-30 characters';
    }
    return null;
  }
}

/// Validation result
class ValidationResult {
  final bool isValid;
  final Map<String, String> errors;

  ValidationResult({required this.isValid, this.errors = const {}});

  factory ValidationResult.success() => ValidationResult(isValid: true);

  factory ValidationResult.failure(Map<String, String> errors) =>
      ValidationResult(isValid: false, errors: errors);
}

/// Form validator helper
class AcFormValidator {
  final Map<String, String?> _errors = {};

  void validate(
    String field,
    String? value,
    String? Function(String?) validator,
  ) {
    final error = validator(value);
    if (error != null) {
      _errors[field] = error;
    }
  }

  ValidationResult get result => _errors.isEmpty
      ? ValidationResult.success()
      : ValidationResult.failure(Map.unmodifiable(_errors));

  String? getError(String field) => _errors[field];
  bool hasError(String field) => _errors.containsKey(field);
  void clear() => _errors.clear();
}
