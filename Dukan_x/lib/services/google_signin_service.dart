// ignore_for_file: unused_field

import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  static final GoogleSignInService _instance = GoogleSignInService._internal();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  GoogleSignInService._internal();

  factory GoogleSignInService() {
    return _instance;
  }

  /// Initiates the Google Sign-In flow and returns the [UserCredential].
  /// Does NOT handle Firestore creation or session management.
  Future<UserCredential?> signIn() async {
    try {
      developer.log(
        'Starting Google Sign-In flow...',
        name: 'GoogleSignInService',
      );

      if (kIsWeb) {
        // Web: Use popup (Preferred for Firebase on Web)
        final GoogleAuthProvider googleAuthProvider = GoogleAuthProvider();
        googleAuthProvider.setCustomParameters({'prompt': 'select_account'});

        return await _firebaseAuth.signInWithPopup(googleAuthProvider);
      } else {
        // Mobile: Use native Google Sign-In (v7.x Singleton API)
        final GoogleSignInAccount googleUser = await GoogleSignIn.instance
            .authenticate(scopeHint: ['email']);

        // v7.x separates Authentication (ID Token) and Authorization (Access Token)
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        // Explicitly authorize scopes to get the access token
        final authz = await googleUser.authorizationClient.authorizeScopes([
          'email',
        ]);

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: authz.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _firebaseAuth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      developer.log(
        'FirebaseAuthException: ${e.code}',
        name: 'GoogleSignInService',
      );
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception('Email already linked to another login method.');
      } else if (e.code == 'invalid-credential') {
        throw Exception('Invalid Google credentials.');
      } else {
        throw Exception(e.message ?? 'Authentication failed');
      }
    } catch (e) {
      developer.log('Google Sign-In Error: $e', name: 'GoogleSignInService');
      rethrow;
    }
  }

  /// Signs out from both Firebase and Google.
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      developer.log('Sign out error: $e', name: 'GoogleSignInService');
    }
  }
}
