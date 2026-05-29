abstract class AppStrings {
  // App Info
  static const String appName      = 'PETROL STAFF CONNECT';
  static const String appTagline   = 'Staff App | Safe. Secure. Efficient.';

  // Login Screen
  static const String staffLogin        = 'STAFF LOGIN';
  static const String staffIdLabel      = 'Staff ID / Employee Number';
  static const String staffIdHint       = 'Enter your Staff ID';
  static const String passwordLabel     = 'Password';
  static const String passwordHint      = 'Enter Password';
  static const String forgotPassword    = 'Forgot Password?';
  static const String loginButton       = 'LOG IN';
  static const String orDivider         = 'OR';
  static const String biometricMain     = 'Continue with Biometrics';
  static const String biometricSub      = 'Biometric Login';
  static const String newStaffContact   = 'New Staff? Contact Admin';
  static const String helpSupport       = 'Help & Support';

  // Validation
  static const String staffIdRequired   = 'Staff ID is required';
  static const String staffIdInvalid    = 'Enter a valid Staff ID';
  static const String passwordRequired  = 'Password is required';
  static const String passwordMinLength = 'Password must be at least 8 characters';

  // Errors
  static const String invalidCredentials = 'Invalid Staff ID or Password';
  static const String accountDisabled    = 'Your account has been deactivated. Contact Admin.';
  static const String networkError       = 'Network error. Check your connection.';
  static const String unknownError       = 'Something went wrong. Try again.';
  static const String biometricFailed    = 'Biometric authentication failed';
  static const String biometricNotSetup  = 'Biometrics not configured on this device';
}
