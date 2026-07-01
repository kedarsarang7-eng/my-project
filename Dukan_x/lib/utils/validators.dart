/// Input validators
class Validators {
  /// Validate a phone number.
  /// Accepts an optional +91 / 91 / 0 prefix, then 10 digits starting 6-9.
  /// Any non-digit characters (spaces, dashes, parens) are stripped before
  /// checking.
  static bool isValidPhone(String phone) {
    var cleaned = phone.trim().replaceAll(RegExp(r'\D'), '');
    // Strip common country/trunk prefixes.
    if (cleaned.length == 12 && cleaned.startsWith('91')) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.length == 11 && cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned);
  }

  /// Validate email
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  /// Validate password strength
  static bool isValidPassword(String password) {
    return password.isNotEmpty && password.length >= 4;
  }

  /// Validate name
  static bool isValidName(String name) {
    return name.isNotEmpty && name.length >= 2;
  }
}
