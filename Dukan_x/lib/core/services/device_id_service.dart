// ============================================================================
// DEVICE ID SERVICE
// ============================================================================
// Generates and persists a unique device identifier for multi-device
// conflict resolution in the sync engine.
//
// Usage:
//   final deviceId = await DeviceIdService.instance.getDeviceId();
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service for managing unique device identification
class DeviceIdService {
  static const String _deviceIdKey = 'dukanx_device_id';
  static const String _deviceNameKey = 'dukanx_device_name';

  // Singleton
  static DeviceIdService? _instance;
  static DeviceIdService get instance => _instance ??= DeviceIdService._();

  DeviceIdService._();

  String? _cachedDeviceId;
  String? _cachedDeviceName;

  /// Get the unique device ID
  /// Generates one if it doesn't exist
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null || deviceId.isEmpty) {
      // Generate new UUID for this device
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
      debugPrint('DeviceIdService: Generated new device ID: $deviceId');
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Get a human-readable device name
  Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    final prefs = await SharedPreferences.getInstance();
    var deviceName = prefs.getString(_deviceNameKey);

    if (deviceName == null || deviceName.isEmpty) {
      // Generate default name based on platform
      deviceName = _generateDefaultDeviceName();
      await prefs.setString(_deviceNameKey, deviceName);
    }

    _cachedDeviceName = deviceName;
    return deviceName;
  }

  /// Set a custom device name
  Future<void> setDeviceName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceNameKey, name);
    _cachedDeviceName = name;
  }

  /// Generate a default device name based on platform
  String _generateDefaultDeviceName() {
    if (kIsWeb) {
      return 'Web Browser';
    }

    // Use platform-specific identification
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android Device';
      case TargetPlatform.iOS:
        return 'iPhone/iPad';
      case TargetPlatform.windows:
        return 'Windows PC';
      case TargetPlatform.macOS:
        return 'Mac';
      case TargetPlatform.linux:
        return 'Linux PC';
      default:
        return 'Unknown Device';
    }
  }

  /// Get device info for conflict resolution
  Future<Map<String, String>> getDeviceInfo() async {
    return {
      'deviceId': await getDeviceId(),
      'deviceName': await getDeviceName(),
    };
  }

  /// Check if this is the same device that created a record
  Future<bool> isSameDevice(String? recordDeviceId) async {
    if (recordDeviceId == null) return false;
    final currentDeviceId = await getDeviceId();
    return recordDeviceId == currentDeviceId;
  }

  /// Clear device ID (for testing or factory reset)
  Future<void> clearDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    await prefs.remove(_deviceNameKey);
    _cachedDeviceId = null;
    _cachedDeviceName = null;
    debugPrint('DeviceIdService: Device ID cleared');
  }
}
