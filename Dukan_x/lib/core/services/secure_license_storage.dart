// ignore_for_file: unused_field
// ============================================
// FIX P0-008: Secure License Storage with Encryption
// ============================================
// Stores encrypted license tokens using platform keychains.
// - Android: EncryptedSharedPreferences
// - iOS: Keychain
// - Uses flutter_secure_storage for automatic encryption

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted license data persisted in platform keychain
class SecureLicenseData {
  final String licenseKey;
  final String clientId;
  final String businessType;
  final String status;
  final DateTime expiryDate;
  final DateTime activationDate;
  final int maxDevices;
  final int offlineGraceHours;
  final String? signedToken;  // JWT signed by server
  final DateTime? nextValidationRequiredBy;
  final Map<String, dynamic> features;
  final DateTime storedAt;

  SecureLicenseData({
    required this.licenseKey,
    required this.clientId,
    required this.businessType,
    required this.status,
    required this.expiryDate,
    required this.activationDate,
    required this.maxDevices,
    required this.offlineGraceHours,
    this.signedToken,
    this.nextValidationRequiredBy,
    required this.features,
    required this.storedAt,
  });

  /// Serialize to JSON for storage
  Map<String, dynamic> toJson() => {
    'licenseKey': licenseKey,
    'clientId': clientId,
    'businessType': businessType,
    'status': status,
    'expiryDate': expiryDate.toIso8601String(),
    'activationDate': activationDate.toIso8601String(),
    'maxDevices': maxDevices,
    'offlineGraceHours': offlineGraceHours,
    'signedToken': signedToken,
    'nextValidationRequiredBy': nextValidationRequiredBy?.toIso8601String(),
    'features': features,
    'storedAt': storedAt.toIso8601String(),
  };

  /// Deserialize from JSON
  factory SecureLicenseData.fromJson(Map<String, dynamic> json) {
    return SecureLicenseData(
      licenseKey: json['licenseKey'] as String,
      clientId: json['clientId'] as String,
      businessType: json['businessType'] as String,
      status: json['status'] as String,
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      activationDate: DateTime.parse(json['activationDate'] as String),
      maxDevices: json['maxDevices'] as int,
      offlineGraceHours: json['offlineGraceHours'] as int,
      signedToken: json['signedToken'] as String?,
      nextValidationRequiredBy: json['nextValidationRequiredBy'] != null
          ? DateTime.parse(json['nextValidationRequiredBy'] as String)
          : null,
      features: (json['features'] as Map<String, dynamic>?) ?? {},
      storedAt: DateTime.parse(json['storedAt'] as String),
    );
  }
}

/// Secure storage service for encrypted license persistence
class SecureLicenseStorage {
  static const _storageKey = 'dukanx_license_encrypted_v2';
  static const _passwordKey = 'dukanx_license_passwd';
  
  final FlutterSecureStorage _storage;

  SecureLicenseStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Store encrypted license data in secure storage
  /// - Serializes to JSON
  /// - Encrypts via FlutterSecureStorage (platform keychain)
  /// - Platform handles key management securely
  Future<void> saveLicense(SecureLicenseData license) async {
    try {
      final json = jsonEncode(license.toJson());
      
      await _storage.write(
        key: _storageKey,
        value: json,
      );
      
      developer.log('License encrypted and stored securely', 
          name: 'SecureLicenseStorage');
    } catch (e) {
      developer.log('Failed to save license securely: $e',
          name: 'SecureLicenseStorage', level: 900);
      rethrow;
    }
  }

  /// Retrieve and decrypt license data from secure storage
  /// - Decrypts via FlutterSecureStorage (platform keychain)
  /// - Validates expiry + nextValidationRequiredBy
  /// - Returns null if not found or expired
  Future<SecureLicenseData?> getLicense() async {
    try {
      final json = await _storage.read(key: _storageKey);
      
      if (json == null) {
        developer.log('No license found in secure storage',
            name: 'SecureLicenseStorage');
        return null;
      }
      
      final data = SecureLicenseData.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      
      // Check expiry
      if (data.expiryDate.isBefore(DateTime.now())) {
        developer.log('License expired', name: 'SecureLicenseStorage');
        return null;
      }
      
      // Check next validation deadline
      if (data.nextValidationRequiredBy != null &&
          DateTime.now().isAfter(data.nextValidationRequiredBy!)) {
        developer.log('Next validation deadline exceeded',
            name: 'SecureLicenseStorage');
        // Don't delete - let app decide on re-validation
      }
      
      developer.log('License decrypted successfully',
          name: 'SecureLicenseStorage');
      return data;
    } catch (e) {
      developer.log('Failed to read license: $e',
          name: 'SecureLicenseStorage', level: 900);
      return null;
    }
  }

  /// Delete encrypted license data
  Future<void> deleteLicense() async {
    try {
      await _storage.delete(key: _storageKey);
      developer.log('License removed from secure storage',
          name: 'SecureLicenseStorage');
    } catch (e) {
      developer.log('Failed to delete license: $e',
          name: 'SecureLicenseStorage', level: 900);
    }
  }

  /// Check if license is stored (without decrypting)
  Future<bool> hasLicense() async {
    try {
      final value = await _storage.read(key: _storageKey);
      return value != null;
    } catch (_) {
      return false;
    }
  }

  /// Clear all secure storage (complete wipe)
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      developer.log('All secure storage cleared', 
          name: 'SecureLicenseStorage');
    } catch (e) {
      developer.log('Failed to clear secure storage: $e',
          name: 'SecureLicenseStorage', level: 900);
    }
  }
}
