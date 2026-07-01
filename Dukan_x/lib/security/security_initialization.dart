import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import './encryption/encryption_service.dart';
import './device/device_security.dart';
import './network/ssl_pinning.dart';
import './monitoring/threat_detector.dart';
import './monitoring/security_monitor.dart';
import './auth/biometric_auth.dart';
import './database/tamper_detection.dart';
import './backup/backup_service.dart';

/// Master Security Initialization Service
/// Initializes and coordinates all security layers on app startup
class SecurityInitializationService {
  // Security services
  late EncryptionService _encryptionService;
  late DeviceSecurityService _deviceSecurityService;
  late NetworkSecurityService _networkSecurityService;
  late ThreatDetectionService _threatDetectionService;
  late SecurityMonitoringService _securityMonitoringService;
  late BiometricAuthService _biometricAuthService;
  late TamperDetectionService _tamperDetectionService;
  late BackupService _backupService;

  bool _isInitialized = false;
  bool _isDeviceSafe = false;
  bool _hasValidAppSignature = false;

  /// Initialize all security layers
  Future<bool> initializeAllSecurityLayers() async {
    try {
      // 1. Device Security Check (CRITICAL)
      _deviceSecurityService = DeviceSecurityService();
      _isDeviceSafe = await _deviceSecurityService.isDeviceSafe();
      _hasValidAppSignature = await _deviceSecurityService.verifyAppSignature();

      if (!_isDeviceSafe) {
        _showCriticalSecurityAlert(
          'Device Jailbroken/Rooted',
          'This app cannot run on modified devices for security reasons.',
        );
        return false;
      }

      if (!_hasValidAppSignature) {
        _showCriticalSecurityAlert(
          'App Tampered',
          'App integrity check failed. Do not use this app.',
        );
        return false;
      }

      // 2. Encryption Service
      _encryptionService = EncryptionService();
      await _encryptionService.initialize();

      // 3. Network Security
      _networkSecurityService = NetworkSecurityService();
      await _networkSecurityService.initialize();

      // 4. Backup Service
      _backupService = BackupService();
      await _backupService.initialize();

      // 5. Threat Detection
      _threatDetectionService = ThreatDetectionService();
      await _threatDetectionService.initialize();

      // 6. Security Monitoring
      _securityMonitoringService = SecurityMonitoringService();
      await _securityMonitoringService.initialize();

      // 7. Biometric Authentication
      _biometricAuthService = BiometricAuthService();
      await _biometricAuthService.initialize();

      // 8. Tamper Detection
      _tamperDetectionService = TamperDetectionService();
      await _tamperDetectionService.initialize();

      _isInitialized = true;

      // Print security status
      await _printSecurityStatus();

      return true;
    } catch (e) {
      _showCriticalSecurityAlert(
        'Security Initialization Failed',
        'The app could not initialize security systems. Please reinstall.',
      );
      return false;
    }
  }

  /// Verify all security systems are active
  Future<bool> verifyAllSecurityActive() async {
    try {
      // Check device security
      if (!_isDeviceSafe) {
        return false;
      }

      // Check app integrity
      if (!_hasValidAppSignature) {
        return false;
      }

      // Check threat status
      final threats = _threatDetectionService.getDetectedThreats();
      if (threats.isNotEmpty) {
        return false;
      }

      // Check if biometric auth required
      if (!_biometricAuthService.isAuthenticated()) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Print comprehensive security status
  Future<void> _printSecurityStatus() async {
    try {
      // Collect security status (for future logging/reporting)
      await _deviceSecurityService.getSecurityReport();
      await _networkSecurityService.getNetworkSecurityStatus();
      _threatDetectionService.getThreatStatus();
      _biometricAuthService.getAuthStatus();
      await _backupService.getBackupStatus();
      _tamperDetectionService.getTamperStatus();
    } catch (e) {
      // Ignore
    }
  }

  /// Show critical security alert and terminate app
  ///
  /// SECURITY: This is a hard enforcement - app MUST NOT run on compromised devices
  void _showCriticalSecurityAlert(String title, String message) {
    // Log security incident locally (Firebase Crashlytics removed)
    try {
      developer.log(
        'CRITICAL_SECURITY_VIOLATION: $title - $message',
        name: 'SecurityInit',
        level: 1000, // SEVERE
        error: SecurityViolationException('$title: $message'),
        stackTrace: StackTrace.current,
      );
    } catch (e) {
      debugPrint('Failed to log security violation: $e');
    }

    // Force app termination - cannot continue on compromised device
    // Note: In debug mode, we log but don't exit to allow development
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        SystemNavigator.pop();
      } else if (Platform.isIOS || Platform.isMacOS) {
        exit(1);
      } else {
        exit(1);
      }
    } else {
      debugPrint(
        '⚠️ SECURITY ALERT (Debug Mode - Not Exiting): $title - $message',
      );
    }
  }

  // Getters for security services
  EncryptionService get encryptionService => _encryptionService;
  DeviceSecurityService get deviceSecurityService => _deviceSecurityService;
  NetworkSecurityService get networkSecurityService => _networkSecurityService;
  ThreatDetectionService get threatDetectionService => _threatDetectionService;
  SecurityMonitoringService get securityMonitoringService =>
      _securityMonitoringService;
  BiometricAuthService get biometricAuthService => _biometricAuthService;
  TamperDetectionService get tamperDetectionService => _tamperDetectionService;
  BackupService get backupService => _backupService;

  bool get isInitialized => _isInitialized;
  bool get isDeviceSafe => _isDeviceSafe;
  bool get hasValidAppSignature => _hasValidAppSignature;

  /// Dispose all security services
  void dispose() {
    _encryptionService.dispose();
    _deviceSecurityService.dispose();
    _networkSecurityService.dispose();
    _threatDetectionService.dispose();
    _securityMonitoringService.dispose();
    _biometricAuthService.dispose();
    _tamperDetectionService.dispose();
    _backupService.dispose();
  }

  /// Get full security dashboard
  Future<Map<String, dynamic>> getSecurityDashboard() async {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'isInitialized': _isInitialized,
      'isDeviceSafe': _isDeviceSafe,
      'hasValidSignature': _hasValidAppSignature,
      'device': await _deviceSecurityService.getSecurityReport(),
      'network': await _networkSecurityService.getNetworkSecurityStatus(),
      'threats': _threatDetectionService.getThreatStatus(),
      'monitoring': _securityMonitoringService.getMonitoringDashboard(),
      'authentication': _biometricAuthService.getAuthStatus(),
      'backup': await _backupService.getBackupStatus(),
      'tamperDetection': _tamperDetectionService.getTamperStatus(),
      'overallStatus': _isInitialized && _isDeviceSafe && _hasValidAppSignature
          ? 'SECURE âœ“'
          : 'COMPROMISED âœ—',
    };
  }
}

/// Exception thrown when a critical security violation is detected
class SecurityViolationException implements Exception {
  final String message;

  SecurityViolationException(this.message);

  @override
  String toString() => 'SecurityViolationException: $message';
}
