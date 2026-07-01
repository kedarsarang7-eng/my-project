// ============================================================================
// IDatabaseService — Generic Key-Value-ish Document Store Contract
// ============================================================================
// This is intentionally a NARROW interface — most production code in DukanX
// continues to use the rich `BaseRepository` pattern over Drift. This contract
// exists for a) the migration engine's batch read/write, and b) cross-cutting
// services (audit, settings) that don't warrant a full repository.
//
// Online impl  -> calls AWS Lambda (which fronts DynamoDB).
// Offline impl -> writes directly into Drift's generic `kv_store` table.
// ============================================================================

import 'dart:async';

class QueryFilter {
  /// Map of equality predicates (field => value).
  final Map<String, Object?> equals;

  /// Optional pagination cursor (provider-specific; opaque to caller).
  final String? cursor;

  /// Max results.
  final int limit;

  const QueryFilter({
    this.equals = const {},
    this.cursor,
    this.limit = 100,
  });
}

class QueryPage {
  final List<Map<String, dynamic>> items;
  final String? nextCursor;
  const QueryPage(this.items, [this.nextCursor]);
}

abstract class IDatabaseService {
  /// Upsert a record by its `id` field.
  Future<void> save(String table, Map<String, dynamic> record);

  /// Lookup by primary key.
  Future<Map<String, dynamic>?> findById(String table, String id);

  /// Filter query with simple equality predicates and pagination.
  Future<QueryPage> query(String table, QueryFilter filter);

  /// Hard delete (offline) or soft-delete-by-tombstone (online).
  Future<void> delete(String table, String id);

  /// Batch upsert. Implementations chunk to provider-safe sizes (DynamoDB 25).
  Future<void> batchWrite(String table, List<Map<String, dynamic>> records);

  /// Count rows matching a filter — used by the migration verification pass.
  Future<int> count(String table, [QueryFilter? filter]);

  Future<void> dispose() async {}
}
