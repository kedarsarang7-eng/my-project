import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

/// Performs security checks on app startup.
/// In production, a rooted/jailbroken device triggers a non-dismissible warning.
class SecurityService {
  static bool _checked = false;
  static bool _isCompromised = false;

  static bool get isCompromised => _isCompromised;

  static Future<SecurityCheckResult> checkDevice() async {
    if (_checked) {
      return _isCompromised
          ? SecurityCheckResult.compromised('Device already flagged')
          : SecurityCheckResult.ok();
    }

    _checked = true;

    if (kDebugMode) {
      // Never block in debug mode (emulators/dev devices)
      return SecurityCheckResult.ok();
    }

    try {
      final isJailbroken = await FlutterJailbreakDetection.jailbroken;
      final isDeveloperMode = await FlutterJailbreakDetection.developerMode;

      if (isJailbroken) {
        _isCompromised = true;
        debugPrint('[Security] Device is rooted/jailbroken');
        return SecurityCheckResult.compromised('Rooted or jailbroken device detected');
      }

      if (isDeveloperMode && Platform.isAndroid) {
        // Developer mode alone is not a hard block — warn only
        debugPrint('[Security] Developer mode enabled');
      }

      return SecurityCheckResult.ok();
    } catch (e) {
      // If detection fails, allow — do not block legitimate users
      debugPrint('[Security] Device check failed: $e');
      return SecurityCheckResult.ok();
    }
  }

  /// Call on every sensitive screen (invoice detail, ledger, payments).
  static Future<bool> requireSecureSession() async {
    if (_isCompromised) return false;
    return true;
  }
}

class SecurityCheckResult {
  final bool passed;
  final String? reason;

  const SecurityCheckResult._({required this.passed, this.reason});

  factory SecurityCheckResult.ok() =>
      const SecurityCheckResult._(passed: true);

  factory SecurityCheckResult.compromised(String reason) =>
      SecurityCheckResult._(passed: false, reason: reason);
}
