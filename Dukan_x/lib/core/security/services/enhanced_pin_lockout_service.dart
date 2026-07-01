// ============================================================================
// ENHANCED PIN LOCKOUT SERVICE
// ============================================================================
// Progressive lockout enhancement for PIN brute-force protection.
//
// Features:
// - Progressive lockout durations (1 min → 5 min → 15 min → 1 hour)
// - Persisted failed attempt counter (survives app restart)
// - Soft lock warning before hard lock
// - Cooldown timer display
// - Respects device binding
//
// IMPORTANT: This is an ADDITIVE enhancement. It does not modify the core
// OwnerPinService verification logic, only wraps it with enhanced lockout.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Progressive lockout configuration
class ProgressiveLockoutConfig {
  /// Lockout durations based on attempt count
  static const List<Duration> lockoutDurations = [
    Duration(minutes: 1), // After 3 failed attempts
    Duration(minutes: 5), // After 5 failed attempts
    Duration(minutes: 15), // After 7 failed attempts
    Duration(hours: 1), // After 10 failed attempts (hard lock)
  ];

  /// Attempt thresholds for each lockout level
  static const List<int> attemptThresholds = [3, 5, 7, 10];

  /// Soft warning threshold (shows warning but allows attempts)
  static const int softWarningThreshold = 2;

  /// Maximum cooldown display (for UI)
  static const Duration maxCooldownDisplay = Duration(hours: 1);

  /// Auto-reset duration (failed attempts reset after this inactivity)
  static const Duration autoResetDuration = Duration(hours: 24);
}

/// Lockout status for UI display
enum LockoutStatus {
  /// No lockout, normal operation
  clear,

  /// Soft warning - user should be warned but can continue
  softWarning,

  /// Hard locked - user cannot attempt PIN
  locked,
}

/// Result of a lockout check
class LockoutCheckResult {
  final LockoutStatus status;
  final int failedAttempts;
  final int attemptsRemaining;
  final Duration? cooldownRemaining;
  final String? message;
  final DateTime? lockedUntil;

  LockoutCheckResult({
    required this.status,
    required this.failedAttempts,
    required this.attemptsRemaining,
    this.cooldownRemaining,
    this.message,
    this.lockedUntil,
  });

  bool get isLocked => status == LockoutStatus.locked;
  bool get isSoftWarning => status == LockoutStatus.softWarning;
  bool get isClear => status == LockoutStatus.clear;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'failedAttempts': failedAttempts,
    'attemptsRemaining': attemptsRemaining,
    'cooldownSeconds': cooldownRemaining?.inSeconds,
    'message': message,
    'lockedUntil': lockedUntil?.toIso8601String(),
  };
}

/// Enhanced PIN Lockout Service with progressive lockout and persistence
class EnhancedPinLockoutService {
  final FlutterSecureStorage _storage;
  static const String _storagePrefix = 'pin_lockout_';

  EnhancedPinLockoutService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Check lockout status before allowing PIN entry
  Future<LockoutCheckResult> checkLockoutStatus({
    required String businessId,
    String? deviceId,
  }) async {
    final data = await _loadLockoutData(businessId);

    // Check if lockout has expired
    if (data.lockedUntil != null && DateTime.now().isAfter(data.lockedUntil!)) {
      // Lockout expired, but don't reset attempts (they decay over time)
      await _updateLockoutData(businessId, data.copyWith(lockedUntil: null));
    }

    // Check for auto-reset (24 hours since last attempt)
    if (data.lastAttemptAt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(
        data.lastAttemptAt!,
      );
      if (timeSinceLastAttempt > ProgressiveLockoutConfig.autoResetDuration) {
        // Reset all lockout data
        await resetLockout(businessId);
        return LockoutCheckResult(
          status: LockoutStatus.clear,
          failedAttempts: 0,
          attemptsRemaining: ProgressiveLockoutConfig.attemptThresholds.first,
        );
      }
    }

    // Check if currently locked
    if (data.lockedUntil != null &&
        DateTime.now().isBefore(data.lockedUntil!)) {
      final cooldown = data.lockedUntil!.difference(DateTime.now());
      return LockoutCheckResult(
        status: LockoutStatus.locked,
        failedAttempts: data.failedAttempts,
        attemptsRemaining: 0,
        cooldownRemaining: cooldown,
        lockedUntil: data.lockedUntil,
        message: _formatCooldownMessage(cooldown),
      );
    }

    // Check for soft warning
    if (data.failedAttempts >= ProgressiveLockoutConfig.softWarningThreshold) {
      final nextThreshold = _getNextThreshold(data.failedAttempts);
      return LockoutCheckResult(
        status: LockoutStatus.softWarning,
        failedAttempts: data.failedAttempts,
        attemptsRemaining: nextThreshold - data.failedAttempts,
        message:
            'Warning: ${nextThreshold - data.failedAttempts} attempts remaining before lockout',
      );
    }

    // Clear status
    return LockoutCheckResult(
      status: LockoutStatus.clear,
      failedAttempts: data.failedAttempts,
      attemptsRemaining:
          ProgressiveLockoutConfig.attemptThresholds.first -
          data.failedAttempts,
    );
  }

  /// Record a failed PIN attempt
  Future<LockoutCheckResult> recordFailedAttempt({
    required String businessId,
    String? deviceId,
  }) async {
    final data = await _loadLockoutData(businessId);
    final newAttempts = data.failedAttempts + 1;

    // Determine if we should lock
    final thresholdIndex = _getThresholdIndex(newAttempts);
    DateTime? lockedUntil;

    if (thresholdIndex >= 0) {
      final lockoutDuration =
          ProgressiveLockoutConfig.lockoutDurations[thresholdIndex.clamp(
            0,
            ProgressiveLockoutConfig.lockoutDurations.length - 1,
          )];
      lockedUntil = DateTime.now().add(lockoutDuration);
    }

    // Update data
    await _updateLockoutData(
      businessId,
      _PinLockoutData(
        failedAttempts: newAttempts,
        lockedUntil: lockedUntil,
        lastAttemptAt: DateTime.now(),
        deviceId: deviceId ?? data.deviceId,
      ),
    );

    debugPrint(
      '[EnhancedPinLockout] Failed attempt #$newAttempts for $businessId',
    );

    // Return updated status
    return checkLockoutStatus(businessId: businessId, deviceId: deviceId);
  }

  /// Record a successful PIN verification (resets lockout)
  Future<void> recordSuccess({
    required String businessId,
    String? deviceId,
  }) async {
    await resetLockout(businessId);
    debugPrint(
      '[EnhancedPinLockout] PIN verified successfully for $businessId',
    );
  }

  /// Reset lockout for a business
  Future<void> resetLockout(String businessId) async {
    await _storage.delete(key: '$_storagePrefix$businessId');
    debugPrint('[EnhancedPinLockout] Lockout reset for $businessId');
  }

  /// Get cooldown information for UI display
  Future<CooldownInfo?> getCooldownInfo(String businessId) async {
    final result = await checkLockoutStatus(businessId: businessId);

    if (!result.isLocked) return null;

    return CooldownInfo(
      remainingDuration: result.cooldownRemaining!,
      lockedUntil: result.lockedUntil!,
      failedAttempts: result.failedAttempts,
      displayMessage: result.message ?? 'PIN locked',
    );
  }

  /// Get lockout history for audit
  Future<Map<String, dynamic>> getLockoutHistory(String businessId) async {
    final data = await _loadLockoutData(businessId);
    final status = await checkLockoutStatus(businessId: businessId);

    return {
      'businessId': businessId,
      'failedAttempts': data.failedAttempts,
      'isLocked': status.isLocked,
      'lockedUntil': data.lockedUntil?.toIso8601String(),
      'lastAttemptAt': data.lastAttemptAt?.toIso8601String(),
      'deviceId': data.deviceId,
      'status': status.status.name,
    };
  }

  // ============================================================================
  // INTERNAL METHODS
  // ============================================================================

  Future<_PinLockoutData> _loadLockoutData(String businessId) async {
    try {
      final json = await _storage.read(key: '$_storagePrefix$businessId');
      if (json == null) return _PinLockoutData.empty();

      final map = jsonDecode(json) as Map<String, dynamic>;
      return _PinLockoutData.fromJson(map);
    } catch (e) {
      debugPrint('[EnhancedPinLockout] Error loading data: $e');
      return _PinLockoutData.empty();
    }
  }

  Future<void> _updateLockoutData(
    String businessId,
    _PinLockoutData data,
  ) async {
    try {
      await _storage.write(
        key: '$_storagePrefix$businessId',
        value: jsonEncode(data.toJson()),
      );
    } catch (e) {
      debugPrint('[EnhancedPinLockout] Error saving data: $e');
    }
  }

  int _getThresholdIndex(int attempts) {
    for (
      var i = 0;
      i < ProgressiveLockoutConfig.attemptThresholds.length;
      i++
    ) {
      if (attempts >= ProgressiveLockoutConfig.attemptThresholds[i]) {
        continue;
      }
      return i - 1;
    }
    return ProgressiveLockoutConfig.attemptThresholds.length - 1;
  }

  int _getNextThreshold(int attempts) {
    for (final threshold in ProgressiveLockoutConfig.attemptThresholds) {
      if (attempts < threshold) return threshold;
    }
    return ProgressiveLockoutConfig.attemptThresholds.last;
  }

  String _formatCooldownMessage(Duration cooldown) {
    if (cooldown.inHours >= 1) {
      return 'Locked for ${cooldown.inHours} hour(s) and ${cooldown.inMinutes % 60} minute(s)';
    } else if (cooldown.inMinutes >= 1) {
      return 'Locked for ${cooldown.inMinutes} minute(s)';
    } else {
      return 'Locked for ${cooldown.inSeconds} second(s)';
    }
  }
}

/// Internal lockout data storage
class _PinLockoutData {
  final int failedAttempts;
  final DateTime? lockedUntil;
  final DateTime? lastAttemptAt;
  final String? deviceId;

  _PinLockoutData({
    required this.failedAttempts,
    this.lockedUntil,
    this.lastAttemptAt,
    this.deviceId,
  });

  factory _PinLockoutData.empty() => _PinLockoutData(failedAttempts: 0);

  factory _PinLockoutData.fromJson(Map<String, dynamic> json) {
    return _PinLockoutData(
      failedAttempts: json['failedAttempts'] as int? ?? 0,
      lockedUntil: json['lockedUntil'] != null
          ? DateTime.parse(json['lockedUntil'] as String)
          : null,
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
      deviceId: json['deviceId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'failedAttempts': failedAttempts,
    'lockedUntil': lockedUntil?.toIso8601String(),
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    'deviceId': deviceId,
  };

  _PinLockoutData copyWith({
    int? failedAttempts,
    DateTime? lockedUntil,
    DateTime? lastAttemptAt,
    String? deviceId,
  }) {
    return _PinLockoutData(
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}

/// Cooldown information for UI display
class CooldownInfo {
  final Duration remainingDuration;
  final DateTime lockedUntil;
  final int failedAttempts;
  final String displayMessage;

  CooldownInfo({
    required this.remainingDuration,
    required this.lockedUntil,
    required this.failedAttempts,
    required this.displayMessage,
  });

  String get formattedCooldown {
    final minutes = remainingDuration.inMinutes;
    final seconds = remainingDuration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
