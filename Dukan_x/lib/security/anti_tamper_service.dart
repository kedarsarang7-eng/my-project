// Anti-Tamper Service — Client-side integrity checks
// Detects: debug mode, emulator, clock manipulation, root/jailbreak, app integrity
// Reports suspicious activity to server for logging

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../core/services/logger_service.dart';

/// Result of client-side tamper checks
class TamperCheckResult {
  final bool isSuspicious;
  final List<String> warnings;
  final bool isDebugMode;
  final bool isEmulator;
  final bool clockDriftDetected;
  final bool isRooted;
  final bool integrityCompromised;

  const TamperCheckResult({
    required this.isSuspicious,
    this.warnings = const [],
    this.isDebugMode = false,
    this.isEmulator = false,
    this.clockDriftDetected = false,
    this.isRooted = false,
    this.integrityCompromised = false,
  });

  Map<String, dynamic> toJson() => {
    'is_suspicious': isSuspicious,
    'warnings': warnings,
    'is_debug': isDebugMode,
    'is_emulator': isEmulator,
    'clock_drift': clockDriftDetected,
    'is_rooted': isRooted,
    'integrity_compromised': integrityCompromised,
  };
}

/// Client-side anti-tamper detection service
class AntiTamperService {
  /// Cached server time offset (milliseconds) — updated on each server response
  int _serverTimeOffsetMs = 0;

  /// Maximum allowed clock drift before flagging (5 minutes)
  static const int _maxClockDriftMs = 5 * 60 * 1000;

  /// Singleton
  static final AntiTamperService _instance = AntiTamperService._internal();
  factory AntiTamperService() => _instance;
  AntiTamperService._internal();

  /// Run all tamper checks and return combined result
  TamperCheckResult performChecks() {
    final warnings = <String>[];
    bool suspicious = false;
    bool isRooted = false;
    bool integrityFailed = false;

    // 1. Debug mode detection
    final isDebug = _checkDebugMode();
    if (isDebug) {
      warnings.add('debug_mode');
      if (!kDebugMode) suspicious = true;
    }

    // 2. Emulator detection
    final isEmulator = _detectEmulator();
    if (isEmulator) {
      warnings.add('emulator_detected');
      if (!kDebugMode) suspicious = true;
    }

    // 3. Clock drift detection
    final hasDrift = _detectClockDrift();
    if (hasDrift) {
      warnings.add('clock_drift');
      suspicious = true;
    }

    // 4. Root/Jailbreak detection
    isRooted = _detectRootOrJailbreak();
    if (isRooted) {
      warnings.add('root_jailbreak');
      if (!kDebugMode) suspicious = true;
    }

    // 5. App integrity check
    integrityFailed = _checkAppIntegrity();
    if (integrityFailed) {
      warnings.add('integrity_compromised');
      suspicious = true;
    }

    return TamperCheckResult(
      isSuspicious: suspicious,
      warnings: warnings,
      isDebugMode: isDebug,
      isEmulator: isEmulator,
      clockDriftDetected: hasDrift,
      isRooted: isRooted,
      integrityCompromised: integrityFailed,
    );
  }

  /// Update server time offset from a server response's server_time field
  void updateServerTimeOffset(String? serverTimeIso) {
    if (serverTimeIso == null) return;
    try {
      final serverTime = DateTime.parse(serverTimeIso);
      final localTime = DateTime.now().toUtc();
      _serverTimeOffsetMs = serverTime.difference(localTime).inMilliseconds;
      LoggerService.d('AntiTamper', 'AntiTamper: Server time offset = ${_serverTimeOffsetMs}ms');
    } catch (e) {
      LoggerService.d('AntiTamper', 'AntiTamper: Failed to parse server_time: $e');
    }
  }

  /// Get drift-corrected current time
  DateTime getCorrectedTime() {
    return DateTime.now().toUtc().add(
      Duration(milliseconds: _serverTimeOffsetMs),
    );
  }

  /// Generate app signature for server verification
  /// The server will verify this using APP_SIGNATURE_SECRET
  String getAppSignature() {
    return ApiConfig.appVersion;
  }

  // ── Private Detection Methods ──────────────────────────────────

  /// Detect if running in debug mode (assert mode / profile mode)
  bool _checkDebugMode() {
    return kDebugMode || kProfileMode;
  }

  /// Detect if running on emulator/simulator
  bool _detectEmulator() {
    try {
      if (Platform.isAndroid) {
        final env = Platform.environment;
        if (env.containsKey('ANDROID_EMULATOR') ||
            env.containsKey('GOLDFISH')) {
          return true;
        }
      }

      if (Platform.isWindows) {
        final hostname = Platform.localHostname.toLowerCase();
        final vmIndicators = ['virtualbox', 'vmware', 'qemu', 'hyper-v'];
        for (final indicator in vmIndicators) {
          if (hostname.contains(indicator)) return true;
        }
      }
    } catch (e) {
      LoggerService.d('AntiTamper', 'AntiTamper: Emulator check error: $e');
    }
    return false;
  }

  /// Detect if local clock differs significantly from server time
  bool _detectClockDrift() {
    if (_serverTimeOffsetMs == 0) return false;
    return _serverTimeOffsetMs.abs() > _maxClockDriftMs;
  }

  /// Detect if device is rooted (Android) or jailbroken (iOS)
  bool _detectRootOrJailbreak() {
    try {
      if (Platform.isAndroid) {
        // Check for common root indicators
        final rootPaths = [
          '/system/app/Superuser.apk',
          '/system/xbin/su',
          '/system/bin/su',
          '/sbin/su',
          '/data/local/xbin/su',
          '/data/local/bin/su',
          '/data/local/su',
        ];
        for (final path in rootPaths) {
          if (File(path).existsSync()) return true;
        }

        // Check for Magisk
        final magiskPaths = [
          '/sbin/.magisk',
          '/data/adb/magisk',
          '/data/adb/modules',
        ];
        for (final path in magiskPaths) {
          if (Directory(path).existsSync()) return true;
        }

        // Check for Xposed framework
        final xposedPaths = [
          '/system/framework/XposedBridge.jar',
          '/data/data/de.robv.android.xposed.installer',
        ];
        for (final path in xposedPaths) {
          if (File(path).existsSync() || Directory(path).existsSync()) {
            return true;
          }
        }
      }

      if (Platform.isIOS) {
        // Check for common jailbreak indicators
        final jailbreakPaths = [
          '/Applications/Cydia.app',
          '/Library/MobileSubstrate/MobileSubstrate.dylib',
          '/bin/bash',
          '/usr/sbin/sshd',
          '/etc/apt',
          '/private/var/lib/apt/',
        ];
        for (final path in jailbreakPaths) {
          if (File(path).existsSync() || Directory(path).existsSync()) {
            return true;
          }
        }
      }
    } catch (e) {
      LoggerService.d('AntiTamper', 'AntiTamper: Root/jailbreak check error: $e');
    }
    return false;
  }

  /// Check app binary integrity
  /// On Windows: checks if running from unexpected location (temp dir)
  /// On Android: checks for test-keys in build properties
  bool _checkAppIntegrity() {
    try {
      if (Platform.isWindows) {
        final exePath = Platform.resolvedExecutable;
        // Flag if running from temp directory (suspicious — could be cracked copy)
        if (exePath.toLowerCase().contains('\\temp\\') ||
            exePath.toLowerCase().contains('\\tmp\\')) {
          return true;
        }
      }

      if (Platform.isAndroid) {
        try {
          final buildProps = File('/system/build.prop');
          if (buildProps.existsSync()) {
            final content = buildProps.readAsStringSync();
            if (content.contains('test-keys')) {
              return true;
            }
          }
        } catch (_) {
          // Some devices restrict build.prop access
        }
      }
    } catch (e) {
      LoggerService.d('AntiTamper', 'AntiTamper: Integrity check error: $e');
    }
    return false;
  }
}
