// Offline Database Provider — generic CRUD backed by Drift's KvStore table.
// The KvStore is a simple key-value table that stores JSON-encoded records.
// Domain-specific repositories continue to use typed Drift tables directly;
// this provider is used only by the ServiceRegistry for generic/migration ops.

import 'dart:async';
import 'dart:convert';
import '../../../../core/database/app_database.dart';
import '../../contracts/i_database_service.dart';

class DriftDatabaseProvider implements IDatabaseService {
  AppDatabase get _db => AppDatabase.instance;

  // ── Save ──────────────────────────────────────────────────────────────────

  @override
  Future<void> save(String table, Map<String, dynamic> record) async {
    final key = _makeKey(table, record['id']?.toString() ?? '');
    final value = jsonEncode(record);
    await _db.upsertKv(key, value);
  }

  // ── findById ──────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> findById(String table, String id) async {
    final key = _makeKey(table, id);
    final value = await _db.getKv(key);
    if (value == null) return null;
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  // ── query ─────────────────────────────────────────────────────────────────

  @override
  Future<QueryPage> query(String table, QueryFilter filter) async {
    final prefix = '$table:';
    final allValues = await _db.kvByPrefix(prefix);

    var results = allValues
        .map((v) => Map<String, dynamic>.from(jsonDecode(v) as Map))
        .toList();

    // Apply equality filters.
    for (final entry in filter.equals.entries) {
      results = results
          .where((r) => r[entry.key]?.toString() == entry.value?.toString())
          .toList();
    }

    // Cursor-based pagination (cursor = index as string).
    int startIdx = 0;
    if (filter.cursor != null) {
      startIdx = int.tryParse(filter.cursor!) ?? 0;
    }
    final page = results.skip(startIdx).take(filter.limit).toList();
    final nextIdx = startIdx + page.length;
    final hasMore = nextIdx < results.length;

    return QueryPage(page, hasMore ? nextIdx.toString() : null);
  }

  // ── delete ────────────────────────────────────────────────────────────────

  @override
  Future<void> delete(String table, String id) async {
    final key = _makeKey(table, id);
    await _db.deleteKv(key);
  }

  // ── batchWrite ────────────────────────────────────────────────────────────

  @override
  Future<void> batchWrite(String table, List<Map<String, dynamic>> records) async {
    await _db.transaction(() async {
      for (final record in records) {
        final key = _makeKey(table, record['id']?.toString() ?? '');
        await _db.upsertKv(key, jsonEncode(record));
      }
    });
  }

  // ── count ─────────────────────────────────────────────────────────────────

  @override
  Future<int> count(String table, [QueryFilter? filter]) async {
    final page = await query(table, QueryFilter(
      equals: filter?.equals ?? const {},
      limit: 999999,
    ));
    return page.items.length;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {}

  String _makeKey(String table, String id) => '$table:$id';
}
