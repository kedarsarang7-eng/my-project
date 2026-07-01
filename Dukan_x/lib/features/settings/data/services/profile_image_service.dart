import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../../core/service_registry/service_registry.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/di/service_locator.dart';

/// Handles profile-photo and business-logo image processing + storage.
///
/// Uploads go through [Services.storage] (S3 presigned URL online, local FS
/// offline). The returned value is a *stable storage key* — never a presigned
/// URL, because presigned URLs expire and would break reload-after-restart.
/// Call [resolveUrl] to get a fresh, displayable URL for a stored key.
class ProfileImageService {
  ProfileImageService();

  static const int _maxDimension = 512; // px — avatars/logos never need more
  static const int _jpegQuality = 80;

  /// Compresses [bytes] to a square-ish JPEG no larger than [_maxDimension] and
  /// uploads it under a deterministic key. Returns the storage key to persist.
  Future<String> uploadProfilePhoto(Uint8List bytes) {
    return _compressAndUpload(bytes, _keyFor('profile'));
  }

  /// Same as [uploadProfilePhoto] but stored under a separate logo key so the
  /// business logo and the user's avatar never overwrite each other.
  Future<String> uploadBusinessLogo(Uint8List bytes) {
    return _compressAndUpload(bytes, _keyFor('logo'));
  }

  /// Resolves a stored key into a currently-valid URL for display.
  Future<String> resolveUrl(String key) {
    return Services.storage.getUrl(key);
  }

  String _keyFor(String kind) {
    final owner = sl<SessionManager>().ownerId ?? 'unknown';
    return 'profiles/$owner/$kind.jpg';
  }

  Future<String> _compressAndUpload(Uint8List bytes, String key) async {
    final compressed = _compress(bytes);
    final storedKey = await Services.storage.upload(
      compressed,
      key,
      mimeType: 'image/jpeg',
      context: 'profile',
    );
    LoggerService.d('ProfileImage', 'Uploaded $storedKey (${compressed.length}B)');
    return storedKey;
  }

  /// Pure-Dart compression (works on Android, iOS, Windows, macOS).
  Uint8List _compress(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Not a decodable image — upload original rather than fail hard.
      return bytes;
    }

    final resized = (decoded.width > _maxDimension || decoded.height > _maxDimension)
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? _maxDimension : null,
            height: decoded.height > decoded.width ? _maxDimension : null,
          )
        : decoded;

    return Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));
  }
}
