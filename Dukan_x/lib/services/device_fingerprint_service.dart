// Device Fingerprint Service
// Cross-platform device identification for license binding
//
// This service generates a unique, reproducible fingerprint for each device.
// The fingerprint is used to bind licenses to specific devices.
//
// SECURITY NOTES:
// - Fingerprints are hashed using SHA-256
// - Components vary by platform for maximum uniqueness
// - Desktop fingerprints are more stable than mobile

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Device fingerprint result with metadata
class DeviceFingerprint {
  final String fingerprint;
  final String platform;
  final String? deviceName;
  final String? deviceModel;
  final String? osVersion;
  final Map<String, String> rawComponents;

  const DeviceFingerprint({
    required this.fingerprint,
    required this.platform,
    this.deviceName,
    this.deviceModel,
    this.osVersion,
    required this.rawComponents,
  });

  Map<String, dynamic> toJson() => {
    'fingerprint': fingerprint,
    'platform': platform,
    'deviceName': deviceName,
    'deviceModel': deviceModel,
    'osVersion': osVersion,
    'rawComponents': rawComponents,
  };
}

/// Cross-platform device fingerprint generator
class DeviceFingerprintService {
  static final DeviceFingerprintService _instance =
      DeviceFingerprintService._internal();
  factory DeviceFingerprintService() => _instance;
  DeviceFingerprintService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  DeviceFingerprint? _cachedFingerprint;

  /// Get device fingerprint (cached for performance)
  Future<DeviceFingerprint> getFingerprint() async {
    if (_cachedFingerprint != null) {
      return _cachedFingerprint!;
    }

    _cachedFingerprint = await _generateFingerprint();
    return _cachedFingerprint!;
  }

  /// Force regeneration of fingerprint
  Future<DeviceFingerprint> regenerateFingerprint() async {
    _cachedFingerprint = null;
    return getFingerprint();
  }

  /// Generate platform-specific fingerprint
  Future<DeviceFingerprint> _generateFingerprint() async {
    try {
      if (Platform.isWindows) {
        return _generateWindowsFingerprint();
      } else if (Platform.isMacOS) {
        return _generateMacOSFingerprint();
      } else if (Platform.isLinux) {
        return _generateLinuxFingerprint();
      } else if (Platform.isAndroid) {
        return _generateAndroidFingerprint();
      } else if (Platform.isIOS) {
        return _generateIOSFingerprint();
      } else {
        return _generateFallbackFingerprint();
      }
    } catch (e) {
      debugPrint('DeviceFingerprint: Error generating fingerprint: $e');
      return _generateFallbackFingerprint();
    }
  }

  /// Windows fingerprint using machine GUID, CPU, and disk serial
  Future<DeviceFingerprint> _generateWindowsFingerprint() async {
    final windowsInfo = await _deviceInfo.windowsInfo;
    final components = <String, String>{};

    // Machine GUID (stable across reboots)
    components['machineGuid'] = windowsInfo.deviceId;

    // Computer name
    components['computerName'] = windowsInfo.computerName;

    // Product ID
    components['productId'] = windowsInfo.productId;

    // Try to get CPU ID via command
    try {
      final cpuResult = await Process.run('wmic', [
        'cpu',
        'get',
        'processorid',
      ], runInShell: true);
      final cpuId = cpuResult.stdout
          .toString()
          .split('\n')
          .skip(1)
          .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '')
          .trim();
      if (cpuId.isNotEmpty) {
        components['cpuId'] = cpuId;
      }
    } catch (_) {
      // CPU ID not available
    }

    // Try to get disk serial
    try {
      final diskResult = await Process.run('wmic', [
        'diskdrive',
        'get',
        'serialnumber',
      ], runInShell: true);
      final diskSerial = diskResult.stdout
          .toString()
          .split('\n')
          .skip(1)
          .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '')
          .trim();
      if (diskSerial.isNotEmpty) {
        components['diskSerial'] = diskSerial;
      }
    } catch (_) {
      // Disk serial not available
    }

    // Generate fingerprint hash
    final fingerprintData = components.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    final fingerprint = _hashString(fingerprintData);

    return DeviceFingerprint(
      fingerprint: fingerprint,
      platform: 'windows',
      deviceName: windowsInfo.computerName,
      deviceModel: 'Windows PC',
      osVersion:
          'Windows ${windowsInfo.majorVersion}.${windowsInfo.minorVersion}',
      rawComponents: components,
    );
  }

  /// macOS fingerprint using hardware UUID
  Future<DeviceFingerprint> _generateMacOSFingerprint() async {
    final macInfo = await _deviceInfo.macOsInfo;
    final components = <String, String>{};

    // System UUID (most stable identifier)
    components['systemGuid'] = macInfo.systemGUID ?? '';

    // Model
    components['model'] = macInfo.model;

    // Computer name
    components['computerName'] = macInfo.computerName;

    // Serial number (if available)
    try {
      final serialResult = await Process.run('system_profiler', [
        'SPHardwareDataType',
      ], runInShell: true);
      final output = serialResult.stdout.toString();
      final serialMatch = RegExp(
        r'Serial Number.*:\s*(\S+)',
      ).firstMatch(output);
      if (serialMatch != null) {
        components['serialNumber'] = serialMatch.group(1) ?? '';
      }
    } catch (_) {
      // Serial not available
    }

    final fingerprintData = components.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    final fingerprint = _hashString(fingerprintData);

    return DeviceFingerprint(
      fingerprint: fingerprint,
      platform: 'macos',
      deviceName: macInfo.computerName,
      deviceModel: macInfo.model,
      osVersion:
          'macOS ${macInfo.majorVersion}.${macInfo.minorVersion}.${macInfo.patchVersion}',
      rawComponents: components,
    );
  }

  /// Linux fingerprint using machine ID
  Future<DeviceFingerprint> _generateLinuxFingerprint() async {
    final linuxInfo = await _deviceInfo.linuxInfo;
    final components = <String, String>{};

    // Machine ID (stable across reboots)
    components['machineId'] = linuxInfo.machineId ?? '';

    // Board serial
    try {
      final serialResult = await Process.run('cat', [
        '/sys/class/dmi/id/board_serial',
      ], runInShell: true);
      final serial = serialResult.stdout.toString().trim();
      if (serial.isNotEmpty && !serial.contains('Permission')) {
        components['boardSerial'] = serial;
      }
    } catch (_) {
      // Board serial not available
    }

    // Product UUID
    try {
      final uuidResult = await Process.run('cat', [
        '/sys/class/dmi/id/product_uuid',
      ], runInShell: true);
      final uuid = uuidResult.stdout.toString().trim();
      if (uuid.isNotEmpty && !uuid.contains('Permission')) {
        components['productUuid'] = uuid;
      }
    } catch (_) {
      // Product UUID not available
    }

    final fingerprintData = components.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    final fingerprint = _hashString(fingerprintData);

    return DeviceFingerprint(
      fingerprint: fingerprint,
      platform: 'linux',
      deviceName: linuxInfo.prettyName,
      deviceModel: linuxInfo.name,
      osVersion: linuxInfo.versionId ?? 'Unknown',
      rawComponents: components,
    );
  }

  /// Android fingerprint using Android ID and device properties
  Future<DeviceFingerprint> _generateAndroidFingerprint() async {
    final androidInfo = await _deviceInfo.androidInfo;
    final components = <String, String>{};

    // Android ID (unique per app install)
    components['androidId'] = androidInfo.id;

    // Device fingerprint (manufacturer signature)
    components['deviceFingerprint'] = androidInfo.fingerprint;

    // Serial number (Deprecated/Restricted)
    // if (androidInfo.serialNumber.isNotEmpty ... ) { ... }

    // Hardware ID
    components['hardware'] = androidInfo.hardware;

    // Board
    components['board'] = androidInfo.board;

    final fingerprintData = components.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    final fingerprint = _hashString(fingerprintData);

    return DeviceFingerprint(
      fingerprint: fingerprint,
      platform: 'android',
      deviceName: '${androidInfo.manufacturer} ${androidInfo.model}',
      deviceModel: androidInfo.model,
      osVersion: 'Android ${androidInfo.version.release}',
      rawComponents: components,
    );
  }

  /// iOS fingerprint using identifierForVendor
  Future<DeviceFingerprint> _generateIOSFingerprint() async {
    final iosInfo = await _deviceInfo.iosInfo;
    final components = <String, String>{};

    // Identifier for vendor (stable per vendor apps)
    components['identifierForVendor'] = iosInfo.identifierForVendor ?? '';

    // Device name
    components['name'] = iosInfo.name;

    // Model
    components['model'] = iosInfo.model;

    // System name
    components['systemName'] = iosInfo.systemName;

    final fingerprintData = components.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    final fingerprint = _hashString(fingerprintData);

    return DeviceFingerprint(
      fingerprint: fingerprint,
      platform: 'ios',
      deviceName: iosInfo.name,
      deviceModel: iosInfo.model,
      osVersion: '${iosInfo.systemName} ${iosInfo.systemVersion}',
      rawComponents: components,
    );
  }

  /// Fallback fingerprint for unsupported platforms
  Future<DeviceFingerprint> _generateFallbackFingerprint() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final components = <String, String>{
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'packageName': packageInfo.packageName,
      'localHostname': Platform.localHostname,
    };

    final fingerprintData = components.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    final fingerprint = _hashString(fingerprintData);

    return DeviceFingerprint(
      fingerprint: fingerprint,
      platform: Platform.operatingSystem,
      deviceName: Platform.localHostname,
      deviceModel: 'Unknown',
      osVersion: Platform.operatingSystemVersion,
      rawComponents: components,
    );
  }

  /// Hash string using SHA-256
  String _hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get human-readable platform name
  String getPlatformName() {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  /// Check if running on desktop
  bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Check if running on mobile
  bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// Get platform code for license key
  String getPlatformCode() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return 'DESK';
    }
    return 'MOB';
  }
}
