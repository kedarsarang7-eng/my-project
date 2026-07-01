// ============================================================================
// IStorageService — Blob Storage Contract
// ============================================================================
// Online  -> S3 (presigned PUT/GET).
// Offline -> local filesystem under app-support dir
//            (e.g. %APPDATA%/dukanx/blobs/{key}).
// ============================================================================

import 'dart:async';
import 'dart:typed_data';

class StorageObjectMeta {
  final String key;
  final int sizeBytes;
  final String? contentType;
  final DateTime lastModified;
  final String? checksumSha256;

  const StorageObjectMeta({
    required this.key,
    required this.sizeBytes,
    required this.lastModified,
    this.contentType,
    this.checksumSha256,
  });
}

abstract class IStorageService {
  /// Upload bytes and return the canonical public URL (online) or a
  /// `file://` URI (offline).
  Future<String> upload(
    Uint8List bytes,
    String key, {
    required String mimeType,
    String? context,
  });

  /// Stream-friendly upload for large files. Default falls back to [upload].
  Future<String> uploadStream(
    Stream<List<int>> stream,
    String key, {
    required String mimeType,
    int? expectedSize,
    String? context,
  }) async {
    final chunks = <int>[];
    await for (final chunk in stream) {
      chunks.addAll(chunk);
    }
    return upload(Uint8List.fromList(chunks), key, mimeType: mimeType, context: context);
  }

  /// Download bytes by key.
  Future<Uint8List> download(String key);

  /// Time-limited URL (online: presigned S3 URL; offline: returns the
  /// resolvable `file://` URI — the [expirySeconds] is ignored).
  Future<String> getUrl(String key, {int expirySeconds = 900});

  /// Delete by key. No-op if missing.
  Future<void> delete(String key);

  /// List by prefix — used by migration to enumerate offline blobs.
  Future<List<StorageObjectMeta>> list(String prefix);

  Future<void> dispose() async {}
}
