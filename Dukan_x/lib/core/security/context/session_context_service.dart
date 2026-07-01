// ============================================================================
// SESSION CONTEXT SERVICE
// ============================================================================
// Session intelligence for automatic restrictions.
// Detects odd hours, new devices, unusual patterns.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../device/trusted_device_service.dart';

/// Access Level based on session context
enum AccessLevel {
  /// Full access - normal operations
  full,

  /// Restricted - no critical actions
  restricted,

  /// Read only - view only
  readOnly,

  /// Blocked - no access
  blocked,
}

/// Session Context - Current session state and restrictions.
class SessionContext {
  final String userId;
  final String businessId;
  final DateTime loginTime;
  final String deviceFingerprint;
  final bool isNewDevice;
  final bool isOddHours;
  final bool isAfterInactivity;
  final int actionCountThisSession;
  final AccessLevel accessLevel;
  final String? restrictionReason;

  const SessionContext({
    required this.userId,
    required this.businessId,
    required this.loginTime,
    required this.deviceFingerprint,
    this.isNewDevice = false,
    this.isOddHours = false,
    this.isAfterInactivity = false,
    this.actionCountThisSession = 0,
    this.accessLevel = AccessLevel.full,
    this.restrictionReason,
  });

  SessionContext copyWith({
    int? actionCountThisSession,
    AccessLevel? accessLevel,
    String? restrictionReason,
  }) {
    return SessionContext(
      userId: userId,
      businessId: businessId,
      loginTime: loginTime,
      deviceFingerprint: deviceFingerprint,
      isNewDevice: isNewDevice,
      isOddHours: isOddHours,
      isAfterInactivity: isAfterInactivity,
      actionCountThisSession:
          actionCountThisSession ?? this.actionCountThisSession,
      accessLevel: accessLevel ?? this.accessLevel,
      restrictionReason: restrictionReason ?? this.restrictionReason,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'businessId': businessId,
    'loginTime': loginTime.toIso8601String(),
    'deviceFingerprint': deviceFingerprint,
    'isNewDevice': isNewDevice,
    'isOddHours': isOddHours,
    'isAfterInactivity': isAfterInactivity,
    'actionCountThisSession': actionCountThisSession,
    'accessLevel': accessLevel.name,
    'restrictionReason': restrictionReason,
  };
}

/// Session Context Service - Intelligent session restrictions.
///
/// Auto-restricts on:
/// - New device (7-day read-only)
/// - Odd hours (12AM-5AM)
/// - After long inactivity (7+ days)
/// - Excessive action count
class SessionContextService {
  final TrustedDeviceService _deviceService;

  /// Current session context
  SessionContext? _currentContext;

  /// Last activity timestamp key
  static const String _lastActivityKey = 'last_activity_timestamp';

  /// Inactivity threshold for suspicious flag
  static const Duration inactivityThreshold = Duration(days: 7);

  /// Odd hours range (local time)
  static const int oddHourStart = 0; // 12 AM
  static const int oddHourEnd = 5; // 5 AM

  /// Max actions before restrictions kick in
  static const int maxActionsPerSession = 100;

  SessionContextService({required TrustedDeviceService deviceService})
    : _deviceService = deviceService;

  /// Get current session context
  SessionContext? get currentContext => _currentContext;

  /// Create session context on login
  Future<SessionContext> createSessionContext({
    required String userId,
    required String businessId,
  }) async {
    final fingerprint = await _deviceService.getCurrentFingerprint();
    final now = DateTime.now();

    // Check if new device
    final deviceValidation = await _deviceService.validateCurrentDevice(
      businessId: businessId,
      ownerId: userId,
    );
    final isNewDevice = deviceValidation.isInCoolingPeriod;

    // Check if odd hours
    final isOddHours = _isOddHours(now);

    // Check inactivity
    final isAfterInactivity = await _checkInactivity();

    // Determine access level
    final (accessLevel, reason) = _determineAccessLevel(
      isNewDevice: isNewDevice,
      isOddHours: isOddHours,
      isAfterInactivity: isAfterInactivity,
      deviceTrusted: deviceValidation.isTrusted,
    );

    _currentContext = SessionContext(
      userId: userId,
      businessId: businessId,
      loginTime: now,
      deviceFingerprint: fingerprint.fingerprintHash,
      isNewDevice: isNewDevice,
      isOddHours: isOddHours,
      isAfterInactivity: isAfterInactivity,
      accessLevel: accessLevel,
      restrictionReason: reason,
    );

    // Update last activity
    await _updateLastActivity();

    debugPrint(
      'SessionContextService: Created context. '
      'Access: ${accessLevel.name}, Reason: ${reason ?? "None"}',
    );

    return _currentContext!;
  }

  /// Record action and check limits
  Future<SessionContext> recordAction() async {
    if (_currentContext == null) {
      throw StateError('No session context. Call createSessionContext first.');
    }

    final newCount = _currentContext!.actionCountThisSession + 1;

    // Check if exceeded limit
    if (newCount > maxActionsPerSession) {
      _currentContext = _currentContext!.copyWith(
        actionCountThisSession: newCount,
        accessLevel: AccessLevel.restricted,
        restrictionReason: 'Excessive actions in session ($newCount)',
      );
    } else {
      _currentContext = _currentContext!.copyWith(
        actionCountThisSession: newCount,
      );
    }

    await _updateLastActivity();
    return _currentContext!;
  }

  /// Check if critical action is allowed
  bool isCriticalActionAllowed() {
    if (_currentContext == null) return false;

    switch (_currentContext!.accessLevel) {
      case AccessLevel.full:
        return true;
      case AccessLevel.restricted:
      case AccessLevel.readOnly:
      case AccessLevel.blocked:
        return false;
    }
  }

  /// Get restriction reason if any
  String? getRestrictionReason() {
    return _currentContext?.restrictionReason;
  }

  /// Re-verify after long-running session
  Future<SessionContext> reVerifyContext() async {
    if (_currentContext == null) {
      throw StateError('No session context');
    }

    // Re-check current hour
    final isOddHours = _isOddHours(DateTime.now());

    if (isOddHours && !_currentContext!.isOddHours) {
      // Entered odd hours during session
      _currentContext = _currentContext!.copyWith(
        accessLevel: AccessLevel.readOnly,
        restrictionReason: 'Session entered odd hours (12AM-5AM)',
      );
    }

    return _currentContext!;
  }

  /// Clear session on logout
  void clearSession() {
    _currentContext = null;
    debugPrint('SessionContextService: Session cleared');
  }

  bool _isOddHours(DateTime time) {
    final hour = time.hour;
    return hour >= oddHourStart && hour < oddHourEnd;
  }

  Future<bool> _checkInactivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastActivityStr = prefs.getString(_lastActivityKey);

      if (lastActivityStr == null) return false;

      final lastActivity = DateTime.tryParse(lastActivityStr);
      if (lastActivity == null) return false;

      return DateTime.now().difference(lastActivity) > inactivityThreshold;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateLastActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('SessionContextService: Failed to update last activity: $e');
    }
  }

  (AccessLevel, String?) _determineAccessLevel({
    required bool isNewDevice,
    required bool isOddHours,
    required bool isAfterInactivity,
    required bool deviceTrusted,
  }) {
    // Priority order of restrictions

    if (!deviceTrusted) {
      return (AccessLevel.blocked, 'Untrusted device');
    }

    if (isNewDevice) {
      return (AccessLevel.readOnly, 'New device - 7 day cooling period');
    }

    if (isOddHours) {
      return (AccessLevel.readOnly, 'Odd hours access (12AM-5AM)');
    }

    if (isAfterInactivity) {
      return (AccessLevel.restricted, 'First login after 7+ days inactivity');
    }

    return (AccessLevel.full, null);
  }
}
