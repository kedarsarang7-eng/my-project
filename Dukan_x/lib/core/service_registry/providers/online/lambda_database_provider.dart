// Online Database Provider — proxies generic CRUD through Lambda/DynamoDB
// via the existing ApiClient. The /data/{table} endpoints on the backend
// handle single-table DynamoDB access with PK/SK routing.

import 'dart:async';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../contracts/i_database_service.dart';

class LambdaDatabaseProvider implements IDatabaseService {
  ApiClient get _api => sl<ApiClient>();

  @override
  Future<void> save(String table, Map<String, dynamic> record) async {
    final res = await _api.put(
      '/data/$table/${record['id']}',
      body: record,
    );
    if (!res.isSuccess) {
      throw Exception('[LambdaDB] save $table/${record['id']} failed: ${res.error}');
    }
  }

  @override
  Future<Map<String, dynamic>?> findById(String table, String id) async {
    final res = await _api.get('/data/$table/$id');
    if (!res.isSuccess) return null;
    final raw = res.data;
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  Future<QueryPage> query(
    String table,
    QueryFilter filter,
  ) async {
    final params = <String, String>{
      'limit': filter.limit.toString(),
      if (filter.cursor != null) 'cursor': filter.cursor!,
      ...filter.equals.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    };
    final res = await _api.get('/data/$table', queryParams: params);
    if (!res.isSuccess || res.data == null) return const QueryPage([], null);
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return QueryPage(items, data['nextCursor'] as String?);
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> delete(String table, String id) async {
    final res = await _api.delete('/data/$table/$id');
    if (!res.isSuccess) {
      throw Exception('[LambdaDB] delete $table/$id failed: ${res.error}');
    }
  }

  @override
  Future<void> batchWrite(String table, List<Map<String, dynamic>> records) async {
    // DynamoDB BatchWriteItem limit = 25. Chunk client-side.
    const chunkSize = 25;
    for (int i = 0; i < records.length; i += chunkSize) {
      final chunk = records.skip(i).take(chunkSize).toList();
      final res = await _api.post('/data/$table/batch', body: {'items': chunk});
      if (!res.isSuccess) {
        throw Exception('[LambdaDB] batchWrite $table chunk $i failed: ${res.error}');
      }
    }
  }

  @override
  Future<int> count(String table, [QueryFilter? filter]) async {
    final params = <String, String>{
      'countOnly': 'true',
      if (filter?.cursor != null) 'cursor': filter!.cursor!,
      ...?filter?.equals.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    };
    final res = await _api.get('/data/$table', queryParams: params);
    if (!res.isSuccess || res.data == null) return 0;
    final data = res.data as Map<String, dynamic>;
    return (data['count'] as int?) ?? 0;
  }
}
