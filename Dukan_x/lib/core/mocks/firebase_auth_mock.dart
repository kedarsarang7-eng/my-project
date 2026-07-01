// ============================================================================
// Cognito Auth Types — Lightweight type stubs for Cognito integration
// ============================================================================
// These types provide a compatibility layer for code that previously used
// Firebase Auth types. They are simple data classes — NOT mock implementations.
//
// IMPORTANT: These do NOT perform actual authentication. Real authentication
// is handled by Amazon Cognito via the `amazon_cognito_identity_dart_2` package.
// ============================================================================

/// Exception type for authentication errors.
/// Compatible with both Cognito and legacy Firebase error handling patterns.
class FirebaseAuthException implements Exception {
  final String code;
  final String message;
  FirebaseAuthException({required this.code, required this.message});
  @override
  String toString() => 'FirebaseAuthException($code): $message';
}

/// Wrapper for authentication result containing user info.
class UserCredential {
  final User? user;
  UserCredential(this.user);
}

/// Generic auth credential base class.
class AuthCredential {}

/// Phone-based auth credential.
class PhoneAuthCredential extends AuthCredential {}

/// User data model — represents authenticated user information.
/// Populated from Cognito ID token claims after successful authentication.
class User {
  final String uid;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final String? photoURL;
  User({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.photoURL,
  });
}

/// Phone auth credential factory.
class PhoneAuthProvider {
  static PhoneAuthCredential credential({
    required String verificationId,
    required String smsCode,
  }) => PhoneAuthCredential();
}

/// Stub FirebaseAuth class.
///
/// This exists solely as a type-compatible stub for legacy code that
/// references `FirebaseAuth.instance`. Real authentication flows use
/// Cognito via `CognitoUserPool` and `SessionManager`.
///
/// All methods return empty/null defaults. No mock UIDs or fake data.
class FirebaseAuth {
  static final FirebaseAuth instance = FirebaseAuth();
  User? get currentUser => null;

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) codeSent,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String) codeAutoRetrievalTimeout,
    int? forceResendingToken,
    Duration? timeout,
  }) async {}

  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    // No-op stub — real auth is handled by Cognito
    return UserCredential(null);
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // No-op stub — real signup is handled by Cognito
    return UserCredential(null);
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // No-op stub — real login is handled by Cognito
    return UserCredential(null);
  }

  Future<void> sendPasswordResetEmail({required String email}) async {}
  Future<void> signOut() async {}
}
