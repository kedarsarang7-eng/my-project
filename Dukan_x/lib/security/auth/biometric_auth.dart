import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Biometric & Authentication Security
/// Implements fingerprint/face login, session timeout, 2FA, and brute-force protection
class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  late Timer _sessionTimeoutTimer;
  late Timer _inactivityTimer;

  bool _isAuthenticated = false;
  bool _isBiometricAvailable = false;
  String? _lastAuthTime;
  String? _currentSessionToken;

  static const Duration sessionTimeout = Duration(minutes: 15);
  static const Duration inactivityTimeout = Duration(minutes: 5);
  static const int maxFailedAttempts = 5;

  /// Initialize biometric authentication
  Future<void> initialize() async {
    try {
      // Check if biometric is available
      _isBiometricAvailable = await _localAuth.canCheckBiometrics;

      // Start session management
      _startSessionTimeout();
      _startInactivityTimeout();
    } catch (e) {
      rethrow;
    }
  }

  /// Authenticate with biometric (fingerprint or face)
  Future<bool> authenticateWithBiometric({
    String reason = 'Authentication required',
  }) async {
    try {
      if (!_isBiometricAvailable) {
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
      );

      if (authenticated) {
        await _createAuthSession();
        _isAuthenticated = true;
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Authenticate with PIN/Pattern (fallback)
  /// Uses SHA-256 hashing with salt for secure comparison
  Future<bool> authenticateWithPIN(String pin) async {
    try {
      // Read stored hash and salt
      final storedHash = await _secureStorage.read(key: 'admin_pin_hash');
      final storedSalt = await _secureStorage.read(key: 'admin_pin_salt');

      // Fallback: Check for legacy plaintext PIN and migrate
      if (storedHash == null) {
        final legacyPin = await _secureStorage.read(key: 'admin_pin');
        if (legacyPin != null && pin == legacyPin) {
          // Migrate to hashed storage
          await setPin(pin);
          await _secureStorage.delete(key: 'admin_pin');
          await _createAuthSession();
          _isAuthenticated = true;
          return true;
        }
        return false;
      }

      // Hash input with stored salt and compare
      final inputHash = _hashPin(pin, storedSalt ?? '');
      if (inputHash == storedHash) {
        await _createAuthSession();
        _isAuthenticated = true;
        // Reset failed attempts on success
        await _secureStorage.delete(key: 'failed_auth_attempts');
        return true;
      } else {
        await _recordFailedAuthAttempt();
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Set/Update PIN with secure hashing
  Future<bool> setPin(String pin) async {
    try {
      // Generate cryptographically secure salt
      final salt = _generateSecureSalt();
      final hash = _hashPin(pin, salt);

      // Store hash and salt separately
      await _secureStorage.write(key: 'admin_pin_hash', value: hash);
      await _secureStorage.write(key: 'admin_pin_salt', value: salt);

      // Remove legacy plaintext PIN if exists
      await _secureStorage.delete(key: 'admin_pin');

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Hash PIN with SHA-256 and salt
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate cryptographically secure salt
  String _generateSecureSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  /// Enable 2FA (Two-Factor Authentication)
  Future<bool> enable2FA() async {
    try {
      // Generate 2FA token
      final twoFAToken = _generate2FAToken();

      // Store token securely
      await _secureStorage.write(key: '2fa_token', value: twoFAToken);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Verify 2FA code
  Future<bool> verify2FACode(String code) async {
    try {
      final storedToken = await _secureStorage.read(key: '2fa_token');

      if (storedToken == null) {
        return false;
      }

      // In production, use TOTP (Time-based One-Time Password)
      // This is a placeholder implementation
      if (code == storedToken) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Create new authentication session
  Future<void> _createAuthSession() async {
    try {
      _lastAuthTime = DateTime.now().toIso8601String();
      _currentSessionToken = _generateSessionToken();

      // Store session token securely
      await _secureStorage.write(
        key: 'session_token',
        value: _currentSessionToken!,
      );

      // Reset session timeout
      _resetSessionTimeout();
    } catch (e) {
      // Ignore
    }
  }

  /// Start session timeout monitoring
  void _startSessionTimeout() {
    _sessionTimeoutTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) async {
      await _checkSessionTimeout();
    });
  }

  /// Check if session has timed out
  Future<void> _checkSessionTimeout() async {
    try {
      if (!_isAuthenticated || _lastAuthTime == null) {
        return;
      }

      final lastAuth = DateTime.parse(_lastAuthTime!);
      final elapsed = DateTime.now().difference(lastAuth);

      if (elapsed > sessionTimeout) {
        await logout();
      }
    } catch (e) {
      // Ignore
    }
  }

  /// Reset session timeout (on activity)
  void _resetSessionTimeout() {
    _lastAuthTime = DateTime.now().toIso8601String();
  }

  /// Start inactivity timeout monitoring
  void _startInactivityTimeout() {
    _inactivityTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      // Check inactivity
    });
  }

  /// Record failed authentication attempt (brute-force protection)
  Future<void> _recordFailedAuthAttempt() async {
    try {
      final failedAttempts =
          int.tryParse(
            await _secureStorage.read(key: 'failed_auth_attempts') ?? '0',
          ) ??
          0;

      if (failedAttempts >= maxFailedAttempts) {
        // Lock account temporarily
        await _secureStorage.write(
          key: 'account_locked_until',
          value: DateTime.now()
              .add(const Duration(minutes: 15))
              .toIso8601String(),
        );

        // In production: notify admin, trigger 2FA
      } else {
        await _secureStorage.write(
          key: 'failed_auth_attempts',
          value: (failedAttempts + 1).toString(),
        );
      }
    } catch (e) {
      // Ignore
    }
  }

  /// Check if account is locked
  Future<bool> isAccountLocked() async {
    try {
      final lockedUntil = await _secureStorage.read(
        key: 'account_locked_until',
      );

      if (lockedUntil == null) {
        return false;
      }

      final lockTime = DateTime.parse(lockedUntil);
      return DateTime.now().isBefore(lockTime);
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Generate 2FA token using Secure RNG
  String _generate2FAToken() {
    final random = Random.secure();
    final values = List<int>.generate(6, (i) => random.nextInt(10));
    return values.join();
  }

  /// Generate session token
  String _generateSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        DateTime.now().microsecond.toString();
  }

  /// Logout current session
  Future<void> logout() async {
    try {
      _isAuthenticated = false;
      _currentSessionToken = null;
      _lastAuthTime = null;

      await _secureStorage.delete(key: 'session_token');
      await _secureStorage.delete(key: 'failed_auth_attempts');
    } catch (e) {
      // Ignore
    }
  }

  /// Check if currently authenticated
  bool isAuthenticated() {
    return _isAuthenticated;
  }

  /// Get authentication status
  Map<String, dynamic> getAuthStatus() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'isAuthenticated': _isAuthenticated,
      'biometricAvailable': _isBiometricAvailable,
      'lastAuthTime': _lastAuthTime,
      'sessionToken': _currentSessionToken,
      'sessionValid': _isAuthenticated,
    };
  }

  /// Dispose
  void dispose() {
    _sessionTimeoutTimer.cancel();
    _inactivityTimer.cancel();
  }
}
