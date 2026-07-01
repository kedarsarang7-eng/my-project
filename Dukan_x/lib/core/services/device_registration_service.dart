// ============================================================================
// DEVICE REGISTRATION SERVICE — Phase 3 Multi-Device Auth
// ============================================================================
// Registers the current device with the backend on login and handles
// heartbeat updates during sync cycles. If the backend returns 410
// (DEVICE_DEREGISTERED), the device was remotely signed out.
// ============================================================================

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'logger_service.dart';
import 'device_id_service.dart';

/// Result of a heartbeat call. If deregistered, the app should sign out.
enum HeartbeatResult { ok, deregistered, error }

/// Manages device registration lifecycle with the backend.
class DeviceRegistrationService {
  static DeviceRegistrationService? _instance;
  static DeviceRegistrationService get instance =>
      _instance ??= DeviceRegistrationService._();

  DeviceRegistrationService._();

  static const String _kRegistered = 'device_registered';

  String get _baseUrl => dotenv.env['API_BASE_URL'] ?? '';

  String? _authToken;
  String? _tenantId;

  /// Set auth credentials (called after login).
  void setCredentials({required String token, String? tenantId}) {
    _authToken = token;
    _tenantId = tenantId;
  }

  Map<String, String> _buildHeaders(String deviceId) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_authToken',
    // ignore: use_null_aware_elements
    if (_tenantId != null) 'X-Tenant-Id': _tenantId!,
    'X-Device-Id': deviceId,
  };

  /// Register this device with the backend.
  /// Should be called after successful Cognito login.
  Future<bool> registerDevice() async {
    try {
      final deviceId = await DeviceIdService.instance.getDeviceId();
      final deviceName = await DeviceIdService.instance.getDeviceName();
      final platform = _getCurrentPlatform();

      final packageInfo = await PackageInfo.fromPlatform();

      final response = await http.post(
        Uri.parse('$_baseUrl/devices/register'),
        headers: _buildHeaders(deviceId),
        body: jsonEncode({
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
          'appVersion': packageInfo.version,
        }),
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kRegistered, true);
        LoggerService.d('DeviceRegistration', 'DeviceRegistration: Registered ($deviceName / $platform)');
        return true;
      } else {
        LoggerService.d('DeviceRegistration', 
          'DeviceRegistration: Registration failed: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      LoggerService.d('DeviceRegistration', 'DeviceRegistration: Error: $e');
      return false;
    }
  }

  /// List all devices for the current user.
  Future<List<Map<String, dynamic>>> listDevices() async {
    try {
      final deviceId = await DeviceIdService.instance.getDeviceId();

      final response = await http.get(
        Uri.parse('$_baseUrl/devices'),
        headers: _buildHeaders(deviceId),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final devices = (data['devices'] as List<dynamic>?) ?? [];
        return devices.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      LoggerService.d('DeviceRegistration', 'DeviceRegistration: List error: $e');
    }
    return [];
  }

  /// Deregister a device by session ID (remote sign-out).
  Future<bool> deregisterDevice(String sessionId) async {
    try {
      final deviceId = await DeviceIdService.instance.getDeviceId();

      final response = await http.post(
        Uri.parse('$_baseUrl/devices/$sessionId/deregister'),
        headers: _buildHeaders(deviceId),
      );

      return response.statusCode == 200;
    } catch (e) {
      LoggerService.d('DeviceRegistration', 'DeviceRegistration: Deregister error: $e');
      return false;
    }
  }

  /// Send heartbeat to update last_active_at.
  /// Returns [HeartbeatResult.deregistered] if the device was remotely
  /// signed out (HTTP 410), signaling the app should log out.
  Future<HeartbeatResult> sendHeartbeat() async {
    try {
      final deviceId = await DeviceIdService.instance.getDeviceId();

      final response = await http.post(
        Uri.parse('$_baseUrl/devices/heartbeat'),
        headers: _buildHeaders(deviceId),
        body: jsonEncode({'deviceId': deviceId}),
      );

      if (response.statusCode == 200) {
        return HeartbeatResult.ok;
      } else if (response.statusCode == 410) {
        LoggerService.d('DeviceRegistration', 'DeviceRegistration: Device was remotely deregistered!');
        return HeartbeatResult.deregistered;
      }
      return HeartbeatResult.error;
    } catch (e) {
      LoggerService.d('DeviceRegistration', 'DeviceRegistration: Heartbeat error: $e');
      return HeartbeatResult.error;
    }
  }

  /// Get the current platform string for the backend.
  String _getCurrentPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isWindows) return 'windows';
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'unknown';
  }
}
