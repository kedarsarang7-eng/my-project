import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Service to handle secure storage of sensitive data
/// Wraps flutter_secure_storage
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
          // resetOnError: true, // Risky, but prevents crash on key corruption
        ),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  // Keys
  static const String _kPinHash = 'user_pin_hash';
  static const String _kBiometricsEnabled = 'biometrics_enabled';
  static const String _kPinEnabled = 'pin_enabled';

  /// Write a value
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Error writing to secure storage: $e');
    }
  }

  /// Read a value
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Error reading from secure storage: $e');
      return null;
    }
  }

  /// Delete a value
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('Error deleting from secure storage: $e');
    }
  }

  /// Clear all
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('Error clearing secure storage: $e');
    }
  }

  // --- Convenience Methods for Auth ---

  /// Store PIN hash
  Future<void> storePinHash(String hash) async {
    await write(_kPinHash, hash);
    await write(_kPinEnabled, 'true');
  }

  /// Get PIN hash
  Future<String?> getPinHash() async {
    return await read(_kPinHash);
  }

  /// Enable/Disable Biometrics
  Future<void> setBiometricsEnabled(bool enabled) async {
    await write(_kBiometricsEnabled, enabled.toString());
  }

  /// Check if Biometrics enabled
  Future<bool> isBiometricsEnabled() async {
    final val = await read(_kBiometricsEnabled);
    return val == 'true';
  }

  /// Check if PIN enabled
  Future<bool> isPinEnabled() async {
    final val = await read(_kPinEnabled);
    return val == 'true';
  }

  /// Disable Fast Login completely
  Future<void> disableFastLogin() async {
    await delete(_kPinHash);
    await delete(_kPinEnabled);
    await delete(_kBiometricsEnabled);
  }
}

// Global instance
final secureStorage = SecureStorageService();
