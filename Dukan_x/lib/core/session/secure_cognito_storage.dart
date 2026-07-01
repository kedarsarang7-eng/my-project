import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// A secure storage implementation for Amazon Cognito using flutter_secure_storage.
/// Valid for Desktop, Web, and Mobile per user requirement.
class SecureCognitoStorage implements CognitoStorage {
  final FlutterSecureStorage _storage;

  SecureCognitoStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<dynamic> setItem(String key, dynamic value) async {
    final stringValue = value is String ? value : jsonEncode(value);
    await _storage.write(key: key, value: stringValue);
    return stringValue;
  }

  @override
  Future<dynamic> getItem(String key) async {
    final value = await _storage.read(key: key);
    if (value == null) return null;
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  @override
  Future<dynamic> removeItem(String key) async {
    final item = await getItem(key);
    if (item != null) {
      await _storage.delete(key: key);
      return item;
    }
    return null;
  }

  @override
  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
