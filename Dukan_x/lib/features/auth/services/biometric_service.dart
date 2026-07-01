import 'package:local_auth/local_auth.dart';

import 'package:flutter/services.dart';
import '../../../../core/services/secure_storage_service.dart';
import 'dart:developer' as developer;

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final SecureStorageService _secureStorage = SecureStorageService();

  /// Check if device supports biometrics
  Future<bool> isDeviceSupported() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (e) {
      developer.log(
        'Error checking biometrics support: $e',
        name: 'BiometricService',
      );
      return false;
    }
  }

  /// Get available biometrics
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      developer.log(
        'Error getting available biometrics: $e',
        name: 'BiometricService',
      );
      return [];
    }
  }

  /// Authenticate user using biometrics
  Future<bool> authenticate() async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        throw Exception('Biometrics not supported on this device');
      }

      // NOTE: Options temporarily disabled due to local_auth version conflict in environment
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to login securely',
      );
    } on PlatformException catch (e) {
      developer.log(
        'Biometric auth error: ${e.message}',
        name: 'BiometricService',
      );
      return false;
    } catch (e) {
      developer.log('Biometric auth error: $e', name: 'BiometricService');
      return false;
    }
  }

  /// Enable biometrics for the app
  Future<bool> enableBiometrics() async {
    final success = await authenticate();
    if (success) {
      await _secureStorage.setBiometricsEnabled(true);
    }
    return success;
  }

  /// Disable biometrics
  Future<void> disableBiometrics() async {
    await _secureStorage.setBiometricsEnabled(false);
  }

  /// Check if enabled
  Future<bool> isBiometricsEnabled() async {
    return await _secureStorage.isBiometricsEnabled();
  }
}

// Global instance
final biometricService = BiometricService();
