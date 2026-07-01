// ============================================================================
// DEVICE FINGERPRINT MODEL
// ============================================================================
// Unique device identification for trusted device binding.
// Combines multiple signals to create unforgeable device identity.
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device Fingerprint - Unique device identification.
///
/// Combines multiple signals:
/// - Platform device ID
/// - App installation UUID (persisted)
/// - OS version
/// - App version
/// - Hardware characteristics
class DeviceFingerprint {
  /// Unique installation ID (generated once, persisted)
  final String installationId;

  /// Platform-specific device ID
  final String deviceId;

  /// Operating system name
  final String platform;

  /// OS version string
  final String osVersion;

  /// App version
  final String appVersion;

  /// Device model/name
  final String deviceModel;

  /// Combined fingerprint hash
  final String fingerprintHash;

  /// Creation timestamp
  final DateTime createdAt;

  const DeviceFingerprint({
    required this.installationId,
    required this.deviceId,
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.deviceModel,
    required this.fingerprintHash,
    required this.createdAt,
  });

  /// Generate fingerprint for current device
  static Future<DeviceFingerprint> generate({
    required String appVersion,
  }) async {
    final installationId = await _getOrCreateInstallationId();
    final deviceId = await _getDeviceId();
    final platform = _getPlatform();
    final osVersion = _getOsVersion();
    final deviceModel = _getDeviceModel();

    // Create combined hash
    final combined = '$installationId:$deviceId:$platform:$osVersion';
    final hash = sha256.convert(utf8.encode(combined)).toString();

    return DeviceFingerprint(
      installationId: installationId,
      deviceId: deviceId,
      platform: platform,
      osVersion: osVersion,
      appVersion: appVersion,
      deviceModel: deviceModel,
      fingerprintHash: hash,
      createdAt: DateTime.now(),
    );
  }

  /// Get or create persistent installation ID
  static Future<String> _getOrCreateInstallationId() async {
    const key = 'device_installation_id';
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(key);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await prefs.setString(key, id);
        debugPrint('DeviceFingerprint: Created new installation ID');
      }
      return id;
    } catch (e) {
      debugPrint('DeviceFingerprint: Failed to get installation ID: $e');
      return 'unknown-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Get platform-specific device ID
  static Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        // Android ID would come from device_info_plus
        // For now, use a placeholder
        return 'android-${await _getOrCreateInstallationId()}';
      } else if (Platform.isIOS) {
        return 'ios-${await _getOrCreateInstallationId()}';
      } else if (Platform.isWindows) {
        return 'windows-${await _getOrCreateInstallationId()}';
      }
      return 'unknown-${await _getOrCreateInstallationId()}';
    } catch (e) {
      return 'error-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  static String _getPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static String _getOsVersion() {
    return Platform.operatingSystemVersion;
  }

  static String _getDeviceModel() {
    // Would come from device_info_plus
    return Platform.localHostname;
  }

  /// Check if this fingerprint matches another
  bool matches(DeviceFingerprint other) {
    // Primary match: installation ID (most stable)
    if (installationId == other.installationId) {
      return true;
    }
    // Secondary match: fingerprint hash
    return fingerprintHash == other.fingerprintHash;
  }

  /// Serialize to map
  Map<String, dynamic> toMap() => {
    'installationId': installationId,
    'deviceId': deviceId,
    'platform': platform,
    'osVersion': osVersion,
    'appVersion': appVersion,
    'deviceModel': deviceModel,
    'fingerprintHash': fingerprintHash,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Deserialize from map
  factory DeviceFingerprint.fromMap(Map<String, dynamic> map) {
    return DeviceFingerprint(
      installationId: map['installationId'] as String,
      deviceId: map['deviceId'] as String,
      platform: map['platform'] as String,
      osVersion: map['osVersion'] as String? ?? '',
      appVersion: map['appVersion'] as String? ?? '',
      deviceModel: map['deviceModel'] as String? ?? '',
      fingerprintHash: map['fingerprintHash'] as String,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  String toString() =>
      'DeviceFingerprint(platform: $platform, model: $deviceModel, hash: ${fingerprintHash.substring(0, 8)}...)';
}

/// Trusted Device - A registered owner device
class TrustedDevice {
  final String id;
  final String businessId;
  final String ownerId;
  final DeviceFingerprint fingerprint;
  final String deviceName;
  final DateTime registeredAt;
  final DateTime? lastUsedAt;
  final bool isPrimary;
  final TrustedDeviceStatus status;

  const TrustedDevice({
    required this.id,
    required this.businessId,
    required this.ownerId,
    required this.fingerprint,
    required this.deviceName,
    required this.registeredAt,
    this.lastUsedAt,
    this.isPrimary = false,
    this.status = TrustedDeviceStatus.active,
  });

  /// Check if device is in cooling period (new device restrictions)
  bool get isInCoolingPeriod {
    const coolingDays = 7;
    return DateTime.now().difference(registeredAt).inDays < coolingDays;
  }

  /// Check if device can perform owner actions
  bool get canPerformOwnerActions {
    return status == TrustedDeviceStatus.active && !isInCoolingPeriod;
  }

  TrustedDevice copyWith({DateTime? lastUsedAt, TrustedDeviceStatus? status}) {
    return TrustedDevice(
      id: id,
      businessId: businessId,
      ownerId: ownerId,
      fingerprint: fingerprint,
      deviceName: deviceName,
      registeredAt: registeredAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      isPrimary: isPrimary,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'businessId': businessId,
    'ownerId': ownerId,
    'fingerprint': fingerprint.toMap(),
    'deviceName': deviceName,
    'registeredAt': registeredAt.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
    'isPrimary': isPrimary,
    'status': status.name,
  };

  factory TrustedDevice.fromMap(Map<String, dynamic> map) {
    return TrustedDevice(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      ownerId: map['ownerId'] as String,
      fingerprint: DeviceFingerprint.fromMap(
        map['fingerprint'] as Map<String, dynamic>,
      ),
      deviceName: map['deviceName'] as String,
      registeredAt: DateTime.parse(map['registeredAt'] as String),
      lastUsedAt: map['lastUsedAt'] != null
          ? DateTime.parse(map['lastUsedAt'] as String)
          : null,
      isPrimary: map['isPrimary'] as bool? ?? false,
      status: TrustedDeviceStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => TrustedDeviceStatus.active,
      ),
    );
  }
}

/// Trusted device status
enum TrustedDeviceStatus {
  /// Device is active and can be used
  active,

  /// Device is in cooling period (new registration)
  cooling,

  /// Device has been revoked
  revoked,

  /// Device is suspended (suspicious activity)
  suspended,
}

// ============================================================================
// MACHINE FINGERPRINT — Offline License Activation (Fingerprint_Collector)
// ============================================================================
// Extends the device-identity surface above with the structured
// Machine_Fingerprint used to bind an offline lifetime license to a single
// machine. This is the COLLECTION + same-machine layer (spec task 4.1).
//
// The Fingerprint_Hash (SHA256(cpuId + macAddress + hddSerial)) is computed by
// task 4.2 and is intentionally left as a placeholder here.
//
//   Requirements: 5.1 (collect cpuId, macAddress, hddSerial, osType, hostname),
//                 6.1 (same machine iff at most one component differs),
//                 6.2 (two or more differing components => new machine).
// ============================================================================

/// Structured device identity composed of the five components the offline
/// license binding depends on (Requirement 5.1).
///
/// Values are gathered cross-platform (Windows / macOS / Linux). Missing or
/// unavailable components are represented as empty strings rather than thrown
/// errors so collection always yields a complete, comparable fingerprint.
class MachineFingerprint {
  /// Stable CPU / processor identifier.
  final String cpuId;

  /// Primary network adapter MAC address (normalized, uppercase).
  final String macAddress;

  /// Primary disk / board serial number.
  final String hddSerial;

  /// Operating system family, e.g. `windows`, `macos`, `linux`.
  final String osType;

  /// Machine host name.
  final String hostname;

  const MachineFingerprint({
    required this.cpuId,
    required this.macAddress,
    required this.hddSerial,
    required this.osType,
    required this.hostname,
  });

  /// The five components in their canonical order.
  List<String> get components => [
    cpuId,
    macAddress,
    hddSerial,
    osType,
    hostname,
  ];

  /// Count of the five components that differ between this fingerprint and
  /// [other]. This is the drift measure used by both [FingerprintCollector.isSameMachine]
  /// (Requirements 6.1/6.2) and, later, the License_Validator grace-period
  /// classification (task 5.1, `driftComponentCount`).
  int differingComponentCount(MachineFingerprint other) {
    var count = 0;
    if (cpuId != other.cpuId) count++;
    if (macAddress != other.macAddress) count++;
    if (hddSerial != other.hddSerial) count++;
    if (osType != other.osType) count++;
    if (hostname != other.hostname) count++;
    return count;
  }

  Map<String, dynamic> toMap() => {
    'cpuId': cpuId,
    'macAddress': macAddress,
    'hddSerial': hddSerial,
    'osType': osType,
    'hostname': hostname,
  };

  factory MachineFingerprint.fromMap(Map<String, dynamic> map) {
    return MachineFingerprint(
      cpuId: map['cpuId'] as String? ?? '',
      macAddress: map['macAddress'] as String? ?? '',
      hddSerial: map['hddSerial'] as String? ?? '',
      osType: map['osType'] as String? ?? '',
      hostname: map['hostname'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MachineFingerprint &&
          cpuId == other.cpuId &&
          macAddress == other.macAddress &&
          hddSerial == other.hddSerial &&
          osType == other.osType &&
          hostname == other.hostname;

  @override
  int get hashCode =>
      Object.hash(cpuId, macAddress, hddSerial, osType, hostname);

  /// Masked representation — raw hardware identifiers must never reach logs
  /// (Security_Layer log-scrubbing, Requirement 17.10).
  @override
  String toString() =>
      'MachineFingerprint(osType: $osType, cpuId: ${_mask(cpuId)}, '
      'mac: ${_mask(macAddress)}, hdd: ${_mask(hddSerial)}, '
      'host: ${_mask(hostname)})';

  static String _mask(String value) {
    if (value.isEmpty) return '<none>';
    if (value.length <= 4) return '****';
    return '${value.substring(0, 4)}…';
  }
}

/// Collects the [MachineFingerprint] and decides whether two fingerprints
/// describe the same machine.
abstract class FingerprintCollector {
  /// Gather the current machine's [MachineFingerprint] (Requirement 5.1).
  Future<MachineFingerprint> collect();

  /// Fingerprint_Hash = SHA256(cpuId + macAddress + hddSerial).
  ///
  /// Implemented by spec task 4.2; declared here so the collector contract is
  /// complete.
  String fingerprintHash(MachineFingerprint fp);

  /// True iff [current] is the same machine as [activated], tolerating drift in
  /// at most one of the five components (Requirements 6.1, 6.2).
  bool isSameMachine(MachineFingerprint activated, MachineFingerprint current);
}

/// Cross-platform [FingerprintCollector] for desktop (Windows / macOS / Linux).
///
/// Reuses the established collection patterns already used by
/// `device_fingerprint_service.dart` (PowerShell `Get-CimInstance` on Windows,
/// `system_profiler` on macOS, `/sys/class/dmi` on Linux) plus the
/// `device_info_plus` plugin already in the project for stable fallbacks.
class DeviceFingerprintCollector implements FingerprintCollector {
  DeviceFingerprintCollector({DeviceInfoPlugin? deviceInfo})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  @override
  bool isSameMachine(
    MachineFingerprint activated,
    MachineFingerprint current,
  ) => activated.differingComponentCount(current) <= 1;

  @override
  String fingerprintHash(MachineFingerprint fp) {
    // Fingerprint_Hash = SHA256(cpuId + macAddress + hddSerial) (Requirement 5.2).
    //
    // Only the three hardware-bound components are hashed (in canonical order);
    // osType and hostname are deliberately excluded so the binding survives an
    // OS reinstall or a hostname change. Reuses the `crypto` package already
    // imported for DeviceFingerprint above rather than introducing a new hasher.
    final combined = fp.cpuId + fp.macAddress + fp.hddSerial;
    return sha256.convert(utf8.encode(combined)).toString();
  }

  @override
  Future<MachineFingerprint> collect() async {
    final osType = Platform.operatingSystem;
    final hostname = _safeHostname();

    if (Platform.isWindows) {
      return _collectWindows(osType: osType, hostname: hostname);
    } else if (Platform.isMacOS) {
      return _collectMacOS(osType: osType, hostname: hostname);
    } else if (Platform.isLinux) {
      return _collectLinux(osType: osType, hostname: hostname);
    }

    // Unsupported platform — return os/hostname only so the result is still a
    // complete, comparable fingerprint.
    return MachineFingerprint(
      cpuId: '',
      macAddress: await _collectMacAddress(),
      hddSerial: '',
      osType: osType,
      hostname: hostname,
    );
  }

  // ---- Windows ----------------------------------------------------------

  Future<MachineFingerprint> _collectWindows({
    required String osType,
    required String hostname,
  }) async {
    var cpuId = await _runCommand('powershell', [
      '-NoProfile',
      '-Command',
      '(Get-CimInstance -ClassName Win32_Processor).ProcessorId',
    ]);
    final hddSerial = await _runCommand('powershell', [
      '-NoProfile',
      '-Command',
      '(Get-CimInstance -ClassName Win32_DiskDrive | Select-Object -First 1).SerialNumber',
    ]);
    final macAddress = await _runCommand('powershell', [
      '-NoProfile',
      '-Command',
      '(Get-CimInstance Win32_NetworkAdapter -Filter "PhysicalAdapter=True AND '
          'NetEnabled=True" | Select-Object -First 1).MACAddress',
    ]);

    // Stable fallback from device_info_plus when ProcessorId is unavailable.
    if (cpuId.isEmpty) {
      try {
        cpuId = (await _deviceInfo.windowsInfo).deviceId;
      } catch (_) {
        // ignore — leave empty
      }
    }

    return MachineFingerprint(
      cpuId: cpuId.trim(),
      macAddress: _normalizeMac(macAddress),
      hddSerial: hddSerial.trim(),
      osType: osType,
      hostname: hostname,
    );
  }

  // ---- macOS ------------------------------------------------------------

  Future<MachineFingerprint> _collectMacOS({
    required String osType,
    required String hostname,
  }) async {
    final hardware = await _runCommand('system_profiler', [
      'SPHardwareDataType',
    ]);

    var cpuId = _matchFirst(hardware, RegExp(r'Hardware UUID:\s*(\S+)'));
    final hddSerial = _matchFirst(
      hardware,
      RegExp(r'Serial Number.*:\s*(\S+)'),
    );
    final macAddress = await _collectMacAddress();

    if (cpuId.isEmpty) {
      try {
        cpuId = (await _deviceInfo.macOsInfo).systemGUID ?? '';
      } catch (_) {
        // ignore — leave empty
      }
    }

    return MachineFingerprint(
      cpuId: cpuId.trim(),
      macAddress: _normalizeMac(macAddress),
      hddSerial: hddSerial.trim(),
      osType: osType,
      hostname: hostname,
    );
  }

  // ---- Linux ------------------------------------------------------------

  Future<MachineFingerprint> _collectLinux({
    required String osType,
    required String hostname,
  }) async {
    var cpuId = await _readFirstLine('/sys/class/dmi/id/product_uuid');
    final hddSerial = await _readFirstLine('/sys/class/dmi/id/board_serial');
    final macAddress = await _collectMacAddress();

    if (cpuId.isEmpty) {
      try {
        cpuId = (await _deviceInfo.linuxInfo).machineId ?? '';
      } catch (_) {
        // ignore — leave empty
      }
    }

    return MachineFingerprint(
      cpuId: cpuId.trim(),
      macAddress: _normalizeMac(macAddress),
      hddSerial: hddSerial.trim(),
      osType: osType,
      hostname: hostname,
    );
  }

  // ---- Shared helpers ---------------------------------------------------

  /// Best-effort primary MAC address, cross-platform.
  ///
  /// `dart:io`'s [NetworkInterface] does not expose the hardware MAC address,
  /// so each desktop OS is queried through its native tooling instead.
  Future<String> _collectMacAddress() async {
    try {
      if (Platform.isWindows) {
        return await _runCommand('powershell', [
          '-NoProfile',
          '-Command',
          '(Get-CimInstance Win32_NetworkAdapter -Filter "PhysicalAdapter=True '
              'AND NetEnabled=True" | Select-Object -First 1).MACAddress',
        ]);
      } else if (Platform.isMacOS) {
        final out = await _runCommand('ifconfig', ['en0']);
        return _matchFirst(out, RegExp(r'ether\s+([0-9a-fA-F:]{17})'));
      } else if (Platform.isLinux) {
        // First non-loopback interface address file.
        final netDir = Directory('/sys/class/net');
        if (netDir.existsSync()) {
          for (final entry in netDir.listSync()) {
            final name = entry.path.split(Platform.pathSeparator).last;
            if (name == 'lo') continue;
            final addr = await _readFirstLine('${entry.path}/address');
            if (addr.isNotEmpty) return addr;
          }
        }
      }
    } catch (_) {
      // ignore — return empty
    }
    return '';
  }

  String _safeHostname() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return '';
    }
  }

  /// Runs [executable] with [args] and returns trimmed stdout, or '' on error.
  Future<String> _runCommand(String executable, List<String> args) async {
    try {
      final result = await Process.run(executable, args, runInShell: true);
      if (result.exitCode != 0) return '';
      return result.stdout.toString().trim();
    } catch (_) {
      return '';
    }
  }

  Future<String> _readFirstLine(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return '';
      final content = await file.readAsString();
      final value = content.trim();
      if (value.contains('Permission')) return '';
      return value;
    } catch (_) {
      return '';
    }
  }

  String _matchFirst(String input, RegExp pattern) {
    final match = pattern.firstMatch(input);
    return match == null ? '' : (match.group(1) ?? '').trim();
  }

  /// Normalizes a MAC address to uppercase with stripped surrounding
  /// whitespace so comparisons are case- and format-stable.
  String _normalizeMac(String mac) => mac.trim().toUpperCase();
}
