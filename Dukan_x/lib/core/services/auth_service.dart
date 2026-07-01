import 'dart:async';
import 'dart:developer' as developer;

import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/service_locator.dart';
// Note: This relies on the new auth_types.dart (previously firebase_auth_mock.dart)
import '../../../core/mocks/firebase_auth_mock.dart';
import '../../../core/services/notification_controller.dart';
import '../../../core/session/session_manager.dart';

import '../../features/auth/services/google_signin_service.dart';
import 'session_service.dart' as legacy;
import 'token_manager.dart';

/// AuthService fully migrated to AWS Cognito + API Gateway.
/// Firebase Auth and Firestore CRUD operations have been eliminated.
class AuthService {
  // Session keys
  static const String _sessionKeyUid = 'session_uid';
  static const String _sessionKeyRole = 'session_role';
  static const String _sessionKeyTimestamp = 'session_timestamp';
  static const String _sessionKeyTenantId = 'session_tenant_id';
  static const String _legacySessionKeyShopId = 'session_shop_id';

  /// Sign up with synthetic email derived from phone.
  Future<UserCredential> signUpWithEmail({
    required String name,
    required String phone,
    required String password,
    required String role,
    String? tenantId,
  }) async {
    final email = '$phone@dukanx.local';
    developer.log('signUpWithEmail email=$email role=$role tenantId=$tenantId');

    final userPool = sl<CognitoUserPool>();

    final userAttributes = [
      AttributeArg(name: 'email', value: email),
      AttributeArg(name: 'name', value: name),
      AttributeArg(name: 'custom:role', value: role),
      AttributeArg(
        name: 'custom:tenant_id',
        value: tenantId ?? 'default_tenant',
      ),
      if (phone.isNotEmpty)
        AttributeArg(
          name: 'phone_number',
          value: phone.startsWith('+') ? phone : '+91$phone',
        ),
    ];

    CognitoUserPoolData result;
    try {
      result = await userPool.signUp(
        email,
        password,
        userAttributes: userAttributes,
      );
    } catch (e) {
      developer.log('Cognito SignUp Error: $e');
      throw FirebaseAuthException(code: 'signup-error', message: e.toString());
    }

    final uid = result.userSub;
    final userCredential = UserCredential(
      User(
        uid: uid ?? email,
        email: email,
        displayName: name,
        phoneNumber: phone,
      ),
    );

    if (uid != null) {
      // Create user record in AWS Backend via API Gateway
      final apiClient = sl<ApiClient>();
      await apiClient.post('/api/v1/users/sync', body: {
        'uid': uid,
        'email': email,
        'name': name,
        'phone': phone,
        'role': role,
        'tenantId': tenantId,
      });

      // Save FCM token
      try {
        await sl<NotificationController>().getToken(uid: uid);
      } catch (_) {}
      
      await _saveSession(uid, tenantId: tenantId, currentRole: role);
    }

    return userCredential;
  }

  Future<UserCredential> signUpOwner({
    required String name,
    required String phone,
    required String password,
    required String tenantId,
  }) async {
    return signUpWithEmail(
      name: name,
      phone: phone,
      password: password,
      role: 'owner',
      tenantId: tenantId,
    );
  }

  Future<UserCredential> signUpCustomer({
    required String name,
    required String phone,
    required String password,
    String? tenantId,
  }) async {
    return signUpWithEmail(
      name: name,
      phone: phone,
      password: password,
      role: 'customer',
      tenantId: tenantId,
    );
  }

  /// Sign in with synthetic email from phone + password.
  Future<UserCredential> signInWithEmail({
    required String phone,
    required String password,
  }) async {
    final email = '$phone@dukanx.local';
    developer.log('signInWithEmail email=$email');
    
    final userPool = sl<CognitoUserPool>();
    final cognitoUser = CognitoUser(email, userPool);
    final authDetails = AuthenticationDetails(
      username: email,
      password: password,
    );

    CognitoUserSession? session;
    try {
      session = await cognitoUser.authenticateUser(authDetails);
    } on CognitoUserNewPasswordRequiredException catch (_) {
      throw FirebaseAuthException(
        code: 'new-password-required',
        message: 'New password required',
      );
    } on CognitoUserConfirmationNecessaryException catch (_) {
      throw FirebaseAuthException(
        code: 'unconfirmed',
        message: 'User is not confirmed',
      );
    } on CognitoClientException catch (e) {
      throw FirebaseAuthException(
        code: e.code ?? 'error',
        message: e.message ?? 'Login failed',
      );
    } catch (e) {
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }

    if (session == null || !session.isValid()) {
      throw FirebaseAuthException(
        code: 'invalid-session',
        message: 'Invalid Cognito session',
      );
    }

    final idTokenPayload = session.getIdToken().payload;
    final uid = (idTokenPayload['sub'] as String?) ?? email;

    final userCredential = UserCredential(
      User(uid: uid, email: email, phoneNumber: phone),
    );

    try {
      await sl<NotificationController>().getToken(uid: uid);
    } catch (_) {}

    return userCredential;
  }

  Future<UserCredential> signInOwner({
    required String phone,
    required String password,
    required String tenantId,
  }) async {
    final cred = await signInWithEmail(phone: phone, password: password);
    final uid = cred.user?.uid;
    
    if (uid != null) {
      final role = await getCurrentUserRole() ?? 'customer';
      if (role != 'owner') {
        await signOut();
        throw FirebaseAuthException(
          code: 'invalid-role',
          message: 'User is not an owner',
        );
      }

      await _saveSession(uid, tenantId: tenantId, currentRole: role);
    }
    return cred;
  }

  Future<UserCredential> signInCustomer({
    required String phone,
    required String password,
    String? tenantId,
  }) async {
    final cred = await signInWithEmail(phone: phone, password: password);
    final uid = cred.user?.uid;
    
    if (uid != null) {
      final role = await getCurrentUserRole() ?? 'customer';
      if (role != 'customer') {
        await signOut();
        throw FirebaseAuthException(
          code: 'invalid-role',
          message: 'User is not a customer',
        );
      }
      // Session saved successfully without enforcing tenant boundaries for customers at login
      await _saveSession(uid, tenantId: tenantId, currentRole: role);
    }
    return cred;
  }

  /// Launches the Cognito Hosted UI — returns immediately.
  Future<bool> signInWithGoogle({String role = 'customer'}) async {
    try {
      final gs = GoogleSignInService();
      await gs.launchGoogleSignIn(state: role);
      // Flow continues asynchronously via deep link redirect
      return true;
    } catch (e) {
      developer.log('Google Sign-In Error: $e', name: 'AuthService');
      return false;
    }
  }

  /// Sign in with Google as an Owner via Cognito Hosted UI.
  Future<void> signInOwnerWithGoogle() async {
    try {
      final gs = GoogleSignInService();
      await gs.launchGoogleSignIn(state: 'owner');
    } catch (e) {
      developer.log('Owner Google Sign-In Error: $e', name: 'AuthService');
      rethrow;
    }
  }

  /// Update backend profile via API Gateway.
  Future<void> updateProfile(
    String uid, {
    String? name,
    String? phone,
    String? email,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (email != null) data['email'] = email;
    
    if (data.isNotEmpty) {
      final apiClient = sl<ApiClient>();
      await apiClient.put('/api/v1/users/me', body: data);
    }
  }

  /// Sign out and clear all caching
  Future<void> signOut() async {
    // POST-REMEDIATION FIX #6: Call server-side logout to revoke all refresh tokens
    // This ensures Cognito globalSignOut is called, invalidating ALL sessions.
    try {
      final sessionManager = sl<SessionManager>();
      final cognitoUser = await sessionManager.currentCognitoUser;
      if (cognitoUser != null) {
        final session = await cognitoUser.getSession();
        if (session != null && session.isValid()) {
          final accessToken = session.getAccessToken().getJwtToken();
          if (accessToken != null && accessToken.isNotEmpty) {
            final apiClient = sl<ApiClient>();
            await apiClient.post('/auth/logout', body: {}).timeout(
              const Duration(seconds: 5),
              onTimeout: () => ApiResponse<Map<String, dynamic>>.offline(),
            );
          }
        }
      }
    } catch (e) {
      developer.log('Server-side logout failed (non-blocking): $e', name: 'AuthService');
    }

    // Clear local session - SECURE: Using flutter_secure_storage
    try {
      const secureStorage = FlutterSecureStorage();
      await secureStorage.delete(key: _sessionKeyUid);
      await secureStorage.delete(key: _sessionKeyRole);
      await secureStorage.delete(key: _sessionKeyTimestamp);
      await secureStorage.delete(key: _sessionKeyTenantId);
      await secureStorage.delete(key: _legacySessionKeyShopId);
    } catch (_) {}

    try {
      await GoogleSignInService().signOut();
    } catch (_) {}

    try {
      final userPool = sl<CognitoUserPool>();
      final currentUser = await userPool.getCurrentUser();
      await currentUser?.signOut();
    } catch (_) {}

    // SEC-04 FIX: Clear TokenManager tokens (cognito_tokens_v2, cognito_refresh_token_v2)
    // Without this, refresh tokens survive logout on shared devices.
    try {
      if (sl.isRegistered<TokenManager>()) {
        await sl<TokenManager>().clearTokens();
      }
    } catch (_) {}

    // SEC-04 FIX: Clear SharedPreferences role cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
      await prefs.remove('user_id');
    } catch (_) {}
  }

  Future<void> _saveSession(String uid, {String? tenantId, String? currentRole}) async {
    // CRITICAL FIX: Using flutter_secure_storage instead of SharedPreferences
    const secureStorage = FlutterSecureStorage();
    final role = currentRole ?? await getCurrentUserRole();
    
    await secureStorage.write(key: _sessionKeyUid, value: uid);
    if (role != null) {
      await secureStorage.write(key: _sessionKeyRole, value: role);
    }
    
    if (tenantId != null) {
      await secureStorage.write(key: _sessionKeyTenantId, value: tenantId);
      await secureStorage.write(key: _legacySessionKeyShopId, value: tenantId);
    }

    await secureStorage.write(
      key: _sessionKeyTimestamp,
      value: DateTime.now().toIso8601String(),
    );
    
    developer.log(
      'Session saved securely for $uid role=${role ?? 'unknown'} tenantId=$tenantId',
    );

    try {
      if (!legacy.sessionService.isInitialized) {
        await legacy.sessionService.init();
      }
      await legacy.sessionService.saveSession(
        userId: uid,
        role: role ?? 'customer',
        contact: 'cognito_user',
      );
    } catch (e) {
      developer.log('SessionService mirror failed: $e', name: 'AuthService');
    }
  }

  Future<Map<String, String>?> getSavedSession() async {
    // CRITICAL FIX: Using flutter_secure_storage instead of SharedPreferences
    const secureStorage = FlutterSecureStorage();
    final uid = await secureStorage.read(key: _sessionKeyUid);
    final role = await secureStorage.read(key: _sessionKeyRole);
    var tenantId = await secureStorage.read(key: _sessionKeyTenantId);
    tenantId ??= await secureStorage.read(key: _legacySessionKeyShopId);
    
    if (uid == null) return null;
    return {
      'uid': uid,
      'role': role ?? 'customer',
      'tenantId': tenantId ?? '',
      'shopId': tenantId ?? '',
    };
  }

  Future<String?> getTenantId() async {
    // CRITICAL FIX: Using flutter_secure_storage instead of SharedPreferences
    const secureStorage = FlutterSecureStorage();
    var tenantId = await secureStorage.read(key: _sessionKeyTenantId);
    if (tenantId == null || tenantId.isEmpty) {
      tenantId = await secureStorage.read(key: _legacySessionKeyShopId);
      if (tenantId != null && tenantId.isNotEmpty) {
        await secureStorage.write(key: _sessionKeyTenantId, value: tenantId);
      }
    }
    return tenantId;
  }

  Future<String?> getShopId() => getTenantId();

  /// Retrieve the current user role from API Gateway instead of Firestore
  Future<String?> getCurrentUserRole() async {
    try {
      final sessionManager = sl<SessionManager>();
      // Fallback check against API if sessionManager doesn't have it
      if (sessionManager.isAuthenticated) {
        return sessionManager.isOwner ? 'owner' : (sessionManager.isCustomer ? 'customer' : 'patient');
      }
      
      final apiClient = sl<ApiClient>();
      final res = await apiClient.get('/api/v1/users/me');
      if (res.isSuccess && res.data != null) {
        return res.data!['role'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Handle post-sign-in logic for Identity Providers outside standard flow
  Future<void> handlePostSignIn(UserCredential userCred) async {
    final user = userCred.user;
    if (user == null) return;
    await _saveSession(user.uid);
    try {
      await sl<NotificationController>().getToken(uid: user.uid);
    } catch (_) {}
  }

  Future<void> handlePostSignInGoogle(dynamic googleUser) async {
    String? tenantId;
    try {
      final sessionManager = sl<SessionManager>();
      final cognitoUser = await sessionManager.currentCognitoUser;
      if (cognitoUser != null) {
        final session = await cognitoUser.getSession();
        if (session != null && session.isValid()) {
          final idToken = session.getIdToken();
          final payload = idToken.payload;
          tenantId = payload['custom:tenant_id'] as String?;
        }
      }
    } catch (e) {
      developer.log('Failed to extract tenant context from session: $e');
    }

    await _saveSession(googleUser.id, tenantId: tenantId);

    try {
      await sl<NotificationController>().getToken(uid: googleUser.id);
    } catch (_) {}
  }
}
