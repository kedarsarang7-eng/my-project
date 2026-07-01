import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart';

/// Service to handle Gmail OAuth and Token Management
/// This service is responsible for:
/// 1. Signing in the user with Google
/// 2. Requesting the 'https://www.googleapis.com/auth/gmail.send' scope
/// 3. Providing a fresh Access Token for the backend to use
class GmailService {
  static final GmailService _instance = GmailService._internal();
  factory GmailService() => _instance;
  GmailService._internal();

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  // onCurrentUserChanged seems undefined in v7.x or exposed differently.
  // We will rely on manual checks or re-implement if needed.
  // Stream<GoogleSignInAccount?> get onCurrentUserChanged => ...

  /// Initialize
  Future<void> init() async {
    // In v7.x, auto-sign-in/silent sign-in seems to be handled differently or requires
    // calling authenticate(). For now, we wait for explicit sign-in or until we figure out
    // the silent auth flow (maybe authenticate() is silent if session exists? We can't know without trying).
    // So we leave this empty or just log.
    debugPrint('[GmailService] Initialized.');
  }

  /// Sign in explicitly (opens browser/window)
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: [GmailApi.gmailSendScope, 'email'],
      );
      _currentUser = account;
      debugPrint('[GmailService] User signed in: ${account.email}');
      return account;
    } catch (e) {
      debugPrint('[GmailService] Sign-in failed: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      await GoogleSignIn.instance.disconnect();
      _currentUser = null;
    } catch (e) {
      debugPrint('[GmailService] Sign-out failed: $e');
    }
  }

  /// Check if fully authenticated
  Future<bool> isAuthenticated() async {
    // Rely on local state. App restart will require re-login unless we persist/restore.
    return _currentUser != null;
  }

  /// Get a fresh Access Token
  Future<String> getAccessToken() async {
    if (_currentUser == null) {
      throw Exception('User not signed in via Google');
    }

    // authorizeScopes returns a response with accessToken
    final response = await _currentUser!.authorizationClient.authorizeScopes([
      GmailApi.gmailSendScope,
    ]);

    return response.accessToken;
  }

  /// Get current user email
  String? get userEmail => _currentUser?.email;
}
