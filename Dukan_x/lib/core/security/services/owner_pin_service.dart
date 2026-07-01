// ============================================================================
// OWNER PIN SERVICE
// ============================================================================
// Handles secure storage and verification of owner PINs.
// PINs are hashed using SHA-256 before storage - never stored plain text.
// ============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';

import '../models/security_settings.dart';
import 'enhanced_pin_lockout_service.dart';

/// Owner PIN Service - Secure PIN management for business owners.
///
/// Features:
/// - SHA-256 hashing of PINs
/// - Secure storage in Firestore and local cache
/// - PIN validation with lockout after failed attempts
/// - Audit logging of all verification attempts
class OwnerPinService {
  final FirebaseFirestore _firestore;

  /// Cache of security settings by businessId
  final Map<String, SecuritySettings> _settingsCache = {};

  /// Failed attempt counter for lockout
  final Map<String, int> _failedAttempts = {};

  /// Lockout end times
  final Map<String, DateTime> _lockoutUntil = {};

  /// Maximum failed attempts before lockout
  static const int maxFailedAttempts = 5;

  /// Lockout duration after max failed attempts
  static const Duration lockoutDuration = Duration(minutes: 15);

  /// Enhanced lockout service for progressive lockout with persistence
  final EnhancedPinLockoutService _enhancedLockout =
      EnhancedPinLockoutService();

  OwnerPinService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Hash a PIN using SHA-256
  ///
  /// PIN is salted with businessId for additional security.
  String _hashPin(String businessId, String pin) {
    final saltedPin = '$businessId:$pin';
    final bytes = utf8.encode(saltedPin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Set owner PIN for a business
  ///
  /// Used during onboarding or when changing PIN.
  /// PIN must be 4-6 digits.
  Future<void> setPin({
    required String businessId,
    required String pin,
    String? oldPin, // Required when changing existing PIN
  }) async {
    // Validate PIN format
    if (!_isValidPinFormat(pin)) {
      throw PinException('PIN must be 4-6 digits');
    }

    // If changing existing PIN, verify old PIN first
    if (oldPin != null) {
      final isValid = await verifyPin(businessId: businessId, pin: oldPin);
      if (!isValid) {
        throw PinException('Current PIN is incorrect');
      }
    }

    // Hash and store
    final pinHash = _hashPin(businessId, pin);

    final existingSettings = await getSecuritySettings(businessId);

    if (existingSettings != null) {
      // Update existing settings
      await _firestore.collection('security_settings').doc(businessId).update({
        'ownerPinHash': pinHash,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update cache
      _settingsCache[businessId] = existingSettings.copyWith(
        ownerPinHash: pinHash,
      );
    } else {
      // Create new settings with defaults
      final settings = SecuritySettings.withDefaults(
        businessId: businessId,
        ownerPinHash: pinHash,
      );

      await _firestore
          .collection('security_settings')
          .doc(businessId)
          .set(settings.toFirestore());

      _settingsCache[businessId] = settings;
    }

    debugPrint('OwnerPinService: PIN set for business $businessId');
  }

  /// Verify owner PIN
  ///
  /// Returns true if PIN matches, false otherwise.
  /// Implements progressive lockout after failed attempts with persistence.
  Future<bool> verifyPin({
    required String businessId,
    required String pin,
    String? deviceId,
  }) async {
    // Check enhanced lockout first (persisted, survives app restart)
    final lockoutStatus = await _enhancedLockout.checkLockoutStatus(
      businessId: businessId,
      deviceId: deviceId,
    );

    if (lockoutStatus.isLocked) {
      throw PinLockoutException(
        lockoutStatus.message ?? 'Too many failed attempts. Try again later.',
      );
    }

    // Show soft warning if approaching lockout
    if (lockoutStatus.isSoftWarning) {
      debugPrint('[PIN] Warning: ${lockoutStatus.message}');
    }

    // Legacy lockout check (in-memory, for backward compatibility)
    if (_isLockedOut(businessId)) {
      final remaining = _lockoutUntil[businessId]!.difference(DateTime.now());
      throw PinLockoutException(
        'Too many failed attempts. Try again in ${remaining.inMinutes} minutes.',
      );
    }

    final settings = await getSecuritySettings(businessId);
    if (settings == null) {
      throw PinException('Security settings not configured');
    }

    final inputHash = _hashPin(businessId, pin);
    final isValid = inputHash == settings.ownerPinHash;

    if (isValid) {
      // Reset failed attempts (both legacy and enhanced)
      _failedAttempts.remove(businessId);
      _lockoutUntil.remove(businessId);
      await _enhancedLockout.recordSuccess(
        businessId: businessId,
        deviceId: deviceId,
      );
      return true;
    } else {
      // Record failed attempt in enhanced service (persisted)
      final newStatus = await _enhancedLockout.recordFailedAttempt(
        businessId: businessId,
        deviceId: deviceId,
      );

      // Also update legacy counters for backward compatibility
      _failedAttempts[businessId] = (_failedAttempts[businessId] ?? 0) + 1;

      if (_failedAttempts[businessId]! >= maxFailedAttempts) {
        _lockoutUntil[businessId] = DateTime.now().add(lockoutDuration);
      }

      // Throw if now locked
      if (newStatus.isLocked) {
        throw PinLockoutException(
          newStatus.message ?? 'Too many failed attempts. Account locked.',
        );
      }

      return false;
    }
  }

  /// Get cooldown information for UI display
  Future<CooldownInfo?> getCooldownInfo(String businessId) async {
    return await _enhancedLockout.getCooldownInfo(businessId);
  }

  /// Get current lockout status for UI
  Future<LockoutCheckResult> getLockoutStatus(
    String businessId, {
    String? deviceId,
  }) async {
    return await _enhancedLockout.checkLockoutStatus(
      businessId: businessId,
      deviceId: deviceId,
    );
  }

  /// Check if PIN is configured for a business
  Future<bool> isPinConfigured(String businessId) async {
    final settings = await getSecuritySettings(businessId);
    return settings != null && settings.ownerPinHash.isNotEmpty;
  }

  /// Get security settings for a business
  Future<SecuritySettings?> getSecuritySettings(String businessId) async {
    // Check cache first
    if (_settingsCache.containsKey(businessId)) {
      return _settingsCache[businessId];
    }

    // Fetch from Firestore
    try {
      final doc = await _firestore
          .collection('security_settings')
          .doc(businessId)
          .get();

      if (!doc.exists) return null;

      final settings = SecuritySettings.fromFirestore(doc);
      _settingsCache[businessId] = settings;
      return settings;
    } catch (e) {
      debugPrint('OwnerPinService: Error fetching settings: $e');
      return null;
    }
  }

  /// Update security settings
  Future<void> updateSecuritySettings({
    required String businessId,
    required SecuritySettings settings,
    required String pin, // Require PIN to change settings
  }) async {
    // Verify PIN first
    final isValid = await verifyPin(businessId: businessId, pin: pin);
    if (!isValid) {
      throw PinException('Invalid PIN');
    }

    await _firestore
        .collection('security_settings')
        .doc(businessId)
        .update(settings.toFirestore());

    _settingsCache[businessId] = settings;
  }

  /// Check if high discount requires PIN
  Future<bool> requiresPinForDiscount({
    required String businessId,
    required double discountPercent,
  }) async {
    final settings = await getSecuritySettings(businessId);
    if (settings == null) return true; // Default to requiring PIN
    return settings.requiresPinForDiscount(discountPercent);
  }

  /// Clear cache (for testing or logout)
  void clearCache() {
    _settingsCache.clear();
    _failedAttempts.clear();
    _lockoutUntil.clear();
  }

  bool _isValidPinFormat(String pin) {
    if (pin.length < 4 || pin.length > 6) return false;
    return RegExp(r'^\d+$').hasMatch(pin);
  }

  bool _isLockedOut(String businessId) {
    final lockoutEnd = _lockoutUntil[businessId];
    if (lockoutEnd == null) return false;
    return DateTime.now().isBefore(lockoutEnd);
  }
}

/// Exception for PIN-related errors
class PinException implements Exception {
  final String message;
  PinException(this.message);

  @override
  String toString() => 'PinException: $message';
}

/// Exception for PIN lockout
class PinLockoutException implements Exception {
  final String message;
  PinLockoutException(this.message);

  @override
  String toString() => 'PinLockoutException: $message';
}
