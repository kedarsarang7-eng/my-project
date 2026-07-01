import 'dart:developer' as developer;
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/di/service_locator.dart';
import '../core/services/notification_controller.dart';
import 'google_signin_service.dart';
import 'session_service.dart' as legacy;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _ensureNetwork() async {
    try {
      await _firestore.enableNetwork().timeout(const Duration(seconds: 10));
    } catch (e) {
      developer.log(
        'AuthService: enableNetwork warning: $e',
        name: 'AuthService',
      );
    }
  }

  // Demo mode switch (safe default false)
  static const bool demoMode = false;
  // OTP Feature Flag (Set to true to enable Firebase Phone Auth)
  static const bool enableOtp = false;

  // Session keys
  static const String _sessionKeyUid = 'session_uid';
  static const String _sessionKeyRole = 'session_role';
  static const String _sessionKeyTimestamp = 'session_timestamp';

  // Phone Auth Methods

  /// Verify a phone number by sending an OTP.
  /// NOTE: OTP login intentionally disabled to avoid Firebase SMS billing costs.
  /// Re-enable by uncommenting the original logic when billing is approved.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) codeSent,
    required Function(AuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    if (!enableOtp) {
      verificationFailed(
        FirebaseAuthException(
          code: 'otp-disabled',
          message:
              'OTP login is disabled. Please use Google Sign-In or Password login.',
        ),
      );
      return;
    }

    developer.log(
      'Starting phone verification for $phoneNumber',
      name: 'AuthService',
    );
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Signs in with the SMS code provided by the user.
  /// NOTE: OTP login intentionally disabled to avoid Firebase SMS billing costs.
  /// Users can use Google Sign-In or Password login instead.
  Future<UserCredential> signInWithOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    if (!enableOtp) {
      throw FirebaseAuthException(
        code: 'otp-disabled',
        message:
            'OTP login is disabled. Please use Google Sign-In or Password login.',
      );
    }

    developer.log('Signing in with OTP...', name: 'AuthService');
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _auth.signInWithCredential(credential);

    if (userCredential.user != null) {
      await _saveSession(userCredential.user!.uid);
    }

    return userCredential;
  }

  /// Sign up with synthetic email derived from phone and store role in Firestore.
  Future<UserCredential> signUpWithEmail({
    required String name,
    required String phone,
    required String password,
    required String role,
    String? shopId,
  }) async {
    await _ensureNetwork();
    final email = '$phone@vegetable-billing.local';
    developer.log('signUpWithEmail email=$email role=$role shopId=$shopId');

    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user?.uid;
    if (uid != null) {
      final userData = {
        'name': name,
        'phone': phone,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (shopId != null) userData['shopId'] = shopId;

      int retries = 3;
      while (retries > 0) {
        try {
          await _firestore
              .collection('users')
              .doc(uid)
              .set(userData, SetOptions(merge: true));
          break;
        } catch (e) {
          if (retries > 1) {
            retries--;
            await Future.delayed(const Duration(seconds: 1));
          } else {
            developer.log(
              'AuthService: signUpWithEmail retry failed: $e',
              name: 'AuthService',
            );
            // We don't rethrow here because the basic user was created in Auth
            // But we should probably warn or try best effort for session
          }
        }
      }

      // Save FCM token
      try {
        await sl<NotificationController>().getToken(uid: uid);
      } catch (_) {}
      await _saveSession(uid);
    }

    return userCredential;
  }

  /// Convenience wrappers for owner/customer sign-up using phone-derived email.
  Future<UserCredential> signUpOwner({
    required String name,
    required String phone,
    required String password,
    required String shopId,
  }) async {
    return signUpWithEmail(
      name: name,
      phone: phone,
      password: password,
      role: 'owner',
      shopId: shopId,
    );
  }

  Future<UserCredential> signUpCustomer({
    required String name,
    required String phone,
    required String password,
    String? shopId,
  }) async {
    return signUpWithEmail(
      name: name,
      phone: phone,
      password: password,
      role: 'customer',
      shopId: shopId,
    );
  }

  /// Sign in with synthetic email from phone + password, then save session.
  Future<UserCredential> signInWithEmail({
    required String phone,
    required String password,
  }) async {
    await _ensureNetwork();
    final email = '$phone@vegetable-billing.local';
    developer.log('signInWithEmail email=$email');
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (userCredential.user != null) {
      // persist session and FCM token
      await _saveSession(userCredential.user!.uid);
      try {
        await sl<NotificationController>().getToken(
          uid: userCredential.user!.uid,
        );
      } catch (_) {}
    }

    return userCredential;
  }

  /// Convenience wrappers for owner/customer login.
  Future<UserCredential> signInOwner({
    required String phone,
    required String password,
    required String shopId,
  }) async {
    final cred = await signInWithEmail(phone: phone, password: password);
    // validate role and shopId from Firestore
    final uid = cred.user?.uid;
    if (uid != null) {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      final role = data?['role'] as String? ?? 'customer';
      final storedShopId = data?['shopId'] as String?;

      if (role != 'owner') {
        await signOut();
        throw FirebaseAuthException(
          code: 'invalid-role',
          message: 'User is not an owner',
        );
      }

      if (storedShopId != shopId) {
        await signOut();
        throw FirebaseAuthException(
          code: 'invalid-shop-id',
          message: 'Invalid Shop ID for this account',
        );
      }
    }
    return cred;
  }

  Future<UserCredential> signInCustomer({
    required String phone,
    required String password,
    String? shopId,
  }) async {
    final cred = await signInWithEmail(phone: phone, password: password);
    final uid = cred.user?.uid;
    if (uid != null) {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      final role = data?['role'] as String? ?? 'customer';

      if (role != 'customer') {
        await signOut();
        throw FirebaseAuthException(
          code: 'invalid-role',
          message: 'User is not a customer',
        );
      }

      // We no longer strictly enforce shopId on login for customers
      // as they can match multiple shops.
      // If a shopId IS provided (legacy flow), we could check it,
      // but simplest is to just allow login if credentials are correct.
    }
    return cred;
  }

  /// Sign in with Google as a Customer.
  /// Handles authentication, Firestore user creation (strict no-overwrite), and session.
  Future<bool> signInWithGoogle({String role = 'customer'}) async {
    try {
      // 1. Authenticate with Google (returns UserCredential)
      final gs = GoogleSignInService();
      final userCred = await gs.signIn();
      if (userCred == null || userCred.user == null) {
        return false; // User cancelled
      }
      final user = userCred.user!;

      // 2. Ensure Firestore Document Exists (Idempotent)
      final userData = await _ensureFirestoreUser(user, role: role);

      // 3. Role Validation
      final storedRole = userData['role'];
      if (storedRole != role) {
        // If role doesn't match and it's not a generic 'customer' upgrading...
        // Actually, strict requirement: "Role must persist".
        // If I am an owner trying to log in as customer, I should probably be redirected or denied.
        // For now, if stored role is 'owner' and I try to login as 'customer', we allow it?
        // User request: "Role (Owner / Customer) must persist across logins"
        // If I registered as Owner, I am an Owner.
        if (role == 'customer' && storedRole == 'owner') {
          // Allow owner to access customer features? Or deny?
          // Usually better to just update local session to 'owner' and redirect to owner dash.
          // BUT, user asked for "Login UI... Role differs".
          // If I choose Customer Login but I am an Owner, should I be blocked?
          // Let's being strict as per standard security:
          await signOut();
          throw FirebaseAuthException(
            code: 'role-mismatch',
            message:
                'This account is registered as $storedRole. Please login as $storedRole.',
          );
        } else if (role == 'owner' && storedRole != 'owner') {
          await signOut();
          throw FirebaseAuthException(
            code: 'role-mismatch',
            message: 'This account is not an Owner account.',
          );
        }
      }

      // 4. Session & Post-Auth
      await handlePostSignIn(userCred);
      return true;
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'role-mismatch') rethrow;
      developer.log('Google Sign-In Error: $e', name: 'AuthService');
      return false;
    }
  }

  /// Sign in with Google as an Owner.
  Future<void> signInOwnerWithGoogle() async {
    try {
      // 1. Authenticate
      final gs = GoogleSignInService();
      final userCred = await gs.signIn();
      if (userCred == null || userCred.user == null) {
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'Google sign-in cancelled',
        );
      }
      final user = userCred.user!;

      // 2. Ensure Document (Idempotent)
      // For owner, we might need a separate 'owners' record?
      // UnifiedAuthScreen was creating it. let's check it here.
      final userData = await _ensureFirestoreUser(user, role: 'owner');

      // 3. Role/Shop Validation
      final storedRole = userData['role'];
      if (storedRole != 'owner') {
        await signOut();
        throw FirebaseAuthException(
          code: 'unauthorized-owner',
          message: 'This google account is not registered as an Owner.',
        );
      }

      // 4. Ensure Owner Profile (Legacy/Shop Data) - Optional check
      // We assume if role is owner, the owner doc exists or will be created by UI if missing?
      // Better to ensure it here if possible, but we need Shop Name.
      // If it's a new user, ensureFirestoreUser created it with role='owner'.
      // We might need to redirect to a "Finish Setup" screen if shop details are missing.
      // For now, we proceed.

      // 5. Session
      await handlePostSignIn(userCred);
    } catch (e) {
      if (e is FirebaseAuthException && e.code.startsWith('role-mismatch')) {
        rethrow;
      }
      developer.log('Owner Google Sign-In Error: $e', name: 'AuthService');
      rethrow;
    }
  }

  /// Ensure a Firestore `users/{uid}` document exists.
  /// Returns the document data (existing or newly created).
  Future<Map<String, dynamic>> _ensureFirestoreUser(
    User user, {
    String? name,
    String role = 'customer',
  }) async {
    await _ensureNetwork();
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      // Return existing data. Do NOT overwrite role or createdAt.
      return doc.data()!;
    }

    // Create New
    final data = {
      'uid': user.uid,
      'email': user.email ?? '',
      'name': name ?? user.displayName ?? '',
      'phone': user.phoneNumber ?? '',
      'photoUrl': user.photoURL ?? '',
      'role': role,
      'loginMethod': 'google', // helpful for analytics
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data);
    return data;
  }

  /// High-level wrapper to sign up or sign in with phone using OTP.
  /// Returns the UserCredential on success or null on failure/cancel.
  Future<UserCredential?> signInOrSignUpWithPhone({
    required String phone,
    String? name,
    String role = 'customer',
    int? forceResendingToken,
  }) async {
    final completer = Completer<UserCredential?>();

    try {
      await verifyPhone(
        phone: phone,
        forceResendingToken: forceResendingToken,
        onVerified: (AuthCredential credential) async {
          try {
            final cred = await signInWithCredential(credential);
            if (cred.user != null) {
              await _ensureFirestoreUser(cred.user!, name: name, role: role);
            }
            if (!completer.isCompleted) completer.complete(cred);
          } catch (e) {
            if (!completer.isCompleted) completer.completeError(e);
          }
        },
        onCodeSent: (verificationId, token) {
          // The UI should handle prompting user for SMS code and then call confirmWebOtp or signInWithCredential.
          // For this high-level wrapper we just wait; the UI will complete the flow via confirmWebOtp or signInWithCredential.
          developer.log(
            'Code sent for $phone verificationId=$verificationId resendToken=$token',
            name: 'AuthService',
          );
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
      );
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }

    return completer.future;
  }

  /// FIX (H-04): Phone password reset via synthetic email was broken —
  /// emails to @vegetable-billing.local go nowhere.
  /// Now throws a clear exception for the UI to show.
  Future<void> sendPasswordResetForPhone(String phone) async {
    throw FirebaseAuthException(
      code: 'phone-reset-unsupported',
      message: 'Password reset is not available for phone-based accounts. '
          'Please use OTP login or contact support to reset your account.',
    );
  }

  /// Update Firestore profile for the given uid (merge).
  Future<void> updateProfile(
    String uid, {
    String? name,
    String? phone,
    String? email,
  }) async {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (email != null) data['email'] = email;
    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  /// Sign out and clear local session
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKeyUid);
      await prefs.remove(_sessionKeyRole);
      await prefs.remove(_sessionKeyTimestamp);
    } catch (_) {}

    // Explicitly sign out of Google to force account selection next time
    try {
      await GoogleSignInService().signOut();
      // Note: GoogleSignInService().signOut() also calls _firebaseAuth.signOut()
    } catch (e) {
      // Fallback if Google Sign-In service fails
      await _auth.signOut();
    }
  }

  Future<void> _saveSession(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final role = await getCurrentUserRole();
    await prefs.setString(_sessionKeyUid, uid);
    if (role != null) await prefs.setString(_sessionKeyRole, role);
    await prefs.setString(
      _sessionKeyTimestamp,
      DateTime.now().toIso8601String(),
    );
    developer.log('Session saved for $uid role=${role ?? 'unknown'}');

    try {
      if (!legacy.sessionService.isInitialized) {
        await legacy.sessionService.init();
      }
      final firebaseUser = _auth.currentUser;
      final phoneOrEmail =
          firebaseUser?.phoneNumber ?? firebaseUser?.email ?? 'unknown';
      await legacy.sessionService.saveSession(
        userId: uid,
        role: role ?? 'customer',
        contact: phoneOrEmail,
      );
    } catch (e) {
      developer.log('SessionService mirror failed: $e', name: 'AuthService');
    }
  }

  Future<Map<String, String>?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_sessionKeyUid);
    final role = prefs.getString(_sessionKeyRole);
    if (uid == null) return null;
    return {'uid': uid, 'role': role ?? 'customer'};
  }

  /// Get role from Firestore for current user
  Future<String?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return doc.data()?['role'] as String?;
  }

  // PHONE AUTH (mobile + web helpers)
  dynamic _webConfirmationResult;

  Future<void> verifyPhone({
    required String phone,
    required Function(AuthCredential) onVerified,
    required Function(String verificationId, int? token) onCodeSent,
    required Function(FirebaseAuthException) onError,
    int? forceResendingToken,
  }) async {
    if (!enableOtp) {
      onError(
        FirebaseAuthException(
          code: 'otp-disabled',
          message:
              'OTP login is disabled. Please use Google Sign-In or Password login.',
        ),
      );
      return;
    }

    // Web support could be added here if needed, but for now we focus on mobile logic restoration
    // or standard Firebase Auth flow. For verifyPhone wrapper:

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: onVerified,
      verificationFailed: onError,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (String verificationId) {},
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken,
    );
  }

  Future<UserCredential> confirmWebOtp(String smsCode) async {
    if (!kIsWeb) {
      throw FirebaseAuthException(
        code: 'not-web',
        message: 'confirmWebOtp is for web only',
      );
    }
    if (_webConfirmationResult == null) {
      throw FirebaseAuthException(
        code: 'no-confirmation',
        message: 'No confirmation result available',
      );
    }
    final userCred = await _webConfirmationResult.confirm(smsCode);
    if (userCred.user != null) {
      await _saveSession(userCred.user!.uid);
      try {
        await sl<NotificationController>().getToken(uid: userCred.user!.uid);
      } catch (_) {}
    }
    return userCred;
  }

  Future<UserCredential> signInWithCredential(
    AuthCredential credential,
  ) async {
    final userCred = await _auth.signInWithCredential(credential);
    if (userCred.user != null) {
      await _saveSession(userCred.user!.uid);
      try {
        await sl<NotificationController>().getToken(uid: userCred.user!.uid);
      } catch (_) {}
    }
    return userCred;
  }

  /// Current Firebase User (nullable)
  User? get currentUser => _auth.currentUser;

  /// Handle common post-sign-in tasks for external sign-in flows (Google, etc.).
  /// Saves session info and FCM token for the signed-in user.
  Future<void> handlePostSignIn(UserCredential userCred) async {
    final user = userCred.user;
    if (user == null) return;
    await _saveSession(user.uid);
    try {
      await sl<NotificationController>().getToken(uid: user.uid);
    } catch (_) {}
  }
}
