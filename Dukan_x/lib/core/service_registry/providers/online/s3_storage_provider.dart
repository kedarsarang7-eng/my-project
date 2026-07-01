// Online Storage Provider — S3 via presigned URLs from Lambda.
// Upload: POST /storage/presign → PUT to presigned URL.
// Download: GET /storage/url/{key} → presigned GET URL → http.get.
// Mirrors existing CloudStorageService but satisfies IStorageService.

import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../contracts/i_storage_service.dart';

class S3StorageProvider implements IStorageService {
  ApiClient get _api => sl<ApiClient>();

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

  @override
  Future<String> upload(
    Uint8List bytes,
    String key, {
    required String mimeType,
    String? context,
  }) async {
    // 1. Get presigned PUT URL from Lambda.
    final bodyParams = <String, dynamic>{
      'key': key,
      'mimeType': mimeType,
      'operation': 'putObject',
    };
    if (context != null) {
      bodyParams['context'] = context;
    }

    final presignRes = await _api.post('/storage/presign', body: bodyParams);
    if (!presignRes.isSuccess || presignRes.data == null) {
      throw Exception('[S3Storage] presign failed: ${presignRes.error}');
    }
    final presignData = presignRes.data as Map<String, dynamic>;
    final putUrl = presignData['url'] as String;
    
    // The lambda now returns the fully resolved 'key' instead of 'publicUrl'
    // The client uses getUrl() later to fetch it, so we return the canonical key
    final resolvedKey = presignData['key'] as String? ?? key;

    // 2. PUT directly to S3.
    final putRes = await http.put(
      Uri.parse(putUrl),
      headers: {'Content-Type': mimeType},
      body: bytes,
    );
    if (putRes.statusCode != 200 && putRes.statusCode != 204) {
      throw Exception('[S3Storage] PUT to S3 failed: ${putRes.statusCode}');
    }
    return resolvedKey;
  }

  @override
  Future<Uint8List> download(String key) async {
    final url = await getUrl(key);
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('[S3Storage] download failed: ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  @override
  Future<String> getUrl(String key, {int expirySeconds = 900}) async {
    final res = await _api.get(
      '/storage/url/${Uri.encodeComponent(key)}',
      queryParams: {'expiresIn': expirySeconds.toString()},
    );
    if (!res.isSuccess || res.data == null) {
      throw Exception('[S3Storage] getUrl failed: ${res.error}');
    }
    final data = res.data as Map<String, dynamic>;
    return data['url'] as String;
  }

  @override
  Future<void> delete(String key) async {
    final res = await _api.delete('/storage/${Uri.encodeComponent(key)}');
    if (!res.isSuccess) {
      throw Exception('[S3Storage] delete failed: ${res.error}');
    }
  }

  @override
  Future<List<StorageObjectMeta>> list(String prefix) async {
    final res = await _api.get(
      '/storage/list',
      queryParams: {'prefix': prefix},
    );
    if (!res.isSuccess || res.data == null) return [];
    final items = (res.data as Map<String, dynamic>)['items'] as List? ?? [];
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return StorageObjectMeta(
        key: m['key'] as String,
        sizeBytes: (m['sizeBytes'] as int?) ?? 0,
        contentType: m['contentType'] as String?,
        lastModified: DateTime.tryParse(m['lastModified'] as String? ?? '') ??
            DateTime.now(),
        checksumSha256: m['checksumSha256'] as String?,
      );
    }).toList();
  }
}
