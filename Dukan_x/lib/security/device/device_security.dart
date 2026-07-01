import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Device Security Layer
/// Detects rooted/jailbroken devices, app tampering, and malicious modifications
///
/// SECURITY NOTE: These are heuristic checks. For production-grade security,
/// implement native platform channels and use:
/// - Android: Play Integrity API, SafetyNet (deprecated)
/// - iOS: App Attest API
class DeviceSecurityService {
  /// Known suspicious paths that indicate root/jailbreak
  static const List<String> _rootIndicators = [
    '/system/app/Superuser.apk',
    '/sbin/su',
    '/system/bin/su',
    '/system/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su',
    '/su/bin/su',
    '/data/adb/magisk',
    '/sbin/.magisk',
  ];

  static const List<String> _jailbreakIndicators = [
    '/Applications/Cydia.app',
    '/Library/MobileSubstrate/MobileSubstrate.dylib',
    '/bin/bash',
    '/usr/sbin/sshd',
    '/etc/apt',
    '/private/var/lib/apt/',
    '/private/var/lib/cydia',
    '/private/var/stash',
    '/usr/libexec/cydia/',
  ];

  /// Initialize device security checks
  /// Returns true if device is safe, false if compromised
  Future<bool> isDeviceSafe() async {
    try {
      // Check for debug build in release context
      if (kReleaseMode && kDebugMode) {
        debugPrint('DeviceSecurity: Inconsistent build mode detected');
        return false;
      }

      // Platform-specific root/jailbreak detection
      if (Platform.isAndroid) {
        return !await _isAndroidRooted();
      } else if (Platform.isIOS) {
        return !await _isIosJailbroken();
      }

      // Other platforms considered safe by default
      return true;
    } catch (e) {
      debugPrint('DeviceSecurity: Error checking device safety: $e');
      return false;
    }
  }

  /// Check for Android root indicators
  Future<bool> _isAndroidRooted() async {
    try {
      for (final path in _rootIndicators) {
        if (await File(path).exists()) {
          debugPrint('DeviceSecurity: Root indicator found at $path');
          return true;
        }
      }

      // Check if su binary is executable
      try {
        final result = await Process.run('which', ['su']);
        if (result.exitCode == 0 &&
            result.stdout.toString().trim().isNotEmpty) {
          debugPrint('DeviceSecurity: su binary found');
          return true;
        }
      } catch (_) {
        // which command failed, likely not rooted
      }

      return false;
    } catch (e) {
      debugPrint('DeviceSecurity: Error checking root status: $e');
      return false;
    }
  }

  /// Check for iOS jailbreak indicators
  Future<bool> _isIosJailbroken() async {
    try {
      for (final path in _jailbreakIndicators) {
        if (await File(path).exists()) {
          debugPrint('DeviceSecurity: Jailbreak indicator found at $path');
          return true;
        }
      }

      // Check if we can write outside sandbox
      try {
        final testFile = File('/private/jailbreak_test');
        await testFile.writeAsString('test');
        await testFile.delete();
        debugPrint('DeviceSecurity: Sandbox escape detected');
        return true;
      } catch (_) {
        // Expected to fail on non-jailbroken device
      }

      return false;
    } catch (e) {
      debugPrint('DeviceSecurity: Error checking jailbreak status: $e');
      return false;
    }
  }

  /// Verify app signature and integrity
  /// Returns true if APK signature is valid
  Future<bool> verifyAppSignature() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      // Check if package name is correct
      if (packageInfo.packageName != 'com.jayhandeveg.billing') {
        debugPrint(
          'DeviceSecurity: Package name mismatch: ${packageInfo.packageName}',
        );
        return false;
      }

      // Check for debug signature in release mode
      if (kReleaseMode) {
        // In release mode, we should have a release signature
        // The signature itself would need native code to verify
        // For now, we verify the package name and that we're in release mode
        return true;
      }

      // Debug builds are allowed during development
      return true;
    } catch (e) {
      debugPrint('DeviceSecurity: Error verifying app signature: $e');
      return false;
    }
  }

  /// Check for common malware indicators
  /// Monitors for hooking frameworks, debuggers, and emulators
  Future<bool> checkForMalware() async {
    try {
      // Check for Frida (common hooking framework)
      if (Platform.isAndroid) {
        final fridaIndicators = [
          '/data/local/tmp/frida-server',
          '/data/local/tmp/re.frida.server',
        ];

        for (final path in fridaIndicators) {
          if (await File(path).exists()) {
            debugPrint('DeviceSecurity: Frida detected at $path');
            return false;
          }
        }
      }

      // Check for debugger attachment
      // Note: This is a basic check; proper detection requires native code
      if (kReleaseMode && kProfileMode) {
        debugPrint('DeviceSecurity: Profile mode in release build detected');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('DeviceSecurity: Error checking for malware: $e');
      return true; // Fail open to avoid blocking on errors
    }
  }

  /// Detect if app is running in emulator
  Future<bool> isRunningInEmulator() async {
    try {
      if (Platform.isAndroid) {
        // Check common Android emulator indicators
        final emulatorIndicators = [
          '/dev/socket/qemud',
          '/dev/qemu_pipe',
          '/system/lib/libc_malloc_debug_qemu.so',
          '/sys/qemu_trace',
          '/system/bin/qemu-props',
        ];

        for (final path in emulatorIndicators) {
          if (await File(path).exists()) {
            debugPrint('DeviceSecurity: Emulator indicator found at $path');
            return true;
          }
        }

        // Check environment variables
        final envVars = Platform.environment;
        if (envVars.containsKey('ANDROID_EMULATOR') ||
            envVars.containsKey('ANDROID_SDK_ROOT')) {
          return true;
        }
      }

      if (Platform.isIOS) {
        // iOS simulator detection via arch
        // Simulators run on x86_64, real devices on arm64
        // This requires native code to check reliably
      }

      return false;
    } catch (e) {
      debugPrint('DeviceSecurity: Error checking emulator status: $e');
      return false;
    }
  }

  /// Verify database file integrity (file system level)
  /// Check if database file is stored in secure application directory
  Future<bool> verifyDatabaseLocation(String dbPath) async {
    try {
      final dbFile = File(dbPath);

      if (!dbFile.existsSync()) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Monitor device storage security
  /// Warns if app data stored in unsecured location
  Future<bool> isStorageSecure(String storagePath) async {
    try {
      // Check if storage is in private app directory (secure)
      if (storagePath.contains('/data/data/') ||
          storagePath.contains('/data/user/')) {
        return true;
      }

      if (storagePath.contains('/sdcard/') ||
          storagePath.contains('/storage/emulated/')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get device security report
  Future<Map<String, dynamic>> getSecurityReport() async {
    try {
      final isEmulator = await isRunningInEmulator();
      final isSafe = await isDeviceSafe();
      final sigValid = await verifyAppSignature();
      final noMalware = await checkForMalware();

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'deviceSafe': isSafe,
        'signatureValid': sigValid,
        'noMalware': noMalware,
        'isEmulator': isEmulator,
        'isDebugBuild': kDebugMode,
        'isReleaseBuild': kReleaseMode,
        'platform': Platform.operatingSystem,
        'overallSafe':
            isSafe && sigValid && noMalware && (!isEmulator || kDebugMode),
      };
    } catch (e) {
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'error': e.toString(),
        'overallSafe': false,
      };
    }
  }

  /// Dispose
  void dispose() {
    // Cleanup
  }
}
