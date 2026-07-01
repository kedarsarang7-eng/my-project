// ============================================================================
// GOOGLE DRIVE BACKUP — DEPRECATED STUB
// ============================================================================
// The Google Drive backup pathway was retired when backups migrated to S3
// (see pubspec note: "googleapis removed — Google Drive backup migrated to S3").
//
// This file keeps the public surface alive so legacy UI references in
// `main_settings_screen.dart` continue to compile. All operations are no-ops.
// New backup flows must use the S3 backup service.
// ============================================================================

import '../../../../core/services/logger_service.dart';

@Deprecated('Google Drive backup retired. Use S3 backup service instead.')
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  /// Always false — Drive integration removed.
  bool get isConnected => false;

  /// Last error message (always returns the deprecation notice).
  String? get lastError =>
      'Google Drive backup retired; use the S3 backup service.';

  /// No-op connect — returns false to signal disabled feature.
  Future<bool> connect() async {
    LoggerService.d('GoogleDrive', 'GoogleDriveService.connect(): disabled (S3 migration).');
    return false;
  }

  /// No-op connect with details.
  Future<({bool success, String? error})> connectWithDetails() async {
    return (
      success: false,
      error: 'Google Drive backup is disabled. Use the S3 backup option.',
    );
  }

  /// No-op disconnect.
  Future<void> disconnect() async {
    LoggerService.d('GoogleDrive', 'GoogleDriveService.disconnect(): no-op.');
  }
}
