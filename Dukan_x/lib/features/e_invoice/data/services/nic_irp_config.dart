import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/pointycastle.dart';

/// NIC IRP Configuration Service
///
/// Securely stores and retrieves NIC e-Invoice API credentials.
/// All credentials are stored in FlutterSecureStorage.
///
/// IMPORTANT: Configure these credentials during vendor onboarding,
/// NOT in source code.
class NicIrpConfig {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Storage keys
  static const String _keyPrefix = 'nic_irp_';
  static const String _clientIdKey = '${_keyPrefix}client_id';
  static const String _clientSecretKey = '${_keyPrefix}client_secret';
  static const String _usernameKey = '${_keyPrefix}username';
  static const String _passwordKey = '${_keyPrefix}password';
  static const String _gstinKey = '${_keyPrefix}gstin';
  static const String _publicKeyPemKey = '${_keyPrefix}public_key_pem';
  static const String _environmentKey =
      '${_keyPrefix}environment'; // 'sandbox' or 'production'

  // Environment URLs
  static const String sandboxBaseUrl =
      'https://einv-apisandbox.nic.in/einv/v1.03';
  static const String productionBaseUrl =
      'https://einv-apigw.nic.in/einv/v1.03';

  /// Load configuration from secure storage
  static Future<NicIrpConfig?> fromSecureStorage() async {
    try {
      final clientId = await _secureStorage.read(key: _clientIdKey);
      final clientSecret = await _secureStorage.read(key: _clientSecretKey);
      final username = await _secureStorage.read(key: _usernameKey);
      final password = await _secureStorage.read(key: _passwordKey);
      final gstin = await _secureStorage.read(key: _gstinKey);
      final publicKeyPem = await _secureStorage.read(key: _publicKeyPemKey);
      final environment = await _secureStorage.read(key: _environmentKey);

      if (clientId == null ||
          clientSecret == null ||
          username == null ||
          password == null ||
          gstin == null ||
          publicKeyPem == null) {
        debugPrint('NicIrpConfig: Incomplete configuration');
        return null;
      }

      return NicIrpConfig._(
        clientId: clientId,
        clientSecret: clientSecret,
        username: username,
        password: password,
        gstin: gstin,
        publicKeyPem: publicKeyPem,
        isSandbox: environment != 'production',
      );
    } catch (e) {
      debugPrint('NicIrpConfig: Error loading configuration: $e');
      return null;
    }
  }

  /// Configure NIC IRP credentials
  ///
  /// Call this during vendor onboarding or settings configuration
  static Future<void> configure({
    required String clientId,
    required String clientSecret,
    required String username,
    required String password,
    required String gstin,
    required String publicKeyPem,
    bool isSandbox = true,
  }) async {
    await _secureStorage.write(key: _clientIdKey, value: clientId);
    await _secureStorage.write(key: _clientSecretKey, value: clientSecret);
    await _secureStorage.write(key: _usernameKey, value: username);
    await _secureStorage.write(key: _passwordKey, value: password);
    await _secureStorage.write(key: _gstinKey, value: gstin);
    await _secureStorage.write(key: _publicKeyPemKey, value: publicKeyPem);
    await _secureStorage.write(
      key: _environmentKey,
      value: isSandbox ? 'sandbox' : 'production',
    );
  }

  /// Check if NIC IRP is configured
  static Future<bool> isConfigured() async {
    final clientId = await _secureStorage.read(key: _clientIdKey);
    final gstin = await _secureStorage.read(key: _gstinKey);
    return clientId != null &&
        clientId.isNotEmpty &&
        gstin != null &&
        gstin.isNotEmpty;
  }

  /// Clear all NIC IRP configuration
  static Future<void> clearConfiguration() async {
    await _secureStorage.delete(key: _clientIdKey);
    await _secureStorage.delete(key: _clientSecretKey);
    await _secureStorage.delete(key: _usernameKey);
    await _secureStorage.delete(key: _passwordKey);
    await _secureStorage.delete(key: _gstinKey);
    await _secureStorage.delete(key: _publicKeyPemKey);
    await _secureStorage.delete(key: _environmentKey);
  }

  // Instance properties
  final String clientId;
  final String clientSecret;
  final String username;
  final String password;
  final String gstin;
  final String publicKeyPem;
  final bool isSandbox;

  NicIrpConfig._({
    required this.clientId,
    required this.clientSecret,
    required this.username,
    required this.password,
    required this.gstin,
    required this.publicKeyPem,
    required this.isSandbox,
  });

  /// Get base URL based on environment
  String get baseUrl => isSandbox ? sandboxBaseUrl : productionBaseUrl;

  /// Get auth endpoint
  String get authUrl => '$baseUrl/auth';

  /// Get IRN generation endpoint
  String get generateIrnUrl => '$baseUrl/invoice/irn';

  /// Get IRN cancellation endpoint
  String get cancelIrnUrl => '$baseUrl/invoice/cancel';

  /// Get IRN validation endpoint
  String get validateIrnUrl => '$baseUrl/invoice/irn/get';

  /// Encrypt password using RSA with NIC public key
  ///
  /// As per NIC specification, the password must be encrypted with
  /// the RSA public key provided by NIC.
  String encryptPassword() {
    try {
      final publicKey = _parsePublicKey(publicKeyPem);
      final encrypter = OAEPEncoding(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

      final passwordBytes = utf8.encode(password);
      final encryptedBytes = encrypter.process(
        Uint8List.fromList(passwordBytes),
      );

      return base64Encode(encryptedBytes);
    } catch (e) {
      debugPrint('NicIrpConfig: Error encrypting password: $e');
      rethrow;
    }
  }

  /// Generate and encrypt AppKey
  ///
  /// As per NIC specification:
  /// 1. Generate a random 32-byte key
  /// 2. Encrypt it with NIC's RSA public key
  /// 3. Store the original key for SEK decryption later
  (String encryptedAppKey, Uint8List originalAppKey) generateAppKey() {
    try {
      // Generate 32 bytes of cryptographically secure random data
      final random = Random.secure();
      final appKeyBytes = Uint8List.fromList(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );

      // Encrypt with RSA public key
      final publicKey = _parsePublicKey(publicKeyPem);
      final encrypter = OAEPEncoding(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

      final encryptedBytes = encrypter.process(appKeyBytes);
      final encryptedAppKey = base64Encode(encryptedBytes);

      return (encryptedAppKey, appKeyBytes);
    } catch (e) {
      debugPrint('NicIrpConfig: Error generating AppKey: $e');
      rethrow;
    }
  }

  /// Parse PEM-encoded RSA public key
  RSAPublicKey _parsePublicKey(String pem) {
    // Remove PEM headers and decode base64
    final lines = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();

    final keyBytes = base64Decode(lines);

    // Parse ASN.1 structure
    // This is a simplified parser - for production, use a proper ASN.1 library
    final asn1Parser = ASN1Parser(keyBytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    // Skip algorithm identifier, get key data
    final keyBitString = topLevelSeq.elements![1] as ASN1BitString;
    final keyParser = ASN1Parser(keyBitString.stringValues as Uint8List);
    final keySeq = keyParser.nextObject() as ASN1Sequence;

    final modulus = (keySeq.elements![0] as ASN1Integer).integer!;
    final exponent = (keySeq.elements![1] as ASN1Integer).integer!;

    return RSAPublicKey(modulus, exponent);
  }
}

/// Validate GSTIN format for NIC configuration
bool isValidGstinForNic(String gstin) {
  // GSTIN must be exactly 15 characters
  if (gstin.length != 15) return false;

  // Basic format check
  final pattern = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
  );
  return pattern.hasMatch(gstin);
}
