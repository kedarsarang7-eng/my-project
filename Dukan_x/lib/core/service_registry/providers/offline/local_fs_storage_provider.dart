// Offline Storage Provider — persists blobs to the app's support directory.
// Path layout:  <appSupportDir>/dukanx_blobs/<key>
// Sub-directories in the key (e.g. "invoices/2024/INV-001.pdf") are created
// automatically. The returned "URL" is the absolute file:// URI.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../contracts/i_storage_service.dart';

class LocalFsStorageProvider implements IStorageService {
  static const _blobDir = 'dukanx_blobs';

  Future<Directory> get _root async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, _blobDir));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File> _fileFor(String key) async {
    final root = await _root;
    // Sanitize key — collapse leading slashes, keep sub-paths.
    final clean = key.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
    final file = File(p.join(root.path, clean));
    file.parent.createSync(recursive: true);
    return file;
  }

  @override
  Future<String> upload(
    Uint8List bytes,
    String key, {
    required String mimeType,
    String? context,
  }) async {
    final file = await _fileFor(key);
    await file.writeAsBytes(bytes, flush: true);
    return file.uri.toString();
  }

  @override
  Future<Uint8List> download(String key) async {
    final file = await _fileFor(key);
    if (!file.existsSync()) {
      throw Exception('[LocalFsStorage] File not found: $key');
    }
    return file.readAsBytes();
  }

  @override
  Future<String> getUrl(String key, {int expirySeconds = 900}) async {
    // Offline: return file URI — expiry is ignored (local access is instant).
    final file = await _fileFor(key);
    return file.uri.toString();
  }

  @override
  Future<void> delete(String key) async {
    final file = await _fileFor(key);
    if (file.existsSync()) await file.delete();
  }

  @override
  Future<List<StorageObjectMeta>> list(String prefix) async {
    final root = await _root;
    final cleanPrefix = prefix.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
    final prefixDir = Directory(p.join(root.path, cleanPrefix));

    if (!prefixDir.existsSync()) return [];

    final results = <StorageObjectMeta>[];
    await for (final entity in prefixDir.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        // Compute relative key from root.
        final relPath = p.relative(entity.path, from: root.path)
            .replaceAll('\\', '/');
        final bytes = await entity.readAsBytes();
        final checksum = sha256.convert(bytes).toString();
        results.add(StorageObjectMeta(
          key: relPath,
          sizeBytes: stat.size,
          lastModified: stat.modified,
          checksumSha256: checksum,
        ));
      }
    }
    return results;
  }

  @override
  Future<void> dispose() async {}

  @override
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
}
