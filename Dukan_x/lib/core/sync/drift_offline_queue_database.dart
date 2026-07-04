// ============================================================================
// DRIFT OFFLINE QUEUE DATABASE ADAPTER
// ============================================================================
// Adapts AppDatabase (Drift) to the OfflineQueueDatabase interface so the
// OfflineQueue can execute raw SQL operations through Drift's executor.
//
// Author: DukanX Engineering
// ============================================================================

import 'package:drift/drift.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/sync/offline_queue.dart';

/// Bridges [AppDatabase] (Drift) to the [OfflineQueueDatabase] interface
/// required by [OfflineQueue].
///
/// Drift exposes `customStatement`, `customSelect`, `customInsert`,
/// `customUpdate` which map directly to the abstract contract.
class DriftOfflineQueueDatabase implements OfflineQueueDatabase {
  final AppDatabase _db;

  const DriftOfflineQueueDatabase(this._db);

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await _db.customStatement(sql, arguments ?? const []);
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final rows = await _db
        .customSelect(sql, variables: _toVariables(arguments))
        .get();
    return rows.map((row) => row.data).toList();
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    await _db.customStatement(sql, arguments ?? const []);
    // Drift's customStatement doesn't return affected count for inserts;
    // return 1 as the OfflineQueue only inserts single rows.
    return 1;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    await _db.customStatement(sql, arguments ?? const []);
    // Return 1 as approximation; OfflineQueue updates single rows by PK.
    return 1;
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    await _db.customStatement(sql, arguments ?? const []);
    // Return 1 as approximation; OfflineQueue deletes single rows by PK.
    return 1;
  }

  /// Convert positional arguments to Drift's Variable list for customSelect.
  List<Variable<Object>> _toVariables(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return const [];
    return arguments.map((arg) => Variable<Object>(arg ?? '')).toList();
  }
}
