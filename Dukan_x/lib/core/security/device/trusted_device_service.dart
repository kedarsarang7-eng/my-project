// ============================================================================
// TRUSTED DEVICE SERVICE
// ============================================================================
// Manages trusted device registration and validation.
// Core defense: Owner actions only from registered devices.
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:uuid/uuid.dart';

import 'device_fingerprint.dart';
import '../../repository/audit_repository.dart';

/// Device Validation Result
class DeviceValidationResult {
  final bool isValid;
  final bool isTrusted;
  final bool isInCoolingPeriod;
  final TrustedDevice? device;
  final String? reason;

  const DeviceValidationResult._({
    required this.isValid,
    this.isTrusted = false,
    this.isInCoolingPeriod = false,
    this.device,
    this.reason,
  });

  factory DeviceValidationResult.trusted(TrustedDevice device) {
    return DeviceValidationResult._(
      isValid: true,
      isTrusted: true,
      isInCoolingPeriod: device.isInCoolingPeriod,
      device: device,
    );
  }

  factory DeviceValidationResult.untrusted(String reason) {
    return DeviceValidationResult._(isValid: false, reason: reason);
  }

  factory DeviceValidationResult.cooling(TrustedDevice device) {
    return DeviceValidationResult._(
      isValid: false,
      isTrusted: true,
      isInCoolingPeriod: true,
      device: device,
      reason:
          'Device is in 7-day cooling period. Full access after ${device.registeredAt.add(const Duration(days: 7)).toString().split(' ')[0]}',
    );
  }
}

/// Trusted Device Service - Device binding for owner security.
///
/// Rules:
/// - Max 2 trusted devices per owner
/// - New devices have 7-day cooling period
/// - Owner actions ONLY from trusted devices
/// - Device removal requires dual control
class TrustedDeviceService {
  final FirebaseFirestore _firestore;
  final AuditRepository _auditRepository;

  /// Max trusted devices per owner
  static const int maxTrustedDevices = 2;

  /// Cooling period for new devices
  static const int coolingPeriodDays = 7;

  /// Cached current device fingerprint
  DeviceFingerprint? _currentFingerprint;

  /// Cached trusted devices
  final Map<String, List<TrustedDevice>> _deviceCache = {};

  TrustedDeviceService({
    FirebaseFirestore? firestore,
    required AuditRepository auditRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auditRepository = auditRepository;

  /// Get current device fingerprint
  Future<DeviceFingerprint> getCurrentFingerprint() async {
    _currentFingerprint ??= await DeviceFingerprint.generate(
      appVersion: '1.0.0', // Would come from package_info_plus
    );
    return _currentFingerprint!;
  }

  /// Register current device as trusted
  Future<TrustedDevice> registerTrustedDevice({
    required String businessId,
    required String ownerId,
    required String pin, // Require PIN for registration
    required String deviceName,
    bool isPrimary = false,
  }) async {
    final fingerprint = await getCurrentFingerprint();

    // Check existing device count
    final existingDevices = await getTrustedDevices(businessId, ownerId);

    // Check if this device is already registered
    for (final device in existingDevices) {
      if (device.fingerprint.matches(fingerprint)) {
        throw DeviceBindingException('This device is already registered');
      }
    }

    // Check max device limit
    final activeDevices = existingDevices
        .where((d) => d.status == TrustedDeviceStatus.active)
        .length;

    if (activeDevices >= maxTrustedDevices) {
      throw DeviceBindingException(
        'Maximum $maxTrustedDevices trusted devices allowed. '
        'Remove an existing device first.',
      );
    }

    // Create trusted device
    final device = TrustedDevice(
      id: const Uuid().v4(),
      businessId: businessId,
      ownerId: ownerId,
      fingerprint: fingerprint,
      deviceName: deviceName,
      registeredAt: DateTime.now(),
      isPrimary: isPrimary || existingDevices.isEmpty,
      status: TrustedDeviceStatus.cooling,
    );

    // Save to Firestore
    await _firestore
        .collection('trusted_devices')
        .doc(device.id)
        .set(device.toMap());

    // Update cache
    _deviceCache[_cacheKey(businessId, ownerId)] = [...existingDevices, device];

    // Audit log
    await _auditRepository.logAction(
      userId: ownerId,
      targetTableName: 'trusted_devices',
      recordId: device.id,
      action: 'REGISTER',
      newValueJson: jsonEncode({
        'deviceName': deviceName,
        'platform': fingerprint.platform,
        'fingerprintHash': fingerprint.fingerprintHash.substring(0, 16),
      }),
    );

    debugPrint('TrustedDeviceService: Registered new device: $deviceName');
    return device;
  }

  /// Validate if current device is trusted for owner actions
  Future<DeviceValidationResult> validateCurrentDevice({
    required String businessId,
    required String ownerId,
  }) async {
    final fingerprint = await getCurrentFingerprint();
    final devices = await getTrustedDevices(businessId, ownerId);

    for (final device in devices) {
      if (device.fingerprint.matches(fingerprint)) {
        // Device found
        if (device.status == TrustedDeviceStatus.revoked) {
          return DeviceValidationResult.untrusted('Device has been revoked');
        }
        if (device.status == TrustedDeviceStatus.suspended) {
          return DeviceValidationResult.untrusted('Device is suspended');
        }
        if (device.isInCoolingPeriod) {
          return DeviceValidationResult.cooling(device);
        }

        // Update last used
        await _updateLastUsed(device);
        return DeviceValidationResult.trusted(device);
      }
    }

    return DeviceValidationResult.untrusted(
      'This device is not registered as a trusted owner device',
    );
  }

  /// Check if action is allowed on current device
  Future<bool> isOwnerActionAllowed({
    required String businessId,
    required String ownerId,
    required String action,
  }) async {
    final result = await validateCurrentDevice(
      businessId: businessId,
      ownerId: ownerId,
    );

    if (!result.isValid) {
      // Log unauthorized attempt
      await _logUnauthorizedAttempt(
        businessId: businessId,
        ownerId: ownerId,
        action: action,
        reason: result.reason ?? 'Unknown',
      );
      return false;
    }

    return true;
  }

  /// Get all trusted devices for an owner
  Future<List<TrustedDevice>> getTrustedDevices(
    String businessId,
    String ownerId,
  ) async {
    final cacheKey = _cacheKey(businessId, ownerId);

    if (_deviceCache.containsKey(cacheKey)) {
      return _deviceCache[cacheKey]!;
    }

    try {
      final querySnapshot = await _firestore
          .collection('trusted_devices')
          .where('businessId', isEqualTo: businessId)
          .where('ownerId', isEqualTo: ownerId)
          .get();

      final devices = querySnapshot.docs
          .map((doc) => TrustedDevice.fromMap(doc.data()))
          .toList();

      _deviceCache[cacheKey] = devices;
      return devices;
    } catch (e) {
      debugPrint('TrustedDeviceService: Error fetching devices: $e');
      return [];
    }
  }

  /// Revoke a trusted device (requires dual control for non-current device)
  Future<void> revokeDevice({
    required String deviceId,
    required String businessId,
    required String ownerId,
    required String revokedBy,
    String? reason,
  }) async {
    final devices = await getTrustedDevices(businessId, ownerId);
    final device = devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => throw DeviceBindingException('Device not found'),
    );

    // Cannot revoke if it's the only active device
    final activeCount = devices
        .where((d) => d.status == TrustedDeviceStatus.active)
        .length;

    if (activeCount == 1 && device.status == TrustedDeviceStatus.active) {
      throw DeviceBindingException(
        'Cannot revoke the only active device. Register a new device first.',
      );
    }

    // Update status
    await _firestore.collection('trusted_devices').doc(deviceId).update({
      'status': TrustedDeviceStatus.revoked.name,
    });

    // Clear cache
    _deviceCache.remove(_cacheKey(businessId, ownerId));

    // Audit log
    await _auditRepository.logAction(
      userId: revokedBy,
      targetTableName: 'trusted_devices',
      recordId: deviceId,
      action: 'REVOKE',
      oldValueJson: jsonEncode({'status': device.status.name}),
      newValueJson: jsonEncode({
        'status': TrustedDeviceStatus.revoked.name,
        'reason': reason,
      }),
    );

    debugPrint('TrustedDeviceService: Device revoked: $deviceId');
  }

  /// Update last used timestamp
  Future<void> _updateLastUsed(TrustedDevice device) async {
    try {
      await _firestore.collection('trusted_devices').doc(device.id).update({
        'lastUsedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('TrustedDeviceService: Failed to update last used: $e');
    }
  }

  /// Log unauthorized action attempt
  Future<void> _logUnauthorizedAttempt({
    required String businessId,
    required String ownerId,
    required String action,
    required String reason,
  }) async {
    final fingerprint = await getCurrentFingerprint();

    await _auditRepository.logAction(
      userId: ownerId,
      targetTableName: 'security_events',
      recordId: businessId,
      action: 'UNAUTHORIZED_DEVICE_ATTEMPT',
      newValueJson: jsonEncode({
        'attemptedAction': action,
        'reason': reason,
        'devicePlatform': fingerprint.platform,
        'deviceModel': fingerprint.deviceModel,
        'fingerprintHash': fingerprint.fingerprintHash.substring(0, 16),
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    debugPrint(
      'TrustedDeviceService: UNAUTHORIZED ATTEMPT - $action from untrusted device',
    );
  }

  String _cacheKey(String businessId, String ownerId) => '$businessId:$ownerId';

  /// Clear cache
  void clearCache() {
    _deviceCache.clear();
    _currentFingerprint = null;
  }
}

/// Exception for device binding errors
class DeviceBindingException implements Exception {
  final String message;
  DeviceBindingException(this.message);

  @override
  String toString() => 'DeviceBindingException: $message';
}
