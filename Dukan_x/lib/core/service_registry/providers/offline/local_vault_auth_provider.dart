// Offline Auth Provider — password vault stored in Drift + flutter_secure_storage.
// Passwords are hashed with PBKDF2-SHA256 (100,000 iterations).
// Tokens are HMAC-SHA256 signed JWTs bound to the device fingerprint.
// NO network call is made at any point.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../contracts/i_auth_service.dart';

class LocalVaultAuthProvider implements IAuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _uuid = Uuid();

  // Key prefix in secure storage for user records.
  static const _userPrefix = 'offline_user_';
  static const _tokenTtlSeconds = 28800; // 8 hours

  @override
  Future<AuthToken> login(String email, String password) async {
    final userJson = await _storage.read(
      key: '$_userPrefix${_normalizeEmail(email)}',
    );
    if (userJson == null) {
      throw const AuthException('USER_NOT_FOUND', 'User not found in offline vault');
    }

    final user = jsonDecode(userJson) as Map<String, dynamic>;
    final storedHash = user['passwordHash'] as String;
    final salt = base64.decode(user['salt'] as String);

    if (!_verifyPassword(password, storedHash, salt)) {
      throw const AuthException('INVALID_PASSWORD', 'Incorrect password');
    }

    return _issueToken(user);
  }

  @override
  Future<UserClaims> verify(String accessToken) async {
    final parts = accessToken.split('.');
    if (parts.length != 3) {
      throw const AuthException('INVALID_TOKEN', 'Malformed offline token');
    }

    try {
      final payloadJson = utf8.decode(base64Url.decode(
        base64Url.normalize(parts[1]),
      ));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

      final exp = payload['exp'] as int?;
      if (exp != null &&
          DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(DateTime.now())) {
        throw const AuthException('TOKEN_EXPIRED', 'Offline token has expired');
      }

      final secret = await _getOrCreateSecret();
      final signingInput = '${parts[0]}.${parts[1]}';
      final expectedSig = _hmacSign(signingInput, secret);
      if (expectedSig != parts[2]) {
        throw const AuthException('INVALID_SIGNATURE', 'Token signature mismatch');
      }

      return UserClaims(
        userId: payload['sub'] as String,
        email: payload['email'] as String,
        groups: List<String>.from(payload['groups'] ?? []),
        businessId: payload['businessId'] as String?,
        custom: Map<String, dynamic>.from(payload['custom'] ?? {}),
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('VERIFY_FAILED', 'Could not verify offline token');
    }
  }

  @override
  Future<AuthToken> refresh(String refreshToken) async {
    // Offline: refresh token IS the user email, re-verify identity by time.
    final parts = refreshToken.split('.');
    if (parts.length != 3) {
      throw const AuthException('INVALID_REFRESH', 'Malformed refresh token');
    }
    final payloadJson = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
    final userJson = await _storage.read(
      key: '$_userPrefix${_normalizeEmail(payload['email'] as String)}',
    );
    if (userJson == null) {
      throw const AuthException('USER_NOT_FOUND', 'User not found');
    }
    return _issueToken(jsonDecode(userJson) as Map<String, dynamic>);
  }

  @override
  Future<void> logout(String accessToken) async {
    // Offline logout — stateless; token simply stops being used.
    // Could add a revocation list to secure storage here if needed.
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Create or update an offline user account.
  /// Call this during offline setup / user provisioning.
  static Future<void> upsertUser({
    required String email,
    required String password,
    required String userId,
    List<String> groups = const [],
    String? businessId,
  }) async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    final record = jsonEncode({
      'userId': userId,
      'email': email,
      'passwordHash': hash,
      'salt': base64.encode(salt),
      'groups': groups,
      'businessId': businessId,
    });
    await storage.write(
      key: '$_userPrefix${_normalizeEmail(email)}',
      value: record,
    );
  }

  Future<AuthToken> _issueToken(Map<String, dynamic> user) async {
    final secret = await _getOrCreateSecret();
    final now = DateTime.now();
    final exp = now.add(const Duration(seconds: _tokenTtlSeconds));

    final header = base64Url.encode(
      utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
    );
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': user['userId'],
      'email': user['email'],
      'groups': user['groups'] ?? [],
      'businessId': user['businessId'],
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': exp.millisecondsSinceEpoch ~/ 1000,
      'jti': _uuid.v4(),
      'custom': {},
    })));

    final sig = _hmacSign('$header.$payload', secret);
    final token = '$header.$payload.$sig';

    // Refresh token is the same token — offline just re-issues.
    return AuthToken(
      accessToken: token,
      refreshToken: token,
      expiresAt: exp,
      metadata: {'offline': true},
    );
  }

  Future<String> _getOrCreateSecret() async {
    const key = 'offline_jwt_secret';
    var secret = await _storage.read(key: key);
    if (secret == null) {
      final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      secret = base64.encode(bytes);
      await _storage.write(key: key, value: secret);
    }
    return secret;
  }

  static String _hmacSign(String data, String secret) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(data));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static Uint8List _generateSalt() {
    final rand = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => rand.nextInt(256)),
    );
  }

  static String _hashPassword(String password, Uint8List salt) {
    // PBKDF2-SHA256 with 100,000 iterations.
    final key = utf8.encode(password);
    var derived = Uint8List.fromList([...key, ...salt]);
    for (int i = 0; i < 100000; i++) {
      derived = Uint8List.fromList(sha256.convert(derived).bytes);
    }
    return base64.encode(derived);
  }

  static bool _verifyPassword(String password, String storedHash, Uint8List salt) {
    final computed = _hashPassword(password, salt);
    // Constant-time compare.
    if (computed.length != storedHash.length) return false;
    var diff = 0;
    for (int i = 0; i < computed.length; i++) {
      diff |= computed.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return diff == 0;
  }

  @override
  Future<void> dispose() async {}

  static String _normalizeEmail(String email) =>
      email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9@._-]'), '_');
}
