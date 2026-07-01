// ============================================================================
// Firebase Auth Compatibility Layer — Routes to Cognito via API Gateway
// ============================================================================
// This file provides the same classes and types that `package:firebase_auth`
// exposes, but routes all operations through the CognitoAuthProvider / API
// client. Services that were written against `FirebaseAuth.instance` can
// switch their import to this file and continue working unmodified.
//
// FIX (H-03): Eliminates direct Firebase Auth SDK dependency while
// maintaining backward compatibility with legacy auth screens and services.
// ============================================================================

import 'dart:async';
import 'dart:developer' as developer;
import '../api/api_client.dart';
import '../di/service_locator.dart';
import '../services/token_manager.dart';

ApiClient get _api => sl<ApiClient>();
TokenManager get _tokens => sl<TokenManager>();

// ============================================================================
// Stub Types — Mirrors firebase_auth API surface
// ============================================================================

class AuthCredential {
  final String providerId;
  final String? token;
  AuthCredential({required this.providerId, this.token});
}

class PhoneAuthCredential extends AuthCredential {
  final String verificationId;
  final String smsCode;
  PhoneAuthCredential({required this.verificationId, required this.smsCode})
    : super(providerId: 'phone');
}

class EmailAuthCredential extends AuthCredential {
  final String email;
  final String password;
  EmailAuthCredential({required this.email, required this.password})
    : super(providerId: 'password');
}

class GoogleAuthProvider extends AuthCredential {
  GoogleAuthProvider() : super(providerId: 'google');

  void setCustomParameters(Map<String, String> customParameters) {}

  static AuthCredential credential({String? accessToken, String? idToken}) {
    return AuthCredential(providerId: 'google', token: idToken ?? accessToken);
  }
}

class FirebaseAuthException implements Exception {
  final String code;
  final String? message;
  FirebaseAuthException({required this.code, this.message});

  @override
  String toString() => 'FirebaseAuthException($code): $message';
}

class User {
  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoURL;
  final bool emailVerified;

  User({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
    this.emailVerified = false,
  });

  Future<String?> getIdToken([bool forceRefresh = false]) async {
    try {
      if (forceRefresh) {
        final refreshed = await _tokens.refreshTokens();
        if (refreshed != null) {
          return refreshed.idToken;
        }
      }
      return await _tokens.getIdToken();
    } catch (e) {
      developer.log('getIdToken error: $e', name: 'AuthCompat');
      return null;
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    await _api.patch('/auth/me', body: {'displayName': displayName});
  }

  Future<void> updatePhotoURL(String photoURL) async {
    await _api.patch('/auth/me', body: {'photoURL': photoURL});
  }

  Future<void> reload() async {
    /* No-op in Cognito compat */
  }
  Future<void> delete() async {
    await _api.delete('/auth/me');
    await _tokens.clearTokens();
  }
}

class UserCredential {
  final User? user;
  final AuthCredential? credential;
  UserCredential({this.user, this.credential});
}

class AdditionalUserInfo {
  final bool? isNewUser;
  AdditionalUserInfo({this.isNewUser});
}

// ============================================================================
// PhoneAuthProvider — Stub
// ============================================================================

class PhoneAuthProvider {
  static PhoneAuthCredential credential({
    required String verificationId,
    required String smsCode,
  }) {
    return PhoneAuthCredential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }
}

// ============================================================================
// FirebaseAuth — API-backed singleton
// ============================================================================

class FirebaseAuth {
  static final FirebaseAuth instance = FirebaseAuth._();
  FirebaseAuth._() {
    restoreSession();
  }

  User? _currentUser;
  final StreamController<User?> _authStateController =
      StreamController<User?>.broadcast();

  /// The currently signed-in user, or null.
  User? get currentUser => _currentUser;

  /// Stream of auth state changes.
  Stream<User?> authStateChanges() {
    final controller = StreamController<User?>();
    controller.add(_currentUser);
    final subscription = _authStateController.stream.listen(
      (user) => controller.add(user),
      onError: (err) => controller.addError(err),
      onDone: () => controller.close(),
    );
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  Stream<User?> idTokenChanges() => authStateChanges();

  /// Sign in with email and password via Cognito.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _api.post(
        '/auth/login',
        body: {'email': email, 'password': password},
      );

      if (!res.isSuccess || res.data == null) {
        throw FirebaseAuthException(
          code: res.code ?? 'wrong-password',
          message: res.error ?? 'Login failed',
        );
      }

      final data = res.data as Map<String, dynamic>;
      await _tokens.saveTokens(
        TokenPair(
          idToken: data['idToken'] ?? data['id_token'] ?? data['accessToken'] ?? data['access_token'] ?? '',
          accessToken: data['accessToken'] ?? data['access_token'] ?? '',
          tokenType: 'Bearer',
          expiresInSeconds: data['expiresIn'] as int? ?? 3600,
          issuedAt: DateTime.now(),
        ),
        refreshToken: data['refreshToken'] ?? data['refresh_token'],
      );

      _currentUser = User(
        uid: data['userId'] ?? data['sub'] ?? '',
        email: email,
        displayName: data['displayName'],
      );
      _authStateController.add(_currentUser);

      return UserCredential(user: _currentUser);
    } catch (e) {
      if (e is FirebaseAuthException) rethrow;
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: e.toString(),
      );
    }
  }

  /// Create a new user with email and password via Cognito.
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _api.post(
        '/auth/register',
        body: {'email': email, 'password': password},
      );

      if (!res.isSuccess || res.data == null) {
        throw FirebaseAuthException(
          code: res.code ?? 'email-already-in-use',
          message: res.error ?? 'Registration failed',
        );
      }

      final data = res.data as Map<String, dynamic>;
      await _tokens.saveTokens(
        TokenPair(
          idToken: data['idToken'] ?? data['id_token'] ?? data['accessToken'] ?? data['access_token'] ?? '',
          accessToken: data['accessToken'] ?? data['access_token'] ?? '',
          tokenType: 'Bearer',
          expiresInSeconds: data['expiresIn'] as int? ?? 3600,
          issuedAt: DateTime.now(),
        ),
        refreshToken: data['refreshToken'] ?? data['refresh_token'],
      );

      _currentUser = User(
        uid: data['userId'] ?? data['sub'] ?? '',
        email: email,
      );
      _authStateController.add(_currentUser);

      return UserCredential(user: _currentUser);
    } catch (e) {
      if (e is FirebaseAuthException) rethrow;
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: e.toString(),
      );
    }
  }

  /// Sign in with a credential (used by Google Sign-In, OTP, etc.)
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    try {
      final res = await _api.post(
        '/auth/login/credential',
        body: {'providerId': credential.providerId, 'token': credential.token},
      );

      if (!res.isSuccess || res.data == null) {
        throw FirebaseAuthException(
          code: 'credential-login-failed',
          message: res.error ?? 'Credential login failed',
        );
      }

      final data = res.data as Map<String, dynamic>;
      await _tokens.saveTokens(
        TokenPair(
          idToken: data['idToken'] ?? data['id_token'] ?? data['accessToken'] ?? data['access_token'] ?? '',
          accessToken: data['accessToken'] ?? data['access_token'] ?? '',
          tokenType: 'Bearer',
          expiresInSeconds: data['expiresIn'] as int? ?? 3600,
          issuedAt: DateTime.now(),
        ),
        refreshToken: data['refreshToken'] ?? data['refresh_token'],
      );

      _currentUser = User(
        uid: data['userId'] ?? data['sub'] ?? '',
        email: data['email'],
        displayName: data['displayName'],
      );
      _authStateController.add(_currentUser);

      return UserCredential(user: _currentUser);
    } catch (e) {
      if (e is FirebaseAuthException) rethrow;
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: e.toString(),
      );
    }
  }

  /// Sign in with popup (Web-only helper for Cognito compat)
  Future<UserCredential> signInWithPopup(dynamic provider) async {
    throw UnimplementedError('signInWithPopup is not supported in Cognito compat layer.');
  }

  /// OTP phone verification — disabled but stub provided for compatibility
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) codeSent,
    required Function(AuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String) codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
    int? forceResendingToken,
  }) async {
    // OTP disabled — immediately call verificationFailed
    verificationFailed(
      FirebaseAuthException(
        code: 'otp-disabled',
        message:
            'OTP login is disabled. Please use email/password or Google Sign-In.',
      ),
    );
  }

  /// Send password reset email via Cognito
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _api.post('/auth/forgot-password', body: {'email': email});
  }

  /// Sign out — clears tokens and state
  Future<void> signOut() async {
    try {
      final token = await _tokens.getIdToken();
      if (token != null) {
        await _api.post('/auth/logout', body: {'token': token});
      }
    } catch (e) {
      developer.log('signOut API error (ignored): $e', name: 'AuthCompat');
    }
    await _tokens.clearTokens();
    _currentUser = null;
    _authStateController.add(null);
  }

  /// Restore session from stored tokens (call during app startup)
  Future<void> restoreSession() async {
    try {
      final token = await _tokens.getIdToken();
      if (token != null) {
        final res = await _api.get('/auth/me');
        if (res.isSuccess && res.data != null) {
          final data = res.data as Map<String, dynamic>;
          _currentUser = User(
            uid: data['userId'] ?? data['sub'] ?? '',
            email: data['email'],
            displayName: data['displayName'],
            phoneNumber: data['phone'],
          );
          _authStateController.add(_currentUser);
          return;
        }
      }
    } catch (e) {
      developer.log('Session restore failed: $e', name: 'AuthCompat');
    }
    _currentUser = null;
    _authStateController.add(null);
  }
}
