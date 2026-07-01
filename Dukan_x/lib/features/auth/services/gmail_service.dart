// ============================================================================
// GMAIL SERVICE — DEPRECATED STUB
// ============================================================================
// Gmail OAuth was retired alongside Google Drive backup (see pubspec note:
// "googleapis removed — Google Drive/Gmail backup migrated to S3").
//
// This stub keeps the public surface alive so legacy callers (e.g.
// `email_repository.dart`, `bill_creation_screen_v2.dart`) continue to compile.
// All operations are no-ops; the new email pathway runs through the backend.
// ============================================================================

import '../../../../core/services/logger_service.dart';

/// Replacement for the cloud_firestore-era Gmail account record. We keep just
/// the fields the current call sites read.
class GoogleSignInAccount {
  final String email;
  final String? displayName;

  const GoogleSignInAccount({required this.email, this.displayName});
}

@Deprecated('Gmail OAuth retired. Use the backend email service instead.')
class GmailService {
  static final GmailService _instance = GmailService._internal();
  factory GmailService() => _instance;
  GmailService._internal();

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  /// No-op initializer.
  Future<void> init() async {
    LoggerService.d('Gmail', '[GmailService] Stub initialised; backend email path is used.');
  }

  /// Always fails — Gmail sign-in retired.
  Future<GoogleSignInAccount?> signIn() async {
    LoggerService.d('Gmail', '[GmailService] signIn(): disabled (S3 + backend migration).');
    return null;
  }

  /// No-op sign out.
  Future<void> signOut() async {
    _currentUser = null;
  }

  /// Always reports unauthenticated so callers fall through to backend.
  Future<bool> isAuthenticated() async => false;

  /// Throws — there is no live Gmail token any more.
  Future<String> getAccessToken() async {
    throw StateError(
      'Gmail OAuth retired; route email sending through the backend service.',
    );
  }

  /// Last-known email (always null in stub).
  String? get userEmail => _currentUser?.email;
}
