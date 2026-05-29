class EmailValidator {
  static final _pattern = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');

  static bool isValid(String email) => _pattern.hasMatch(email.trim());

  static String? validate(String? email) {
    if (email == null || email.trim().isEmpty) return 'Email is required';
    if (!isValid(email)) return 'Enter a valid email address';
    return null;
  }
}
