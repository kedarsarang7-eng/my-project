import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-CBC encryption helper using `encrypt` package and `flutter_secure_storage`.
///
/// SECURITY: Uses cryptographically secure random key AND IV generation.
/// IV is prepended to ciphertext and extracted during decryption.
class EncryptionService {
  static const _keyStorage = 'app_aes_key_v2'; // Versioned key storage
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<Uint8List> _getKey() async {
    final existing = await _secure.read(key: _keyStorage);
    if (existing != null) {
      return base64Url.decode(existing);
    }

    // Generate 32 bytes using cryptographically secure random
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final keyEnc = base64Url.encode(keyBytes);
    await _secure.write(key: _keyStorage, value: keyEnc);
    return Uint8List.fromList(keyBytes);
  }

  /// Generate a random 16-byte IV for each encryption operation.
  encrypt_pkg.IV _generateIV() {
    final random = Random.secure();
    final ivBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return encrypt_pkg.IV(Uint8List.fromList(ivBytes));
  }

  /// Encrypt plaintext. Returns base64 string of [IV (16 bytes) || ciphertext].
  Future<String> encryptUtf8(String plain) async {
    final key = await _getKey();
    final keyObj = encrypt_pkg.Key(key);
    final iv = _generateIV();
    final encr = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(keyObj, mode: encrypt_pkg.AESMode.cbc),
    );
    final cipher = encr.encrypt(plain, iv: iv);

    // Prepend IV to ciphertext so we can extract it during decryption
    final combined = Uint8List(16 + cipher.bytes.length);
    combined.setAll(0, iv.bytes);
    combined.setAll(16, cipher.bytes);
    return base64.encode(combined);
  }

  /// Decrypt ciphertext. Expects base64 of [IV (16 bytes) || ciphertext].
  /// Falls back to legacy zero-IV decryption for data encrypted before this fix.
  Future<String> decryptToUtf8(String cipherBase64) async {
    final key = await _getKey();
    final keyObj = encrypt_pkg.Key(key);

    final combined = base64.decode(cipherBase64);

    if (combined.length <= 16) {
      // Too short — attempt legacy zero-IV decryption
      return _legacyDecrypt(keyObj, cipherBase64);
    }

    // Extract IV (first 16 bytes) and ciphertext (remainder)
    final iv = encrypt_pkg.IV(Uint8List.fromList(combined.sublist(0, 16)));
    final cipherBytes = combined.sublist(16);

    try {
      final encr = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(keyObj, mode: encrypt_pkg.AESMode.cbc),
      );
      return encr.decrypt(encrypt_pkg.Encrypted(Uint8List.fromList(cipherBytes)), iv: iv);
    } catch (_) {
      // If new format fails, try legacy zero-IV format for backward compatibility
      return _legacyDecrypt(keyObj, cipherBase64);
    }
  }

  /// Legacy decryption with zero IV — for data encrypted before S-01 fix.
  String _legacyDecrypt(encrypt_pkg.Key keyObj, String cipherBase64) {
    final iv = encrypt_pkg.IV(Uint8List(16)); // All zeros — legacy
    final encr = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(keyObj, mode: encrypt_pkg.AESMode.cbc),
    );
    return encr.decrypt64(cipherBase64, iv: iv);
  }

  Future<String> encryptMap(Map<String, dynamic> m) async {
    final js = jsonEncode(m);
    return encryptUtf8(js);
  }

  Future<Map<String, dynamic>> decryptToMap(String cipherBase64) async {
    final js = await decryptToUtf8(cipherBase64);
    return jsonDecode(js) as Map<String, dynamic>;
  }
}
