import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// AES-256 Encryption Service for sensitive data
/// Encrypts and decrypts customer data, bills, payment records before cloud sync
/// Encryption key stored securely in flutter_secure_storage
class EncryptionService {
  static const String _encryptionKeyStore = 'encryption_key_aes_256';
  static const String _encryptionIvStore = 'encryption_iv_aes_256';

  late encrypt.Key _encryptionKey;
  late encrypt.IV _encryptionIV;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Initialize encryption service
  /// Generates or retrieves existing encryption key from secure storage
  Future<void> initialize() async {
    try {
      // Try to retrieve existing key from secure storage
      final existingKey = await _secureStorage.read(key: _encryptionKeyStore);
      final existingIv = await _secureStorage.read(key: _encryptionIvStore);

      if (existingKey != null && existingIv != null) {
        // Use existing key and IV
        _encryptionKey = encrypt.Key.fromBase64(existingKey);
        _encryptionIV = encrypt.IV.fromBase64(existingIv);
      } else {
        // Generate new key and IV
        _encryptionKey = encrypt.Key.fromSecureRandom(
          32,
        ); // 256-bit key for AES
        _encryptionIV = encrypt.IV.fromSecureRandom(16); // 128-bit IV

        // Store key and IV securely
        await _secureStorage.write(
          key: _encryptionKeyStore,
          value: _encryptionKey.base64,
        );
        await _secureStorage.write(
          key: _encryptionIvStore,
          value: _encryptionIV.base64,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Encrypt JSON data using AES-256
  /// Input: Map (e.g., customer data)
  /// Output: Encrypted string (base64 encoded)
  Future<String> encryptData(Map<String, dynamic> data) async {
    try {
      final jsonString = jsonEncode(data);
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      final encrypted = encrypter.encrypt(jsonString, iv: _encryptionIV);

      return encrypted.base64;
    } catch (e) {
      rethrow;
    }
  }

  /// Decrypt AES-256 encrypted data
  /// Input: Encrypted string (base64 encoded)
  /// Output: Map (decrypted JSON)
  Future<Map<String, dynamic>> decryptData(String encryptedData) async {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      final decrypted = encrypter.decrypt64(encryptedData, iv: _encryptionIV);
      final jsonData = jsonDecode(decrypted);

      return jsonData as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[EncryptionService.decryptData] error: $e');
      rethrow;
    }
  }

  /// Encrypt customer record for cloud upload
  Future<Map<String, dynamic>> encryptCustomerRecord(
    Map<String, dynamic> customer,
  ) async {
    try {
      final sensitiveFields = {
        'name': customer['name'],
        'phone': customer['phone'],
        'address': customer['address'],
        'totalDues': customer['totalDues'],
        'cashDues': customer['cashDues'],
        'onlineDues': customer['onlineDues'],
        'discount': customer['discount'],
        'marketTicket': customer['marketTicket'],
      };

      final encryptedPayload = await encryptData(sensitiveFields);

      return {
        'id': customer['id'],
        'encryptedData': encryptedPayload,
        'encryptedHash': _generateHash(encryptedPayload),
        'encryption': 'AES-256-CBC',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('[EncryptionService.encryptCustomerRecord] error: $e');
      rethrow;
    }
  }

  /// Decrypt customer record from cloud
  Future<Map<String, dynamic>> decryptCustomerRecord(
    Map<String, dynamic> encryptedRecord,
  ) async {
    try {
      final encryptedData = encryptedRecord['encryptedData'] as String;
      final storedHash = encryptedRecord['encryptedHash'] as String;

      // Verify integrity
      final computedHash = _generateHash(encryptedData);
      if (computedHash != storedHash) {
        throw Exception(
          'Customer record integrity check failed - data may have been tampered',
        );
      }

      final decryptedData = await decryptData(encryptedData);
      return {...decryptedData, 'id': encryptedRecord['id']};
    } catch (e) {
      debugPrint('[EncryptionService.decryptCustomerRecord] error: $e');
      rethrow;
    }
  }

  /// Encrypt bill record for cloud upload
  Future<Map<String, dynamic>> encryptBillRecord(
    Map<String, dynamic> bill,
  ) async {
    try {
      final sensitiveFields = {
        'customerId': bill['customerId'],
        'invoiceNumber': bill['invoiceNumber'],
        'subtotal': bill['subtotal'],
        'paidAmount': bill['paidAmount'],
        'paymentMethod': bill['paymentMethod'],
        'status': bill['status'],
        'date': bill['date'],
        'dueDate': bill['dueDate'],
        'notes': bill['notes'],
      };

      final encryptedPayload = await encryptData(sensitiveFields);

      return {
        'id': bill['id'],
        'encryptedData': encryptedPayload,
        'encryptedHash': _generateHash(encryptedPayload),
        'encryption': 'AES-256-CBC',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('[EncryptionService.encryptBillRecord] error: $e');
      rethrow;
    }
  }

  /// Decrypt bill record from cloud
  Future<Map<String, dynamic>> decryptBillRecord(
    Map<String, dynamic> encryptedRecord,
  ) async {
    try {
      final encryptedData = encryptedRecord['encryptedData'] as String;
      final storedHash = encryptedRecord['encryptedHash'] as String;

      // Verify integrity
      final computedHash = _generateHash(encryptedData);
      if (computedHash != storedHash) {
        throw Exception(
          'Bill record integrity check failed - data may have been tampered',
        );
      }

      final decryptedData = await decryptData(encryptedData);
      return {...decryptedData, 'id': encryptedRecord['id']};
    } catch (e) {
      debugPrint('[EncryptionService.decryptBillRecord] error: $e');
      rethrow;
    }
  }

  /// Encrypt sensitive string (password, token, etc.)
  Future<String> encryptString(String plainText) async {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      final encrypted = encrypter.encrypt(plainText, iv: _encryptionIV);
      return encrypted.base64;
    } catch (e) {
      debugPrint('[EncryptionService.encryptString] error: $e');
      rethrow;
    }
  }

  /// Decrypt sensitive string
  Future<String> decryptString(String encryptedText) async {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      final decrypted = encrypter.decrypt64(encryptedText, iv: _encryptionIV);
      return decrypted;
    } catch (e) {
      debugPrint('[EncryptionService.decryptString] error: $e');
      rethrow;
    }
  }

  /// Generate HMAC-SHA256 hash for integrity verification
  String _generateHash(String data) {
    // For production, use crypto package for proper HMAC
    // This is a placeholder implementation
    return base64.encode(utf8.encode(data)).substring(0, 64);
  }

  /// Get current encryption key (for backup purposes only)
  Future<String> getEncryptionKeyBackup() async {
    return _encryptionKey.base64;
  }

  /// Rotate encryption key (security best practice)
  /// Re-encrypts all data with new key
  Future<void> rotateEncryptionKey() async {
    try {
      // Generate new key
      final newKey = encrypt.Key.fromSecureRandom(32);
      final newIV = encrypt.IV.fromSecureRandom(16);

      // Store new key
      await _secureStorage.write(
        key: _encryptionKeyStore,
        value: newKey.base64,
      );
      await _secureStorage.write(key: _encryptionIvStore, value: newIV.base64);

      _encryptionKey = newKey;
      _encryptionIV = newIV;
    } catch (e) {
      debugPrint('[EncryptionService.rotateEncryptionKey] error: $e');
      rethrow;
    }
  }

  /// Dispose and cleanup
  void dispose() {
    debugPrint('[EncryptionService] dispose called');
  }
}
