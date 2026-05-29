import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cognito_auth_service.g.dart';

class AuthConfig {
  // Supplied at build time via --dart-define. No defaults — missing values
  // cause Cognito to fail fast rather than silently authenticating nowhere.
  static const String userPoolId = String.fromEnvironment('COGNITO_USER_POOL_ID');
  static const String clientId = String.fromEnvironment('COGNITO_RESTRO_CLIENT_ID');
}

class CognitoAuthServicePWA {
  final CognitoUserPool _userPool;
  CognitoUser? _cognitoUser;
  CognitoUserSession? _session;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  CognitoAuthServicePWA()
      : _userPool = CognitoUserPool(AuthConfig.userPoolId, AuthConfig.clientId);

  /// Authenticate user via username and password
  Future<CognitoUserSession?> login(String username, String password) async {
    _cognitoUser = CognitoUser(username, _userPool);
    final authDetails = AuthenticationDetails(
      username: username,
      password: password,
    );

    try {
      _session = await _cognitoUser!.authenticateUser(authDetails);
      await _saveTokens();
      return _session;
    } on CognitoUserNewPasswordRequiredException {
      throw Exception('New password required');
    } on CognitoClientException catch (e) {
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      throw Exception('Unknown login error: $e');
    }
  }

  /// Register a new user
  Future<bool> signUp(String username, String password, String email) async {
    final userAttributes = [AttributeArg(name: 'email', value: email)];

    try {
      final result = await _userPool.signUp(
        username,
        password,
        userAttributes: userAttributes,
      );
      return result.userConfirmed ?? false;
    } on CognitoClientException catch (e) {
      throw Exception('Signup failed: ${e.message}');
    }
  }

  /// Confirm user registration via OTP
  Future<bool> confirmRegistration(
    String username,
    String confirmationCode,
  ) async {
    final cognitoUser = CognitoUser(username, _userPool);
    try {
      return await cognitoUser.confirmRegistration(confirmationCode);
    } on CognitoClientException catch (e) {
      throw Exception('Confirmation failed: ${e.message}');
    }
  }

  /// Resend confirmation code
  Future<void> resendConfirmationCode(String username) async {
    final cognitoUser = CognitoUser(username, _userPool);
    try {
      await cognitoUser.resendConfirmationCode();
    } on CognitoClientException catch (e) {
      throw Exception('Resend code failed: ${e.message}');
    }
  }

  /// Forgot password
  Future<void> forgotPassword(String username) async {
    final cognitoUser = CognitoUser(username, _userPool);
    try {
      await cognitoUser.forgotPassword();
    } on CognitoClientException catch (e) {
      throw Exception('Forgot password failed: ${e.message}');
    }
  }

  /// Confirm forgot password
  Future<bool> confirmForgotPassword(
    String username,
    String confirmationCode,
    String newPassword,
  ) async {
    final cognitoUser = CognitoUser(username, _userPool);
    try {
      return await cognitoUser.confirmPassword(confirmationCode, newPassword);
    } on CognitoClientException catch (e) {
      throw Exception('Password reset failed: ${e.message}');
    }
  }

  /// Logout
  Future<void> logout() async {
    if (_cognitoUser != null) {
      await _cognitoUser!.signOut();
      _cognitoUser = null;
    }
    _session = null;
    await _clearTokens();
  }

  /// Check if a valid session exists
  Future<bool> isAuthenticated() async {
    try {
      final idToken = await _storage.read(key: 'idToken');
      if (idToken == null) return false;

      // In a real app, you would validate the JWT signature here or locally
      // For now, we rely on the existence of the token as a basic check

      // Attempt to retrieve user from pool
      _cognitoUser = await _userPool.getCurrentUser();
      if (_cognitoUser == null) return false;

      _session = await _cognitoUser!.getSession();
      return _session?.isValid() ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveTokens() async {
    if (_session != null) {
      await _storage.write(
        key: 'accessToken',
        value: _session!.getAccessToken().getJwtToken(),
      );
      await _storage.write(
        key: 'idToken',
        value: _session!.getIdToken().getJwtToken(),
      );
      await _storage.write(
        key: 'refreshToken',
        value: _session!.getRefreshToken()?.getToken(),
      );
    }
  }

  Future<void> _clearTokens() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'idToken');
    await _storage.delete(key: 'refreshToken');
  }
}

@riverpod
CognitoAuthServicePWA authService(AuthServiceRef ref) {
  return CognitoAuthServicePWA();
}
