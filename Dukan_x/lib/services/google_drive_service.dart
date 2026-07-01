// Google Drive Backup Service
//
// Uses user's own Google Drive for free backup storage.
// Only accesses app-created files (drive.file scope).

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Google Drive backup service for DukanX
/// Uses `drive.file` scope - can ONLY access files created by the app
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  drive.DriveApi? _driveApi;
  String? _appFolderId;
  String? _lastError;
  GoogleSignInAccount? _account;
  DateTime? _connectedAt;

  /// Check if Drive is connected
  bool get isConnected => _driveApi != null;

  /// Get the last error message (if any)
  String? get lastError => _lastError;

  /// Email of the linked Google account (null when disconnected).
  String? get accountEmail => _account?.email;

  /// When the current Drive session was established (null when disconnected).
  DateTime? get connectedAt => _connectedAt;

  /// Required scopes for Drive backup (minimal permissions)
  static const List<String> driveScopes = [
    drive.DriveApi.driveFileScope, // Only app-created files
  ];

  /// Connect to Google Drive
  /// Must call after Google Sign-In is complete
  Future<bool> connect() async {
    final result = await connectWithDetails();
    return result.success;
  }

  /// Connect to Google Drive with detailed error reporting
  /// Returns a record with success status and optional error message
  Future<({bool success, String? error})> connectWithDetails() async {
    _lastError = null;
    try {
      final googleSignIn = GoogleSignIn.instance;

      // Authenticate and authorize Drive scopes
      final user = await googleSignIn.authenticate(scopeHint: driveScopes);
      _bindAccount(user);

      debugPrint('GoogleDrive: Connected successfully as ${user.email}');
      return (success: true, error: null);
    } on Exception catch (e) {
      final errorMsg = _parseError(e);
      _lastError = errorMsg;
      debugPrint('GoogleDrive: Connection error: $errorMsg');
      return (success: false, error: errorMsg);
    } catch (e) {
      _lastError = e.toString();
      debugPrint('GoogleDrive: Connection error: $e');
      return (success: false, error: e.toString());
    }
  }

  /// Attempt to silently restore a previous Drive session on app start so the
  /// user is not forced to re-login every session. Returns true if restored.
  Future<bool> tryRestoreSession() async {
    try {
      final user =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (user == null) return false;
      _bindAccount(user);
      debugPrint('GoogleDrive: Session restored for ${user.email}');
      return true;
    } catch (e) {
      debugPrint('GoogleDrive: Silent restore failed: $e');
      return false;
    }
  }

  /// Actively verifies Drive API access (not just token presence) by issuing a
  /// lightweight `about.get` call. Returns a real pass/fail with a message.
  Future<({bool success, String? error})> testConnection() async {
    if (_driveApi == null) {
      return (success: false, error: 'Not connected to Google Drive.');
    }
    try {
      final about = await _driveApi!.about.get($fields: 'user(emailAddress)');
      final email = about.user?.emailAddress ?? _account?.email;
      debugPrint('GoogleDrive: testConnection OK for $email');
      return (success: true, error: null);
    } on Exception catch (e) {
      final msg = _parseError(e);
      _lastError = msg;
      return (success: false, error: msg);
    } catch (e) {
      _lastError = e.toString();
      return (success: false, error: e.toString());
    }
  }

  /// Binds a signed-in account: builds a refresh-capable Drive client and
  /// records account metadata.
  void _bindAccount(GoogleSignInAccount user) {
    _account = user;
    _connectedAt = DateTime.now();
    final client = _AuthClient(http.Client(), user, driveScopes);
    _driveApi = drive.DriveApi(client);
    // Ensure app folder exists (best-effort; not fatal to connection).
    _ensureAppFolder();
  }

  /// Parse error into user-friendly message
  String _parseError(Exception e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Network error. Please check your internet connection.';
    }
    if (msg.contains('cancel') || msg.contains('abort')) {
      return 'Sign-in was cancelled.';
    }
    if (msg.contains('permission') || msg.contains('denied')) {
      return 'Permission denied. Please grant access to Google Drive.';
    }
    if (msg.contains('token') || msg.contains('auth')) {
      return 'Authentication failed. Please try signing in again.';
    }
    return 'Connection failed: ${e.toString().split('Exception:').last.trim()}';
  }

  /// Disconnect from Google Drive
  Future<void> disconnect() async {
    _driveApi = null;
    _appFolderId = null;
    _account = null;
    _connectedAt = null;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('GoogleDrive: signOut during disconnect failed: $e');
    }
    debugPrint('GoogleDrive: Disconnected');
  }

  /// Create app folder structure in user's Drive
  Future<void> _ensureAppFolder() async {
    if (_driveApi == null) return;

    final query =
        "name='DukanX' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final response = await _driveApi!.files.list(q: query, spaces: 'drive');

    if (response.files?.isNotEmpty ?? false) {
      _appFolderId = response.files!.first.id;
    } else {
      final folder = drive.File()
        ..name = 'DukanX'
        ..mimeType = 'application/vnd.google-apps.folder';

      final created = await _driveApi!.files.create(folder);
      _appFolderId = created.id;
    }

    await _ensureSubfolder('Bills');
    await _ensureSubfolder('Reports');
    await _ensureSubfolder('Backups');

    debugPrint('GoogleDrive: App folder ready: $_appFolderId');
  }

  Future<String?> _ensureSubfolder(String name) async {
    if (_driveApi == null || _appFolderId == null) return null;

    final query =
        "name='$name' and mimeType='application/vnd.google-apps.folder' and '$_appFolderId' in parents and trashed=false";
    final response = await _driveApi!.files.list(q: query, spaces: 'drive');

    if (response.files?.isNotEmpty ?? false) {
      return response.files!.first.id;
    }

    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [_appFolderId!];

    final created = await _driveApi!.files.create(folder);
    return created.id;
  }

  /// Upload file to DukanX folder
  Future<String?> uploadFile({
    required String localPath,
    required String subfolder,
    required String fileName,
  }) async {
    if (_driveApi == null) {
      debugPrint('GoogleDrive: Not connected');
      return null;
    }

    try {
      final folderId = await _ensureSubfolder(subfolder);
      if (folderId == null) return null;

      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('GoogleDrive: File not found: $localPath');
        return null;
      }

      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId];

      final media = drive.Media(file.openRead(), await file.length());
      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      debugPrint('GoogleDrive: Uploaded ${result.name} (${result.id})');
      return result.id;
    } catch (e) {
      debugPrint('GoogleDrive: Upload error: $e');
      return null;
    }
  }

  /// List backup files in Drive
  Future<List<DriveBackupFile>> listBackups({
    String subfolder = 'Backups',
  }) async {
    if (_driveApi == null || _appFolderId == null) return [];

    try {
      final folderId = await _ensureSubfolder(subfolder);
      if (folderId == null) return [];

      final query = "'$folderId' in parents and trashed=false";
      final response = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id,name,size,createdTime,modifiedTime)',
        orderBy: 'modifiedTime desc',
      );

      return (response.files ?? [])
          .map(
            (f) => DriveBackupFile(
              id: f.id ?? '',
              name: f.name ?? '',
              size: int.tryParse(f.size ?? '0') ?? 0,
              createdAt: f.createdTime,
              modifiedAt: f.modifiedTime,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('GoogleDrive: List error: $e');
      return [];
    }
  }

  /// Download file from Drive
  Future<String?> downloadFile(String fileId, String localName) async {
    if (_driveApi == null) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final localPath = '${tempDir.path}/$localName';

      final media =
          await _driveApi!.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final file = File(localPath);
      final sink = file.openWrite();
      await sink.addStream(media.stream);
      await sink.close();

      debugPrint('GoogleDrive: Downloaded to $localPath');
      return localPath;
    } catch (e) {
      debugPrint('GoogleDrive: Download error: $e');
      return null;
    }
  }
}

/// Authenticated HTTP client that fetches a fresh access token per request via
/// the account's authorizationClient, so the Drive session keeps working across
/// token expiry without forcing the user to re-login.
class _AuthClient extends http.BaseClient {
  final http.Client _inner;
  final GoogleSignInAccount _account;
  final List<String> _scopes;

  _AuthClient(this._inner, this._account, this._scopes);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final auth = await _account.authorizationClient.authorizeScopes(_scopes);
    request.headers['Authorization'] = 'Bearer ${auth.accessToken}';
    return _inner.send(request);
  }
}

/// Represents a backup file in Drive
class DriveBackupFile {
  final String id;
  final String name;
  final int size;
  final DateTime? createdAt;
  final DateTime? modifiedAt;

  DriveBackupFile({
    required this.id,
    required this.name,
    required this.size,
    this.createdAt,
    this.modifiedAt,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
