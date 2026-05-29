import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'token_data.dart';

/// Persists tokens exclusively in flutter_secure_storage (AES-256 on Android Keystore).
/// NEVER use SharedPreferences for tokens.
class SecureTokenStore {
  static const _prefix = 'cx_';
  static const _keys = [
    'accessToken',
    'idToken',
    'refreshToken',
    'expiresAt',
    'customerId',
    'phone',
    'email',
    'displayName',
  ];

  final FlutterSecureStorage _storage;

  SecureTokenStore()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            keyCipherAlgorithm:
                KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
            storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
          ),
        );

  Future<void> write(TokenData tokenData) async {
    final map = tokenData.toStorageMap();
    await Future.wait(map.entries.map(
      (e) => _storage.write(key: '$_prefix${e.key}', value: e.value),
    ));
  }

  Future<TokenData?> read() async {
    try {
      final map = <String, String>{};
      for (final key in _keys) {
        final value = await _storage.read(key: '$_prefix$key');
        if (value != null) map[key] = value;
      }
      if (!map.containsKey('accessToken') ||
          !map.containsKey('customerId') ||
          !map.containsKey('phone')) {
        return null;
      }
      return TokenData.fromStorageMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await Future.wait(
      _keys.map((key) => _storage.delete(key: '$_prefix$key')),
    );
  }

  Future<bool> hasTokens() async {
    final token = await _storage.read(key: '${_prefix}accessToken');
    return token != null && token.isNotEmpty;
  }
}
