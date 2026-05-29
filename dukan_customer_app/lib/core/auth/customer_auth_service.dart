import 'dart:convert';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../config/app_config.dart';

class CustomerAuthService {
  final AppConfig _config;
  late final CognitoUserPool _userPool;

  CustomerAuthService(this._config) {
    _userPool = CognitoUserPool(
      _config.cognitoUserPoolId,
      _config.cognitoClientId,
    );
  }

  /// Step 1: Send OTP to phone number.
  /// Cognito custom auth flow — triggers the "CUSTOM_CHALLENGE" Lambda.
  Future<void> sendOtp(String phone) async {
    final normalizedPhone = _normalizePhone(phone);
    final user = CognitoUser(normalizedPhone, _userPool);
    await user.initiateAuth(
      AuthenticationDetails(
        username: normalizedPhone,
        authParameters: [AttributeArg(name: 'CHALLENGE_NAME', value: 'CUSTOM_CHALLENGE')],
      ),
    );
  }

  /// Step 2: Submit OTP — returns TokenData on success.
  Future<TokenData> signInWithOtp({
    required String phone,
    required String otp,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    final user = CognitoUser(normalizedPhone, _userPool);

    final authDetails = AuthenticationDetails(
      username: normalizedPhone,
      authParameters: [AttributeArg(name: 'CHALLENGE_NAME', value: 'CUSTOM_CHALLENGE')],
    );

    CognitoUserSession? session;
    try {
      session = await user.initiateAuth(authDetails);

      session ??= await user.sendCustomChallengeAnswer(otp);
    } on CognitoUserCustomChallengeException {
      session = await user.sendCustomChallengeAnswer(otp);
    }

    if (session == null || !session.isValid()) {
      throw Exception('Authentication failed');
    }

    final accessToken = session.getAccessToken().getJwtToken()!;
    final idToken = session.getIdToken().getJwtToken()!;
    final refreshToken = session.getRefreshToken()!.getToken()!;

    final payload = JwtUtils.decodePayload(idToken);
    final customerId = payload?['custom:customerId'] as String? ??
        payload?['sub'] as String? ??
        '';

    final expiry = JwtUtils.expiryFromToken(accessToken) ??
        DateTime.now().add(const Duration(hours: 1));

    return TokenData(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: refreshToken,
      expiresAt: expiry,
      customerId: customerId,
      phone: normalizedPhone,
      email: payload?['email'] as String?,
      displayName: payload?['name'] as String?,
    );
  }

  /// Refreshes tokens using the stored refresh token.
  /// Returns new TokenData on success, null on failure.
  Future<TokenData?> refreshTokens(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('${_config.apiBaseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );

      if (response.statusCode != 200) return null;

      final body = json.decode(response.body) as Map<String, dynamic>;
      final tokens = body['tokens'] as Map<String, dynamic>;
      final newAccessToken = tokens['accessToken'] as String;
      final newIdToken = tokens['idToken'] as String? ?? newAccessToken;

      final payload = JwtUtils.decodePayload(newIdToken);
      final customerId = payload?['custom:customerId'] as String? ??
          payload?['sub'] as String? ??
          '';

      final expiry = JwtUtils.expiryFromToken(newAccessToken) ??
          DateTime.now().add(const Duration(hours: 1));

      return TokenData(
        accessToken: newAccessToken,
        idToken: newIdToken,
        refreshToken: refreshToken,
        expiresAt: expiry,
        customerId: customerId,
        phone: payload?['phone_number'] as String? ?? '',
        email: payload?['email'] as String?,
        displayName: payload?['name'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut({required String accessToken}) async {
    try {
      await http.post(
        Uri.parse('${_config.apiBaseUrl}/auth/logout'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );
    } catch (_) {
      // Ignore network errors on sign-out — local token is cleared regardless
    }
  }

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) return '+$digits';
    if (digits.length == 10) return '+91$digits';
    if (phone.startsWith('+')) return phone;
    return '+$digits';
  }
}

final customerAuthServiceProvider = Provider<CustomerAuthService>((ref) {
  return CustomerAuthService(ref.read(appConfigProvider));
});
